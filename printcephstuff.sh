#!/bin/bash

# Having trouble with vars nested into the rsync. I think separate it into a separate file and send it over to execute for physical rebuild..... 
# Also can perhaps do multithread if do a watch is it done without waiting to complete idk...

# set -x ~ Print shell command before execute it. This feature help programmers to track their shell script.
# set -e ~ If the return code of one command is not 0 and the caller does not check it, the shell script will exit. This feature make shell script robust.
set -e

# If all your hosts contain osds no need to define them all. Import them dynamically.
hosts_auto_populate=false
# Hosts that provide OSDs - if you don't specify a host here that has OSDs, they will become "Ghost OSDs" in rebuild and data may be lost
hosts=( "Avocado" "Bamboo" "Cosmos" )

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

# Clear the terminal history for easy reading.
clear

hosts=($(hosts_get_names))

echo Hosts: ${hosts[@]}
echo -----------------------
echo Ceph mgr keyring @ /var/lib/ceph/mgr/ceph-Bamboo/keyring \~
echo
cat /var/lib/ceph/mgr/ceph-Bamboo/keyring
echo -----------------------
echo Ceph mon keyring @ /var/lib/ceph/mon/ceph-Bamboo/keyring \~
echo
cat /var/lib/ceph/mon/ceph-Bamboo/keyring
echo -----------------------
echo Ceph "client" admin keyring @ /etc/pve/priv/ceph.client.admin.keyring \~
echo
cat /etc/pve/priv/ceph.client.admin.keyring
echo -----------------------
echo Ceph mon keyring @ /etc/pve/priv/ceph.mon.keyring \~
echo
cat /etc/pve/priv/ceph.mon.keyring
echo -----------------------
echo Ceph bootstrap osd keyring @ ceph.client.bootstrap-osd.keyring \~
echo
cat /etc/pve/priv/ceph.client.bootstrap-osd.keyring
echo -----------------------

# ceph-monstore-tool /var/lib/ceph/mon/ceph-Bamboo/store.db/ rebuild – –keyring /etc/pve/priv/ceph.mon.keyring –mon-ids Avocado Bamboo Cosmos
