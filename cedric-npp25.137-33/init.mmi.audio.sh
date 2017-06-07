#!/system/bin/sh

path=/etc/acdbdata
typeset -l device=$(getprop ro.hw.device)
index=0
for file in $(ls $path/$device/*.acdb); do
    setprop persist.audio.calfile$index $file
    index=$((index+1))
done

