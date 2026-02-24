# CLAUDE.md

## Project overview

This repository defines a Docker image that provides a complete C/C++ build environment on Alpine Linux (musl libc) using a pure-LLVM/Clang toolchain with vcpkg for dependency management. The image targets production of optimized static binaries with full LTO support across `linux/amd64` and `linux/arm64`.

Published to Docker Hub as `p120ph37/alpine-clang-vcpkg`.

## Repository structure

```
.
├── Dockerfile                         # Multi-stage Docker build (builder → test → final)
├── toolchains/
│   ├── linux.cmake                    # Vcpkg port toolchain wrapper (includes upstream + extra-flags)
│   └── extra-flags.cmake              # Shared module: compiler-rt defaults + EXTRA_* env vars
├── buildsystems/
│   └── vcpkg.cmake                    # vcpkg.cmake wrapper (applies extra-flags to main project)
├── test/
│   ├── CMakeLists.txt                 # Test project: validates LTO, static/dynamic linking
│   ├── main.c                         # Test entry point (calls used_func)
│   ├── mylib.c                        # Library with used_func + unused_func (LTO strips unused)
│   └── mylib.h                        # Library header
├── .github/workflows/
│   ├── docker-publish.yml             # CI: build, test, push to Docker Hub on main/tags
│   ├── docker-validate.yml            # CI: dry-run validation on PRs
│   └── check-vcpkg-updates.yml        # Scheduled daily vcpkg bump
├── .vcpkg-commit                      # Pinned vcpkg commit SHA (updated by CI)
├── claude-web-docker-setup.sh         # Docker setup for Claude Code web agent (not for general use)
├── .gitignore                         # Ignores environment-specific proxy-ca.pem
├── .dockerignore                      # Excludes .git, .github, README.md, LICENSE from build context
├── README.md                          # Main docs (contains CI-updated version markers)
├── LTO.md                             # Link-time optimization guide
├── BUILDING.md                        # CI/CD setup and local build instructions
└── LICENSE                            # MIT
```

## Key architecture decisions

- **Pure-LLVM toolchain**: GNU binutils and GCC compiler binaries are removed from the image; LLVM equivalents are symlinked in their place (`cc`→`clang`, `ar`→`llvm-ar`, `ld`→`lld`, etc.). GCC CRT objects are retained because the clang driver references them for startup object discovery.
- **compiler-rt + libunwind by default**: The shared `extra-flags.cmake` module passes `--rtlib=compiler-rt --unwindlib=libunwind` to the linker instead of using libgcc/libgcc_s.
- **EXTRA_\* environment variables**: Build flags are injected via environment variables (`EXTRA_CFLAGS`, `EXTRA_CXXFLAGS`, `EXTRA_LDFLAGS`) rather than custom vcpkg triplets. Per-config overrides (`EXTRA_CFLAGS_RELEASE`, etc.) use `CACHE FORCE` to replace CMake platform defaults. The flag logic lives in `extra-flags.cmake` and is included by two wrappers: `toolchains/linux.cmake` (for vcpkg port builds) and `buildsystems/vcpkg.cmake` (for the main project build).
- **Static linking by default**: vcpkg's built-in Linux triplets already default to `VCPKG_LIBRARY_LINKAGE=static`. Alpine provides `.a` archives for all system packages.

## Build and test commands

### Local Docker build (single platform)

```bash
docker build -t alpine-clang-vcpkg .
```

