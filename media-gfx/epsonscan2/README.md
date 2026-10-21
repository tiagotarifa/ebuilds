# media-gfx/epsonscan2

Epson Scan 2 (6.7.92.0) built from the official Epson source package. It provides:

- the SANE backend `epsonscan2`, so Epson scanners work with simple-scan, xsane,
  `scanimage` and any other SANE frontend;
- optionally, the Epson Scan 2 graphical front-end (`/usr/bin/epsonscan2`), ported from
  Qt5 to Qt6.

[← Back to the overlay](../../README.md)

## USE flags

| Flag | Default | Description |
|---|---|---|
| `gui` | off | Build the Qt6 front-end (`epsonscan2`, `detectalert`). Without it only the SANE driver is installed and there is no Qt dependency. Note: the `desktop` profiles enable `gui` globally, so use `-gui` in `package.use` for a driver-only build. |
| `wifi` | off | Network (Wi-Fi/Ethernet) scanning. Pulls in the proprietary [`media-gfx/epsonscan2-non-free-plugin`](../epsonscan2-non-free-plugin/README.md) and `net-dns/avahi` for scanner discovery. |

With `-wifi`, everything installed is free software.

## Installation

1. The source package is fetch-restricted. Download `epsonscan2-6.7.92.0-1.src.tar.gz`
   ("Epson Scan 2" → source) from
   <https://support.epson.net/linux/en/epsonscan2.php> with a web browser and copy it
   into your DISTDIR:

   ```sh
   cp epsonscan2-6.7.92.0-1.src.tar.gz "$(portageq distdir)"/
   ```

2. Accept the keyword and choose the USE flags:

   ```sh
   echo "media-gfx/epsonscan2 ~amd64" >> /etc/portage/package.accept_keywords/epsonscan2
   echo "media-gfx/epsonscan2 -gui"   >> /etc/portage/package.use/epsonscan2
   emerge -av media-gfx/epsonscan2
   ```

   For network scanners, use `wifi` and follow the
   [plugin instructions](../epsonscan2-non-free-plugin/README.md) as well.

3. Add your user to the `scanner` group (the udev rules also grant access to the user of
   the active seat via `uaccess`), replug the scanner and test:

   ```sh
   usermod -aG scanner <user>
   scanimage -L
   simple-scan
   ```

## Network scanners (`USE=wifi`)

Network scanners are discovered with `avahi-browse`, so `avahi-daemon` must be running:

```sh
systemctl enable --now avahi-daemon   # systemd
rc-update add avahi-daemon default && rc-service avahi-daemon start   # OpenRC
```

If a scanner is not discovered, add its IP address to
`~/.epsonscan2/Network/epsonscan2.conf` (per user; with `USE=gui`,
`epsonscan2 --set-ip <ip>` writes this file):

```ini
[Network]
192.168.0.10
```

The scanner then appears as `epsonscan2:networkscanner:esci2:network:<ip>`.

## Without the plugin

Without `media-gfx/epsonscan2-non-free-plugin` (`-wifi`):

- network scanning is not available;
- USB models with product IDs 0x013a–0x013f, 0x0142 and 0x014a do not work (they need
  the `es2intif` interpreter);
- image-processing features such as automatic deskew, text enhancement and OCR-based
  rotation are unavailable.

## Changes from upstream

Built with the user's `CFLAGS`/`CXXFLAGS` (tested with `-O3 -march=native -pipe`, GCC 16,
CMake 4, Boost 1.90). Patches in [`files/`](files/):

| Patch | Purpose |
|---|---|
| `cmake` | CMake 4 compatibility, respect user flags, C++17, no writes outside DESTDIR, `BUILD_GUI`/`BUILD_SCANSDK` options |
| `unbundle` | use system libharu and zlib instead of the bundled copies |
| `boost` | Boost ≥ 1.87 compatibility |
| `gcc` | C++17 (`std::ptr_fun` removal) and a GCC ≥ 15 template error |
| `udev-desktop` | `scanner` group + `uaccess` instead of world-writable devices; desktop file cleanup |
| `Fix-*`, `Use-XDG-open-*` | crash fixes by Hubert Figuière (via the slonko overlay) |
| `qt6` | GUI port from Qt5 to Qt6 |
| `return-type` | fix undefined behaviour (missing return values) in the GUI |
| `per-user-workdir` | private temporary folder per process (upstream's shared `/tmp/epsonWork` made scanning crash for every user but the first) and no crash when it can't be created |
