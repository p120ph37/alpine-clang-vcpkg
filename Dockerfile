# Build environment with clang + vcpkg on Alpine (musl)
FROM alpine:3.21 AS builder

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

# Install vcpkg
ENV VCPKG_ROOT=/opt/vcpkg
ENV VCPKG_FORCE_SYSTEM_BINARIES=1
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git $VCPKG_ROOT && \
    $VCPKG_ROOT/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s $VCPKG_ROOT/vcpkg /usr/local/bin/vcpkg

WORKDIR /src
