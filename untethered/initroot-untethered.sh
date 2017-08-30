#!/bin/sh

# usage: initroot-untethered.sh <name> <local pad file> <target partition>
# use the device specific initroot.sh which runs this file with the correct parameters

echo Welcome to initroot-$1-untethered
cd ../../tethered/$1
../../tethered/$1/initroot-tethered.sh
cd ../../untethered/$1

adb wait-for-device shell id
adb wait-for-device push $2 /data/local/tmp
adb wait-for-device shell "dd of=/dev/block/$3 if=/data/local/tmp/$2"
adb wait-for-device reboot bootloader
fastboot oem config fsg-id "a rdinit= root=/dev/$3"
fastboot reboot
adb wait-for-device shell id
adb wait-for-device shell
