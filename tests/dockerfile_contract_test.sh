#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DOCKERFILE="$ROOT_DIR/Dockerfile"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

grep -Fq 'CMD ["web"]' "$DOCKERFILE" || fail 'Dockerfile default command must start web mode'
grep -Fq 'EXPOSE 7681' "$DOCKERFILE" || fail 'Dockerfile must expose the web terminal port'

printf 'ok - Dockerfile startup contract\n'
