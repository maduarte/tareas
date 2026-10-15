#!/bin/sh
# Instala el widget: mueve la app a ~/Applications y la registra como LaunchAgent
# (arranca al iniciar sesión y se relanza si se cierra). Desinstalar: ./uninstall.sh
set -e
cd "$(dirname "$0")"
./build.sh
DEST="$HOME/Applications/ToDoi Widget.app"
PLIST="$HOME/Library/LaunchAgents/cl.tareas.widget.plist"
LABEL="cl.tareas.widget"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x ToDoiWidget 2>/dev/null || true
# Versiones anteriores al cambio de nombre (se llamaba "Tareas Widget")
pkill -x TareasWidget 2>/dev/null || true
rm -rf "$DEST" "$HOME/Applications/Tareas Widget.app"
# Mover (no copiar) y quitar el registro de build/: si no, aparece dos veces en Aplicaciones
mv "build/ToDoi Widget.app" "$DEST"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -u "$PWD/build/ToDoi Widget.app" 2>/dev/null || true
"$LSREGISTER" -f "$DEST" 2>/dev/null || true
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/ToDoiWidget</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Instalado. Arranca solo al iniciar sesión."
