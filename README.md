# Ceph-Disaster_Recovery

We have a refactored and improved script for recovering monitor stores from osds. Maybe we will make more aids soon but for now this is all. 

How to:

To recover your monmap from osds you will need to form a quorum with managers or it will not work...

Due to limitations in the functionality of bash I was unable to package the dynamically configuring aspects of this script with the many variables and functions I created to refactor the code.
In executing the scripts they failed when packaged in one script. If you can fix this while keeping it dynamic please let me know!

Transfer both of these scripts to a folder on one of your PVE nodes: 

recover_monstore_from_osds-bluestore_runtime.sh
recover_monstore_from_osds-bluestore_scanner.sh

Read over the scripts. Inspect them carefully. Should be functionally identical to other ones that are floating around. Just dynamic. If you feel confident:

Simply run recover_monstore_from_osds-bluestore_runtime.sh after ensuring the few variables are set properly such as the bluestore tool. There are paths defined that can be changed in the lower functions in the "_scanner.sh" as well as at the top of each file there are variables like optionally scanning for bluestore and a few others.

**Make sure the variable that defines the location of the "_scanner.sh" is set properly in the "_runtime.sh". Maybe I should make that an argument that you pass into the runtime.. Idk. But for now thats how you use this! Unless you edit it.** 

Credits:
This is such a helpful manual! (A lot of the topis useful!): https://docs.redhat.com/en/documentation/red_hat_ceph_storage/3/pdf/troubleshooting_guide/Red_Hat_Ceph_Storage-3-Troubleshooting_Guide-en-US.pdf  
Write up I sourced most of this script from: https://forum.proxmox.com/threads/recover-ceph-from-osds-only.113699/   