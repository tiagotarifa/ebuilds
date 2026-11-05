# games-engines/openbor

[OpenBOR](https://github.com/DCurrent/openbor), a royalty-free, sprite-based side-scrolling
game engine descended from Senile Team's Beats of Rage. It is made for beat 'em up games but
its script engine handles other genres too. Only the engine is installed: games (modules) are
`.pak` files, found for example on the [ChronoCrash](https://www.chronocrash.com/) forums.

Packaged version: `4.0.7533`, i.e. upstream's GitHub release "OpenBOR <major>.<minor>
Build <build>" (tag `v<build>`).

[← Back to the overlay](../../README.md)

## USE flags

None. Upstream's Linux build always includes OpenGL (loaded at run time), Ogg Vorbis music
and WebM video support.

## Installation

```sh
echo "games-engines/openbor ~amd64" >> /etc/portage/package.accept_keywords/openbor
emerge -av games-engines/openbor
```

## Usage

```sh
openbor                  # menu listing the .pak files in the Paks folder
openbor game.pak         # start a module directly
```

- OpenBOR keeps everything in the current directory, so the `openbor` launcher runs it from
  `${XDG_DATA_HOME:-~/.local/share}/openbor/`, where the first run creates `Paks/`, `Saves/`,
  `Logs/` and `ScreenShots/`. Put your `.pak` files in `Paks/`.
- Logs (`Logs/OpenBorLog.txt`) are the first place to look when a module fails to load.

## License

BSD-3-Clause (OpenBOR Team, Senile Team).
