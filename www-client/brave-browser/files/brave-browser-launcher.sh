#!/bin/bash
# Launcher for www-client/brave-browser, adapted from www-client/chromium-common.
# The ebuild substitutes the values marked @...@.

BRAVE_HOME="@BRAVE_HOME@"
OZONE_AUTO_SESSION=@OZONE_AUTO_SESSION@

# System-wide flags: BRAVE_FLAGS in /etc/brave-browser/default (and any other
# file in that directory).
for f in /etc/brave-browser/*; do
	# Skip backup files and hidden files
	case "${f}" in
		*~|*.bak|*.old|*.swp|*.tmp|*/.*) continue ;;
	esac
	[[ -f "${f}" ]] && source "${f}"
done

# BRAVE_USER_FLAGS from the environment replaces the system default.
BRAVE_FLAGS=${BRAVE_USER_FLAGS:-"${BRAVE_FLAGS}"}

# Per-user flags, one or more per line; lines starting with # are comments.
user_conf=${XDG_CONFIG_HOME:-${HOME}/.config}/brave-flags.conf
if [[ -r ${user_conf} ]]; then
	BRAVE_FLAGS+=" $(sed -e 's/#.*//' "${user_conf}" | tr '\n' ' ')"
fi

if [[ ${EUID} == 0 && -O ${XDG_CONFIG_HOME:-${HOME}} ]]; then
	# Running as root with HOME owned by root.
	# Pass --user-data-dir to work around upstream failsafe.
	echo "Refusing to run as root is a safety feature. Running as root disables the sandbox." >&2
	BRAVE_FLAGS="--user-data-dir=${XDG_CONFIG_HOME:-${HOME}/.config}/BraveSoftware/@PROFILE_DIR@
		${BRAVE_FLAGS}"
fi

# Select session type and platform when both X11 and Wayland are built in
if [[ ${OZONE_AUTO_SESSION} == true ]]; then
	if [[ ${XDG_SESSION_TYPE} == x11 ]]; then
		platform=x11
	elif [[ ${XDG_SESSION_TYPE} == wayland || -n ${WAYLAND_DISPLAY} ]]; then
		platform=wayland
	else
		platform=x11
	fi
	if ${DISABLE_OZONE_PLATFORM:-false}; then
		platform=x11
	fi
	BRAVE_FLAGS="--ozone-platform=${platform} ${BRAVE_FLAGS}"
fi

# Release channel, as in Brave's own packages (otherwise "unknown").
export CHROME_VERSION_EXTRA="stable"
export CHROME_WRAPPER="$(readlink -f "$0")"
export CHROME_DESKTOP="brave-browser.desktop"

# Sanitise std{in,out,err} because they'll be shared with untrusted child
# processes (http://crbug.com/376567).
exec < /dev/null
exec > >(exec cat)
exec 2> >(exec cat >&2)

exec -a /usr/bin/brave-browser "${BRAVE_HOME}/brave" ${BRAVE_FLAGS} "$@"
