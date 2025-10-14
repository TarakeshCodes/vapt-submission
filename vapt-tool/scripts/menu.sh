#!/usr/bin/env bash
set -euo pipefail

PROJECT="$HOME/vapt-tool"
VENV="$PROJECT/.venv"

# Activate venv if exists
if [ -f "$VENV/bin/activate" ]; then
  # shellcheck source=/dev/null
  source "$VENV/bin/activate"
fi

start_services() {
  echo "[*] Starting core services (best-effort, may require sudo)"
  sudo systemctl start ospd-openvas || true
  sudo systemctl start gvmd || true
  sudo systemctl start gsad || true
  if command -v msfdb >/dev/null 2>&1; then
    sudo msfdb start || true
  fi
  sudo systemctl start docker 2>/dev/null || true
  echo "[*] Services start attempted."
}

open_gvm() {
  echo "Open GVM web UI: https://127.0.0.1:9392"
  xdg-open "https://127.0.0.1:9392" >/dev/null 2>&1 || true
}

start_burp() {
  if [ -f "$PROJECT/tools/burpsuite_community.jar" ]; then
    (cd "$PROJECT/tools" && java -jar burpsuite_community.jar &) 
    echo "Burp started from $PROJECT/tools/burpsuite_community.jar"
    return
  fi
  if command -v burpsuite >/dev/null 2>&1; then
    burpsuite &>/dev/null &
    echo "Burp launched from system command"
    return
  fi
  echo "Burp not found: place burpsuite_community.jar in $PROJECT/tools or install burpsuite"
}

run_demo() {
  read -rp "Target IP (lab only): " T
  if [ -z "$T" ]; then
    echo "No target provided"; return 1
  fi
  "$PROJECT/run_demo.sh" "$T"
}

vapt_check() {
  echo "== Environment quick check =="
  printf "Python: %s\n" "$(python3 --version 2>/dev/null || echo missing)"
  if [ -d "$VENV" ]; then
    echo "venv: present ($VENV)"
  else
    echo "venv: missing"
  fi
  for t in nmap nikto nuclei msfconsole burpsuite; do
    if command -v "$t" >/dev/null 2>&1; then
      printf "ok: %s\n" "$t"
    else
      printf "missing: %s\n" "$t"
    fi
  done
}

show_menu() {
  PS3=$'\nSelect an option: '
  options=("Start core services" "Open GVM UI" "Start Burp" "Run demo scans (nmap/nikto/nuclei)" "Validation check" "Exit")
  select opt in "${options[@]}"; do
    case $REPLY in
      1) start_services ;;
      2) open_gvm ;;
      3) start_burp ;;
      4) run_demo ;;
      5) vapt_check ;;
      6) echo "Goodbye"; exit 0 ;;
      *) echo "Invalid selection";;
    esac
  done
}

# If this file is sourced accidentally, avoid running menu. Only run when executed.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  show_menu
fi
