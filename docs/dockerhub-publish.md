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

Run the workflow manually. The publish workflow creates:

- `latest`.
- `git-<sha>`.

For semver image tags, build and push locally or update the workflow input handling before release.

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
