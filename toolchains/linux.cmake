# linux.cmake wrapper — EXTRA_* env-var support
#
# Installed into $VCPKG_ROOT/scripts/toolchains/linux.cmake during the Docker
# build (the upstream file is renamed to linux-upstream.cmake first).
#
# This wrapper includes the upstream vcpkg Linux toolchain (preserving all
# standard setup) and then reads EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS
# from the environment so users can inject flags (LTO, optimization level,
# -march, etc.) into every build at container run time or in a derived
# Dockerfile.
#
# Compiler selection is handled by the symlinks installed in the image
# (cc → clang, ld → lld, ar → llvm-ar, etc.), so no CMAKE_*_COMPILER
# overrides are needed here.
#
# Because VCPKG_CHAINLOAD_TOOLCHAIN_FILE is NOT consumed by this wrapper,
# users are free to set it in their own triplets exactly as they would on a
# vanilla vcpkg installation.

if(NOT _VCPKG_LINUX_EXTRA_FLAGS)
set(_VCPKG_LINUX_EXTRA_FLAGS 1)

include("${CMAKE_CURRENT_LIST_DIR}/linux-upstream.cmake")

# ── Base flags (all build types) ─────────────────────────────────────
# Set EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS in the environment to
# inject flags into ALL builds, including vcpkg dependency builds.
#
# These are appended to CMAKE_<LANG>_FLAGS_INIT so they appear in every
# compiler invocation regardless of build type.
#
# Examples:
#   EXTRA_CFLAGS="-flto -ffunction-sections -fdata-sections"
#   EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all"
#   EXTRA_CFLAGS="-O2 -march=native"    # tune for the build machine
#   EXTRA_LDFLAGS="-Wl,-s"              # strip symbols at link time
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

# ── Per-config flag overrides ────────────────────────────────────────
# EXTRA_CFLAGS_<CONFIG> / EXTRA_CXXFLAGS_<CONFIG> / EXTRA_LDFLAGS_<CONFIG>
# replace CMake's platform-default flags for that build type using
# CACHE FORCE.  This solves the problem where base-flag optimization
# levels (e.g. -Oz in EXTRA_CFLAGS) are silently overridden by the
# per-config defaults (e.g. -O3 in CMAKE_C_FLAGS_RELEASE).
#
# Only active when explicitly set — existing behavior is unchanged.
#
# Examples:
#   EXTRA_CFLAGS_RELEASE="-Oz -DNDEBUG"   # size-optimized release
#   EXTRA_CFLAGS_DEBUG="-O0 -g"            # custom debug flags
#   EXTRA_LDFLAGS_RELEASE="-Wl,-s"         # strip only release builds
foreach(_config RELEASE DEBUG)
    if(DEFINED ENV{EXTRA_CFLAGS_${_config}})
        set(CMAKE_C_FLAGS_${_config} "$ENV{EXTRA_CFLAGS_${_config}}"
            CACHE STRING "" FORCE)
    endif()
    if(DEFINED ENV{EXTRA_CXXFLAGS_${_config}})
        set(CMAKE_CXX_FLAGS_${_config} "$ENV{EXTRA_CXXFLAGS_${_config}}"
            CACHE STRING "" FORCE)
    endif()
    if(DEFINED ENV{EXTRA_LDFLAGS_${_config}})
        set(CMAKE_EXE_LINKER_FLAGS_${_config}
            "$ENV{EXTRA_LDFLAGS_${_config}}" CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS_${_config}
            "$ENV{EXTRA_LDFLAGS_${_config}}" CACHE STRING "" FORCE)
        set(CMAKE_MODULE_LINKER_FLAGS_${_config}
            "$ENV{EXTRA_LDFLAGS_${_config}}" CACHE STRING "" FORCE)
    endif()
endforeach()

endif()
