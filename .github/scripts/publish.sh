#!/bin/bash
# Add freshly built RPMs to the dnf repository on the gh-pages branch.
#
#   publish.sh <dir-of-new-rpms>
#
# The directory holds one subdirectory of RPMs per chroot, e.g.
# fedora-44-x86_64/. Chroots of releases not in FEDORA_RELEASES are removed.
#
# Environment: FEDORA_RELEASES (JSON list, e.g. [44]), REPO_URL, REPO_NAME,
# GPG_KEY (fingerprint of a secret key in the gpg keyring, without a
# passphrase, that signs the RPMs and each chroot's repomd.xml).
#
# The layout mirrors a COPR project, one repository per chroot:
#   <REPO_URL>/<REPO_NAME>.repo
#   <REPO_URL>/RPM-GPG-KEY-<REPO_NAME>
#   <REPO_URL>/fedora-$releasever-$basearch/{*.rpm,repodata/}
#
# gh-pages is force-pushed as a single commit so old binaries do not pile up
# in git history.
set -euo pipefail

new=$(realpath "$1")
site=$(mktemp -d)
keep=2
: "${GPG_KEY:?GPG_KEY must name the signing key}"
pubkey=RPM-GPG-KEY-$REPO_NAME
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

# Only binary packages are published. SRPMs (with vendored sources) and
# debuginfo are too large to keep in git and remain available as workflow
# artifacts.
shopt -s nullglob extglob
published=0
declare -A changed
for dir in "$new"/fedora-*/; do
    chroot=$(basename "$dir")
    rpms=("$dir"!(*.src|*-debuginfo-*|*-debugsource-*).rpm)
    [ ${#rpms[@]} -gt 0 ] || continue
    mkdir -p "$site/$chroot"
    cp -p "${rpms[@]}" "$site/$chroot/"
    # Keep the newest $keep builds of each package so a bad one can be
    # downgraded
    dnf repomanage --old --keep "$keep" "$site/$chroot" | xargs -r rm -v
    changed[$chroot]=1
    published=$((published + ${#rpms[@]}))
done
if [ "$published" -eq 0 ]; then
    echo "No RPMs to publish"
    exit 0
fi

# Drop chroots of releases that are no longer built (end of life)
for dir in "$site"/fedora-*/; do
    chroot=$(basename "$dir")
    release=${chroot#fedora-}
    release=${release%%-*}
    if ! jq -e --arg r "$release" 'map(tostring) | index($r)' \
            <<< "$FEDORA_RELEASES" > /dev/null; then
        echo "Removing $chroot"
        rm -rf "$dir"
    fi
done

# The public key is served next to the repositories, and imported into the
# local rpm database so that rpm -K can tell which RPMs it has signed
gpg --batch --export --armor "$GPG_KEY" > "$site/$pubkey"
rpm --import "$site/$pubkey"

# Sign every RPM not yet signed with the key: the new builds, and any older
# ones published before signing began, so that dnf can still downgrade to
# them. rpm -K reports "signatures OK" only for a valid signature by a key
# in the rpm database.
for dir in "$site"/fedora-*/; do
    chroot=$(basename "$dir")
    unsigned=()
    for rpm in "$dir"*.rpm; do
        if ! rpm -K "$rpm" 2>&1 | grep -q 'signatures OK'; then
            unsigned+=("$rpm")
        fi
    done
    if [ ${#unsigned[@]} -gt 0 ]; then
        rpmsign --addsign --define "_gpg_name $GPG_KEY" "${unsigned[@]}"
        changed[$chroot]=1
    fi
    # Regenerate and sign the metadata where the RPMs changed, or where it
    # has no signature yet. The signature lets dnf check the metadata
    # (repo_gpgcheck).
    if [ -n "${changed[$chroot]:-}" ] || [ ! -f "$dir/repodata/repomd.xml.asc" ]; then
        createrepo_c --update "$dir"
        gpg --batch --yes --local-user "$GPG_KEY" --detach-sign --armor \
            "$dir/repodata/repomd.xml"
    fi
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
        for rpm in "$dir"*.rpm; do
            f=$(basename "$rpm")
            echo "<li><a href=\"$chroot/$f\">$f</a></li>"
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
