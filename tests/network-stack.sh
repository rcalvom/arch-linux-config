#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

fail() {
  printf 'test failure: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle=$1
  local file=$2

  grep -Fqx -- "$needle" "$file" || fail "$file does not contain $needle"
}

assert_absent() {
  local needle=$1
  local file=$2

  ! grep -Fqx -- "$needle" "$file" || fail "$file unexpectedly contains $needle"
}

assert_contains iwd "$REPO_DIR/packages/base.txt"
assert_contains wireless-regdb "$REPO_DIR/packages/base.txt"
assert_absent networkmanager "$REPO_DIR/packages/base.txt"
assert_absent network-manager-applet "$REPO_DIR/packages/desktop.txt"
assert_absent networkmanager "$REPO_DIR/live/packages.x86_64"
assert_absent network-manager-applet "$REPO_DIR/live/packages.x86_64"
grep -Fq 'EnableNetworkConfiguration=true' "$REPO_DIR/network/iwd/main.conf" || fail "IWD does not own Wi-Fi addressing"
grep -Fq 'NameResolvingService=systemd' "$REPO_DIR/network/iwd/main.conf" || fail "IWD does not publish DNS to resolved"
grep -Fq 'Name=en* eth*' "$REPO_DIR/network/systemd/network/20-wired.network" || fail "networkd does not have a narrow wired match"
grep -Fq 'RouteMetric=100' "$REPO_DIR/network/systemd/network/20-wired.network" || fail "wired route priority is not explicit"
grep -Fq 'enable_system_service_in_profile "$profile_copy" iwd.service' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not enable IWD"
grep -Fq 'enable_system_service_in_profile "$profile_copy" systemd-networkd.service' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not enable networkd"
grep -Fq 'enable_system_service_in_profile "$profile_copy" systemd-resolved.service' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not enable resolved"
grep -Fq 'enable_system_service_in_profile "$profile_copy" network-online.target' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not start network-online.target"
grep -Fq 'enable_profile_local_system_service "$profile_copy" host-network-online.service network-online.target' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not enable aggregate network wait"
grep -Fq 'file_permissions["/usr/local/libexec/archcfg-wait-network-online"]="0:0:755"' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO does not preserve the network wait helper mode"
grep -Fq 'rm -f "$profile_copy/airootfs/etc/systemd/network/20-ethernet.network"' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO retains a duplicate wired network rule"
grep -Fq 'disable_service_if_present NetworkManager.service' "$REPO_DIR/scripts/services.sh" || fail "installed systems do not disable NetworkManager"
grep -Fq 'check_disabled_unit NetworkManager.service' "$REPO_DIR/scripts/verify-system-config.sh" || fail "system verifier does not reject active NetworkManager"
grep -Fq 'wait_for_live_services' "$REPO_DIR/scripts/vbox-e2e.sh" || fail "E2E does not wait for live network services"
grep -Fq 'run_live_checks' "$REPO_DIR/scripts/vbox-e2e.sh" || fail "E2E does not verify live networking"
! grep -Fq 'enable_system_service_in_profile "$profile_copy" NetworkManager.service' "$REPO_DIR/scripts/build-iso.sh" || fail "live ISO still enables NetworkManager"

networkd_enable_line=$(grep -n 'enable_service_if_present systemd-networkd.service' "$REPO_DIR/scripts/services.sh" | cut -d: -f1)
networkd_wait_disable_line=$(grep -n 'disable_service_if_present systemd-networkd-wait-online.service' "$REPO_DIR/scripts/services.sh" | cut -d: -f1)
[[ "$networkd_wait_disable_line" -gt "$networkd_enable_line" ]] || fail "networkd wait-online is disabled before networkd can enable it"
