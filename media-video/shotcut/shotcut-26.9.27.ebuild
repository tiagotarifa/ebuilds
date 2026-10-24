# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Based on media-video/shotcut-25.08.16 from the Gentoo repository.

EAPI=8

inherit cmake flag-o-matic xdg

DESCRIPTION="A free, open source, cross-platform video editor"
HOMEPAGE="https://www.shotcut.org/ https://github.com/mltframework/shotcut/"
SRC_URI="https://github.com/mltframework/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="debug test vulkan"
RESTRICT="!test? ( test )"

BDEPEND="
	dev-qt/qttools:6[linguist]
"
DEPEND="
	dev-qt/qtbase:6[concurrent,dbus,gui,network,opengl,sql,sqlite,widgets,X,xml]
	dev-qt/qtcharts:6
	dev-qt/qtdeclarative:6[widgets]
	dev-qt/qtmultimedia:6
	dev-qt/qtwebsockets:6
	>=media-libs/mlt-7.36.0[ffmpeg,frei0r,jack,opengl,qt6,sdl,xml]
	media-video/ffmpeg:=
	sci-libs/fftw:3.0=
	x11-libs/libX11
"
RDEPEND="
	${DEPEND}
	virtual/jack
	vulkan? ( media-video/ffmpeg[vulkan] )
"

src_configure() {
	CMAKE_BUILD_TYPE=$(usex debug Debug Release)
	local mycmakeargs=(
		-DSHOTCUT_VERSION="${PV}"
		-DCLANG_FORMAT=OFF
		-DSHOTCUT_BUILD_TESTS=$(usex test)
		# Hardware decoding through Vulkan instead of VA-API
		-DUSE_VULKAN=$(usex vulkan)
	)
	use debug || append-cxxflags "-DNDEBUG"
	append-cxxflags "-DSHOTCUT_NOUPGRADE"
	cmake_src_configure
}
