#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Generate the desktop entry, manpage, AppStream metadata and GNOME default-app
# entry of www-client/brave-browser from upstream's templates, using upstream's
# own template processor. Adapted from www-client/chromium's
# generate-support-files.py (Gentoo); missing template variables are fatal.
# The manpage template is Chromium's: its Google/Chromium references are
# rewritten for Brave, and a template change that breaks this is fatal too.
import argparse
import sys
from pathlib import Path

# Add upstream installer script to search path; Brave's patched copy also
# imports brave/script/brave_chromium_utils.py
sys.path.insert(0, str(Path.cwd() / "chrome/installer/linux/common"))
sys.path.insert(0, str(Path.cwd() / "brave/script"))
import installer

# User data directory under ~/.config/BraveSoftware (chrome_paths_linux.cc)
PROFILE_DIRS = {"brave-browser": "Brave-Browser", "brave-origin": "Brave-Origin"}


def rebrand_manpage(path, info, profile_dir):
    page = path.read_text()
    shortdesc = info["SHORTDESC"][0].lower() + info["SHORTDESC"][1:]
    replacements = {
        "\\- the web browser from Google": f"\\- {shortdesc}",
        "See the Google Chrome help center": "See the Brave Help Center",
        "<https://support.google.com/chrome/>": "<https://support.brave.com/>",
        "$HOME/.config/brave-browser": f"$HOME/.config/BraveSoftware/{profile_dir}",
        "$HOME/.cache/brave-browser": f"$HOME/.cache/BraveSoftware/{profile_dir}",
        "http://code.google.com/p/chromium/issues/list":
            "https://github.com/brave/brave-browser/issues",
        'Be sure to do your search within "All Issues" before reporting bugs,\n'
        'and be sure to pick the "Defect on Linux" template when filing a new one.':
            "Search the existing issues before reporting a new one.",
        "The Chromium team \\- <http://www.chromium.org>":
            f"{info['MAINTNAME']} \\- <{info['PRODUCTURL']}>",
    }
    for old, new in replacements.items():
        if old not in page:
            sys.exit(f"{path}: {old!r} not found in the manpage template")
        page = page.replace(old, new)
    path.write_text(page)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--installdir",
        required=True,
        help="Installation directory (e.g. /usr/lib64/brave-browser)",
    )
    parser.add_argument(
        "-b",
        "--branding",
        default="brave-browser",
        choices=["brave-browser", "brave-origin"],
        help="Brave branding directory with the .info and appdata files",
    )
    parser.add_argument("-o", "--outdir", default="out/Release")
    args = parser.parse_args()

    branding = Path("brave/chromium_src/chrome/installer/linux/common") / args.branding
    info = {}
    with open(branding / "chromium-browser.info") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                info[key] = value.strip('"')

    package = "brave-browser"
    context = {
        "INSTALLDIR": args.installdir,
        "MENUNAME": info["MENUNAME"],
        "PACKAGE": package,
        "desktop_exec": f"/usr/bin/{package}",
        "desktop_icon": package,
        "extra_desktop_entries": "",
        "startup_wm_class": package,
        "uri_scheme": "x-scheme-handler/brave;",
    }

    outdir = Path(args.outdir)
    templates = {
        Path("chrome/installer/linux/common/desktop.template"): f"{package}.desktop",
        Path("chrome/app/resources/manpage.1.in"): f"{package}.1",
        branding / "appdata.xml.template": f"{package}.appdata.xml",
        Path("chrome/installer/linux/common/default-app.template"): f"{package}.xml",
    }
    for template, output in templates.items():
        installer.process_template(template, outdir / output, context)
    rebrand_manpage(outdir / f"{package}.1", info, PROFILE_DIRS[args.branding])


if __name__ == "__main__":
    main()
