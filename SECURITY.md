# Security

This image is designed as a short-lived local administration tool.

Recommended runtime restrictions:

- Mount TrueNAS storage read-only with `-v /mnt:/mnt:ro`.
- Disable networking with `--network none`.
- Drop Linux capabilities with `--cap-drop ALL`.
- Set `--security-opt no-new-privileges`.
- Use `--read-only` for the container filesystem.

Do not run the container with write access unless you intentionally want `ncdu` delete support and understand the risk.

Report security issues privately to the repository owner rather than opening a public issue.
