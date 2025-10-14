# ---------- CREATE PROJECT SKELETON + SCRIPTS (paste once) ----------
set -euo pipefail
PROJECT="$HOME/vapt-tool"
mkdir -p "$PROJECT"
cd "$PROJECT"

# README
cat > README.md <<'MD'
vapt-tool — VAPT toolkit (lab-only). Use only against systems you own or have written permission to test.
See START.md for quick start.
MD

# requirements.txt (pip)
cat > requirements.txt <<'TXT'
gvm-tools
requests
httpx
dnspython==2.7.0
beautifulsoup4
lxml
pandas
pyyaml
tqdm
packaging
TXT

# apt-packages.txt (editable)
cat > apt-packages.txt <<'TXT'
nmap masscan netcat tcpdump tshark nikto sqlmap gobuster ffuf wpscan \
metasploit-framework openvas ospd-openvas gvmd gsad \
hashcat john hydra medusa wordlists \
theharvester amass sherlock \
aircrack-ng hcxtools hcxdumptool wifite \
wfuzz afl lynis openscap-utils scout-suite \
jq yq pandoc docker.io docker-compose snapd default-jre default-jdk golang-go \
apktool jadx frida python3-venv python3-pip python3-dev build-essential libssl-dev libxml2-dev libxslt1-dev libpcap-dev \
ruby ruby-dev
TXT

# setup.sh - installs apt pkgs, creates venv, installs pip packages, installs nuclei via go
cat > setup.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/vapt-tool"
cd "$PROJECT"
echo "[1/4] apt update && install packages (may ask sudo password)"
sudo apt update -y
xargs -a apt-packages.txt sudo apt install -y --no-install-recommends || true

echo "[2/4] Ensure snapd & core"
sudo systemctl enable --now snapd.socket || true
sudo snap install core || true
sudo snap refresh || true

echo "[3/4] Create python venv and install pip packages"
python3 -m venv .venv
# shellcheck source=/dev/null
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt || true

echo "[4/4] Install nuclei via go (if go present)"
export GOPATH="$HOME/go"
mkdir -p "$GOPATH/bin" "$HOME/.local/bin"
if ! command -v nuclei >/dev/null 2>&1; then
  /usr/bin/env bash -c "go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest" || true
  mv "$GOPATH/bin/nuclei" "$HOME/.local/bin/" 2>/dev/null || true
fi

echo "Setup complete. Activate venv: source $PROJECT/.venv/bin/activate"
SH
chmod +x setup.sh

# run_demo.sh - quick discovery & web scan
cat > run_demo.sh <<'SH'
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
SH
chmod +x run_demo.sh

