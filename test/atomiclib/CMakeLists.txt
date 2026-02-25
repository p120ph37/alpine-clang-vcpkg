cmake_minimum_required(VERSION 3.20)
project(atomiclib C)

add_library(atomiclib STATIC atomiclib.c)
target_include_directories(atomiclib
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
)

install(TARGETS atomiclib EXPORT atomiclib-targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)
install(FILES atomiclib.h DESTINATION include)
install(EXPORT atomiclib-targets
    FILE atomiclib-config.cmake
    NAMESPACE atomiclib::
    DESTINATION share/atomiclib
)
