# OnePlus 5 Custom LineageOS Kernel - Build & Install Guide

> Repository path: `docs/BUILD_INSTALL.md`
>
> This guide is for users of a prepared fork. It does **not** require a full Android or LineageOS source checkout.

## What this kernel adds

The fork stays close to the LineageOS OnePlus 5 kernel while enabling peripherals useful for a Klipper / embedded-Linux host:

- CDC ACM serial devices (`/dev/ttyACM*`);
- CH340/CH341, CP210x, FTDI, and PL2303 USB serial (`/dev/ttyUSB*`);
- SocketCAN and common `gs_usb` adapters;
- SLCAN;
- standard UVC USB webcams (`/dev/video*`);
- UAS storage;
- optional CDC ACM gadget support.

---

## 1. Phone prerequisites

Before flashing a custom kernel, the phone should already have:

- a **OnePlus 5** (`cheeseburger`);
- an unlocked bootloader;
- **LineageOS 22.2** installed and booting normally;
- the firmware required by that LineageOS installation;
- working USB debugging;
- working `adb` and `fastboot` access from a PC;
- a known-good LineageOS recovery / installation ZIP available for recovery;
- enough battery charge to safely perform the flash.

If you use Magisk/root and a Debian chroot, keep a known-good rooted boot image so you can preserve or restore that setup.

Confirm the device:

```bash
adb devices
adb shell getprop ro.product.device
adb shell uname -a
```

The device should report `cheeseburger`.

---

## 2. Check whether you actually need the custom kernel

For USB serial, connect the adapter or Klipper MCU through USB OTG and check:

```bash
adb shell su -c 'lsusb'
adb shell su -c 'ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'
```

The stock LineageOS kernel may enumerate the USB device while still lacking the driver needed to create `/dev/ttyUSB*` or `/dev/ttyACM*`.

If the required device node already exists and works, you do not need this custom kernel solely for USB serial.

---

## 3. Prepare the build machine

Supported practical environments include:

- native Debian/Ubuntu Linux;
- a Debian/Ubuntu VM;
- WSL2 with Debian or Ubuntu.

For WSL2, keep the project in the Linux filesystem:

```text
~/op5-kernel/
```

Do not build under `/mnt/c/...`.

Allow roughly **15-20 GB** of free space for source, toolchains, output, packaging, and backups.

Install the host packages:

```bash
sudo apt update
sudo apt install -y \
  bc \
  bison \
  build-essential \
  ca-certificates \
  cpio \
  curl \
  file \
  flex \
  git \
  libelf-dev \
  libncurses-dev \
  libssl-dev \
  make \
  python3 \
  rsync \
  unzip \
  wget \
  zip
```

`libssl-dev` is required for host-side kernel tools such as `scripts/extract-cert`. If it is missing, the build can fail with:

```text
fatal error: 'openssl/bio.h' file not found
```

---

## 4. Create the workspace and clone the prepared fork

```bash
mkdir -p ~/op5-kernel/{src,toolchains,package,backups}
cd ~/op5-kernel/src
```

Clone the prepared branch:

```bash
git clone -b printer-host-support \
  https://github.com/YOUR_GITHUB_USERNAME/android_kernel_oneplus_msm8998.git

cd android_kernel_oneplus_msm8998
```

Record the exact revision you are building:

```bash
git rev-parse HEAD
git log -1 --oneline
```

---

## 5. Download and verify the pinned toolchains

Run:

```bash
./scripts/setup-toolchains.sh
```

The script downloads the pinned build dependencies into:

```text
~/op5-kernel/toolchains/
```

The important compiler paths should then exist:

```text
~/op5-kernel/toolchains/<clang-tag>/bin/clang
~/op5-kernel/toolchains/gcc64/bin/aarch64-linux-android-gcc
~/op5-kernel/toolchains/gcc32/bin/arm-linux-androideabi-gcc
```

The old MSM8998 kernel can use Clang while still requiring the Android GCC 4.9 cross-tool prefixes, so all three toolchains are intentional.

