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

I have felt that my monitor store had corruption is why I could not proceed from here... I found an additional guide. Will be adapting soon to see if this is what is missed currently.
https://docs.redhat.com/en/documentation/red_hat_ceph_storage/8/html/troubleshooting_guide/troubleshooting-ceph-monitors#recovering-the-ceph-monitor-store-when-using-bluestore_diag

Credits:

This is such a helpful manual! (A lot of the topis useful!): https://docs.redhat.com/en/documentation/red_hat_ceph_storage/3/pdf/troubleshooting_guide/Red_Hat_Ceph_Storage-3-Troubleshooting_Guide-en-US.pdf  
Write up I sourced most of this script from: https://forum.proxmox.com/threads/recover-ceph-from-osds-only.113699/  

Note:

Due to limitations in the functionality of bash I was unable to keep this down to a single script while maintaining the dynamic additions I threw in the mix.
In executing the scripts the many variables and functions I created did not function as expected. However with debug I discovered everything works when packaged in two scripts. 
If you can compact this into a single script while keeping the process completely dynamic, please let me know!

> I found out after a few months of attempting to fix it and no test environment that the problem in my recovery procedure was trying to force dual stack IPV4 and IPV6 for the cluster addresses. It was always strange to me how close I seemed to have got with a few times PVE showed that I had a good database after doing the monstore process via this script. Eventually I got tired of everything being down and so, I committed to dealing with 100% loss of all application data. Yet, I still couldn't use the disks after I wiped them to start over as. Ceph was livid that I used ipv4 public addresses and ipv6 private ones via frr ospfv6. Alternatively now both nets are ipv6 with two different subnets and i just have to have ipv6 setup and firewall rules to the servers to talk to ceph rbd from my client machine. Please if you get to this point be sure what you are doing as ceph is very resiliant but there are many ways to stop it in its tracks. ipv4/ipv6 forwarding if you have multiple hops to the destination (ospf) theres a mix of things that could make it a very bad day.. ... Don't worry about my dillema I have recovered quite a bit from my NAS atm I just didn't have VM or db backups etc before so it has been a headache getting back to where I started with my cluster setup started back from scratch with only the knowledge to jumpstart me. Hopefully this update helps someone be it the day someone with data loss woes and not corporate wallet and stumbles accross this script!
