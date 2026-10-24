# CLAUDE.md

Gentoo overlay (repo name `tiagotarifa`) for Epson Scan 2, Brave and AppleWin. Public repository: see
[Privacy](#privacy) before committing anything.

## Layout

- `media-gfx/epsonscan2/` — Epson Scan 2 built from source (CMake). Patches in `files/`,
  applied in the order of the `PATCHES` array.
- `media-gfx/epsonscan2-non-free-plugin/` — Epson's binary plugin, unpacked from the RPM
  bundle with `rpm.eclass`.
- `www-client/brave-browser/` — Brave built from source (brave-core + Chromium). `files/` has
  the launcher, `/etc/brave-browser/default`, the support-file generator and patches.
- `games-emulation/applewin/` — AppleWin (Apple II emulator), CMake, snapshot of
  audetto/AppleWin `master`; git submodules (imgui, imgui_club, imgui-filebrowser, QHexView)
  are separate `SRC_URI` tarballs pinned to the commits the snapshot references.
- `metadata/layout.conf` — `thin-manifests = true`: Manifests only hold `DIST` lines.
- Each package has a `README.md` for end users; the root `README.md` links to them.
- `fontes/` (git-ignored) holds the distfiles; they can't be committed or redistributed.
  Never upload distfiles or sources that are already downloadable elsewhere (GitHub
  releases included).

## Ebuild conventions

- EAPI 8, `KEYWORDS="~amd64"` (plugin: `-* ~amd64`).
- Never change a committed ebuild in place: copy it to the next revision (`foo-1.0.ebuild` →
  `foo-1.0-r1.ebuild`, `-r1` → `-r2`; see the
  [devmanual](https://devmanual.gentoo.org/eclass-reference/ebuild/index.html)) and edit the
  copy. Keep only the three most recent ebuilds of each package; delete older ones, plus
  patches in `files/` that only they use. Patches are named after `${P}`, which has no
  revision, so revisions share them.
- Both Epson distfiles are `RESTRICT="fetch"`: Epson's CDN rejects automated downloads (HTTP 403),
  so `pkg_nofetch` explains the manual download.
- Patch files are named `${P}-<topic>.patch` and start with a short paragraph explaining
  why. Generate them with `git diff` from a scratch git tree of the sources (see the
  `bump-epsonscan2` skill), never by hand.
- epsonscan2 USE flags: `gui` (Qt6 front-end; off → SANE driver only, no Qt) and `wifi` (default off;
  `PDEPEND` on the proprietary plugin plus `net-dns/avahi[dbus]`). Without `wifi` everything
  installed must stay free software.
- The Epson builds must respect user flags and work with `-O3 -march=native -pipe`; never
  re-add hardcoded `-O`/`-std` flags. Brave follows `www-client/chromium` instead: user
  flags are filtered unless `USE=custom-cflags`.

## Upstream facts that are easy to miss

- `EPSON_INSTALL_PATH` (`/usr/$(get_libdir)/epsonscan2/`) is compiled in; the SANE backend
  `dlopen`s `libepsonscan2.so` from there, and plugins are looked up in `non-free-exec/`.
- `-DEPSON_OCR_INSTALL_PATH=` is mandatory or `SearchablePDFPlugin.cpp` fails to build.
- For network devices `Engine.cpp` (`FindConnectionType`) only proceeds if
  `/usr/libexec/epsonscan2-ocr/ocr-engine-getrotate` (shipped by the plugin) exists.
- Network discovery runs `avahi-browse -r -p -t _scanner._tcp` (`NetFinder.cpp`); manual IPs
  are read from `~/.epsonscan2/Network/epsonscan2.conf` (`[Network]`, one IP per line).
- Debug logging (`CommonUtility/DbgLog.cpp`) is enabled only when `/tmp/epson` exists.
- The prebuilt `es2netif` always appends to `/tmp/test.txt` and segfaults when `fopen`
  fails (file owned by another user, `fs.protected_regular`); the plugin's `tmpfiles.d`
  entry creates it 0666 as root.
- `/tmp/epsonWork/interrupt.dat` is the `ftok` key of the IPC between `es2netif` and
  `ipcInterfaceImpl.cpp`: keep that path. Temporary images no longer go there: the
  `per-user-workdir` patch makes `ES_GetWorkTempPath()` return a `mkdtemp()` folder.
- Upstream sources use CRLF line endings in many files; patches keep them, so edit them with
  tools that preserve `\r`.
- SANE's dll backend needs `/usr/lib*/sane/libsane-epsonscan2.so.1` symlinks (`dosym`).

## Brave facts that are easy to miss

- No source tarball exists: `src_unpack` runs brave-core's `pnpm run init --no-history`
  (gclient). `PROPERTIES="live"` is what gives `src_unpack` network access under
  `network-sandbox` (Portage `doebuild.py`, `_doebuild_spawn`); every later phase must work
  offline. Only the pinned Node 24 tarball is in `SRC_URI`.
- The prepared tree (`src/` without VCS data, `pnpm/`, `pnpm-store/`) is cached in
  `${PORTAGE_ACTUAL_DISTDIR}/brave-browser-src/${P}-src.tar.zst` (the phases' `DISTDIR`
  is a shadow dir; `addwrite` as in `git-r3`); when present `src_unpack` only extracts it.
  Never add it to `SRC_URI`/Manifest nor upload it. Anything `src_unpack` adds that later
  phases need must live under `WORKDIR` and go into the tarball (`brave_node_env`).
- brave-core's `devEngines` demand Node 24 and pnpm ≥ 11.11 (hard failure otherwise); both
  are pinned at the top of the ebuild (`NODE_VER`, `PNPM_VER`), with `CHROMIUM_VER` checked
  against `brave/package.json`.
- gclient runs `git reset --force` on the repository it finds at `src/`: keep
  `GIT_CEILING_DIRECTORIES` set, or it climbs into an enclosing checkout (it once picked up
  this overlay from `.work/`).
- Brave patches `chrome/VERSION` to `156.<brave version>`; the Chromium version lives in
  `brave/package.json` (`config.projects.chrome.tag`). `init` writes it before `src_prepare`
  creates `.env`, and outside CI/release builds it zeroes the patch number, hence the
  `ignore_patch_version_number=false` `.env` in `src_unpack`.
- The channel comes from `CHROME_VERSION_EXTRA` (the launcher exports `stable`; unset means
  "unknown"). Non-official builds append `-Development` to the profile directory.
- Before `gn gen`, `pnpm run build` copies Brave's branding over Chromium's; the ebuild runs
  `build.ts Release --prepare_only` for that, configured by `brave/.env`
  (`is_brave_release_build=1` selects the release logos, `is_brave_origin_branded`).
- GN args mirror `brave/build/commands/lib/buildArgs.ts`. Official builds assert that
  `brave_services_key`, `service_key_search`, `service_key_stt` and `service_key_aichat` are
  non-empty; they are private, so the ebuild uses `BRAVE_*` env vars or a placeholder.
- Not optional despite having buildflags (referenced unconditionally): commander, containers,
  custom NTP background, local AI, Request-OTR, Widevine (`brave.widevine_opted_in` is read
  unguarded: `-widevine` builds crash at startup). VPN is Windows/Mac/Android only.
  `system-icu` breaks (`icudata`/`copy_icudata` missing from the unbundle shim).
- `brave/vendor/web-discovery-project/.git/HEAD` is a build input; keep it when deleting VCS
  data.
- Hidden network use during the build (masked by caches in a normal `$HOME`): wasm-pack's
  `cargo metadata` (private `CARGO_HOME` with `offline` + vendored crates) and pnpm's
  `packageManager` switch in web-discovery-project (`pnpm_config_pm_on_fail=ignore`).
- Cargo builds C/C++ for Brave's wasm tools with `$CC`/`$CXX`: GCC at `-O3` breaks binaryen,
  so the ebuild always exports upstream's clang. The unbundle toolchain appends `$CFLAGS`
  after a target's own flags, so a user `-march` would override Skia's per-file
  `-march=x86-64-v4`: with `custom-cflags`, `files/redirect-cc.py` (the GN `cc_wrapper`)
  puts `-march`/`-mtune`/`-mcpu` right after the compiler instead.
- A system LLVM/Rust toolchain fails at `gn gen` (Chromium 156 builds Rust std and crubit
  bindings itself); there is no `system-toolchain` flag.
- Telemetry is blocked by `${P}-disable-telemetry.patch`, which makes Brave Origin's
  "telemetry off" branches (`IS_BRAVE_ORIGIN_BRANDED`) unconditional and hard-codes the
  gates (`P3AService::IsP3AEnabled()`, the referral/SERP usage-ping checks, crash upload
  URL); there is no `stats` flag. `${P}-unofficial-build-notice.patch` adds the
  "Unofficial build" line to `brave://settings/help`. Rebase both on every bump.
- Re-running later phases of an existing build dir reuses `temp/environment`: delete it (and
  `.setuped`) for ebuild edits to take effect.

## AppleWin facts that are easy to miss

- The source is audetto/AppleWin, not the seanshpark/AppleWinLinux fork (a Raspberry Pi 1
  hack: hardcoded `-march=armv6`, CPU forced to 65C02).
- With every `BUILD_*` frontend option OFF upstream builds all of them, hence the
  `REQUIRED_USE`.
- `ROOT_PATH` (resources relative to the executable, i.e. `g_sProgramDir` with the debugger
  `.SYM` files) is compiled in; the `resource-path` patch sets it to `../share/applewin`.
  It's only used by `common2` (every frontend but `qapple`), as is `testyaml`.
- `resource/Cousine-Regular.ttf` is a symlink into the imgui submodule and is embedded by
  every frontend, so the imgui tarball is needed even with `-sdl`.
- `--log` always writes `/tmp/AppleWin.log` (`Log.cpp`).

## Testing

Use the `test-ebuild` skill: it runs `ebuild … clean install` as a normal user with a
private `PORTAGE_TMPDIR` under `.work/` (git-ignored) and `DISTDIR=fontes/`. Test every USE
combination and check QA notices. Never use `sudo`/`su`/root and never run a real
`emerge` (only `emerge -p`, which asks for permission); installing is left to the user.
Brave's `pnpm run init` fails with a `PORTAGE_TMPDIR` under `.work/`: `tsx` creates a Unix
socket in `${T}` and the path exceeds 108 characters. Use a short one such as
`/var/tmp/bt-a` for that test.

## Privacy

This repository is published. Never commit data about the maintainer's machine, network or
employer:
- local paths;
- hostnames, IP addresses or the test scanner's model;
- local user names;
- personal or work e-mail addresses.

Use generic examples such as `192.168.0.10`. The following public identities are allowed:
- the maintainer's address in `metadata.xml` and the git author;
- the authors credited in upstream/third-party patches;
- the `Co-Authored-By` trailer. Machine-specific notes go in
`CLAUDE.local.md` (git-ignored). Commits use the repository's local `user.email`; check it
with `git config --local user.email` before committing.

## Skills

- `test-ebuild` — build and QA-check an ebuild without root.
- `bump-epsonscan2` — update to a new Epson Scan 2 release and rebase the patches.
