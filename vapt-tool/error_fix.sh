# Fix missing tools: jq, apktool, frida, docker-compose
set -euo pipefail

echo "1) Update apt cache"
sudo apt update --allow-releaseinfo-change -y || sudo apt update -y

echo
echo "2) Install jq (apt)"
sudo apt install -y jq || echo "jq apt install failed (will report later)"

echo
echo "3) Install apktool (apt fallback to manual installer)"
if sudo apt install -y apktool >/dev/null 2>&1; then
  echo "apktool installed via apt"
else
  echo "apktool apt not available — installing jar and wrapper"
  # download latest stable apktool (uses official source)
  APK_JAR="/usr/local/bin/apktool.jar"
  sudo wget -q -O "$APK_JAR" "https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool" || true
  # if the above raw script isn't appropriate, fall back to official releases:
  if [ ! -f "$APK_JAR" ]; then
    sudo wget -q -O /tmp/apktool.jar "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.8.2.jar" || true
    sudo mv /tmp/apktool.jar /usr/local/bin/apktool.jar || true
  fi
  # create wrapper
  sudo tee /usr/local/bin/apktool >/dev/null <<'AW'
#!/usr/bin/env bash
java -jar /usr/local/bin/apktool.jar "$@"
AW
  sudo chmod +x /usr/local/bin/apktool
  echo "apktool (jar) installed at /usr/local/bin/apktool"
fi

echo
echo "4) Install frida & frida-tools into project venv (preferred) and system fallback"
PROJECT="$HOME/vapt-tool"
# ensure venv exists
if [ -d "$PROJECT/.venv" ]; then
  # shellcheck source=/dev/null
  source "$PROJECT/.venv/bin/activate"
  pip install --upgrade pip setuptools wheel >/dev/null || true
  pip install frida frida-tools >/dev/null 2>&1 && echo "frida installed in project venv" || echo "frida pip install in venv failed (will try system pip)"
else
  echo "Project venv not found at $PROJECT/.venv — creating temporary venv for frida install"
  python3 -m venv "$PROJECT/.venv"
  # shellcheck source=/dev/null
  source "$PROJECT/.venv/bin/activate"
  pip install --upgrade pip setuptools wheel >/dev/null || true
  pip install frida frida-tools >/dev/null 2>&1 || echo "frida pip install in new venv failed"
fi

# also attempt system-wide install as fallback (so CLI is available outside venv)
if ! command -v frida >/dev/null 2>&1; then
  echo "Attempting system-wide frida install (may need build tools)"
  sudo pip3 install frida frida-tools >/dev/null 2>&1 || echo "system pip install of frida failed; you can still use frida from the venv"
fi

echo
echo "5) Install Docker Compose (try plugin, then apt, then official binary fallback)"
# Try plugin (preferred)
if sudo apt install -y docker-compose-plugin >/dev/null 2>&1; then
  echo "docker-compose-plugin installed"
fi

# Try legacy package
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  if sudo apt install -y docker-compose >/dev/null 2>&1; then
    echo "docker-compose installed (legacy)"
  fi
fi

# Fallback: official standalone binary (if still missing)
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
  echo "Installing official docker-compose standalone binary to /usr/local/bin/docker-compose"
  sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose || \
    sudo curl -fsSL "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose || true
  sudo chmod +x /usr/local/bin/docker-compose || true
fi

echo
echo "6) Verify installed commands (jq, apktool, frida, afl-fuzz, docker compose)"
echo "----------------------------------------------------------------------"
# check compose variants: 'docker compose' or 'docker-compose'
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_STATUS="docker compose ok"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_STATUS="docker-compose ok"
else
  COMPOSE_STATUS="MISSING"
fi

for c in jq apktool frida afl-fuzz docker; do
  if command -v "$c" >/dev/null 2>&1; then
    printf " OK  %-10s -> %s\n" "$c" "$(command -v "$c")"
  else
    printf "MISS %-10s\n" "$c"
  fi
done
printf " COMPOSE   : %s\n" "$COMPOSE_STATUS"

echo
echo "If any items still show MISS, paste the output here. Otherwise you are ready to continue."
