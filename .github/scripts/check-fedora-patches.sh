#!/bin/bash
# Compare the patches of specs that carry Fedora's patches with Fedora's own
# spec, and keep an issue open for each package and release that differs.
#
#   check-fedora-patches.sh
#
# A spec opts in with
#   # rpmfission-fedora-patches: <Fedora source package>
# and is compared, by patch file name, with that package's spec on the
# release's dist-git branch (fNN, or rawhide for a release not yet branched),
# for each release in FEDORA_RELEASES (in build.yml) that the spec builds for
# (see release-ok.sh). Fedora's patch names are those of the files it
# downloads, so a URL patch counts by its "#/<name>" or its basename. Name a
# local copy of a Fedora patch the same as Fedora's file.
#
# Fedora patches deliberately left out, and patches of our own, go on
#   # rpmfission-fedora-patches-ignore: <file> [<file> ...]
# lines, each with a comment saying why.
#
# A difference opens an issue titled "<pkg>: patches differ from Fedora <N>",
# or updates the body of the open one; once the patches match again the issue
# is closed. With DRY_RUN=1 the differences are only printed.
#
# Environment: GH_TOKEN and GH_REPO, unless DRY_RUN=1.
set -euo pipefail

releases=$(sed -nE "s/^[[:space:]]*FEDORA_RELEASES:[[:space:]]*'(.*)'.*/\1/p" .github/workflows/build.yml |
    jq -r '.[]')
work=$(mktemp -d)
status=0

# Patch file names of a spec, one per line, sorted. rpmspec expands macros and
# conditionals as for the given release.
patch_names() {
    local spec=$1 release=$2
    rpmspec -P --define "fedora $release" --define "dist .fc$release" "$spec" |
        sed -nE 's/^Patch[0-9]*:[[:space:]]*([^[:space:]]+).*/\1/p' |
        sed -E 's|.*#/||; s|.*/||' | sort -u
}

for spec in */*.spec; do
    pkg=$(dirname "$spec")
    fedora_pkg=$(sed -nE 's/^#[[:space:]]*rpmfission-fedora-patches:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' "$spec" | head -n 1)
    [ -n "$fedora_pkg" ] || continue
    ignored=$(sed -nE 's/^#[[:space:]]*rpmfission-fedora-patches-ignore:(.*)/\1/p' "$spec" |
        tr -s ' \t' '\n' | sed '/^$/d' | sort -u)

    for release in $releases; do
        .github/scripts/release-ok.sh "$release" "$spec" || continue

        branch=f$release
        fedora_spec=$work/$fedora_pkg-$release.spec
        url=https://src.fedoraproject.org/rpms/$fedora_pkg/raw/$branch/f/$fedora_pkg.spec
        if ! curl -sfL --retry 3 -o "$fedora_spec" "$url"; then
            branch=rawhide
            url=https://src.fedoraproject.org/rpms/$fedora_pkg/raw/$branch/f/$fedora_pkg.spec
            if ! curl -sfL --retry 3 -o "$fedora_spec" "$url"; then
                echo "::error::$pkg: cannot fetch Fedora's $fedora_pkg.spec for Fedora $release"
                status=1
                continue
            fi
        fi

        if ! ours=$(patch_names "$spec" "$release") ||
           ! theirs=$(patch_names "$fedora_spec" "$release"); then
            echo "::error::$pkg: cannot read the patches of the specs for Fedora $release"
            status=1
            continue
        fi
        missing=$(comm -13 <(echo "$ours") <(echo "$theirs") | comm -23 - <(echo "$ignored") | sed '/^$/d')
        extra=$(comm -23 <(echo "$ours") <(echo "$theirs") | comm -23 - <(echo "$ignored") | sed '/^$/d')
        fedora_version=$(rpmspec -q --srpm --qf '%{version}-%{release}\n' \
            --define "fedora $release" --define "dist .fc$release" "$fedora_spec" 2>/dev/null || echo unknown)

        title="$pkg: patches differ from Fedora $release"
        if [ -z "$missing$extra" ]; then
            echo "$pkg: patches match Fedora $release ($fedora_pkg $fedora_version)"
        else
            echo "$pkg: patches differ from Fedora $release ($fedora_pkg $fedora_version)"
            [ -z "$missing" ] || sed 's/^/  only in Fedora: /' <<< "$missing"
            [ -z "$extra" ] || sed 's/^/  only here: /' <<< "$extra"
        fi
        [ "${DRY_RUN:-0}" = 1 ] && continue

        issue=$(gh issue list --state open --search "in:title \"$title\"" --json number,title \
            --jq "map(select(.title == \"$title\")) | .[0].number // empty")
        if [ -z "$missing$extra" ]; then
            if [ -n "$issue" ]; then
                gh issue close "$issue" --comment "The patches of \`$spec\` match Fedora $release's $fedora_pkg $fedora_version again."
            fi
            continue
        fi

        body=$(
            echo "The patches of \`$spec\` differ from those of Fedora's [$fedora_pkg $fedora_version]($(sed 's|/raw/|/blob/|' <<< "$url")) on \`$branch\`."
            echo
            if [ -n "$missing" ]; then
                echo "Only in Fedora:"
                echo
                sed 's/^/- `/; s/$/`/' <<< "$missing"
                echo
            fi
            if [ -n "$extra" ]; then
                echo "Only here (Fedora dropped them, or they are our own):"
                echo
                sed 's/^/- `/; s/$/`/' <<< "$extra"
                echo
            fi
            echo "Carry the patch, or list it on a \`# rpmfission-fedora-patches-ignore:\` line in the spec with the reason. This issue closes itself once the patches match. See \`.github/scripts/check-fedora-patches.sh\`."
        )
        if [ -n "$issue" ]; then
            gh issue edit "$issue" --body "$body" > /dev/null
            echo "$pkg: updated issue #$issue"
        else
            gh issue create --title "$title" --body "$body"
        fi
    done
done

rm -rf "$work"
exit "$status"
