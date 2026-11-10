#!/bin/bash
# Add freshly built RPMs to the dnf repository.
#
#   publish.sh <dir-of-new-rpms>
#
# The directory holds one subdirectory of RPMs per chroot, e.g.
# fedora-44-x86_64/. Chroots of releases not in FEDORA_RELEASES are removed.
#
# Environment: FEDORA_RELEASES (JSON list, e.g. [44]), REPO_URL, REPO_NAME,
# GPG_KEY (fingerprint of a secret key in the gpg keyring, without a
# passphrase, that signs the RPMs and each chroot's repomd.xml), GH_REPO
# (owner/name) and GH_TOKEN (allowed to write releases and push gh-pages).
#
# The layout mirrors a COPR project, one repository per chroot:
#   <REPO_URL>/<REPO_NAME>.repo
#   <REPO_URL>/RPM-GPG-KEY-<REPO_NAME>
#   <REPO_URL>/fedora-$releasever-$basearch/repodata/
#
# The repository metadata is served by GitHub Pages from the gh-pages branch,
# but the RPMs are assets of a GitHub release per chroot, tagged with the
# chroot's name: Pages times out deploying a site of hundreds of MB. Each
# chroot's metadata names its release as the packages' xml:base, so dnf
# fetches them from there.
#
# gh-pages is force-pushed as a single commit, as it only holds the metadata.
set -euo pipefail

new=$(realpath "$1")
site=$(mktemp -d)
# The RPMs of each chroot being republished, named as their release assets
work=$(mktemp -d)
keep=2
: "${GPG_KEY:?GPG_KEY must name the signing key}"
: "${GH_REPO:?GH_REPO must name the repository}"
pubkey=RPM-GPG-KEY-$REPO_NAME
assets_url=https://github.com/$GH_REPO/releases/download
# A separate index so the checkout of main is left alone
export GIT_INDEX_FILE=$site.index

# Only a missing branch means "start fresh"; any other git failure must stop
# the publish rather than force-push an empty repository over the old one
if git ls-remote --exit-code --heads origin gh-pages > /dev/null; then
    git fetch --depth 1 origin gh-pages
    git --work-tree "$site" checkout FETCH_HEAD -- .
else
    status=$?
    [ "$status" -eq 2 ] || exit "$status"
fi

# The id of the chroot's release, or nothing if it has none. Any failure but
# a missing release stops the publish.
release_id() {
    local out
    if out=$(gh api "repos/$GH_REPO/releases/tags/$1" --jq .id 2>&1); then
        echo "$out"
    elif ! grep -q 'HTTP 404' <<< "$out"; then
        echo "$out" >&2
        return 1
    fi
}

# The names of a release's assets
release_assets() {
    gh api --paginate "repos/$GH_REPO/releases/$1/assets" --jq '.[].name'
}

# GitHub renames assets with characters other than these, such as the ^ of
# x264's snapshot version, so the RPMs are given such names before upload and
# the metadata names them so. dnf goes by the RPM headers, not file names.
asset_name() {
    echo "${1//[^A-Za-z0-9._-]/.}"
}

