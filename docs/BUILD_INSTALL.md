# OnePlus 5 Custom LineageOS Kernel — Build & Install Guide

> Intended repository path: `docs/BUILD_INSTALL.md`
>
> This guide is for users who want to clone a prepared fork, build the kernel, and install it on an already-prepared OnePlus 5. It does **not** require a full LineageOS/Android source checkout.

## What this kernel adds

The prepared fork keeps the LineageOS OnePlus 5 kernel close to upstream while enabling a focused set of peripheral features useful for a Klipper / embedded-Linux host:

- CDC ACM devices (`/dev/ttyACM*`);
- CH340/CH341, CP210x, FTDI, and PL2303 USB serial (`/dev/ttyUSB*`);
- SocketCAN including common `gs_usb` adapters;
- SLCAN;
- UVC USB webcams (`/dev/video*`);
- UAS storage;
- optional CDC ACM gadget support.

---

## 1. OnePlus 5 prerequisites

Before building or flashing, the phone should already have:

- a **OnePlus 5** (`cheeseburger`);
- an **unlocked bootloader**;
- **LineageOS 22.2** installed and booting normally;
- the underlying OnePlus firmware required by that LineageOS release;
- **Magisk/root** working if you want to preserve the rooted Debian/chroot setup;
- USB debugging enabled;
- working `adb` and `fastboot` access from the PC;
- a known-good LineageOS recovery / installation ZIP available for recovery;
- enough battery charge to safely perform the flash.

If you already use the phone as a Debian chroot/Klipper host, that data normally lives under `/data` and is not erased by changing only the boot/kernel image. Still, keep backups.

### Confirm device and kernel

From the PC:

```bash
adb devices
adb shell getprop ro.product.device
adb shell uname -a
```

The device should identify as the OnePlus 5 / `cheeseburger`.

---

## 2. Test whether a custom kernel is actually needed

If your goal is USB serial, plug the USB-UART or Klipper MCU into the phone through USB OTG and check:

```bash
adb shell su -c 'lsusb'
adb shell su -c 'ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'
```

If the device already appears as `/dev/ttyUSB*` or `/dev/ttyACM*`, you do not need this kernel solely for USB serial.

On the stock LineageOS OnePlus 5 kernel, USB enumeration may work while USB serial drivers are not compiled in.

---

## 3. Build-machine prerequisites

Use one of:

- native Linux;
- Debian/Ubuntu VM;
- WSL2 with Debian or Ubuntu.

For WSL2, keep the project under the Linux filesystem, for example:

```text
~/op5-kernel/
```

Do not build under `/mnt/c/...`.

Recommended free space: roughly **15–20 GB**.

Install host packages on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y \
  bc \
  bison \
  build-essential \
  ca-certificates \
  curl \
  file \
  flex \
  git \
  libssl-dev \
  make \
  python3 \
  unzip \
  wget \
  zip
```

---

## 4. Create the workspace and clone the prepared fork

```bash
mkdir -p ~/op5-kernel/{src,toolchains,package,backups}
cd ~/op5-kernel/src
```

Clone the fork/branch that contains the printer-host configuration and build scripts:

```bash
git clone -b printer-host-support \
  https://github.com/YOUR_GITHUB_USERNAME/android_kernel_oneplus_msm8998.git

