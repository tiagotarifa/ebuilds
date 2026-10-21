---
name: test-ebuild
description: Build, install into the image directory and QA-check an ebuild of this overlay as a normal user (no root), for every relevant USE combination. Use after changing an ebuild, a patch or a Manifest, or when asked to test/validate a package.
---

# Test an ebuild without root

Root is not available: never use `sudo`, `su`, `doas` or a real `emerge`. Everything below
writes only to `.work/` inside the repository (git-ignored).

## 1. Prepare the environment

```sh
source .claude/skills/test-ebuild/scripts/portage-user-env.sh
```

It sets `PORTAGE_TMPDIR`, `DISTDIR` (pointing at `fontes/`, read-only use),
`PORTAGE_REPOSITORIES` and disables the root-only features. It must be sourced, not
executed (executing it fails on purpose). Source it in the same shell command as the
`ebuild` calls, since shell state does not persist between tool calls.

If a distfile is missing from `fontes/`, stop and ask the user to download it with a
browser (Epson's CDN returns 403 to scripts); `pkg_nofetch` in the ebuild says from where.

## 2. Build and install into the image

For each USE combination that matters (epsonscan2: `-gui -wifi`, `gui`, `wifi`):

```sh
cd media-gfx/<pkg>
USE="<flags>" CFLAGS="-O3 -march=native -pipe" CXXFLAGS="-O3 -march=native -pipe" \
	ebuild <pkg>-<ver>.ebuild clean install > "$EBUILD_TEST_DIR/<pkg>-<flags>.log" 2>&1
```

Do not run `ebuild … manifest` here: the fetch phase must verify the distfile against the
committed Manifest. A digest mismatch means the distfile in `fontes/` differs from the one
the Manifest was made from — report it instead of regenerating the Manifest. Only
`bump-epsonscan2` (a deliberate version or distfile change) regenerates Manifests.

Then inspect, stripping colour codes:

```sh
sed 's/\x1b\[[0-9;]*m//g' "$EBUILD_TEST_DIR/<pkg>-<flags>.log" | grep -A6 "QA Notice\| ERROR"
```

- Fix every QA notice that comes from the package. The only expected one is an unresolved
  soname for a dependency that isn't installed on the test machine (see step 4).
- Treat `-Wreturn-type`, `-Waggressive-loop-optimizations` and similar "severe warnings"
  as bugs: with `-O3` they cause real miscompilations. Patch them.
- Check the installed tree in `$PORTAGE_TMPDIR/portage/media-gfx/<pkg>-<ver>/image/` and
  `readelf -d` (NEEDED, RUNPATH = `/usr/lib64/epsonscan2/`) on the libraries.

## 3. Check metadata and dependency resolution

`emerge` always asks for permission (see `.claude/settings.json`); only ever run it with `-p`.

```sh
portageq metadata / ebuild media-gfx/<pkg>-<ver>::epsonscan2 IUSE RDEPEND PDEPEND
ACCEPT_KEYWORDS="~amd64" ACCEPT_LICENSE="*" USE="<flags>" emerge -pv media-gfx/<pkg>::epsonscan2
```

## 4. Dependencies that aren't installed

If a build dependency is missing on the test machine and can't be emerged without root,
build it from its upstream source into a prefix under `.work/` and inject it **only for
the test** (`CXXFLAGS="… -I<prefix>/include"`, `LDFLAGS="… -L<prefix>/lib64"`). Never
change the ebuild to point at it.

## 5. Runtime tests

The installed image has `/usr/...` paths compiled in, so it can't run from `image/`. To
exercise the SANE backend, configure the sources with CMake directly and
`-DCMAKE_INSTALL_PREFIX=$EBUILD_TEST_DIR/root`, install, then:

```sh
mkdir -p "$EBUILD_TEST_DIR/root/sane.d" "$EBUILD_TEST_DIR/root/lib64/sane"
echo epsonscan2 > "$EBUILD_TEST_DIR/root/sane.d/dll.conf"
ln -sf ../epsonscan2/libsane-epsonscan2.so "$EBUILD_TEST_DIR/root/lib64/sane/libsane-epsonscan2.so.1"
HOME="$EBUILD_TEST_DIR/home" SANE_CONFIG_DIR="$EBUILD_TEST_DIR/root/sane.d" \
	LD_LIBRARY_PATH="$EBUILD_TEST_DIR/root/lib64/sane" scanimage -L
```

Network scanning additionally needs the plugin's `non-free-exec/` copied into the prefix
and the hardcoded `/usr/libexec/epsonscan2-ocr` path (see CLAUDE.md) redirected in a
throw-away copy of the sources. Machine-specific test hardware is described in
`CLAUDE.local.md`, if present. Anything that needs the real `/usr` install (udev rules,
simple-scan) must be reported to the user as untested.

## 6. Report

Summarise per USE combination: build result, QA notices, what was tested at runtime and
what remains for the user to verify after installing as root.
