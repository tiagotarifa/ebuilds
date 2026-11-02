# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake desktop xdg

DESCRIPTION="High-performance Quake engine, a fork of QuakeSpasm"
HOMEPAGE="https://github.com/andrei-drexler/ironwail"
SRC_URI="https://github.com/andrei-drexler/ironwail/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

# Engine: GPL-2+; jsmn: MIT; stb_image, stb_image_write: public-domain;
# miniz: Unlicense
LICENSE="GPL-2+ MIT public-domain Unlicense"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+curl flac mikmod modplug +mp3 opus +vorbis xmp"

DEPEND="
	media-libs/libsdl2[opengl,video]
	virtual/opengl
	curl? ( net-misc/curl )
	flac? ( media-libs/flac:= )
	mikmod? ( media-libs/libmikmod )
	modplug? ( media-libs/libmodplug )
	mp3? ( media-sound/mpg123-base )
	opus? ( media-libs/opusfile )
	vorbis? ( media-libs/libvorbis )
	xmp? ( media-libs/libxmp )
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}"/${P}-codec-options.patch
	"${FILESDIR}"/${P}-datadir.patch
)

DOCS=( README.md Quakespasm.txt Quakespasm-Music.txt )
HTML_DOCS=( Quakespasm.html )

src_prepare() {
	# Nothing in it needs the pre-3.10 behaviour
	sed -i 's/^cmake_minimum_required(VERSION 3\.7)$/cmake_minimum_required(VERSION 3.10)/' \
		CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_DISABLE_FIND_PACKAGE_CURL=$(usex !curl)
		-DENABLE_USERDIRS=ON
		-DIRONWAIL_DATADIR="${EPREFIX}"/usr/share/${PN}
		-DUSE_CODEC_FLAC=$(usex flac)
		-DUSE_CODEC_MIKMOD=$(usex mikmod)
		-DUSE_CODEC_MODPLUG=$(usex modplug)
		-DUSE_CODEC_MP3=$(usex mp3)
		-DUSE_CODEC_OPUS=$(usex opus)
		-DUSE_CODEC_VORBIS=$(usex vorbis)
		-DUSE_CODEC_XMP=$(usex xmp)
	)
	cmake_src_configure
}

src_install() {
	# No install target upstream
	dobin "${BUILD_DIR}"/${PN}

	insinto /usr/share/${PN}
	doins Quake/${PN}.pak

	newicon Misc/QuakeSpasm_512.png ${PN}.png
	make_desktop_entry ${PN} Ironwail ${PN} "Game;ActionGame;Shooter"

	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Ironwail needs the Quake game data (id1/pak0.pak, id1/pak1.pak), which"
		elog "is not included. Either copy the id1 directory to ~/.ironwail/id1, run"
		elog "ironwail from your Quake directory, or pass it with:"
		elog "  ironwail -basedir /path/to/quake"
		elog "A Steam installation of Quake (including the 2021 re-release) is"
		elog "detected automatically."
	fi
}
