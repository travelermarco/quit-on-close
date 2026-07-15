#!/usr/bin/env bash
# Installs QuitOnClose.app into /Applications and registers a LaunchAgent
# so it starts automatically, silently, at every login.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="QuitOnClose"
SRC_APP="dist/${APP_NAME}.app"
DEST_APP="/Applications/${APP_NAME}.app"
PLIST_LABEL="com.travelermarco.quitonclose"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

if [ ! -d "$SRC_APP" ]; then
    echo "Bundle non trovato: esegui prima ./Scripts/build.sh" >&2
    exit 1
fi

echo "==> Installo in /Applications"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

echo "==> Scrivo il LaunchAgent"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"
cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${DEST_APP}/Contents/MacOS/${APP_NAME}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/${APP_NAME}.out.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/${APP_NAME}.err.log</string>
</dict>
</plist>
PLIST

echo "==> Carico il LaunchAgent"
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT"

cat <<MSG

Installazione completata.

IMPORTANTE - permesso di Accessibilita':
al primo avvio macOS potrebbe mostrare (o richiedere manualmente) il permesso
in Impostazioni di Sistema > Privacy e Sicurezza > Accessibilita'.
Attiva "${APP_NAME}" nell'elenco. Senza questo permesso l'app resta inattiva
e non chiude nulla.

Se il prompt di sistema non compare da solo, aprilo tu con:
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

${APP_NAME} si avvia automaticamente ad ogni login, senza icona nel Dock
ne' nella barra dei menu: non cambia nulla a livello di interfaccia.

Log: ~/Library/Logs/${APP_NAME}.log
Esclusioni:  ~/Library/Application Support/${APP_NAME}/excluded-bundle-ids.txt
MSG
