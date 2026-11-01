#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 && "$(systemd-detect-virt)" == oracle ]] || { printf 'Disposable root VirtualBox fixture required\n' >&2; exit 1; }
username=${1:?Test username required}
[[ " $(id -nG "$username") " != *' docker '* ]] || { printf 'Unexpected docker membership\n' >&2; exit 1; }
if runuser -u "$username" -- docker info >/dev/null 2>&1; then
  printf 'Docker was accessible without sudo\n' >&2
  exit 1
fi
tmp=$(mktemp -d)
image="archcfg-sudo-test:$(date +%s)-$$"
trap 'docker image rm "$image" >/dev/null 2>&1 || true; rm -rf -- "$tmp"' EXIT
printf 'int main(void) { return 0; }\n' | gcc -static -x c -o "$tmp/success" -
printf 'FROM scratch\nCOPY success /success\nENTRYPOINT ["/success"]\n' > "$tmp/Dockerfile"
docker buildx version
docker build --network none -t "$image" "$tmp"
docker run --rm --network none --read-only --cap-drop ALL "$image"
printf 'PASS: sudo Docker build/run without docker membership or external image downloads\n'
