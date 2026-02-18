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

The image is automatically built and pushed to Docker Hub on every push to `main` via GitHub Actions. Tag a release with `vX.Y.Z` to publish versioned images.

## Setup (for maintainers)

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret              | Value                        |
|---------------------|------------------------------|
| `DOCKERHUB_USERNAME`| Your Docker Hub username     |
| `DOCKERHUB_TOKEN`   | Docker Hub access token      |
