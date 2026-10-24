# media-video/shotcut

[Shotcut](https://www.shotcut.org/), the free and open source video editor based on the
MLT framework, version 26.9.27. The Gentoo repository carries an older release; this one
is a version bump of the Gentoo ebuild, and Portage picks it because its version is
higher.

[← Back to the overlay](../../README.md)

## USE flags

| Flag | Default | Description |
|---|---|---|
| `vulkan` | off | Use Vulkan instead of VA-API for hardware video decoding (Settings → Video Mode → hardware decoder). Requires `media-video/ffmpeg[vulkan]`. |
| `debug` | off | Debug build. |
| `test` | off | Build and run the unit tests. |

## Installation

```sh
echo "media-video/shotcut::tiagotarifa ~amd64" >> /etc/portage/package.accept_keywords/shotcut
emerge -av media-video/shotcut::tiagotarifa
```

Shotcut needs `media-libs/mlt` with `ffmpeg frei0r jack opengl qt6 sdl xml`; `emerge` will
ask for those USE flags if they are missing. `qt6` is not required by the Gentoo ebuild, but
without it the text, crop, GPS and audio visualization filters are missing. It works with
MLT 7.36 or newer; some of the newest filters only show up with a recent MLT.

## Credits

Based on the `media-video/shotcut` ebuild from the Gentoo repository. Shotcut is
© Meltytech, LLC, licensed under GPL-3+.
