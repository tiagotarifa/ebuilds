#!/usr/bin/env python3
"""Check upstream for new releases of the overlay's packages and bump them.

For every package with a new release the script works in a git worktree on a new branch
(auto-update/<pkg>-<version>): it copies the newest ebuild, adjusts it mechanically,
regenerates the Manifest and runs the test-ebuild procedure for the package's USE
combinations. If that passes it keeps the three newest ebuilds, updates the READMEs and
commits on the branch (never on main, never pushes).

If the mechanical bump or the build fails, `claude -p` is started in the worktree to fix
it; Claude tests with `--resume <pkg>` and the script commits once the tests pass. Claude
is the only part that uses the subscription, and only when something breaks.

Usage:
    auto-update.py                    check everything and bump what is new
    auto-update.py --check-only       only report the versions
    auto-update.py --only applewin    restrict to some packages (name or cat/pkg)
    auto-update.py --resume <pkg>     re-run the tests of a pending bump (used by Claude)
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import urllib.request
from pathlib import Path

from portage.versions import pkgsplit, vercmp

SCRIPT_DIR = Path(__file__).resolve().parent


def _main_checkout():
    """The main checkout, also when the script runs from a worktree."""
    common = subprocess.run(
        ["git", "-C", str(SCRIPT_DIR), "rev-parse", "--path-format=absolute",
         "--git-common-dir"], check=True, capture_output=True, text=True).stdout.strip()
    return Path(common).parent


REPO = _main_checkout()
FONTES = REPO / "fontes"
WORK = REPO / ".work" / "auto-update"
STATE_DIR = WORK / "state"
# Builds write tens of GB (Brave); AUTO_UPDATE_SCRATCH moves them to another disk
SCRATCH = Path(os.environ["AUTO_UPDATE_SCRATCH"]) if os.environ.get("AUTO_UPDATE_SCRATCH") \
    else None
BUILD_ROOT = (SCRATCH or WORK) / "build"
ENV_SCRIPT = ".claude/skills/test-ebuild/scripts/portage-user-env.sh"
IN_CLAUDE = os.environ.get("AUTO_UPDATE_IN_CLAUDE") == "1"
MAX_RESUMES = 3        # --resume runs Claude may do per bump
MAX_CLAUDE_ROUNDS = 2  # Claude sessions per bump
CLAUDE_TIMEOUT = 20 * 3600
TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
COMMON_FLAGS = "-O3 -march=native -pipe"

# QA notices that are not the package's fault: the user-mode Portage environment can't
# resolve sonames against the installed system, and Chromium's language list has no "bs".
QA_ALLOW = [r"Unresolved soname dependencies"]
SEVERE = re.compile(r"warning: .*\[-W(return-type|aggressive-loop-optimizations)\]")

PACKAGES = {
    "games-emulation/applewin": {
        "uses": ["sdl", "qt6 -sdl", "ncurses libretro -sdl",
                 "-network libretro ncurses qt6 sdl"],
    },
    "media-video/shotcut": {"uses": ["-vulkan", "vulkan"]},
    "games-fps/ironwail": {
        "uses": ["", "-curl -mp3 -vorbis flac mikmod modplug opus xmp"],
    },
    "games-emulation/blastem": {"uses": ["-gtk", "gtk"]},
    "media-gfx/epsonscan2": {"uses": ["-gui -wifi", "gui", "wifi"]},
    "media-gfx/epsonscan2-non-free-plugin": {"uses": [""]},
    # Last: the build takes hours. tsx needs a short PORTAGE_TMPDIR (CLAUDE.md).
    "www-client/brave-browser": {
        "uses": [""], "tmpdir": str(SCRATCH / "bt") if SCRATCH else "/var/tmp/bt-au",
        "qa_allow": [r"L10N warning: no bs in LANGS"],
    },
}


class BumpError(Exception):
    """The mechanical bump can't go on; Claude has to look at it."""


# ---------------------------------------------------------------------------- helpers

def log(msg):
    print(f"[{datetime.datetime.now():%H:%M:%S}] {msg}", flush=True)


def run(cmd, **kw):
    kw.setdefault("check", True)
    kw.setdefault("text", True)
    return subprocess.run(cmd, **kw)


def git(*args, cwd=REPO, **kw):
    return run(["git", "-C", str(cwd), *args], capture_output=True, **kw).stdout.strip()