# run_full_gvm_pipeline.sh - requires gvm-tools and admin credentials (automated)
cat > run_full_gvm_pipeline.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/vapt-tool"
if [ -z "${1-}" ]; then echo "Usage: $0 <target-ip>"; exit 1; fi
TARGET="$1"
read -rp "GVM admin username (usually 'admin'): " GMP_USER
read -rsp "GVM admin password: " GMP_PASS
echo
mkdir -p "$PROJECT/reports/$TARGET"
# create target
CREATE_XML="<create_target><name>lab-$TARGET</name><hosts>$TARGET</hosts></create_target>"
CREATED=$(echo "$CREATE_XML" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
TARGET_ID=$(echo "$CREATED" | xmllint --xpath 'string(//create_target_response/@id)' - 2>/dev/null || true)
if [ -z "$TARGET_ID" ]; then echo "Failed to create target. Output:"; echo "$CREATED"; exit 2; fi
# get config id 'Full and fast'
CONFIGS=$(echo '<get_configs/>' | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
CONF_ID=$(echo "$CONFIGS" | xmllint --xpath "string(//config[name='Full and fast']/@id)" - 2>/dev/null || true)
if [ -z "$CONF_ID" ]; then CONF_ID=$(echo "$CONFIGS" | xmllint --xpath "string(//config[1]/@id)" -); fi
# create task
CTASK="<create_task><name>auto-scan-$TARGET</name><config id=\"$CONF_ID\"/><target id=\"$TARGET_ID\"/></create_task>"
CREATED_TASK=$(echo "$CTASK" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
TASK_ID=$(echo "$CREATED_TASK" | xmllint --xpath 'string(//create_task_response/@id)' - 2>/dev/null || true)
if [ -z "$TASK_ID" ]; then echo "Failed to create task"; echo "$CREATED_TASK"; exit 3; fi
# start
echo "<start_task task_id=\"$TASK_ID\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -
# poll
while true; do
  STATUS_XML=$(echo "<get_tasks task_id=\"$TASK_ID\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
  STATUS=$(echo "$STATUS_XML" | xmllint --xpath "string(//task/status/text())" - 2>/dev/null || true)
  echo "Status: $STATUS"
  if [[ "$STATUS" =~ Done|Complete|Stopped ]]; then break; fi
  sleep 20
done
# export latest report (PDF)
REPORT_XML=$(echo "<get_reports task_id=\"$TASK_ID\" details=\"1\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
REPORT_ID=$(echo "$REPORT_XML" | xmllint --xpath "string(//report/@id)" - 2>/dev/null || true)
if [ -n "$REPORT_ID" ]; then
  echo "<get_report report_id=\"$REPORT_ID\" format_id=\"c402cc3e-b531-11e1-9163-406186ea4fc5\"/>" \
    | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --raw - > "$PROJECT/reports/$TARGET/gvm_report.pdf"
  echo "Saved: $PROJECT/reports/$TARGET/gvm_report.pdf"
else
  echo "No report id found"
fi
SH
chmod +x run_full_gvm_pipeline.sh

# menu.sh - single interactive menu
cat > scripts/menu.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/vapt-tool"
# source venv if exists
if [ -f "$PROJECT/.venv/bin/activate" ]; then
  # shellcheck source=/dev/null
  source "$PROJECT/.venv/bin/activate"
fi
start_services(){
  sudo systemctl start ospd-openvas || true
  sudo systemctl start gvmd || true
  sudo systemctl start gsad || true
  if command -v msfdb >/dev/null 2>&1; then sudo msfdb start || true; fi
  sudo systemctl start docker 2>/dev/null || true
  echo "Services started (or attempted)."
}
start_gvm_ui(){ echo "Open https://127.0.0.1:9392 in browser"; xdg-open "https://127.0.0.1:9392" >/dev/null 2>&1 || true; }
start_burp(){
  if [ -f "$PROJECT/tools/burpsuite_community.jar" ]; then (cd "$PROJECT/tools" && java -jar burpsuite_community.jar &) ;
  elif command -v burpsuite >/dev/null 2>&1; then burpsuite &>/dev/null &; else echo "Burp not found. Place jar in $PROJECT/tools or install via snap/apt."; fi
}
run_demo(){ read -rp "Target IP: " T; "$PROJECT/run_demo.sh" "$T"; }
run_full_gvm(){ read -rp "Target IP: " T; "$PROJECT/run_full_gvm_pipeline.sh" "$T"; }
msf_import(){ read -rp "Target IP: " T; msfconsole -q -x "db_import $PROJECT/reports/$T/nmap_quick.xml; hosts; services; exit"; }
vapt_check(){
  echo "Python: $(python3 --version 2>/dev/null || echo 'missing')"
  [ -d "$PROJECT/.venv" ] && echo "venv: ok" || echo "venv: missing"
  for t in nmap nikto nuclei msfconsole burpsuite; do command -v $t >/dev/null 2>&1 && echo "ok: $t" || echo "missing: $t"; done
}
PS3=$'\nChoose: '
options=("Start services" "Open GVM UI" "Start Burp" "Run demo scans (nmap/nikto/nuclei)" "Import nmap into Metasploit" "Run full GVM pipeline (automated)" "Validation check" "Exit")
select opt in "${options[@]}"; do
  case $REPLY in
    1) start_services;;
    2) start_gvm_ui;;
    3) start_burp;;
    4) run_demo;;
    5) msf_import;;
    6) run_full_gvm;;
    7) vapt_check;;
    8) echo "Bye"; exit 0;;
    *) echo "Invalid";;
  esac
done
SH
chmod +x scripts/menu.sh

# report template
mkdir -p templates reports tools scripts
cat > templates/vapt_report_template.md <<'MD'
# VAPT Report - <PROJECT>
Date: <DATE>
Scope: <TARGETS>

## Executive Summary
...

## Tools & Methodology
- nmap, nikto, nuclei, Metasploit, GVM/OpenVAS, Burp Suite

## Findings
- ID: 001
  - Title:
  - Affected:
  - Evidence:
  - Remediation:

## Appendix
Raw outputs: ~/vapt-tool/reports/<target>/
MD

# START.md
cat > START.md <<'TXT'
Quick start:
1) Open bash: exec bash --login
2) cd ~/vapt-tool
3) bash setup.sh
4) source .venv/bin/activate
5) bash scripts/menu.sh
TXT

echo "vapt-tool skeleton created in $PROJECT. Next: run 'bash setup.sh' (may take a while)."
# ---------- END CREATE ----------
