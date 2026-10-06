# Aurora tray app

Aurora as a standalone, self-contained tray application for macOS (menu bar) and Windows (notification area). Closing the popup leaves the scheduler running, reminders appear in their own always-on-top window with **Snooze** and **Dismiss**, and on macOS the app is an agent (`LSUIElement`), so there is no dock icon.

It is the same calculator and alarm model as the Plasma widget: 90-minute cycles, wake/bed/sleep-now modes, configurable advance bedtime notice, repeat days, sounds, volume and snooze. Alarms are scheduled locally from `schedule_core.py`; a reminder window plus an optional native tray notification are shown when one is due. Wake sounds repeat for up to five minutes, overdue alarms up to one hour old are delivered after sleep or restart, and persisted reminders recover after a restart. Linux runs are supported for development and testing only; Linux users keep the Plasma widget.

## Run from source

Requires Python 3.10+ and either a system or virtualenv PySide6.

```sh
python3 -m venv .venv
.venv/bin/pip install -e "tray/"
.venv/bin/aurora-tray          # or: .venv/bin/python tray/run.py
```

On Windows use `.venv\Scripts\aurora-tray.exe`. `python tray/run.py --self-test` loads the interface with the offscreen platform, verifies the bundled timezone data and an alarm save/load plus reminder delivery, and exits. `--debug` also prints logs to the console.

## Behaviour

- **Tray menu** (right-click): Open Aurora, Configure alarms…, Test reminder, Start at login, Quit. Left-click toggles the popup.
- **Configure** opens inside the popup: alarm name, saved alarms, bedtime/wake-up switches and sounds, advance notice, snooze, volume, repeat days, enable/pause, Test, pending reminders, start at login and Quit. **Esc** closes settings first, then the popup.
- **Start at login** uses a `LaunchAgent` on macOS, the `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value on Windows and `~/.config/autostart` on Linux.
- **Sounds** are generated chimes written atomically to the cache directory on first use, so no system sound theme is required.
- **Single instance**: launching Aurora twice just opens the running popup.
- Alarms are stored in the platform application-data directory (`~/Library/Application Support/...` on macOS, `%LOCALAPPDATA%\Dralk\Aurora\alarms.json` on Windows, `~/.local/share/Dralk/Aurora` on Linux). Calculator preferences are kept in `QSettings`. This is separate from the Plasma widget's `alarms.json`.
- Diagnostics are written to `aurora.log` (rotated, 256 KB × 3) in the same data directory.

## Build installers

The version comes from `aurora_tray/__init__.py`; all packaging metadata reads it. PyInstaller produces `dist/Aurora` (onedir) via the spec:

```sh
pip install -e "tray[build]"
cd tray
python packaging/make_icons.py
pyinstaller --noconfirm --clean packaging/Aurora.spec
```

- macOS: run `iconutil -c icns packaging/build/aurora.iconset -o packaging/aurora.icns` before building. The app bundle targets Apple Silicon; build on an Intel Mac for an Intel binary. The DMG includes an `/Applications` symlink for drag-install.
- Windows: `make_icons.py` writes `packaging/aurora.ico`. Compile `packaging/aurora.iss` with Inno Setup to produce `Aurora-Setup-<version>.exe`; the CI passes the version with `/DAppVersion=…`.

The GitHub Actions workflow (`.github/workflows/tray.yml`) tests on Linux, Windows and macOS, builds the DMG and Windows installer, verifies that timezone data is bundled, smoke-tests the frozen bundles and attaches the DMG, installer and `aurora.plasmoid` to a `v*` tag release.

Builds are **unsigned**: on macOS use right-click → Open (or `xattr -dr com.apple.quarantine /Applications/Aurora.app`) and on Windows choose More info → Run anyway in SmartScreen. Reminder windows may not appear above fullscreen macOS Spaces; the tray notification and icon still signal the alarm.

## Uninstall

Quit Aurora first. On macOS drag the app to the Trash and delete `~/Library/LaunchAgents/org.dralk.aurora.tray.plist` if start-at-login was enabled; on Windows run the uninstaller (it calls `Aurora.exe --uninstall-autostart`). Saved alarms and preferences live in the data directory above and can be deleted separately. `--uninstall-autostart` works on any platform.

## Tests

```sh
cd tray
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software python -m unittest discover -s tests -v
```

The suite covers the alarm engine (delivery, snooze, dismiss, pause/delete, catch-up, recovery, error clearing), the QML backend and preference persistence, login items, the vendored `schedule_core.py` staying identical to the Plasma widget's copy, and QML tests that load the full interface, fail on any QML warning and exercise the calculator save/update/load flow.
