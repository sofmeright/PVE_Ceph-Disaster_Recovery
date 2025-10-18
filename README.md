# Proxmox / PVE Ceph Disaster Recovery
Recovering the Monitor Store from OSDs after Complete Monitor Loss

## Overview

There are two Guides contained in this ReadMe currently. 
1. Instructions on recovering from loss of monitore stores (mommap[s])
2. Guidance on recovering from backfillfull, OSDs beyond capacity that I/O or them remaining online is possible.

---

## Recovering from loss of monmaps:

Contained in this repo alongside this ReadMe is a scripted process you can use to recover Ceph monitor stores (monstore) from OSDs when your cluster has lost all monitors. This procedure helps restore your monitor quorum and cluster health without full data loss.
> These scripts are adaptations of existing recovery methods found in Proxmox forums, IBM, and Red Hat Ceph documentation.
- This is not a magic wand or a simple fix. 
- Recovering a Ceph cluster after total monitor loss is challenging and requires careful planning. 
- This script and accompanying guides aims to guide you through a safer and more dynamic recovery process. 
- You should *still* review things thoroughly and proceed only if you are confident in the steps.
- Disaster recovery is a delicate process — one where mistakes can be costly. 

## Important Warnings
- DO NOT run any purge scripts unless you absolutely want to destroy all data and start over.
- Review all scripts carefully before running, especially if you have any custom setups.
- This recovery is sensitive — mistakes can cause irreversible damage.
- You must have a quorum with managers (mgrs) for the recovery to work.
- Ceph’s networking setup (IPv4/IPv6, dual-stack, routing) can cause OSDs to fail peering if misconfigured.

## Before You Begin
Recovering a Ceph monitor store from OSDs is a delicate process — **get these steps wrong, and you risk permanent data loss.** This section outlines what must be in place, when recovery is doomed from the start, and the checks you should run before executing the scripts.

# If you have a working monitor map on more than one of your nodes 
If you have healthy surviving monmaps you can clone them to nodes that are missing their monmap.
- Only do this if you have no reason to believe the surviving monitors would be corrupted or not containing the latest understanding of your storage
- Consider for split-brain, you CAN cause this if you are not deliberate with your restoration efforts, one of the features of redundancy is that we can validate integrity between duplicates by ensuring they all are the same...
- If you restore one monmap to all of your nodes you will want to be careful that it truly contains good data.
> I do plan to update this guide with steps on this but I know they are available many other places and my priority is to commit the rest of the steps I am adding in this edit as I have not seen them elsewhere during my disaster incident last night that I'm wrapping up documentation thereof. Cheers. DuckDuckGo/SearXNG is your friend if you are reading this prior to my update.

## Prerequisites for Recovery
You’ll need the following intact and accessible on at least one node in your cluster:

### 🔑 Critical Keyrings
- /var/lib/ceph/mgr/<cluster>-<host>/keyring
- /var/lib/ceph/mon/<cluster>-<host>/keyring
- /etc/pve/priv/ceph.client.admin.keyring
- /etc/pve/priv/ceph.mon.keyring
- /etc/pve/priv/ceph.client.bootstrap-osd.keyring

### 📄 Configuration Files
- /etc/ceph/ceph.conf (cluster config)
- /etc/pve/ceph.conf (Proxmox cluster-synced config)
- /var/lib/ceph (daemon state and store data)

### 💾 OSD Requirements
- At least one full replica of the data must exist — this may be on a single OSD or spread across multiple OSDs.
- All OSDs holding the surviving replica(s) must have intact metadata and object stores.
- The OSD data (BlueStore or FileStore) must be intact and accessible for scanning.

### Recovery Will Fail If…
- All OSDs are missing or corrupted — no intact PG replicas on any OSDs = no recovery.
- Keyrings are gone — without them, daemons and clients can’t authenticate.
- Configuration files are missing — cluster topology and FSID will be unknown.
- Networking is broken — incorrect subnets, firewall rules, or unsupported IPv4/IPv6 dual-stack will block peering.
- Cluster FSID mismatch — recovered monitors won’t talk to your OSDs.
- Severe clock skew — quorum will never form if node clocks are too far apart.

### Pre-flight Checklist

Answer YES to each before proceeding:

✅ At least one intact OSD passes object store inspection.

✅ All critical keyrings listed above are present.

✅ /etc/ceph/ceph.conf and /etc/pve/ceph.conf exist.

✅ Nodes can communicate over Ceph’s public and cluster networks.

✅ Firewalls allow Ceph ports (TCP 3300, 6789 for mons; 6800–7300 for OSDs).

✅ Cluster FSID is known and matches across surviving components.

✅ NTP or chrony is running; clocks are in sync.

✅ A safe backup directory is ready for configs and keyrings.

💡 Pro tip: The rsync backup steps in the script will create a full copy of critical configs and keyrings. Run this first and confirm backups before touching live data.

