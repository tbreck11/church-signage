#!/usr/bin/env bash
# Zips the app and sideloads it to one or more Rokus in Developer Mode (macOS/Linux).
# Usage: scripts/deploy.sh [--zip-only] [ip ...]
# IPs on the command line override rokuIps in deploy.json. The password comes
# from deploy.json (rokuPassword, or passwords.<ip>) or the ROKU_PASSWORD env var.
set -euo pipefail
cd "$(dirname "$0")/.."

ZIP_ONLY=0
if [ "${1:-}" = "--zip-only" ]; then ZIP_ONLY=1; shift; fi

mkdir -p out
ZIP=out/church-signage.zip
rm -f "$ZIP"
zip -qr "$ZIP" manifest source components images
echo "Built $ZIP"
[ "$ZIP_ONLY" = 1 ] && exit 0

json_get() { [ -f deploy.json ] && python3 -c "import json,sys; d=json.load(open('deploy.json')); v=d
for k in sys.argv[1:]: v=(v or {}).get(k) if isinstance(v,dict) else None
print(' '.join(v) if isinstance(v,list) else (v or ''))" "$@" || true; }

IPS=("$@")
[ ${#IPS[@]} -eq 0 ] && read -r -a IPS <<< "$(json_get rokuIps)"
[ ${#IPS[@]} -eq 0 ] && { echo "Set rokuIps in deploy.json, or pass IPs as arguments." >&2; exit 1; }

failed=()
for ip in "${IPS[@]}"; do
  pw="$(json_get passwords "$ip")"
  [ -z "$pw" ] && pw="${ROKU_PASSWORD:-$(json_get rokuPassword)}"
  if [ -z "$pw" ]; then echo "$ip: no developer password. Set rokuPassword in deploy.json." >&2; failed+=("$ip"); continue; fi
  echo "Sideloading to $ip ..."
  out=$(curl --silent --show-error --connect-timeout 10 --max-time 120 --digest --user "rokudev:$pw" \
    -F "mysubmit=Install" -F "archive=@$ZIP" "http://$ip/plugin_install" 2>&1 || true)
  if echo "$out" | grep -qE "Install Success|Identical to previous version"; then
    echo "$ip: installed. The board is running."
  else
    echo "$out" | grep -o '<font color="red">[^<]*' | sed 's/<font color="red">//' >&2 || true
    echo "$ip: FAILED. Check the IP, the developer password, and that the TV is on." >&2
    failed+=("$ip")
  fi
done

[ ${#failed[@]} -gt 0 ] && { echo "Sideload failed on: ${failed[*]}" >&2; exit 1; }
echo "All ${#IPS[@]} Roku(s) updated."
