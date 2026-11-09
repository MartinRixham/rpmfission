#!/bin/bash
# Keep an issue open for each package whose upstream GitHub repository has a
# newer release than the spec's Version, and fail while any is out of date.
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
# A newer version opens an issue titled "<pkg>: newer version available", or
# updates the body of the open one; once the spec is up to date the issue is
# closed. With DRY_RUN=1 the versions are only printed.
#
# Exits 1 if any package is out of date or could not be checked.
#
# Environment: GH_TOKEN and GH_REPO, unless DRY_RUN=1.
set -euo pipefail

# Exit status of a single-package check that found a newer version
outdated=3

if [ $# -eq 0 ]; then
    status=0
    for spec in */*.spec; do
        # A child process, so that set -e applies within each package
        rc=0
        "$0" "$spec" || rc=$?
        if [ "$rc" -ne 0 ]; then
            [ "$rc" -eq "$outdated" ] || echo "::error::$(dirname "$spec"): update check failed"
            status=1
        fi
    done
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

# rpmdev-vercmp exits 0 when the versions are equal, 11 when the first is
# newer and 12 when the second is
rc=0
rpmdev-vercmp "$version" "$current" > /dev/null || rc=$?
case $rc in
    11)
        echo "::error::$pkg: $current is out of date (latest: $tag)"
        result=$outdated
        ;;
    0|12)
        echo "$pkg: $current is up to date (latest: $tag)"
        result=0
        ;;
    *) exit 1 ;;
esac
[ "${DRY_RUN:-0}" = 1 ] && exit "$result"

title="$pkg: newer version available"
issue=$(gh issue list --state open --search "in:title \"$title\"" --json number,title \
    --jq "map(select(.title == \"$title\")) | .[0].number // empty")
if [ "$result" -eq 0 ]; then
    if [ -n "$issue" ]; then
        gh issue close "$issue" --comment "\`$spec\` is at $current, the latest version."
    fi
    exit 0
fi

body=$(cat <<EOF
\`$spec\` is at $current; upstream has [$tag]($url), version $version.

- [ ] Read the release notes for changed build steps, dependencies or files
- [ ] Bump \`Version\`, reset \`Release\` and add a changelog entry
- [ ] Refresh the checksums in \`$pkg/sources\` (\`spectool -g\`, then
      \`sha512sum --tag\` of the downloaded files)
- [ ] The build passes, including the patches applying
- [ ] \`License:\` matches \`%cargo_license_summary\` in the build log

This issue closes itself once the spec is up to date. See
\`.github/scripts/check-updates.sh\`.
EOF
)
if [ -n "$issue" ]; then
    gh issue edit "$issue" --body "$body" > /dev/null
    echo "$pkg: updated issue #$issue"
else
    gh issue create --title "$title" --body "$body"
fi
exit "$result"
