# Building and CI/CD

## Building locally

```bash
docker build -t alpine-clang-vcpkg .
```

For a multi-platform build matching what CI produces (requires Docker Buildx):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t alpine-clang-vcpkg .
```

## CI/CD workflows

Two GitHub Actions workflows handle automation:

### `docker-publish.yml`

Triggered on:
- Any push to `main` (publishes `latest`)
- Version tags matching `v*` (publishes `vX.Y.Z`, `vX.Y`, and `latest`)
- Manual `workflow_dispatch`

After a successful push it also syncs `README.md` to the Docker Hub repository description
via `peter-evans/dockerhub-description`.

### `check-vcpkg-updates.yml`

Runs daily at 06:00 UTC. Queries the vcpkg `HEAD` commit SHA via `git ls-remote` and
compares it to the value stored in `.vcpkg-commit`. If the SHA has changed, it updates
`.vcpkg-commit` and commits directly to `main`, which in turn triggers `docker-publish.yml`
to rebuild and push a fresh image.

Run manually from the Actions tab to force an immediate check.

## Maintainer setup

### 1. Docker Hub access token

1. Log in to Docker Hub → **Account Settings** → **Security** → **New Access Token**
2. Give it a description (e.g. `github-actions`) and **Read & Write** scope (Delete is not required)
3. Copy the token — it is only shown once

### 2. GitHub repository variable and secret

Go to your repo → **Settings** → **Secrets and variables** → **Actions** and add:

| Kind | Name | Value |
|------|------|-------|
| Variable | `DOCKERHUB_USERNAME` | Your Docker Hub username |
| Secret | `DOCKERHUB_TOKEN` | The access token from step 1 |

### 3. Allow Actions to push commits (for scheduled vcpkg updates)

`check-vcpkg-updates.yml` commits back to `main` when vcpkg changes. For this to work:

Go to **Settings** → **Actions** → **General** → **Workflow permissions** and select
**Read and write permissions**.

> If your repo has branch protection rules on `main` (required reviews, status checks, etc.),
> the bot push will be blocked. You will need to either exempt the `github-actions[bot]` user
> from those rules or store a Personal Access Token (PAT) with `repo` write access as an
> additional secret (e.g. `GH_PAT`) and substitute it for `GITHUB_TOKEN` in the push step of
> `check-vcpkg-updates.yml`.
