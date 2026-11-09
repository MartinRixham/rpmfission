#!/bin/bash
# Open a pull request for each package whose upstream GitHub repository has a
# newer release than the spec's Version.
#
#   check-updates.sh                  check every package
#   check-updates.sh <pkg/pkg.spec>   check one package
#
# The upstream repository is the first github.com/<owner>/<repo> in the spec's
# URL or Source fields. The latest release (not a draft or pre-release) is
# used, with a leading "v" or "<name>-" stripped from its tag, or else
# everything up to the "-" before the version (intel-media-26.3.5). Packages
# whose upstream has no GitHub releases are skipped.
#
# A spec with a "# rpmfission-follows-fedora: <binary package>" line instead
# follows the version of that Fedora package in the oldest release in
# FEDORA_RELEASES (in build.yml), as mesa-freeworld must match Fedora's mesa
# exactly.
#
# The update branch is update/<pkg>-<version>. A version whose branch already
# exists is not offered again, so closing a PR without deleting its branch
# skips that version.
#
# The PR bumps Version, resets Release, adds a changelog entry and refreshes
# the "sources" checksums, then runs the build workflow on the branch.
#
# Environment: GH_TOKEN, and a git identity for the commit.
set -euo pipefail

if [ $# -eq 0 ]; then
    base=$(git rev-parse HEAD)
    status=0
    for spec in */*.spec; do
        git checkout -q --force --detach "$base"
        # A child process, so that set -e applies within each package
        "$0" "$spec" || { echo "::error::$(dirname "$spec"): update check failed"; status=1; }
    done
    git checkout -q --force --detach "$base"
    exit "$status"
fi

spec=$1
pkg=$(dirname "$spec")
name=$(rpmspec -q --qf '%{name}\n' --srpm "$spec")
current=$(rpmspec -q --qf '%{version}\n' --srpm "$spec")

follows=$(sed -nE 's/^#[[:space:]]*rpmfission-follows-fedora:[[:space:]]*([^[:space:]]+).*/\1/p' "$spec" | head -n 1)
if [ -n "$follows" ]; then
    release=$(sed -nE "s/^[[:space:]]*FEDORA_RELEASES:[[:space:]]*'(.*)'.*/\1/p" .github/workflows/build.yml |
        jq -r min)
    read -r version srpm < <(dnf repoquery --quiet --releasever="$release" \
        --repo=fedora --repo=updates --latest-limit=1 --arch=x86_64 \
        --qf '%{version} %{sourcerpm}\n' "$follows") || true
    if [ -z "${version:-}" ]; then
        echo "::error::$pkg: no $follows in Fedora $release"
        exit 1
    fi
    tag="$follows $version (Fedora $release)"
    url=https://src.fedoraproject.org/rpms/${srpm%-*-*}
else
    repo=$(rpmspec -P "$spec" |
        sed -nE 's#^(URL|Source[0-9]*):.*https://github\.com/([^/[:space:]]+/[^/[:space:]]+).*#\2#p' |
        head -n 1)
    repo=${repo%.git}
    if [ -z "$repo" ]; then
        echo "$pkg: no GitHub repository in the spec, skipping"
        exit 0
    fi

    err=$(mktemp)
    if ! release=$(gh api "repos/$repo/releases/latest" --jq '[.tag_name, .html_url] | @tsv' 2> "$err"); then
        if grep -q 'HTTP 404' "$err"; then
            echo "$pkg: $repo has no releases, skipping"
            exit 0
        fi
        cat "$err" >&2
        exit 1
    fi
    IFS=$'\t' read -r tag url <<< "$release"

    version=${tag#"$name"-}
    version=${version#v}
    if ! [[ $version =~ ^[0-9] ]] && [[ $version =~ -v?([0-9][A-Za-z0-9._+~^]*)$ ]]; then
        version=${BASH_REMATCH[1]}
    fi
fi
if ! [[ $version =~ ^[0-9][A-Za-z0-9._+~^]*$ ]]; then
    echo "::warning::$pkg: cannot turn release '$tag' into an RPM version"
    exit 0
fi

# rpmdev-vercmp exits 11 when the first version is newer
rc=0
rpmdev-vercmp "$version" "$current" > /dev/null || rc=$?
if [ "$rc" -ne 11 ]; then
    echo "$pkg: $current is up to date (latest: $tag)"
    exit 0
fi

branch=update/$pkg-$version
# Exit status 2 means no such branch; anything else but 0 is a failure
rc=0
git ls-remote --exit-code --heads origin "$branch" > /dev/null || rc=$?
case $rc in
    0) echo "$pkg: branch $branch already exists, skipping"; exit 0 ;;
    2) ;;
    *) exit "$rc" ;;
esac
echo "$pkg: updating $current -> $version"

git switch -q -c "$branch"

sed -i -E \
    -e "s/^(Version:[[:space:]]+).*/\\1$version/" \
    -e 's/^(Release:[[:space:]]+)[0-9.]+/\11/' \
    "$spec"

entry=$(mktemp)
{
    echo "* $(LC_ALL=C date -u '+%a %b %d %Y') $(git config user.name) <$(git config user.email)> - $version-1"
    echo "- Update to $version"
    echo
} > "$entry"
sed -i "/^%changelog\$/r $entry" "$spec"

# Checksums of the remote sources at the new version. Generated sources such
# as vendored crates are made from these during the SRPM build.
dl=$(mktemp -d)
spectool --get-files --sourcedir --define "_sourcedir $dl" "$spec"
files=()
for source in $(spectool --list-files "$spec" | awk '{print $2}' | grep '://'); do
    files+=("$(basename "$source")")
done
if [ ${#files[@]} -gt 0 ]; then
    (cd "$dl" && sha512sum --tag "${files[@]}") > "$pkg/sources"
fi

git add "$pkg"
git commit -q -m "$pkg: update to $version"
git push -q origin "$branch"

# Pushes and pull requests made with the workflow token do not trigger other
# workflows, but a dispatch does. Before the pull request, so that the branch
# builds even if opening it fails.
gh workflow run build.yml --ref "$branch" -f packages="$pkg"

body=$(cat <<EOF
Upstream: $url

Automated update of \`$pkg\` from $current to $version. Version, Release,
the changelog and \`sources\` are updated; the rest needs a person:

- [ ] Read the release notes for changed build steps, dependencies or files
- [ ] The build passes (the build workflow runs on this branch), including
      the patches applying
- [ ] \`License:\` matches \`%cargo_license_summary\` in the build log
EOF
)
gh pr create --base main --head "$branch" \
    --title "$pkg: update to $version" --body "$body"
