# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..15} )

inherit desktop python-any-r1 toolchain-funcs xdg

DESCRIPTION="Fast and accurate Sega Genesis/Mega Drive emulator"
HOMEPAGE="https://www.retrodev.com/blastem/"
SRC_URI="https://www.retrodev.com/repos/blastem/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-v${PV}"

# BlastEm: GPL-3+; Nuklear: MIT or public domain; gamecontrollerdb.txt: ZLIB
LICENSE="GPL-3+ || ( MIT public-domain ) ZLIB"
SLOT="0"
KEYWORDS="~amd64"
IUSE="gtk"

DEPEND="
	media-libs/glew:0=[-egl-only]
	media-libs/libsdl2[joystick,opengl,sound,video]
	virtual/opengl
	virtual/zlib:=
	gtk? ( x11-libs/gtk+:3 )
"
# The UI font is looked up with fc-match; GTK is dlopen()ed for the file chooser
RDEPEND="
	${DEPEND}
	media-libs/fontconfig
"
BDEPEND="
	${PYTHON_DEPS}
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}"/${P}-flags.patch
)

DOCS=( CHANGELOG README )

src_prepare() {
	default

	# Use the system zlib (HOST_ZLIB=1)
	rm -r zlib || die
	sed -i 's|#include "zlib/zlib.h"|#include <zlib.h>|' \
		chd.h event_log.c event_log.h png.c system.c zip.c || die

	# Generates the CPU cores (m68k.c, z80.c, sh2.c, upd78k2.c)
	python_fix_shebang cpu_dsl.py
}

src_compile() {
	tc-export CC PKG_CONFIG

	local myemakeargs=(
		CPU=x86_64
		DATA_PATH="${EPREFIX}"/usr/share/${PN}
		EXTRA_CFLAGS="${CFLAGS}"
		EXTRA_LDFLAGS="${LDFLAGS}"
		HOST_ZLIB=1
		OPT=
	)
	# NO_FILE_CHOOSER is broken upstream (filechooser_nulll.o)
	use gtk || myemakeargs+=( GTKFLAGS= CHOOSER=nuklear_ui/filechooser_null.o )

	emake "${myemakeargs[@]}" blastem termhelper
}

src_install() {
	dobin blastem

	insinto /usr/share/${PN}
	doins -r default.cfg gamecontrollerdb.txt images rom.db shaders systems.cfg

	# Debugger terminal helper, looked up in DATA_PATH
	exeinto /usr/libexec/${PN}
	doexe termhelper
	dosym -r /usr/libexec/${PN}/termhelper /usr/share/${PN}/termhelper

	make_desktop_entry ${PN} BlastEm applications-games "Game;Emulator"

	einstalldocs
}