def fetch(url, binary=False):
    headers = {"User-Agent": "tiagotarifa-overlay-auto-update"}
    if "api.github.com" in url:
        headers["Accept"] = "application/vnd.github+json"
        if os.environ.get("GITHUB_TOKEN"):
            headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers),
                                timeout=60) as r:
        data = r.read()
    return data if binary else data.decode()


def fetch_json(url):
    return json.loads(fetch(url))


def ebuilds(pkgdir):
    """[(pv, pr, path)] of a package directory, oldest first."""
    pn = pkgdir.name
    out = []
    for f in pkgdir.glob(f"{pn}-*.ebuild"):
        split = pkgsplit(f.stem)
        if split and split[0] == pn and split[1] != "9999":
            out.append((split[1], split[2], f))
    out.sort(key=lambda e: _CmpKey(e[0] + ("" if e[1] == "r0" else "-" + e[1])))
    return out


class _CmpKey:
    def __init__(self, v):
        self.v = v

    def __lt__(self, other):
        return vercmp(self.v, other.v) < 0


def newer(a, b):
    return vercmp(a, b) > 0


def ebuild_var(text, name):
    m = re.search(rf'^{name}="([^"]*)"', text, re.M)
    if not m:
        raise BumpError(f"{name} not found in the ebuild")
    return m.group(1)


def set_var(text, name, value):
    new, n = re.subn(rf'^({name}=")[^"]*(")', rf"\g<1>{value}\g<2>", text, flags=re.M)
    if n != 1:
        raise BumpError(f"could not set {name} in the ebuild")
    return new


def semver_ok(version, spec):
    """Check a version against a simple npm range ('>=24.16.0 <25.0.0')."""
    def key(v):
        return [int(x) for x in v.split(".")]
    ops = {">=": lambda a, b: a >= b, "<=": lambda a, b: a <= b, ">": lambda a, b: a > b,
           "<": lambda a, b: a < b, "=": lambda a, b: a == b}
    for term in spec.split():
        m = re.fullmatch(r"(>=|<=|>|<|=)?(\d+(?:\.\d+)*)", term)
        if not m:
            raise BumpError(f"unsupported version range {spec!r}")
        if not ops[m.group(1) or "="](key(version), key(m.group(2))):
            return False
    return True


# ------------------------------------------------------------------ version checks
# Each check returns None (nothing new) or a dict with at least "version" (used in the
# branch name). Notices for the report go to the `notices` list.

def check_github_release(repo, current):
    rel = fetch_json(f"https://api.github.com/repos/{repo}/releases/latest")
    if rel.get("prerelease") or rel.get("draft"):
        return None
    ver = rel["tag_name"].lstrip("v")
    return {"version": ver, "tag": rel["tag_name"]} if newer(ver, current) else None


def check_brave(pkgdir, notices):
    return check_github_release("brave/brave-browser", ebuilds(pkgdir)[-1][0])


def check_shotcut(pkgdir, notices):
    ours = ebuilds(pkgdir)[-1][0]
    gentoo = Path(run(["portageq", "get_repo_path", "/", "gentoo"],
                      capture_output=True).stdout.strip()) / "media-video/shotcut"
    theirs = ebuilds(gentoo)
    if theirs and vercmp(theirs[-1][0], ours) >= 0:
        notices.append(f"media-video/shotcut: ::gentoo has {theirs[-1][0]} (ours: {ours}); "
                       "consider dropping the package from the overlay.")
    return check_github_release("mltframework/shotcut", ours)


def check_applewin(pkgdir, notices):
    base = ebuilds(pkgdir)[-1][0].split("_p")[0]
    best = None
    for tag in fetch_json("https://api.github.com/repos/audetto/AppleWin/tags?per_page=100"):
        m = re.fullmatch(r"v(\d+(?:\.\d+)*)", tag["name"])
        if m and newer(m.group(1), base) and (not best or newer(m.group(1), best["version"])):
            best = {"version": m.group(1), "tag": tag["name"], "sha": tag["commit"]["sha"]}
    return best


def check_ironwail(pkgdir, notices):
    return check_github_release("andrei-drexler/ironwail", ebuilds(pkgdir)[-1][0])


def check_blastem(pkgdir, notices):
    # Mercurial (hgweb): one "<tag>\t<node>" line per tag
    current = ebuilds(pkgdir)[-1][0]
    best = None
    for line in fetch("https://www.retrodev.com/repos/blastem/raw-tags").splitlines():
        m = re.fullmatch(r"v(\d+(?:\.\d+)*)\t[0-9a-f]+", line.strip())
        if m and newer(m.group(1), current) and (not best or newer(m.group(1), best["version"])):
            best = {"version": m.group(1), "tag": f"v{m.group(1)}"}
    return best


