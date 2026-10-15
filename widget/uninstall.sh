#!/bin/sh
# Quita el LaunchAgent y la app instalada.
LABEL="cl.tareas.widget"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x ToDoiWidget 2>/dev/null || true
pkill -x TareasWidget 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/ToDoi Widget.app" "$HOME/Applications/Tareas Widget.app"
echo "Desinstalado."
