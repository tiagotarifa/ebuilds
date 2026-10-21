# CLAUDE.md

Gentoo overlay (repo name `tiagotarifa`) for Epson Scan 2. Public repository: see
[Privacy](#privacy) before committing anything.

## Layout

- `media-gfx/epsonscan2/` — Epson Scan 2 built from source (CMake). Patches in `files/`,
  applied in the order of the `PATCHES` array.
- `media-gfx/epsonscan2-non-free-plugin/` — Epson's binary plugin, unpacked from the RPM
  bundle with `rpm.eclass`.
- `metadata/layout.conf` — `thin-manifests = true`: Manifests only hold `DIST` lines.
- Each package has a `README.md` for end users; the root `README.md` links to them.
- `fontes/` (git-ignored) holds the distfiles; they can't be committed or redistributed.

## Ebuild conventions

- EAPI 8, `KEYWORDS="~amd64"` (plugin: `-* ~amd64`).
- Both distfiles are `RESTRICT="fetch"`: Epson's CDN rejects automated downloads (HTTP 403),
  so `pkg_nofetch` explains the manual download.
- Patch files are named `${P}-<topic>.patch` and start with a short paragraph explaining
  why. Generate them with `git diff` from a scratch git tree of the sources (see the
  `bump-epsonscan2` skill), never by hand.
- USE flags: `gui` (Qt6 front-end; off → SANE driver only, no Qt) and `wifi` (default off;
  `PDEPEND` on the proprietary plugin plus `net-dns/avahi[dbus]`). Without `wifi` everything
  installed must stay free software.
- The build must respect user flags and work with `-O3 -march=native -pipe`; never re-add
  hardcoded `-O`/`-std` flags.

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

## Testing

Use the `test-ebuild` skill: it runs `ebuild … clean install` as a normal user with a
private `PORTAGE_TMPDIR` under `.work/` (git-ignored) and `DISTDIR=fontes/`. Test every USE
combination and check QA notices. Never use `sudo`/`su`/root and never run a real
`emerge` (only `emerge -p`, which asks for permission); installing is left to the user.

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
