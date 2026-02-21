# ThinLTO toolchain
# This toolchain is automatically applied to:
# 1. All vcpkg dependency builds (via triplet chainloading)
# 2. User project builds (via vcpkg.cmake chainloading)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Base flags for all builds — LTO flags go here so they cannot be
# overridden by vcpkg ports that set CMAKE_C_FLAGS_RELEASE directly.
set(CMAKE_C_FLAGS_INIT "-ffunction-sections -fdata-sections -flto=thin")
set(CMAKE_CXX_FLAGS_INIT "-ffunction-sections -fdata-sections -flto=thin")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld -flto=thin")

# Release: -O2 default (overridable via CMake flags)
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-O2 -DNDEBUG -fvisibility=hidden")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-Wl,--gc-sections -Wl,--icf=all")

# Debug: debug symbols
set(CMAKE_C_FLAGS_DEBUG_INIT "-g -O0")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-g -O0")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-Wl,--gc-sections")