### Local Docker build (multi-platform, matching CI)

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t alpine-clang-vcpkg .
```

### Run the toolchain tests only

```bash
docker build --target test -t alpine-clang-vcpkg-test .
```

The Dockerfile `test` stage validates:
1. `cc` resolves to clang (not gcc)
2. CMake project builds with LTO enabled (proves LLVM tools work)
3. Dynamic and static binaries produce correct output (`result = 42`)
4. LTO strips `unused_func` from the static binary (checked via `nm` and `strings`)
5. musl `libc.a` contains LLVM bitcode (checked via `llvm-bcanalyzer`)
6. `EXTRA_*` flags and compiler-rt defaults apply to the main project via `vcpkg.cmake`

There are no unit test frameworks or linters — validation is the Docker build itself.

## CI/CD workflows

### `docker-publish.yml`
- **Triggers**: push to `main`, version tags (`v*`), manual dispatch
- Builds for `linux/amd64` and `linux/arm64`
- Runs the `test` stage, then builds and pushes the final image
- After push on `main`: extracts version info from the built image and updates HTML comment markers in README.md (e.g., `<!-- alpine-version -->3.23.3<!-- /alpine-version -->`)
- Syncs README.md to Docker Hub description
- **Skips** on markdown-only changes (`paths-ignore: '**/*.md'`)

### `docker-validate.yml`
- **Triggers**: PRs to `main`
- Dry-run: builds test and final stages without pushing

### `check-vcpkg-updates.yml`
- **Triggers**: daily at 06:00 UTC, manual dispatch
- Compares vcpkg HEAD to `.vcpkg-commit`; if different, updates the file and commits to `main` (triggering a rebuild)

## Commit message conventions

Use conventional-commit-style prefixes observed in the project history:

- `feat:` — new features or capabilities
- `fix:` — bug fixes
- `chore:` — maintenance tasks (version bumps, CI-generated updates)
- `docs:` — documentation-only changes
- `refactor:` — code restructuring without behavior change

Commit messages are concise, imperative mood, lowercase after the prefix. Examples from history:
- `feat: add per-config EXTRA_*_<CONFIG> flags to override CMake defaults`
- `fix: wrap upstream linux.cmake instead of replacing it via chainload`
- `chore: bump vcpkg to <SHA>`

## Important files to understand

### `Dockerfile`
Multi-stage build with three stages:
1. **`builder`** — installs Alpine packages, purges GCC/binutils, creates LLVM symlinks, rebuilds musl with LTO (`libc.a` + CRT objects only), installs vcpkg, installs toolchain wrappers (`linux.cmake`, `vcpkg.cmake`, `extra-flags.cmake`)
2. **`test`** — copies `test/` project and runs end-to-end validation
3. **final** (unnamed) — derives from `builder`, sets `WORKDIR /src`

### `toolchains/extra-flags.cmake`
Shared CMake module that provides two things:
- Default `--rtlib=compiler-rt --unwindlib=libunwind` linker flags
- `EXTRA_CFLAGS` / `EXTRA_CXXFLAGS` / `EXTRA_LDFLAGS` (appended to `_INIT` variables)
- Per-config overrides via `EXTRA_CFLAGS_RELEASE`, `EXTRA_CFLAGS_DEBUG`, etc. (uses `CACHE FORCE`)

Guarded by `_ALPINE_CLANG_EXTRA_FLAGS` to prevent double-inclusion. Included by both `toolchains/linux.cmake` (for vcpkg port builds) and `buildsystems/vcpkg.cmake` (for main project builds).

### `toolchains/linux.cmake`
Thin wrapper around vcpkg's upstream `linux-upstream.cmake`. Includes the upstream toolchain and then includes `extra-flags.cmake`. Used by vcpkg internally when building ports.

### `buildsystems/vcpkg.cmake`
Wrapper around vcpkg's upstream `vcpkg-upstream.cmake`. Includes `extra-flags.cmake` before the upstream buildsystem integration so that the same compiler-rt defaults and `EXTRA_*` flags apply to the user's main project build (not just vcpkg port builds). `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` is handled by the upstream `vcpkg.cmake` and is unaffected by this wrapper.

### `.vcpkg-commit`
Single-line file containing the pinned vcpkg commit SHA. Updated automatically by `check-vcpkg-updates.yml`. The Dockerfile clones vcpkg with `--depth 1` at HEAD (not this specific SHA) — the file primarily serves as a change trigger for CI rebuilds.

### `README.md`
Contains HTML comment markers (`<!-- alpine-version -->...<!-- /alpine-version -->`) that are auto-updated by CI. Do not manually edit values inside these markers — they will be overwritten on the next push to `main`.

## Common modification patterns

### Adding a new Alpine package to the image
Add it to the `apk add` line in the `Dockerfile` `builder` stage (line 5). The package list in README.md is auto-updated by CI after the next push to `main`.

### Modifying the CMake toolchain behavior
Edit `toolchains/extra-flags.cmake` for flag injection or compiler-rt defaults (shared by both port and main project builds). Edit `toolchains/linux.cmake` for port-build-specific behavior, or `buildsystems/vcpkg.cmake` for main-project-specific behavior. The upstream vcpkg files (`linux-upstream.cmake`, `vcpkg-upstream.cmake`) are included via `include()` — do not modify those files.

### Adding or modifying toolchain tests
Edit files in the `test/` directory and/or the `RUN` block in the Dockerfile `test` stage. Tests run during every Docker build, including CI.

### Updating vcpkg manually
Write the desired commit SHA to `.vcpkg-commit` and commit. CI will rebuild with that version.

## Docker in Claude Code web agent

`claude-web-docker-setup.sh` configures Docker for the Claude Code web agent sandbox (not for general-purpose developer use). The sandbox lacks iptables support, overlayfs, and uses a TLS-intercepting HTTPS proxy.

### Quick start

```bash
source claude-web-docker-setup.sh   # defines setup_docker and docker-build functions
setup_docker                         # starts dockerd, extracts proxy CA, configures proxy
docker-build --target test -t alpine-clang-vcpkg-test .
```

### What it does

1. **Starts `dockerd`** with `--iptables=false --bridge=none --storage-driver=vfs` (required by the sandbox constraints)
2. **Extracts the proxy CA** from the system trust store (looks for "sandbox-egress-production TLS Inspection CA")
3. **Configures Docker proxy** settings in `~/.docker/config.json`
4. **Provides `docker-build`** — a wrapper around `docker build` that auto-injects the proxy CA into Dockerfiles and adds `--network=host`

### Why a Dockerfile wrapper instead of a daemon config?

Docker has no daemon-level mechanism to inject CA certificates into build containers (unlike `resolv.conf` which has special handling). BuildKit's `buildkitd.toml` CA config only affects registry connections, not operations inside `RUN` commands (`apk add`, `curl`, `git clone`, etc.). The `docker-build` wrapper transparently transforms the Dockerfile to inject the CA after each `FROM` line.

## Things to avoid

- Do not remove GCC CRT objects or the `gcc` package record from the image — the clang driver depends on them for startup object discovery, and the APK database entry prevents re-installation.
- Do not manually edit content between HTML comment markers in README.md (e.g., `<!-- package-list -->`) — CI overwrites these.
- Do not add `CMAKE_C_COMPILER` or `CMAKE_CXX_COMPILER` overrides to the toolchain wrapper — compiler selection is handled by symlinks.
- Do not set `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` in `toolchains/linux.cmake` — it is intentionally left available for user triplets. The `buildsystems/vcpkg.cmake` wrapper also does not consume it; it is handled by the upstream `vcpkg.cmake`.
- Do not modify the upstream renamed files (`linux-upstream.cmake`, `vcpkg-upstream.cmake`) — edit the wrappers or `extra-flags.cmake` instead.
