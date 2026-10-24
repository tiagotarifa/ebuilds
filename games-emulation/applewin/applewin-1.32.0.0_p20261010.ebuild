# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake desktop

COMMIT="a1e20c0362f392dc25f1a3b218d2f84d4f1a25da"
IMGUI_COMMIT="f1cc2ae15e53a861a874c3034aae6798fde194ab"
IMGUI_CLUB_COMMIT="b083116866e05e0d4bccb2c7f28d94a76ee4965e"
IMGUI_FILEBROWSER_COMMIT="47a1884524d6a3df5d99f70ecc82e1ed0ccd26cf"
QHEXVIEW_COMMIT="3d433cff336c1d1218397ed40f287be7249e9b66"

DESCRIPTION="Apple II emulator (Linux port of AppleWin)"
HOMEPAGE="https://github.com/audetto/AppleWin"
SRC_URI="
	https://github.com/audetto/AppleWin/archive/${COMMIT}.tar.gz -> ${P}.gh.tar.gz
	https://github.com/ocornut/imgui/archive/${IMGUI_COMMIT}.tar.gz
		-> imgui-${IMGUI_COMMIT}.gh.tar.gz
	sdl? (
		https://github.com/ocornut/imgui_club/archive/${IMGUI_CLUB_COMMIT}.tar.gz
			-> imgui_club-${IMGUI_CLUB_COMMIT}.gh.tar.gz
		https://github.com/AirGuanZ/imgui-filebrowser/archive/${IMGUI_FILEBROWSER_COMMIT}.tar.gz
			-> imgui-filebrowser-${IMGUI_FILEBROWSER_COMMIT}.gh.tar.gz
	)
	qt6? (
		https://github.com/Dax89/QHexView/archive/${QHEXVIEW_COMMIT}.tar.gz
			-> QHexView-${QHEXVIEW_COMMIT}.gh.tar.gz
	)
"
S="${WORKDIR}/AppleWin-${COMMIT}"

# Code: GPL-2+; imgui, imgui_club, imgui-filebrowser, QHexView, libretro-common:
# MIT; Cousine font: Apache-2.0. The Apple II and peripheral card ROMs are
# embedded in the binaries and are not freely redistributable.
LICENSE="GPL-2+ Apache-2.0 MIT all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
IUSE="libretro ncurses +network qt6 +sdl"
# With every frontend disabled upstream builds all of them
REQUIRED_USE="|| ( libretro ncurses qt6 sdl )"
RESTRICT="bindist mirror"

DEPEND="
	dev-libs/libyaml
	virtual/minizip:=
	virtual/zlib:=
	ncurses? (
		dev-libs/libevdev
		sys-libs/ncurses:=
	)
	network? ( net-libs/libslirp )
	qt6? (
		dev-qt/qtbase:6[gui,opengl,widgets]
		dev-qt/qtmultimedia:6
	)
	sdl? (
		media-libs/libsdl2[opengl,video]
		media-libs/sdl2-image
		virtual/opengl
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	dev-util/xxd
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}"/${P}-unbundle.patch
	"${FILESDIR}"/${P}-resource-path.patch
)

src_prepare() {
	# Make sure the bundled copies can't be used
	rm -r libyaml minizip zlib || die

	# resource/Cousine-Regular.ttf, embedded by every frontend, links into imgui
	local d=source/frontends/sdl/imgui
	rmdir ${d}/imgui || die
	mv "${WORKDIR}"/imgui-${IMGUI_COMMIT} ${d}/imgui || die
	# Unused, with old cmake_minimum_required
	rm -r ${d}/imgui/examples || die
	if use sdl; then
		rmdir ${d}/{imgui_club,imgui-filebrowser} || die
		mv "${WORKDIR}"/imgui_club-${IMGUI_CLUB_COMMIT} ${d}/imgui_club || die
		mv "${WORKDIR}"/imgui-filebrowser-${IMGUI_FILEBROWSER_COMMIT} \
			${d}/imgui-filebrowser || die
	fi
	if use qt6; then
		rmdir source/frontends/qt/QHexView || die
		mv "${WORKDIR}"/QHexView-${QHEXVIEW_COMMIT} source/frontends/qt/QHexView || die
	fi

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_APPLEN=$(usex ncurses)
		-DBUILD_LIBRETRO=$(usex libretro)
		-DBUILD_QAPPLE=$(usex qt6)
		-DBUILD_SA2=$(usex sdl)
		-DENABLE_NETWORKING=$(usex network)
	)
	# Used by common2 (all frontends but qapple)
	if use libretro || use ncurses || use sdl; then
		mycmakeargs+=( -DAPPLEWIN_ROOT_PATH=../share/${PN} )
	fi
	# Desktop OpenGL instead of OpenGL ES
	use sdl && mycmakeargs+=( -DSA2_OPENGL=ON -DSA2_SDL3=OFF )
	cmake_src_configure
}

src_test() {
	"${BUILD_DIR}"/testcpu6502 || die "testcpu6502 failed"
	# Built with common2, which qapple doesn't use
	if use libretro || use ncurses || use sdl; then
		"${BUILD_DIR}"/testyaml || die "testyaml failed"
	fi
}

src_install() {
	cmake_src_install

	# Debugger symbol tables, looked up in ${ROOT_PATH}/bin
	insinto /usr/share/${PN}/bin
	doins bin/{APPLE2E.SYM,A2_BASIC.SYM,A2_DOS33.SYM2}

	if use libretro; then
		exeinto /usr/$(get_libdir)/libretro
		doexe "${BUILD_DIR}"/source/frontends/libretro/applewin_libretro.so
		insinto /usr/share/libretro/info
		doins "${BUILD_DIR}"/source/frontends/libretro/applewin_libretro.info
	fi

	use sdl && make_desktop_entry sa2 "AppleWin (SDL)" applications-games "Game;Emulator"
	use qt6 && make_desktop_entry qapple "AppleWin (Qt)" applications-games "Game;Emulator"

	einstalldocs
}
