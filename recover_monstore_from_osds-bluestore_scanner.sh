#!/bin/bash

set -x

ms=/root/mon-store
# set to 1 if the osds are bluestore otherwise set to 0.
bluestore_flag=1
# FUNCTION DEFINITIONS ~ Feel free to read to see how I implemented these as you see it below in the main runtime.
function osd_get_block_device() { # syntax pass osd #
    osd_n_info=$(ceph-volume lvm list $1)
    if [[ "$osd_n_info" =~ /dev/ceph[0-9a-z-]+/osd-block-[0-9a-z-]+ ]]; then
        osd_block_device=${BASH_REMATCH[0]}  # Outputs "bcd"
        fi
    echo $osd_block_device
}
function osd_mount_bluestore() { # syntax pass osd #
    if [ $bluestore_flag -eq 1 ]; then
        ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev $(osd_get_block_device $1) --path $(osd_get_mount_path $1)
        ln -snf $(osd_get_block_device $1) $(osd_get_mount_path $1)/block
        fi
}
function mon_rebuild_from_osd() {
    if [ $bluestore_flag -eq 1 ]; then
        ceph-objectstore-tool --type bluestore --data-path $1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        else ceph-objectstore-tool --data-path $1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        fi
}
function osd_get_mount_path() { # syntax pass osd #
    echo /var/lib/ceph/osd/ceph-$1
}

for osd in /var/lib/ceph/osd/ceph-*; do
    # We do need the || true here to not crash when ceph tries to recover the osd-{node}-Directory present on some hosts
    osd_mount_bluestore $osd
    mon_rebuild_from_osd $osd
    done