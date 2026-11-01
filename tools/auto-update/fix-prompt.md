You were started unattended by `tools/auto-update/auto-update.py` (weekly cron job of this
overlay). Nobody is watching: don't ask questions, decide and act.

## Task

Bump `{{CP}}` from `{{OLD}}` to `{{NEW}}`. The script did the mechanical part in this git
worktree (`{{WORKTREE}}`, branch `{{BRANCH}}`); new ebuild: `{{EBUILD}}` (empty if the script
did not get that far). It stopped with:

```
{{ERROR}}
```

Logs of the failed `ebuild … clean install` runs:
{{LOGS}}

## What to do

1. Read `CLAUDE.md` and follow it (ebuild conventions, upstream facts, privacy). For the Epson
   packages follow the `bump-epsonscan2` skill; for testing, the `test-ebuild` skill.
2. Find the cause and fix it in this worktree only: the new ebuild, its patches under
   `files/` (regenerate them with `git diff` from a scratch git tree of the sources under
   `{{BUILD_DIR}}`, never by hand; rebase patches that no longer apply), or the Manifest
   (`ebuild <file> manifest` in the test-ebuild environment). Don't touch other packages.
   Don't edit the older ebuilds. If the new ebuild doesn't exist yet, create it from the
   newest one.
3. Iterate on the failing phase quickly in the test-ebuild environment
   (`export EBUILD_TEST_DIR={{BUILD_DIR}}; source .claude/skills/test-ebuild/scripts/portage-user-env.sh`,
   plus `export PORTAGE_TMPDIR={{TMPDIR}}` if that is non-empty) with single phases such as
   `ebuild {{EBUILD}} prepare` / `compile`. Delete `temp/environment` and `.setuped` in the
   build dir after editing the ebuild (CLAUDE.md).
4. When you think it's fixed, run the full test:
   `tools/auto-update/auto-update.py --resume {{PN}}`
   It rebuilds every USE combination from scratch and prints the problems. You may run it at
   most {{MAX}} times. For `www-client/brave-browser` the full build takes hours: run it in
   the background and wait for it; if that's not possible, stop after the failing phase
   works, since the calling script runs the full test again after you exit.
5. If you can't fix it (upstream change that needs a decision, missing distfile that must
   be downloaded with a browser, limit reached), stop and write a short diagnosis to
   `{{BUILD_DIR}}/DIAGNOSIS.md`.

## Rules

- No root: never `sudo`, `su`, `doas`, a real `emerge` (only `emerge -p`), `eselect`.
- Never `git commit`, `git push`, `git rebase` or switch branches: the script commits on
  `{{BRANCH}}` after the tests pass.
- Don't upload or redistribute distfiles. Don't add local paths, host names, user names, IPs
  or e-mail addresses to any file (CLAUDE.md, Privacy).
- Don't change `tools/auto-update/` to make a test pass, e.g. by relaxing the QA checks.
  Fix every QA notice that comes from the package.

End your answer with one line: `RESULT: fixed` or `RESULT: gave up: <reason>`.
