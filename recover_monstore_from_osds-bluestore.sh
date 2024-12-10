#!/bin/bash
# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -xe

# CHANGE These!
# Hosts that provide OSDs - if you don't specify a host here that has OSDs, they will become "Ghost OSDs" in rebuild and data may be lost
hosts=( "Avocado" "Bamboo" "Cosmos" )
# Your rebuild target path. Make sure it's large enough and empty (couple of GB for a big cluster, not the sum of OSD size)
ms=/root/mon-store
# set to 1 if the osds are bluestore otherwise set to 0.
bluestore_bool=1

# FUNCTION DEFINITIONS ~ Feel free to read to see how I implemented these as you see it below in the main runtime.
function osd_get_block_device() { # syntax pass osd #
    osd_n_info=$(ceph-volume lvm list $1)
    if [[ "$osd_n_info" =~ /dev/ceph[0-9a-z-]+/osd-block-[0-9a-z-]+ ]]; then
        osd_block_device=${BASH_REMATCH[0]}  # Outputs "bcd"
        fi
    echo $osd_block_device
}
function osd_get_mount_path() { # syntax pass osd #
    echo /var/lib/ceph/osd/ceph-$1/block
}
function osd_mount_bluestore() { # syntax pass osd #
    ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev $(osd_get_block_device $1) --path /var/lib/ceph/osd/ceph-$1
    ln -snf $(osd_get_block_device $1) /var/lib/ceph/osd/ceph-$1/block
}
function mon_rebuild_from_osd() {
    ceph-objectstore-tool --type bluestore --data-path \$1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
}
# --------------------------------------------------------------------------------------------------------------------------


# if there is a monstore back it up!

#remove the monmap
rm -r $ms || true
mkdir $ms || true

osd_get_block_device 0
osd_get_mount_path 0
osd_mount_bluestore 0