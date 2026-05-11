# Contributing

Keep this project small and predictable.

Before opening a pull request:

```bash
sh scripts/test.sh
```

Changes should preserve the default safety posture:

- Read-only host mounts in examples.
- No runtime network requirement.
- No privileged container mode.
- No package manager writes on the TrueNAS host.

If you add behavior to `entrypoint.sh`, add or update `tests/entrypoint_test.sh` first.
