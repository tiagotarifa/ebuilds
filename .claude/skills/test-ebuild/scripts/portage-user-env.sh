#!/bin/bash
# Source this file to run Portage's `ebuild` command as a normal user against this
# overlay, without touching the system's PORTAGE_TMPDIR, DISTDIR or repos.conf.
#
#   source .claude/skills/test-ebuild/scripts/portage-user-env.sh
#
# EBUILD_TEST_DIR overrides the work directory (default: <repo>/.work).

_repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel) || return 1
_gentoo=$(portageq get_repo_path / gentoo) || return 1

EBUILD_TEST_DIR=${EBUILD_TEST_DIR:-${_repo}/.work}
mkdir -p "${EBUILD_TEST_DIR}"/{tmp,distfiles} || return 1

# Distfiles can't be fetched automatically (fetch restriction): reuse the local copies.
if [[ -d ${_repo}/fontes ]]; then
	cp -u "${_repo}"/fontes/*.tar.gz "${EBUILD_TEST_DIR}"/distfiles/ 2>/dev/null
fi

export EBUILD_TEST_DIR
export PORTAGE_TMPDIR=${EBUILD_TEST_DIR}/tmp
export DISTDIR=${EBUILD_TEST_DIR}/distfiles
export PORTAGE_REPOSITORIES="
[DEFAULT]
main-repo = gentoo
[gentoo]
location = ${_gentoo}
[epsonscan2]
location = ${_repo}
"
# The sandboxes and privilege dropping need root.
export FEATURES="-userpriv -usersandbox -sandbox -ipc-sandbox -network-sandbox -pid-sandbox -mount-sandbox -userfetch"
export PORTAGE_USERNAME=$(id -un) PORTAGE_GRPNAME=$(id -gn)

echo "Portage user environment ready: ${EBUILD_TEST_DIR}"
unset _repo _gentoo
