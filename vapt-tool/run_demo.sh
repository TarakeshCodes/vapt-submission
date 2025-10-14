#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/vapt-tool"
if [ -z "${1-}" ]; then echo "Usage: $0 <target-ip>"; exit 1; fi
TARGET="$1"
OUT="$PROJECT/reports/$TARGET"
mkdir -p "$OUT"
echo "[demo] nmap quick"
nmap -sS -sV -T4 -oA "$OUT/nmap_quick" "$TARGET"
echo "[demo] nikto http"
nikto -h "http://$TARGET" -o "$OUT/nikto.txt" || true
echo "[demo] nuclei (http)"
nuclei -u "http://$TARGET" -o "$OUT/nuclei.txt" || true
echo "[demo] done. Reports: $OUT"
