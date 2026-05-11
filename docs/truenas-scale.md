# TrueNAS SCALE Usage

This image is intended for one-off disk-usage inspection on TrueNAS SCALE systems that do not have `ncdu` installed on the host.

`ncdu` is interactive, so the best experience is usually an SSH session to the TrueNAS host followed by `docker run -it`. The TrueNAS Apps UI/YAML route is useful when you prefer a managed app container that stays stopped or sleeping until you open a shell into it.

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
  docker.io/joanmarcriera/truenas-ncdu:latest
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

The example keeps the container alive with:

```yaml
command: ["--", "sleep", "infinity"]
```

After the app starts, open a shell for the `truenas-ncdu` container and run:

```bash
truenas-ncdu /mnt/tank/media
```

If you want the TUI to start immediately instead of keeping a sleeping helper container, remove the `command` line. That only works well when your execution path attaches an interactive terminal.

## Permissions

The image runs as root inside the container because NAS datasets often have mixed ownership and ACLs. Keep the host mount read-only unless you intentionally want delete support.

If you deploy through the guided Custom App UI and enable a custom user, make sure that UID/GID can read and traverse the mounted dataset. The TrueNAS Custom App storage settings also expose read-only host path mounts and optional ACL entries; use those controls for the specific mounted path rather than broadening unrelated share permissions.

If `ncdu` reports permission denied, first confirm that the path is mounted read-only into the container, then check the dataset ACL and the app user settings.

## Useful Options

Stay on one filesystem is enabled by default through `ncdu -x`. Disable it only when you deliberately want to cross filesystem boundaries:

```bash
docker run --rm -it -v /mnt:/mnt:ro \
  -e NCDU_ONE_FILESYSTEM=false \
  docker.io/joanmarcriera/truenas-ncdu:latest
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