> Note: Failing one or more of the above checks does not guarantee your data is unrecoverable. It simply means the recovery process is out of scope for this repository. At that point, recovery would require a Ceph data recovery specialist who can extract data directly from Placement Groups (PGs) and piece it back together — a process that is highly technical, extremely time-consuming, and often very costly. Unless the lost data is exceptionally valuable *and* you or your organization have deep pockets, this route is usually impractical.

## Setup and Usage
### Scripts
You will need two scripts:
- `recover_monstore_from_osds-bluestore_runtime.sh`
- `recover_monstore_from_osds-bluestore_scanner.sh`

### Installation
1. Transfer both scripts to a folder on one of your Proxmox VE nodes.
2. Inspect both scripts carefully; they should be functionally similar to common scripts floating around.
3. Make both scripts executable:
```bash
chmod +x recover_monstore_from_osds-bluestore_runtime.sh
chmod +x recover_monstore_from_osds-bluestore_scanner.sh
```
### Configuration
- Ensure the _runtime.sh script correctly references the location of the _scanner.sh script.
- By default, hostnames with OSDs are auto-detected.
  - If you want to specify hosts manually, set hosts_auto_populate=0 in the runtime script and list your hosts below.
- You can toggle variables like whether you’re using Bluestore or Filestore.
- Paths and other environment-specific settings are defined near the top of each script — adjust as needed, especially if not using PVE.
### Running
Once configured:
```bash
bash recover_monstore_from_osds-bluestore_runtime.sh
```
## Additional Notes & Troubleshooting
- I found an additional helpful Red Hat troubleshooting guide that may be useful:
https://docs.redhat.com/en/documentation/red_hat_ceph_storage/8/html/troubleshooting_guide/troubleshooting-ceph-monitors#recovering-the-ceph-monitor-store-when-using-bluestore_diag
- My own recovery attempts failed initially due to dual-stack IPv4/IPv6 configuration issues on public and private subnets. Ceph does not fully support mixed IPv4/IPv6 addressing for cluster communication, which blocked OSD peering.
- After switching to consistent IPv6 subnets and configuring firewall rules, OSDs successfully peered.
- Be cautious of networking and firewall setups — any mismatch or blocked routes can cause Ceph to fail. (Enable ipv4/ipv6 forwarding if using frr/ospf)
- This process is meant for advanced users who understand Ceph internals and networking.

## Why Two Scripts?
- Bash limitations prevented packaging all logic into a single script while keeping the process fully dynamic.
- Splitting into _runtime.sh and _scanner.sh allows for modular functions and dynamic variable handling.
- If you can consolidate into one script without losing functionality, please share your approach!

## Credits & References
- Primary source and inspiration: https://forum.proxmox.com/threads/recover-ceph-from-osds-only.113699/
- Helpful manual: https://docs.redhat.com/en/documentation/red_hat_ceph_storage/3/pdf/troubleshooting_guide/Red_Hat_Ceph_Storage-3-Troubleshooting_Guide-en-US.pdf

---

# Recovering from backfillfull 😵

## If your disks aren't truly at 100% fill:
> By default Ceph sets fill limits to prevent OSD fill from exceeding 100%
You can raise the tolerated fill level to start the osd so you can perform operations to reduce fill:
```bash
ceph osd set-full-ratio 0.98
ceph osd set-backfillfull-ratio 0.97
ceph osd set-nearfull-ratio 0.96
```
### You should probably take some precautionary measures to prevent more chaos when you start the OSDs once more:
| Command                     | Description
| --------------------------- | ---------------------------------------------- |
| ceph osd set noout          | Prevent automatic rebalancing                  |
| ceph osd set noin           | Prevent OSD from rejoining and receiving data  |
| ceph osd set nobackfill     | Stop backfill operations                       |
| ceph osd set norebalance    | Stop rebalancing                               |
| ceph osd set norecover      | Stop recovery operations                       |
| ceph osd set noscrub        | Stop scrubbing                                 |
| ceph osd set nodeep-scrub   | Stop deep scrubbing                            |
| ceph osd pause              | NUCLEAR OPTION: Pauses ALL I/O                 |

 # REDUCE POOL SIZES (reduces space needed immediately)
 > You can use something like this example to set a reduced pool size (this can also be done from PVE's GUI).
```bash
  for pool in $(ceph osd pool ls); do
      ceph osd pool set $pool size 2
      ceph osd pool set $pool min_size 1
  done
```

# CHECK WHAT'S FILLING THE DISKS
ceph df detail
ceph osd df tree

# STOP SPECIFIC BUSY POOLS (if identified)
ceph osd pool set <pool-name> target_max_bytes 1  # Effectively stops writes to pool

## If your disk is REALLY 100% FULL:

### Temporarily relocate the BlueStore Database to a disk with sufficient free space
```bash
# Prepare a file to be used as the temp db:
sudo mkdir -p /var/lib/ceph/bluestore-rescue
sudo fallocate -l 10G /var/lib/ceph/bluestore-rescue/db-osd0.img

# Perform the relocation:
sudo ceph-bluestore-tool bluefs-bdev-new-db --path /var/lib/ceph/osd/ceph-0 \
    --dev-target /var/lib/ceph/bluestore-rescue/db-osd0.img

# Create symlink/fix permissions:
# sudo ln -s /var/lib/ceph/bluestore-rescue/db-osd0.img /var/lib/ceph/osd/ceph-0/block.db # May not be needed.
sudo chown ceph:ceph /var/lib/ceph/bluestore-rescue/db-osd0.img
```

### List PGs on the offline OSD 1
```bash
sudo ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-1 --op list-pgs
```

### Make a backup of a PG, probs best one you are more willing to "risk" losing
```bash
sudo ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-0 \
	--pgid 94.c --op export --file /var/lib/ceph/bluestore-rescue/pg-94.c-backup \
	--skip-journal-replay --skip-mount-omap
```

### Delete the PG to make free space for normal disk operations again
```bash
sudo ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-0 --op remove --pgid 94.c --force
```

### Start the OSD and perform operations to free space
```
# I find these commands finicky, hopefully either of these two works for you...
sudo -u ceph /usr/bin/ceph-osd -f --cluster ceph --id 0 --setgroup ceph --setuser ceph
sudo /usr/bin/ceph-osd -f --cluster ceph --id 0
# Let cluster rebalance, move data, etc.
```

### Recover the PG(s) you exported:
```bash
sudo systemctl stop ceph-osd@0
sudo ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-0 --op import --pgid 94.c --file /var/lib/ceph/bluestore-rescue/pg-94.c-backup
```

# Move the Bluestore DB back to the OSD 
> You can adapt this if  you wish to specify a different disk/target to restore the reworked db, my OSD is a NVME so it makes sense to be located on the same disk)

