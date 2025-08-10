#!/bin/bash
# -----------------------------------------------------------------------------------
# Notes: This may work for other OS than PVE; it is configured for such, yet you are welcome to tweak it to you needs. 
# --------------------- Variables you might change ? --------------------------------
# Set the script to populate the list of hosts dynamically? You can set this to 0 or 1 ~ true/false.
hosts_auto_populate=true
# Hosts that provide OSDs - if you don't specify a host here that has OSDs, they will become "Ghost OSDs" in rebuild and data may be lost
hosts=( "Avocado" "Bamboo" "Cosmos" )
# Your rebuild target path. Make sure it's large enough and *empty* (all contents will be deleted) (couple of GB for a big cluster, not the sum of OSD size)
ms=/root/mon-store
# -----------------------------------------------------------------------------------
# I wouldn't change anything past this line unless you are careful and know what you are doing.
# -----------------------------------------------------------------------------------
# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -x
# -----------------------------------------------------------------------------------
# FUNCTION DEFINITIONS ~ Feel free to read to see how I implemented these as you see it below in the main runtime.
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
# exit # remove this to make this script possible to execute for safety...
hosts=($(hosts_get_names))

for host in "${hosts[@]}"; do
        ssh root@$host "rm -rf /etc/systemd/system/ceph*"
        ssh root@$host "killall -9 ceph-mon ceph-mgr ceph-mds"
        ssh root@$host "rm -rf /var/lib/ceph/mon/  /var/lib/ceph/mgr/  /var/lib/ceph/mds/"
        ssh root@$host "pveceph purge"
        ssh root@$host "apt -y purge ceph-mon ceph-osd ceph-mgr ceph-mds"
        ssh root@$host "rm /etc/init.d/ceph"
        ssh root@$host "for i in $(apt search ceph | grep installed | awk -F/ '{print $1}'); do apt reinstall $i; done"
        ssh root@$host "dpkg-reconfigure ceph-base"
        ssh root@$host "dpkg-reconfigure ceph-mds"
        ssh root@$host "dpkg-reconfigure ceph-common"
        ssh root@$host "dpkg-reconfigure ceph-fuse"
        ssh root@$host "for i in $(apt search ceph | grep installed | awk -F/ '{print $1}'); do apt reinstall $i; done"

        ssh root@$host "rm /etc/ceph/ceph.conf"
        ssh root@$host "rm -r /etc/pve/ceph.conf"
        ssh root@$host "rm -r /etc/ceph"
        ssh root@$host "rm -rf /var/lib/ceph"
        ssh root@$host "rm -rf /etc/pve/priv/ceph"
        ssh root@$host "rm -rf /etc/pve/priv/ceph*"
    done
