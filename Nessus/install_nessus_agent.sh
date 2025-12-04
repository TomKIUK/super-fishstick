
#!/bin/bash
# Intune macOS install script for Nessus Agent via GitHub-hosted PKG
# - Downloads PKG from GitHub (raw URL)
# - Installs PKG
# - Waits for agent binary
# - Links to Tenable.io cloud (or on‑prem by changing flags)
# - Logs to /tmp/nessus_install.log

set -euo pipefail
exec > /tmp/nessus_install.log 2>&1

PKG_URL="https://raw.githubusercontent.com/metisdevelopment/super-fishstick/Atlas/Nessus/Install%20Nessus%20Agent.pkg"
PKG_PATH="/tmp/NessusAgent.pkg"
NESSUSCLI="/Library/NessusAgent/run/sbin/nessuscli"

# ===== Download PKG =====
echo "[INFO] Downloading PKG from GitHub: $PKG_URL"
# -L follows redirects; --fail ensures non-200 exits with error
curl -L --fail -o "$PKG_PATH" "$PKG_URL"
echo "[INFO] Download complete: $PKG_PATH"

# Optional: verify file presence and size
if [ ! -s "$PKG_PATH" ]; then
  echo "[ERROR] Downloaded PKG is missing or empty."
  exit 1
fi

# ===== Install PKG =====
echo "[INFO] Installing PKG..."
installer -pkg "$PKG_PATH" -target / || {
  echo "[ERROR] installer command failed."
  exit 1
}

# ===== Wait for agent binary to exist =====
echo "[INFO] Waiting for nessuscli to appear..."
for i in {1..24}; do  # up to ~2 minutes
  if [ -x "$NESSUSCLI" ]; then
    echo "[INFO] Found nessuscli at $NESSUSCLI"
    break
  fi
  echo "[WARN] Not found yet (attempt $i), retrying in 5s..."
  sleep 5
done

if [ ! -x "$NESSUSCLI" ]; then
  echo "[ERROR] Nessus Agent CLI not found after waiting."
  exit 1
fi

# ===== Link agent (choose ONE of the two blocks) =====

# --- Tenable.io (cloud) ---
AGENT_KEY="29d29c259c9405d76b0560cdbbe6d5856250f87256dac2b469f00a64d1e9876e"
echo "[INFO] Linking agent to Tenable.io cloud..."
"$NESSUSCLI" agent link --key="$AGENT_KEY" --cloud || {
  echo "[ERROR] Agent link to cloud failed."
  exit 1
}

# # --- Nessus Manager (on‑prem) ---
# AGENT_KEY="REPLACE_WITH_YOUR_AGENT_KEY"
# MANAGER_HOST="your.manager.address"
# MANAGER_PORT="8834"
# echo "[INFO] Linking agent to Manager $MANAGER_HOST:$MANAGER_PORT..."
# "$NESSUSCLI" agent link --key="$AGENT_KEY" --host="$MANAGER_HOST" --port="$MANAGER_PORT" || {
#   echo "[ERROR] Agent link to Manager failed."
#   exit 1
# }

# ===== Status (non-blocking) =====
echo "[INFO] Agent status:"
"$NESSUSCLI" agent status || true

echo "[SUCCESS] Nessus Agent install + link completed."
exit 0
