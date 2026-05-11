#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENTRYPOINT="$ROOT_DIR/entrypoint.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_equals() {
  expected=$1
  actual_file=$2
  actual=$(cat "$actual_file")
  [ "$actual" = "$expected" ] || fail "expected [$expected], got [$actual]"
}

make_ncdu_stub() {
  stub_dir=$1
  cat > "$stub_dir/ncdu-stub" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" > "$NCDU_STUB_OUTPUT"
STUB
  chmod +x "$stub_dir/ncdu-stub"
}

test_default_scans_mnt_with_one_filesystem_flag() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/scan" "$ENTRYPOINT"

  assert_file_equals "-x $tmp/scan" "$tmp/args"
  rm -rf "$tmp"
}

test_path_argument_overrides_default_path_and_preserves_options() {
  tmp=$(mktemp -d)
  mkdir "$tmp/default" "$tmp/media"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/default" \
    "$ENTRYPOINT" "$tmp/media" --exclude .zfs --color dark

  assert_file_equals "-x --exclude .zfs --color dark $tmp/media" "$tmp/args"
  rm -rf "$tmp"
}

test_one_filesystem_flag_can_be_disabled() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/scan" \
    NCDU_ONE_FILESYSTEM=false "$ENTRYPOINT"

  assert_file_equals "$tmp/scan" "$tmp/args"
  rm -rf "$tmp"
}

test_command_passthrough_allows_shell_access() {
  output=$("$ENTRYPOINT" sh -c 'printf shell-ok')
  [ "$output" = "shell-ok" ] || fail "expected shell passthrough, got [$output]"
}

test_missing_scan_path_fails_before_ncdu_runs() {
  tmp=$(mktemp -d)
  make_ncdu_stub "$tmp"

  if NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/missing" "$ENTRYPOINT" 2>"$tmp/stderr"; then
    fail "expected missing path to fail"
  fi

  grep -q "scan path does not exist" "$tmp/stderr" || fail "missing path error was not helpful"
  [ ! -f "$tmp/args" ] || fail "ncdu should not run for a missing path"
  rm -rf "$tmp"
}

test_default_scans_mnt_with_one_filesystem_flag
test_path_argument_overrides_default_path_and_preserves_options
test_one_filesystem_flag_can_be_disabled
test_command_passthrough_allows_shell_access
test_missing_scan_path_fails_before_ncdu_runs

printf 'ok - entrypoint behavior\n'
