# Link-Time Optimization (LTO)

When building static binaries, LTO allows the compiler to optimize across
every translation unit at link time — including vcpkg dependencies built from
source.  This produces smaller, faster binaries than per-library optimization
alone because the linker can inline across library boundaries, eliminate unused
code globally, and perform whole-program devirtualization.

## Quick start

Set the `EXTRA_*` environment variables before any build step:

```dockerfile
ENV EXTRA_CFLAGS="-flto -Oz -ffunction-sections -fdata-sections"
ENV EXTRA_CXXFLAGS="-flto -Oz -ffunction-sections -fdata-sections"
ENV EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all"
```

These flags are injected into the CMake toolchain so they apply uniformly to
both your project and all vcpkg dependencies.

See the [main README](README.md) for a complete Dockerfile example.
