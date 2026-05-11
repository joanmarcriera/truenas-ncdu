#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$ROOT_DIR/entrypoint.sh"
sh "$ROOT_DIR/tests/entrypoint_test.sh"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  DOCKER_PLATFORM=${DOCKER_PLATFORM:-linux/amd64}
  docker build --pull=false --platform "$DOCKER_PLATFORM" -t truenas-ncdu:test "$ROOT_DIR"
else
  printf 'skip - docker daemon not available; container build was not run\n'
fi
