#!/system/bin/sh
scriptname=${0##*/}
dbg_on=1
debug()
{
	[ $dbg_on ] && echo "Debug: $*"
}

notice()
{
	echo "$*"
	echo "$scriptname: $*" > /dev/kmsg
}

error_and_leave()
{
	local err_msg
	local err_code=$1
	case $err_code in
		1)  err_msg="Error: No response";;
		2)  err_msg="Error: in factory mode";;
		3)  err_msg="Error: calibration file not exist";;
		4)  err_msg="Error: the calibration sys file not show up";;
	esac
	notice "$err_msg"
	exit $err_code
}

bootmode=`getprop ro.bootmode`
if [ $bootmode == "mot-factory" ]
then
	error_and_leave 2
fi

laser_offset_path=/sys/kernel/range/offset
laser_offset_string=$(ls $laser_offset_path)
[ -z "$laser_offset_string" ] && error_and_leave 4

cal_offset_path=/persist/camera/focus/offset_cal
cal_offset_string=$(ls $cal_offset_path)
[ -z "$cal_offset_string" ] && error_and_leave 3

offset_cal=$(cat $cal_offset_path)
debug "offset cal value [$offset_cal]"

debug "set cal value to kernel"
echo $offset_cal > $laser_offset_path
notice "laser cal data update success"
