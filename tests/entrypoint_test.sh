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

make_tmux_stub() {
  stub_dir=$1
  cat > "$stub_dir/tmux-stub" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$TMUX_STUB_OUTPUT"
if [ "${1:-}" = "has-session" ]; then
  exit 1
fi
exit 0
STUB
  chmod +x "$stub_dir/tmux-stub"
}

make_ttyd_stub() {
  stub_dir=$1
  cat > "$stub_dir/ttyd-stub" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" > "$TTYD_STUB_OUTPUT"
STUB
  chmod +x "$stub_dir/ttyd-stub"
}

test_default_scans_mnt_with_one_filesystem_flag() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/scan" "$ENTRYPOINT"

  assert_file_equals "-x --exclude .zfs $tmp/scan" "$tmp/args"
  rm -rf "$tmp"
}

test_path_argument_overrides_default_path_and_preserves_options() {
  tmp=$(mktemp -d)
  mkdir "$tmp/default" "$tmp/media"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/default" \
    "$ENTRYPOINT" "$tmp/media" --color dark

  assert_file_equals "-x --exclude .zfs --color dark $tmp/media" "$tmp/args"
  rm -rf "$tmp"
}

test_one_filesystem_flag_can_be_disabled() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/scan" \
    NCDU_ONE_FILESYSTEM=false "$ENTRYPOINT"

  assert_file_equals "--exclude .zfs $tmp/scan" "$tmp/args"
  rm -rf "$tmp"
}

test_zfs_snapshot_exclusion_can_be_disabled() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_ncdu_stub "$tmp"

  NCDU_BIN="$tmp/ncdu-stub" NCDU_STUB_OUTPUT="$tmp/args" NCDU_PATH="$tmp/scan" \
    NCDU_EXCLUDE_ZFS=false "$ENTRYPOINT"

  assert_file_equals "-x $tmp/scan" "$tmp/args"
  rm -rf "$tmp"
}

test_command_passthrough_allows_shell_access() {
  output=$("$ENTRYPOINT" sh -c 'printf shell-ok')
  [ "$output" = "shell-ok" ] || fail "expected shell passthrough, got [$output]"
}

test_version_reports_environment_version() {
  output=$(TRUENAS_NCDU_VERSION=9.9.9 "$ENTRYPOINT" --version)
  [ "$output" = "9.9.9" ] || fail "expected version output, got [$output]"
}

test_sleep_command_passthrough_supports_truenas_command_fields() {
  "$ENTRYPOINT" sleep 0 || fail "expected sleep command passthrough"
}

test_web_mode_starts_tmux_session_and_ttyd() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_tmux_stub "$tmp"
  make_ttyd_stub "$tmp"

  TMUX_BIN="$tmp/tmux-stub" TTYD_BIN="$tmp/ttyd-stub" \
    TMUX_STUB_OUTPUT="$tmp/tmux-args" TTYD_STUB_OUTPUT="$tmp/ttyd-args" \
    NCDU_PATH="$tmp/scan" TTYD_PASSWORD="secret" "$ENTRYPOINT" web

  assert_file_equals "has-session -t truenas-ncdu
new-session -d -s truenas-ncdu /usr/local/bin/truenas-ncdu" "$tmp/tmux-args"
  assert_file_equals "--port 7681 --writable --credential admin:secret sh -lc exec $tmp/tmux-stub attach-session -t truenas-ncdu" "$tmp/ttyd-args"
  rm -rf "$tmp"
}

# Runs web mode with stubbed tmux/ttyd. Extra VAR=value arguments are passed
# through env so a test can set or omit TTYD_PASSWORD and TTYD_ALLOW_NO_AUTH.
run_web_with_stubs() {
  tmp=$1
  shift
  env -u TTYD_PASSWORD -u TTYD_ALLOW_NO_AUTH -u TTYD_USER \
    TMUX_BIN="$tmp/tmux-stub" TTYD_BIN="$tmp/ttyd-stub" \
    TMUX_STUB_OUTPUT="$tmp/tmux-args" TTYD_STUB_OUTPUT="$tmp/ttyd-args" \
    NCDU_PATH="$tmp/scan" "$@" "$ENTRYPOINT" web 2>"$tmp/stderr"
}

make_web_fixture() {
  tmp=$(mktemp -d)
  mkdir "$tmp/scan"
  make_tmux_stub "$tmp"
  make_ttyd_stub "$tmp"
  printf '%s\n' "$tmp"
}

