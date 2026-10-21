# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Based on the media-gfx/epsonscan2-non-free-plugin ebuild from the slonko
# overlay (Marcin Deranek). Versioned after the plugin itself, which is the
# same (1.0.0.6-1) in several Epson Scan 2 bundles.

EAPI=8

RPM_COMPRESS_TYPE="xz"
inherit rpm

BUNDLE="epsonscan2-bundle-6.7.80.0.x86_64.rpm"

DESCRIPTION="Proprietary plugins for Epson Scan 2 (network scanning, image processing)"
HOMEPAGE="https://support.epson.net/linux/en/epsonscan2.php"
SRC_URI="${BUNDLE}.tar.gz"
S="${WORKDIR}"

LICENSE="EPSON"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist fetch mirror strip"

RDEPEND="
	dev-libs/libltdl
	media-gfx/epsonscan2
	virtual/libusb:1
"

QA_PREBUILT="*"

pkg_nofetch() {
	einfo "The Epson download server does not allow automatic downloads."
	einfo "Download ${SRC_URI} (\"rpm\" / \"64bit\" Epson Scan 2 bundle) with"
	einfo "a web browser from"
	einfo "  ${HOMEPAGE}"
	einfo "and place it in your DISTDIR (usually /var/cache/distfiles)."
}

src_unpack() {
	default
	rpm_unpack "./${BUNDLE}/plugins/${P}-1.x86_64.rpm"
}

src_install() {
	# Keep the upstream symlinks and permissions of the prebuilt files
	mkdir -p "${ED}"/usr || die
	cp -a usr/lib64 usr/libexec usr/share "${ED}"/usr/ || die
	rm -r "${ED}"/usr/share/doc || die

	dodoc usr/share/doc/${P}-1/{NEWS,copyright}
}

pkg_postinst() {
	elog "Network scanners are used through media-gfx/epsonscan2[wifi]."
	elog "See 'scanimage -L' or simple-scan."
}
