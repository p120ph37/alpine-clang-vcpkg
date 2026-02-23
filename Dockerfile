# Build environment with clang + vcpkg on Alpine (musl)
FROM alpine:latest AS builder

# Install clang/LLVM toolchain and build dependencies
RUN apk add --no-cache \
    clang \
    clang-static \
    compiler-rt \
    lld \
    llvm \
    llvm-libunwind-dev \
    llvm-libunwind-static \
    musl-dev \
    cmake \
    ninja \
    git \
    curl \
    zip \
    unzip \
    tar \
    pkgconf \
    linux-headers \
    patch \
    perl \
    bash \
    autoconf \
    automake \
    libtool \
    make

# ── Purge GCC / GNU binutils files, keep only what the clang driver needs ──
#
# clang21 depends on the "gcc" apk for a handful of object files it passes to
# the linker (crtbeginS.o, crtendS.o, libgcc.a, …).  The gcc package in turn
# pulls in binutils (GNU ar, ld.bfd, …).  We want a pure-LLVM toolchain, so:
#
#   1. Keep the CRT objects + static libgcc in the GCC resource directory
#      (clang hardcodes this search path via --print-search-dirs).
#   2. Keep the libgcc_s.so linker script (resolves -lgcc_s → libgcc_s.so.1
#      which is owned by the separate "libgcc" apk).
#   3. Delete everything else from both packages — binaries, headers, sanitizer
#      libs, ld scripts, plugins.
#   4. Do NOT run `apk del gcc binutils`.  Because gcc is not in /etc/apk/world
#      (it is an auto-installed dependency of clang21), leaving its entry in the
#      apk database means future `apk add` of any package that depends on gcc
#      will see the dependency as already satisfied and skip re-installation.
#   5. Replace every removed tool with a symlink to its LLVM equivalent — both
#      in /usr/bin and in the GCC-sysroot bin dir that the clang driver uses.
#
# Note: The CMake toolchain wrapper sets --rtlib=compiler-rt and
# --unwindlib=libunwind so that builds link against LLVM's compiler-rt builtins
# and libunwind instead of libgcc/libgcc_s.  The GCC CRT objects and libgcc
# files are still retained because the clang driver references them for startup
# object discovery, and to allow users to opt back to libgcc if needed.