cd android_kernel_oneplus_msm8998
```

Record the exact source revision:

```bash
git rev-parse HEAD
git log -1 --oneline
```

---

## 5. Download the pinned standalone toolchains

The repository provides:

```text
toolchains.conf
scripts/setup-toolchains.sh
```

Run:

```bash
./scripts/setup-toolchains.sh
```

The script downloads the pinned Clang, AArch64 GCC 4.9, ARM GCC 4.9, and LineageOS build-tools trees into:

```text
~/op5-kernel/toolchains/
```

Toolchains are intentionally kept outside the Git checkout.

---

## 6. Build the kernel

Run:

```bash
./scripts/build.sh
```

The script:

1. generates the OnePlus 5 config from `lineage_oneplus5_defconfig`;
2. checks that the requested peripheral features resolved to `=y`;
3. builds the kernel using the pinned toolchains;
4. verifies that `Image.gz-dtb` exists;
5. prints its SHA-256 checksum.

Expected output:

```text
out/arch/arm64/boot/Image.gz-dtb
```

Verify manually if desired:

```bash
grep -E '^CONFIG_(USB_ACM|USB_SERIAL|USB_SERIAL_CH341|USB_SERIAL_CP210X|USB_SERIAL_FTDI_SIO|USB_SERIAL_PL2303|CAN_GS_USB|USB_VIDEO_CLASS|USB_UAS)=' out/.config
```

---

## 7. Back up the phone's known-good boot partition

Do this **before flashing anything**.

From the PC:

```bash
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot-known-good.img'
adb pull /sdcard/boot-known-good.img ~/op5-kernel/backups/
```

Verify it:

```bash
ls -lh ~/op5-kernel/backups/boot-known-good.img
sha256sum ~/op5-kernel/backups/boot-known-good.img
```

Keep this image somewhere safe. It is your fast recovery path if the custom kernel does not boot.

Also keep the LineageOS ZIP and recovery image available.

---

## 8. Package the new kernel into the existing boot image

The build produces only the kernel payload:

```text
Image.gz-dtb
```

The safest lean approach is to preserve the phone's currently working boot ramdisk/metadata and replace only the kernel payload.

Use one of the packaging methods provided/documented by the fork, typically:

- an AnyKernel3-based installer ZIP; or
- `magiskboot` to unpack the known-good boot image, replace the kernel, and repack it.

### Preferred property of the packaging flow

It should preserve the existing LineageOS ramdisk and boot metadata rather than attempting to recreate them from scratch.

If the generated boot image is not already Magisk-patched, patch it through Magisk before permanently flashing it so root is preserved.

---

## 9. Patch the generated boot image with Magisk when required

Copy the newly packaged `boot.img` to the phone:

```bash
adb push boot.img /sdcard/Download/
```

On the phone:

```text
Magisk
→ Install
→ Select and Patch a File
→ choose /sdcard/Download/boot.img
```

Pull the resulting image back to the PC:

```bash
adb pull /sdcard/Download/magisk_patched-*.img .
```

Use the exact generated filename in the next commands.

---

## 10. Flash the custom boot image

Reboot to the bootloader:

```bash
adb reboot bootloader
```

Verify fastboot sees the phone:

```bash
fastboot devices
```

Flash the patched custom boot image:

```bash
fastboot flash boot magisk_patched-XXXXX.img
```

Then reboot:

```bash
fastboot reboot
```

Allow the first boot a little extra time.

---

## 11. Verify the kernel after boot

Confirm Android boots normally and Magisk/root still works.

Then inspect the running kernel config:

```bash
adb shell su -c "zcat /proc/config.gz | grep -E 'CONFIG_USB_ACM|CONFIG_USB_SERIAL|CONFIG_USB_SERIAL_CH341|CONFIG_USB_SERIAL_CP210X|CONFIG_USB_SERIAL_FTDI_SIO|CONFIG_USB_SERIAL_PL2303|CONFIG_CAN_GS_USB|CONFIG_USB_VIDEO_CLASS|CONFIG_USB_UAS'"
```

The enabled options should report `=y` rather than `is not set`.

---

## 12. Test USB serial

Plug in the USB-UART adapter or USB-connected Klipper MCU through OTG.

Check enumeration:

```bash
adb shell su -c 'lsusb'
```

Check kernel messages:

```bash
adb shell su -c 'dmesg | tail -100'
```

Check device nodes:

```bash
adb shell su -c 'ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'
```

Typical successful results are:

```text
/dev/ttyUSB0
```

or:

```text
/dev/ttyACM0
```

The same device node should then be visible from a Debian chroot that bind-mounts/shares `/dev`.

---

## 13. Optional peripheral tests

### UVC webcam

After connecting a standard USB webcam:

```bash
adb shell su -c 'ls -l /dev/video* 2>/dev/null'
```

Inside Debian, tools such as `v4l2-ctl`, `ffmpeg`, `ustreamer`, or `camera-streamer` can use `/dev/video*` if permissions/SELinux allow it.

### USB-CAN

For a supported `gs_usb` adapter, inspect:

```bash
adb shell su -c 'ip link'
```

After configuration, a SocketCAN interface such as `can0` should be possible.

### USB storage/UAS

Inspect:

```bash
adb shell su -c 'dmesg | tail -100'
adb shell su -c 'lsblk'
```

---

## 14. Recovery if the phone does not boot

Do not panic. The bootloader is already unlocked and you saved the original boot image.

Enter fastboot mode and restore the known-good image:

```bash
fastboot flash boot ~/op5-kernel/backups/boot-known-good.img
fastboot reboot
```

If necessary, use the saved LineageOS recovery/ZIP as an additional recovery route.

Changing the boot image normally does **not** wipe `/data`, so Android settings and a Debian chroot should remain intact.

---

## 15. Updating to a newer fork revision later

From the kernel checkout:

```bash
git fetch origin
git checkout printer-host-support
git pull --ff-only
```

Re-run:

```bash
./scripts/setup-toolchains.sh
./scripts/build.sh
```

Then repeat the boot-image packaging and flash procedure.

Always keep a known-good boot image before testing a new kernel revision.

---

## Summary

The intended end-user workflow is:

```text
Prepared OnePlus 5
        ↓
clone prepared kernel fork
        ↓
setup pinned toolchains
        ↓
build Image.gz-dtb
        ↓
preserve existing boot ramdisk/metadata
        ↓
package custom boot.img
        ↓
patch with Magisk if needed
        ↓
flash boot
        ↓
verify USB serial / CAN / webcam / UAS support
```

No full LineageOS source checkout is required.
