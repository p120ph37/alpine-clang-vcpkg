# Link-Time Optimization (LTO)

When building static binaries, LTO allows the compiler to optimize across
every translation unit at link time — including vcpkg dependencies built from
source.  This produces smaller, faster binaries than per-library optimization
alone because the linker can inline across library boundaries, eliminate unused
code globally, and perform whole-program devirtualization.

## musl libc LTO

The base image rebuilds musl libc from Alpine's source with `-flto -Oz`, so
`libc.a` contains LLVM bitcode instead of native object code.  When you
build a static binary with LTO enabled, the linker can optimize across
your application, vcpkg libraries, **and** the C library in a single
whole-program LTO pass.  No extra configuration is needed — just set the
`EXTRA_*` flags shown below.

## arm64: compiler-rt and outline atomics

On aarch64 (arm64), LLVM's compiler-rt uses **outline atomics** — runtime
helpers that call `getauxval()` to detect whether the CPU supports LSE atomic
instructions.  `getauxval` is provided by musl's `libc.a`, which creates a
circular link-time dependency when building static binaries:

```
compiler-rt (libclang_rt.builtins) → getauxval → libc.a
```

This is handled automatically by lld, which iterates over input archives until
all symbols are resolved (unlike GNU ld, which requires explicit
`--start-group`/`--end-group`).  Since this toolchain uses lld exclusively, no
extra linker flags are needed — static arm64 binaries that use atomics link
correctly out of the box.  The Docker build's test stage validates this on
every arm64 build.

## Quick start

Set the `EXTRA_*` environment variables before any build step:

```dockerfile
ENV EXTRA_CFLAGS="-flto -ffunction-sections -fdata-sections"
ENV EXTRA_CXXFLAGS="-flto -ffunction-sections -fdata-sections"
ENV EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all"
```

These flags are injected via a wrapper around `vcpkg.cmake` and the vcpkg
port toolchain, so they apply uniformly to both your project and all vcpkg
dependencies when you use `CMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake`.

### Overriding per-config optimization levels

The base `EXTRA_CFLAGS` flags are appended to `CMAKE_C_FLAGS_INIT`, which
means they appear in every compiler invocation.  However, CMake also appends
build-type-specific flags (e.g. `-O3 -DNDEBUG` for Release).  Since the
last optimization flag wins, a `-Oz` in `EXTRA_CFLAGS` would be overridden
by the default `-O3` in Release builds.

To replace the per-config defaults, use the `EXTRA_<LANG>FLAGS_<CONFIG>`
variables:

```dockerfile
ENV EXTRA_CFLAGS_RELEASE="-Oz -DNDEBUG"
ENV EXTRA_CXXFLAGS_RELEASE="-Oz -DNDEBUG"
```

These use `CACHE FORCE` to replace CMake's platform defaults entirely.
Supported configs: `RELEASE` and `DEBUG` (the two build types vcpkg uses).

> **Note:** A small number of vcpkg ports (notably **mbedTLS** and
> **libsodium**) set their own per-config optimization flags in their
> `CMakeLists.txt`, which take precedence over `EXTRA_CFLAGS_RELEASE`.
> The base `-flto` flags from `EXTRA_CFLAGS` are unaffected — they flow
> through `CMAKE_C_FLAGS` independently and still apply to these ports.
> To override a port's hardcoded optimization level, use a
> [vcpkg port overlay](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports).

## Binary size: Clang+LTO vs standard GCC

The following table compares the stripped static binary size of the
[test program](test/) (a minimal C program that calls one library function)
built on Alpine 3.21 for x86_64:

| Toolchain | Stripped size |
|---|--:|
| **alpine-clang-vcpkg + full LTO (-O3)** | **~18 KB** |
| **alpine-clang-vcpkg + full LTO (-Oz)** | **~17 KB** |
| Stock Alpine clang + LTO (no musl rebuild) | ~19 KB |

**alpine-clang-vcpkg + full LTO** uses the recommended `EXTRA_*` flags from
[Quick start](#quick-start) above (`-flto -ffunction-sections -fdata-sections`
for compilation, `-flto -Wl,--gc-sections -Wl,--icf=all` for linking).
**Stock Alpine clang + LTO** uses the same clang toolchain and LTO flags but
with the unmodified `musl-dev` package (GCC-compiled native objects in
`libc.a`, which cannot participate in cross-library LTO).

The saving comes from whole-program LTO across the application/libc boundary:
the linker can inline, eliminate dead code, and merge identical functions
(`--icf=all`) across **all** translation units including musl libc itself.
The benefit grows with real-world projects that pull in more libc surface area.

> **Important:** The `-Wl,--gc-sections` linker flag is essential when using
> the LTO-compiled musl.  Without it, unreferenced libc sections are retained
> and the binary balloons to ~100 KB — _larger_ than the GCC equivalent.
> Always pair `-ffunction-sections -fdata-sections` in `EXTRA_CFLAGS` with
> `-Wl,--gc-sections` in `EXTRA_LDFLAGS`.

See the [main README](README.md) for a complete Dockerfile example and
a full description of [flag precedence](README.md#flag-precedence-and-per-port-overrides).
