#!/bin/bash
# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -xe

# Notes: This may work for other OS than PVE, you may want to tweak the mgr get key function if the mgr key paths will be different in that case. There may be other paths called dynamically in the function calls. 
# This is meant to be a for dummies rescue script for PVE so it's limited what I am adding to the script here. Other than that, everything else is configurable here afaik.

# CHANGE These!
# If all your hosts contain osds no need to define them all. Import them dynamically.
hosts_auto_populate=1
# Hosts that provide OSDs - if you don't specify a host here that has OSDs, they will become "Ghost OSDs" in rebuild and data may be lost
hosts=( "Avocado" "Bamboo" "Cosmos" )
# Your rebuild target path. Make sure it's large enough and empty (couple of GB for a big cluster, not the sum of OSD size)
ms=/root/mon-store
# set to 1 if the osds are bluestore otherwise set to 0.
bluestore_flag=1
# You probably need this mon key path if you are using proxmox
KEYRING="/etc/pve/priv/ceph.mon.keyring"

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
    if [ $bluestore_flag -ne 1 ]; then
        ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev $(osd_get_block_device $1) --path /var/lib/ceph/osd/ceph-$1
        ln -snf $(osd_get_block_device $1) /var/lib/ceph/osd/ceph-$1/block
        fi
}
function mgr_get_key() {
    # Temporarily store a copy of the mgr keyring from the remote node to gain a copy of the key.
    scp root@$1:/var/lib/ceph/mgr/ceph-$1/keyring /root/mgr-ceph-$1-keyring
    local file="/root/mgr-ceph-$1-keyring"
    # Extract the key using awk
    local key=$(awk -F '=' '/key *=/ {
        # Trim leading/trailing whitespace from the key value
        gsub(/^[ \t]+|[ \t]+$/, "", $2);
        if (length($2) > 0) {
            print $2;
            exit;
        }
    }' "$file")
    # Remove the file
    rm "$file"
    # Return the extracted key
    echo "$key"
}
function mon_rebuild_from_osd() {
    if [ $bluestore_flag -ne 1 ]; then
        ceph-objectstore-tool --type bluestore --data-path \$1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        else ceph-objectstore-tool --data-path \$1 --no-mon-config --op update-mon-db --mon-store-path $ms.remote || true
        fi
}
function hosts_get_names() {
    awk '
    BEGIN {
        line = "";  # Initialize an empty string to store names
    }

    # Flag to track when inside a node block
    /node {/ {
        in_node = 1;  # Set the flag when "node {" is found
    }

    # Look for "name:" within a node block
    in_node && /name:/ {
        # Split the line on colon to get the name
        split($0, parts, ":");
        # Trim any leading/trailing whitespace
        gsub(/^[ \t]+|[ \t]+$/, "", parts[2]);
        # Append the name to the line string, separated by a space
        if (line == "") {
            line = parts[2];
        } else {
            line = line " " parts[2];
        }
    }

    # End of a node block
    /}/ {
        if (in_node) {
            in_node = 0;  # Reset the flag
        }
    }

    # Print the result at the end
    END {
        print line;
    }
' "/etc/pve/corosync.conf"
}
# --------------------------------------------------------------------------------------------------------------------------

if [ $hosts_auto_populate -e 1 ]; then
        hosts=($(hosts_get_names))
        fi

# Ensure the folder we use as a target for the monmap rebuild starts empty.
rm -r $ms || true
mkdir $ms || true

# collect the cluster map from stopped OSDs - basically, this daisy-chains the gathering. Make
# sure to start with clean folders, or the rebuild will fail when starting ceph-mon
# (update_from_paxos assertion error) (the rm -rf is no mistake here)
for host in "${hosts[@]}"; do
    echo $hosts
    exit
    rsync -avz $ms/. root@$host:$ms.remote
    rm -rf $ms
    ssh root@$host <<EOF
        set -x
        for osd in /var/lib/ceph/osd/ceph-*; do
            # We do need the || true here to not crash when ceph tries to recover the osd-{node}-Directory present on some hosts
            osd_mount_bluestore $osd
            mon_rebuild_from_osd $osd
            done
EOF
    rsync -avz --remove-source-files root@$host:$ms.remote/. $ms
    done

# rebuild the monitor store from the collected map, if the cluster does not
# use cephx authentication, we can skip the following steps to update the
# keyring with the caps, and there is no need to pass the "--keyring" option.
# i.e. just use "ceph-monstore-tool $ms rebuild" instead
ceph-authtool "$KEYRING" -n mon. \
  --cap mon 'allow *'
ceph-authtool "$KEYRING" -n client.admin \
  --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *'
# add one or more ceph-mgr's key to the keyring. in this case, an encoded key
# for mgr.x is added, you can find the encoded key in
# /etc/ceph/${cluster}.${mgr_name}.keyring on the machine where ceph-mgr is
# deployed

for host in "${hosts[@]}"; do
    ceph-authtool "$KEYRING" --add-key '$(mgr_get_key $host)' -n mgr.$host \
        --cap mon 'allow profile mgr' --cap osd 'allow *' --cap mds 'allow *'
    done

# If your monitors' ids are not sorted by ip address, please specify them in order.
# For example. if mon 'a' is 10.0.0.3, mon 'b' is 10.0.0.2, and mon 'c' is  10.0.0.4,
# please passing "--mon-ids b a c".
# In addition, if your monitors' ids are not single characters like 'a', 'b', 'c', please
# specify them in the command line by passing them as arguments of the "--mon-ids"
# option. if you are not sure, please check your ceph.conf to see if there is any
# sections named like '[mon.foo]'. don't pass the "--mon-ids" option, if you are
# using DNS SRV for looking up monitors.
# This will fail if the provided monitors are not in the ceph.conf or if there is a mismatch in length. SET YOUR OWN monitor IDs here
ceph-monstore-tool $ms rebuild -- --keyring "$KEYRING" --mon-ids $hosts_get_names

# make a backup of the existing store.db just in case!  repeat for all monitors.
# CAREFUL here: Running the script multiple times will never overwrite the *original* backup! (Cause that's unsafe imho)

for host in "${hosts[@]}"; do
    # if there is not an original backup db in the folder back it up.
    if ssh "root"@"$host" "[ ! -e /var/lib/ceph/mon/ceph-$host/store.db.original ]"; then
        ssh root@$host "mv /var/lib/ceph/mon/ceph-$host/store.db /var/lib/ceph/mon/ceph-$host/store.db.original"
        else 
            ssh root@$host "rm -r /var/lib/ceph/mon/ceph-$host/store.db.bak
            ssh root@$host "mv /var/lib/ceph/mon/ceph-$host/store.db /var/lib/ceph/mon/ceph-$host/store.db.bak"
        fi
        # move rebuild store.db into place.  repeat for all monitors.
        rsync -av $ms/store.db root@$host:/var/lib/ceph/mon/ceph-$host/store.db
        ssh root@$host "chown -R ceph:ceph /var/lib/ceph/mon/ceph-$host/store.db"
    done
