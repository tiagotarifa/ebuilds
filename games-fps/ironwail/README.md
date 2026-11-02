# games-fps/ironwail

[Ironwail](https://github.com/andrei-drexler/ironwail), a fork of the QuakeSpasm Quake engine
focused on high performance: culling and lightmap updates run on the GPU and the renderer is
decoupled from the server, so even huge modern maps run at very high frame rates. It adds a
Mods menu, mouse-driven menus, Q64-style HUDs, real-time palettization and plays the 2021
re-release content with no setup.

Needs an OpenGL 4.3 GPU (compute shaders).

[← Back to the overlay](../../README.md)

## USE flags

| Flag | Default | Description |
|---|---|---|
| `curl` | on | Download the add-ons of the 2021 re-release from inside the game. |
| `mp3` | on | MP3 music (libmpg123). |
| `vorbis` | on | Ogg Vorbis music. |
| `flac` | off | FLAC music. |
| `opus` | off | Opus music. |
| `mikmod`, `modplug`, `xmp` | off | Tracker music (`.mod`, `.s3m`, `.it`, `.xm`, `.umx`); any one is enough. |

WAV music is always supported.

## Installation

```sh
echo "games-fps/ironwail ~amd64" >> /etc/portage/package.accept_keywords/ironwail
emerge -av games-fps/ironwail
```

## Usage

The game data is not included: you need your own copy of Quake (`id1/pak0.pak` and
`id1/pak1.pak`; the shareware `pak0.pak` alone also works). Ironwail looks for it, in order:

1. in the directory given with `-basedir`: `ironwail -basedir ~/games/quake`;
2. in the current directory and its parents;
3. in `~/.ironwail` (copy `id1/` to `~/.ironwail/id1/`);
4. in a Steam installation of Quake (`~/.steam/steam`, also the Flatpak one), including the
   2021 re-release.

Settings, saves and screenshots go to `~/.ironwail/`. Mods are directories next to `id1/`;
pick them in the Mods menu or with `-game <dir>`. `ironwail.pak` (default config and menu
graphics) is installed in `/usr/share/ironwail/`.

## License

Ironwail is GPL-2+. The bundled jsmn is MIT, stb_image/stb_image_write are public domain and
miniz is under the Unlicense.
