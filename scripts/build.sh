#!/bin/sh
#
# usb-serial-enable: Build the kernel with USB serial support enabled.
#

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE=${WORKSPACE:-$HOME/op5-kernel}
TOOLCHAINS="$WORKSPACE/toolchains"
OUT=${OUT:-$REPO_DIR/out}

. "$REPO_DIR/toolchains.conf"

CLANG="$TOOLCHAINS/$LLVM_TAG"
GCC64="$TOOLCHAINS/gcc64"
GCC32="$TOOLCHAINS/gcc32"
BUILD_TOOLS="$TOOLCHAINS/android_prebuilts_build-tools-${BUILD_TOOLS_HASH}"

export PATH="$CLANG/bin:$GCC64/bin:$GCC32/bin:$BUILD_TOOLS/path/linux-x86:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-

for tool in \
    clang \
    aarch64-linux-android-gcc \
    arm-linux-androideabi-gcc; do
    command -v "$tool" > /dev/null 2>&1 ||
    {
        echo "ERROR: required compiler tool not found: $tool" >&2
        exit 1
    }
done

cd "$REPO_DIR"
mkdir -p "$OUT"

make O="$OUT" \
    ARCH=arm64 \
    SUBARCH=arm64 \
    LLVM=1 \
    lineage_oneplus5_defconfig

# Fail early if key requested options were not resolved to =y.
for option in \
  CONFIG_USB_ACM \
  CONFIG_USB_SERIAL \
  CONFIG_USB_SERIAL_CH341 \
  CONFIG_USB_SERIAL_CP210X \
  CONFIG_USB_SERIAL_FTDI_SIO \
  CONFIG_USB_SERIAL_PL2303 \
  CONFIG_CAN \
  CONFIG_CAN_GS_USB \
  CONFIG_USB_VIDEO_CLASS \
  CONFIG_USB_UAS; do
  grep -q "^${option}=y$" "$OUT/.config" || {
    echo "ERROR: ${option} did not resolve to =y" >&2
    exit 1
  }
done

make -j"$(nproc)" O="$OUT" \
    ARCH=arm64 \
    SUBARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    LLVM=1

IMAGE="$OUT/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMAGE" ] || {
  echo "ERROR: expected kernel image not found: $IMAGE" >&2
  exit 1
}

printf '\nBuilt kernel:\n%s\n' "$IMAGE"
sha256sum "$IMAGE"
