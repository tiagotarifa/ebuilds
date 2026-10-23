#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Compiler wrapper (GN cc_wrapper) for www-client/brave-browser.
#
# Brave overrides Chromium C/C++ sources by placing a file with the same path
# under brave/chromium_src/. Upstream builds with siso, whose redirect_cc
# handler (brave/build/config/siso/brave_siso_config.star) compiles the
# override instead of the original; the override #includes the original
# itself. This does the same for ninja.
#
# Usage: redirect-cc.py [<cpu flags>...] -- <compiler> <args...>
# The CPU flags (the user's -march/-mtune/-mcpu with USE=custom-cflags) are put
# right after the compiler, before the target's own flags: code that is built
# for a specific CPU level and dispatched at runtime (e.g. Skia's AVX-512
# paths) keeps its -march, everything else gets the user's.
import os
import sys

args = sys.argv[1:]
cpu_flags = []
if "--" in args:
    sep = args.index("--")
    cpu_flags, args = args[:sep], args[sep + 1:]
args[1:1] = cpu_flags

try:
    i = args.index("-c") + 1
except ValueError:
    i = None

if i is not None and i < len(args):
    source = args[i]
    override = None
    if source.startswith("../../"):
        override = source.replace("../../", "../../brave/chromium_src/", 1)
    elif source.startswith("gen/"):
        override = source.replace("gen/", "../../brave/chromium_src/", 1)
    else:
        # Generated file inside a custom toolchain, e.g. clang_x64/gen/...
        parts = source.split("/")
        if len(parts) > 1 and parts[1] == "gen":
            override = "../../brave/chromium_src/" + "/".join(parts[2:])
    if override and os.path.isfile(override):
        args[i] = override

os.execvp(args[0], args)
