#!/usr/bin/env bash
set -euo pipefail

IFACE="${1:-eth0}"
THRESH="${2:-250}"
LOG="/home/housestark/soc/logs/alert.log"

# her 10 sn ölç
WIN=10

while true; do
  # 10 sn DNS say
  cnt="$(timeout "${WIN}" tcpdump -n -i "$IFACE" "(udp port 53 or tcp port 53)" 2>/dev/null | wc -l || true)"
  cnt="${cnt:-0}"

  # dakikaya normalize (10 sn * 6)
  rate=$(( cnt * (60 / WIN) ))

  # severity: her zaman en az INFO
  sev="INFO"
  if   (( rate >= THRESH * 4 )); then sev="CRITICAL"
  elif (( rate >= THRESH * 2 )); then sev="HIGH"
  elif (( rate >= THRESH ));     then sev="MEDIUM"
  fi

  ts="$(date '+%F %T')"
  echo "$ts [$sev] dns_live rate_per_min=$rate threshold=$THRESH iface=$IFACE" >> "$LOG"
done
