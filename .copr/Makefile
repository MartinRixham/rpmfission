# Entry point for COPR's "make_srpm" source method. COPR runs:
#   make -f .copr/Makefile srpm outdir=<outdir> spec=<spec>
# inside a Fedora chroot with network access.

srpm:
	dnf -y install rpmdevtools rpm-build cargo
	.copr/srpm.sh $(spec) $(outdir)

.PHONY: srpm
