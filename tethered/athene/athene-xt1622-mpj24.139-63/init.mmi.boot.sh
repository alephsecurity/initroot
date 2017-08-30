#!/system/bin/sh

# We take this from cpuinfo because hex "letters" are lowercase there
set -A cinfo `cat /proc/cpuinfo | /system/bin/grep Revision`
hw=${cinfo[2]#?}

# Now "cook" the value so it can be matched against devtree names
m2=${hw%?}
minor2=${hw#$m2}
m1=${m2%?}
minor1=${m2#$m1}
if [ "$minor2" == "0" ]; then
	minor2=""
	if [ "$minor1" == "0" ]; then
		minor1=""
	fi
fi
setprop ro.hw.revision p${hw%??}$minor1$minor2
unset hw cinfo m1 m2 minor1 minor2

# reload UTAGS
echo 1 > /proc/config/reload

# Export these for factory validation purposes
iccid=$(cat /proc/config/iccid/ascii 2>/dev/null)
if [ ! -z "$iccid" ]; then
	setprop ro.mot.iccid $iccid
fi
unset iccid
cust_md5=$(cat /proc/config/cust_md5/ascii 2>/dev/null)
if [ ! -z "$cust_md5" ]; then
	setprop ro.mot.cust_md5 $cust_md5
fi
unset cust_md5

# Get FTI data and catch old units with incorrect/missing UTAG_FTI
pds_fti=/persist/factory/fti
set -A fti_pds $(hd $pds_fti 2>/dev/null)
if [ $? -eq 0 ]; then
	set -A fti $(hd $pds_fti 2>/dev/null)
fi

# If UTAG_FTI is readable, compare checksums
# and if they mismatch, assume PDS is valid and overwrite UTAG
utag_fti=/proc/config/fti
set -A fti_utag $(hd ${utag_fti}/ascii 2>/dev/null)
if [ $? -eq 0 ]; then
	# Byte 153 is total cksum, if nothing there, PDS data is invalid/missing
	if [ ! -z "${fti[153]}" ]; then
		# Bytes 75 and 94 have line checksums for year and month/date
		if [ "${fti[75]}" != "${fti_utag[75]}" -o "${fti[94]}" != "${fti_utag[94]}" ]; then
			echo "Copying FTI data from PDS"
			cat $pds_fti > ${utag_fti}/raw
		fi
	else
		# If PDS data is invalid, take UTAG and hope it is correct
		set -A fti $(hd ${utag_fti}/ascii 2>/dev/null)
	fi
fi

# Now we have set fti var either from PDS or UTAG
# Get Last Test Station stamp from FTI
# and convert to user-friendly date, US format
# The offsets are for hd-format, corresponding to real offsets 64/65/66
# If the month/date look reasonable, data is probably OK.
mdate="Unknown"
y=0x${fti[73]}
m=0x${fti[77]}
d=0x${fti[78]}
let year=$y month=$m day=$d
# Invalid data will often have bogus month/date values
if [ $month -le 12 -a $day -le 31 -a $year -ge 12 ]; then
	mdate=$month/$day/20$year
else
	echo "Corrupt FTI data"
fi

setprop ro.manufacturedate $mdate
unset fti y m d year month day utag_fti pds_fti fti_utag mdate

t=$(getprop ro.build.tags)
if [[ "$t" != *release* ]]; then
	for p in $(cat /proc/cmdline); do
		if [ ${p%%:*} = "@" ]; then
			v=${p#@:}; a=${v%=*}; b=${v#*=}
			${a%%:*} ${a##*:} $b
	fi
	done
fi
unset p v a b t

# Cleanup stale/incorrect programmed model value
# Real values will never contain substrings matching "internal" device name
product=$(getprop ro.hw.device)
model=$(cat /proc/config/model/ascii 2>/dev/null)
if [ $? -eq 0 ]; then
	if [ "${model#*_}" == "$product" -o "${model%_*}" == "$product" ]; then
		echo "Clearing stale model value"
		echo "" > /proc/config/model/raw
	fi
fi
unset model product

# For non-user builds only check if Normal min free offset file is there and use
# those values to override the default setting
if [ "`getprop ro.build.type`" != "user" ]
then
	if [ -f /data/minFreeOff.txt ]
	then
		if [ -e /proc/sys/vm/min_free_normal_offset ]
		then
			echo -e `cat /data/minFreeOff.txt` > /proc/sys/vm/min_free_normal_offset
		fi
	fi
fi

if [ -e /dev/vfsspi ]
then
	setprop ro.mot.hw.fingerprint 1
fi

