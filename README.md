# Proxmox / PVE Ceph Disaster Recovery
Recovering the Monitor Store from OSDs after Complete Monitor Loss

## Overview
This is a refactored and improved script-based process to recover Ceph monitor stores (monstore) from OSDs when your cluster has lost all monitors. This procedure helps restore your monitor quorum and cluster health without full data loss.
> This is not a magic wand or a simple fix. These scripts are adaptations of existing recovery methods found in Proxmox forums, IBM, and Red Hat Ceph documentation. They have been enhanced to provide extra guidance and dynamic handling because disaster recovery is a delicate process — one where mistakes can be costly. Use with care and make sure you fully understand each step before proceeding.

## Important Warnings
- DO NOT run any purge scripts unless you absolutely want to destroy all data and start over.
- Review all scripts carefully before running, especially if you have any custom setups.
- This recovery is sensitive — mistakes can cause irreversible damage.
- You must have a quorum with managers (mgrs) for the recovery to work.
- Ceph’s networking setup (IPv4/IPv6, dual-stack, routing) can cause OSDs to fail peering if misconfigured.

## Before You Begin
Recovering a Ceph monitor store from OSDs is a delicate process — **get these steps wrong, and you risk permanent data loss.** This section outlines what must be in place, when recovery is doomed from the start, and the checks you should run before executing the scripts.

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
- All OSDs are missing or corrupted — no intact PG replicas = no recovery.
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

## Final Thoughts
Recovering a Ceph cluster after total monitor loss is challenging and requires careful planning. This script set aims to guide you through a safer, more dynamic recovery process. Please review everything thoroughly and only proceed if you are confident in the steps.
Good luck, and I hope this helps anyone facing disaster recovery situations with Ceph on Proxmox!

## Disclaimer
> The scripts and guidance provided here ("Software") are offered as-is, without any warranties, express or implied. Use at your own risk.
The author makes no guarantees regarding the functionality, reliability, compatibility, or sanity of the Software. It is not responsible for any data loss, system instability, spontaneous server combustions, or black holes that may or may not open in your data center.
Should running these scripts cause your cat to develop a sudden obsession with the monitor LEDs, your coffee machine to stop working, or your neighbor to question your life choices — well, that’s purely coincidental and definitely not the author’s fault.
If, during the recovery process, you find yourself talking to your servers, singing lullabies to OSDs, or considering a career as a circus performer, remember: you agreed to this adventure willingly.
Finally, the author accepts no liability for any missed gaming sessions, forgotten birthdays, or weird dreams involving Ceph daemons dancing in a disco — those are all on you.
Huge thanks and eternal respect go to the Ceph community, Proxmox developers, and all open source heroes who made any of this possible.
Now go forth, recover bravely, and may your monitors never lose quorum again.
