#!/bin/bash

# This script is used to backup all the system config and monstores at any given time!

# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -xech

backup_path=/root/_Server/Backups/sfmr-pveceph-ER
# Set the flag below to 1 to Import hosts dynamically. Otherwise set 0 and specify manually below.
hosts_auto_populate=1
hosts=( "Avocado" "Bamboo" "Cosmos" )
KEYRING="/etc/pve/priv/ceph.mon.keyring"

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

if [ $hosts_auto_populate -eq 1 ]; then
        hosts=($(hosts_get_names))
        fi

for host in "${hosts[@]}"; do
    # Note should look into ~ ceph auth export ~ to see if can backup some other things.

    mkdir -p $backup_path/$host/etc/ceph/
    mkdir -p $backup_path/$host/etc/pve/ceph
    mkdir -p $backup_path/$host/etc/pve/priv/ceph/
    mkdir -p $backup_path/$host/var/lib/ceph/
    rsync -avz -mkpath root@$host:/etc/ceph* $backup_path/$host/etc/
    rsync -avz -mkpath root@$host:/etc/pve/ceph* $backup_path/$host/etc/pve/
    rsync -avz -mkpath root@$host:/etc/pve/priv/ceph* $backup_path/$host/etc/pve/priv/
    rsync -avz -mkpath root@$host:/var/lib/ceph* $backup_path/$host/var/lib/
    
    done
