#!/bin/bash
# Check that the published RPMs can still be installed on Fedora, and keep an
# issue open for each package with dependencies that are no longer met.
#
#   check-repoclosure.sh
#
# Runs dnf repoclosure on the newest build of each package in the published
# repository, for each chroot of FEDORA_RELEASES and FEDORA_ARCHES (in
# build.yml), against Fedora's fedora, updates and fedora-cisco-openh264
# repositories. A dependency can break without any change here, for example
# when Fedora updates a library to a new soname (openapv 1.1 for ffmpeg), or
# updates a package that ours require at an exact version (mesa for
# mesa-freeworld). The fix is usually a rebuild (bump Release), or an update
# to Fedora's new version.
#
# A package with unmet dependencies, named by its source package, opens an
# issue titled "<pkg>: published RPMs have unmet dependencies", or updates the
# body of the open one. Once every chroot is checked and the package is clean,
# the issue is closed. With DRY_RUN=1 the problems are only printed.
#
# Exits 1 if any package has unmet dependencies or a chroot could not be
# checked.
#
# Environment: REPO_URL (the published repository's base URL), and GH_TOKEN
# and GH_REPO unless DRY_RUN=1.
set -euo pipefail

: "${REPO_URL:?REPO_URL must name the published repository}"
workflow=.github/workflows/build.yml
releases=$(sed -nE "s/^[[:space:]]*FEDORA_RELEASES:[[:space:]]*'(.*)'.*/\1/p" "$workflow" | jq -r '.[]')
arches=$(sed -nE "s/^[[:space:]]*FEDORA_ARCHES:[[:space:]]*'(.*)'.*/\1/p" "$workflow" | jq -r '.[]')
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
title_suffix=": published RPMs have unmet dependencies"
status=0
complete=1

# One line per unmet dependency: <source package> <chroot> <NEVRA> <dependency>
: > "$work/broken"

for release in $releases; do
    for arch in $arches; do
        chroot=fedora-$release-$arch
        baseurl=$REPO_URL/$chroot/
        if ! curl -sfL --retry 3 -o /dev/null "${baseurl}repodata/repomd.xml"; then
            echo "$chroot: not published yet, skipping"
            continue
        fi

        # The published repository's id must not clash with a configured one.
        # --forcearch only picks the metadata, so any runner checks any
        # architecture. Old builds kept for downgrades (see publish.sh) may
        # well be broken, so only the newest of each package is checked.
        # shellcheck disable=SC2054 # the commas are dnf's
        dnf_args=(--quiet --setopt=cachedir="$work/cache"
            --repofrompath=rpmfission-published,"$baseurl"
            --releasever="$release" --forcearch="$arch")
        rm -rf "$work/cache"
        rc=0
        dnf "${dnf_args[@]}" --repo=fedora,updates,fedora-cisco-openh264,rpmfission-published \
            repoclosure --check=rpmfission-published --newest --json \
            > "$work/closure.json" 2> "$work/closure.err" || rc=$?

        # repoclosure exits 1 both for unmet dependencies and for errors, but
        # only prints a JSON list for the first
        problems=
        if ! jq -e 'type == "array"' "$work/closure.json" > /dev/null 2>&1 ||
           ! problems=$(jq -r '.[] | .package as $p | .unresolved_dependencies[] | [$p, .] | @tsv' \
                "$work/closure.json") ||
           { [ "$rc" -ne 0 ] && [ -z "$problems" ]; }; then
            cat "$work/closure.err" >&2
            echo "::error::$chroot: repoclosure failed"
            status=1
            complete=0
            continue
        fi
        if [ -z "$problems" ]; then
            echo "$chroot: every dependency is met"
            continue
        fi

        # Binary package NEVRA to source package name
        declare -A source=()
        while read -r nevra src; do
            source[$nevra]=$src
        done < <(dnf "${dnf_args[@]}" --repo=rpmfission-published repoquery \
            --qf '%{name}-%{evr}.%{arch} %{source_name}\n' 2> /dev/null || true)

        while IFS=$'\t' read -r nevra dep; do
            # NEVRA from repoclosure has no epoch when it is 0; repoquery's
            # evr has none then either
            src=${source[$nevra]:-${nevra%-*-*}}
            echo "::error::$chroot: $nevra (from $src) needs $dep, which nothing provides"
            printf '%s\t%s\t%s\t%s\n' "$src" "$chroot" "$nevra" "$dep" >> "$work/broken"
        done <<< "$problems"
        status=1
        unset source
    done
done

[ "${DRY_RUN:-0}" = 1 ] && exit "$status"

broken_pkgs=$(cut -f1 "$work/broken" | sort -u)

for pkg in $broken_pkgs; do
    title=$pkg$title_suffix
    body=$(
        echo "The newest published RPMs of \`$pkg\` need packages that neither Fedora nor this repository provides, so dnf cannot install or upgrade them:"
        echo
        awk -F'\t' -v pkg="$pkg" '$1 == pkg {
            if ($2 != last) { if (last != "") print ""; print "**" $2 "**"; print ""; last = $2 }
            print "- `" $3 "` needs `" $4 "`"
        }' "$work/broken"
        echo
        echo "This usually means Fedora has updated something the package was built against, such as a library with a new soname or a package required at an exact version. Rebuild the package by bumping \`Release\` with a changelog entry, or update it to Fedora's new version if it follows Fedora."
        echo
        echo "This issue closes itself once the published RPMs install again. See \`.github/scripts/check-repoclosure.sh\`."
    )
    issue=$(gh issue list --state open --search "in:title \"$title\"" --json number,title \
        --jq "map(select(.title == \"$title\")) | .[0].number // empty")
    if [ -n "$issue" ]; then
        gh issue edit "$issue" --body "$body" > /dev/null
        echo "$pkg: updated issue #$issue"
    else
        gh issue create --title "$title" --body "$body"
    fi
done

# A chroot that could not be checked may be where an open issue's problem is
if [ "$complete" -eq 1 ]; then
    gh issue list --state open --search "in:title \"$title_suffix\"" --json number,title \
        --jq ".[] | select(.title | endswith(\"$title_suffix\")) | [.number, .title] | @tsv" |
    while IFS=$'\t' read -r number title; do
        pkg=${title%"$title_suffix"}
        grep -qxF -- "$pkg" <<< "$broken_pkgs" && continue
        gh issue close "$number" --comment "The newest published RPMs of \`$pkg\` have every dependency met again."
    done
fi

exit "$status"