### Migrate DB back to main device
```bash
sudo ceph-bluestore-tool bluefs-bdev-migrate \
    --path /var/lib/ceph/osd/ceph-0 \
    --devs-source /var/lib/ceph/osd/ceph-0/block.db \
    --dev-target /var/lib/ceph/osd/ceph-0/block
```

### Remove the temporary DB file and symlink
```bash
sudo rm /var/lib/ceph/bluestore-rescue/db-osd0.img
sudo rm /var/lib/ceph/bluestore-rescue/pg-94.c-backup
sudo rmdir /var/lib/ceph/bluestore-rescue/
```

### Start OSD again
```bash
sudo systemctl reset-failed ceph-osd@0
sudo systemctl start ceph-osd@0
```

### Remember to default/deliberately set any that you manipulated during recovery:
| Command                     | Description
| --------------------------- | ---------------------------------------------- |
| ceph osd unset pause        | If you used it
| ceph osd unset norecover    | Allow recovery first
| ceph osd unset nobackfill   | Allow backfill
| ceph osd unset norebalance  | Allow rebalancing
| ceph osd unset noscrub      | Allow scrubbing
| ceph osd unset nodeep-scrub |
| ceph osd unset noin         |
| ceph osd unset noout        |

### Reset the full ratios back to normal # THIS IS CRUCIAL OR THAT IS NEEDED ^^^
ceph osd set-full-ratio 0.95
ceph osd set-backfillfull-ratio 0.90
ceph osd set-nearfull-ratio 0.85

### Also you can set more conservative full ratios to stop writes earlier
ceph osd set-nearfull-ratio 0.75    # Warning at 75%
ceph osd set-backfillfull-ratio 0.80 # Stop backfill at 80%
ceph osd set-full-ratio 0.85         # Stop all writes at 85%

---

## Final Thoughts
Ceph is a very resiliant filesystem! And even when ish hits the fan, we have a lot of options to get back up and running.
Good luck, I hope this helps if you are also facing disaster recovery situations with Ceph on Proxmox as I have! I have done my best.

## Disclaimer
> The scripts and guidance provided here ("Software") are offered as-is, without any warranties, express or implied. Use at your own risk.
The author makes no guarantees regarding the functionality, reliability, compatibility, or sanity of the Software. It is not responsible for any data loss, system instability, spontaneous server combustions, or black holes that may or may not open in your data center.
Should running these scripts cause your cat to develop a sudden obsession with the monitor LEDs, your coffee machine to stop working, or your neighbor to question your life choices — well, that’s purely coincidental and definitely not the author’s fault.
If, during the recovery process, you find yourself talking to your servers, singing lullabies to OSDs, or considering a career as a circus performer, remember: you agreed to this adventure willingly.
Finally, the author accepts no liability for any missed gaming sessions, forgotten birthdays, or weird dreams involving Ceph daemons dancing in a disco — those are all on you.
Huge thanks and eternal respect go to the Ceph community, Proxmox developers, and all open source heroes who made any of this possible.
Now go forth, recover bravely, and may your monitors never lose quorum again.
