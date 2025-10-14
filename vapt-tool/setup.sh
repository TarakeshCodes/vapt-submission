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
