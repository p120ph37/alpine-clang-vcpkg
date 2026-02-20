set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# Chainload shared toolchain - applies to BOTH vcpkg deps AND user project!
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "/opt/vcpkg/toolchains/lto.cmake")
