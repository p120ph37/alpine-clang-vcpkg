# linux.cmake — vcpkg Linux toolchain wrapper
#
# Installed into $VCPKG_ROOT/scripts/toolchains/linux.cmake during the Docker
# build (the upstream file is renamed to linux-upstream.cmake first).
#
# This wrapper includes the upstream vcpkg Linux toolchain (preserving all
# standard setup) and then applies compiler-rt defaults and EXTRA_* flag
# injection via the shared extra-flags.cmake module.
#
# Compiler selection is handled by the symlinks installed in the image
# (cc → clang, ld → lld, ar → llvm-ar, etc.), so no CMAKE_*_COMPILER
# overrides are needed here.
#
# Because VCPKG_CHAINLOAD_TOOLCHAIN_FILE is NOT consumed by this wrapper,
# users are free to set it in their own triplets exactly as they would on a
# vanilla vcpkg installation.

if(_VCPKG_LINUX_TOOLCHAIN_WRAPPER)
    return()
endif()
set(_VCPKG_LINUX_TOOLCHAIN_WRAPPER 1)

include("${CMAKE_CURRENT_LIST_DIR}/linux-upstream.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/extra-flags.cmake")
