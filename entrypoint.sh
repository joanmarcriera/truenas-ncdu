#!/bin/sh
set -eu

print_help() {
  cat <<'HELP'
truenas-ncdu - ncdu in a small container for TrueNAS SCALE

Usage:
  truenas-ncdu [SCAN_PATH] [NCDU_OPTIONS...]
  truenas-ncdu web
  truenas-ncdu --help-container
  truenas-ncdu COMMAND [ARGS...]

Environment:
  NCDU_PATH=/mnt              Default scan path when SCAN_PATH is omitted.
  NCDU_ONE_FILESYSTEM=true    Add ncdu -x so scans stay on one filesystem.
  NCDU_BIN=ncdu               Override ncdu binary, mainly for tests.
  TTYD_PORT=7681              Web terminal port for "truenas-ncdu web".
  TTYD_USER=admin             Web terminal username when TTYD_PASSWORD is set.
  TTYD_PASSWORD=              Optional web terminal password.

Examples:
  truenas-ncdu
  truenas-ncdu web
  truenas-ncdu /mnt/tank/media --exclude .zfs
  truenas-ncdu sleep infinity
  truenas-ncdu sh
HELP
}

validate_scan_path() {
  path=$1
  if [ ! -e "$path" ]; then
    printf 'truenas-ncdu: scan path does not exist: %s\n' "$path" >&2
    printf 'truenas-ncdu: mount a TrueNAS path into the container, for example -v /mnt:/mnt:ro\n' >&2
    exit 66
  fi

  if [ ! -d "$path" ]; then
    printf 'truenas-ncdu: scan path is not a directory: %s\n' "$path" >&2
    exit 66
  fi
}

start_web_tui() {
  scan_path=${NCDU_PATH:-/mnt}
  validate_scan_path "$scan_path"

  tmux_bin=${TMUX_BIN:-tmux}
  ttyd_bin=${TTYD_BIN:-ttyd}
  session=${NCDU_TMUX_SESSION:-truenas-ncdu}
  ttyd_port=${TTYD_PORT:-7681}
  ttyd_user=${TTYD_USER:-admin}
  ncdu_cmd=${NCDU_WEB_CMD:-/usr/local/bin/truenas-ncdu}

  if ! "$tmux_bin" has-session -t "$session" >/dev/null 2>&1; then
    "$tmux_bin" new-session -d -s "$session" "$ncdu_cmd"
  fi

  set -- --port "$ttyd_port" --writable
  if [ -n "${TTYD_PASSWORD:-}" ]; then
    set -- "$@" --credential "$ttyd_user:$TTYD_PASSWORD"
  else
    printf 'truenas-ncdu: warning: TTYD_PASSWORD is not set; web terminal has no login prompt\n' >&2
  fi

  exec "$ttyd_bin" "$@" sh -lc "exec $tmux_bin attach-session -t $session"
}

if [ "${1:-}" = "--help-container" ] || [ "${1:-}" = "help" ]; then
  print_help
  exit 0
fi

if [ "${1:-}" = "--version" ] || [ "${1:-}" = "version" ]; then
  printf '%s\n' "${TRUENAS_NCDU_VERSION:-unknown}"
  exit 0
fi

if [ "${1:-}" = "web" ]; then
  start_web_tui
fi

case "${1:-}" in
  --)
    shift
    exec "$@"
    ;;
  sh|/bin/sh|bash|/bin/bash|sleep|/bin/sleep|tail|/usr/bin/tail|cat|/bin/cat|ncdu|/usr/bin/ncdu)
    exec "$@"
    ;;
esac

scan_path=${NCDU_PATH:-/mnt}

if [ "$#" -gt 0 ]; then
  case "$1" in
    -*)
      ;;
    *)
      scan_path=$1
      shift
      ;;
  esac
fi

validate_scan_path "$scan_path"

ncdu_bin=${NCDU_BIN:-ncdu}

case "${NCDU_ONE_FILESYSTEM:-true}" in
  true|TRUE|1|yes|YES|on|ON)
    exec "$ncdu_bin" -x "$@" "$scan_path"
    ;;
  false|FALSE|0|no|NO|off|OFF)
    exec "$ncdu_bin" "$@" "$scan_path"
    ;;
  *)
    printf 'truenas-ncdu: invalid NCDU_ONE_FILESYSTEM value: %s\n' "$NCDU_ONE_FILESYSTEM" >&2
    printf 'truenas-ncdu: use true or false\n' >&2
    exit 64
    ;;
esac
