#!/bin/bash
# Add freshly built RPMs to the dnf repository on the gh-pages branch.
#
#   publish.sh <dir-of-new-rpms>
#
# Environment: CHROOT (e.g. fedora-44-x86_64), REPO_URL, REPO_NAME.
#
# The layout mirrors a COPR project, one repository per chroot:
#   <REPO_URL>/<REPO_NAME>.repo
#   <REPO_URL>/fedora-$releasever-$basearch/{*.rpm,repodata/}
#
# gh-pages is force-pushed as a single commit so old binaries do not pile up
# in git history.
set -euo pipefail

new=$(realpath "$1")
site=$(mktemp -d)
keep=2
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
rpms=("$new"/!(*.src|*-debuginfo-*|*-debugsource-*).rpm)
if [ ${#rpms[@]} -eq 0 ]; then
    echo "No RPMs to publish"
    exit 0
fi

mkdir -p "$site/$CHROOT"
cp -p "${rpms[@]}" "$site/$CHROOT/"

# Keep the newest $keep builds of each package so a bad one can be downgraded
dnf repomanage --old --keep "$keep" "$site/$CHROOT" | xargs -r rm -v
createrepo_c --update "$site/$CHROOT"

cat > "$site/$REPO_NAME.repo" <<EOF
[$REPO_NAME]
name=$REPO_NAME
baseurl=$REPO_URL/fedora-\$releasever-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=0
repo_gpgcheck=0
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
