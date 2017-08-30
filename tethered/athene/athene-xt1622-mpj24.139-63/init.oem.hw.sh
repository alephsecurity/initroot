#!/system/bin/sh

PATH=/sbin:/system/sbin:/system/bin:/system/xbin
export PATH

while getopts dpfr op;
do
	case $op in
		d)  dbg_on=1;;
		p)  populate_only=1;;
		f)  dead_touch=1;;
		r)  reset_touch=1;;
	esac
done
shift $(($OPTIND-1))

scriptname=${0##*/}
hw_mp=/proc/hw
config_mp=/proc/config
reboot_utag=$hw_mp/.reboot
touch_status_prop=hw.touch.status
hw_cfg_file=hw_config.xml
vhw_file=/system/etc/vhw.xml
bp_file=/system/build.prop
oem_file=/oem/oem.prop
load_error=3
need_to_reload=2
reload_in_progress=1
reload_done=0
ver_utag=".version"
version_fs="unknown"
xml_version="unknown"
device_params=""
xml_file=""
set -A prop_names
set -A prop_overrides
prop_names=(ro.product.device ro.product.name)

set_reboot_counter()
{
	local value=$1
	local reboot_cnt=0
	local reboot_mp=${reboot_utag%.*}
	local tag_name=${reboot_utag##*/}
	if [ $((value)) -gt 0 ]; then
		notice "increase reboot counter"
		[ -d $reboot_utag ] && reboot_cnt=$(cat $reboot_utag/ascii)
		value=$(($reboot_cnt + 1))
	fi
	if [ ! -d $reboot_utag ]; then
		echo ${reboot_utag##*/} > $reboot_mp/all/new
		[ $? != 0 ] && notice "error creating UTAG $tag_name"
	fi
	echo "$value" > $reboot_utag/ascii
	[ $? != 0 ] && notice "error updating UTAG $tag_name"
	notice "UTAG $tag_name is [`cat $reboot_utag/ascii`]"
}

set_reboot_counter_property()
{
	local reboot_cnt=0
	local tag_name=${reboot_utag##*/}
	if [ -d $reboot_utag ]; then
		reboot_cnt=$(cat $reboot_utag/ascii)
		notice "UTAG $tag_name has value [$reboot_cnt]"
	else
		notice "UTAG $tag_name does not exist"
	fi
	setprop $touch_status_prop $reboot_cnt
	notice "property [$touch_status_prop] is set to [`getprop $touch_status_prop`]"
}

debug()
{
	[ $dbg_on ] && echo "Debug: $*"
}

notice()
{
	echo "$*"
	echo "$scriptname: $*" > /dev/kmsg
}

add_device_params()
{
	device_params=$device_params" $@"
	debug "add_device_params='$device_params'"
}

drop_device_parameter()
{
	device_params=${device_params% *}
	debug "drop_device_parameter='$device_params'"
}

set_xml_file()
{
	xml_file=$@
	debug "working with XML file='$xml_file'"
}

exec_parser()
{
	eval motobox expat -u -f $xml_file $device_params "$@" 2>/dev/null
}

reload_utags()
{
	local mp=$1
	local value
	echo "1" > $mp/reload
	value=$(cat $mp/reload)
	while [ "$value" == "$reload_in_progress" ]; do
		notice "waiting for loading to complete"
		sleep 1;
		value=$(cat $mp/reload)
		notice "'$mp' current status [$value]"
	done
}

procfs_wait_for_device()
{
	local __result=$1
	local status
	local mpi
	local IFS=' '
	while [ ! -f $hw_mp/reload ] || [ ! -f $config_mp/reload ]; do
		notice "waiting for devices"
		sleep 1;
        done
	for mpi in $hw_mp; do
		status=$(cat $mpi/reload)
		notice "mount point '$mpi' status [$status]"
		if [ "$status" == "$need_to_reload" ]; then
			notice "force $mpi reloading"
			reload_utags $mpi
		fi
	done
	for mpi in $hw_mp; do
		status=$(cat $mpi/reload)
		notice "$mpi reload is [$status]"
		while [ "$status" != "$reload_done" ]; do
			notice "waiting for loading to complete"
			sleep 1;
			status=$(cat $mpi/reload)
		done
	done
	eval $__result=$status
}

get_attr_data_by_name()
{
	local __result=$1
	local attr=$2
	shift 2
	local IFS=' '
	for arg in ${@}; do
		[ "${arg%=*}" == "$attr" ] || continue
		debug "attr_data='${arg#*=}'"
		eval $__result="${arg#*=}"
		break
	done
}

get_tag_data()
{
	local __name=$1
	local __value=$2
	shift 2
	local dataval
	local IFS=' '
	for arg in ${@}; do
		debug "---> arg='$arg'"
		[ "${arg#?}" == "$arg" ] && continue
		if [ "${arg%=*}" == "name" ]; then
			eval $__name=${arg#*=}
			continue
		fi
		# eval treats ';' as a separator, thus make it '\;'
		dataval=$(echo ${arg#?} | sed 's/;/\\;/g')
		debug "<--- dataval='$dataval'"
		eval $__value=$dataval
	done
}

update_utag()
{
	local utag=$1
	local payload=$2
	local verify
	local rc
	if [ ! -d $hw_mp/$utag ]; then
		notice "creating utag '$utag'"
		echo $utag > $hw_mp/all/new
		rc=$?
		[ "$rc" != "0" ] && notice "'$utag' create dir failed rc=$rc"
	fi
	debug "writing '$payload' to '$hw_mp/$utag/ascii'"
	echo "$payload" > $hw_mp/$utag/ascii
	rc=$?
	[ "$rc" != "0" ] && notice "'$utag' write file failed rc=$rc"
	verify=$(cat $hw_mp/$utag/ascii)
	debug "read '$verify' from '$hw_mp/$utag/ascii'"
	[ "$verify" != "$payload" ] && notice "'$utag' payload validation failed"
}

populate_utags()
{
	local selection="$@"
	local pline
	local ptag
	local pvalue
	for pline in $(exec_parser $selection); do
		get_tag_data ptag pvalue $pline
		debug "tag='$ptag' value='$pvalue'"
		update_utag $ptag $pvalue
	done
}

retrieve_overrides_from_file()
{
	local prop_file=$1
	local ftoken
	local fproperty
	local findex=0
	local IFS=' '
	if [ ! -f $prop_file ]; then
		notice "warning: unable to find '$prop_file'"
		return
	fi
	for fproperty in ${prop_names[@]}; do
		debug "searching prop [$fproperty] in '$prop_file'"
		ftoken=$(cat $prop_file 2>/dev/null | grep $fproperty | sed '/^#/d')
		if [ "${ftoken%=*}" == "$fproperty" ]; then
			prop_overrides[$findex]=${ftoken#*=}
			debug "property='$fproperty' value='${prop_overrides[$findex]}'"
		fi
		((findex++))
	done
}

append_hw_variant()
{
	local variant_id=${1:-}
	local prop_value
	local property
	local pindex=0
	local IFS=' '
	retrieve_overrides_from_file $bp_file
	debug "build props (${prop_overrides[*]})"
	if [ -f $oem_file ]; then
		retrieve_overrides_from_file $oem_file
		debug "oem props (${prop_overrides[*]})"
	fi
	[ -z "$variant_id" ] && notice "falling back to no variant"
	for property in ${prop_names[@]}; do
		prop_value=${prop_overrides[$pindex]}
		debug "updating prop [$property] to override[$pindex]='$prop_value'"
		((pindex++))
		if [ -z "$prop_value" ]; then
			notice "empty value for property '$property'"
			continue;
		fi
		setprop $property "$prop_value$variant_id"
		notice "$property='$prop_value$variant_id'"
	done
}

set_ro_hw_properties()
{
	local utag_path
	local utag_name
	local prop_prefix
	local utag_value
	local verify
	for hwtag in $(find $hw_mp -name '.system'); do
		debug "path $hwtag has '.system' in its name"
		prop_prefix=$(cat $hwtag/ascii)
		verify=${prefix%.}
		# esure property ends with '.'
		if [ "$prop_prefix" == "$verify" ]; then
			prop_prefix="$prop_prefix."
			debug "added '.' at the end of [$prop_prefix]"

                fi
		utag_path=${hwtag%/*}
		utag_name=${utag_path##*/}
		utag_value=$(cat $utag_path/ascii)
		setprop $prop_prefix$utag_name "$utag_value"
		notice "ro.hw.$utag_name='$utag_value'"
	done
}

match()
{
	local mapping=$(echo $1 | sed 's/%20/ /g')
	local mline
	local mtag
	local fs_value
	local mvalue
	local matched
	debug "match mapping='$mapping'"
	# put '\"' around $mapping to ensure XML
	# parser takes it as a single argument
	for mline in $(exec_parser \"$mapping\"); do
		get_tag_data mtag mvalue $mline
		[ "$matched" == "false" ] && continue
		[ -f $hw_mp/$mtag/ascii ] && fs_value=$(cat $hw_mp/$mtag/ascii)
		if [ "$fs_value" == "$mvalue" ]; then
			matched="true";
		else
			matched="false";
		fi
		debug "cmp utag='$mtag' values '$mvalue' & '$fs_value' is \"$matched\""
	done
	[ "$matched" == "true" ] && return 0
	return 1
}

find_match()
{
	local __retval=$1
	local tag_name
	local fline
	for fline in $(exec_parser); do
		get_attr_data_by_name tag_name "name" $fline
		debug "tag_name='$tag_name'"
		match $tag_name
		[ "$?" != "0" ] && continue
		eval $__retval=$tag_name
		break
	done
}

process_mappings()
{
	local set_property
	local sebsection
	local pline
	local matched_val
	local whitespace_val
	for pline in $(exec_parser); do
		subsection=${pline%% *}
		get_attr_data_by_name set_property "export" $pline
		debug "set_property='$set_property'"
		# add 'subsection' to permanent parameters
		add_device_params $subsection
		matched_val=""
		find_match matched_val
		if [ "$matched_val" ]; then
			whitespace_val=$(echo $matched_val | sed 's/%20/ /g')
			[ "$matched_val" != "$whitespace_val" ] && debug "value has whitespaces='$whitespace_val'"
			setprop $set_property "$whitespace_val"
			notice "exporting '$whitespace_val' into property $set_property"
		fi
		# remove the last added parameter
		drop_device_parameter
	done
}

# Main starts here
IFS=$'\n'

if [ ! -z "$reset_touch" ]; then
	notice "reset reboot counter"
	set_reboot_counter 0
	return 0
fi

if [ ! -z "$dead_touch" ]; then
	notice "property [$touch_status_prop] set to [dead]"
	set_reboot_counter 1
	return 0
fi

notice "checking integrity"
# check necessary components exist and just proceed
# with RO properties setup otherwise
if [ ! -f /system/bin/expat ] || [ ! -f $vhw_file ]; then
	notice "warning: missing expat or xml"
	set_ro_hw_properties
	return 0
fi

if [ ! -z "$populate_only" ]; then
	# special handling for factory UTAGs provisioning
	for path in /data/local/tmp /pds/factory; do
		[ -f $path/$hw_cfg_file ] && break
	done
	notice "populating hw config from '$path/$hw_cfg_file'"
	set_xml_file $path/$hw_cfg_file
	populate_utags hardware
	return 0
fi

notice "initializing procfs"
procfs_wait_for_device readiness
if [ "$readiness" != "0" ]; then
	notice "applying empty hw variant only"
	return 0
fi

# populate touch status property with reboot counter
set_reboot_counter_property

# XML parsing starts here
set_xml_file $vhw_file

get_attr_data_by_name boot_device_prop "match" $(exec_parser)
debug "attr='get' value='$boot_device_prop'"
if [ -z $boot_device_prop ]; then
	notice "fatal: undefined boot device property"
	return 1
fi

# ensure lower case
typeset -l boot_device=$(getprop $boot_device_prop)
# drop suffixes
boot_device=${boot_device%[_-]*}
notice "matching to boot device '$boot_device'"

# add 'validation' to permanent parameters
add_device_params validation

for line in $(exec_parser); do
	get_attr_data_by_name product "name" $line
	debug "attr='name' value='$product'"
	if [ "$product" == "$boot_device" ]; then
		get_attr_data_by_name xml_version "version" $line
		[ "$xml_version" != "unknown" ] && notice "device '$boot_device' xml version='$xml_version'"
		break
	fi
done

[ "$xml_version" == "unknown" ] && notice "no match found for device '$boot_device'"
# delete obsolete 'version' utag if exists
[ -d $hw_mp/${ver_utag#?} ] && $(echo ${ver_utag#?} > $hw_mp/all/delete)
# read procfs version
[ -d $hw_mp/$ver_utag ] && version_fs=$(cat $hw_mp/$ver_utag/ascii)
notice "procfs version='$version_fs'"
# add 'device' and '$boot_device' to permanent parameters
add_device_params device $boot_device
[ "$xml_version" == "$version_fs" ] && notice "hw descriptor is up to date"
for section in $(exec_parser); do
	debug "section='$section'"
	case $section in
	mappings)
		# add 'mappings' to permanent parameters
		add_device_params $section
		notice "skip 'mappings' handling"
		;;
	*)
		[ "$xml_version" == "$version_fs" ] && continue
		# create version utag if it's missing
		[ ! -d $hw_mp/$ver_utag ] && $(echo "$ver_utag" > $hw_mp/all/new)
		# update procfs version
		[ -d $hw_mp/$ver_utag ] && $(echo "$xml_version" > $hw_mp/$ver_utag/ascii)
		populate_utags $section;;
	esac
done

set_ro_hw_properties

return 0

