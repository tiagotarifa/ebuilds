# epsonscan2 Gentoo overlay

Gentoo overlay for **Epson Scan 2**, the Epson scanner driver for Linux, built from
source with a SANE backend usable from simple-scan, xsane, `scanimage`, etc.

## Packages

| Package | Description |
|---|---|
| [`media-gfx/epsonscan2`](media-gfx/epsonscan2/README.md) | Epson Scan 2 built from source: SANE backend (driver-only build possible) and optional Qt6 front-end. Free software. |
| [`media-gfx/epsonscan2-non-free-plugin`](media-gfx/epsonscan2-non-free-plugin/README.md) | Proprietary, binary-only Epson plugins (network scanning, some USB models, image processing). Optional, pulled in by `media-gfx/epsonscan2[wifi]`. |

## Adding the overlay

With `app-eselect/eselect-repository`:

```sh
eselect repository add epsonscan2 git https://github.com/tiagotarifa/ebuilds.git
emaint sync -r epsonscan2
```

Or manually, in `/etc/portage/repos.conf/epsonscan2.conf`:

```ini
[epsonscan2]
location = /var/db/repos/epsonscan2
sync-type = git
sync-uri = https://github.com/<user>/<repo>.git
auto-sync = yes
```

Both packages are keyworded `~amd64` and their distfiles are fetch-restricted (Epson
does not allow automated downloads); see each package's README for the details.

## Credits

The ebuilds are based on the ones in the
[slonko overlay](https://github.com/gringus/slonko) by Marcin Deranek. Several crash
fixes are by Hubert Figuière.

Epson Scan 2 is © SEIKO EPSON CORPORATION. The driver sources are licensed under
LGPL-2.1+ (udev rules GPL-3+); the plugin is distributed under the EPSON license.
