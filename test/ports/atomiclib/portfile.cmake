# The source lives alongside the overlay port, inside the test/ tree.
# CMAKE_CURRENT_LIST_DIR points to test/ports/atomiclib/, so go up two
# levels to reach test/, then into atomiclib/.
vcpkg_cmake_configure(
    SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../atomiclib"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME atomiclib)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
set(VCPKG_POLICY_SKIP_COPYRIGHT_CHECK enabled)
