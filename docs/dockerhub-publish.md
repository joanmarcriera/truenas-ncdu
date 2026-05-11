# Docker Hub Publishing

The repository includes a GitHub Actions workflow that builds and publishes multi-architecture images to Docker Hub.

## Required GitHub Secrets

Create this repository secret in GitHub:

- `DOCKERHUB_TOKEN`: Docker Hub access token with permission to push images.

The workflow publishes to:

```text
docker.io/joanmarcriera/truenas-ncdu
```

## Tags

Run the workflow manually or push a semver tag. The publish workflow creates:

- `latest` for manual runs and semver tag pushes.
- `vX.Y.Z`, `X.Y`, and `git-<sha>` tags for semver Git tags.

To publish a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Local Manual Push

```bash
docker login
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/joanmarcriera/truenas-ncdu:latest \
  --push .
```
