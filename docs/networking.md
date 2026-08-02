# Networking

The system uses one network owner per link:

- IWD owns all Wi-Fi interfaces and provides DHCP through `EnableNetworkConfiguration=true`.
- `systemd-networkd` owns wired and USB Ethernet interfaces matched by `en*` or `eth*`.
- `systemd-resolved` receives DNS data from IWD and networkd.
- `host-network-online.service` provides the aggregate wait for services such as Docker that require `network-online.target`.
- Cisco temporarily replaces `/etc/resolv.conf` with tunnel DNS. When it restores the `systemd-resolved` stub on disconnect, `archcfg-reset-resolved-if-stub.path` restarts resolved to discard stale tunnel DNS.

The IWD profile and Wi-Fi passphrase are intentionally not stored in this repository. Click the Waybar network module to open Impala after installation.

## Existing System Migration

Disconnect an active Cisco VPN, keep a local terminal open, and run the reversible migration script. It backs up NetworkManager profiles and unit state, provisions required IWD profiles, and arms a systemd-owned rollback before disabling NetworkManager. Keep NetworkManager and wpa_supplicant installed until Wi-Fi, DNS, Cisco, Ethernet, suspension, and enterprise Wi-Fi have passed a soak test.

Cisco Secure Client temporarily owns `/etc/resolv.conf` while a tunnel is connected. The watcher intentionally restarts resolved only after Cisco restores the resolved stub on a normal disconnect. This compatibility exception requires a real Cisco connect/disconnect test before NetworkManager is removed.

Verify the deployed network files and units without changing them with:

```bash
sudo ./scripts/verify-system-config.sh --profile developer
```

On hosts without an NVIDIA PCI device, `modules-load.d/nvidia-utils.conf` masks the vendor module list that otherwise requests `nvidia_uvm`. This keeps `nvidia-utils` installed for package dependencies while avoiding an irrelevant module-load warning. Remove the local override before adding an NVIDIA GPU or eGPU.
