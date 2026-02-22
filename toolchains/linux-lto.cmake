# Full LTO linux.cmake wrapper
#
# Installed into $VCPKG_ROOT/scripts/toolchains/linux.cmake during the Docker
# build (the upstream file is renamed to linux-upstream.cmake first).
#
# This wrapper:
#   1. Includes the upstream vcpkg Linux toolchain so that all standard
#      setup is preserved (CMAKE_SYSTEM_NAME, -fPIC, VCPKG_C_FLAGS, cross-
#      compilation detection, CRT linkage, etc.).
#   2. Selects the LLVM/Clang compiler shipped in this image.
#   3. Appends full-LTO flags via string(APPEND … _INIT) so they compose
#      with — rather than replace — whatever the upstream toolchain set.
#   4. Reads EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS from the
#      environment so users can inject additional flags at container run
#      time.
#
# Because VCPKG_CHAINLOAD_TOOLCHAIN_FILE is NOT consumed by this approach,
# users are free to set it in their own triplets exactly as they would on a
# vanilla vcpkg installation.

if(NOT _VCPKG_ALPINE_CLANG_LTO)
set(_VCPKG_ALPINE_CLANG_LTO 1)

# ── 1. Upstream vcpkg linux toolchain ────────────────────────────────────────
include("${CMAKE_CURRENT_LIST_DIR}/linux-upstream.cmake")

# ── 2. Compiler selection ────────────────────────────────────────────────────
set(CMAKE_C_COMPILER   clang)
set(CMAKE_CXX_COMPILER clang++)

# ── 3. LTO flags ────────────────────────────────────────────────────────────
string(APPEND CMAKE_C_FLAGS_INIT   " -flto -ffunction-sections -fdata-sections")
string(APPEND CMAKE_CXX_FLAGS_INIT " -flto -ffunction-sections -fdata-sections")

string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT    " -fuse-ld=lld -flto -Wl,--gc-sections -Wl,--icf=all")
string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " -fuse-ld=lld -flto -Wl,--gc-sections -Wl,--icf=all")
string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " -fuse-ld=lld -flto -Wl,--gc-sections -Wl,--icf=all")

# ── 4. User-customizable flags ──────────────────────────────────────────────
# Set EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS in the environment to
# inject flags into ALL builds, including vcpkg dependency builds.
#
# Examples:
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