def aur_version(name):
    res = fetch_json(f"https://aur.archlinux.org/rpc/v5/info?arg[]={name}")["results"]
    return res[0]["Version"].rsplit("-", 1)[0] if res else None


def check_epsonscan2(pkgdir, notices):
    current = ebuilds(pkgdir)[-1][0]
    local = [m.group(1) for f in FONTES.glob("epsonscan2-*-1.src.tar.gz")
             if (m := re.fullmatch(r"epsonscan2-([\d.]+)-1\.src\.tar\.gz", f.name))]
    local = [v for v in local if newer(v, current)]
    if local:
        best = max(local, key=_CmpKey)
        return {"version": best}
    # Epson's site rejects scripts; the AUR package is a good enough signal
    try:
        aur = aur_version("epsonscan2")
    except OSError as e:
        notices.append(f"media-gfx/epsonscan2: could not query the AUR ({e}).")
        return None
    if aur and newer(aur, current):
        notices.append(
            f"media-gfx/epsonscan2: Epson Scan 2 {aur} seems to be out (ours: {current}). "
            f"Download epsonscan2-{aur}-1.src.tar.gz and the 64-bit rpm bundle "
            f"(epsonscan2-bundle-{aur}.x86_64.rpm.tar.gz) from "
            "https://support.epson.net/linux/en/epsonscan2.php into fontes/; the next run "
            "bumps both packages.")
    return None


def check_plugin(pkgdir, notices):
    text = ebuilds(pkgdir)[-1][2].read_text()
    current = re.fullmatch(r"epsonscan2-bundle-([\d.]+)\.x86_64\.rpm",
                           ebuild_var(text, "BUNDLE")).group(1)
    local = [m.group(1) for f in FONTES.glob("epsonscan2-bundle-*.x86_64.rpm.tar.gz")
             if (m := re.fullmatch(r"epsonscan2-bundle-([\d.]+)\.x86_64\.rpm\.tar\.gz",
                                   f.name))]
    local = [v for v in local if newer(v, current)]
    return {"version": max(local, key=_CmpKey)} if local else None


CHECKS = {
    "games-emulation/applewin": check_applewin,
    "media-video/shotcut": check_shotcut,
    "games-fps/ironwail": check_ironwail,
    "games-emulation/blastem": check_blastem,
    "media-gfx/epsonscan2": check_epsonscan2,
    "media-gfx/epsonscan2-non-free-plugin": check_plugin,
    "www-client/brave-browser": check_brave,
}


# ------------------------------------------------------------------ mechanical bumps
# Each prepare function gets (pkgdir, newest ebuild text, info) and returns
# (new ebuild file name, new text, [(old, new)] README replacements).

def prepare_simple(pkgdir, pv, text, info):
    pn = pkgdir.name
    return f"{pn}-{info['version']}.ebuild", text, [(pv, info["version"])]


def prepare_brave(pkgdir, pv, text, info):
    pkg = fetch_json(f"https://raw.githubusercontent.com/brave/brave-core/"
                     f"{info['tag']}/package.json")
    text = set_var(text, "CHROMIUM_VER", pkg["config"]["projects"]["chrome"]["tag"])
    dev = pkg.get("devEngines", {})
    for key, var in (("runtime", "NODE_VER"), ("packageManager", "PNPM_VER")):
        spec = dev.get(key, {}).get("version")
        if spec and not semver_ok(ebuild_var(text, var), spec):
            raise BumpError(f"brave-core {info['tag']} devEngines.{key} wants {spec}; "
                            f"update {var} (and the Manifest, for Node).")
    return f"{pkgdir.name}-{info['version']}.ebuild", text, [(pv, info["version"])]


def prepare_applewin(pkgdir, pv, text, info):
    tag = info["tag"]
    api = "https://api.github.com/repos/audetto/AppleWin/contents"
    submodules = {
        "IMGUI_COMMIT": "source/frontends/sdl/imgui/imgui",
        "IMGUI_CLUB_COMMIT": "source/frontends/sdl/imgui/imgui_club",
        "IMGUI_FILEBROWSER_COMMIT": "source/frontends/sdl/imgui/imgui-filebrowser",
        "QHEXVIEW_COMMIT": "source/frontends/qt/QHexView",
    }
    gitmodules = fetch(f"https://raw.githubusercontent.com/audetto/AppleWin/{tag}/.gitmodules")
    paths = set(re.findall(r"^\s*path\s*=\s*(\S+)", gitmodules, re.M))
    if paths != set(submodules.values()):
        raise BumpError(f"the submodules changed in {tag}: {sorted(paths)}")
    old_commit = ebuild_var(text, "COMMIT")
    text = set_var(text, "COMMIT", info["sha"])
    for var, path in submodules.items():
        meta = fetch_json(f"{api}/{path}?ref={tag}")
        if meta.get("type") != "submodule":
            raise BumpError(f"{path} is not a submodule in {tag}")
        text = set_var(text, var, meta["sha"])
    repl = [(pv, info["version"]), (f"`{old_commit[:7]}`", f"`{info['sha'][:7]}`")]
    return f"{pkgdir.name}-{info['version']}.ebuild", text, repl


