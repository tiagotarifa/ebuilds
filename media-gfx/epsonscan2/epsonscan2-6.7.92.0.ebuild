# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Based on the media-gfx/epsonscan2 ebuild from the slonko overlay
# (Marcin Deranek), adapted for 6.7.92.0, Qt6 and a driver-only build.

EAPI=8

inherit cmake desktop udev

MY_P="${P}-1"

DESCRIPTION="Epson Scan 2 SANE backend and scanner utility for Epson scanners"
HOMEPAGE="https://support.epson.net/linux/en/epsonscan2.php"
SRC_URI="${MY_P}.src.tar.gz"
S="${WORKDIR}/${MY_P}"

# Code: LGPL-2.1+, udev rules: GPL-3+, bundled rapidjson: MIT
LICENSE="LGPL-2.1+ GPL-3+ MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="gui wifi"
RESTRICT="fetch mirror"

DEPEND="
	dev-libs/boost
	media-libs/libharu:=
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/tiff:=
	virtual/libusb:1
	virtual/zlib:=
	gui? ( dev-qt/qtbase:6[gui,widgets] )
"
RDEPEND="
	${DEPEND}
	media-gfx/sane-backends
	sys-process/psmisc
	wifi? ( net-dns/avahi[dbus] )
"
# The plugin depends on this package, hence PDEPEND
PDEPEND="wifi? ( media-gfx/epsonscan2-non-free-plugin )"

PATCHES=(
	"${FILESDIR}"/${P}-cmake.patch
	"${FILESDIR}"/${P}-unbundle.patch
	"${FILESDIR}"/${P}-boost.patch
	"${FILESDIR}"/${P}-gcc.patch
	"${FILESDIR}"/${P}-udev-desktop.patch
	# Bug fixes by Hubert Figuière, via the slonko overlay
	"${FILESDIR}"/${P}-Fix-crash.patch
	"${FILESDIR}"/${P}-Use-XDG-open-to-open-the-directory.patch
	"${FILESDIR}"/${P}-Fix-a-crash-on-an-OOB-container-access.patch
	"${FILESDIR}"/${P}-Fix-folder-creation-crash.patch
	"${FILESDIR}"/${P}-qt6.patch
	"${FILESDIR}"/${P}-return-type.patch
)

pkg_nofetch() {
	einfo "Download the Epson Scan 2 source package (${SRC_URI}) from"
	einfo "  ${HOMEPAGE}"
	einfo "and place it in your DISTDIR (usually /var/cache/distfiles)."
}

src_prepare() {
	# Make sure the bundled copies can't be used
	rm -r thirdparty/{HaruPDF,zlib} || die
	# Unused test/sample projects (old cmake_minimum_required)
	rm -r src/ES2Emulator src/Controller/Test \
		"src/ScanSDK/Src/SDK/SCANSDKsample_C++" || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_GUI=$(usex gui)
		# The Scan SDK is only used by third-party applications
		-DBUILD_SCANSDK=OFF
		-DEPSON_OCR_INSTALL_PATH="${EPREFIX}/usr/libexec/epsonscan2-ocr/"
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# SANE's dll backend loads libsane-<name>.so.1 from /usr/lib*/sane
	local so
	for so in libsane-epsonscan2.so.1 libsane-epsonscan2.so.1.0.0; do
		dosym ../epsonscan2/libsane-epsonscan2.so /usr/$(get_libdir)/sane/${so}
	done

	insinto /etc/sane.d/dll.d
	doins epsonscan2

	udev_newrules epsonscan2.rules 60-epsonscan2.rules

	dodoc AUTHORS NEWS README
	newdoc changelog.Debian ChangeLog

	if use gui; then
		domenu desktop/rpm/x86_64/epsonscan2.desktop
		newicon Resources/Icons/escan2_app.png epsonscan2.png
	fi
}

pkg_postinst() {
	udev_reload

	elog "Add your user to the 'scanner' group to access USB scanners:"
	elog "  usermod -aG scanner <user>"
	elog "Then test with 'scanimage -L' or simple-scan."
	elog
	if use wifi; then
		elog "Network (Wi-Fi/Ethernet) scanners are discovered with avahi-browse"
		elog "(avahi-daemon must be running). If a scanner is not found, list its"
		elog "IP address in ~/.epsonscan2/Network/epsonscan2.conf:"
		elog "  [Network]"
		elog "  192.168.0.10"
		elog "(with USE=gui, 'epsonscan2 --set-ip <ip>' writes this file)."
	else
		elog "Built without USE=wifi: network scanning and some USB models"
		elog "(product IDs 0x013a-0x013f, 0x0142, 0x014a) need the proprietary"
		elog "media-gfx/epsonscan2-non-free-plugin, which USE=wifi pulls in."
	fi
}

pkg_postrm() {
	udev_reload
}
