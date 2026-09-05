# truenas-ncdu CLAUDE.md

## Purpose

A minimal, secure Alpine-based Docker container that bundles `ncdu` (Ncurses Disk Usage) for inspection of TrueNAS SCALE datasets without modifying the host appliance. Runs two modes: CLI (read-only scan) and web (browser terminal via `ttyd` + `tmux`).

## How to Run & Test

```bash
# Test (shell linting + unit tests + Docker build if available)
make test

# Build locally
make build

# Run CLI scan (read-only, one filesystem only)
make run SCAN_PATH=/mnt/tank/media

# Run web mode (browser terminal on http://localhost:7681)
make web SCAN_PATH=/mnt/tank/media

# Shell into container
make shell SCAN_PATH=/mnt
```

Direct Docker commands are shown in the Makefile and README.md.

## Layout

```
entrypoint.sh                   # Main entry point: 138 lines, all logic here
Dockerfile                      # Alpine 3.22 + ncdu/tini/tmux/ttyd
Makefile                        # Build/test/run targets with sensible defaults
scripts/test.sh                 # Runs entrypoint linting, unit tests, Docker build
tests/entrypoint_test.sh        # Shell unit tests with function stubs
tests/dockerfile_contract_test.sh  # Dockerfile content checks
examples/compose.*.yaml         # Docker Compose for BigDisk and generic /mnt setups
docs/                           # TrueNAS-specific setup, ZFS snapshots, publishing
.github/workflows/              # CI (PR/main push) and manual Docker Hub publish
```

## Conventions

- **Shell-first**: all business logic in `entrypoint.sh`; portable POSIX sh (not bash).
- **Test-driven**: add tests to `tests/entrypoint_test.sh` *before* new behavior.
- **Safety defaults**: read-only host mounts, dropped capabilities, ZFS snapshot exclusion, no network. Examples preserve these.
- **One filesystem by default**: `-x` flag prevents crossing mount boundaries (NCDU_ONE_FILESYSTEM=true).
- **No host modifications**: zero write operations to TrueNAS; purely inspect-mode.

## How It Works

**CLI mode** (default):
1. Validates SCAN_PATH directory exists.
2. Builds `ncdu` command with flags: `-x` (one fs) and `--exclude .zfs` (snapshots).
3. Environment variables control behavior: NCDU_PATH, NCDU_ONE_FILESYSTEM, NCDU_EXCLUDE_ZFS.
4. Runs `ncdu` interactively in the container.

**Web mode** (`truenas-ncdu web`):
1. Starts a persistent `tmux` session running `ncdu` (detached).
2. Serves that session via `ttyd` browser terminal on port 7681.
3. Requires TTYD_PASSWORD for login (recommended; unset = no auth).
4. Reattach with `truenas-ncdu` command inside the browser terminal to restart scan.

**Entrypoint logic**:
- `--help-container` / `help`: Show usage (same as entrypoint.sh header).
- `--version` / `version`: Print TRUENAS_NCDU_VERSION.
- `web`: Start web mode.
- `sh` / `bash` / `sleep` / `tail` / `cat` / `ncdu`: Pass through directly.
- `--`: Execute raw command.
- Default: scan SCAN_PATH with ncdu, respecting flags.

## Gotchas

1. **Web mode defaults to startup**: Dockerfile `CMD ["web"]` starts browser terminal by default. If you want CLI mode, override: `docker run ... --entrypoint ... /mnt`.

2. **ZFS snapshot size inflation**: If Time Machine or other ZFS-backed datasets report impossibly large sizes, check `NCDU_EXCLUDE_ZFS=true` (default) and see `docs/time-machine-zfs-snapshots.md`. Visible `.zfs/snapshot` trees aren't live files.

3. **TTYD_PASSWORD required for auth**: If not set, web terminal has no login prompt (warning on startup). Always set a password in production.

4. **Mount paths must be readable**: ACL issues on the dataset may block the scan. Test with a simple `ls` from the container first.

5. **tmux session persists**: Stopping the container will kill `ttyd` but not the tmux session if you used `docker exec ... sh`. Always use `docker stop` or run with `--rm`.

6. **NCDU_EXCLUDE_ZFS logic**: Environment variable accepts true/false/1/0/yes/no/on/off (case-insensitive). Invalid values exit with code 64.

## Versioning & Publishing

Version lives in `Dockerfile` as `TRUENAS_NCDU_VERSION`. Tag releases in git (`git tag v0.2.2`), then trigger `.github/workflows/docker-publish.yml` manually to build and push to Docker Hub. See `docs/dockerhub-publish.md` for secrets setup.

## Known Limitations

- No delete support in default (read-only) mode; intended for inspection only.
- `ttyd` web terminal requires JavaScript and modern browser (no IE11 or older).
- Single tmux session per container; concurrent users will share the same ncdu instance.
