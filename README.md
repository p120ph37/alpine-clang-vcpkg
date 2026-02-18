# alpine-clang-vcpkg

Alpine Linux-based Docker image with clang/LLVM and vcpkg for building static C/C++ binaries targeting musl.

## What's included

- **Alpine 3.21** (musl libc)
- **clang/LLVM** toolchain with lld linker
- **vcpkg** package manager (latest, with metrics disabled)
- **CMake + Ninja** build system
- Common build dependencies (autoconf, automake, libtool, pkg-config, etc.)

## Usage

Pull from Docker Hub:

```bash
docker pull <your-dockerhub-username>/alpine-clang-vcpkg:latest
```

Use as a build stage in your own Dockerfile:

```dockerfile
FROM <your-dockerhub-username>/alpine-clang-vcpkg:latest AS builder

COPY . /src
RUN cmake -B build -G Ninja \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
      -DVCPKG_TARGET_TRIPLET=<arch>-linux-musl \
    && cmake --build build
```

Or mount your source and build interactively:

```bash
docker run --rm -it -v $(pwd):/src <your-dockerhub-username>/alpine-clang-vcpkg:latest
```

## Supported platforms

Images are built for both `linux/amd64` and `linux/arm64`.

## Building locally

```bash
docker build -t alpine-clang-vcpkg .
```

## CI/CD

Two workflows handle automation:

- **`docker-publish.yml`** — builds and pushes the image on every push to `main` (or a version tag). PRs get a dry-run build without pushing.
- **`check-vcpkg-updates.yml`** — runs daily at 06:00 UTC, queries the vcpkg HEAD commit, and commits an updated `.vcpkg-commit` file if it has changed. That commit to `main` then triggers the publish workflow automatically.

Tag a release with `vX.Y.Z` to also publish versioned images alongside `latest`.

## Setup (for maintainers)

### 1. Docker Hub access token

1. Log in to Docker Hub → **Account Settings** → **Security** → **New Access Token**
2. Give it a description (e.g. `github-actions`) and `Read, Write, Delete` scope
3. Copy the token — you won't see it again

### 2. GitHub repository secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** and add:

| Secret               | Value                                      |
|----------------------|--------------------------------------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username                   |
| `DOCKERHUB_TOKEN`    | The access token created in step 1         |

### 3. Allow Actions to push commits (for scheduled updates)

The scheduled `check-vcpkg-updates.yml` workflow commits back to `main` when vcpkg changes. For this to work:

Go to **Settings** → **Actions** → **General** → **Workflow permissions** and select **Read and write permissions**.

> If your repo has branch protection rules on `main` that require status checks or prevent direct pushes, you will need to either exempt the `github-actions[bot]` user or use a Personal Access Token (PAT) with write access stored as an additional secret (e.g. `GH_PAT`) and substitute it for `GITHUB_TOKEN` in the push step.
