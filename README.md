# alpine-clang-vcpkg

Alpine Linux Docker image with clang/LLVM and vcpkg for building static C/C++ binaries targeting musl.

## What's included

- **Alpine <!-- alpine-version -->3.21<!-- /alpine-version -->** — musl <!-- musl-version -->unknown<!-- /musl-version --> libc base
- **clang/LLVM <!-- clang-version -->19<!-- /clang-version -->** with lld linker
- **vcpkg** package manager (commit <!-- vcpkg-sha -->unknown<!-- /vcpkg-sha -->, metrics disabled)
- **CMake + Ninja** build system
- Common build dependencies: autoconf, automake, libtool, pkg-config, make, perl

## Supported platforms

`linux/amd64` and `linux/arm64`

## Image tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build from `main` |
| `vX.Y.Z` | Versioned release |
| `<sha>` | Exact commit SHA for reproducible builds |

The image is automatically rebuilt when vcpkg is updated upstream.

## Using in a Dockerfile

Build a CMake/vcpkg project and package it into a minimal runtime image:

```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest AS builder

# Copy source into container
COPY ./ ./

# Configure and build
RUN cmake --preset release && \
    cmake --build build

# Run tests
RUN ctest --test-dir build --output-on-failure

# Minimal runtime image (statically linked binary needs no base OS)
FROM scratch AS runtime
COPY --from=builder /src/build/myapp /myapp
ENTRYPOINT ["/myapp"]
CMD []
```

> Your `CMakePresets.json` configure preset should set the build directory to `build/` and point
> `CMAKE_TOOLCHAIN_FILE` at `$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake` to enable vcpkg
> integration. Choose a musl triplet such as `x64-linux-musl` or `arm64-linux-musl` to produce
> statically linked binaries.

## Interactive use

Mount your source tree and work in a shell:

```bash
docker run --rm -it -v $(pwd):/src p120ph37/alpine-clang-vcpkg:latest
```

## Building and contributing

See [BUILDING.md](BUILDING.md) for local build instructions, CI/CD details, and maintainer setup.