def prepare_plugin(pkgdir, pv, text, info):
    old_bundle = ebuild_var(text, "BUNDLE")
    bundle = f"epsonscan2-bundle-{info['version']}.x86_64.rpm"
    listing = run(["tar", "-tzf", str(FONTES / f"{bundle}.tar.gz")],
                  capture_output=True).stdout
    m = re.search(r"plugins/epsonscan2-non-free-plugin-([\d.]+)-1\.x86_64\.rpm$", listing, re.M)
    if not m:
        raise BumpError(f"no plugin rpm found in {bundle}.tar.gz")
    text = set_var(text, "BUNDLE", bundle)
    plugin_ver = m.group(1)
    if plugin_ver == pv:
        revs = [int(r[1:]) for v, r, _ in ebuilds(pkgdir) if v == pv]
        name = f"{pkgdir.name}-{pv}-r{max(revs) + 1}.ebuild"
    else:
        name = f"{pkgdir.name}-{plugin_ver}.ebuild"
    return name, text, [(old_bundle, bundle)]


PREPARES = {
    "games-emulation/applewin": prepare_applewin,
    "media-video/shotcut": prepare_simple,
    "games-fps/ironwail": prepare_simple,
    "games-emulation/blastem": prepare_simple,
    "media-gfx/epsonscan2": prepare_simple,
    "media-gfx/epsonscan2-non-free-plugin": prepare_plugin,
    "www-client/brave-browser": prepare_brave,
}


# --------------------------------------------------------------------------- state

def state_path(cp):
    return STATE_DIR / (cp.replace("/", "_") + ".json")


def load_state(cp):
    p = state_path(cp)
    return json.loads(p.read_text()) if p.exists() else None


def save_state(st):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_path(st["cp"]).write_text(json.dumps(st, indent=2))


def tree_hash(pkgdir):
    h = hashlib.sha256()
    for f in sorted(pkgdir.rglob("*")):
        if f.is_file():
            h.update(str(f.relative_to(pkgdir)).encode())
            h.update(f.read_bytes())
    return h.hexdigest()


# ------------------------------------------------------------------- ebuild runs

def portage_env_cmd(st, body):
    """A bash command running `body` in the test-ebuild environment of the worktree."""
    tmpdir = PACKAGES[st["cp"]].get("tmpdir")
    pre = f'export EBUILD_TEST_DIR="{st["build_dir"]}"; source "{ENV_SCRIPT}" >/dev/null || exit 1; '
    if tmpdir:
        pre += f'export PORTAGE_TMPDIR="{tmpdir}"; mkdir -p "{tmpdir}"; '
    return ["bash", "-c", pre + f'cd "{st["cp"]}" && ' + body]


def ebuild_manifest(st):
    logf = Path(st["log_dir"]) / f"{st['pn']}-manifest.log"
    with open(logf, "w") as out:
        r = run(portage_env_cmd(st, f'ebuild "{st["ebuild"]}" manifest'),
                cwd=st["worktree"], stdout=out, stderr=subprocess.STDOUT, check=False)
    if r.returncode:
        raise BumpError(f"`ebuild manifest` failed, see {logf}")


