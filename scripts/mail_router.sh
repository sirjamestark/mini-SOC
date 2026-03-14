#!/usr/bin/env bash
set -euo pipefail

LOG="${1:-/home/housestark/soc/logs/alert.log}"

SUPPRESS_SEC="${SUPPRESS_SEC:-1}"   # correlation sonrası (src bazlı) portscan susturma
DEDUP_SEC="${DEDUP_SEC:-5}"         # aynı satırı tekrar görürse sustur
DEBUG="${DEBUG:-0}"

# tek instance
exec 9>/run/soc-mailrouter.lock
flock -n 9 || exit 0

mkdir -p /run/soc-mailrouter
chmod 700 /run/soc-mailrouter

WEBHOOK_URL=""
if [[ -r /etc/minisoc-discord.conf ]]; then
  # shellcheck disable=SC1091
  source /etc/minisoc-discord.conf
fi

to_epoch() { date -d "$1" +%s 2>/dev/null || echo 0; }

logd() {
  [[ "$DEBUG" == "1" ]] || return 0
  echo "mailrouter: $*" | systemd-cat -t soc-mailrouter
}

sev_prefix() {
  local sev="$1"
  case "$sev" in
    INFO|MEDIUM) echo "-" ;;
    HIGH)        echo "!" ;;
    CRITICAL)    echo "!!!" ;;
    *)           echo "-" ;;
  esac
}

discord_send() {
  local prefix="$1"
  local title="$2"
  local line="$3"

  [[ -n "${WEBHOOK_URL:-}" ]] || { logd "WEBHOOK_URL empty"; return 0; }

  local msg payload code
  msg="$(printf '%s %s\n%s' "$prefix" "$title" "$line")"

  # JSON'ı doğru encode et (newline dahil)
  payload="$(python3 - <<PY
import json
msg = """$msg"""
print(json.dumps({"content": msg}))
PY
)"

  code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "$WEBHOOK_URL" || echo "000")"

  if [[ "$code" != "204" && "$code" != "200" ]]; then
    logd "discord_send failed http=$code title='$title'"
  else
    logd "discord_send ok http=$code title='$title'"
  fi
}

# src bazlı suppression
declare -A suppress_until

dedupe_ok() {
  local line="$1" now="$2"
  local h f last
  h="$(printf '%s' "$line" | sha1sum | awk '{print $1}')"
  f="/run/soc-mailrouter/$h"
  if [[ -f "$f" ]]; then
    last="$(cat "$f" 2>/dev/null || echo 0)"
    if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < DEDUP_SEC )); then
      return 1
    fi
  fi
  echo "$now" > "$f"
  return 0
}

tail -n 0 -F "$LOG" | while read -r line; do
  ts="${line:0:19}"
  [[ "$ts" =~ ^[0-9]{4}- ]] || continue
  epoch="$(to_epoch "$ts")"
  (( epoch > 0 )) || continue

  logd "seen: $line"

  sev="$(echo "$line" | sed -nE 's/.*\[(INFO|MEDIUM|HIGH|CRITICAL)\].*/\1/p')"
  [[ -n "$sev" ]] || continue
  prefix="$(sev_prefix "$sev")"

  # CORRELATION (genelde CRITICAL)
  if [[ "$line" == *" correlation "* ]]; then
    src="$(echo "$line" | sed -nE 's/.*src=([^ ]+).*/\1/p')"
    [[ -n "$src" ]] || src="unknown"
    suppress_until["$src"]=$(( epoch + SUPPRESS_SEC ))

    if dedupe_ok "$line" "$epoch"; then
      discord_send "$prefix" "CORRELATION ($(hostname)) src=$src" "$line"
    fi
    continue
  fi

  # PORTSCAN
  if [[ "$line" == *"portscan_live"* ]]; then
    src="$(echo "$line" | sed -nE 's/.*src=([^ ]+).*/\1/p')"
    [[ -n "$src" ]] || src="unknown"

    until="${suppress_until[$src]:-0}"
    if (( epoch < until )); then
      logd "suppressed portscan src=$src until=$until"
      continue
    fi

    if dedupe_ok "$line" "$epoch"; then
      discord_send "$prefix" "PORTSCAN ($(hostname)) src=$src" "$line"
    fi
    continue
  fi

  # DNS
  if [[ "$line" == *"dns_live "* ]]; then
    if dedupe_ok "$line" "$epoch"; then
      discord_send "$prefix" "DNS ($(hostname))" "$line"
    fi
    continue
  fi

done