If you want to verify manually:

```bash
find ~/op5-kernel/toolchains -type f -name 'aarch64-linux-android-gcc'
find ~/op5-kernel/toolchains -type f -name 'arm-linux-androideabi-gcc'
```

---

## 6. Build the kernel

Run:

```bash
./scripts/build.sh
```

The script:

1. verifies the required compiler commands are on `PATH`;
2. generates the OnePlus 5 config from `lineage_oneplus5_defconfig`;
3. verifies that the requested Kconfig options actually resolved to `=y`;
4. builds the standalone kernel with the pinned toolchains;
5. checks for `Image.gz-dtb`;
6. prints its SHA-256 checksum.

A successful build produces:

```text
out/arch/arm64/boot/Image.gz-dtb
```

### It may build surprisingly quickly

That is normal. You are compiling only the Linux kernel tree, not Android/LineageOS itself. On a modern multi-core desktop a clean build can take only a few minutes; incremental rebuilds can be considerably faster.

The important success criteria are:

```bash
test -f out/arch/arm64/boot/Image.gz-dtb && echo 'kernel image exists'
sha256sum out/arch/arm64/boot/Image.gz-dtb
```

and a successful exit from `./scripts/build.sh`.

### Optional config verification

```bash
grep -E '^CONFIG_(USB_ACM|USB_SERIAL|USB_SERIAL_GENERIC|USB_SERIAL_CH341|USB_SERIAL_CP210X|USB_SERIAL_FTDI_SIO|USB_SERIAL_PL2303|CAN_GS_USB|MEDIA_USB_SUPPORT|VIDEO_DEV|VIDEO_V4L2|USB_VIDEO_CLASS|USB_UAS|USB_CONFIGFS_ACM)=' out/.config
```

---

## 7. Back up the currently working boot partition

Do this **before flashing anything**.

From a PC with ADB access:

```bash
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot-known-good.img'
adb pull /sdcard/boot-known-good.img ~/op5-kernel/backups/
```

Verify the backup exists and record its checksum:

```bash
ls -lh ~/op5-kernel/backups/boot-known-good.img
sha256sum ~/op5-kernel/backups/boot-known-good.img
```

Keep this file somewhere safe. If an experimental kernel fails to boot, it provides a fast recovery path:

```bash
fastboot flash boot ~/op5-kernel/backups/boot-known-good.img
fastboot reboot
```

Also keep the matching LineageOS recovery image and installation ZIP available.

---

## 8. Package the kernel for the phone

The standalone build produces the kernel payload:

```text
out/arch/arm64/boot/Image.gz-dtb
```

It does **not** by itself produce a complete Android `boot.img`.

Use the packaging flow provided by the fork. A good lean flow should preserve the currently working LineageOS ramdisk and boot metadata and replace only the kernel payload. Common approaches are:

- an AnyKernel3 installer ZIP; or
- unpacking a known-good boot image with `magiskboot`, replacing the kernel, and repacking it.

Do not invent new boot parameters or rebuild the ramdisk from scratch unless the fork specifically requires that.

---

## 9. Preserve Magisk/root when applicable

If the resulting `boot.img` is not already Magisk-patched, copy it to the phone:

```bash
adb push boot.img /sdcard/Download/
```

In Magisk:

```text
Install
-> Select and Patch a File
-> /sdcard/Download/boot.img
```

Pull the patched image back:

```bash
adb pull /sdcard/Download/magisk_patched-*.img ~/op5-kernel/package/
```

Use the exact generated filename when testing or flashing.

---

## 10. Test/flash the new boot image

Before flashing, confirm Fastboot sees the phone:

```bash
adb reboot bootloader
fastboot devices
```

If your bootloader/fastboot setup supports temporary booting of the image, that is a useful first test. Otherwise flash the prepared image:

```bash
fastboot flash boot /path/to/your/new-boot.img
fastboot reboot
```

Keep the known-good image nearby until the new kernel has completed several normal boots and the required peripherals have been tested.

