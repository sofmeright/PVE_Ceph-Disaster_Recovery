#!/bin/bash
# -----------------------------------------------------------------------------------
# Notes: This may work for other OS than PVE; it is configured for such, yet you are welcome to tweak it to you needs. 
# --------------------- Variables you might change ? --------------------------------
monmap_exe=/root/_Server/__SysAdmin_Scripts/Ceph/Disaster-Recovery/extract_monmap_from_osds-scanner.sh
# Set the script to populate the list of hosts dynamically? You can set this to 0 or 1 ~ true/false.
hosts_auto_populate=true
# Hosts that provide OSDs - if you don't specify a host here that has OSDs, they will become "Ghost OSDs" in rebuild and data may be lost
hosts=( "Avocado" "Bamboo" "Cosmos" )
# Your rebuild target path. Make sure it's large enough and *empty* (all contents will be deleted) (couple of GB for a big cluster, not the sum of OSD size)
ms=/root/mon-store
# You probably need this mon key path if you are using proxmox
KEYRING="/etc/pve/priv/ceph.mon.keyring"
# -----------------------------------------------------------------------------------
# I wouldn't change anything past this line unless you are careful and know what you are doing.
# -----------------------------------------------------------------------------------
# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -xe
# -----------------------------------------------------------------------------------
# FUNCTION DEFINITIONS ~ Feel free to read to see how I implemented these as you see it below in the main runtime.
function mgr_get_key() {
    # Temporarily store a copy of the mgr keyring from the remote node to gain a copy of the key.
    scp root@$1:/var/lib/ceph/mgr/ceph-$1/keyring /root/mgr-ceph-$1-keyring
    local file="/root/mgr-ceph-$1-keyring"
    
    # Use grep to find the line with the key and then extract the key using awk
    local key=$(grep -oP 'key\s*=\s*\K[A-Za-z0-9+/=]+' "$file")
    
    # Remove the temporary keyring file
    rm "$file"
    
    # Return the extracted key
    echo "$key"
}
function hosts_get_names() {
    if [[ $hosts_auto_populate == "false" || $hosts_auto_populate == "0" ]]; then
            echo ${hosts[@]}
        elif [[ $hosts_auto_populate == "true" || $hosts_auto_populate == "1" ]]; then
                # Now we populate hosts dynamically if was indicated to do so by hosts_auto_populate.
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
        else
            # Invalid input: show an error message and exit with error
            echo Please set hosts_auto_populate to either 0 or 1, or true/false. \"$1\" is an invalid entry. > /dev/tty
            return 1
        fi
}
# --------------------- This is the main runtime below ---------------------
hosts=($(hosts_get_names))
# Ensure the folders we use as targets for the monmap rebuild starts empty.
for host in "${hosts[@]}"; do
    ssh root@$host "rm -rf $ms || true"
    ssh root@$host "rm -rf $ms.remote || true"
    done
mkdir $ms || true
# collect the cluster map from stopped OSDs - basically, this daisy-chains the gathering. Make
# sure to start with clean folders, or the rebuild will fail when starting ceph-mon
# (update_from_paxos assertion error) (the rm -rf is no mistake here)
for host in "${hosts[@]}"; do
    # Copy the temp monmap remote folder from the ? last iteration to the remote(?) host.
    rsync -avz --mkpath $ms/. root@$host:$ms.remote
    # Remove the local copy of the tmp monmap keeping things clean.
    rm -rf $ms
    # Attempt to activate all the osds using ceph tools.
    ssh root@$host "ceph-volume lvm activate --all"
    # For safety's sake: Stops all ceph services to prevent conflicts during read.
    ssh root@$host "systemctl stop ceph.target"
    ssh root@$host "systemctl stop ceph-mgr@$host"
    ssh root@$host "systemctl stop ceph-mon@$host"
    # Transfer the osds_scanner.sh to the remote host.
    rsync -avz --mkpath $monmap_exe root@$host:$monmap_exe
    # Execute the osds_scanner.sh on the remote host.
    ssh root@$host "bash $monmap_exe"
    # Pull the tmp monmap from the remote host so it can be added to on the ? next cycle.
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
    # Get the key using the mgr_get_key function and assign it to a variable
    key=$(mgr_get_key $host) 
    # Execute ceph-authtool with the key for the remote host
    ceph-authtool "$KEYRING" --add-key "$key" -n mgr.$host --cap mon 'allow profile mgr' --cap osd 'allow *' --cap mds 'allow *'
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
ceph-monstore-tool $ms rebuild -- --keyring $KEYRING --mon-ids ${hosts[@]}
# make a backup of the existing store.db just in case!  repeat for all monitors.
# CAREFUL here: Running the script multiple times will never overwrite the *original* backup! (Cause that's unsafe imho)
for host in "${hosts[@]}"; do
    # if there is not an original backup db in the folder back it up. (On all hosts)
    if ssh "root"@"$host" "[ ! -e /var/lib/ceph/mon/ceph-$host/store.db.original ]"; then
        ssh root@$host "mv /var/lib/ceph/mon/ceph-$host/store.db /var/lib/ceph/mon/ceph-$host/store.db.original"
        else 
            # create a 2nd backup on every run thereafter just for giggles. (On all hosts)
            ssh root@$host "rm -r /var/lib/ceph/mon/ceph-$host/store.db.bak || true"
            ssh root@$host "mv /var/lib/ceph/mon/ceph-$host/store.db /var/lib/ceph/mon/ceph-$host/store.db.bak"
        fi
        # Copy the monmap that was extracted from the osds to each host.
        rsync -av $ms/store.db/ root@$host:/var/lib/ceph/mon/ceph-$host/store.db/
        ssh root@$host "chown -R ceph:ceph /var/lib/ceph/mon/ceph-$host/store.db"
        # Start the ceph managers & monitors per host. Hopefully we are up now.
        ssh root@$host "systemctl start ceph.target"
        ssh root@$host "systemctl start ceph-mgr@$host"
        ssh root@$host "systemctl start ceph-mon@$host"
    done