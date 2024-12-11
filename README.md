# Proxmox / PVE ~ Ceph Disaster Recovery - Recovering the monstore from OSDs after complete monitor loss.

We have refactored and improved the usual script for recovering monitor stores from osds. Maybe we will make more aids soon but for now this is all. 

How to:

To recover your monmap from osds you will need to form a quorum with managers or it will not work...


"Installing":
1. Transfer both of these scripts to a folder on one of your PVE nodes: 

> [recover_monstore_from_osds-bluestore_runtime.sh](https://github.com/sofmeright/PVE_Ceph-Disaster_Recovery/blob/main/recover_monstore_from_osds-bluestore_runtime.sh)

> [recover_monstore_from_osds-bluestore_scanner.sh](https://github.com/sofmeright/PVE_Ceph-Disaster_Recovery/blob/main/recover_monstore_from_osds-bluestore_scanner.sh)

Read over the scripts. 
Inspect them carefully. 
Should be functionally identical to other ones that are floating around. 

I simply set out to make this process quite a bit more dynamic and with the extra handholding, 
... cause disaster recovery is a process where we really don't want to make any mistakes. 

If you feel confident:

1. Simply run "bash recover_monstore_from_osds-bluestore_runtime.sh" after ensuring at least the variable that defines the location of the "_scanner.sh".

> By default host names are returned automatically, if you only have certain hosts with OSDs then you will need to set the flag "hosts_auto_populate" to 0 and update your list of hosts underneath accordingly.

> Please also observe that there are a few other variables for you to toggle, such as you can indicate if you are using bluestore or not. 

> There are paths defined that can be changed in the lower functions in the "_scanner.sh" say if you are not using PVE you may need to make some adjustments, most of the things one might change are again... declared at the top of each file.

One last time: **Make sure the variable that defines the location of the "_scanner.sh" is set properly in the "_runtime.sh". Maybe I should make that an argument that you pass into the runtime.. Idk. But for now thats how you use this! Unless you edit it. 
I expect as a Ceph user you would know you need to chmod +x both files if they dont execute.** 

Credits:

This is such a helpful manual! (A lot of the topis useful!): https://docs.redhat.com/en/documentation/red_hat_ceph_storage/3/pdf/troubleshooting_guide/Red_Hat_Ceph_Storage-3-Troubleshooting_Guide-en-US.pdf  
Write up I sourced most of this script from: https://forum.proxmox.com/threads/recover-ceph-from-osds-only.113699/   

Note:
Due to limitations in the functionality of bash I was unable to keep this down to a single script while maintaining the dynamic additions I threw in the mix.
In executing the scripts the many variables and functions I created did not function as expected. However with debug I discovered everything works when packaged in two scripts. 
If you can compact this into a single script while keeping the process completely dynamic, please let me know!
