cmake_minimum_required(VERSION 3.20)
project(toolchain-test C)

# Enable LTO — requires LLVM tools (llvm-ar, lld); GNU ar cannot parse
# LLVM bitcode objects so this doubles as proof that the toolchain is pure-LLVM.
include(CheckIPOSupported)
check_ipo_supported(RESULT ipo_supported OUTPUT ipo_error)
if(NOT ipo_supported)
    message(FATAL_ERROR "LTO is not supported: ${ipo_error}")
endif()
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)

find_package(ZLIB REQUIRED)

# --- shared library ----------------------------------------------------------
add_library(mylib_shared SHARED mylib.c)
set_target_properties(mylib_shared PROPERTIES OUTPUT_NAME mylib)

# --- static library ----------------------------------------------------------
add_library(mylib_static STATIC mylib.c)
set_target_properties(mylib_static PROPERTIES OUTPUT_NAME mylib)

# --- dynamically-linked executable -------------------------------------------
add_executable(hello_dynamic main.c)
target_link_libraries(hello_dynamic PRIVATE mylib_shared ZLIB::ZLIB)

# --- statically-linked executable --------------------------------------------
# Links vcpkg-installed zlib + atomics, exercising the full static-linking
# path including compiler-rt ↔ libc circular dependency resolution on arm64.
add_executable(hello_static main.c)
target_link_libraries(hello_static PRIVATE mylib_static ZLIB::ZLIB)
target_link_options(hello_static PRIVATE -static)
