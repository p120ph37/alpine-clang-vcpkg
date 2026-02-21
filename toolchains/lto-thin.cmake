# ThinLTO toolchain
# This toolchain is automatically applied to:
# 1. All vcpkg dependency builds (via triplet chainloading)
# 2. User project builds (via vcpkg.cmake chainloading)
#
# Only LTO-specific flags are added here.  All other flags (optimization
# level, debug info, NDEBUG, etc.) are left at CMake's built-in defaults
# so that the LTO variants differ from the baseline image only in LTO.

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# LTO flags in _INIT so they cannot be overridden by vcpkg ports
# that set CMAKE_C_FLAGS directly.
set(CMAKE_C_FLAGS_INIT   "-flto=thin -ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_INIT "-flto=thin -ffunction-sections -fdata-sections")

set(CMAKE_EXE_LINKER_FLAGS_INIT    "-fuse-ld=lld -flto=thin -Wl,--gc-sections -Wl,--icf=all")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld -flto=thin -Wl,--gc-sections -Wl,--icf=all")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld -flto=thin -Wl,--gc-sections -Wl,--icf=all")

# ── User-customizable flags ─────────────────────────────────────────────────
# Set EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS in the environment to
# inject flags into ALL builds, including vcpkg dependency builds.
#
# Examples:
#   EXTRA_CFLAGS="-Oz"                  # optimise for size everywhere
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
