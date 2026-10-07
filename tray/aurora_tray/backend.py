"""QML bridge for calculator preferences, alarms, and reminders."""
from __future__ import annotations

from PySide6.QtCore import Property, QCoreApplication, QObject, QSettings, Signal, Slot

from . import platform_support
from .diary_core import DiaryStore

DEFAULTS = dict(wakeMinutes=360, bedMinutes=1320, latency=14, cycles=5, mode=0, clock24=False)
LIMITS = dict(wakeMinutes=(0, 1439), bedMinutes=(0, 1439), latency=(0, 120), cycles=(1, 6), mode=(0, 2))
BOOL_PREFS = {'clock24'}
TRUTHY = {'1', 'true', 'yes', 'on'}
FALSY = {'0', 'false', 'no', 'off', ''}


def coerce_bool(value, default=False):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return int(value) != 0
    if isinstance(value, str):
        text = value.strip().lower()
        if text in TRUTHY:
            return True
        if text in FALSY:
            return False
    return default


def coerce_int(value, default, low, high):
    if isinstance(value, bool):
        value = int(value)
    try:
        number = int(float(value))
    except (TypeError, ValueError):
        return default
    return max(low, min(high, number))


class Backend(QObject):
    preferencesChanged = Signal()
    alarmsChanged = Signal()
    remindersChanged = Signal()
    statusChanged = Signal()
    reminderStarted = Signal(str)
    loginItemChanged = Signal()

    def __init__(self, engine, parent=None):
        super().__init__(parent)
        self.engine = engine
        self.diary = DiaryStore(engine.store.path.with_name('diary.sqlite3'))
        self.settings = QSettings()
        self._prefs = {}
        for name, default in DEFAULTS.items():
            stored = self.settings.value(f'calculator/{name}', default)
            self._prefs[name] = self._coerce(name, stored)
        self._snapshot = self.engine.snapshot()
        self._active_keys = set(self.engine.active)
        self.engine.changed.connect(self._on_changed)
        self.engine.statusChanged.connect(self.statusChanged)

    def _on_changed(self) -> None:
        self._snapshot = self.engine.snapshot()
        current = set(self.engine.active)
        started = current - self._active_keys
        self._active_keys = current
        self.alarmsChanged.emit()
        self.remindersChanged.emit()
        for key in sorted(started):
            self.reminderStarted.emit(key)

    def _coerce(self, name, value, default=None):
        if default is None:
            default = DEFAULTS[name]
        if name in BOOL_PREFS:
            return coerce_bool(value, default)
        low, high = LIMITS[name]
        return coerce_int(value, default, low, high)

    def _set_pref(self, name, value):
        value = self._coerce(name, value)
        if self._prefs[name] == value:
            return
        self._prefs[name] = value
        self.settings.setValue(f'calculator/{name}', value)
        self.preferencesChanged.emit()

    @staticmethod
    def _error_text(error):
        if isinstance(error, OSError):
            return f'Could not save alarms: {error}'
        return str(error)

    wakeMinutes = Property(int, lambda self: self._prefs['wakeMinutes'],
                           lambda self, value: self._set_pref('wakeMinutes', value),
                           notify=preferencesChanged)
    bedMinutes = Property(int, lambda self: self._prefs['bedMinutes'],
                          lambda self, value: self._set_pref('bedMinutes', value),
                          notify=preferencesChanged)
    latency = Property(int, lambda self: self._prefs['latency'],
                       lambda self, value: self._set_pref('latency', value),
                       notify=preferencesChanged)
    cycles = Property(int, lambda self: self._prefs['cycles'],
                      lambda self, value: self._set_pref('cycles', value),
                      notify=preferencesChanged)
    mode = Property(int, lambda self: self._prefs['mode'],
                    lambda self, value: self._set_pref('mode', value),
                    notify=preferencesChanged)
    clock24 = Property(bool, lambda self: self._prefs['clock24'],
                       lambda self, value: self._set_pref('clock24', value),
                       notify=preferencesChanged)

    schedules = Property('QVariantList', lambda self: self._snapshot['schedules'], notify=alarmsChanged)
    pending = Property('QVariantList', lambda self: self._snapshot['pending'], notify=alarmsChanged)
    reminders = Property('QVariantList', lambda self: self.engine.reminders(), notify=remindersChanged)
    reminderCount = Property(int, lambda self: len(self.engine.active), notify=remindersChanged)
    error = Property(str, lambda self: self.engine.last_error, notify=statusChanged)
    available = Property(bool, lambda self: True, constant=True)

    def _get_login(self) -> bool:
        try:
            return platform_support.is_enabled()
        except OSError:
            return False

    def _set_login(self, enabled: bool) -> None:
        try:
            platform_support.set_enabled(bool(enabled))
        except OSError as error:
            self.engine.set_error(f'Could not change the login item: {error}')
        self.loginItemChanged.emit()

    startAtLogin = Property(bool, _get_login, _set_login, notify=loginItemChanged)

    @Slot('QVariantMap', result='QVariantMap')
    def saveSchedule(self, raw):
        try:
            schedule = self.engine.save(dict(raw))
            return {'ok': True, 'savedId': schedule['id'], 'error': ''}
        except (ValueError, KeyError, TypeError) as error:
            return {'ok': False, 'savedId': '', 'error': str(error)}
        except OSError as error:
            return {'ok': False, 'savedId': '', 'error': f'Could not save alarms: {error}'}

    @Slot(str, result='QVariantMap')
    def removeSchedule(self, schedule_id):
        try:
            self.engine.remove(schedule_id)
            return {'ok': True, 'error': ''}
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'ok': False, 'error': self._error_text(error)}

    @Slot(str, bool, result='QVariantMap')
    def toggleSchedule(self, schedule_id, enabled):
        try:
            self.engine.toggle(schedule_id, enabled)
            return {'ok': True, 'error': ''}
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'ok': False, 'error': self._error_text(error)}

    @Slot(str, result='QVariantMap')
    def dismissReminder(self, key):
        try:
            self.engine.dismiss(str(key))
            return {'ok': True, 'error': ''}
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'ok': False, 'error': self._error_text(error)}

    @Slot(str, result='QVariantMap')
    def snoozeReminder(self, key):
        try:
            self.engine.snooze(str(key))
            return {'ok': True, 'error': ''}
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'ok': False, 'error': self._error_text(error)}

    @Slot(result='QVariantMap')
    def testReminder(self):
        try:
            self.engine.test()
            return {'ok': True, 'error': ''}
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'ok': False, 'error': self._error_text(error)}

    @Slot()
    def quit(self):
        QCoreApplication.quit()

    @Slot('QVariantMap', result='QVariantMap')
    def diaryRequest(self, payload):
        return self.diary.request(dict(payload))
