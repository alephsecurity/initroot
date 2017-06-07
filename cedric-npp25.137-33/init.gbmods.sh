#!/system/bin/sh

debug=$(getprop ro.boot.gbdebug 2> /dev/null)
bootmode=$(getprop ro.bootmode 2> /dev/null)

# If androidboot.gbdebug is set on command line, skip inserting
# the pre-installed modules.
if [ "$debug" == "1" ]; then
    return 0
fi

insmod /system/lib/modules/greybus.ko

# Only support PTP and BATTERY in charge-only mode
if [ "$bootmode" == "charger" ]; then
    insmod /system/lib/modules/gb-mods.ko
    insmod /system/lib/modules/gb-battery.ko
    insmod /system/lib/modules/gb-ptp.ko

    return 0
fi

gbmods="/system/lib/modules/gb-*"
for mod in $gbmods
do
    insmod $mod
done

insmod /system/lib/modules/v4l2-hal.ko
start mods_camd