def run_tests(st):
    """Run `ebuild clean install` for every USE combination. Returns [problems]."""
    cfg = PACKAGES[st["cp"]]
    allow = [re.compile(a) for a in QA_ALLOW + cfg.get("qa_allow", []) + st.get("qa_allow", [])]
    problems = []
    st["test_logs"] = []
    for use in cfg["uses"]:
        tag = re.sub(r"[^a-z0-9]+", "_", use).strip("_") or "default"
        logf = Path(st["log_dir"]) / f"{st['pn']}-{tag}-{st.get('attempt', 0)}.log"
        st["test_logs"].append(str(logf))
        log(f"  {st['pn']}: ebuild clean install, USE=\"{use}\" -> {logf}")
        body = (f'USE="{use}" CFLAGS="{COMMON_FLAGS}" CXXFLAGS="{COMMON_FLAGS}" '
                f'ebuild "{st["ebuild"]}" clean install')
        with open(logf, "w") as out:
            r = run(portage_env_cmd(st, body), cwd=st["worktree"], stdout=out,
                    stderr=subprocess.STDOUT, check=False)
        text = re.sub(r"\x1b\[[0-9;]*m", "", logf.read_text(errors="replace"))
        if r.returncode:
            err = re.search(r"^ \* ERROR: .*\n(?: \*   .*\n?)?", text, re.M)
            err = " ".join(err.group(0).replace(" * ", "").split()) if err else ""
            problems.append(f'USE="{use}": ebuild failed (exit {r.returncode}): {err} '
                            f'(see {logf})')
            continue
        for line in text.splitlines():
            if "QA Notice" in line and not any(a.search(line) for a in allow):
                problems.append(f'USE="{use}": {line.strip(" *")} (see {logf})')
            elif SEVERE.search(line):
                problems.append(f'USE="{use}": severe warning: {line.strip()} (see {logf})')
    return problems


def clean_build(st):
    shutil.rmtree(st["build_dir"], ignore_errors=True)
    tmpdir = PACKAGES[st["cp"]].get("tmpdir")
    if tmpdir:
        shutil.rmtree(tmpdir, ignore_errors=True)


# -------------------------------------------------------------------- finalisation

def prune(st):
    """Keep the three newest ebuilds and the patches they use. Returns removed versions."""
    pkgdir = Path(st["worktree"]) / st["cp"]
    eb = ebuilds(pkgdir)
    removed = []
    for pv, pr, f in eb[:-3]:
        git("rm", "-q", str(f.relative_to(st["worktree"])), cwd=st["worktree"])
        removed.append(pv)
    kept = {pv for pv, _, _ in eb[-3:]}
    gone = set(removed) - kept
    files = pkgdir / "files"
    for pv in gone:
        for p in files.glob(f"{pkgdir.name}-{pv}-*"):
            git("rm", "-q", str(p.relative_to(st["worktree"])), cwd=st["worktree"])
    # Brave's cached sources of versions that left the overlay (tens of GB each)
    if st["cp"] == "www-client/brave-browser":
        for pv in gone:
            cache = FONTES / "brave-browser-src" / f"brave-browser-{pv}-src.tar.zst"
            if cache.exists():
                cache.unlink()
                st.setdefault("notes", []).append(f"deleted the source cache {cache.name}")
    return sorted(gone, key=_CmpKey)


def update_readmes(st):
    wt = Path(st["worktree"])
    for readme in (wt / st["cp"] / "README.md", wt / "README.md"):
        if not readme.exists():
            continue
        text = orig = readme.read_text()
        for old, new in st["readme_repl"]:
            text = text.replace(old, new)
        if text != orig:
            readme.write_text(text)


