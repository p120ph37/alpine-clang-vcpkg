# extra-flags.cmake — compiler-rt defaults + EXTRA_* environment variable support
#
# This module is included by two wrappers:
#   • toolchains/linux.cmake      — applies flags to vcpkg port builds
#   • buildsystems/vcpkg.cmake    — applies flags to the main project build
#
# It selects LLVM's compiler-rt and libunwind as the default runtime libraries
# (instead of GCC's libgcc/libgcc_s), and reads EXTRA_CFLAGS / EXTRA_CXXFLAGS /
# EXTRA_LDFLAGS from the environment so users can inject flags (LTO, optimization
# level, -march, etc.) into every build at container run time or in a derived
# Dockerfile.
#
# Guarded to prevent double-inclusion (e.g. if a user explicitly chainloads
# a toolchain that also includes this file).

if(_ALPINE_CLANG_EXTRA_FLAGS)
    return()
endif()
set(_ALPINE_CLANG_EXTRA_FLAGS 1)

# ── Runtime library: compiler-rt + libunwind (instead of libgcc) ─────
# Use LLVM's compiler-rt builtins and libunwind instead of GCC's libgcc
# and libgcc_s.  These flags are passed to the clang driver at link time.
# To revert to libgcc for a specific build, pass --rtlib=libgcc and/or
# --unwindlib=libgcc_s via EXTRA_LDFLAGS.
string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT    " --rtlib=compiler-rt --unwindlib=libunwind")
string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " --rtlib=compiler-rt --unwindlib=libunwind")
string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " --rtlib=compiler-rt --unwindlib=libunwind")

# ── Link-group wrapping (arm64 circular-dependency fix) ───────────────
# On aarch64, compiler-rt's outline atomic helpers call getauxval() from
# libc, creating a circular dependency when any static archive uses
# atomics:  archive → compiler-rt → libc → …
#
# The clang driver wraps its implicit runtime libraries in a link group,
# but CMake places explicit archive paths (e.g. vcpkg-installed .a files)
# outside that group.  Wrapping <LINK_LIBRARIES> with --start-group /
# --end-group ensures the linker rescans all archives to resolve circular
# references between user libraries, compiler-rt, and libc.
#
# This is harmless on non-arm64 (no outline atomics, nothing to rescan)
# and on targets that don't produce executables (shared/module libraries
# use a different link rule).
set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_C_COMPILER> <FLAGS> <CMAKE_C_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> -Wl,--start-group <LINK_LIBRARIES> -Wl,--end-group")
set(CMAKE_CXX_LINK_EXECUTABLE
    "<CMAKE_CXX_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> -Wl,--start-group <LINK_LIBRARIES> -Wl,--end-group")

# ── Base flags (all build types) ─────────────────────────────────────
# Set EXTRA_CFLAGS / EXTRA_CXXFLAGS / EXTRA_LDFLAGS in the environment to
# inject flags into ALL builds — both vcpkg dependencies and your project.
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