# Only binary packages are published. SRPMs (with vendored sources) and
# debuginfo are too large, and remain available as workflow artifacts.
shopt -s nullglob extglob
published=0
declare -A todo
for dir in "$new"/fedora-*/; do
    rpms=("$dir"!(*.src|*-debuginfo-*|*-debugsource-*).rpm)
    [ ${#rpms[@]} -gt 0 ] || continue
    todo[$(basename "$dir")]=1
    published=$((published + ${#rpms[@]}))
done
if [ "$published" -eq 0 ]; then
    echo "No RPMs to publish"
    exit 0
fi

# Drop chroots of releases that are no longer built (end of life). Their
# releases are deleted once the metadata no longer names them.
eol=()
for dir in "$site"/fedora-*/; do
    chroot=$(basename "$dir")
    release=${chroot#fedora-}
    release=${release%%-*}
    if ! jq -e --arg r "$release" 'map(tostring) | index($r)' \
            <<< "$FEDORA_RELEASES" > /dev/null; then
        echo "Removing $chroot"
        rm -rf "$dir"
        unset "todo[$chroot]"
        eol+=("$chroot")
    fi
done

# The public key is served next to the repositories, and imported into the
# local rpm database so that rpm -K can tell which RPMs it has signed
gpg --batch --export --armor "$GPG_KEY" > "$site/$pubkey"
rpm --import "$site/$pubkey"

declare -A stale
for chroot in "${!todo[@]}"; do
    dir=$work/$chroot
    mkdir -p "$dir" "$site/$chroot"
    id=$(release_id "$chroot")
    if [ -z "$id" ]; then
        gh release create "$chroot" --title "$chroot" --latest=false \
            --notes "RPMs of the $REPO_NAME repository for $chroot. Install them with dnf, as the README says, rather than from here."
        id=$(release_id "$chroot")
    fi
    mapfile -t before < <(release_assets "$id")
    if [ ${#before[@]} -gt 0 ]; then
        gh release download "$chroot" --pattern '*.rpm' --dir "$dir"
    fi

    # The new builds replace any of the same name
    declare -A upload=()
    for rpm in "$new/$chroot/"!(*.src|*-debuginfo-*|*-debugsource-*).rpm; do
        name=$(asset_name "$(basename "$rpm")")
        cp -p "$rpm" "$dir/$name"
        upload[$name]=1
    done

    # Keep the newest $keep builds of each package so a bad one can be
    # downgraded
    dnf repomanage --old --keep "$keep" "$dir" | xargs -r rm -v

    # Sign every RPM not yet signed with the key. rpm -K reports
    # "signatures OK" only for a valid signature by a key in the rpm
    # database.
    unsigned=()
    for rpm in "$dir/"*.rpm; do
        if ! rpm -K "$rpm" 2>&1 | grep -q 'signatures OK'; then
            unsigned+=("$rpm")
            upload[$(basename "$rpm")]=1
        fi
    done
    if [ ${#unsigned[@]} -gt 0 ]; then
        rpmsign --addsign --define "_gpg_name $GPG_KEY" "${unsigned[@]}"
    fi

    files=()
    for name in "${!upload[@]}"; do
        [ -f "$dir/$name" ] && files+=("$dir/$name")
    done
    if [ ${#files[@]} -gt 0 ]; then
        gh release upload "$chroot" --clobber "${files[@]}"
    fi

    # The metadata must name each RPM exactly as its asset is named
    mapfile -t after < <(release_assets "$id")
    for rpm in "$dir/"*.rpm; do
        name=$(basename "$rpm")
        if ! printf '%s\n' "${after[@]}" | grep -qxF -- "$name"; then
            echo "::error::$name is missing from the $chroot release"
            exit 1
        fi
    done

    # Assets no longer kept are deleted after gh-pages stops naming them
    for name in "${before[@]}"; do
        [ -f "$dir/$name" ] || stale[$chroot/$name]=1
    done

    # Regenerate and sign the metadata. The signature lets dnf check the
    # metadata (repo_gpgcheck).
    rm -rf "$site/$chroot/repodata"
    createrepo_c --baseurl "$assets_url/$chroot/" --outputdir "$site/$chroot" "$dir"
    gpg --batch --yes --local-user "$GPG_KEY" --detach-sign --armor \
        "$site/$chroot/repodata/repomd.xml"
done

# A priority above the default (99) makes dnf take packages that are also in
# other repositories, such as RPM Fusion's ffmpeg and x264, from this one.
# Metadata expires after 6 hours, as for Fedora's updates repository, instead
# of dnf's default of 48, so that new builds are seen the same day.
cat > "$site/$REPO_NAME.repo" <<EOF
[$REPO_NAME]
name=$REPO_NAME
baseurl=$REPO_URL/fedora-\$releasever-\$basearch/
type=rpm-md
priority=90
metadata_expire=6h
skip_if_unavailable=True
gpgcheck=1
repo_gpgcheck=1
gpgkey=$REPO_URL/$pubkey
enabled=1
enabled_metadata=1
EOF

{
    echo "<!doctype html><meta charset=utf-8><title>$REPO_NAME</title>"
    echo "<h1>$REPO_NAME</h1>"
    echo "<pre>sudo dnf config-manager addrepo --from-repofile=$REPO_URL/$REPO_NAME.repo</pre>"
    for dir in "$site"/fedora-*/; do
        chroot=$(basename "$dir")
        echo "<h2>$chroot</h2><ul>"
        if [ -d "$work/$chroot" ]; then
            names=$(cd "$work/$chroot" && ls -- *.rpm)
        else
            names=$(release_assets "$(release_id "$chroot")" | grep '\.rpm$' | sort)
        fi
        for f in $names; do
            echo "<li><a href=\"$assets_url/$chroot/$f\">$f</a></li>"
        done
        echo "</ul>"
    done
} > "$site/index.html"
touch "$site/.nojekyll"

rm -f "$GIT_INDEX_FILE"
git --work-tree "$site" add -A
tree=$(git write-tree)
export GIT_AUTHOR_NAME="github-actions[bot]"
export GIT_AUTHOR_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
commit=$(git commit-tree "$tree" -m "Publish $(git rev-parse --short HEAD)")
git push -f origin "$commit:refs/heads/gh-pages"

# Only now that gh-pages no longer names them. dnf clients with metadata
# from before can still fail to download an old build until it expires.
for key in "${!stale[@]}"; do
    gh release delete-asset "${key%%/*}" "${key#*/}" --yes
done
for chroot in "${eol[@]}"; do
    if [ -n "$(release_id "$chroot")" ]; then
        gh release delete "$chroot" --cleanup-tag --yes
    fi
done
