# OnePlus 5 LineageOS kernel

Device: **OnePlus 5 (`cheeseburger`)**, using the LineageOS 22.2 kernel fork.
The documentation review branch is `appliance-docs`, based on `usb-serial-enable`.

Installation, build, recovery, and maintenance guides are maintained in
[`klipper-android-appliance-scripts`](https://github.com/BGW-10/klipper-android-appliance-scripts/tree/mona-appliance/docs):

- [OnePlus 5 setup and operation](https://github.com/BGW-10/klipper-android-appliance-scripts/blob/mona-appliance/docs/devices/oneplus5/README.md)
- [Kernel build, packaging, testing, and recovery](https://github.com/BGW-10/klipper-android-appliance-scripts/blob/mona-appliance/docs/devices/oneplus5/kernel.md)
- [Kernel maintenance and toolchains](https://github.com/BGW-10/klipper-android-appliance-scripts/blob/mona-appliance/docs/devices/oneplus5/kernel-maintenance.md)

Build inputs live here: [device configuration](arch/arm64/configs/lineage_oneplus5_defconfig),
[toolchain setup](scripts/setup-toolchains.sh), [build script](scripts/build.sh),
and [toolchain revisions](toolchains.conf).

**AI usage:** This documentation consolidation was prepared with AI assistance,
including OpenAI Codex. See
[sources and validation](https://github.com/BGW-10/klipper-android-appliance-scripts/blob/mona-appliance/docs/reference/sources.md#ai-usage).
