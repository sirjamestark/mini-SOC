#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: portscan.sh <ip|cidr|hostname>"
  exit 1
fi

sev_for_port() {
  local p="$1"
  case "$p" in
    23|2323|21) echo "CRITICAL" ;;
    445|139|3389|5900) echo "HIGH" ;;
    3306|5432|27017|6379|9200) echo "MEDIUM" ;;
    22|80|443|53) echo "INFO" ;;
    *) echo "INFO" ;;
  esac
}

TS() { date "+%Y-%m-%d %H:%M:%S"; }

mkdir -p ~/soc/logs

OUT="$(nmap -sT -T4 --open -sV --version-light -oG - "$TARGET" 2>/dev/null || true)"

# If the port line is not there
if ! echo "$OUT" | grep -q 'Ports:'; then
  msg="portscan target=$TARGET result=no_open_ports_or_no_response"
  echo "$(TS) [INFO] $msg" >> ~/soc/logs/alert.log
  echo "[INFO] $msg"
  exit 0
fi

# Ex. line:
# Host: 127.0.0.1 (localhost)  Ports: 22/open/tcp//ssh///, 631/open/tcp//ipp///
echo "$OUT" | grep 'Ports:' | while IFS= read -r line; do
  host="$(echo "$line" | sed -nE 's/^Host: ([^ ]+).*/\1/p')"
  ports_str="$(echo "$line" | sed -nE 's/.*Ports: (.*)/\1/p')"

  echo "$ports_str" | tr ',' '\n' | while IFS= read -r entry; do
    entry="$(echo "$entry" | xargs)"
    [[ -z "$entry" ]] && continue

    port="$(echo "$entry" | awk -F'/' '{print $1}')"
    state="$(echo "$entry" | awk -F'/' '{print $2}')"
    svc="$(echo "$entry" | awk -F'/' '{print $5}')"
    [[ "$state" != "open" ]] && continue

    sev="$(sev_for_port "$port")"
    msg="portscan target=$host port=$port service=${svc:-unknown}"
    echo "$(TS) [$sev] $msg" >> ~/soc/logs/alert.log
    echo "[$sev] $msg"
  done
done
