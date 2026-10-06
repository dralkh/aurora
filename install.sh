#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
/usr/bin/python3 -c "from PySide6 import QtCore, QtDBus, QtMultimedia"
command -v notify-send >/dev/null
package_id=org.dralk.aurorasleep
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
icon_dir="$data_dir/icons/hicolor/256x256/apps"
mkdir -p -- "$icon_dir"
cp -- "$project_dir/package/contents/icons/aurora.png" "$icon_dir/aurora.png"
svg_icon_dir="$data_dir/icons/hicolor/scalable/apps"
mkdir -p -- "$svg_icon_dir"
cp -- "$project_dir/package/contents/icons/aurora.svg" "$svg_icon_dir/aurora.svg"
if [[ -d "$data_dir/plasma/plasmoids/$package_id" ]]; then
    kpackagetool6 --type Plasma/Applet --upgrade "$project_dir/package"
else
    kpackagetool6 --type Plasma/Applet --install "$project_dir/package"
fi
/usr/bin/python3 "$project_dir/install-alarm-service.py"
systemctl --user daemon-reload
systemctl --user enable --now aurora-alarms.service
systemctl --user restart aurora-alarms.service
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat -- "$project_dir/enable-tray.js")"
