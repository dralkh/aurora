"""Platform paths, local timezone, and login-item management."""
from __future__ import annotations

import os
import plistlib
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QStandardPaths

APP_NAME = 'Aurora'
ORG_NAME = 'Dralk'
APP_ID = 'org.dralk.aurora'
AUTOSTART_LABEL = 'org.dralk.aurora.tray'


def data_path(name: str) -> Path:
    override = os.environ.get('AURORA_DATA_DIR')
    base = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppLocalDataLocation)
    root = Path(override) if override else (Path(base) if base else Path.home() / '.aurora')
    root.mkdir(parents=True, exist_ok=True)
    return root / name


def cache_dir() -> Path:
    override = os.environ.get('AURORA_CACHE_DIR')
    base = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.CacheLocation)
    root = Path(override) if override else (Path(base) if base else Path.home() / '.cache/aurora')
    root.mkdir(parents=True, exist_ok=True)
    return root


def local_zone():
    if os.environ.get('TZ'):
        try:
            from zoneinfo import ZoneInfo
            return ZoneInfo(os.environ['TZ'])
        except (KeyError, ValueError):
            pass
    try:
        from tzlocal import get_localzone
        zone = get_localzone()
        if zone is not None:
            return zone
    except Exception:
        pass
    return datetime.now().astimezone().tzinfo


def _override() -> Path | None:
    value = os.environ.get('AURORA_AUTOSTART_DIR')
    return Path(value) if value else None


def _launch_command() -> list[str]:
    if getattr(sys, 'frozen', False):
        return [sys.executable]
    runner = Path(__file__).resolve().parents[1] / 'run.py'
    python = sys.executable
    if sys.platform == 'win32':
        windowless = Path(python).with_name('pythonw.exe')
        if windowless.exists():
            python = str(windowless)
    return [python, str(runner)]


def _command_line() -> str:
    if sys.platform == 'win32':
        return subprocess.list2cmdline(_launch_command())
    return ' '.join(shlex.quote(part) for part in _launch_command())


def _mac_plist_path() -> Path:
    root = _override() or Path.home() / 'Library/LaunchAgents'
    return root / f'{AUTOSTART_LABEL}.plist'


def _linux_desktop_path() -> Path:
    if _override():
        return _override() / 'aurora-tray.desktop'
    root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'autostart'
    return root / 'aurora-tray.desktop'


def _windows_registry_path() -> str:
    return os.environ.get('AURORA_AUTOSTART_REGPATH', r'Software\Microsoft\Windows\CurrentVersion\Run')


def _windows_value():
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _windows_registry_path(), 0, winreg.KEY_QUERY_VALUE) as key:
            return winreg.QueryValueEx(key, APP_NAME)[0]
    except FileNotFoundError:
        return None


def _set_windows_value(value) -> None:
    import winreg
    with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, _windows_registry_path(), 0, winreg.KEY_SET_VALUE) as key:
        if value is None:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except FileNotFoundError:
                pass
        else:
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, value)


def is_enabled() -> bool:
    if sys.platform == 'darwin':
        return _mac_plist_path().exists()
    if sys.platform == 'win32':
        return _windows_value() == _command_line()
    return _linux_desktop_path().exists()


def set_enabled(enabled: bool) -> None:
    if sys.platform == 'darwin':
        path = _mac_plist_path()
        if enabled:
            path.parent.mkdir(parents=True, exist_ok=True)
            payload = dict(Label=AUTOSTART_LABEL, ProgramArguments=_launch_command(),
                           RunAtLoad=True, ProcessType='Interactive')
            path.write_bytes(plistlib.dumps(payload))
            if not _override():
                _launchctl('load', path)
        else:
            if path.exists():
                if not _override():
                    _launchctl('unload', path)
                path.unlink()
        return
    if sys.platform == 'win32':
        _set_windows_value(_command_line() if enabled else None)
        return
    path = _linux_desktop_path()
    if enabled:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('[Desktop Entry]\n'
                        'Type=Application\n'
                        'Name=Aurora\n'
                        'Comment=Sleep schedule reminders\n'
                        f'Exec={_command_line()}\n'
                        'Terminal=false\n'
                        'X-GNOME-Autostart-enabled=true\n', encoding='utf-8')
    elif path.exists():
        path.unlink()


def _launchctl(action: str, path: Path) -> None:
    try:
        subprocess.run(['launchctl', action, str(path)], capture_output=True, check=False)
    except OSError:
        pass


def resource(*parts: str) -> Path:
    return Path(__file__).resolve().parent.joinpath(*parts)
