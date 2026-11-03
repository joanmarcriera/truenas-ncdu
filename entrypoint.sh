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
  NCDU_EXCLUDE_ZFS=true       Exclude .zfs snapshot directories from scans.
  NCDU_BIN=ncdu               Override ncdu binary, mainly for tests.
  TTYD_PORT=7681              Web terminal port for "truenas-ncdu web".
  TTYD_USER=admin             Web terminal username when TTYD_PASSWORD is set.
  TTYD_PASSWORD=              Web terminal password. Required for "web";
                              empty or placeholder values exit with code 64.
  TTYD_ALLOW_NO_AUTH=false    Set true to start "web" with no login prompt.

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

require_web_auth() {
  case "${TTYD_ALLOW_NO_AUTH:-false}" in
    true|TRUE|1|yes|YES|on|ON)
      return 0
      ;;
    false|FALSE|0|no|NO|off|OFF)
      ;;
    *)
      printf 'truenas-ncdu: invalid TTYD_ALLOW_NO_AUTH value: %s\n' "$TTYD_ALLOW_NO_AUTH" >&2
      printf 'truenas-ncdu: use true or false\n' >&2
      exit 64
      ;;
  esac

  if [ -z "${TTYD_PASSWORD:-}" ]; then
    printf 'truenas-ncdu: TTYD_PASSWORD is not set; refusing to start the web terminal without a login\n' >&2
  else
    password_lower=$(printf '%s' "$TTYD_PASSWORD" | tr '[:upper:]' '[:lower:]')
    case "$password_lower" in
      changeme|change-me|change_me|password|change-this-password)
        printf 'truenas-ncdu: TTYD_PASSWORD is a placeholder value; refusing to start the web terminal\n' >&2
        ;;
      *)
        return 0
        ;;
    esac
  fi

  printf 'truenas-ncdu: set TTYD_PASSWORD to a real password, or set TTYD_ALLOW_NO_AUTH=true to run without a login prompt\n' >&2
  exit 64
}

start_web_tui() {
  require_web_auth
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

case "${NCDU_EXCLUDE_ZFS:-true}" in
  true|TRUE|1|yes|YES|on|ON)
    set -- --exclude .zfs "$@"
    ;;
  false|FALSE|0|no|NO|off|OFF)
    ;;
  *)
    printf 'truenas-ncdu: invalid NCDU_EXCLUDE_ZFS value: %s\n' "$NCDU_EXCLUDE_ZFS" >&2
    printf 'truenas-ncdu: use true or false\n' >&2
    exit 64
    ;;
esac

case "${NCDU_ONE_FILESYSTEM:-true}" in
  true|TRUE|1|yes|YES|on|ON)
    set -- -x "$@"
    ;;
  false|FALSE|0|no|NO|off|OFF)
    ;;
  *)
    printf 'truenas-ncdu: invalid NCDU_ONE_FILESYSTEM value: %s\n' "$NCDU_ONE_FILESYSTEM" >&2
    printf 'truenas-ncdu: use true or false\n' >&2
    exit 64
    ;;
esac

exec "$ncdu_bin" "$@" "$scan_path"
