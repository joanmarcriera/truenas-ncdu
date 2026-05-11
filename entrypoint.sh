#!/bin/sh
set -eu

print_help() {
  cat <<'HELP'
truenas-ncdu - ncdu in a small container for TrueNAS SCALE

Usage:
  truenas-ncdu [SCAN_PATH] [NCDU_OPTIONS...]
  truenas-ncdu --help-container
  truenas-ncdu COMMAND [ARGS...]

Environment:
  NCDU_PATH=/mnt              Default scan path when SCAN_PATH is omitted.
  NCDU_ONE_FILESYSTEM=true    Add ncdu -x so scans stay on one filesystem.
  NCDU_BIN=ncdu               Override ncdu binary, mainly for tests.

Examples:
  truenas-ncdu
  truenas-ncdu /mnt/tank/media --exclude .zfs
  truenas-ncdu sleep infinity
  truenas-ncdu sh
HELP
}

if [ "${1:-}" = "--help-container" ] || [ "${1:-}" = "help" ]; then
  print_help
  exit 0
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

if [ ! -e "$scan_path" ]; then
  printf 'truenas-ncdu: scan path does not exist: %s\n' "$scan_path" >&2
  printf 'truenas-ncdu: mount a TrueNAS path into the container, for example -v /mnt:/mnt:ro\n' >&2
  exit 66
fi

if [ ! -d "$scan_path" ]; then
  printf 'truenas-ncdu: scan path is not a directory: %s\n' "$scan_path" >&2
  exit 66
fi

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
