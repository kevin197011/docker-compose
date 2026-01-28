# Build and Push Docker Workflow

Template workflow for building and pushing Docker images to Gitea Packages (container registry).

## Location

- **Template**: [.gitea/workflows/build-push-docker.yml](../../.gitea/workflows/build-push-docker.yml)
- Use it in **application repos** that have a `Dockerfile` in the repo root. Copy the workflow into your repo’s `.gitea/workflows/` or reference it via URL if supported.

## Requirements

1. **Dockerfile** in the repository root.
2. **Secrets** (repository or organization):
   - `GITEA_TOKEN`: PAT with **packages** scope (read/write).
   - `GITEA_USERNAME` (optional): registry user; defaults to `repository_owner` (must match image namespace for push).
3. **Variables** (optional):
   - `GITEA_HOST`: Registry host (default `localhost:3000` when Gitea and act-runner share the same host).
   - `IMAGE_NAME`: Full image name (default `{GITEA_HOST}/{owner}/{repo}`).
4. **Act-runner**:
   - Job containers must have **Docker socket** mounted and **Docker CLI** available.
   - See [act-runner config](#act-runner-config) below.

## Act-runner config

The workflow runs `docker build` (and `skopeo copy` for push). Act-runner must:

1. Mount the host Docker socket into **job** containers.
2. Use a job image with Docker CLI (or the workflow installs it via apt). The workflow also installs **skopeo**.

This compose setup does the following:

- **`config/config.yml`**  
  `container.options` adds `--add-host=gitea:host-gateway` only. Do **not** add `-v /var/run/docker.sock:/var/run/docker.sock` here—act-runner already mounts the Docker socket into job containers by default; adding it again causes "Duplicate mount point" errors.

- **Runner labels** (e.g. `ubuntu-latest:docker://node:20-bullseye`)  
  The workflow runs on `ubuntu-latest` → `node:20-bullseye`. It installs `docker.io` and `skopeo` in the “Check Docker availability” step.


## HTTP registry (no host Docker config)

Push uses **skopeo** with `--dest-tls-verify=false` and a per-run `registries.conf` marking the registry as insecure. The workflow does **not** use `docker login` or `docker push`, so you do **not** need to add the registry to the host Docker **insecure-registries**. Works with HTTP Gitea (e.g. `192.168.1.8:3000`) without changing Docker on the host.

## Triggers

- **Push** to `main`, `develop`, or tags `v*`
- **Pull requests** to `main`, `develop` (build only, no push)
- **workflow_dispatch** with optional input `tag`

## Fixes vs. original workflow

- **Expressions**: Avoids `format()` and `||` in top-level `env`; Gitea expression support is limited. Registry and image name are set in a “Set registry and image env” step.
- **Docker**: Uses `docker build` only (no buildx). Push via **skopeo**; installs `docker.io` and `skopeo` when missing (Debian-based job image).
- **Push**: Uses **skopeo** (`skopeo copy --dest-tls-verify=false` + `registries.conf` insecure). No `docker login`/`docker push`, so **no host Docker insecure-registries** needed for HTTP.
- **permissions**: Ignored by Gitea; use PAT with packages scope.

## Gitea vs GitHub

- `permissions` / `packages: write` ignored; use a PAT with packages scope.
- Use `vars.GITEA_HOST` (default `localhost:3000`) and `vars.IMAGE_NAME` as needed. Override `GITEA_HOST` for other hosts (e.g. `192.168.1.8:3000`).

## 401 Unauthorized when pushing

1. **`ROOT_URL`**  
   Set via `GITEA_ROOT_URL` (default `http://localhost:3000/`). Override in `.env` if you use another URL; restart Gitea after changes.

2. **PAT and username**  
   Use a **PAT** with **packages** (read + write). `GITEA_USERNAME` must be able to push to the image namespace (default `repository_owner`).
