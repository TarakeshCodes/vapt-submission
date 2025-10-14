#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Config
PROJECT_DIR="$HOME/vapt-tool"                # change if you want a different path
VENV_DIR="$PROJECT_DIR/.venv"
LOCAL_BIN="$HOME/bin"                        # user-local executables (preferred)
REQ_FILE="$PROJECT_DIR/requirements.txt"
MISSED_PKGS=()

echo "=== VAPT Tool bulk installer ==="
echo "Project directory: $PROJECT_DIR"
echo

# 1) Ensure project dir exists
mkdir -p "$PROJECT_DIR" || { echo "Cannot create $PROJECT_DIR"; exit 1; }

# 2) apt update
echo "[1/6] Updating apt..."
sudo apt update -y || echo "apt update failed - continuing (network?)"

# 3) Install system packages (best-effort)
echo "[2/6] Installing common system packages (best-effort)..."
PKGS=( \
  build-essential git curl wget python3 python3-venv python3-pip python3-dev \
  default-jre default-jdk golang-go docker.io docker-compose-plugin snapd \
  ruby ruby-dev zlib1g-dev libxml2-dev libxslt1-dev libssl-dev libgcrypt20-dev \
  postgresql redis-server jq ncftp nasm net-tools whois vim screen unzip p7zip-full \
  masscan nmap nikto sqlmap wpscan amass gobuster hashcat hydra metasploit-framework \
  aircrack-ng theharvester wfuzz afl-fuzz apktool frida-tools smbclient smbmap enum4linux \
  rpcbind smbclient smbclient samba wine nfs-common docker-compose \
)
# install in chunks to avoid long single apt errors
sudo apt install -y "${PKGS[@]}" || true

# record missing packages (quick check)
for p in "${PKGS[@]}"; do
  if ! apt-cache policy "$p" >/dev/null 2>&1 || dpkg -s "$p" >/dev/null 2>&1; then
    # dpkg -s returns 0 if installed; ignore installed; apt-cache policy being missing isn't reliable
    :
  fi
done

# 4) Create Python venv and install pip packages
echo "[3/6] Create Python virtualenv (if missing) and install Python deps..."
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
  echo "Created virtualenv at $VENV_DIR"
fi
# activate
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip setuptools wheel || true

# Create requirements.txt in project dir
cat > "$REQ_FILE" <<'REQ'
# vapt-tool python requirements (pin versions if you prefer)
nmap-python
dnspython==2.7.0
impacket==0.12.0
requests
httpx
beautifulsoup4
pandas
pyyaml
msfrpc
pyOpenSSL
python-dateutil
tqdm
jinja2
rich
REQ

echo "Installing python requirements from $REQ_FILE (inside venv)..."
python -m pip install -r "$REQ_FILE" || true

# 5) Make local bin dir and create vapt launcher
echo "[4/6] Creating launcher in $LOCAL_BIN ..."
mkdir -p "$LOCAL_BIN"
LAUNCHER="$LOCAL_BIN/vapt"

cat > "$LAUNCHER" <<'VAPT_SH'
#!/usr/bin/env bash
# Simple launcher for VAPT tool
PROJECT_DIR="$HOME/vapt-tool"
VENV="$PROJECT_DIR/.venv"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: $PROJECT_DIR not found. Clone your project into $PROJECT_DIR first."
  exit 2
fi

if [ -f "$VENV/bin/activate" ]; then
  # shellcheck source=/dev/null
  source "$VENV/bin/activate"
fi

# If the known menu exists, run it. Otherwise run vapt_check
if [ -x "$PROJECT_DIR/scripts/menu.sh" ]; then
  bash "$PROJECT_DIR/scripts/menu.sh"
elif [ -x "$PROJECT_DIR/vapt_check.sh" ]; then
  bash "$PROJECT_DIR/vapt_check.sh"
else
  echo "No menu found. Use $PROJECT_DIR/run_demo.sh or open the project."
  ls -la "$PROJECT_DIR"
fi
VAPT_SH

chmod +x "$LAUNCHER"

# Put ~/bin into PATH for future shells if not already
if ! grep -q 'export PATH="$HOME/bin' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
  echo "Added ~/bin to PATH in ~/.profile. Run: source ~/.profile or re-login to apply."
fi

# 6) Copy a helpful README add-on into project
echo "[5/6] Writing quick README addition..."
cat > "$PROJECT_DIR/README_ADD_INSTALL.md" <<'README'
# Quick start (installer created by install_vapt_tool.sh)

1. Activate venv:
   source .venv/bin/activate

2. Launch the VAPT tool with:
   vapt

3. Run a demo scan against a lab host:
   ./run_demo.sh <lab-ip>

Notes:
- If launcher 'vapt' is not found after install, run:
  source ~/.profile
  or log out and log in.
- To run GVM or Metasploit startup scripts use:
  ./start_gvm.sh
  ./start_msf.sh
README

# 7) Final validation quick checks
echo "[6/6] Quick validation checks..."
echo "Checking: python, venv, vapt launcher, core tools..."
python --version || true
if [ -f "$VENV/bin/activate" ]; then
  echo "Venv present: $VENV"
else
  echo "Venv missing: $VENV"
fi
if command -v "$LOCAL_BIN/vapt" >/dev/null 2>&1; then
  echo "Launcher present: $LOCAL_BIN/vapt"
else
  echo "Launcher missing at $LOCAL_BIN/vapt"
fi

echo
echo "=== Installer finished ==="
echo "Project dir: $PROJECT_DIR"
echo "Activate & launch:"
echo "  cd $PROJECT_DIR"
echo "  source .venv/bin/activate"
echo "  vapt"
echo
echo "If some system packages were not available, please check apt output above and your Kali mirrors."
