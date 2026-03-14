#!/usr/bin/env bash
set -euo pipefail

LOG="/home/housestark/soc/logs/alert.log"

# dosya yoksa oluştur
sudo install -o housestark -g adm -m 0664 /dev/null "$LOG" 2>/dev/null || true

# Canlı takip + renklendirme
sudo tail -n 0 --follow=name --retry "$LOG" | stdbuf -oL awk '
/\[CRITICAL\]/ {print "\033[1;31m"$0"\033[0m"; next}
/\[HIGH\]/     {print "\033[1;35m"$0"\033[0m"; next}
/\[MEDIUM\]/   {print "\033[1;33m"$0"\033[0m"; next}
/\[INFO\]/     {print "\033[1;34m"$0"\033[0m"; next}
{print}
'
