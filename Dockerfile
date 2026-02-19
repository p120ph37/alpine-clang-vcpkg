# Build environment with clang + vcpkg on Alpine (musl)
FROM alpine:latest AS builder

# Install clang/LLVM toolchain and build dependencies
RUN apk add --no-cache \
    clang \
    clang-static \
    lld \
    llvm \
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
    perl \
    bash \
    autoconf \
    automake \
    libtool \
    make

# Make LLVM tools the system-default ar/ranlib/ld.
# Alpine has no update-alternatives; symlinks are the idiomatic override mechanism.
# ln -sf replaces any existing binaries (e.g. GNU binutils) installed as transitive deps.
RUN ln -sf /usr/bin/llvm-ar     /usr/bin/ar     && \
    ln -sf /usr/bin/llvm-ranlib /usr/bin/ranlib  && \
    ln -sf /usr/bin/lld         /usr/bin/ld

# Install vcpkg
ENV VCPKG_ROOT=/opt/vcpkg
ENV VCPKG_FORCE_SYSTEM_BINARIES=1
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git $VCPKG_ROOT && \
    $VCPKG_ROOT/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s $VCPKG_ROOT/vcpkg /usr/local/bin/vcpkg

WORKDIR /src
