#!/usr/bin/env bash
set -euo pipefail

LOG="${1:-/home/housestark/soc/logs/alert.log}"
WINDOW_SEC="${WINDOW_SEC:-60}"
COOLDOWN_SEC="${COOLDOWN_SEC:-60}"
ALERT_TO="${ALERT_TO:-}"

# Tek instance
exec 9>/run/soc-correlator.lock
flock -n 9 || exit 0

declare -A last_port_epoch
declare -A last_port_info
declare -A last_corr_epoch

last_dns_epoch=0
last_dns_info=""

# Global mail cooldown (spam kesmek için)
last_global_corr_epoch=0

to_epoch() {
  local ts="$1" out
  if out="$(date -d "$ts" +%s 2>/dev/null)"; then echo "$out"; else echo 0; fi
}

emit_corr() {
  local src="$1" now_epoch="$2" ts="$3"

  # src bazlı cooldown
  local last="${last_corr_epoch[$src]:-0}"
  if (( now_epoch - last < COOLDOWN_SEC )); then return; fi
  last_corr_epoch["$src"]="$now_epoch"

  # global cooldown (mail+log spam’i keser)
  if (( now_epoch - last_global_corr_epoch < COOLDOWN_SEC )); then return; fi
  last_global_corr_epoch="$now_epoch"

  local line="$ts [CRITICAL] correlation src=$src ${last_port_info[$src]} ${last_dns_info} reason=dns_plus_port window=${WINDOW_SEC}s"
  echo "$line" >> "$LOG"

  if [[ -n "${ALERT_TO}" ]]; then
    echo "$line" | mail -s "[CRITICAL] SOC Correlation on $(hostname) (src=$src)" "$ALERT_TO" || true
  fi
}

while read -r line; do
  ts="${line:0:19}"
  [[ "$ts" =~ ^[0-9]{4}- ]] || continue
  epoch="$(to_epoch "$ts")"
  (( epoch > 0 )) || continue

  # PORT EVENT: SADECE CRITICAL portscan_live
  if [[ "$line" == *"[CRITICAL]"* && "$line" == *"portscan_live "* ]]; then
    src="$(echo "$line" | sed -nE 's/.*src=([^ ]+).*/\1/p')"
    dst="$(echo "$line" | sed -nE 's/.*dst=([^ ]+).*/\1/p')"
    uniq="$(echo "$line" | sed -nE 's/.*uniq_dpt=([^ ]+).*/\1/p')"

    [[ "$src" == 192.168.0.* ]] || continue
    [[ "$src" == 192.168.0.41 ]] && continue

    last_port_epoch["$src"]="$epoch"
    last_port_info["$src"]="dst=$dst uniq_dpt=$uniq"

    if (( last_dns_epoch > 0 )) && (( epoch - last_dns_epoch <= WINDOW_SEC )); then
      emit_corr "$src" "$epoch" "$ts"
    fi
  fi

  # DNS EVENT: SADECE CRITICAL dns_live
  if [[ "$line" == *"[CRITICAL]"* && "$line" == *"dns_live "* ]]; then
    last_dns_epoch="$epoch"
    rate="$(echo "$line" | sed -nE 's/.*rate_per_min=([^ ]+).*/\1/p')"
    last_dns_info="dns_rate=$rate"

    for src in "${!last_port_epoch[@]}"; do
      p="${last_port_epoch[$src]}"
      if (( epoch - p <= WINDOW_SEC )); then
        emit_corr "$src" "$epoch" "$ts"
      fi
    done
  fi
done < <(tail -n 0 -F "$LOG")
