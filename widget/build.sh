#!/bin/sh
# Compila el widget como "ToDoi Widget.app" (solo Command Line Tools, sin Xcode).
set -e
cd "$(dirname "$0")"
APP="build/ToDoi Widget.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/ToDoiWidget"
# Ícono: AppIcon.png lo genera diseno/logo/fuente/generar.py
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for n in 16 32 128 256 512; do
  sips -z $n $n AppIcon.png --out "$SET/icon_${n}x${n}.png" >/dev/null
  sips -z $((n*2)) $((n*2)) AppIcon.png --out "$SET/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$SET")"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>cl.tareas.widget</string>
  <key>CFBundleName</key><string>ToDoi Widget</string>
  <key>CFBundleDisplayName</key><string>ToDoi Widget</string>
  <key>CFBundleExecutable</key><string>ToDoiWidget</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Listo: widget/$APP"
