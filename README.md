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

After publishing the image to Docker Hub, replace `YOUR_DOCKERHUB_USERNAME` and run this from a TrueNAS SCALE shell:

```bash
docker run --rm -it \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -v /mnt:/mnt:ro \
  docker.io/YOUR_DOCKERHUB_USERNAME/truenas-ncdu:latest
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
  docker.io/YOUR_DOCKERHUB_USERNAME/truenas-ncdu:latest \
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

## TrueNAS SCALE Custom App

Current TrueNAS SCALE documentation describes two Custom App paths for third-party Docker images: a guided Custom App screen and an advanced YAML/Compose editor. Use [`examples/compose.truenas.yaml`](examples/compose.truenas.yaml) as the starting YAML.

The compose example runs the container as a sleeping toolbox. After it starts, open a shell into the app container and run:

```bash
truenas-ncdu /mnt/tank/media
```

See [docs/truenas-scale.md](docs/truenas-scale.md) for the detailed TrueNAS notes, including permissions and interactive terminal trade-offs.

## Publish to Docker Hub

The repository includes [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml).

Add these GitHub repository secrets:

- `DOCKERHUB_USERNAME`
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
docker run --rm -it -v /mnt:/mnt:ro docker.io/YOUR_DOCKERHUB_USERNAME/truenas-ncdu:latest /mnt/tank/media --exclude .zfs
docker run --rm -it -v /mnt:/mnt:ro -e NCDU_ONE_FILESYSTEM=false docker.io/YOUR_DOCKERHUB_USERNAME/truenas-ncdu:latest
docker run --rm -it -v /mnt:/mnt:ro docker.io/YOUR_DOCKERHUB_USERNAME/truenas-ncdu:latest -- sh
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
