#!/bin/sh
# Checks that README.md still matches the entrypoint usage text, the
# Dockerfile version and the published image name.
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
README="$ROOT_DIR/README.md"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

help_text=$(sh "$ROOT_DIR/entrypoint.sh" --help-container)

# Every usage line in --help-container appears verbatim in the README.
printf '%s\n' "$help_text" | sed -n '/^Usage:/,/^$/p' | sed -n 's/^  \(truenas-ncdu.*\)$/\1/p' |
  while IFS= read -r line; do
    grep -Fqx -- "$line" "$README" || fail "README is missing usage line: $line"
  done

# Every environment variable in --help-container is documented in the README.
printf '%s\n' "$help_text" | sed -n '/^Environment:/,/^$/p' | sed -n 's/^  \([A-Z_]*\)=.*/\1/p' |
  while IFS= read -r var; do
    grep -Fq -- "\`$var\`" "$README" || fail "README does not document $var"
  done

# Image tags in the README and examples match the Dockerfile version.
version=$(sed -n 's/^ENV TRUENAS_NCDU_VERSION=//p' "$ROOT_DIR/Dockerfile")
[ -n "$version" ] || fail 'Dockerfile has no TRUENAS_NCDU_VERSION'
for f in "$README" "$ROOT_DIR"/examples/*.yaml; do
  grep -o 'joanmarcriera/truenas-ncdu:[0-9][0-9.]*' "$f" | while IFS= read -r ref; do
    [ "$ref" = "joanmarcriera/truenas-ncdu:$version" ] || fail "$f uses $ref, Dockerfile is $version"
  done
done
grep -Fqx "Tag: $version" "$README" || fail "README Custom App tag is not $version"

# The image name in the README is the one the publish workflow pushes.
image=$(sed -n 's/^  IMAGE_NAME: //p' "$ROOT_DIR/.github/workflows/docker-publish.yml")
grep -Fq "$image:latest" "$README" || fail "README does not use $image"

printf 'ok - README matches usage text and image version\n'
