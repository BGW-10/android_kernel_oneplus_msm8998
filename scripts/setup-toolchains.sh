#!/bin/sh
#
# usb-serial-enable: Setup toolchains for building the kernel.
#

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE=${WORKSPACE:-$HOME/op5-kernel}
TOOLCHAINS="$WORKSPACE/toolchains"

. "$REPO_DIR/toolchains.conf"

mkdir -p "$TOOLCHAINS"
cd "$TOOLCHAINS"

if [ ! -x "$LLVM_TAG/bin/clang" ]; then
  mkdir -p "$LLVM_TAG"
  curl -L \
    "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/${LLVM_TAG}.tar.gz" \
    | tar -xz -C "$LLVM_TAG"
fi

if [ ! -d "android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9-${AARCH64_GCC_HASH}" ]; then
  curl -L -o aarch64-gcc.zip \
    "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9/archive/${AARCH64_GCC_HASH}.zip"
  unzip -q aarch64-gcc.zip
fi

if [ ! -d "android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9-${ARM_GCC_HASH}" ]; then
  curl -L -o arm-gcc.zip \
    "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9/archive/${ARM_GCC_HASH}.zip"
  unzip -q arm-gcc.zip
fi

if [ ! -d "android_prebuilts_build-tools-${BUILD_TOOLS_HASH}" ]; then
  curl -L -o build-tools.zip \
    "https://github.com/LineageOS/android_prebuilts_build-tools/archive/${BUILD_TOOLS_HASH}.zip"
  unzip -q build-tools.zip
fi
