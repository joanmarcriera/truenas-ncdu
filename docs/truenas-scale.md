# TrueNAS SCALE Usage

This image is intended for one-off disk-usage inspection on TrueNAS SCALE systems that do not have `ncdu` installed on the host.

`ncdu` is interactive. Use the SSH command path when you are already in a terminal, or use the TrueNAS App/YAML path to run a browser terminal on port `7681`.

## Recommended One-Off SSH Command

Use the published Docker Hub image:

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

To scan a specific pool or dataset:

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

The container mount is read-only. `ncdu` can inspect and navigate usage, but it cannot delete files through this run command.

## TrueNAS Apps / YAML

For TrueNAS SCALE 24.10 or later, the Apps screen supports third-party Docker images through Custom App and YAML/Compose flows. Use `examples/compose.truenas.yaml` as the starting point.

The image defaults to browser terminal mode. The Compose examples do not need a `command` override:

```yaml
ports:
  - "7681:7681"
```

The container starts a detached `tmux` session running `ncdu`, then serves it through `ttyd`. Open:

```text
http://<truenas-ip>:7681
```

Set `TTYD_PASSWORD` in the app environment before exposing the port on a shared network.

## Permissions

The image runs as root inside the container because NAS datasets often have mixed ownership and ACLs. Keep the host mount read-only unless you intentionally want delete support.

If you deploy through the guided Custom App UI and enable a custom user, make sure that UID/GID can read and traverse the mounted dataset. The TrueNAS Custom App storage settings also expose read-only host path mounts and optional ACL entries; use those controls for the specific mounted path rather than broadening unrelated share permissions.

If `ncdu` reports permission denied, first confirm that the path is mounted read-only into the container, then check the dataset ACL and the app user settings.

## Useful Options

Stay on one filesystem is enabled by default through `ncdu -x`. Disable it only when you deliberately want to cross filesystem boundaries:

```bash
docker run --rm -it -v /mnt:/mnt:ro \
  -e NCDU_ONE_FILESYSTEM=false \
  docker.io/joanmarcriera/truenas-ncdu:latest \
  /mnt
```

Pass normal `ncdu` options after the scan path:

```bash
docker run --rm -it -v /mnt:/mnt:ro \
  docker.io/joanmarcriera/truenas-ncdu:latest \
  /mnt/tank/media --exclude .zfs
```

## Official TrueNAS References

- [TrueNAS 25.04 Apps UI reference](https://www.truenas.com/docs/scale/25.04/scaleuireference/apps/)
- [TrueNAS 25.04 Custom App screens](https://www.truenas.com/docs/scale/25.04/scaleuireference/apps/installcustomappscreens/)
- [TrueNAS Apps Market: Installing Custom Apps](https://apps.truenas.com/managing-apps/installing-custom-apps/)
