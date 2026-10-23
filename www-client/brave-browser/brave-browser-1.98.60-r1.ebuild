# Copyright 2009-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Brave built from source. Based on the www-client/chromium ebuild from the
# Gentoo repository; packaging details follow the binary ebuild of
# another-brave-overlay (Florian Albrechtskirchinger).
#
# Brave publishes no source tarball: the tree is assembled by brave-core's
# `pnpm run init` (gclient sync of Chromium and every DEPS entry, Brave's
# patches, and upstream's prebuilt Clang/Rust). src_unpack runs it, which is
# why this ebuild is PROPERTIES="live": Portage only allows network access in
# src_unpack for live ebuilds. Everything after src_unpack builds offline.
#
# The result is cached as a tarball in DISTDIR/brave-browser-src (see
# brave_src_tarball); later builds of the same version unpack it instead of
# downloading everything again, and need no network at all.

EAPI=8

CHROMIUM_LANGS="af am ar az bg bn bs ca cs da de el en-GB es es-419 et fa fi fil fr
	gu he hi hr hu id it ja ka kk km kn ko lo lt lv mk ml mn mr ms my nb nl pl
	pt-BR pt-PT ro ru si sk sl sq sr sr-Latn sv sw ta te th tr uk ur uz vi zh-CN
	zh-TW"

PYTHON_COMPAT=( python3_{11..14} )
PYTHON_REQ_USE="xml(+)"

inherit check-reqs chromium-2 desktop flag-o-matic ninja-utils pax-utils
inherit python-any-r1 xdg

# brave-core's devEngines: Node 24 and pnpm >= 11.11 (hard failure otherwise)
NODE_VER="24.22.1"
PNPM_VER="11.28.7"
CHROMIUM_VER="156.0.8078.48"

DESCRIPTION="Brave web browser, built from source"
HOMEPAGE="https://brave.com/ https://github.com/brave/brave-core"
SRC_URI="https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.xz"
S="${WORKDIR}/src"

# Chromium's licences (www-client/chromium) plus Brave's MPL-2.0
LICENSE="Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
LICENSE+=" rar? ( unRAR )"
SLOT="0"
KEYWORDS="~amd64"

# Chromium features
IUSE_CHROMIUM="+X chromedriver +cups custom-cflags debug gtk4 hangouts kerberos +official
	+proprietary-codecs +pulseaudio qt6 +rar +screencast selinux system-harfbuzz system-zstd
	+vaapi +wayland"
# Brave features (brave-core buildflags); defaults match upstream's Linux build.
# Commander, Containers, custom NTP backgrounds, local AI and Request-OTR are
# referenced unconditionally by other code and can't be turned off.
IUSE_BRAVE="+ads +ai-chat +education +news origin +page-graph +playlist +psst
	+rewards +speedreader +talk +tor +traffic-control +wallet +wayback +web-discovery"
IUSE="${IUSE_CHROMIUM} ${IUSE_BRAVE}"

PROPERTIES="live"
# Proprietary codecs and prebuilt toolchains; the cached sources stay local
RESTRICT="bindist mirror test"

REQUIRED_USE="
	|| ( X wayland )
	screencast? ( wayland )
	rewards? ( ads )
	origin? ( !ads !ai-chat !education !news !playlist !psst !rewards !speedreader
		!talk !tor !wallet !wayback !web-discovery )
"

COMMON_X_DEPEND="
	x11-libs/libXcomposite:=
	x11-libs/libXcursor:=
	x11-libs/libXdamage:=
	x11-libs/libXfixes:=
	>=x11-libs/libXi-1.6.0:=
	x11-libs/libXrandr:=
	x11-libs/libXrender:=
	x11-libs/libXtst:=
	x11-libs/libxshmfence:=
"

