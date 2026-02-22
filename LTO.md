# Link-Time Optimization (LTO)

When building static binaries, LTO allows the compiler to optimize across
every translation unit at link time — including vcpkg dependencies built from
source.  This produces smaller, faster binaries than per-library optimization
alone because the linker can inline across library boundaries, eliminate unused
code globally, and perform whole-program devirtualization.

## Quick start

Set the `EXTRA_*` environment variables before any build step:

```dockerfile
ENV EXTRA_CFLAGS="-flto -ffunction-sections -fdata-sections"
ENV EXTRA_CXXFLAGS="-flto -ffunction-sections -fdata-sections"
ENV EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all"
```

These flags are injected into the CMake toolchain so they apply uniformly to
both your project and all vcpkg dependencies.

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
Supported configs: `RELEASE`, `DEBUG`, `MINSIZEREL`, `RELWITHDEBINFO`.

See the [main README](README.md) for a complete Dockerfile example.
