# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop toolchain-funcs xdg

# Upstream tags are the build number (v7533); the version is "4.0 Build 7533"
BUILD=${PV##*.}

DESCRIPTION="Open-source 2D beat 'em up game engine, a continuation of Beats of Rage"
HOMEPAGE="https://github.com/DCurrent/openbor"
SRC_URI="https://github.com/DCurrent/openbor/archive/refs/tags/v${BUILD}.tar.gz
	-> ${P}.gh.tar.gz"
S="${WORKDIR}/${PN}-${BUILD}/engine"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	media-libs/libogg
	media-libs/libpng:=
	media-libs/libsdl2[joystick,opengl,sound,video]
	media-libs/libvorbis
	media-libs/libvpx:=
	media-libs/sdl2-gfx
	virtual/zlib:=
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}"/${P}-flags.patch
)

src_prepare() {
	default

	# version.sh asks for the build number interactively outside a git checkout
	cat > version.h <<-EOV || die
		#ifndef VERSION_H
		#define VERSION_H

		#define VERSION_NAME "OpenBOR"
		#define VERSION_MAJOR "$(ver_cut 1)"
		#define VERSION_MINOR "$(ver_cut 2)"
		#define VERSION_BUILD "${BUILD}"
		#define VERSION_BUILD_INT ${BUILD}
		#define VERSION "v"VERSION_MAJOR"."VERSION_MINOR" Build "VERSION_BUILD

		#endif
	EOV
}

src_compile() {
	tc-export CC PKG_CONFIG

	# CFLAGS/LDFLAGS come from the environment: the Makefile appends to them.
	# CC, INCLUDES and LIBRARIES default to cross-compilation SDK paths
	# ($(LNXDEV)/gcc, -I$(SDKPATH)/include, -Wl,-rpath,$(SDKPATH)/lib/...).
	emake \
		BUILD_LINUX=1 \
		GCC_TARGET=x86_64 \
		CC="$(tc-getCC)" \
		INCLUDES= \
		LIBRARIES= \
		NO_STRIP=1
}

src_install() {
	# Paks, Saves, Logs and ScreenShots are relative to the current directory:
	# the launcher changes to a per-user one first
	exeinto /usr/libexec/${PN}
	doexe OpenBOR
	dobin "${FILESDIR}"/${PN}

	newicon resources/OpenBOR_Icon_128x128.png ${PN}.png
	make_desktop_entry ${PN} OpenBOR ${PN} "Game;ActionGame"

	dodoc README ../README.md
}

pkg_postinst() {
	xdg_pkg_postinst

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "OpenBOR only ships the engine: games (modules) are .pak files that"
		elog "go into \${XDG_DATA_HOME:-~/.local/share}/openbor/Paks, created on the"
		elog "first run along with Saves, Logs and ScreenShots. A .pak can also be"
		elog "started directly with: openbor /path/to/game.pak"
	fi
}
