#!/system/bin/sh

block_by_name=/dev/block/bootdevice/by-name
utags=${block_by_name}/utags
utags_backup=${block_by_name}/utagsBackup

# Set correct permissions for UTAGS
/system/bin/chown -L mot_tcmd:system $utags
/system/bin/chown -L mot_tcmd:system $utags_backup
/system/bin/chmod -L 0660 $utags
/system/bin/chmod -L 0660 $utags_backup

# HOB/DHOB
hob=${block_by_name}/hob
dhob=${block_by_name}/dhob
/system/bin/chown -L radio:radio $hob
/system/bin/chown -L radio:radio $dhob
/system/bin/chmod -L 0660 $hob
/system/bin/chmod -L 0660 $dhob

# CLOGO
clogo=${block_by_name}/clogo
/system/bin/chown -L root:mot_tcmd $clogo
/system/bin/chmod -L 0660 $clogo

#CID
cid=${block_by_name}/cid
/system/bin/chown -L root:mot_tcmd $cid
/system/bin/chmod -L 0660 $cid

#BL logs
logs=${block_by_name}/logs
/system/bin/chown -L root:log $logs
/system/bin/chmod -L 0640 $logs
