# Source this file (do not execute it) to run Portage's `ebuild` command as a normal
# user against this overlay, without touching the system's PORTAGE_TMPDIR or repos.conf:
#
#   source .claude/skills/test-ebuild/scripts/portage-user-env.sh
#
# EBUILD_TEST_DIR overrides the work directory (default: <repo>/.work).
# Distfiles are read directly from <repo>/fontes (Portage only reads them).

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	echo "error: source this file instead of executing it" >&2
	exit 1
fi

_portage_user_env() {
	local repo gentoo
	repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel) || return 1
	gentoo=$(portageq get_repo_path / gentoo) || return 1

	if [[ ! -d ${repo}/fontes ]]; then
		echo "error: ${repo}/fontes (distfiles) not found" >&2
		return 1
	fi

	export EBUILD_TEST_DIR=${EBUILD_TEST_DIR:-${repo}/.work}
	mkdir -p "${EBUILD_TEST_DIR}"/tmp || return 1

	export PORTAGE_TMPDIR=${EBUILD_TEST_DIR}/tmp
	export DISTDIR=${repo}/fontes
	export PORTAGE_REPOSITORIES="
[DEFAULT]
main-repo = gentoo
[gentoo]
location = ${gentoo}
[tiagotarifa]
location = ${repo}
"
	# The sandboxes and privilege dropping need root; distlocks would write into DISTDIR.
	export FEATURES="-userpriv -usersandbox -sandbox -ipc-sandbox -network-sandbox -pid-sandbox -mount-sandbox -userfetch -distlocks"
	export PORTAGE_USERNAME=$(id -un) PORTAGE_GRPNAME=$(id -gn)

	echo "Portage user environment ready: ${EBUILD_TEST_DIR}"
}

if _portage_user_env; then
	unset -f _portage_user_env
	return 0
fi
unset -f _portage_user_env
return 1
