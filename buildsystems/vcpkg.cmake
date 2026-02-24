# vcpkg.cmake wrapper — applies EXTRA_* flags to the main project build
#
# Installed into $VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake during the
# Docker build (the upstream file is renamed to vcpkg-upstream.cmake first).
#
# Without this wrapper, the EXTRA_* environment variables and compiler-rt
# defaults from extra-flags.cmake would only apply to vcpkg port builds
# (via toolchains/linux.cmake).  This wrapper includes extra-flags.cmake
# before the upstream vcpkg.cmake so that the same flags are applied
# uniformly to both port builds and the user's main project.
#
# VCPKG_CHAINLOAD_TOOLCHAIN_FILE is handled entirely by the upstream
# vcpkg.cmake and is unaffected by this wrapper.

include("${CMAKE_CURRENT_LIST_DIR}/../toolchains/extra-flags.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/vcpkg-upstream.cmake")
