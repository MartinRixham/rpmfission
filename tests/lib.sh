# shellcheck shell=bash
# Helpers for the tests run for every package (see run-tests.sh); sourced,
# not run. Package tests can source it too: . tests/lib.sh

# The package's binary RPMs under $PKG_RPMS, one path per line: not the SRPM,
# debuginfo or debugsource, which nobody installs from the repository
pkg_rpms() {
    find "$PKG_RPMS" -maxdepth 1 -name '*.rpm' ! -name '*.src.rpm' \
        ! -name '*-debuginfo-*' ! -name '*-debugsource-*' | sort
}

# Their names and NEVRAs, one per line
pkg_names() {
    pkg_rpms | xargs -r rpm -qp --qf '%{name}\n' 2> /dev/null | sort -u
}
pkg_nevras() {
    pkg_rpms | xargs -r rpm -qp --qf '%{nevra}\n' 2> /dev/null | sort -u
}

# quiet <command>...: runs quietly, showing the output on failure
quiet() {
    local out
    out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }
}

# dnf_checked <dnf args>...: runs dnf -y, showing its output, and fails if
# a scriptlet failed. rpm only warns when %post, %posttrans, %preun or
# %postun fail, and dnf still exits 0.
dnf_checked() {
    local out rc=0
    out=$(dnf -y --setopt=install_weak_deps=False "$@" 2>&1) || rc=$?
    echo "$out"
    if grep -qiE 'scriptlet failed|error in [a-z]+ scriptlet' <<< "$out"; then
        echo "FAIL: a scriptlet failed in: dnf $*" >&2
        return 1
    fi
    return "$rc"
}
