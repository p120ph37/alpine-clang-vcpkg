# alpine-clang-vcpkg

[Dockerfile](https://github.com/p120ph37/alpine-clang-vcpkg/blob/main/Dockerfile)

Alpine Linux Docker image with clang/LLVM and vcpkg for building static C/C++ binaries targeting musl.

## What's included in [`p120ph37/alpine-clang-vcpkg:latest`](https://hub.docker.com/r/p120ph37/alpine-clang-vcpkg)

- **Alpine <!-- alpine-version -->3.23.3<!-- /alpine-version -->** — musl <!-- musl-version -->1.2.5<!-- /musl-version --> libc base
- **clang/LLVM <!-- clang-version -->21.1.2<!-- /clang-version -->** — set as system-default toolchain; LLVM tools override GCC/binutils system-wide (`cc`→`clang`, `ar`→`llvm-ar`, `ld`→`lld`, etc.), and the `gcc` package has been overridden (compiler binaries removed; retained as a dependency-marker only)
- **vcpkg** package manager (commit <!-- vcpkg-sha -->dd930e3<!-- /vcpkg-sha --> from <!-- vcpkg-date -->2026-02-19<!-- /vcpkg-date -->, metrics disabled)
- **CMake + Ninja** build system
- Some common build dependencies: autoconf, automake, libtool, pkg-config, make, perl (full list below)

<details>
<summary>List of all installed Alpine packages</summary>

<!-- package-list -->
| Package | Version |
|---------|---------|
| acl-libs | 2.3.2-r1 |
| alpine-baselayout | 3.7.1-r8 |
| alpine-baselayout-data | 3.7.1-r8 |
| alpine-keys | 2.6-r0 |
| alpine-release | 3.23.3-r0 |
| apk-tools | 3.0.3-r1 |
| autoconf | 2.72-r1 |
| automake | 1.18.1-r0 |
| bash | 5.3.3-r1 |
| binutils | 2.45.1-r0 |
| brotli-libs | 1.2.0-r0 |
| busybox | 1.37.0-r30 |
| busybox-binsh | 1.37.0-r30 |
| c-ares | 1.34.6-r0 |
| ca-certificates-bundle | 20251003-r0 |
| clang21 | 21.1.2-r2 |
| clang21-headers | 21.1.2-r2 |
| clang21-libs | 21.1.2-r2 |
| clang21-static | 21.1.2-r2 |
| cmake | 4.1.3-r0 |
| curl | 8.17.0-r1 |
| fortify-headers | 1.1-r5 |
| gcc ¹ | 15.2.0-r2 |
| git | 2.52.0-r0 |
| git-init-template | 2.52.0-r0 |
| git-perl | 2.52.0-r0 |
| gmp | 6.3.0-r4 |
| isl26 | 0.26-r1 |
| jansson | 2.14.1-r0 |
| libapk | 3.0.3-r1 |
| libarchive | 3.8.5-r0 |
| libatomic | 15.2.0-r2 |
| libbz2 | 1.0.8-r6 |
| libcrypto3 | 3.5.5-r0 |
| libcurl | 8.17.0-r1 |
| libexpat | 2.7.4-r0 |
| libffi | 3.5.2-r0 |
| libgcc | 15.2.0-r2 |
| libgomp | 15.2.0-r2 |
| libidn2 | 2.3.8-r0 |
| libltdl | 2.5.4-r2 |
| libncursesw | 6.5_p20251123-r0 |
| libpsl | 0.21.5-r3 |
| libssl3 | 3.5.5-r0 |
| libstdc++ | 15.2.0-r2 |
| libstdc++-dev | 15.2.0-r2 |
| libtool | 2.5.4-r2 |
| libunistring | 1.4.1-r0 |
| libuv | 1.51.0-r0 |
| libxml2 | 2.13.9-r0 |
| linux-headers | 6.16.12-r0 |
| lld21 | 21.1.2-r1 |
| lld21-libs | 21.1.2-r1 |
| llvm | 21-r0 |
| llvm-linker-tools | 21-r0 |
| llvm21 ² | 21.1.2-r1 |
| llvm21-libs | 21.1.2-r1 |
| llvm21-linker-tools | 21.1.2-r1 |
| lz4-libs | 1.10.0-r0 |
| m4 | 1.4.20-r0 |
| make | 4.4.1-r3 |
| mpc1 | 1.3.1-r1 |
| mpfr4 | 4.2.2-r0 |
| musl | 1.2.5-r21 |
| musl-dev | 1.2.5-r21 |
| musl-utils | 1.2.5-r21 |
| ncurses-terminfo-base | 6.5_p20251123-r0 |
| nghttp2-libs | 1.68.0-r0 |
| nghttp3 | 1.13.1-r0 |
| pcre2 | 10.47-r0 |
| perl | 5.42.0-r0 |
| perl-error | 0.17030-r0 |
| perl-git | 2.52.0-r0 |
| pkgconf | 2.5.1-r0 |
| readline | 8.3.1-r0 |
| rhash-libs | 1.4.6-r0 |
| samurai | 1.2-r7 |
| scanelf | 1.3.8-r2 |
| scudo-malloc | 21.1.2-r0 |
| ssl_client | 1.37.0-r30 |
| tar | 1.35-r4 |
| unzip | 6.0-r16 |
| xz-libs | 5.8.2-r0 |
| zip | 3.0-r13 |
| zlib | 1.3.1-r2 |
| zstd-libs | 1.5.7-r2 |
<!-- /package-list -->

---

¹ **`gcc`**: libcrt link objects only — compiler binaries (`gcc`, `cpp`, `gcov`, etc.), sanitizer libs, and headers have been removed from this package. The CRT objects (`crtbeginS.o`, `crtendS.o`) and `libgcc.a`/`libgcc_s.so` link script are kept because `clang` requires them at link time. The package record is retained in the APK database so that `apk` treats the GCC dependency as already satisfied.

² **`llvm`**: Additional symlinks were created in `/usr/bin` and the GCC-sysroot `bin` directory to make LLVM tools the system defaults, overriding GNU binutils: `ar`→`llvm-ar`, `ld`→`lld`, `nm`→`llvm-nm`, `objcopy`→`llvm-objcopy`, `objdump`→`llvm-objdump`, `ranlib`→`llvm-ranlib`, `readelf`→`llvm-readelf`, `strip`→`llvm-strip`, etc. The default C compiler `cc` is also symlinked to `clang`.

</details>

## Supported platforms

`linux/amd64` and `linux/arm64`

## Image tags

| Tag | Description |
|-----|-------------|
| `latest` | Standard build, no LTO |
| `latest-lto-thin` | ThinLTO with `-O2`, faster builds, ~1% larger binaries than full LTO |
| `latest-lto` | Full LTO with `-O2`, smallest binaries, best optimization |
| `<sha>` | Exact commit SHA for reproducible builds |

The image is automatically rebuilt when vcpkg is updated upstream.

LTO variants default to `-O2` optimization but can be overridden via CMake flags.

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

> Your `CMakePresets.json` should point `CMAKE_TOOLCHAIN_FILE` at
> `$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake` to enable vcpkg integration.

## Interactive use

Mount your source tree and work in a shell:

```bash
docker run --rm -it -v $(pwd):/src p120ph37/alpine-clang-vcpkg:latest
```
