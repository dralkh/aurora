import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from qt_app import application

application()

from aurora_tray.backend import Backend
from aurora_tray.engine import AlarmEngine
from PySide6.QtCore import QSettings


class BackendTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.TemporaryDirectory()
        os.environ['AURORA_DATA_DIR'] = cls.root.name
        os.environ['AURORA_CACHE_DIR'] = cls.root.name
        os.environ['AURORA_AUTOSTART_DIR'] = str(Path(cls.root.name) / 'autostart')
        os.environ['AURORA_AUTOSTART_REGPATH'] = r'Software\DralkTest\AuroraTrayBackend'
        QSettings.setDefaultFormat(QSettings.Format.IniFormat)
        QSettings.setPath(QSettings.Format.IniFormat, QSettings.Scope.UserScope, cls.root.name)

    @classmethod
    def tearDownClass(cls):
        if sys.platform == 'win32':
            import winreg
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, os.environ['AURORA_AUTOSTART_REGPATH'])
            except FileNotFoundError:
                pass
        cls.root.cleanup()

    def setUp(self):
        for leftover in Path(self.root.name).rglob('*.ini'):
            leftover.unlink()
        self.clock = datetime(2026, 10, 5, 20, tzinfo=ZoneInfo('Asia/Riyadh'))
        self.temp = tempfile.TemporaryDirectory()
        self.engine = AlarmEngine(Path(self.temp.name) / 'alarms.json', start=False)
        self.engine.now = lambda: self.clock
        self.backend = Backend(self.engine)
        self.value = dict(name='Weeknight', bedMinutes=1320, wakeMinutes=360, wakeDate='2026-10-06', days=[],
                          bedEnabled=True, wakeEnabled=True, bedSound=True, wakeSound=True, bedLead=15,
                          snooze=10, volume=70, enabled=True)

    def tearDown(self):
        self.engine.shutdown()
        self.temp.cleanup()

    def test_defaults_and_persistence(self):
        self.assertEqual(self.backend.wakeMinutes, 360)
        self.assertEqual(self.backend.cycles, 5)
        self.assertFalse(self.backend.clock24)
        self.backend.mode = 1
        self.backend.cycles = 99
        self.backend.clock24 = True
        self.backend.latency = 22
        self.backend.wakeMinutes = 100
        self.backend.bedMinutes = 1439
        self.assertEqual(self.backend.cycles, 6)
        fresh = Backend(self.engine)
        self.assertEqual(fresh.mode, 1)
        self.assertEqual(fresh.cycles, 6)
        self.assertTrue(fresh.clock24)
        self.assertEqual(fresh.latency, 22)
        self.assertEqual(fresh.wakeMinutes, 100)
        self.assertEqual(fresh.bedMinutes, 1439)

    def test_bool_string_persistence(self):
        self.backend.settings.setValue('calculator/clock24', 'true')
        self.assertTrue(Backend(self.engine).clock24)
        self.backend.settings.setValue('calculator/clock24', 'false')
        self.assertFalse(Backend(self.engine).clock24)

    def test_invalid_stored_values_fall_back(self):
        self.backend.settings.setValue('calculator/mode', 'wrong')
        self.backend.settings.setValue('calculator/cycles', None)
        fresh = Backend(self.engine)
        self.assertEqual(fresh.mode, 0)
        self.assertEqual(fresh.cycles, 5)

    def test_save_remove_toggle(self):
        changes = []
        self.backend.alarmsChanged.connect(lambda: changes.append(1))
        response = self.backend.saveSchedule(self.value)
        self.assertTrue(response['ok'])
        self.assertEqual(len(self.backend.schedules), 1)
        self.assertTrue(changes)
        schedule_id = response['savedId']
        self.backend.toggleSchedule(schedule_id, False)
        self.assertFalse(self.backend.schedules[0]['enabled'])
        self.backend.removeSchedule(schedule_id)
        self.assertFalse(self.backend.schedules)

    def test_invalid_save_reports_error(self):
        response = self.backend.saveSchedule(dict(self.value, volume=101))
        self.assertFalse(response['ok'])
        self.assertIn('volume', response['error'])
        self.assertFalse(self.backend.schedules)

    def test_storage_failure_reports_error(self):
        with patch.object(self.engine.store, 'save', side_effect=OSError('disk full')):
            response = self.backend.saveSchedule(self.value)
        self.assertFalse(response['ok'])
        self.assertIn('disk full', response['error'])

    def test_dismiss_storage_failure_keeps_ringing(self):
        self.backend.saveSchedule(self.value)
        self.clock = self.clock.replace(hour=21, minute=45)
        self.engine.tick()
        key = next(iter(self.engine.active))
        with patch.object(self.engine.store, 'save', side_effect=OSError('disk full')):
            response = self.backend.dismissReminder(key)
        self.assertFalse(response['ok'])
        self.assertIn('disk full', response['error'])
        self.assertIn(key, self.engine.active)

    def test_snooze_storage_failure_redelivers(self):
        self.backend.saveSchedule(self.value)
        self.clock = self.clock.replace(hour=21, minute=45)
        self.engine.tick()
        key = next(iter(self.engine.active))
        with patch.object(self.engine.store, 'save', side_effect=OSError('disk full')):
            response = self.backend.snoozeReminder(key)
        self.assertFalse(response['ok'])
        self.assertNotIn(key, self.engine.active)
        self.assertFalse(self.engine.store.data['pending'][key].get('snoozed'))
        self.engine.tick()
        self.assertIn(key, self.engine.active)

    def test_remove_and_toggle_storage_failure(self):
        saved_id = self.backend.saveSchedule(self.value)['savedId']
        with patch.object(self.engine.store, 'save', side_effect=OSError('disk full')):
            removed = self.backend.removeSchedule(saved_id)
            toggled = self.backend.toggleSchedule(saved_id, False)
        self.assertFalse(removed['ok'])
        self.assertFalse(toggled['ok'])
        self.assertEqual(len(self.backend.schedules), 1)

    def test_login_failure_surfaces(self):
        with patch('aurora_tray.backend.platform_support.set_enabled', side_effect=OSError('denied')):
            self.backend.startAtLogin = True
        self.assertFalse(self.backend.startAtLogin)
        self.assertIn('denied', self.backend.error)

    def test_reminder_signals(self):
        started = []
        self.backend.reminderStarted.connect(started.append)
        self.backend.saveSchedule(self.value)
        self.engine.test()
        self.assertEqual(self.backend.reminderCount, 1)
        self.assertEqual(started, ['test'])
        self.assertEqual(self.backend.reminders[0]['kind'], 'bed')
        self.backend.dismissReminder('test')
        self.assertEqual(self.backend.reminderCount, 0)

    def test_snooze_via_backend(self):
        self.backend.saveSchedule(self.value)
        self.clock = self.clock.replace(hour=21, minute=45)
        self.engine.tick()
        key = next(iter(self.engine.active))
        self.backend.snoozeReminder(key)
        self.assertEqual(self.backend.reminderCount, 0)
        self.assertTrue(self.backend.pending[0]['snoozed'])

    def test_start_at_login_round_trip(self):
        self.assertFalse(self.backend.startAtLogin)
        self.backend.startAtLogin = True
        self.assertTrue(self.backend.startAtLogin)
        if sys.platform != 'win32':
            self.assertTrue(any(Path(os.environ['AURORA_AUTOSTART_DIR']).iterdir()))
        self.backend.startAtLogin = False
        self.assertFalse(self.backend.startAtLogin)
        if sys.platform != 'win32':
            self.assertFalse(any(Path(os.environ['AURORA_AUTOSTART_DIR']).iterdir()))


if __name__ == '__main__':
    unittest.main()
