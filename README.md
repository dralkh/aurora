# Aurora

A sleep calculator for KDE Plasma 6 with configurable bedtime and wake-up reminders. The tray popup follows the active Plasma theme, fonts and accent color.

## Use

Choose **Wake at**, **Bed at** or **Sleep now**, adjust the clock handles or time fields, and choose a cycle count. Press **Set alarm** to save bedtime and wake-up reminders using the current calculator choices, without leaving the calculator.

The small **Configure** button opens a dropdown containing the alarm name, separate bedtime and wake-up switches and sounds, advance bedtime notice, volume, snooze, and repeat days. Leave all days off for a one-time alarm at the next wake-up time. Choose **New alarm** or a saved alarm in the dropdown; saved alarms can be loaded, updated, enabled, paused or deleted there. Active reminders have **Snooze** and **Dismiss** controls in both their notification and the dropdown. **Test** checks desktop notification and sound delivery.

A repeating Monday wake-up alarm can have its bedtime reminder on Sunday evening. Bedtimes already passed are skipped. If you confirm during the advance-notice window before bedtime, the bedtime reminder fires immediately. The wake sound repeats for up to five minutes; the notification remains until acknowledged.

Reminders run in an independent user-session service with the popup closed. They require a logged-in session and an awake computer. Aurora does not power on or resume the computer. On resume, overdue alarms up to one hour old are delivered; older occurrences are skipped. Persisted ringing and snoozed reminders recover after service restarts. Old unacknowledged reminders expire from recovery after 24 hours.

Each calculated sleep cycle is estimated as 90 minutes. Sleep times are approximate. Local timezone rules are used for alarm dates; nonexistent daylight-saving wall times shift forward and repeated wall times fire once.

## Install or update

Requires Plasma 6, Python 3 with PySide6 (QtCore, QtDBus and QtMultimedia), `notify-send` from libnotify, `qdbus6`, and systemd user services. Bedtime and wake sounds use the installed Ocean or Freedesktop sound theme.

Run in a terminal inside your Plasma desktop:

```sh
./install.sh
systemctl --user restart plasma-plasmashell.service
```

The installer updates the widget and icon, installs the alarm activation files, enables and starts `aurora-alarms.service`, and enables Aurora in the tray. Restarting the panel loads the current QML; other applications stay open. The alarm service starts with future graphical login sessions and continues across panel restarts.

The standalone `dist/aurora.plasmoid` archive installs the widget through Plasma's widget installer. Use the repository's `install.sh` to install and activate the alarm service as well.

Alarms are stored separately from widget preferences in `${XDG_STATE_HOME:-~/.local/state}/aurora/alarms.json`. Updating the widget preserves saved schedules. Pause or remove schedules through **Alarms**. To stop all reminder delivery, run `systemctl --user disable --now aurora-alarms.service`.

## Validate

```sh
node tests/math.test.cjs
python -m unittest discover -s tests -p 'test_schedule_core.py'
python -m unittest discover -s tests -p 'test_service_logic.py'
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests -o -,txt
./tests/test-native-tray.sh
```

The native tray test requires Qt 6 and Plasma development headers and an installed Aurora package. It builds an actual system tray and checks that its popup opens and closes, including Plasma 6.7's requirement to leave `preferredRepresentation` unset.

For a real D-Bus transport test without notifying your own desktop:

```sh
dbus-run-session -- python tests/test_service_integration.py
```

This uses the real request client and `notify-send` with a simulated notification server. It requires permission to create a private session bus. The scheduling and service logic tests run without a desktop bus and exercise repeat dates, midnight rollover, daylight saving, persistence, snooze, dismiss, failed storage, notification retries and sound state.

Runtime service diagnostics:

```sh
systemctl --user status aurora-alarms.service
journalctl --user -u aurora-alarms.service
```

The package follows the [KDE Plasma widget documentation](https://develop.kde.org/docs/plasma/widget/setup/). Notifications use the [Freedesktop notification protocol](https://specifications.freedesktop.org/notification/latest/protocol.html).

License: MIT.
