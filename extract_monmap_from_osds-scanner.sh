#!/bin/bash
# --------------------- Variables you might change ? --------------------------------
# This is a temp folder where we will place the monmap during extraction of OSDs.
ms=/root/mon-store
# Set to 1 if the osds are bluestore otherwise set to 0.
bluestore_flag=1
# This is the osd mount path containing everything that comes before the osd #.
osd_mount_prefix=/var/lib/ceph/osd/ceph-
# This is any part of the osd path that comes after the OSD number (Idk if that's a thing.)
osd_mount_suffix=
# -----------------------------------------------------------------------------------
# I wouldn't change anything past this line unless you are careful.
# -----------------------------------------------------------------------------------
# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit.
set -x
# -----------------------------------------------------------------------------------
# FUNCTION DEFINITIONS ~ Feel free to read to see how I implemented these as you see it below in the main runtime.
function osd_get_block_device() { # Syntax: osd_get_block_device osd_id(#)
    if [[ "$(ceph-volume lvm list $1)" =~ /dev/ceph[0-9a-z-]+/osd-block-[0-9a-z-]+ ]]; then
            echo ${BASH_REMATCH[0]}  # Outputs the osd's block device formatted ~ /dev/ceph*/osd-block-*
        fi
}
function mount_osd() { # Syntax: mount_osd osd_id(#)
    if [[ $bluestore_flag == "true" || $bluestore_flag == "1" ]]; then
            ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev $(osd_get_block_device $1) --path $osd_mount_prefix$1$osd_mount_suffix
            ln -snf $osd_block_dev $osd_mount_prefix$1$osd_mount_suffix/block
        elif [[ $bluestore_flag != "false" || $bluestore_flag != "0" ]]; then
            # Invalid input: show an error message and exit with error
            echo Please set bluestore_flag to either 0 or 1, or true/false. \"$1\" is an invalid entry. > /dev/tty
            return 1
        fi
}
function extract_osd_to_tmp_monmap() { # Syntax: extract_osd_to_tmp_monmap osd_path
    if [[ $bluestore_flag == "true" || $bluestore_flag == "1" ]]; then
            # We do need the || true here to not crash when ceph tries to recover the osd-{node}-Directory present on some hosts
            ceph-objectstore-tool --type bluestore --data-path $1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        elif [[ $bluestore_flag == "false" || $bluestore_flag == "0" ]]; then
            ceph-objectstore-tool --data-path $1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        else
            # Invalid input: show an error message and exit with error
            echo Please set bluestore_flag to either 0 or 1, or true/false. \"$1\" is an invalid entry. > /dev/tty
            return 1
        fi
}
# --------------------- This is the main runtime below ---------------------
for loop_osd_path in $osd_mount_prefix*$osd_mount_suffix; do
    if [[ "$loop_osd_path" =~ $osd_mount_prefix([0-9]+)$osd_mount_suffix ]]; then
            loop_osd_id=${BASH_REMATCH[1]}
        fi
    mount_osd $loop_osd_id
    systemctl stop ceph-osd@$loop_osd_id || true
    extract_osd_to_tmp_monmap $loop_osd_path
    systemctl start ceph-osd@$loop_osd_id || true
    done