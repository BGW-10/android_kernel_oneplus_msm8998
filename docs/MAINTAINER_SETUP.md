# OnePlus 5 LineageOS Kernel — Maintainer / Fork Setup Guide

> Intended repository path: `docs/MAINTAINER_SETUP.md`
>
> Companion user guide: `docs/BUILD_INSTALL.md`
>
> Target device: OnePlus 5 (`cheeseburger`, Snapdragon 835 / MSM8998)
>
> Base kernel: LineageOS `android_kernel_oneplus_msm8998`, branch `lineage-22.2`

## Purpose

This document is for the maintainer of a fork of the LineageOS OnePlus 5 kernel. It covers:

- creating the fork;
- keeping the fork easy to compare with LineageOS upstream;
- enabling the peripheral drivers useful for a Klipper / embedded-Linux host;
- adding reproducible toolchain and build automation;
- placing the user-facing build/install documentation in the repository.

The actual kernel behavior change should remain small and easy to audit. Toolchains themselves should **not** be committed to Git.

---

## 1. Fork the upstream kernel

Upstream repository:

```text
https://github.com/LineageOS/android_kernel_oneplus_msm8998
```

Fork it to your GitHub account first, then clone your fork:

```bash
git clone -b lineage-22.2 \
  https://github.com/YOUR_GITHUB_USERNAME/android_kernel_oneplus_msm8998.git

cd android_kernel_oneplus_msm8998
```

Add LineageOS as the upstream remote:

```bash
git remote add upstream https://github.com/LineageOS/android_kernel_oneplus_msm8998.git
git remote -v
```

Create a branch for the appliance/peripheral changes:

```bash
git checkout -b printer-host-support
```

Keep the fork based on the LineageOS `lineage-22.2` branch used by the phone's ROM generation.

---

## 2. Repository layout

Keep documentation and automation in the kernel repository, but keep downloaded toolchains and generated build artifacts outside it.

Recommended repository layout:

```text
android_kernel_oneplus_msm8998/
├── README.md
├── docs/
│   ├── MAINTAINER_SETUP.md
│   └── BUILD_INSTALL.md
├── scripts/
│   ├── setup-toolchains.sh
│   └── build.sh
├── toolchains.conf
├── arch/arm64/configs/
│   └── lineage_oneplus5_defconfig
└── ...normal kernel source...
```

Recommended workspace layout for a user/build machine:

```text
~/op5-kernel/
├── src/
│   └── android_kernel_oneplus_msm8998/   # Git checkout
├── toolchains/                            # downloaded; not committed
├── package/                               # generated artifacts; not committed
└── backups/                               # optional local boot backups
```

The two documentation files belong under `docs/`:

- `docs/MAINTAINER_SETUP.md` — this file, for maintainers/fork authors.
- `docs/BUILD_INSTALL.md` — user-facing clone/build/install instructions.

---

## 3. Ignore generated content

Append at least the following to `.gitignore`:

```gitignore
/out/
*.zip
*.img
```

Do **not** commit:

- Clang/GCC toolchain directories;
- downloaded build-tools trees;
- `out/`;
- boot images;
- AnyKernel build ZIPs;
- personal phone backups.

---

## 4. Audit the existing OnePlus 5 config

The relevant defconfig is:

```text
arch/arm64/configs/lineage_oneplus5_defconfig
```

The current LineageOS OnePlus 5 configuration already includes much of what a small Linux appliance needs, including USB host/OTG, mass storage, USB networking, HID/raw HID, USB audio, media framework support, gadget/configfs support, I2C/SPI userspace access, WireGuard, FUSE, and overlayfs.

Do not turn this into a kitchen-sink desktop kernel. Add only the missing peripheral support that is likely to matter for a 3D-printer host.

---

## 5. Enable the recommended peripheral support

Edit:

```bash
nano arch/arm64/configs/lineage_oneplus5_defconfig
```

Add or enable the following:

```text
# ------------------------------------------------------------------
# USB serial / Klipper MCU support
# ------------------------------------------------------------------
CONFIG_USB_ACM=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_CH341=y
CONFIG_USB_SERIAL_CP210X=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_PL2303=y

# ------------------------------------------------------------------
# Klipper / SocketCAN support
# ------------------------------------------------------------------
CONFIG_CAN=y
CONFIG_CAN_RAW=y
CONFIG_CAN_DEV=y
CONFIG_CAN_GS_USB=y
CONFIG_CAN_SLCAN=y

# ------------------------------------------------------------------
# Standard USB webcam support
# ------------------------------------------------------------------
CONFIG_USB_VIDEO_CLASS=y

# ------------------------------------------------------------------
# Modern USB storage bridges / SSDs
# ------------------------------------------------------------------
CONFIG_USB_UAS=y

# ------------------------------------------------------------------
# Optional: allow the phone itself to expose CDC ACM gadget serial
# ------------------------------------------------------------------
CONFIG_USB_CONFIGFS_ACM=y
```

If these conflicting lines exist, replace them:

```text
# CONFIG_USB_ACM is not set
# CONFIG_USB_SERIAL is not set
```

Why these are useful:

- `USB_ACM`: RP2040/STM32 virtual COM ports, many Klipper MCU boards, USB accelerometer boards.
- `USB_SERIAL_*`: CH340/CH341, CP210x, FTDI, and PL2303 adapters.
- `CAN_GS_USB`: common USB-to-CAN adapters used with Klipper toolhead boards.
- `CAN_SLCAN`: LAWICEL/SLCAN-style CAN adapters carried over a serial transport.
- `USB_VIDEO_CLASS`: ordinary UVC webcams as `/dev/video*`.
- `USB_UAS`: newer USB storage bridges and SSD/HDD enclosures.
- `USB_CONFIGFS_ACM`: optional device-side serial gadget support for PC-facing experiments.

