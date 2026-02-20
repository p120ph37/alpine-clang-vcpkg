# Proposal: LTO-Enabled alpine-clang-vcpkg Image Variants

## Executive Summary

Embed LTO configuration as defaults in `alpine-clang-vcpkg` image variants, eliminating the need for per-project toolchain and triplet configuration. Users would simply choose an image tag (`:lto-thin`, `:lto-full`, `:lto-size`) to get optimized builds with zero additional configuration.

## Current Situation

Today, enabling LTO for vcpkg projects requires:
1. Custom `toolchain.cmake` with LTO flags
2. Overlay triplets (`arm64-linux.cmake`, `x64-linux.cmake`) that chainload the toolchain
3. `vcpkg-configuration.json` registering the overlays
4. `CMakePresets.json` chainloading the toolchain for project builds

**Result:** Every project needs 4+ configuration files just to enable LTO, despite it being a common optimization goal.

## Proposed Solution

Provide image variants with pre-configured LTO defaults using system-wide vcpkg triplets that chainload shared toolchains:

```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest          # No LTO (current behavior)
FROM p120ph37/alpine-clang-vcpkg:latest-lto      # Full LTO, smallest binaries
FROM p120ph37/alpine-clang-vcpkg:latest-lto-thin # ThinLTO, faster builds
```

Users change one line in their Dockerfile and get full LTO across all dependencies **and their project** with zero additional configuration.

## Implementation: System-Wide vcpkg Triplets with Chainloaded Toolchains

The implementation uses vcpkg's native triplet system to chainload shared LTO-enabled toolchains. This automatically applies to **both vcpkg dependencies AND user projects** through vcpkg.cmake's standard integration.

### Architecture

Replace default triplets in `/opt/vcpkg/triplets/` that chainload shared LTO toolchains:

```cmake
# /opt/vcpkg/triplets/arm64-linux.cmake (in :latest-lto variant)
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# Chainload shared toolchain - applies to BOTH vcpkg deps AND user project!
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "/opt/vcpkg/toolchains/lto.cmake")
```

```cmake
# /opt/vcpkg/toolchains/lto.cmake
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Base flags for all builds
set(CMAKE_C_FLAGS_INIT "-ffunction-sections -fdata-sections")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")

# Full LTO flags - applied to both Debug and Release
set(CMAKE_C_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-flto -Wl,--gc-sections -Wl,--icf=all")

set(CMAKE_C_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-flto -Wl,--gc-sections")
```

**Why LTO in Debug Builds?**
- Helps debug LTO-specific optimization issues
- Can strip afterwards while preserving debug symbols elsewhere

**Key Design Points:**
- vcpkg-native solution, fully supported by vcpkg.cmake
- **Automatically applies to BOTH vcpkg dependencies AND user projects** via standard vcpkg integration
- Users see exactly what flags are applied (`vcpkg install --debug`)
- Easy to override with user's own overlay triplets or CMake flags
- Single source of truth for LTO configuration
- `-O2` default provides good balance of performance and size

**User Overrides:**
Users can override optimization levels in their CMakeLists.txt or via command line:
```cmake
# In CMakeLists.txt - override optimization level
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    string(REPLACE "-O2" "-Oz" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
    string(REPLACE "-O2" "-Oz" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
endif()
```

Or via cmake command line:
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE="-flto -Oz -DNDEBUG -fvisibility=hidden"
```

## Image Variants

| Variant | Use Case | LTO Mode | Default Optimization |
|---------|----------|----------|---------------------|
| `:latest` | Development, debugging, maximum compatibility | None | Standard (no LTO) |
| `:latest-lto` | Production releases, smallest binaries, best optimization | Full LTO | `-O2` (overridable) |
| `:latest-lto-thin` | CI/CD, iterative development, faster builds | ThinLTO | `-O2` (overridable) |

**Trade-offs:**
- **Full LTO** (`:latest-lto`): Best optimization, smallest binaries, slower link times (~20-30% slower)
- **ThinLTO** (`:latest-lto-thin`): Nearly equivalent optimization (~99% of full LTO), faster parallel builds, ~1% larger binaries
- **No LTO** (`:latest`): Fastest builds, largest binaries, best for rapid iteration

**Note:** Both LTO variants default to `-O2` optimization. Users can override to `-O3`, `-Oz`, or other levels via CMake flags.

## User Experience Comparison

### Before (Current)

```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest

# Copy LTO configuration (4 files minimum)
COPY toolchain.cmake ./
COPY vcpkg-configuration.json ./
COPY triplets/ triplets/

COPY vcpkg.json ./
RUN vcpkg install

COPY CMakeLists.txt CMakePresets.json ./
COPY src/ src/
RUN cmake --preset release && cmake --build build
```

**Required files:**
- `toolchain.cmake` (30-40 lines)
- `vcpkg-configuration.json` (overlay-triplets config)
- `triplets/arm64-linux.cmake` (15 lines)
- `triplets/x64-linux.cmake` (15 lines)
- `CMakePresets.json` (VCPKG_CHAINLOAD_TOOLCHAIN_FILE)

### After (With Variants)

```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest-lto

COPY vcpkg.json ./
RUN vcpkg install

COPY CMakeLists.txt ./
COPY src/ src/
RUN cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
    -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build
```

**Required files:**
- None! Just change the image tag and use standard vcpkg.cmake integration.

**How it works:**
1. `vcpkg.cmake` detects architecture (arm64/x64)
2. Loads `/opt/vcpkg/triplets/arm64-linux.cmake`
3. Triplet specifies `VCPKG_CHAINLOAD_TOOLCHAIN_FILE="/opt/vcpkg/toolchains/lto.cmake"`
4. vcpkg.cmake automatically loads that toolchain
5. LTO flags (with `-O2` default) apply to ALL builds (dependencies + your project)!

**Overriding optimization level:**
```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest-lto

