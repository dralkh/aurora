#!/usr/bin/env python3
"""Write user-owned activation files; install.sh starts the service."""
import os
from pathlib import Path

home = Path.home()
data = Path(os.environ.get('XDG_DATA_HOME', str(home / '.local/share')))
config = Path(os.environ.get('XDG_CONFIG_HOME', str(home / '.config')))
helper = data / 'plasma/plasmoids/org.dralk.aurorasleep/contents/code/aurora_service.py'

def quote(value, systemd=False):
    value = str(value).replace('\\', '\\\\').replace('"', '\\"')
    if '\n' in value or '\r' in value:
        raise ValueError('Unsupported newline in installation path.')
    if systemd:
        value = value.replace('%', '%%')
    return '"' + value + '"'

unit = config / 'systemd/user/aurora-alarms.service'
unit.parent.mkdir(parents=True, exist_ok=True)
unit.write_text('''[Unit]
Description=Aurora bedtime and wake-up reminders
PartOf=graphical-session.target
After=graphical-session-pre.target

[Service]
Type=dbus
BusName=org.dralk.Aurora
ExecStart=/usr/bin/python3 ''' + quote(helper, True) + '''
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
''')
activation = data / 'dbus-1/services/org.dralk.Aurora.service'
activation.parent.mkdir(parents=True, exist_ok=True)
activation.write_text('[D-BUS Service]\nName=org.dralk.Aurora\nExec=/usr/bin/python3 ' + quote(helper) + '\nSystemdService=aurora-alarms.service\n')
desktop = data / 'applications/org.dralk.Aurora.desktop'
desktop.parent.mkdir(parents=True, exist_ok=True)
desktop.write_text('[Desktop Entry]\nType=Application\nName=Aurora\nComment=Bedtime and wake-up reminders\nIcon=aurora\nNoDisplay=true\nExec=/usr/bin/python3 ' + quote(helper) + '\n')
print('Installed Aurora alarm service and user-session activation files.')