def privacy_check(st):
    """Look for local data in the lines the commit adds."""
    wt = st["worktree"]
    diff = git("diff", "--cached", "-C", "-C", "--no-color", "-U0", cwd=wt)
    added = [l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    known_mails = set(re.findall(r"[\w.+-]+@[\w-]+\.[\w.]+",
                                 git("grep", "-h", "-I", "-o", "-E", r"[[:alnum:]._+-]+@[[:alnum:]-]+\.[[:alnum:].]+",
                                     st.get("base", "main"), "--", ".", check=False)))
    host = socket.gethostname().split(".")[0]
    bad = []
    for line in added:
        if "/home/" in line or str(Path.home()) in line:
            bad.append(line)
        elif len(host) > 3 and re.search(rf"\b{re.escape(host)}\b", line):
            bad.append(line)
        elif (m := re.search(r"\b(10\.\d+|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d+\.\d+\b", line)) \
                and m.group(0) != "192.168.0.10":
            bad.append(line)
        else:
            for mail in re.findall(r"[\w.+-]+@[\w-]+\.[\w.]+", line):
                if mail not in known_mails:
                    bad.append(line)
    return bad


def finalize(st):
    wt = st["worktree"]
    gone = prune(st)
    try:
        ebuild_manifest(st)
    except BumpError as e:
        return fail(st, str(e))
    update_readmes(st)
    git("add", "--", st["cp"], "README.md", cwd=wt)
    bad = privacy_check(st)
    if bad:
        return fail(st, "privacy check: the commit would add local data:\n    "
                    + "\n    ".join(bad[:10]))
    msg = f"{st['cp']}: {st['summary']}\n"
    if gone:
        msg += f"\nDrop the old {', '.join(gone)} ebuild(s).\n"
    if st.get("claude_used"):
        msg += f"\n{TRAILER}\n"
    email = git("config", "--local", "user.email")
    git("-c", f"user.email={email}", "commit", "-q", "-F", "-", cwd=wt, input=msg)
    st["commit"] = git("rev-parse", "--short", "HEAD", cwd=wt)
    st["status"] = "committed"
    save_state(st)
    git("worktree", "remove", "--force", wt)
    clean_build(st)
    log(f"  {st['cp']}: committed {st['commit']} on {st['branch']}")
    return True


def fail(st, why):
    st["status"] = "failed"
    st["error"] = why
    save_state(st)
    log(f"  {st['cp']}: FAILED: {why}")
    return False


# -------------------------------------------------------------------------- Claude

def call_claude(st, why):
    prompt = (SCRIPT_DIR / "fix-prompt.md").read_text()
    fields = {
        "CP": st["cp"], "OLD": st["old_pvr"], "NEW": st["version"], "EBUILD": st["ebuild"],
        "BRANCH": st["branch"], "WORKTREE": st["worktree"], "ERROR": why,
        "LOGS": "\n".join(f"- {l}" for l in st.get("test_logs", [])) or "- (none)",
        "BUILD_DIR": st["build_dir"], "TMPDIR": PACKAGES[st["cp"]].get("tmpdir", ""),
        "PN": st["pn"], "MAX": str(MAX_RESUMES),
    }
    for k, v in fields.items():
        prompt = prompt.replace("{{" + k + "}}", v)
    st["claude_used"] = True
    st["claude_rounds"] = st.get("claude_rounds", 0) + 1
    st["resumes"] = 0
    save_state(st)
    out = Path(st["log_dir"]) / f"{st['pn']}-claude-{st['claude_rounds']}.json"
    log(f"  {st['cp']}: calling Claude (round {st['claude_rounds']}) -> {out}")
    env = dict(os.environ, AUTO_UPDATE_IN_CLAUDE="1")
    cmd = ["claude", "-p", prompt, "--permission-mode", "auto", "--output-format", "json",
           "--add-dir", str(FONTES), "--add-dir", str(WORK),
           *(["--add-dir", str(SCRATCH)] if SCRATCH else []),
           "--name", f"auto-update {st['pn']} {st['version']}"]
    try:
        with open(out, "w") as f:
            run(cmd, cwd=st["worktree"], env=env, stdout=f, stderr=subprocess.STDOUT,
                check=False, timeout=CLAUDE_TIMEOUT, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired) as e:
        log(f"  {st['cp']}: Claude did not finish: {e}")
    return load_state(st["cp"])


def test_and_fix(st):
    """Test; on failure let Claude fix it. Returns True when the tests pass."""
    pkgdir = Path(st["worktree"]) / st["cp"]
    while True:
        if st.get("tested_ok_hash") == tree_hash(pkgdir):
            return True
        problems = run_tests(st)
        if not problems:
            st["tested_ok_hash"] = tree_hash(pkgdir)
            save_state(st)
            return True
        why = "the tests failed:\n" + "\n".join(f"  {p}" for p in problems)
        st["error"] = why
        save_state(st)
        if IN_CLAUDE or st.get("no_claude") or st.get("claude_rounds", 0) >= MAX_CLAUDE_ROUNDS:
            return False
        st = call_claude(st, why)
        st["attempt"] = st.get("attempt", 0) + 1
        save_state(st)


# ------------------------------------------------------------------------ main flow

def bump(cp, info, args, run_dir):
    pn = cp.split("/")[1]
    branch = f"auto-update/{pn}-{info['version']}"
    if git("branch", "--list", branch):
        log(f"{cp}: {branch} already exists (waiting for review), skipping")
        st = load_state(cp) or {}
        if st.get("branch") != branch:
            st = {}
        return {"cp": cp, "version": info["version"], "branch": branch,
                "status": "pending review" if st.get("status") != "failed" else
                          "failed earlier, worktree kept",
                "notes": [f"delete the branch `{branch}` (and its worktree) to retry"]}
    worktree = WORK / "wt" / f"{pn}-{info['version']}"
    if worktree.exists():
        git("worktree", "remove", "--force", str(worktree), check=False)
        shutil.rmtree(worktree, ignore_errors=True)
    git("worktree", "prune")
    worktree.parent.mkdir(parents=True, exist_ok=True)
    git("worktree", "add", "-q", "-b", branch, str(worktree), args.base)
    pkgdir = worktree / cp
    pv, pr, old = ebuilds(pkgdir)[-1]
    st = {
        "cp": cp, "pn": pn, "version": info["version"], "info": info, "branch": branch,
        "worktree": str(worktree), "old_pvr": old.stem[len(pn) + 1:],
        "build_dir": str(BUILD_ROOT / f"{pn}-{info['version']}"),
        "log_dir": str(run_dir), "status": "preparing", "no_claude": args.no_claude,
        "base": args.base,
        "summary": f"version bump to {info['version']}", "ebuild": "",
        "readme_repl": [(pv, info["version"])],
    }
    save_state(st)
    log(f"{cp}: {st['old_pvr']} -> {info['version']} on {branch}")
    try:
        name, text, repl = PREPARES[cp](pkgdir, pv, old.read_text(), info)
        st["ebuild"], st["readme_repl"] = name, repl
        (pkgdir / name).write_text(text)
        new_pv = pkgsplit(Path(name).stem)[1]
        if new_pv != pv:
            for p in (pkgdir / "files").glob(f"{pn}-{pv}-*"):
                shutil.copy2(p, p.with_name(p.name.replace(f"{pn}-{pv}-", f"{pn}-{new_pv}-", 1)))
        if cp == "media-gfx/epsonscan2-non-free-plugin" and new_pv == pv:
            st["summary"] = f"update to the {info['version']} bundle"
        save_state(st)
        ebuild_manifest(st)
        ok = test_and_fix(st)
    except (BumpError, OSError, subprocess.CalledProcessError, KeyError) as e:
        why = f"mechanical bump failed: {e}"
        st["error"] = why
        save_state(st)
        ok = False
        if not args.no_claude:
            st = call_claude(st, why)
            st["attempt"] = 1
            st["ebuild"] = st.get("ebuild") or detect_new_ebuild(st)
            save_state(st)
            ok = bool(st["ebuild"]) and test_and_fix(st)
    st = load_state(cp)
    if not ok:
        fail(st, st.get("error", "unknown error"))
        return st
    if args.dry_run:
        st["status"] = "tested (dry run, not committed)"
        save_state(st)
        return st
    finalize(st)
    return load_state(cp)


def resume(cp, args):
    st = load_state(cp)
    if not st or st["status"] not in ("preparing", "failed"):
        sys.exit(f"no pending bump for {cp}")
    if IN_CLAUDE:
        st["resumes"] = st.get("resumes", 0) + 1
        if st["resumes"] > MAX_RESUMES:
            save_state(st)
            sys.exit(f"--resume limit ({MAX_RESUMES}) reached: stop and write a diagnosis")
    st["attempt"] = st.get("attempt", 0) + 1
    st["ebuild"] = st.get("ebuild") or detect_new_ebuild(st)
    if not st["ebuild"] or not (Path(st["worktree"]) / st["cp"] / st["ebuild"]).exists():
        sys.exit(f"create the new ebuild in {st['worktree']}/{st['cp']} first")
    save_state(st)
    try:
        ebuild_manifest(st)
    except BumpError as e:
        sys.exit(str(e))
    problems = run_tests(st)
    if problems:
        st["error"] = "the tests failed:\n" + "\n".join(f"  {p}" for p in problems)
        st["status"] = "failed"
        save_state(st)
        print(st["error"])
        sys.exit(1)
    st["tested_ok_hash"] = tree_hash(Path(st["worktree"]) / st["cp"])
    st["status"] = "preparing"
    save_state(st)
    print(f"{cp}: all tests passed")
    if not IN_CLAUDE and not args.dry_run:
        finalize(st)


def detect_new_ebuild(st):
    """The ebuild that exists in the worktree but not on main (Claude may have made it)."""
    wt = st["worktree"]
    tracked = set(git("ls-tree", "--name-only", st.get("base", "main"), f"{st['cp']}/",
                      cwd=wt).splitlines())
    new = [f for _, _, f in ebuilds(Path(wt) / st["cp"])
           if f"{st['cp']}/{f.name}" not in tracked]
    return new[-1].name if new else ""


def resolve(names):
    out = []
    for n in names:
        match = [cp for cp in PACKAGES if n in (cp, cp.split("/")[1])]
        if not match:
            sys.exit(f"unknown package {n}; known: {', '.join(PACKAGES)}")
        out += match
    return out


def notify(summary):
    if shutil.which("notify-send") and os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        run(["notify-send", "-a", "ebuilds auto-update", "Overlay auto-update", summary],
            check=False, capture_output=True)


def claude_answer(st):
    f = Path(st["log_dir"]) / f"{st['pn']}-claude-{st.get('claude_rounds', 0)}.json"
    try:
        text = json.loads(f.read_text()).get("result") or ""
    except (OSError, ValueError):
        text = f"(no JSON answer, see {f})"
    return "\n".join("> " + l for l in text.strip().splitlines())


def write_report(run_dir, found, results, notices, errors):
    lines = [f"# Overlay auto-update, {datetime.datetime.now():%Y-%m-%d %H:%M}", ""]
    if not found and not notices and not errors:
        lines.append("Everything is up to date.")
    for cp, info in found.items():
        lines.append(f"- **{cp}**: new upstream version {info['version']}")
    lines.append("")
    for st in results:
        lines.append(f"## {st['cp']} {st['version']}: {st['status']}")
        if st.get("branch"):
            lines.append(f"- branch: `{st['branch']}`" + (f" (commit {st['commit']})"
                                                         if st.get("commit") else ""))
        if st.get("claude_used"):
            lines.append(f"- Claude was called {st.get('claude_rounds', 0)} time(s); "
                         "its last answer:")
            lines.append("\n" + claude_answer(st) + "\n")
        if st["status"] == "failed":
            lines.append(f"- worktree left for review: `{st['worktree']}`")
            lines.append(f"- error:\n\n```\n{st.get('error', '')}\n```")
        for n in st.get("notes", []):
            lines.append(f"- {n}")
        if st["cp"] == "games-emulation/applewin" and st["status"] == "committed":
            lines.append("- check the README: it describes a `master` snapshot")
        if st["cp"] == "media-video/shotcut" and st["status"] == "committed":
            lines.append("- compare with the ::gentoo ebuild and upstream's CMakeLists.txt "
                         "(CLAUDE.md)")
        lines.append("")
    if notices or errors:
        lines.append("## Notices")
        lines += [f"- {n}" for n in notices + errors]
    report = run_dir / "report.md"
    report.write_text("\n".join(lines) + "\n")
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check-only", action="store_true", help="only report new versions")
    ap.add_argument("--only", nargs="+", metavar="PKG", help="restrict to these packages")
    ap.add_argument("--resume", metavar="PKG", help="re-test a pending bump")
    ap.add_argument("--no-claude", action="store_true", help="never call Claude")
    ap.add_argument("--dry-run", action="store_true", help="test but do not commit")
    ap.add_argument("--base", default="main", help="commit the branches start from")
    ap.add_argument("--force", nargs=2, metavar=("PKG", "JSON"),
                    help='pretend PKG has the release JSON (e.g. \'{"version": "1.0"}\'), '
                         "for testing the bump")
    args = ap.parse_args()

    if args.resume:
        return resume(resolve([args.resume])[0], args)

    run_dir = WORK / "logs" / f"{datetime.datetime.now():%Y%m%d-%H%M%S}"
    run_dir.mkdir(parents=True, exist_ok=True)
    pkgs = resolve(args.only) if args.only else list(PACKAGES)
    notices, errors, found = [], [], {}
    for cp in pkgs:
        try:
            info = CHECKS[cp](REPO / cp, notices)
        except Exception as e:  # network errors etc. must not stop the other packages
            errors.append(f"{cp}: version check failed: {e}")
            continue
        if args.force and resolve([args.force[0]])[0] == cp:
            info = json.loads(args.force[1])
        current = ebuilds(REPO / cp)[-1]
        log(f"{cp}: ours {current[0]}" + (f", upstream {info['version']}" if info else
                                          ", up to date"))
        if info:
            found[cp] = info
    results = []
    if not args.check_only:
        for cp, info in found.items():
            try:
                results.append(bump(cp, info, args, run_dir))
            except Exception as e:
                errors.append(f"{cp}: {type(e).__name__}: {e}")
    for n in notices + errors:
        log(n)
    report = write_report(run_dir, found, results, notices, errors)
    log(f"report: {report}")
    if not args.check_only and (found or notices or errors):
        done = [f"{r['cp'].split('/')[1]} {r['version']}: {r['status']}" for r in results]
        notify("\n".join(done + notices + errors)[:500] + f"\n{report}")
    return 1 if errors or any(r["status"] == "failed" for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
