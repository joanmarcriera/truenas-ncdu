# truenas-ncdu

Run `ncdu` against TrueNAS SCALE datasets from a small container.

TrueNAS SCALE does not ship `ncdu` on the host appliance. This repository packages `ncdu` in a container so you can inspect dataset usage without installing packages on TrueNAS itself.

## What This Provides

- Alpine-based container with `ncdu` and `tini`.
- Safe default scan path: `/mnt`.
- `ncdu -x` enabled by default to avoid crossing filesystem boundaries.
- Read-only mount examples for TrueNAS datasets.
- GitHub Actions CI and Docker Hub publishing workflow.
- TrueNAS SCALE direct Docker and Custom App/YAML instructions.

## Quick Use

Run this from a TrueNAS SCALE shell:

```bash
docker run --rm -it \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -v /mnt:/mnt:ro \
  docker.io/joanmarcriera/truenas-ncdu:latest
```

Scan one dataset:

```bash
docker run --rm -it \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -v /mnt:/mnt:ro \
  docker.io/joanmarcriera/truenas-ncdu:latest \
  /mnt/tank/media
```

The `/mnt` host mount is read-only, so this mode is for inspection rather than deletion.

## Build Locally

```bash
make build
make run SCAN_PATH=/mnt
```

Or without `make`:

```bash
docker build -t truenas-ncdu:dev .
docker run --rm -it -v /mnt:/mnt:ro truenas-ncdu:dev
```

## TrueNAS SCALE App Setup

Use this path when you want `ncdu` available as a TrueNAS app rather than typing a `docker run` command over SSH.

In the TrueNAS SCALE web UI:

1. Open **Apps**.
2. Click **Discover Apps**.
3. Click **Custom App**.
4. Set **Application Name** to `truenas-ncdu`.
5. In **Image Configuration**, set:

```text
Repository: joanmarcriera/truenas-ncdu
Tag: latest
Pull Policy: Only pull image if not present on host
```

6. In **Container Configuration**, leave **Entrypoint** empty and add these **Command** entries, one value per field:

```text
sleep
infinity
```

Do not add `--` or `---` as a command entry.

This keeps the app running as a small toolbox container. You then open a shell into the app and run `truenas-ncdu` interactively.

7. Still in **Container Configuration**, enable:

```text
TTY: enabled
Stdin: enabled
Restart Policy: Unless Stopped
```

8. Add environment variables:

```text
NCDU_PATH=/mnt/BigDisk
NCDU_ONE_FILESYSTEM=true
```

Change `NCDU_PATH` if you mount a different dataset path.

9. In **Network Configuration**, do not add ports. `ncdu` has no web UI.
10. In **Storage Configuration**, click **Add** and choose **Host Path**.
11. Select only the dataset or pool path you want `ncdu` to read. For the BigDisk scenario:

```text
Type: Host Path
Host Path: /mnt/BigDisk
Mount Path: /mnt/BigDisk
Read Only: enabled
```

Use read-only mounts for normal inspection. If you want to scan multiple datasets, add one Host Path entry per dataset, or mount `/mnt` to `/mnt` read-only if you deliberately want broad visibility.

12. Save the app.
13. After it starts, open the app shell from the installed app workload options.
14. Run:

```bash
truenas-ncdu
```

Or scan a subdirectory:

```bash
truenas-ncdu /mnt/BigDisk/media
```

If the app shell shows permission errors, check the dataset ACL for the mounted path and make sure the app user can read and traverse the dataset. The mount should still stay read-only unless you intentionally want delete support from inside `ncdu`.

## TrueNAS YAML for BigDisk

TrueNAS also supports installing custom apps from YAML. Go to **Apps > Discover Apps**, open the menu at the top right, choose **Install via YAML**, name the app `truenas-ncdu`, and paste this Compose YAML:

```yaml
services:
  truenas-ncdu:
    image: docker.io/joanmarcriera/truenas-ncdu:latest
    container_name: truenas-ncdu
    command: ["sleep", "infinity"]
    stdin_open: true
    tty: true
    network_mode: none
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
    environment:
      NCDU_PATH: /mnt/BigDisk
      NCDU_ONE_FILESYSTEM: "true"
    volumes:
      - type: bind
        source: /mnt/BigDisk
        target: /mnt/BigDisk
        read_only: true
```

This same YAML is available at [`examples/compose.bigdisk.yaml`](examples/compose.bigdisk.yaml). The generic `/mnt` example remains at [`examples/compose.truenas.yaml`](examples/compose.truenas.yaml).

After the app starts, open a shell into the container and run:

```bash
truenas-ncdu
```

See [docs/truenas-scale.md](docs/truenas-scale.md) for extra TrueNAS notes, including permissions and interactive terminal trade-offs.

## Publish to Docker Hub

The repository includes [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml).

Add this GitHub repository secret:

- `DOCKERHUB_TOKEN`

Then run the workflow manually, or tag a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

More detail is in [docs/dockerhub-publish.md](docs/dockerhub-publish.md).

## Container Interface

```bash
truenas-ncdu [SCAN_PATH] [NCDU_OPTIONS...]
```

Environment variables:

- `NCDU_PATH`: default scan path. Defaults to `/mnt`.
- `NCDU_ONE_FILESYSTEM`: `true` or `false`. Defaults to `true`.
- `NCDU_BIN`: override the binary, mainly for tests.

Examples:

```bash
docker run --rm -it -v /mnt:/mnt:ro docker.io/joanmarcriera/truenas-ncdu:latest /mnt/tank/media --exclude .zfs
docker run --rm -it -v /mnt:/mnt:ro -e NCDU_ONE_FILESYSTEM=false docker.io/joanmarcriera/truenas-ncdu:latest
docker run --rm -it -v /mnt:/mnt:ro docker.io/joanmarcriera/truenas-ncdu:latest sh
```

## Development

```bash
sh scripts/test.sh
```

The tests cover the shell entrypoint and build the Docker image when Docker is available.

## References

- [TrueNAS 25.04 Apps UI reference](https://www.truenas.com/docs/scale/25.04/scaleuireference/apps/)
- [TrueNAS 25.04 Custom App screens](https://www.truenas.com/docs/scale/25.04/scaleuireference/apps/installcustomappscreens/)
- [TrueNAS Apps Market: Installing Custom Apps](https://apps.truenas.com/managing-apps/installing-custom-apps/)
