#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f /etc/os-release ]]; then echo "Cannot identify OS" >&2; exit 1; fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || ( "${VERSION_ID:-}" != "22.04" && "${VERSION_ID:-}" != "24.04" && "${VERSION_ID:-}" != "26.04" ) ]]; then
  echo "Ubuntu 22.04, 24.04 or 26.04 required." >&2; exit 1
fi
if [[ "$EUID" -ne 0 ]]; then echo "Run as root: sudo bash install.sh" >&2; exit 1; fi

export DEBIAN_FRONTEND=noninteractive
NODE_MIRROR="https://npmmirror.com/mirrors/node"
NPM_REGISTRY="https://registry.npmmirror.com"

echo "[1/5] Ubuntu mirror and base packages"
BACKUP_DIR="/root/apt-sources-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a /etc/apt/sources.list "$BACKUP_DIR/" 2>/dev/null || true
cp -a /etc/apt/sources.list.d "$BACKUP_DIR/" 2>/dev/null || true

# Only Ubuntu distribution mirror URLs are changed. Third-party repos remain intact.
# Try USTC, Aliyun, then Ubuntu official; do not bypass apt signature checks.
set_ubuntu_mirror() {
  local endpoint="$1"
  local source
  while IFS= read -r -d '' source; do
    sed -i -E \
      -e "s#https?://(archive|security)[.]ubuntu[.]com/ubuntu/?#${endpoint}/ubuntu/#g" \
      -e "s#https?://[a-z0-9.-]+[.]archive[.]ubuntu[.]com/ubuntu/?#${endpoint}/ubuntu/#g" \
      -e "s#https?://(mirrors[.]tuna[.]tsinghua[.]edu[.]cn|mirrors[.]ustc[.]edu[.]cn|mirrors[.]aliyun[.]com)/ubuntu/?#${endpoint}/ubuntu/#g" \
      "$source"
  done < <(find /etc/apt -maxdepth 2 -type f \( -name 'sources.list' -o -name '*.sources' -o -name '*.list' \) -print0)
}
APT_READY=false
for mirror in "https://mirrors.ustc.edu.cn" "https://mirrors.aliyun.com" "http://archive.ubuntu.com"; do
  echo "Trying APT mirror: $mirror"
  set_ubuntu_mirror "$mirror"
  if apt-get update; then
    APT_READY=true
    echo "APT mirror ready: $mirror"
    break
  fi
  echo "APT mirror unavailable, trying next candidate..."
done
if [[ "$APT_READY" != "true" ]]; then
  echo "All Ubuntu mirrors failed. Backup: $BACKUP_DIR" >&2
  exit 1
fi
apt-get install -y ca-certificates curl git xz-utils python3 nano build-essential

echo "[2/5] Download and verify Node.js 22"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) NODE_ARCH=x64 ;;
  arm64) NODE_ARCH=arm64 ;;
  armhf) NODE_ARCH=armv7l ;;
  *) echo "Unsupported CPU architecture: $ARCH" >&2; exit 1 ;;
esac
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL --retry 3 --connect-timeout 15 "$NODE_MIRROR/latest-v22.x/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
TARBALL="$(awk -v a="linux-$NODE_ARCH.tar.xz" '$2 ~ a "$" {print $2; exit}' "$TMP/SHASUMS256.txt")"
[[ -n "$TARBALL" ]] || { echo "No Node archive for $NODE_ARCH" >&2; exit 1; }
curl -fL --retry 3 --connect-timeout 15 "$NODE_MIRROR/latest-v22.x/$TARBALL" -o "$TMP/$TARBALL"
(cd "$TMP" && grep -F "  $TARBALL" SHASUMS256.txt | sha256sum -c -)
tar -xJf "$TMP/$TARBALL" -C /usr/local --strip-components=1
node --version
npm --version

echo "[3/5] Install Deep Code via domestic npm registry"
npm install -g @vegamo/deepcode-cli --registry="$NPM_REGISTRY"
deepcode --version

echo "[4/5] Configure DeepSeek Flash"
[[ -t 0 ]] || { echo "An interactive terminal is required for API key input" >&2; exit 1; }
CONFIG_DIR="$HOME/.deepcode"
install -d -m 700 "$CONFIG_DIR"
printf "DeepSeek API Key: "
IFS= read -r -s DEEPSEEK_API_KEY
printf "\n"
[[ -n "$DEEPSEEK_API_KEY" ]] || { echo "Empty API key" >&2; exit 1; }
export DEEPSEEK_API_KEY
if [[ -f "$CONFIG_DIR/settings.json" ]]; then
  cp -p "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi
python3 - <<'PY'
import json, os
from pathlib import Path
p = Path.home() / ".deepcode" / "settings.json"
config = {
    "env": {
        "MODEL": "deepseek-flash",
        "BASE_URL": "https://api.deepseek.com",
        "API_KEY": os.environ["DEEPSEEK_API_KEY"]
    },
    "thinkingEnabled": True,
    "reasoningEffort": "max"
}
with p.open("w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
p.chmod(0o600)
print("Wrote:", p)
PY
unset DEEPSEEK_API_KEY

echo "[5/5] Launch Deep Code"
mkdir -p "$HOME/workspace"
cd "$HOME/workspace"
exec deepcode
