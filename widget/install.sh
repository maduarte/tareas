#!/bin/sh
# Instala el widget: copia la app a ~/Applications y la registra como LaunchAgent
# (arranca al iniciar sesión y se relanza si se cierra). Desinstalar: ./uninstall.sh
set -e
cd "$(dirname "$0")"
[ -d "build/Tareas Widget.app" ] || ./build.sh
DEST="$HOME/Applications/Tareas Widget.app"
PLIST="$HOME/Library/LaunchAgents/cl.tareas.widget.plist"
LABEL="cl.tareas.widget"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x TareasWidget 2>/dev/null || true
rm -rf "$DEST"
cp -R "build/Tareas Widget.app" "$DEST"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/TareasWidget</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Instalado. Arranca solo al iniciar sesión."
