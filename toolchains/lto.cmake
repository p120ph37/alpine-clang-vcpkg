# Full LTO toolchain
# This toolchain is automatically applied to:
# 1. All vcpkg dependency builds (via triplet chainloading)
# 2. User project builds (via vcpkg.cmake chainloading)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Base flags for all builds
set(CMAKE_C_FLAGS_INIT "-ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_INIT "-ffunction-sections -fdata-sections")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")

# Release: Full LTO with -O2 default (overridable via CMake flags)
set(CMAKE_C_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-flto -O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-flto -Wl,--gc-sections -Wl,--icf=all")

# Debug: LTO with debug symbols (useful for debugging LTO-specific issues)
set(CMAKE_C_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-flto -g -O0")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-flto -Wl,--gc-sections")
