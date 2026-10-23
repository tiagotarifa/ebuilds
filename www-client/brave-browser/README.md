# www-client/brave-browser

[Brave](https://brave.com/), the privacy-focused Chromium-based browser, **built from
source** (brave-core + Chromium), with each optional Brave feature selectable through USE
flags. Stable channel only.

## How the sources are obtained

Brave publishes no source tarball: its tree is assembled by brave-core's `pnpm run init`
(a `gclient` sync of Chromium plus every dependency, Brave's patches and upstream's prebuilt
Clang/Rust toolchains). The ebuild runs that itself in `src_unpack`, so:

- it is marked `PROPERTIES="live"`: that is what lets Portage give `src_unpack` network
  access even with `FEATURES=network-sandbox`. Configure, compile and install run offline;
- the only regular distfile is a pinned Node.js 24 tarball (brave-core's tooling requires
  Node 24 and pnpm 11; both are private to the build and never installed);
- the first build downloads the sources (several GB, shallow clones) and caches the
  prepared tree, without VCS data, in
  `DISTDIR/brave-browser-src/brave-browser-<version>-src.tar.zst` (about 7 GB; that
  much extra free space is needed in `DISTDIR`). Later builds of the same version unpack
  it and need no network. It is kept in a subdirectory so `eclean-dist` doesn't remove it:
  delete old versions by hand, and delete the current one to force a new download. If
  `DISTDIR` isn't writable the build goes on without caching. The tarball contains
  third-party code under many licences: don't redistribute it.

The Brave tag (`v${PV}`), the Chromium version and the Node/pnpm versions are pinned in the
ebuild, and the ebuild checks that brave-core asks for the expected Chromium.

## Requirements

- amd64 (upstream's toolchain is only shipped for x86-64);
- about **100 GB** free in `PORTAGE_TMPDIR` and 16 GB of RAM (24 GB with `USE=official`);
- a few hours: the download, then a full Chromium build.

## USE flags

Defaults follow upstream's Linux build.

| Flag | Default | Effect |
|---|---|---|
| `ads` | on | Brave Ads |
| `ai-chat` | on | Leo, the AI assistant |
| `education` | on | Onboarding/education pages |
| `news` | on | Brave News on the New Tab Page |
| `origin` | off | Brave Origin branding: stripped-down Brave (requires the feature flags marked in `REQUIRED_USE` to be off) |
| `page-graph` | on | PageGraph research instrumentation |
| `playlist` | on | Playlist |
| `psst` | on | Privacy Settings Selection Tool |
| `rewards` | on | Brave Rewards (needs `ads`) |
| `speedreader` | on | Speedreader |
| `talk` | on | Brave Talk |
| `tor` | on | Private windows with Tor |
| `traffic-control` | on | Per-container traffic control |
| `wallet` | on | Brave Wallet (crypto/Web3) |
| `wayback` | on | Wayback Machine suggestions on 404 pages |
| `web-discovery` | on | Web Discovery Project (opt-in at runtime) |
| `official` | on | Upstream's release optimisations (ThinLTO, CFI) |
| `X`, `wayland` | on | Ozone platforms; with both, the launcher picks one per session |
| `cups`, `kerberos`, `pulseaudio`, `screencast`, `vaapi`, `qt6`, `gtk4` | | Same meaning as in `www-client/chromium` |
| `proprietary-codecs`, `rar`, `hangouts` | | Same meaning as in `www-client/chromium` |
| `chromedriver` | off | Install `brave-chromedriver` |
| `system-harfbuzz`, `system-zstd` | off | Use the system library instead of the bundled one |
| `custom-cflags` | off | Build with your CFLAGS/LDFLAGS, `-march=native` included (code built for a specific CPU level and selected at runtime keeps its own `-march`; Rust is not affected). Unsupported |
| `debug` | off | DCHECKs (configurable at runtime) |

Brave's Commander, Containers, custom New Tab backgrounds, local AI models, Request-OTR and
Widevine support are always built: other code references them unconditionally (Brave still
asks before downloading the Widevine CDM). VPN does not exist on Linux.

The build always uses upstream's prebuilt Clang and Rust: Chromium 156 builds the Rust
standard library and its C++ bindings itself, which the system Rust can't provide.

With `USE=rar` (the default) the package is under the non-free `unRAR` licence, as in
`www-client/chromium`: accept it (`www-client/brave-browser unRAR` in
`/etc/portage/package.license`) or disable the flag.

Extra GN arguments can be passed with `EXTRA_GN` (e.g. in `/etc/portage/env`).

## Telemetry

This build is not supported by Brave Software, so it doesn't report to them. The
`disable-telemetry` patch blocks in code, whatever the settings, policies or `Local State`
say:

- P3A (privacy-preserving product analytics);
- the usage ping, plus the referral and search-metrics pings tied to it (the stats updater
  isn't even built);
- crash report uploads (and the dialog that asks for them).

Their toggles are gone from `brave://settings/privacy` and from the welcome page, and
`brave://settings/help` says the build is unofficial.

Brave's servers are still contacted for things the browser needs or that you turn on: Shields
list and component updates, the feature configuration (variations), and services such as
Brave News, Search, Rewards or Wallet. Web Discovery only sends data if you opt in (or
build with `USE=-web-discovery`). Sponsored images and ads report anonymous ad events
(`USE=-ads` removes them).

## Service keys

Some Brave services authenticate with keys that Brave keeps private, and brave-core refuses
official builds without them. Without your own keys the ebuild uses a placeholder, and those
services (e.g. Brave Sync, Leo, speech-to-text) may not work. If you have keys, export them
for the build (for example through `/etc/portage/env/brave-browser.conf` plus
`/etc/portage/package.env`):

```sh
BRAVE_SERVICES_KEY="..."
BRAVE_SERVICE_KEY_SEARCH="..."
BRAVE_SERVICE_KEY_STT="..."
BRAVE_SERVICE_KEY_AICHAT="..."
```

## Running

- Installed in `/usr/lib64/brave-browser`; start it with `brave-browser` (or `brave`).
- System-wide flags: `BRAVE_FLAGS` in `/etc/brave-browser/default`; per-user flags: one or
  more per line in `~/.config/brave-flags.conf`; `BRAVE_USER_FLAGS` in the environment
  replaces the system default.
- The profile lives in `~/.config/BraveSoftware/Brave-Browser`, the same as the official
  packages (`Brave-Origin` with `USE=origin`; with `USE=-official` upstream adds a
  `-Development` suffix).

## Credits

Based on the `www-client/chromium` ebuild from the Gentoo repository; packaging details
follow the binary ebuild of
[another-brave-overlay](https://github.com/falbrechtskirchinger/another-brave-overlay)
by Florian Albrechtskirchinger.