COMMON_DEPEND="
	system-harfbuzz? ( >=media-libs/harfbuzz-3:0=[icu(-)] )
	system-zstd? ( >=app-arch/zstd-1.5.5:= )
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-arch/bzip2:=
	dev-libs/expat:=
	dev-libs/glib:2
	dev-libs/nspr:=
	>=dev-libs/nss-3.26:=
	>=media-libs/alsa-lib-1.0.19:=
	media-libs/fontconfig:=
	>=media-libs/freetype-2.11.0-r1:=
	media-libs/mesa:=[gbm(+),X?,wayland?]
	media-video/pipewire:=
	net-misc/curl[ssl]
	sys-apps/dbus:=
	sys-apps/pciutils:=
	virtual/udev
	x11-libs/cairo:=
	x11-libs/gdk-pixbuf:2
	x11-libs/libxkbcommon:=
	x11-libs/pango:=
	cups? ( >=net-print/cups-1.3.11:= )
	kerberos? ( virtual/krb5 )
	pulseaudio? ( media-libs/libpulse:= )
	qt6? ( dev-qt/qtbase:6[gui,widgets] )
	vaapi? ( >=media-libs/libva-2.7:=[X?,wayland?] )
	wayland? (
		dev-libs/libffi:=
		dev-libs/wayland:=
	)
	X? (
		${COMMON_X_DEPEND}
		x11-base/xorg-proto:=
		x11-libs/libX11:=
		x11-libs/libxcb:=
		x11-libs/libXext:=
	)
"
RDEPEND="${COMMON_DEPEND}
	app-misc/ca-certificates
	|| (
		x11-libs/gtk+:3[X?,wayland?]
		gui-libs/gtk:4[X?,wayland?]
	)
	qt6? ( dev-qt/qtbase:6[X?,wayland?] )
	virtual/ttf-fonts
	x11-misc/xdg-utils
	selinux? ( sec-policy/selinux-chromium )
"
DEPEND="${COMMON_DEPEND}
	gtk4? ( gui-libs/gtk:4[X?,wayland?] )
	!gtk4? ( x11-libs/gtk+:3[X?,wayland?] )
"
BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/setuptools[${PYTHON_USEDEP}]
	')
	app-alternatives/ninja
	app-arch/zstd
	dev-lang/perl
	>=dev-util/gperf-3.2
	dev-vcs/git
	net-misc/curl
	sys-apps/hwdata
	>=sys-devel/bison-2.4.3
	sys-devel/flex
	virtual/pkgconfig
	qt6? ( dev-qt/qtbase:6 )
"

python_check_deps() {
	python_has_version "dev-python/setuptools[${PYTHON_USEDEP}]"
}

pre_build_checks() {
	# Shallow checkout (~30 GB) plus the build directory
	local CHECKREQS_DISK_BUILD="100G"
	local CHECKREQS_MEMORY="16G"
	use official && CHECKREQS_MEMORY="24G"
	check-reqs_${EBUILD_PHASE_FUNC}
}

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && pre_build_checks
}

pkg_setup() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		pre_build_checks
		python-any-r1_pkg_setup

		# GN chooses LTO itself (ThinLTO for official builds)
		filter-lto
	fi

	chromium_suid_sandbox_check_kernel_config
}

# The cached source tree: src/ as left by `pnpm run init` without VCS data,
# plus pnpm and its store (pnpm/, pnpm-store/), relative to WORKDIR. It lives
# in a subdirectory of the real DISTDIR (the one Portage gives the phases only
# holds SRC_URI files) so that eclean-dist leaves it alone, like git-r3's
# git3-src. Delete it to download the sources again.
brave_src_tarball() {
	echo "${PORTAGE_ACTUAL_DISTDIR:-${DISTDIR}}/brave-browser-src/${P}-src.tar.zst"
}

# Node, pnpm and pnpm's store, for src_unpack and the build phases
brave_node_env() {
	export PATH="${WORKDIR}/pnpm/bin:${WORKDIR}/node-v${NODE_VER}-linux-x64/bin:${PATH}"
	export npm_config_cache="${T}/npm-cache"
	export pnpm_config_store_dir="${WORKDIR}/pnpm-store"
}