COPY vcpkg.json ./
RUN vcpkg install

COPY CMakeLists.txt ./
COPY src/ src/
# Use -Oz for extreme size reduction
RUN cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE="-flto -Oz -DNDEBUG -fvisibility=hidden" \
    -DCMAKE_CXX_FLAGS_RELEASE="-flto -Oz -DNDEBUG -fvisibility=hidden" && \
    cmake --build build
```

**If user needs custom flags:**
```dockerfile
FROM p120ph37/alpine-clang-vcpkg:latest-lto

# Override optimization level to -Oz for size
ENV CFLAGS="$CFLAGS -Oz"

# Or use custom triplet overlays as before
COPY my-custom-triplets/ /src/triplets/
RUN vcpkg install --overlay-triplets=/src/triplets
```

## Implementation Details

### Directory Structure in Image

```
/opt/vcpkg/
├── triplets/
│   ├── arm64-linux.cmake          # Points to toolchains/lto.cmake or lto-thin.cmake
│   ├── x64-linux.cmake            # Points to toolchains/lto.cmake or lto-thin.cmake
│   └── community/                 # Unchanged
├── toolchains/
│   ├── lto.cmake                  # Full LTO toolchain
│   └── lto-thin.cmake             # ThinLTO toolchain
└── scripts/
    └── buildsystems/
        └── vcpkg.cmake             # Loads triplet, which loads toolchain
```

### Sample Triplet and Toolchain Content

**For :latest-lto variant:**

```cmake
# /opt/vcpkg/triplets/arm64-linux.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# Chainload shared toolchain - applies to deps AND user project!
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "/opt/vcpkg/toolchains/lto.cmake")
```

```cmake
# /opt/vcpkg/toolchains/lto.cmake
# This toolchain is automatically applied to:
# 1. All vcpkg dependency builds (via triplet)
# 2. User project builds (via vcpkg.cmake chainloading)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Base flags for all builds
set(CMAKE_C_FLAGS_INIT "-ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_INIT "-ffunction-sections -fdata-sections")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")

# Release: Full LTO with -O2 default
set(CMAKE_C_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-flto -Wl,--gc-sections -Wl,--icf=all")

# Debug: LTO with debug symbols (useful for debugging LTO-specific issues)
set(CMAKE_C_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-flto -Wl,--gc-sections")
```

**For :latest-lto-thin variant:**

Same as above, but replace `-flto` with `-flto=thin` throughout.

**Why LTO in Debug builds?**
- Helps identify LTO-specific bugs during development
- Allows symbol stripping while keeping debug info elsewhere

### Build Process

```dockerfile
# Base image (no LTO)
FROM p120ph37/alpine-clang-vcpkg:base AS base
# ... existing setup ...

# :latest-lto-thin variant
FROM base AS latest-lto-thin
COPY triplets/lto-thin/arm64-linux.cmake /opt/vcpkg/triplets/
COPY triplets/lto-thin/x64-linux.cmake /opt/vcpkg/triplets/
COPY toolchains/lto-thin.cmake /opt/vcpkg/toolchains/
LABEL variant="latest-lto-thin" \
      lto="thin" \
      optimization="-O2"

# :latest-lto variant  
FROM base AS latest-lto
COPY triplets/lto/arm64-linux.cmake /opt/vcpkg/triplets/
COPY triplets/lto/x64-linux.cmake /opt/vcpkg/triplets/
COPY toolchains/lto.cmake /opt/vcpkg/toolchains/
LABEL variant="latest-lto" \
      lto="full" \
      optimization="-O2"
```

## Benefits

### For Users
✅ **Zero configuration** for common case (just pick image tag)  
✅ **Discoverable** - see options directly in Docker Hub  
✅ **Still overridable** - can use custom triplets if needed  
✅ **Consistent** - all projects using `:lto-full` get same optimization  
✅ **No learning curve** - just change image tag, everything else identical

### For Maintainers
✅ **Centralized** - LTO config maintained in one place (image), not every project  
✅ **Testable** - can verify LTO works across various vcpkg packages  
✅ **Versioned** - LTO config tied to image version  
✅ **Reduces support burden** - fewer "LTO not working" issues

## Trade-offs and Considerations

### Potential Issues

**1. Increased build times for dependencies**
- LTO makes vcpkg dependency builds 20-30% slower
- Mitigation: Users who need speed keep using `:latest`
- Benefit: One-time cost; users typically cache vcpkg builds

**2. Image size**
- Multiple variants = multiple images to maintain
- Mitigation: Variants are tiny (just different triplet files ~1KB each)
- Can use multi-stage build with shared base layer

**3. Breaking changes for users**
- If `:latest` suddenly had LTO, it would break debug workflows
- Mitigation: Keep `:latest` unchanged, LTO is opt-in via tags

**4. vcpkg cache compatibility**
- LTO-built packages in cache won't work with non-LTO builds
- Mitigation: Document cache implications, recommend per-variant caches

### Documentation Requirements

**In README (which becomes Docker Hub description):**
```markdown
## Image Variants

- `alpine-clang-vcpkg:latest` - Standard build, no LTO
- `alpine-clang-vcpkg:latest-lto-thin` - ThinLTO with -O2, faster builds, ~1% larger binaries
- `alpine-clang-vcpkg:latest-lto` - Full LTO with -O2, smallest binaries, best optimization

Optimization level defaults to `-O2` but can be overridden by users via CMake flags.
```

### Migration Path

- Keep `:latest` unchanged
- Add `:latest-lto` and `:latest-lto-thin` as new tags
- Document in README / Docker Hub (keep documentation in README concise)
- Update examples to use `:latest-lto`
