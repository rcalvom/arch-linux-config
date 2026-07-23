# Networking

The desktop profile uses split network ownership so Impala can manage Wi-Fi without competing with NetworkManager:

- IWD owns one selected Wi-Fi interface and provides DHCP through `EnableNetworkConfiguration=true`.
- `systemd-resolved` receives DNS data from IWD.
- NetworkManager keeps ownership of Ethernet, Cisco Secure Client integration, and other non-Wi-Fi connections.
- `host-network-online.service` replaces `NetworkManager-wait-online.service` for services such as Docker that require `network-online.target`.
- Cisco temporarily replaces `/etc/resolv.conf` with tunnel DNS. When it restores the `systemd-resolved` stub on disconnect, `archcfg-reset-resolved-if-stub.path` restarts resolved to discard stale tunnel DNS.

The IWD profile and Wi-Fi passphrase are intentionally not stored in this repository. Join the network through Impala after installation.

## Existing System Migration

Install the regulatory database while NetworkManager still owns Wi-Fi:

```bash
sudo pacman -S --needed wireless-regdb
```

Disconnect an active Cisco VPN, keep a local terminal open, and have the Wi-Fi passphrase available. Then run:

```bash
sudo ./scripts/apply-iwd-wlan0.sh --wifi-interface auto
```

`auto` selects the only detected Wi-Fi interface. If more than one radio exists, pass its interface name explicitly instead. The script requires typing `MIGRATE`, stores a dated backup in `/var/lib/arch-linux-config/network-backups/`, and leaves the terminal available to start Impala. Test Wi-Fi, DNS, Cisco VPN, Docker, and suspend/resume before considering the migration complete.

If IWD was migrated with an earlier repository revision, install the Cisco DNS recovery watcher without restarting Wi-Fi:

```bash
sudo ./scripts/apply-resolved-reset-watcher.sh
```

If IWD cannot connect, restore the NetworkManager configuration with the backup path printed by the migration script:

```bash
sudo ./scripts/rollback-iwd-wlan0.sh --backup /var/lib/arch-linux-config/network-backups/<timestamp>
```

Rollback intentionally leaves IWD disabled and restarts NetworkManager so it can recover ownership of Wi-Fi without competing supplicants.

## Installer Selection

`install.sh --wifi-interface auto` is the default. It hands a single detected radio to IWD, skips the handoff when no radio exists, and refuses to choose between multiple radios. Use `--wifi-interface <name>` for a known wireless interface, including a target whose radio is not visible from the installer environment; a present Ethernet interface is rejected. Use `--wifi-interface none` to remove Archcfg's IWD handoff and restore NetworkManager ownership of Wi-Fi.

Verify the deployed network files and units without changing them with:

```bash
sudo ./scripts/verify-system-config.sh --profile developer --wifi-interface auto
```

On hosts without an NVIDIA PCI device, `modules-load.d/nvidia-utils.conf` masks the vendor module list that otherwise requests `nvidia_uvm`. This keeps `nvidia-utils` installed for package dependencies while avoiding an irrelevant module-load warning. Remove the local override before adding an NVIDIA GPU or eGPU.
