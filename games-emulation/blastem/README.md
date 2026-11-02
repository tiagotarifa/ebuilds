# games-emulation/blastem

[BlastEm](https://www.retrodev.com/blastem/), a fast and highly accurate Sega Genesis/Mega
Drive emulator by Michael Pavone. Version 1.0.0 also emulates the Sega/Mega CD, 32X, Pico,
Master System, Game Gear, SG-1000/SC-3000 and ColecoVision, and has a built-in debugger and a
GDB remote stub.

The source is the `v1.0.0` tag of upstream's Mercurial repository.

[← Back to the overlay](../../README.md)

## USE flags

| Flag | Default | Description |
|---|---|---|
| `gtk` | off | Use the GTK+ 3 file chooser instead of the built-in one. Also needs `use_native_filechooser on` in the configuration (or the setting in the menu). GTK is loaded at run time. |

## Installation

```sh
echo "games-emulation/blastem ~amd64" >> /etc/portage/package.accept_keywords/blastem
emerge -av games-emulation/blastem
```

## Usage

```sh
blastem                  # GUI: load a ROM from the menu
blastem game.bin         # start a ROM directly
blastem -h               # all options
```

- `Esc` opens the menu, where most settings can be changed.
- The configuration lives in `~/.config/blastem/blastem.cfg` (created from
  `/usr/share/blastem/default.cfg`); saves and save states go to `~/.local/share/blastem/`.
- Sega CD, 32X and ColecoVision games need BIOS images, which are not included. Relative
  paths are looked up in `/usr/share/blastem/` (Sega CD, ColecoVision) or in the current
  directory (32X), so set absolute paths in the `system` section of
  `~/.config/blastem/blastem.cfg`:

  ```
  system {
  	scd_bios_us /path/to/bios/us_scd2_930601.bin
  	scd_bios_eu /path/to/bios/eu_mcd2_930601.bin
  	scd_bios_jp /path/to/bios/jp_mcd2_921222.bin
  	s32x_68k_bios /path/to/bios/32X_G_BIOS.bin
  	s32x_main_bios /path/to/bios/32X_M_BIOS.bin
  	s32x_sub_bios /path/to/bios/32X_S_BIOS.bin
  	coleco_bios_path /path/to/bios/colecovision.rom
  }
  ```
- The old ROM-based menu (`menu.bin`) and the TMSS boot screen (`tmss.md`) are not installed:
  building them needs the `vasm` assembler, which Gentoo doesn't have. The default GUI does
  not use them.
- The debugger opens a terminal running `/usr/libexec/blastem/termhelper`.

## License

BlastEm is GPL-3+. The bundled Nuklear is MIT or public domain, `gamecontrollerdb.txt` (SDL
game controller mappings) is zlib-licensed.
