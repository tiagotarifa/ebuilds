# media-gfx/epsonscan2-non-free-plugin

Proprietary, **binary-only** plugins for Epson Scan 2, distributed by Epson under the
EPSON license. They are optional: install them through
[`media-gfx/epsonscan2[wifi]`](../epsonscan2/README.md), which pulls this package in.

[← Back to the overlay](../../README.md)

## What it provides

| Component | Purpose |
|---|---|
| `es2netif` | network (Wi-Fi/Ethernet) interface — required for network scanning |
| `es2intif` + interpreter libraries | USB interpreter required by some models (product IDs 0x013a–0x013f, 0x0142, 0x014a) |
| `dtrplugin`, `ddeplugin`, `fitplugin`, `libesimp2.so`, … | image-processing filters (deskew, text enhancement, etc.) |
| `epsonscan2-ocr` | OCR engine used for automatic page rotation |
| `/usr/share/epsonscan2/*.bin` | scanner firmware files |

Files are installed under `/usr/lib64/epsonscan2/`, `/usr/lib64/epsonscan2-ocr/`,
`/usr/libexec/epsonscan2-ocr/` and `/usr/share/`, where `media-gfx/epsonscan2` looks for
them. Only amd64 is supported.

## Installation

1. The bundle is fetch-restricted. Download the "rpm" / "64bit" Epson Scan 2 bundle,
   `epsonscan2-bundle-6.7.80.0.x86_64.rpm.tar.gz`, from
   <https://support.epson.net/linux/en/epsonscan2.php> with a web browser and copy it into
   your DISTDIR:

   ```sh
   cp epsonscan2-bundle-6.7.80.0.x86_64.rpm.tar.gz "$(portageq distdir)"/
   ```

   The package is versioned after the plugin itself (1.0.0.6-1), which is identical in
   several Epson Scan 2 bundles. If Epson only offers a newer bundle, adjust `BUNDLE` in the
   ebuild and regenerate the Manifest (`ebuild <file>.ebuild manifest`).

2. Accept the keyword and the license, then enable the plugin through `wifi`:

   ```sh
   cat >> /etc/portage/package.accept_keywords/epsonscan2 <<'EOF'
   media-gfx/epsonscan2 ~amd64
   media-gfx/epsonscan2-non-free-plugin ~amd64
   EOF
   echo "media-gfx/epsonscan2-non-free-plugin EPSON" >> /etc/portage/package.license
   echo "media-gfx/epsonscan2 wifi" >> /etc/portage/package.use/epsonscan2
   emerge -av media-gfx/epsonscan2
   ```

See the [epsonscan2 README](../epsonscan2/README.md#network-scanners-usewifi) for network
scanner discovery and manual IP configuration.

## Files in `/tmp`

`es2netif` has two hardcoded paths in `/tmp` that must be usable by every user, or network
scanning breaks for all users but the one who scanned first:

- it appends a debug log to `/tmp/test.txt` and crashes if it can't open it;
- it shares `/tmp/epsonWork/interrupt.dat` with `media-gfx/epsonscan2` for IPC.

The package installs `/usr/lib/tmpfiles.d/epsonscan2-non-free-plugin.conf`, which creates
`/tmp/test.txt` (mode 0666) and `/tmp/epsonWork` (mode 1777) owned by root at boot and on
installation. The log is readable by all users; it only holds protocol debug messages.

## Runtime dependencies

`dev-libs/libltdl`, `virtual/libusb:1` and `media-gfx/epsonscan2`.
