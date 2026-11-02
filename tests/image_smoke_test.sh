#!/bin/sh
# Smoke-test a built truenas-ncdu image.
#
# Usage:
#   sh tests/image_smoke_test.sh IMAGE_TAG
#
# Example:
#   docker build -t truenas-ncdu:test . && sh tests/image_smoke_test.sh truenas-ncdu:test
#
# Checks, each in a throwaway container:
#   1. --help-container exits 0 and prints the usage text.
#   2. web without TTYD_PASSWORD exits 64 (no tmux/ttyd started).
#   3. ncdu is installed and runs.
#   4. A scan of a small read-only (:ro) fixture works, finds the fixture
#      files and does not descend into .zfs.
#
# Needs a running Docker daemon. Exits non-zero on the first failure.
set -eu

usage() {
  printf 'usage: sh tests/image_smoke_test.sh IMAGE_TAG\n' >&2
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  usage
  exit 64
fi

IMAGE=$1
SMOKE_TIMEOUT=${SMOKE_TIMEOUT:-60}
NAME_PREFIX="truenas-ncdu-smoke-$$"
FIXTURE_DIR=$(mktemp -d)
OUT_FILE=$(mktemp)

cleanup() {
  for suffix in help web ncdu scan; do
    docker rm -f "$NAME_PREFIX-$suffix" >/dev/null 2>&1 || true
  done
  rm -rf "$FIXTURE_DIR" "$OUT_FILE"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'not ok - image smoke: %s\n' "$1" >&2
  if [ -s "$OUT_FILE" ]; then
    printf '# output:\n' >&2
    sed 's/^/#   /' "$OUT_FILE" >&2
  fi
  exit 1
}

# run_container SUFFIX DOCKER_RUN_ARGS...
# Runs a named container with stdout+stderr in $OUT_FILE and sets $rc.
# A timeout stops a container that hangs (for example a web terminal that
# started when it should have refused).
run_container() {
  suffix=$1
  shift
  if command -v timeout >/dev/null 2>&1; then
    set -- timeout "$SMOKE_TIMEOUT" docker run --rm --name "$NAME_PREFIX-$suffix" "$@"
  else
    set -- docker run --rm --name "$NAME_PREFIX-$suffix" "$@"
  fi
  if "$@" >"$OUT_FILE" 2>&1; then
    rc=0
  else
    rc=$?
  fi
}

# 1. --help-container exits 0.
run_container help "$IMAGE" --help-container
[ "$rc" -eq 0 ] || fail "--help-container exited $rc, expected 0"
grep -q 'Usage:' "$OUT_FILE" || fail '--help-container did not print usage'
printf 'ok - image smoke: --help-container exits 0\n'

# 2. web without TTYD_PASSWORD exits 64.
run_container web -e TTYD_PASSWORD= "$IMAGE" web
[ "$rc" -eq 64 ] || fail "web without TTYD_PASSWORD exited $rc, expected 64"
grep -q 'TTYD_PASSWORD' "$OUT_FILE" || fail 'web refusal did not mention TTYD_PASSWORD'
printf 'ok - image smoke: web without TTYD_PASSWORD exits 64\n'

# 3. ncdu is present.
run_container ncdu "$IMAGE" ncdu --version
[ "$rc" -eq 0 ] || fail "ncdu --version exited $rc, expected 0"
grep -qi 'ncdu' "$OUT_FILE" || fail 'ncdu --version did not identify ncdu'
printf 'ok - image smoke: ncdu present (%s)\n' "$(head -n 1 "$OUT_FILE")"

# 4. Scan a small read-only fixture through the default entrypoint path.
mkdir -p "$FIXTURE_DIR/data/nested" "$FIXTURE_DIR/data/.zfs/snapshot/daily"
printf 'smoke\n' >"$FIXTURE_DIR/data/smoke-top-file.txt"
printf 'smoke nested\n' >"$FIXTURE_DIR/data/nested/smoke-nested-file.txt"
printf 'snapshot\n' >"$FIXTURE_DIR/data/.zfs/snapshot/daily/smoke-snapshot-only-file.txt"
chmod -R a+rX "$FIXTURE_DIR"

# truenas-ncdu /fixture -0 -o - => ncdu -x --exclude .zfs -0 -o - /fixture
run_container scan -v "$FIXTURE_DIR/data:/fixture:ro" "$IMAGE" /fixture -0 -o -
[ "$rc" -eq 0 ] || fail "scan of :ro fixture exited $rc, expected 0"
grep -q 'smoke-top-file.txt' "$OUT_FILE" || fail 'scan output is missing smoke-top-file.txt'
grep -q 'smoke-nested-file.txt' "$OUT_FILE" || fail 'scan output is missing nested/smoke-nested-file.txt'
if grep -q 'smoke-snapshot-only-file.txt' "$OUT_FILE"; then
  fail 'scan descended into .zfs although NCDU_EXCLUDE_ZFS defaults to true'
fi
printf 'ok - image smoke: scan of :ro fixture works and skips .zfs\n'

printf 'ok - image smoke: all checks passed for %s\n' "$IMAGE"