assert_web_refused() {
  tmp=$1
  label=$2
  shift 2
  status=0
  run_web_with_stubs "$tmp" "$@" || status=$?
  [ "$status" -eq 64 ] || fail "$label: expected exit 64, got $status"
  grep -q "refusing to start the web terminal" "$tmp/stderr" || fail "$label: stderr did not explain the refusal"
  grep -q "TTYD_ALLOW_NO_AUTH=true" "$tmp/stderr" || fail "$label: stderr did not name the opt-out"
  [ ! -f "$tmp/tmux-args" ] || fail "$label: tmux should not run"
  [ ! -f "$tmp/ttyd-args" ] || fail "$label: ttyd should not run"
  rm -f "$tmp/stderr"
}

test_web_mode_refuses_unset_password() {
  tmp=$(make_web_fixture)
  assert_web_refused "$tmp" "unset TTYD_PASSWORD"
  rm -rf "$tmp"
}

test_web_mode_refuses_empty_password() {
  tmp=$(make_web_fixture)
  assert_web_refused "$tmp" "empty TTYD_PASSWORD" TTYD_PASSWORD=
  rm -rf "$tmp"
}

test_web_mode_refuses_placeholder_passwords() {
  for placeholder in changeme change-me password CHANGE_ME ChangeMe PASSWORD change-this-password; do
    tmp=$(make_web_fixture)
    assert_web_refused "$tmp" "placeholder [$placeholder]" TTYD_PASSWORD="$placeholder"
    rm -rf "$tmp"
  done
}

test_web_mode_placeholder_error_does_not_echo_password() {
  tmp=$(make_web_fixture)
  run_web_with_stubs "$tmp" TTYD_PASSWORD=ChangeMe || true
  if grep -q "ChangeMe" "$tmp/stderr"; then
    fail "placeholder error should not print the password value"
  fi
  rm -rf "$tmp"
}

test_web_mode_allows_no_auth_when_opted_in() {
  tmp=$(make_web_fixture)

  run_web_with_stubs "$tmp" TTYD_ALLOW_NO_AUTH=true || fail "expected opt-out to start web mode"

  grep -q "warning: TTYD_PASSWORD is not set" "$tmp/stderr" || fail "opt-out should keep the no-password warning"
  assert_file_equals "has-session -t truenas-ncdu
new-session -d -s truenas-ncdu /usr/local/bin/truenas-ncdu" "$tmp/tmux-args"
  if grep -q -- "--credential" "$tmp/ttyd-args"; then
    fail "opt-out without a password should not pass --credential"
  fi
  rm -rf "$tmp"
}

test_web_mode_rejects_invalid_allow_no_auth_value() {
  tmp=$(make_web_fixture)
  status=0
  run_web_with_stubs "$tmp" TTYD_ALLOW_NO_AUTH=maybe || status=$?
  [ "$status" -eq 64 ] || fail "invalid TTYD_ALLOW_NO_AUTH: expected exit 64, got $status"
  grep -q "invalid TTYD_ALLOW_NO_AUTH value" "$tmp/stderr" || fail "invalid TTYD_ALLOW_NO_AUTH error was not helpful"
  [ ! -f "$tmp/tmux-args" ] || fail "invalid TTYD_ALLOW_NO_AUTH: tmux should not run"
  [ ! -f "$tmp/ttyd-args" ] || fail "invalid TTYD_ALLOW_NO_AUTH: ttyd should not run"
  rm -rf "$tmp"
}

test_web_mode_passes_real_credential() {
  tmp=$(make_web_fixture)

  run_web_with_stubs "$tmp" TTYD_USER=user TTYD_PASSWORD=pass || fail "expected a real password to start web mode"

  grep -q -- "--credential user:pass " "$tmp/ttyd-args" || fail "expected --credential user:pass, got [$(cat "$tmp/ttyd-args")]"
  if grep -q "warning" "$tmp/stderr"; then
    fail "a real password should not print the no-password warning"
  fi
  rm -rf "$tmp"
}

test_help_documents_allow_no_auth() {
  "$ENTRYPOINT" --help-container | grep -q "TTYD_ALLOW_NO_AUTH" || fail "--help-container should document TTYD_ALLOW_NO_AUTH"
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
test_zfs_snapshot_exclusion_can_be_disabled
test_command_passthrough_allows_shell_access
test_version_reports_environment_version
test_sleep_command_passthrough_supports_truenas_command_fields
test_web_mode_starts_tmux_session_and_ttyd
test_missing_scan_path_fails_before_ncdu_runs
test_web_mode_refuses_unset_password
test_web_mode_refuses_empty_password
test_web_mode_refuses_placeholder_passwords
test_web_mode_placeholder_error_does_not_echo_password
test_web_mode_allows_no_auth_when_opted_in
test_web_mode_rejects_invalid_allow_no_auth_value
test_web_mode_passes_real_credential
test_help_documents_allow_no_auth

printf 'ok - entrypoint behavior\n'
