# Entry point for COPR's "make_srpm" source method. COPR runs:
#   make -f .copr/Makefile srpm outdir=<outdir> spec=<spec>
# inside a Fedora chroot with network access.
# A package's own tools for its sources.sh, such as cargo, are named on
# "# rpmfission-srpm-requires:" lines of its spec and installed by srpm.sh.

srpm:
	dnf -y install rpmdevtools rpm-build
	.copr/srpm.sh $(spec) $(outdir)

.PHONY: srpm