RUN set -eu; \
    # Discover paths from installed files (works on any arch without detection)
    GCC_DIR=$(echo /usr/lib/gcc/*/*) && \
    SYSROOT_BIN=$(echo /usr/*-linux-musl*/bin) && \
    \
    # --- (1) remove gcc compiler binaries -----------------------------------
    rm -f /usr/bin/c89 /usr/bin/c99 /usr/bin/cc /usr/bin/cpp /usr/bin/gcc \
          /usr/bin/gcc-ar /usr/bin/gcc-nm /usr/bin/gcc-ranlib \
          /usr/bin/gcov /usr/bin/gcov-dump /usr/bin/gcov-tool \
          /usr/bin/lto-dump && \
    rm -f /usr/bin/*-linux-musl*-* && \
    \
    # --- (2) remove gcc libraries we do not need ----------------------------
    rm -f /usr/lib/libasan*  /usr/lib/libhwasan* /usr/lib/liblsan* \
          /usr/lib/libtsan*  /usr/lib/libubsan*  /usr/lib/libsanitizer.spec \
          /usr/lib/libitm*   /usr/lib/libcc1* \
          /usr/lib/libgomp.a /usr/lib/libgomp.so \
          /usr/lib/libatomic.a /usr/lib/libatomic.so \
          /usr/lib/libstdc++.modules.json \
          /usr/lib/bfd-plugins/liblto_plugin.so && \
    \
    # --- (3) strip gcc resource dir to CRT + libgcc -------------------------
    rm -rf "$GCC_DIR"/include "$GCC_DIR"/include-fixed \
           "$GCC_DIR"/install-tools "$GCC_DIR"/plugin && \
    rm -f  "$GCC_DIR"/libcaf_single.a "$GCC_DIR"/libgcov.a \
           "$GCC_DIR"/libgomp.spec "$GCC_DIR"/libitm.spec && \
    find /usr/lib/gcc -maxdepth 1 -type l -delete && \
    \
    # --- (4) remove binutils binaries, libs and ld scripts ------------------
    rm -f /usr/bin/addr2line /usr/bin/ar /usr/bin/as /usr/bin/c++filt \
          /usr/bin/dwp /usr/bin/elfedit /usr/bin/gprof \
          /usr/bin/ld /usr/bin/ld.bfd /usr/bin/nm \
          /usr/bin/objcopy /usr/bin/objdump /usr/bin/ranlib \
          /usr/bin/readelf /usr/bin/size /usr/bin/strings /usr/bin/strip && \
    rm -rf /usr/lib/libbfd* /usr/lib/libctf* /usr/lib/libopcodes* \
           /usr/lib/libsframe* \
           /usr/*-linux-musl*/bin \
           /usr/*-linux-musl*/lib/ldscripts && \
    \
    # --- (5) LLVM symlinks in /usr/bin --------------------------------------
    ln -s llvm-addr2line /usr/bin/addr2line && \
    ln -s llvm-ar        /usr/bin/ar        && \
    ln -s llvm-cxxfilt   /usr/bin/c++filt   && \
    ln -s llvm-dwp       /usr/bin/dwp       && \
    ln -s lld            /usr/bin/ld         && \
    ln -s llvm-nm        /usr/bin/nm         && \
    ln -s llvm-objcopy   /usr/bin/objcopy    && \
    ln -s llvm-objdump   /usr/bin/objdump    && \
    ln -s llvm-ranlib    /usr/bin/ranlib     && \
    ln -s llvm-readelf   /usr/bin/readelf    && \
    ln -s llvm-size      /usr/bin/size       && \
    ln -s llvm-strings   /usr/bin/strings    && \
    ln -s llvm-strip     /usr/bin/strip      && \
    ln -s clang          /usr/bin/cc         && \
    \
    # --- (6) LLVM symlinks in the GCC-sysroot bin dir -----------------------
    # The clang driver looks for the linker here:
    #   <gcc-install>/../../../<target>/bin/ld
    mkdir -p "$SYSROOT_BIN" && \
    ln -s /usr/bin/lld          "$SYSROOT_BIN"/ld      && \
    ln -s /usr/bin/llvm-ar      "$SYSROOT_BIN"/ar      && \
    ln -s /usr/bin/llvm-as      "$SYSROOT_BIN"/as      && \
    ln -s /usr/bin/llvm-nm      "$SYSROOT_BIN"/nm      && \
    ln -s /usr/bin/llvm-objcopy "$SYSROOT_BIN"/objcopy && \
    ln -s /usr/bin/llvm-objdump "$SYSROOT_BIN"/objdump && \
    ln -s /usr/bin/llvm-ranlib  "$SYSROOT_BIN"/ranlib  && \
    ln -s /usr/bin/llvm-readelf "$SYSROOT_BIN"/readelf && \
    ln -s /usr/bin/llvm-strip   "$SYSROOT_BIN"/strip

# ── Rebuild musl with LTO ────────────────────────────────────────────────
#
# Alpine's musl is compiled without -flto, so libc.a contains native objects
# that cannot participate in link-time optimization.  We rebuild musl from
# Alpine's exact source + patches, adding -flto so that:
#   • libc.a contains LLVM bitcode — static binaries get whole-program LTO
#     across the application/libc boundary
#   • CRT objects (crt1.o, crti.o, …) contain bitcode as well
#
# We build only the static library and CRT objects.  The dynamic linker
# (libc.so) uses self-modifying relocations in its bootstrap code that LTO
# cannot handle, so the system libc.so from Alpine is left as-is.
#
# Everything (fetch, build, install, cleanup) runs in a single RUN so that
# intermediate files never appear in a layer.

RUN set -eu; \
    # Fetch Alpine's musl source tree (patches + supplementary files)
    ALPINE_VER=$(cut -d. -f1,2 /etc/alpine-release) && \
    git clone --depth 1 --branch "${ALPINE_VER}-stable" \
        --filter=blob:none --sparse \
        https://git.alpinelinux.org/aports /tmp/aports && \
    cd /tmp/aports && git sparse-checkout set main/musl && \
    \
    # Extract musl upstream version from APKBUILD
    MUSL_VER=$(sed -n 's/^pkgver=//p' /tmp/aports/main/musl/APKBUILD) && \
    \
    # Download and extract musl source
    curl -fsSL "https://musl.libc.org/releases/musl-${MUSL_VER}.tar.gz" \
        | tar xz -C /tmp && \
    cd /tmp/musl-${MUSL_VER} && \
    \
    # Apply Alpine's patches in APKBUILD-listed order
    # (restrict to the source= section to avoid matching sha512sums lines)
    sed -n '/^source="/,/"$/{s/^[[:space:]]*//; /\.patch$/p}' \
        /tmp/aports/main/musl/APKBUILD \
    | while read -r p; do \
        patch -p1 < "/tmp/aports/main/musl/$p"; \
    done && \
    \
    # Replicate Alpine's prepare(): remove hand-optimized x86_64 string
    # functions (no-op on other arches) and write the VERSION file
    rm -f src/string/x86_64/memcpy.s src/string/x86_64/memmove.s && \
    echo "${MUSL_VER}" > VERSION && \
    \
    # Configure and build with LTO.
    # musl's configure adds its own -Os; we only append -flto for bitcode.
    # We build only the static library and CRT objects — the dynamic linker
    # (libc.so) uses self-modifying relocations in its bootstrap code that
    # LTO cannot handle, so we leave the system libc.so from Alpine as-is.
    CFLAGS="-flto" \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --enable-debug && \
    make -j$(nproc) lib/libc.a lib/crt1.o lib/Scrt1.o lib/rcrt1.o \
                     lib/crti.o lib/crtn.o && \
    cp -f lib/libc.a lib/crt1.o lib/Scrt1.o lib/rcrt1.o \
          lib/crti.o lib/crtn.o /usr/lib/ && \
    \
    # Rebuild libssp_nonshared.a with LTO bitcode
    cc -flto -c /tmp/aports/main/musl/__stack_chk_fail_local.c \
        -o /tmp/__stack_chk_fail_local.o && \
    ar rcs /usr/lib/libssp_nonshared.a /tmp/__stack_chk_fail_local.o && \
    \
    # Cleanup
    rm -rf /tmp/aports /tmp/musl-* /tmp/__stack_chk_fail_local.o

