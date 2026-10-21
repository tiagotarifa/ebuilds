---
name: bump-epsonscan2
description: Update media-gfx/epsonscan2 to a new Epson Scan 2 source release (rebasing and regenerating the patches) or media-gfx/epsonscan2-non-free-plugin to a new Epson bundle. Use when the user provides a new epsonscan2 tarball/bundle or asks to bump a version.
---

# Bump epsonscan2 / epsonscan2-non-free-plugin

Distfiles live in `fontes/` (git-ignored). Epson blocks scripted downloads, so if the new
file is not there, ask the user to download it with a browser from
<https://support.epson.net/linux/en/epsonscan2.php>.

Work in a scratch directory outside the repository (or under `.work/`), never in
`media-gfx/`.

## media-gfx/epsonscan2

1. **Unpack into a git tree** so patches can be regenerated with `git diff`:

   ```sh
   W=.work/bump && mkdir -p $W && tar -xzf fontes/epsonscan2-<NEW>-1.src.tar.gz -C $W
   cd $W/epsonscan2-<NEW>-1 && git init -q && git add -A && git commit -qm orig && git tag t_orig
   ```

2. **Reproduce `src_prepare`**: delete what the ebuild deletes (`thirdparty/{HaruPDF,zlib}`,
   `src/ES2Emulator`, `src/Controller/Test`, the ScanSDK sample) and commit.

3. **Apply the current patches in `PATCHES` order**, one commit and one tag per patch:

   ```sh
   patch -p1 --dry-run < …/files/epsonscan2-<OLD>-<topic>.patch
   ```

   - If it applies, apply it and commit.
   - If it fails, redo the change by hand on the new sources (read the patch header for the
     intent) and commit.
   - If upstream already fixed it, drop the patch.

4. **Build both configurations** with the target flags (`libharu` must be available; see
   the `test-ebuild` skill for missing dependencies):

   ```sh
   cmake -S . -B ../build-nogui -G Ninja -DCMAKE_BUILD_TYPE=None \
   	-DCMAKE_C_FLAGS="-O3 -march=native -pipe" -DCMAKE_CXX_FLAGS="-O3 -march=native -pipe" \
   	-DBUILD_GUI=OFF -DBUILD_SCANSDK=OFF -DEPSON_OCR_INSTALL_PATH=/usr/libexec/epsonscan2-ocr/
   ninja -C ../build-nogui -k 0
   ```

   Repeat in a separate, fresh build directory (`../build-gui`) with `-DBUILD_GUI=ON`;
   never reconfigure `../build-nogui`. New errors become new commits: put them in the
   matching patch, or add a new `${P}-<topic>.patch`. Also grep the output for
   `-Wreturn-type` and other severe warnings.

5. **Regenerate each patch.** Write the header from scratch: a short paragraph saying
   why the patch exists, plus the original author/credit line for upstream or third-party
   fixes. Do not cut the header out of the old patch, because:
   - some old patches have no `diff --git` line (plain `---`/`+++` diffs);
   - `git format-patch` ones carry stale `From`/`Subject`/diffstat blocks.

   ```sh
   { cat header.txt; echo; git diff --no-color t_<prev> t_<topic> -- . ':!<removed dirs>'; } > new.patch
   ```

   - Exclude directories that `src_prepare` removes, otherwise `eapply` fails on them.
   - If the diff is empty because upstream fixed it, drop the patch instead of keeping a
     header-only file.

6. **Write the new ebuild next to the old one.** `git cp` does not exist, so `cp` the ebuild
   to the new `${P}`, write the regenerated patches under the new names and update
   `PATCHES`. Then regenerate the Manifest with `ebuild <new>.ebuild manifest`. Keep the old
   ebuild and its patches until step 7 passes, so there is something to compare against
   and fall back to.

7. **Run the `test-ebuild` skill** for `-gui -wifi`, `gui` and `wifi` on the new ebuild.
   Only after it passes, `git rm` the old ebuild and its old patches, and regenerate the
   Manifest once more so it drops the old DIST line.

8. **Update the docs**: the patch table and version numbers in
   `media-gfx/epsonscan2/README.md` and the root `README.md`.

## media-gfx/epsonscan2-non-free-plugin

The package is versioned after the plugin RPM, not after the bundle.

1. Find the plugin version inside the new bundle:

   ```sh
   tar -tzf fontes/epsonscan2-bundle-<VER>.x86_64.rpm.tar.gz | grep plugins/
   ```

2. Pick the update path:
   - **Same plugin version:** only change `BUNDLE` and regenerate the Manifest.
   - **New plugin version:** create a new ebuild named after it.
3. Inspect the payload before changing `src_install`. Extract it with
   `bsdtar -xf <rpm>` into a scratch dir.
4. Compare `readelf -d` NEEDED of all ELF files with `RDEPEND`.
5. Check that the install paths still match what `media-gfx/epsonscan2` looks up
   (`non-free-exec/`, `/usr/libexec/epsonscan2-ocr/`).
6. Run `test-ebuild` and confirm there are no QA notices (`RPM_COMPRESS_TYPE` must match
   the payload compression).

## Before committing

Follow the Privacy section of CLAUDE.md: no local paths, IPs, hostnames or personal data in
patches, ebuilds, READMEs or commit messages.
