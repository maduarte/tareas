#!/bin/sh
# Compila el widget como "Tareas Widget.app" (solo Command Line Tools, sin Xcode).
set -e
cd "$(dirname "$0")"
APP="build/Tareas Widget.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/TareasWidget"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>cl.tareas.widget</string>
  <key>CFBundleName</key><string>Tareas Widget</string>
  <key>CFBundleExecutable</key><string>TareasWidget</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Listo: widget/$APP"