brave_create_tarball() {
	local tarball=$(brave_src_tarball)
	local dir=${tarball%/*}

	addwrite "${dir}"
	if ! mkdir -p "${dir}" || [[ ! -w ${dir} ]]; then
		ewarn "Can't write to ${dir}: the sources won't be cached."
		return
	fi

	einfo "Caching the sources in ${tarball} ..."
	local paths=( src pnpm )
	[[ -d ${WORKDIR}/pnpm-store ]] && paths+=( pnpm-store )
	# Written aside and renamed when complete, so an interrupted build never
	# leaves a truncated tarball behind.
	if tar -C "${WORKDIR}" --sort=name --owner=0 --group=0 --numeric-owner \
		-I "zstd -T0 -10" -cf "${tarball}.tmp" "${paths[@]}" &&
		mv "${tarball}"{.tmp,}
	then
		elog "Sources cached in ${tarball}; delete it to download them again"
		elog "and delete old versions by hand."
	else
		rm -f "${tarball}.tmp"
		ewarn "Failed to cache the sources in ${tarball} (out of space?)."
	fi
}

src_unpack() {
	unpack node-v${NODE_VER}-linux-x64.tar.xz
	brave_node_env

	local tarball=$(brave_src_tarball)
	if [[ -f ${tarball} ]]; then
		einfo "Unpacking the cached sources from ${tarball} ..."
		tar -C "${WORKDIR}" -I zstd -xf "${tarball}" ||
			die "Failed to unpack ${tarball}; delete it to download the sources again"
		return
	fi

	# gclient resets whatever repository it finds at src/: never let git
	# climb out of the build directory into an enclosing checkout.
	export GIT_CEILING_DIRECTORIES="${WORKDIR%/*}"
	export DEPOT_TOOLS_UPDATE=0 DEPOT_TOOLS_METRICS=0

	einfo "Installing pnpm ${PNPM_VER} ..."
	npm install -g --prefix "${WORKDIR}/pnpm" "pnpm@${PNPM_VER}" ||
		die "Failed to install pnpm"

	einfo "Fetching brave-core v${PV} ..."
	git clone --depth 1 -b "v${PV}" https://github.com/brave/brave-core.git "${S}/brave" ||
		die "Failed to clone brave-core"
	# init writes the version into chrome/VERSION; outside CI and release
	# builds it zeroes the patch number (1.98.0). src_prepare rewrites .env.
	echo "ignore_patch_version_number=false" > "${S}"/brave/.env || die

	# Chromium, DEPS, toolchains, node modules and Brave's patches. This
	# downloads several GB and takes a while.
	einfo "Fetching Chromium ${CHROMIUM_VER} and dependencies (pnpm run init) ..."
	pushd "${S}/brave" > /dev/null || die
	local chromium_tag
	chromium_tag=$(node -p 'require("./package.json").config.projects.chrome.tag') || die
	[[ ${chromium_tag} == "${CHROMIUM_VER}" ]] ||
		die "brave-core v${PV} wants Chromium ${chromium_tag}, update CHROMIUM_VER"
	pnpm run init --target_os=linux --target_arch=x64 --no-history ||
		die "pnpm run init failed"
	popd > /dev/null || die

	# VCS data takes several GB and nothing after this point needs it, except
	# web-discovery-project/.git/HEAD, a build input of brave_extension.
	einfo "Removing VCS data ..."
	find "${S}" -path "${S}/brave/vendor/web-discovery-project/.git" -prune \
		-o -name .git -prune -exec rm -rf {} + || die

	brave_create_tarball
}

src_prepare() {
	local PATCHES=(
		"${FILESDIR}"/${P}-no-linux-installer.patch
		"${FILESDIR}"/${P}-disable-telemetry.patch
		"${FILESDIR}"/${P}-unofficial-build-notice.patch
	)
	default

	# What `pnpm run build` does before `gn gen` (--prepare_only): copy Brave's
	# branding (strings, logos, icons) over Chromium's. The .env file is
	# brave-core's build configuration; is_brave_release_build selects the
	# release logos instead of the development ones.
	cat > brave/.env <<- EOF || die
		is_brave_release_build=1
		is_brave_origin_branded=$(usex origin true false)
	EOF
	pushd brave > /dev/null || die
	(
		brave_node_env
		node build/commands/scripts/build.ts Release --prepare_only \
			--target_os=linux --target_arch=x64 > "${T}"/branding.log
	) || die "Failed to apply Brave's branding (see ${T}/branding.log)"
	popd > /dev/null || die

	# Allow building against system libraries in official builds
	sed -i 's/OFFICIAL_BUILD/GOOGLE_CHROME_BUILD/' \
		tools/generate_shim_headers/generate_shim_headers.py || die

	local unbundle=()
	use system-zstd && unbundle+=( zstd )
	if [[ ${#unbundle[@]} -gt 0 ]]; then
		build/linux/unbundle/replace_gn_files.py --system-libraries "${unbundle[@]}" ||
			die "Failed to replace GN files for system libraries"
	fi
}

# The environment brave-core's build scripts give gn and ninja
# (build/commands/lib/config.ts, defaultOptions): Brave's patched Python
# scripts import modules from brave/script and friends.
brave_build_env() {
	local p pythonpath=()
	for p in brave/script tools/grit/grit/extern brave/vendor/requests build third_party/depot_tools; do
		pythonpath+=( "${S}/${p}" )
	done
	export PYTHONPATH=$(IFS=:; echo "${pythonpath[*]}")
	export PYTHONUNBUFFERED=1 TARGET_ARCH=x64
	export RUSTUP_HOME="${S}/third_party/rust-toolchain"
	export PATH="${S}/third_party/rust-toolchain/bin:${PATH}"

	# Upstream's clang, used by the unbundle toolchain (USE=custom-cflags) and
	# by the C/C++ that cargo builds for Brave's wasm tools: GCC miscompiles
	# binaryen's bundled LLVM code (undefined llvm::sys::fs references at -O3).
	local llvm_bin="${S}/third_party/llvm-build/Release+Asserts/bin"
	export AR="${llvm_bin}/llvm-ar" NM="${llvm_bin}/llvm-nm"
	export CC="${llvm_bin}/clang" CXX="${llvm_bin}/clang++"

	# Upstream's prebuilt cargo (used to build Brave's vendored wasm tools)
	# links against Debian's libcurl-gnutls.so.4. Gentoo's libcurl has no
	# symbol versioning, so it satisfies it under that name.
	local shim="${T}/libcurl-gnutls"
	if [[ ! -e ${shim}/libcurl-gnutls.so.4 ]]; then
		mkdir -p "${shim}" || die
		ln -s "${BROOT}/usr/$(get_libdir)/libcurl.so.4" "${shim}"/libcurl-gnutls.so.4 || die
	fi
	export LD_LIBRARY_PATH="${shim}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

	# wasm-pack runs `cargo metadata` without the vendored-sources config that
	# the following `cargo build --frozen` gets, and would reach crates.io.
	# Its only user (brave_account's opaque_ke) is vendored here.
	export CARGO_HOME="${T}/cargo-home"
	mkdir -p "${CARGO_HOME}" || die
	cat > "${CARGO_HOME}"/config.toml <<- EOF || die
		[net]
		offline = true
		[source.crates-io]
		replace-with = "brave-wasm-vendor"
		[source.brave-wasm-vendor]
		directory = "${S}/brave/third_party/wasm/vendor"
	EOF

	# brave/script/web_discovery_project.py runs pnpm. Its package.json asks
	# for another pnpm release (packageManager), which pnpm would download.
	brave_node_env
	export pnpm_config_pm_on_fail=ignore
}

# GN boolean named ${2} from USE flag ${1}
gn_use() {
	echo "${2}=$(usex ${1} true false)"
}

src_configure() {
	brave_build_env
	python_export_utf8_locale || die "Brave builds require a UTF-8 locale."

	export TMPDIR="${WORKDIR}/temp"
	mkdir -p -m 755 "${TMPDIR}" || die

	addpredict /dev/dri/ #nowarn

	local flag cpu_flags=()
	if use custom-cflags; then
		# Upstream's clang ($CC, from brave_build_env) rejects some GCC flags
		strip-unsupported-flags
		# Several components (Skia, codecs) build specific code paths with their
		# own -march/-m* flags and detect the CPU at runtime. The unbundle
		# toolchain appends CFLAGS after a target's flags, so e.g. -march=native
		# on a CPU without AVX-512 would break Skia's x86-64-v4 code: the
		# compiler wrapper puts the user's CPU flags first instead.
		for flag in ${CFLAGS}; do
			[[ ${flag} == -march=* || ${flag} == -mtune=* || ${flag} == -mcpu=* ]] &&
				cpu_flags+=( "${flag}" )
		done
	else
		replace-flags "-Os" "-O2"
		strip-flags
		# Debug info section overflows without component build
		filter-flags "-g*"
	fi
	filter-flags "-march*" "-mtune*" "-mcpu*" -mno-mmx -mno-sse2 -mno-ssse3 \
		-mno-sse4.1 -mno-avx -mno-avx2 -mno-fma -mno-fma4 -mno-xop -mno-sse4a

	local myconf_gn=(
		# What brave-core's build scripts pass (build/commands/lib/buildArgs.ts)
		'import("//brave/build/args/brave_defaults.gni")'
		'import("//brave/build/args/blink_platform_defaults.gni")'
		'import("//brave/build/args/desktop_defaults.gni")'
		"$(usex origin \
			'import("//brave/build/args/brave_origin/branding_defaults.gni")' \
			'import("//brave/build/args/branding_defaults.gni")')"
		'brave_channel=""'
		'target_os="linux"'
		'target_cpu="x64"'
		"is_official_build=$(usex official true false)"
		"is_debug=false"
		"is_component_build=false"
		"skip_signing=true"
		"enable_cdm_host_verification=false"
		"enable_update_notifications=false"
		"enable_updater=false"
		"chrome_pgo_phase=0"
		"symbol_level=0"
		"enable_hangout_services_extension=$(usex hangouts true false)"

		# Distribution build, as in www-client/chromium
		"blink_enable_generated_code_formatting=false"
		"dcheck_always_on=$(usex debug true false)"
		"dcheck_is_configurable=$(usex debug true false)"
		"disable_fieldtrial_testing_config=true"
		"enable_nocompile_tests=false"
		"enable_pseudolocales=false"
		"fatal_linker_warnings=false"
		"treat_warnings_as_errors=false"
		"use_sysroot=false"

		# Unofficial build: no usage ping nor crash-report prompt
		# (see ${P}-disable-telemetry.patch)
		"enable_brave_stats_updater=false"
		"enable_crash_dialog=false"

		# Media
		"enable_widevine=true"
		"proprietary_codecs=$(usex proprietary-codecs true false)"
		"ffmpeg_branding=\"$(usex proprietary-codecs Chrome Chromium)\""
		"enable_platform_hevc=$(usex proprietary-codecs true false)"
		"enable_hevc_parser_and_hw_decoder=$(usex proprietary-codecs true false)"
		"safe_browsing_use_unrar=$(usex rar true false)"

		# Desktop integration
		"gtk_version=$(usex gtk4 4 3)"
		"link_pulseaudio=$(usex pulseaudio true false)"
		"ozone_auto_platforms=false"
		"ozone_platform_headless=true"
		"ozone_platform_wayland=$(usex wayland true false)"
		"ozone_platform_x11=$(usex X true false)"
		"ozone_platform=\"$(usex wayland wayland x11)\""
		"rtc_use_pipewire=$(usex screencast true false)"
		"rtc_link_pipewire=$(usex screencast true false)"
		"use_cups=$(usex cups true false)"
		"use_kerberos=$(usex kerberos true false)"
		"use_pulseaudio=$(usex pulseaudio true false)"
		"use_qt5=false"
		"use_qt6=$(usex qt6 true false)"
		"use_system_libffi=$(usex wayland true false)"
		"use_system_harfbuzz=$(usex system-harfbuzz true false)"
		"use_vaapi=$(usex vaapi true false)"
		"use_xkbcommon=true"

		# Brave features
		"is_brave_origin_branded=$(usex origin true false)"
		"$(gn_use ads enable_brave_ads)"
		"$(gn_use ai-chat enable_ai_chat)"
		"$(gn_use education enable_brave_education)"
		"$(gn_use news enable_brave_news)"
		"$(gn_use page-graph enable_brave_page_graph)"
		"$(gn_use playlist enable_playlist)"
		"$(gn_use psst enable_psst)"
		"$(gn_use rewards enable_brave_rewards)"
		"$(gn_use speedreader enable_speedreader)"
		"$(gn_use talk enable_brave_talk)"
		"$(gn_use tor enable_tor)"
		"$(gn_use traffic-control enable_traffic_control)"
		"$(gn_use wallet enable_brave_wallet)"
		"$(gn_use wayback enable_brave_wayback_machine)"
		"$(gn_use web-discovery enable_web_discovery_native)"
		"$(gn_use web-discovery enable_web_discovery)"
	)

	if use qt6; then
		myconf_gn+=( "moc_qt6_path=\"${EPREFIX}/usr/$(get_libdir)/qt6/libexec\"" )
	fi

	# Brave's service keys are private. brave-core refuses official builds
	# without them, so official builds fall back to a placeholder; users can
	# pass their own through the environment (see README.md).
	local key
	for key in brave_services_key service_key_search service_key_stt service_key_aichat; do
		local var="BRAVE_${key^^}"
		var=${var/BRAVE_BRAVE_/BRAVE_}
		if [[ -n ${!var} ]]; then
			myconf_gn+=( "${key}=\"${!var}\"" )
		elif use official; then
			myconf_gn+=( "${key}=\"unset\"" )
		fi
	done

	if use custom-cflags; then
		# The bundled toolchain ignores CFLAGS unless built through the
		# unbundle toolchain, which reads CC/CXX/CFLAGS from the environment
		# (set to upstream's clang in brave_build_env).
		append-ldflags -fuse-ld=lld
		myconf_gn+=(
			'custom_toolchain="//build/toolchain/linux/unbundle:default"'
			'host_toolchain="//build/toolchain/linux/unbundle:default"'
		)
	fi

	# Compile brave/chromium_src overrides in place of the Chromium sources they
	# replace, like upstream's siso redirect_cc handler, and put the user's CPU
	# flags (USE=custom-cflags) before each target's own flags.
	cp "${FILESDIR}"/redirect-cc.py "${T}"/ || die
	local wrapper="${EPYTHON} ${T}/redirect-cc.py"
	[[ ${#cpu_flags[@]} -gt 0 ]] && wrapper+=" ${cpu_flags[*]} --"
	myconf_gn+=( "cc_wrapper=\"${wrapper}\"" )

	einfo "Configuring Brave ..."
	set -- buildtools/linux64/gn gen --args="${myconf_gn[*]}${EXTRA_GN:+ ${EXTRA_GN}}" out/Release
	echo "$@"
	"$@" || die "Failed to configure Brave"
}

src_compile() {
	# Final link uses lots of file descriptors.
	ulimit -n 2048

	brave_build_env

	eninja -C out/Release brave chrome_sandbox $(usev chromedriver)

	pax-mark m out/Release/brave

	if use chromedriver; then
		mv out/Release/chromedriver{.unstripped,} || die
	fi

	rm -f out/Release/locales/*.pak.info || die

	"${EPYTHON}" "${FILESDIR}"/generate-support-files.py \
		--installdir "${EPREFIX}/usr/$(get_libdir)/${PN}" \
		--branding "$(usex origin brave-origin brave-browser)" ||
		die "Failed to generate support files"
}

src_install() {
	local BRAVE_HOME="/usr/$(get_libdir)/${PN}"

	exeinto "${BRAVE_HOME}"
	doexe out/Release/brave out/Release/chrome_crashpad_handler
	newexe out/Release/chrome_sandbox chrome-sandbox
	fperms 4755 "${BRAVE_HOME}"/chrome-sandbox
	use chromedriver && doexe out/Release/chromedriver

	local ozone_auto_session=false
	use X && use wayland && ozone_auto_session=true
	sed -e "s|@BRAVE_HOME@|${EPREFIX}${BRAVE_HOME}|" \
		-e "s|@OZONE_AUTO_SESSION@|${ozone_auto_session}|" \
		-e "s|@PROFILE_DIR@|$(usex origin Brave-Origin Brave-Browser)$(usex official "" -Development)|" \
		"${FILESDIR}"/brave-browser-launcher.sh > "${T}"/brave-browser || die
	doexe "${T}"/brave-browser
	dosym "${BRAVE_HOME}"/brave-browser /usr/bin/brave-browser
	dosym brave-browser /usr/bin/brave
	use chromedriver && dosym "${BRAVE_HOME}"/chromedriver /usr/bin/brave-chromedriver

	insinto /etc/brave-browser
	newins "${FILESDIR}"/brave-browser.default default

	pushd out/Release/locales > /dev/null || die
	chromium_remove_language_paks
	popd > /dev/null || die

	insinto "${BRAVE_HOME}"
	doins out/Release/*.bin out/Release/*.pak
	(
		shopt -s nullglob
		local files=( out/Release/*.so out/Release/*.so.[0-9] )
		[[ ${#files[@]} -gt 0 ]] && doins "${files[@]}"
	)
	doins out/Release/icudtl.dat
	doins -r out/Release/locales out/Release/MEIPreload
	doins out/Release/vk_swiftshader_icd.json

	local size dir theme=$(usex origin brave_origin brave)
	for size in 16 24 32 48 64 128 256; do
		case ${size} in
			16|32) dir=brave/app/theme/default_100_percent/${theme} ;;
			*) dir=brave/app/theme/${theme} ;;
		esac
		newicon -s ${size} "${dir}/product_logo_${size}.png" ${PN}.png
	done

	domenu out/Release/${PN}.desktop
	insinto /usr/share/gnome-control-center/default-apps
	doins out/Release/${PN}.xml
	insinto /usr/share/metainfo
	doins out/Release/${PN}.appdata.xml
	doman out/Release/${PN}.1
}

pkg_postinst() {
	xdg_pkg_postinst

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Command-line flags can be set in /etc/brave-browser/default (system-wide)"
		elog "or in ~/.config/brave-flags.conf (per user)."
		elog
		elog "This is an unofficial build: usage statistics (P3A, usage ping) and"
		elog "crash reports to Brave are blocked."
		if use official; then
			elog
			elog "This build does not carry Brave's private service keys: Brave Sync,"
			elog "Leo, speech-to-text and other key-protected services may not work."
		fi
	fi
}
