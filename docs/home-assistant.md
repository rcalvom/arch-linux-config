# Home Assistant

## Scope

This optional personal deployment runs Home Assistant Container with host
networking. Docker bridge networking did not provide host-to-container access
on the configured host. The web interface is consequently protected with a
dedicated nftables table instead of Docker port publishing.

The policy permits TCP port 8123 only through the loopback interface and drops
all other traffic to that port. It covers IPv4 and IPv6, including LAN, Wi-Fi,
Tailscale, VPN, and Internet-originated traffic. It does not modify the
iptables-nft tables managed by Docker, Tailscale, or Cisco VPN.

The container may still use its host network for outbound IoT integrations and
local discovery. That is distinct from exposing its web interface.

## Tracked Configuration

- `home-assistant/compose.yaml` is the sanitized Compose definition.
- `home-assistant/nftables/home-assistant-loopback.nft` is the dedicated
  loopback-only firewall table.
- `home-assistant/systemd/home-assistant-loopback.service` installs that table
  before Docker during normal boot.

Home Assistant's `config/` volume is runtime state. It can contain user
accounts, integrations, long-lived tokens, device identifiers, databases, and
automations, so it is deliberately not tracked. Do not commit it or copy it
into this repository.

## Initial Deployment

Review the source first, then deploy the firewall policy. This command changes
system configuration and requires explicit approval:

```bash
cd ~/Documents/Personal/repositories/arch-linux-config
sudo bash scripts/apply-home-assistant-loopback.sh
```

Verify that the dedicated table is active before starting the container:

```bash
sudo systemctl status home-assistant-loopback.service --no-pager
sudo nft list table inet home_assistant_loopback
```

Deploy the reviewed Compose file to the existing Home Assistant runtime
directory, preserving its untracked `config/` directory:

```bash
install -Dm644 home-assistant/compose.yaml ~/.local/share/home-assistant/compose.yaml
cd ~/.local/share/home-assistant
sudo docker compose up -d
```

Use only `http://127.0.0.1:8123` for onboarding and normal access. Do not use
the host's LAN, Wi-Fi, Tailscale, or IPv6 address.

## Verification

After the container is ready:

```bash
curl --fail --silent --show-error http://127.0.0.1:8123/ >/dev/null
ss -ltn '( sport = :8123 )'
sudo nft list table inet home_assistant_loopback
```

`ss` can show Home Assistant listening on wildcard addresses because host
networking is intentional. The nftables policy is the enforcement point; it
must remain enabled and active.

## Discovery And Dreo

A passive mDNS scan on September 25, 2026 did not identify either light bulb or
the Dreo fan. This does not establish that the devices are absent: many IoT
vendors do not advertise recognizable local services.

An approved, limited active scan of the local `/24` segment followed by TCP
connection attempts to common web and IoT ports on the unclassified hosts also
did not identify these devices. No port scan beyond those candidates, no
authentication attempt, and no external MAC-vendor lookup was performed. Use
the router's connected-device inventory or the existing vendor applications to
obtain the exact device identities before adding integrations.

Home Assistant's `default_config` enables Zeroconf, which advertises a
`_home-assistant._tcp` service on the local network. The firewall still rejects
all non-loopback connections to its TCP/8123 UI. Suppressing that service would
require removing `default_config` and explicitly selecting replacement
integrations without Zeroconf, which also removes mDNS/HomeKit auto-discovery.
Keep the current configuration while device discovery is needed; make that
privacy-versus-discovery change only in an approved maintenance window.

Dreo's official Home Assistant integration is currently a non-core custom
component (`dreo-team/hass-dreoverse`, version 2.2.1 at review). It is cloud
polling and authenticates with the same Dreo account used in the Dreo mobile
application. It is not a local-only integration. Installing HACS or this custom
component, and entering the Dreo account credentials in Home Assistant, require
separate approval. Do not commit its generated state, diagnostics, or account
data.

Ricardo's Dreo Tower Fan 307S is model `DR-HTF007S`, firmware
`V 3.8.8_3.0.8`. It is explicitly listed as the supported Nomad One S model in
the official Dreo component. It supports cloud-mediated power, modes, speed,
and oscillation controls; it is not a Matter or local-only integration.

The approved component source is the published `v2.2.1` release, pinned in
`home-assistant/components/dreo-v2.2.1.json` with its release-asset SHA-256.
It is installed manually under Home Assistant's untracked runtime
`config/custom_components/dreo` directory; HACS is not installed. The component
depends on `pydreo-cloud==1.0.0` and retains the API-required password hash in
Home Assistant runtime state. The user must enter the Dreo account in the local
Home Assistant UI after installation.

The two light bulbs are TP-Link Kasa KL125 devices, supported by Home
Assistant's built-in **TP-Link Smart Home** integration. That integration polls
the bulbs locally after setup. Depending on their hardware revision and
firmware, Kasa may require the TP-Link account email and password to
authenticate that local connection; enter them only in the Home Assistant UI,
never in this repository or a chat. Their assigned addresses are mutable local
network state and are deliberately not tracked.

On September 25, 2026, adding one KL125 failed with `Device response did not
match our challenge` despite confirmed credentials. Home Assistant 2026.9.3
ships `python-kasa` 0.10.2, and the upstream `python-kasa` KLAP v2 transport
selection issue remains open with an unmerged pull request. This is consistent
with a protocol compatibility defect rather than evidence of an incorrect
password. Confirm **Third-Party Compatibility** is enabled in the Kasa app,
but do not reset the bulbs, rotate the TP-Link password, downgrade firmware, or
install an unreviewed workaround. A temporary custom-component workaround
requires separate approval, source review, and a Home Assistant restart.

Read-only discovery confirmed the affected KL125 reports `IOT.SMARTBULB`,
`KLAP`, login version `2`, and `new_klap: 1`. The old standalone local
controller uses the legacy TCP/9999 protocol and cannot communicate with this
firmware. This directly matches the upstream defect: `python-kasa` selects the
v1 transport for an IOT KLAP device although login version 2 requires the v2
transport. No light state or device configuration was changed during testing.

The temporary `home-assistant/custom-components/tplink_klapv2_fix` component
implements the minimal transport-selection portion of upstream
`python-kasa` PR [#1692](https://github.com/python-kasa/python-kasa/pull/1692)
at reviewed head `8b1f6b8c40588584f5d89df37e4610e2ece9a8cb`. It changes only
IOT smart bulbs and switches that advertise KLAP login version 2, and delegates
all other device configurations to the installed `python-kasa` implementation.
It is activated by the matching YAML fragment, requires a Home Assistant
restart, and must be removed after an equivalent upstream release is included.
The temporary component emits a credential-free local log entry whenever it
selects KLAP v2, so a failed configuration flow can be distinguished from a
failure to activate the workaround.

## Updating the Policy

The apply script deliberately refuses to replace an active policy. Stop Home
Assistant, review the firewall change, stop the policy, apply it, verify it,
and then start Home Assistant again. This prevents an unnoticed firewall gap
during a policy replacement.
