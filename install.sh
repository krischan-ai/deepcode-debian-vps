#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f /etc/os-release ]]; then echo "Cannot detect operating system" >&2; exit 1; fi
. /etc/os-release
if [[ "${ID:-}" != "debian" || ! " ${VERSION_ID:-} " =~ " (12|13) " ]]; then
  echo "Only Debian 12/13 is supported (got ${PRETTY_NAME:-unknown})." >&2
  exit 1
fi
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root (su - or sudo bash install.sh)." >&2
  exit 1
fi

MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
NODE_MIRROR="https://npmmirror.com/mirrors/node"
NPM_REGISTRY="https://registry.npmmirror.com"
export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Backing up and switching Debian APT mirrors..."
python3 - <<'PY' || {
import pathlib, re, shutil, datetime
root = pathlib.Path("/etc/apt")
paths = [root / "sources.list", *sorted((root / "sources.list.d").glob("*.sources")), *sorted((root / "sources.list.d").glob("*.list"))]
stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
changes = 0
for path in paths:
    if not path.is_file():
        continue
    old = path.read_text()
    new = old
    new = re.sub(r"https?://(?:deb|ftp|security).debian.org/debian-security/?", "https://mirrors.tuna.tsinghua.edu.cn/debian-security/", new)
    new = re.sub(r"https?://(?:deb|ftp).debian.org/debian/?", "https://mirrors.tuna.tsinghua.edu.cn/debian/", new)
    if new != old:
        shutil.copy2(path, str(path) + ".backup-" + stamp)
        path.write_text(new)
        changes += 1
print("Updated APT source files:", changes)
PY
  echo "Mirror switch failed; check whether python3 is installed." >&2
  exit 1
}
# Fresh Debian images normally include python3? Not guaranteed: shell needs to bootstrap!
apt-get update
apt-get install -y ca-certificates curl git xz-utils python3 nano build-essential

echo "[2/5] Downloading latest Node.js 22.x from China mirror..."
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) NODE_ARCH=x64 ;;
  arm64) NODE_ARCH=arm64 ;;
  armhf) NODE_ARCH=armv7l ;;
  *) echo "Unsupported CPU architecture: $ARCH" >&2; exit 1 ;;
esac
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl --fail --location --retry 3 --connect-timeout 15 # Save current APT source configuration, then update Debian-only repository URLs.
BACKUP_DIR="/root/apt-sources-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a /etc/apt/sources.list "$BACKUP_DIR/" 2>/dev/null || true
cp -a /etc/apt/sources.list.d "$BACKUP_DIR/" 2>/dev/null || true
while IFS= read -r -d '' src; do
  sed -i -E \
    -e 's#https?://(deb|ftp|security)\.debian\.org/debian-security/?#https://mirrors.tuna.tsinghua.edu.cn/debian-security/#g' \
    -e 's#https?://(deb|ftp)\.debian\.org/debian/?#https://mirrors.tuna.tsinghua.edu.cn/debian/#g' "$src"
done < <(find /etc/apt -maxdepth 2 -type f \( -name 'sources.list' -o -name '*.sources' -o -name '*.list' \) -print0)
apt-get update
apt-get install -y ca-certificates curl git xz-utils python3 nano build-essential
  "$NODE_MIRROR/latest-v22.x/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
TARBALL="$(awk -v a="linux-$NODE_ARCH.tar.xz" '$2 ~ a "$" { print $2; exit }' "$TMP/SHASUMS256.txt")"
if [[ -z "$TARBALL" ]]; then echo "Node.js archive not found" >&2; exit 1; fi
curl --fail --location --retry 3 --connect-timeout 15 \
  "$NODE_MIRROR/latest-v22.x/$TARBALL" -o "$TMP/$TARBALL"
(cd "$TMP" && grep -F "  $TARBALL" SHASUMS256.txt | sha256sum -c -)
NODE_DIR="${TARBALL%.tar.xz}"
tar -xJf "$TMP/$TARBALL" -C /usr/local --strip-components=1
node --version
npm --version

echo "[3/5] Installing Deep Code via China npm registry..."
npm install -g @vegamo/deepcode-cli --registry="$NPM_REGISTRY"
deepcode --version

echo "[4/5] Writing configuration..."
CONFIG_DIR="$HOME/.deepcode"
install -d -m 700 "$CONFIG_DIR"
if [[ ! -t 0 ]]; then
  echo "Interactive terminal required to enter API Key" >&2
  exit 1
fi
printf "Enter DeepSeek API Key: "
IFS= read -r -s DEEPSEEK_API_KEY
printf "\n"
if [[ -z "$DEEPSEEK_API_KEY" ]]; then echo "API Key cannot be empty" >&2; exit 1; fi
export DEEPSEEK_API_KEY
if [[ -f "$CONFIG_DIR/settings.json" ]]; then
  cp -p "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi
python3 - <<'PY'
import json, os
from pathlib import Path
p = Path.home() / ".deepcode" / "settings.json"
data = {
    "env": {
        "MODEL": "deepseek-flash",
        "BASE_URL": "https://api.deepseek.com",
        "API_KEY": os.environ["DEEPSEEK_API_KEY"]
    },
    "thinkingEnabled": True,
    "reasoningEffort": "max"
}
with p.open("w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
p.chmod(0o600)
PY
unset DEEPSEEK_API_KEY

echo "[5/5] Starting Deep Code..."
mkdir -p "$HOME/workspace"
cd "$HOME/workspace"
exec deepcode