# Install vcpkg
ENV VCPKG_ROOT=/opt/vcpkg
ENV VCPKG_FORCE_SYSTEM_BINARIES=1
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git $VCPKG_ROOT && \
    $VCPKG_ROOT/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s $VCPKG_ROOT/vcpkg /usr/local/bin/vcpkg && \
    # Rename the upstream linux toolchain so our wrapper can include() it.
    mv $VCPKG_ROOT/scripts/toolchains/linux.cmake \
       $VCPKG_ROOT/scripts/toolchains/linux-upstream.cmake

# Install our linux.cmake wrapper (adds EXTRA_* env-var support).
COPY toolchains/linux.cmake $VCPKG_ROOT/scripts/toolchains/linux.cmake

# ── Test stage: verify the toolchain works end-to-end ────────────────────────
#
# Builds a small CMake project with LTO enabled, producing both a dynamically-
# linked and a statically-linked binary.  LTO requires LLVM tools (llvm-ar,
# lld) — GNU ar cannot parse LLVM bitcode, so a successful LTO build proves
# the toolchain is pure-LLVM.  We also verify that LTO correctly strips the
# unused library function from the static binary.
FROM builder AS test

COPY test/ /tmp/test/
RUN set -eu; \
    # --- Validate: CMake autodetects Clang, not GCC ---
    # If cc still points to gcc, the toolchain overrides are broken.
    cc --version 2>&1 | head -1 | grep -qi clang || \
        { echo "FAIL: cc is not clang" >&2; cc --version >&2; exit 1; } && \
    \
    cmake -G Ninja -S /tmp/test -B /tmp/test/build \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build /tmp/test/build && \
    \
    # --- Validate: dynamic binary runs correctly ---
    echo "Dynamic binary output: $(/tmp/test/build/hello_dynamic)" && \
    test "$(/tmp/test/build/hello_dynamic)" = "result = 42" && \
    \
    # --- Validate: static binary runs correctly ---
    echo "Static binary output: $(/tmp/test/build/hello_static)" && \
    test "$(/tmp/test/build/hello_static)" = "result = 42" && \
    \
    # --- Validate: LTO stripped unused_func from the static binary ---
    # used_func may be inlined at -O3, so we only assert unused_func is absent.
    # Check both the symbol table and the raw string data.
    if nm /tmp/test/build/hello_static 2>/dev/null | grep -q unused_func; then \
        echo "FAIL: unused_func symbol not stripped by LTO" >&2; exit 1; \
    fi && \
    if strings /tmp/test/build/hello_static | grep -q unused_func; then \
        echo "FAIL: unused_func string not stripped by LTO" >&2; exit 1; \
    fi && \
    \
    # --- Validate: musl libc.a contains LLVM bitcode (proves LTO rebuild) ---
    # exit.lo is always compiled from C (src/exit/exit.c), never assembly.
    # musl uses the .lo suffix for its object files.
    ar x /usr/lib/libc.a exit.lo && \
    llvm-bcanalyzer exit.lo > /dev/null 2>&1 || \
        { echo "FAIL: libc.a does not contain LLVM bitcode" >&2; exit 1; } && \
    rm -f exit.lo && \
    \
    echo "All toolchain tests passed."

# ── Final image: the build environment that gets tagged / pushed ─────────────
FROM builder
WORKDIR /src
