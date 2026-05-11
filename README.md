# truenas-ncdu

Run `ncdu` against TrueNAS SCALE datasets from a small container.

TrueNAS SCALE does not ship `ncdu` on the host appliance. This repository packages `ncdu` in a container so you can inspect dataset usage without installing packages on TrueNAS itself.

## What This Provides

- Alpine-based container with `ncdu` and `tini`.
- Safe default scan path: `/mnt`.
- `ncdu -x` enabled by default to avoid crossing filesystem boundaries.
- Browser terminal mode through `ttyd`, backed by a persistent `tmux` session.
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
  docker.io/joanmarcriera/truenas-ncdu:latest \
  /mnt
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

## TrueNAS SCALE Web App Setup

Use this path when you want `ncdu` available in a browser as a TrueNAS app. The container starts a detached `tmux` session running `ncdu`, then serves that TUI through `ttyd` on port `7681`.

In the TrueNAS SCALE web UI:

1. Open **Apps**.
2. Click **Discover Apps**.
3. Click **Custom App**.
4. Set **Application Name** to `truenas-ncdu`.
5. In **Image Configuration**, set:

```text
Repository: joanmarcriera/truenas-ncdu
Tag: 0.2.1
Pull Policy: Always pull an image even if it is present on the host
```

6. In **Container Configuration**, leave **Entrypoint** empty and leave **Command** empty.

The image defaults to web mode, so the browser terminal server starts when the app boots.

7. Set:

```text
Restart Policy: Unless Stopped
```

TTY and Stdin are not required for web mode.

8. Add environment variables. Choose your own `TTYD_PASSWORD` before saving the app:

```text
NCDU_PATH=/mnt/BigDisk
NCDU_ONE_FILESYSTEM=true
TTYD_USER=admin
TTYD_PASSWORD=<choose-a-password>
```

Change `NCDU_PATH` if you mount a different dataset path.

9. In **Network Configuration**, add a TCP port:

```text
Container Port: 7681
Host Port: 7681
Protocol: TCP
```

If host port `7681` is already in use, choose another host port and keep the container port as `7681`.

10. Optional: in **Portal Configuration**, add an HTTP portal pointing at host port `7681`.
11. In **Storage Configuration**, click **Add** and choose **Host Path**.
12. Select only the dataset or pool path you want `ncdu` to read. For the BigDisk scenario:

```text
Type: Host Path
Host Path: /mnt/BigDisk
Mount Path: /mnt/BigDisk
Read Only: enabled
```

Use read-only mounts for normal inspection. If you want to scan multiple datasets, add one Host Path entry per dataset, or mount `/mnt` to `/mnt` read-only if you deliberately want broad visibility.

13. Save the app.
14. Open the browser terminal:

```text
http://<truenas-ip>:7681
```

Log in with `TTYD_USER` and `TTYD_PASSWORD`. The browser attaches to the running `ncdu` TUI. To restart the scan from inside the browser terminal, press `q` to quit `ncdu`, then run:

```bash
truenas-ncdu
```

If the app shell shows permission errors, check the dataset ACL for the mounted path and make sure the app user can read and traverse the dataset. The mount should still stay read-only unless you intentionally want delete support from inside `ncdu`.

## TrueNAS YAML for BigDisk

TrueNAS also supports installing custom apps from YAML. Go to **Apps > Discover Apps**, open the menu at the top right, choose **Install via YAML**, name the app `truenas-ncdu`, and paste this Compose YAML:

```yaml
services:
  truenas-ncdu:
    image: docker.io/joanmarcriera/truenas-ncdu:0.2.1
    container_name: truenas-ncdu
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
      TTYD_USER: admin
      TTYD_PASSWORD: change-this-password
    ports:
      - "7681:7681"
    volumes:
      - type: bind
        source: /mnt/BigDisk
        target: /mnt/BigDisk
        read_only: true
```

This same YAML is available at [`examples/compose.bigdisk.yaml`](examples/compose.bigdisk.yaml). The generic `/mnt` example remains at [`examples/compose.truenas.yaml`](examples/compose.truenas.yaml).

After the app starts, open `http://<truenas-ip>:7681` and log in with `admin` plus the password you configured.

See [docs/truenas-scale.md](docs/truenas-scale.md) for extra TrueNAS notes, including permissions and interactive terminal trade-offs.

## Publish to Docker Hub

The repository includes [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml).

Add this GitHub repository secret:

- `DOCKERHUB_TOKEN`

Then run the workflow manually. To tag a release in git:

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
docker run --rm -it -v /mnt:/mnt:ro -e NCDU_ONE_FILESYSTEM=false docker.io/joanmarcriera/truenas-ncdu:latest /mnt
docker run --rm -it -v /mnt:/mnt:ro docker.io/joanmarcriera/truenas-ncdu:latest sh
docker run --rm docker.io/joanmarcriera/truenas-ncdu:latest --version
docker run --rm -p 7681:7681 -v /mnt:/mnt:ro -e TTYD_PASSWORD=change-me docker.io/joanmarcriera/truenas-ncdu:latest
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