---

## 11. Verify the custom kernel after boot

Confirm Android boots normally first:

```bash
adb wait-for-device
adb shell uname -a
```

Confirm the requested options are present in the running kernel when `/proc/config.gz` is available:

```bash
adb shell su -c "zcat /proc/config.gz | grep -E 'CONFIG_USB_ACM=|CONFIG_USB_SERIAL=|CONFIG_USB_VIDEO_CLASS=|CONFIG_CAN_GS_USB=|CONFIG_USB_UAS='"
```

Then connect the USB-UART adapter or Klipper MCU through OTG:

```bash
adb shell su -c 'lsusb'
adb shell su -c 'dmesg | tail -100'
adb shell su -c 'ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'
```

Expected device-node examples are:

```text
/dev/ttyUSB0
/dev/ttyACM0
```

For a UVC webcam, check:

```bash
adb shell su -c 'ls -l /dev/video* 2>/dev/null'
```

For a `gs_usb` CAN adapter, check the kernel log and network interfaces after connecting it.

---

## 12. Verify access from the Debian chroot

If Android creates the expected device node, enter the Debian chroot and verify that the device is visible there as well:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
ls -l /dev/video* 2>/dev/null
```

Depending on Android ownership, groups, SELinux policy, and how `/dev` is exposed into the chroot, additional permissions may still be needed even after the kernel driver works. Driver binding and userspace permission are separate problems.

For Klipper, use a stable device identity when possible rather than assuming the device will always remain `/dev/ttyUSB0`.

---

## 13. Recovery

If Android fails to boot or a critical hardware function stops working, return to fastboot and restore the known-good boot image:

```bash
fastboot flash boot ~/op5-kernel/backups/boot-known-good.img
fastboot reboot
```

Changing only the boot/kernel image should not erase `/data`, so the Android installation and Debian chroot normally remain intact. A boot backup is still essential because a bad kernel can prevent Android from reaching userspace.

---

## 14. Troubleshooting

### `CONFIG_USB_VIDEO_CLASS did not resolve to =y`

The UVC option has media/V4L2 dependencies. The prepared fork should already enable the required parent symbols. Inspect the resolved config:

```bash
grep -E '^CONFIG_(MEDIA_SUPPORT|MEDIA_CAMERA_SUPPORT|MEDIA_USB_SUPPORT|VIDEO_DEV|VIDEO_V4L2|USB_VIDEO_CLASS)=' out/.config
```

If the source tree was modified locally, regenerate from a clean output directory:

```bash
rm -rf out
./scripts/build.sh
```

### `aarch64-linux-android-gcc: not found`

Run:

```bash
./scripts/setup-toolchains.sh
```

Then verify:

```bash
export PATH="$HOME/op5-kernel/toolchains/gcc64/bin:$HOME/op5-kernel/toolchains/gcc32/bin:$PATH"
command -v aarch64-linux-android-gcc
command -v arm-linux-androideabi-gcc
```

The correct prefixes are:

```text
64-bit: aarch64-linux-android-
32-bit: arm-linux-androideabi-
```

### `openssl/bio.h` not found

Install:

```bash
sudo apt install -y libssl-dev
```

Then rerun the build.

### `CONFIG_CC_STACKPROTECTOR_STRONG` warning appears with a missing compiler

Fix the compiler/PATH problem first. Compiler-feature probes can fail simply because the expected cross-compiler command could not be executed.

### Adapter appears in `lsusb` but there is still no tty device

Check:

```bash
adb shell su -c 'dmesg | tail -100'
adb shell su -c 'lsusb'
```

Identify the adapter's USB VID:PID and determine which USB serial driver it requires. The fork intentionally enables the most common Klipper/embedded adapters, not every historical USB serial driver in the kernel.

### Build finishes almost immediately on a second run

That is expected for an incremental build. To prove that the complete tree can build from scratch:

```bash
rm -rf out
time ./scripts/build.sh
```

A clean standalone kernel build can still be relatively short compared with a full Android build.
