# tiagotarifa Gentoo overlay

Gentoo overlay with:

- **Epson Scan 2**, the Epson scanner driver for Linux, built from source with a SANE
  backend usable from simple-scan, xsane, `scanimage`, etc.;
- **Brave**, the privacy-focused web browser, built from source with its optional
  features selectable through USE flags;
- **AppleWin**, the Apple II emulator (Linux port), with SDL2, Qt6, ncurses and libretro
  frontends.

> [!CAUTION]
> **USE AT YOUR OWN RISK.** This is a personal overlay, not part of Gentoo and not
> endorsed by Epson or Brave Software. Whatever you install from it is your own
> responsibility.

> [!WARNING]
> **NO WARRANTY.** These ebuilds and patches are provided "as is", without warranty of any
> kind, express or implied. They may fail to build, break your system or the installed
> software, and may stop being maintained at any time.

## Packages

| Package | Description |
|---|---|
| [`media-gfx/epsonscan2`](media-gfx/epsonscan2/README.md) | Epson Scan 2 built from source: SANE backend (driver-only build possible) and optional Qt6 front-end. Free software. |
| [`media-gfx/epsonscan2-non-free-plugin`](media-gfx/epsonscan2-non-free-plugin/README.md) | Proprietary, binary-only Epson plugins (network scanning, some USB models, image processing). Optional, pulled in by `media-gfx/epsonscan2[wifi]`. |
| [`www-client/brave-browser`](www-client/brave-browser/README.md) | Brave web browser (stable) built from source; the ebuild downloads the sources itself while building. |
| [`games-emulation/applewin`](games-emulation/applewin/README.md) | AppleWin Apple II emulator (Linux port), snapshot of upstream `master`. |

## Adding the overlay

With `app-eselect/eselect-repository`:

```sh
eselect repository add tiagotarifa git https://github.com/tiagotarifa/ebuilds.git
emaint sync -r tiagotarifa
```

Or manually, in `/etc/portage/repos.conf/tiagotarifa.conf`:

```ini
[tiagotarifa]
location = /var/db/repos/tiagotarifa
sync-type = git
sync-uri = https://github.com/tiagotarifa/ebuilds.git
auto-sync = yes
```

All packages are keyworded `~amd64`. The Epson distfiles are fetch-restricted (Epson
does not allow automated downloads); Brave's sources are downloaded during the first build
and cached in `DISTDIR`.
See each package's README for the details.

## Credits

The Epson Scan 2 ebuilds are based on the ones in the
[slonko overlay](https://github.com/gringus/slonko) by Marcin Deranek. Several crash
fixes are by Hubert Figuière.

Epson Scan 2 is © SEIKO EPSON CORPORATION. The driver sources are licensed under
LGPL-2.1+ (udev rules GPL-3+); the plugin is distributed under the EPSON license.

The Brave ebuild is based on `www-client/chromium` from the Gentoo repository and on
[another-brave-overlay](https://github.com/falbrechtskirchinger/another-brave-overlay)
by Florian Albrechtskirchinger. Brave is © Brave Software, licensed under MPL-2.0.

AppleWin is by Tom Charlesworth, Michael Pohoreski and the AppleWin team, licensed under
GPL-2+; the Linux port is by Andrea Odetti.
