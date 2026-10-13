#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f /etc/os-release ]]; then
  echo "Error: cannot determine OS." >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "debian" ]]; then
  echo "Error: Debian only (detected ${ID:-unknown})." >&2
  exit 1
fi
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo bash "$0" "$@"
  fi
  echo "Error: run as root or install sudo." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "[1/5] Installing Debian dependencies..."
apt-get update
apt-get install -y ca-certificates curl wget git gnupg build-essential python3 nano

echo "[2/5] Installing Node.js 22 and npm..."
curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/deepcode-nodesource-setup.sh
bash /tmp/deepcode-nodesource-setup.sh
apt-get install -y nodejs
node --version
npm --version

echo "[3/5] Installing Deep Code CLI..."
npm install -g @vegamo/deepcode-cli
command -v deepcode >/dev/null || { echo "Deep Code command not found" >&2; exit 1; }
deepcode --version

echo "[4/5] Creating Deep Code configuration..."
CONFIG_DIR="$HOME/.deepcode"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
if [[ -f "$CONFIG_DIR/settings.json" ]]; then
  cp -p "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi

if [[ ! -t 0 ]]; then
  echo "Error: run in an interactive terminal to enter your API key." >&2
  exit 1
fi
printf "DeepSeek API Key: "
IFS= read -r -s DEEPSEEK_API_KEY
printf "\n"
if [[ -z "$DEEPSEEK_API_KEY" ]]; then
  echo "Error: API key cannot be empty." >&2
  exit 1
fi
export DEEPSEEK_API_KEY
python3 - <<'PY'
import json
import os
from pathlib import Path

target = Path.home() / ".deepcode" / "settings.json"
config = {
    "env": {
        "MODEL": "deepseek-flash",
        "BASE_URL": "https://api.deepseek.com",
        "API_KEY": os.environ["DEEPSEEK_API_KEY"],
    },
    "thinkingEnabled": True,
    "reasoningEffort": "max",
}
with target.open("w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
target.chmod(0o600)
print("Saved:", target)
PY
unset DEEPSEEK_API_KEY

echo "[5/5] Starting Deep Code in $HOME/workspace..."
mkdir -p "$HOME/workspace"
cd "$HOME/workspace"
exec deepcode
