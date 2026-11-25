# Entry point for COPR's "make_srpm" source method. COPR runs:
#   make -f .copr/Makefile srpm outdir=<outdir> spec=<spec>
# inside a Fedora chroot with network access.
# pnpm (which pulls in nodejs) is for sources.sh hooks that vendor node_modules,
# such as mdhero's.

srpm:
	dnf -y install rpmdevtools rpm-build cargo pnpm
	.copr/srpm.sh $(spec) $(outdir)

.PHONY: srpm