Use `=y` instead of modules so Android module-loading details do not become another dependency.

---

## 6. Keep the functional kernel change isolated

Review only the defconfig change:

```bash
git diff -- arch/arm64/configs/lineage_oneplus5_defconfig
```

Commit it separately:

```bash
git add arch/arm64/configs/lineage_oneplus5_defconfig
git commit -m 'oneplus5: enable printer host peripheral support'
```

This keeps the actual kernel behavior change easy to review independently from docs and tooling.

---

## 7. Add pinned toolchain metadata

Create `toolchains.conf` in the repository root:

```bash
nano toolchains.conf
```

Use explicit pinned revisions rather than "latest":

```bash
LLVM_TAG=clang-r530567
AARCH64_GCC_HASH=5e030eafe024784a73cdf47e6936ac0dbfc763dc
ARM_GCC_HASH=111258a10e017f067b27e6cfcea7619d753f3309
BUILD_TOOLS_HASH=f61cfbcb609173e1040753a2b9e8fbe8517343f9
```

If these revisions are intentionally changed later, validate the resulting kernel before updating the pins in the repository.

---

## 8. Add `scripts/setup-toolchains.sh`

Create:

```bash
mkdir -p scripts docs
nano scripts/setup-toolchains.sh
```

Suggested contents:

```sh
#!/bin/sh
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
```

Make it executable:

```bash
chmod +x scripts/setup-toolchains.sh
```

---

## 9. Add `scripts/build.sh`

Create:

```bash
nano scripts/build.sh
```

Suggested contents:

```sh
#!/bin/sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE=${WORKSPACE:-$HOME/op5-kernel}
TOOLCHAINS="$WORKSPACE/toolchains"
OUT=${OUT:-$REPO_DIR/out}

. "$REPO_DIR/toolchains.conf"

CLANG="$TOOLCHAINS/$LLVM_TAG"
GCC64="$TOOLCHAINS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9-${AARCH64_GCC_HASH}"
GCC32="$TOOLCHAINS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9-${ARM_GCC_HASH}"
BUILD_TOOLS="$TOOLCHAINS/android_prebuilts_build-tools-${BUILD_TOOLS_HASH}"

export PATH="$CLANG/bin:$GCC64/bin:$GCC32/bin:$BUILD_TOOLS/path/linux-x86:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-

cd "$REPO_DIR"
mkdir -p "$OUT"

make O="$OUT" lineage_oneplus5_defconfig

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

make -j"$(nproc)" O="$OUT"

IMAGE="$OUT/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMAGE" ] || {
  echo "ERROR: expected kernel image not found: $IMAGE" >&2
  exit 1
}

printf '\nBuilt kernel:\n%s\n' "$IMAGE"
sha256sum "$IMAGE"
```

Make it executable:

```bash
chmod +x scripts/build.sh
```

The build script deliberately stops if the important Kconfig symbols do not resolve to `=y`.

---

## 10. Add the two documentation files

Create/maintain:

```text
docs/MAINTAINER_SETUP.md
docs/BUILD_INSTALL.md
```

`MAINTAINER_SETUP.md` should contain the fork/config/tooling workflow.

`BUILD_INSTALL.md` should contain only what an end user needs to:

1. verify phone prerequisites;
2. clone the fork;
3. install host packages;
4. run the toolchain setup script;
5. run the build script;
6. back up the phone's current boot image;
7. package or inject `Image.gz-dtb` into the existing boot image;
8. patch/repatch with Magisk if needed;
9. flash/test/recover;
10. verify the new kernel options and `/dev/ttyUSB*` / `/dev/ttyACM*` behavior.

Do not make end users reproduce the maintainer-only repository edits.

---

## 11. Commit the reproducibility work separately

For example:

```bash
git add toolchains.conf scripts docs .gitignore
git commit -m 'build: add reproducible standalone kernel workflow'
```

Then push the branch:

```bash
git push -u origin printer-host-support
```

Recommended commit separation:

```text
1. oneplus5: enable printer host peripheral support
2. build: add reproducible standalone kernel workflow
3. docs: add maintainer and user build/install guides
```

This keeps code/config changes independent from documentation/tooling history.

---

## 12. Validate the generated config before publishing

After running the build script, inspect:

```bash
grep -E '^CONFIG_(USB_ACM|USB_SERIAL|USB_SERIAL_GENERIC|USB_SERIAL_CH341|USB_SERIAL_CP210X|USB_SERIAL_FTDI_SIO|USB_SERIAL_PL2303|CAN|CAN_RAW|CAN_DEV|CAN_GS_USB|CAN_SLCAN|USB_VIDEO_CLASS|USB_UAS|USB_CONFIGFS_ACM)=' out/.config
```

Also verify the important pre-existing host capabilities remain enabled:

```bash
grep -E '^CONFIG_(USB_XHCI_HCD|USB_DWC3|DUAL_ROLE_USB_INTF|USB_STORAGE|USB_USBNET|USB_RTL8152|USB_LAN78XX|HIDRAW|SND_USB_AUDIO)=' out/.config
```

The goal is a minimal extension of the known-good LineageOS kernel, not a broad rewrite of its configuration.

---

## 13. Updating from LineageOS upstream later

Fetch upstream:

```bash
git fetch upstream
```

Rebase or merge deliberately onto the newer `lineage-22.2` state, resolve any defconfig changes, rebuild, and re-run the config validation before publishing a new build.

Keep toolchain pin updates separate from kernel-source updates whenever possible so regressions are easier to isolate.
