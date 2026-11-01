#!/bin/bash
# Cron entry point of auto-update.py: one run at a time, sane environment, log file.
#
#   crontab: 0 22 * * 6  [AUTO_UPDATE_SCRATCH=<big disk dir>] <overlay checkout>/tools/auto-update/cron.sh

set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 1
repo=$(git -C "${here}" rev-parse --path-format=absolute --git-common-dir) || exit 1
repo=${repo%/.git}
work=${repo}/.work/auto-update
mkdir -p "${work}/logs" || exit 1

export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/bin"
export LANG=${LANG:-C.UTF-8}
# notify-send needs the user's session bus
if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} && -S /run/user/${UID}/bus ]]; then
	export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID}/bus
fi

exec 9>"${work}/lock"
if ! flock -n 9; then
	echo "another auto-update run is still going" >&2
	exit 0
fi

log=${work}/logs/cron-$(date +%Y%m%d-%H%M%S).log
cd "${repo}" || exit 1
ionice -c 3 nice -n 10 "${here}/auto-update.py" "$@" >"${log}" 2>&1
status=$?
# Keep the logs of the last ~3 months
find "${work}/logs" -mindepth 1 -maxdepth 1 -mtime +90 -exec rm -rf {} + 2>/dev/null
exit ${status}
