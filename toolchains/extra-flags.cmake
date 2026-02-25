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

# ── aarch64: force-extract getauxval from libc (LTO + compiler-rt fix) ─
# On aarch64, compiler-rt's outline atomic helpers (native .o inside
# libclang_rt.builtins) reference getauxval() from musl's libc.a.  When
# the user's code is compiled with LTO, libc.a contains LLVM bitcode but
# compiler-rt remains native object code.  lld's LTO pipeline fails to
# pull the bitcode getauxval.lo from libc.a to satisfy the native object's
# undefined reference, leaving getauxval as a weak symbol at address 0
# and causing a segfault when the outline atomic init constructor runs.
#
# -Wl,-u,getauxval forces lld to extract getauxval.lo from libc.a
# unconditionally, ensuring the symbol is resolved before LTO runs.
# This is harmless on non-aarch64 (getauxval exists in musl on all
# architectures but is simply never referenced by compiler-rt).
#
# getauxval is the ONLY libc symbol unconditionally reachable from
# compiler-rt on any architecture.  All other compiler-rt builtins
# objects (emutls.c.o, int_util.c.o, etc.) are demand-linked — they
# are only extracted when the user's code references their trigger
# symbols, which also transitively resolves their libc dependencies.
# On x86_64, the equivalent cpu_model (x86.c.o) uses inline CPUID
# with no libc calls and is demand-linked only.
cmake_host_system_information(RESULT _host_arch QUERY OS_PLATFORM)
if(_host_arch STREQUAL "aarch64")
    string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -Wl,-u,getauxval")
endif()

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
