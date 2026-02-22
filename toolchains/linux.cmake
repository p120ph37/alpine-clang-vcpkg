# Alpine Clang linux.cmake wrapper
#
# Installed into $VCPKG_ROOT/scripts/toolchains/linux.cmake during the Docker
# build (the upstream file is renamed to linux-upstream.cmake first).
#
# This wrapper:
#   1. Includes the upstream vcpkg Linux toolchain so that all standard
#      setup is preserved (CMAKE_SYSTEM_NAME, -fPIC, VCPKG_C_FLAGS, cross-
#      compilation detection, CRT linkage, etc.).
#   2. Selects the LLVM/Clang compiler shipped in this image.
#   3. Reads EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS from the
#      environment so users can inject flags (LTO, optimization level,
#      -march, etc.) into all builds at container run time.
#
# Because VCPKG_CHAINLOAD_TOOLCHAIN_FILE is NOT consumed by this wrapper,
# users are free to set it in their own triplets exactly as they would on a
# vanilla vcpkg installation.

if(NOT _VCPKG_ALPINE_CLANG)
set(_VCPKG_ALPINE_CLANG 1)

# ── 1. Upstream vcpkg linux toolchain ────────────────────────────────────────
include("${CMAKE_CURRENT_LIST_DIR}/linux-upstream.cmake")

# ── 2. Compiler selection ────────────────────────────────────────────────────
set(CMAKE_C_COMPILER   clang)
set(CMAKE_CXX_COMPILER clang++)

# ── 3. User-customizable flags ──────────────────────────────────────────────
# Set EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS in the environment to
# inject flags into ALL builds, including vcpkg dependency builds.
#
# Examples:
#   EXTRA_CFLAGS="-flto -ffunction-sections -fdata-sections"
#   EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all"
#   EXTRA_CFLAGS="-Oz"                  # optimize for size everywhere
#   EXTRA_CFLAGS="-O2 -march=native"    # tune for the build machine
#   EXTRA_LDFLAGS="-Wl,-s"             # strip symbols at link time
if(DEFINED ENV{EXTRA_CFLAGS})
    string(APPEND CMAKE_C_FLAGS_INIT " $ENV{EXTRA_CFLAGS}")
endif()
if(DEFINED ENV{EXTRA_CXXFLAGS})
    string(APPEND CMAKE_CXX_FLAGS_INIT " $ENV{EXTRA_CXXFLAGS}")
endif()
if(DEFINED ENV{EXTRA_LDFLAGS})
    string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT    " $ENV{EXTRA_LDFLAGS}")
    string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " $ENV{EXTRA_LDFLAGS}")
    string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " $ENV{EXTRA_LDFLAGS}")
endif()

endif()
