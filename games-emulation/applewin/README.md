# games-emulation/applewin

AppleWin, the Apple II emulator, from its Linux port
([audetto/AppleWin](https://github.com/audetto/AppleWin)). It emulates the Apple II,
II Plus, //e and enhanced //e and clones such as the Pravets and TK3000, with Mockingboard,
Disk II, hard disk, Super Serial Card, Uthernet and other cards, plus a symbolic debugger.

The package is a snapshot of upstream's `master` branch (1.32.0.0, commit `a1e20c0`):
upstream has no recent tags.

[← Back to the overlay](../../README.md)

## USE flags

| Flag | Default | Description |
|---|---|---|
| `sdl` | on | `sa2`: SDL2 + Dear ImGui frontend, with settings windows and the debugger. The main frontend. |
| `qt6` | off | `qapple`: Qt6 frontend. |
| `ncurses` | off | `applen`: terminal frontend (reads the keyboard through libevdev). |
| `libretro` | off | `applewin_libretro.so` core for RetroArch and other libretro frontends, in `/usr/lib64/libretro`. |
| `network` | on | Uthernet network card emulation through libslirp. |

At least one frontend must be enabled.

## Installation

```sh
echo "games-emulation/applewin ~amd64"  >> /etc/portage/package.accept_keywords/applewin
echo "sys-libs/zlib minizip"            >> /etc/portage/package.use/applewin
echo "games-emulation/applewin qt6"     >> /etc/portage/package.use/applewin   # optional
emerge -av games-emulation/applewin
```

`sys-libs/zlib[minizip]` provides the zip support (`.zip` disk images); alternatively use
`sys-libs/minizip-ng[compat]`. With `qt6`, `dev-qt/qtmultimedia` pulls in Qt Quick 3D through
its default `qml` flag; set `dev-qt/qtmultimedia -qml` if you don't need it.

## Usage

```sh
sa2 --d1 game.dsk        # disk in slot 6, drive 1
sa2 --help               # all options
```

- The configuration lives in `~/.config/applewin/applewin.yaml`; screenshots go to
  `~/Pictures`.
- The debugger symbol tables are installed in `/usr/share/applewin/bin/`.
- `--log` always writes to `/tmp/AppleWin.log`.
- No disk images are installed. The Apple II and peripheral ROMs are built into the
  emulator.

## License

AppleWin is GPL-2+. The bundled Dear ImGui, imgui_club, imgui-filebrowser, QHexView and
libretro-common are MIT; the Cousine font is Apache-2.0. The Apple ROMs built into the
binaries are copyrighted by Apple and not freely redistributable, so the package is
`RESTRICT="bindist"`.
