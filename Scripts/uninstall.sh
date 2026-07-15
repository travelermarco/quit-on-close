#!/usr/bin/env bash
# Removes QuitOnClose completely: LaunchAgent, app bundle and logs.
set -euo pipefail

APP_NAME="QuitOnClose"
PLIST_LABEL="com.travelermarco.quitonclose"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
DEST_APP="/Applications/${APP_NAME}.app"

echo "==> Scarico il LaunchAgent"
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
rm -f "$LAUNCH_AGENT"

echo "==> Rimuovo l'app"
rm -rf "$DEST_APP"

echo "==> Fatto."
echo "Puoi anche rimuovere ${APP_NAME} da Impostazioni di Sistema > Privacy e Sicurezza > Accessibilita'."
echo "La configurazione resta in ~/Library/Application Support/${APP_NAME} (cancellala manualmente se non ti serve piu')."
