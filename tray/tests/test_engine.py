import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from qt_app import application

application()

from aurora_tray.engine import AlarmEngine
from aurora_tray.schedule_core import Store
from PySide6.QtCore import QObject, Signal


class FakePlayer(QObject):
    failed = Signal(str)

    def __init__(self, event, duration, parent=None):
        super().__init__(parent)
        self.event = event
        self.duration = duration
        self.stopped = False

    def stop(self):
        self.stopped = True


class Engine(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.clock = datetime(2026, 10, 5, 20, tzinfo=ZoneInfo('Asia/Riyadh'))
        self.players = []
        self.engine = AlarmEngine(Path(self.temp.name) / 'alarms.json', sound_factory=self.factory, start=False)
        self.engine.now = lambda: self.clock
        self.value = dict(name='Weeknight', bedMinutes=1320, wakeMinutes=360, wakeDate='2026-10-06', days=[],
                          bedEnabled=True, wakeEnabled=True, bedSound=True, wakeSound=True, bedLead=15,
                          snooze=10, volume=70, enabled=True)
        self.saved = self.engine.save(self.value)

    def tearDown(self):
        self.engine.shutdown()
        self.temp.cleanup()

    def factory(self, event, duration):
        player = FakePlayer(event, duration)
        self.players.append(player)
        return player

    def ring_bed(self):
        self.clock = self.clock.replace(hour=21, minute=45)
        self.engine.tick()
        key = next(iter(self.engine.active))
        return key, self.engine.active[key]

    def test_paired_reminders_and_sound(self):
        key, record = self.ring_bed()
        self.assertEqual(record['event']['kind'], 'bed')
        self.assertEqual(record['event']['volume'], 70)
        self.assertIsNotNone(record['player'])
        self.assertAlmostEqual(record['player'].duration, 300, delta=2)
        self.engine.dismiss(key)
        self.clock = self.clock.replace(day=6, hour=6, minute=0)
        self.engine.tick()
        wake = next(iter(self.engine.active.values()))
        self.assertEqual(wake['event']['kind'], 'wake')
        self.assertFalse(wake['player'].stopped)

    def test_silent_reminder_has_no_player(self):
        self.engine.remove(self.saved['id'])
        self.engine.save(dict(self.value, bedSound=False))
        key, record = self.ring_bed()
        self.assertIsNone(record['player'])

    def test_snooze_stops_audio_and_rearms(self):
        key, record = self.ring_bed()
        self.engine.snooze(key)
        self.assertFalse(self.engine.active)
        self.assertTrue(self.engine.store.data['pending'][key]['snoozed'])
        self.assertTrue(record['player'].stopped)
        self.clock += timedelta(minutes=10)
        self.engine.tick()
        self.assertIn(key, self.engine.active)
        self.assertGreater(self.engine.active[key]['event']['soundUntil'], self.clock.timestamp())

    def test_dismiss_clears_pending_and_stops(self):
        key, record = self.ring_bed()
        self.engine.dismiss(key)
        self.assertFalse(self.engine.active)
        self.assertFalse(self.engine.store.data['pending'])
        self.assertTrue(record['player'].stopped)

    def test_pause_and_delete_stop_ringing(self):
        key, record = self.ring_bed()
        self.engine.toggle(self.saved['id'], False)
        self.assertFalse(self.engine.active)
        self.assertTrue(record['player'].stopped)
        self.engine.remove(self.saved['id'])
        self.assertFalse(self.engine.store.data['schedules'])

    def test_invalid_save_keeps_ringing(self):
        key, record = self.ring_bed()
        with self.assertRaises(ValueError):
            self.engine.save(dict(self.value, volume=101))
        self.assertIn(key, self.engine.active)
        self.assertFalse(record['player'].stopped)

    def test_delivered_once(self):
        key, _ = self.ring_bed()
        self.engine.dismiss(key)
        self.engine.tick()
        self.assertFalse(self.engine.active)

    def test_retry_pending_without_active(self):
        key, _ = self.ring_bed()
        self.engine.active.clear()
        self.engine.tick()
        self.assertIn(key, self.engine.active)

    def test_restore_recent_pending_and_skip_stale(self):
        key, _ = self.ring_bed()
        self.engine.shutdown()
        clock = self.clock.replace(day=6, hour=2, minute=0)
        restored = AlarmEngine(Path(self.temp.name) / 'alarms.json', sound_factory=self.factory, start=False)
        restored.now = lambda: clock
        restored.restore_pending()
        self.assertIn(key, restored.active)
        restored.shutdown()

        store = Store(Path(self.temp.name) / 'alarms.json')
        event = store.data['pending'][key]
        event['due'] -= 25 * 3600
        event['soundUntil'] = event['due'] + 300
        store.save()
        later = clock + timedelta(hours=25)
        stale = AlarmEngine(Path(self.temp.name) / 'alarms.json', sound_factory=self.factory, start=False)
        stale.now = lambda: later
        stale.restore_pending()
        self.assertFalse(stale.active)
        self.assertFalse(stale.store.data['pending'])
        stale.shutdown()

    def test_audio_failure_sets_and_clears_error(self):
        key, record = self.ring_bed()
        record['player'].failed.emit('No output device')
        self.assertIn('Audio unavailable', self.engine.last_error)
        self.engine.dismiss(key)
        self.clock = self.clock.replace(day=6, hour=6, minute=0)
        self.engine.tick()
        self.assertEqual(self.engine.last_error, '')

    def test_storage_failure_sets_and_clears_error(self):
        with patch.object(self.engine.store, 'save', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.engine.toggle(self.saved['id'], False)
        self.assertIn('disk full', self.engine.last_error)
        self.engine.toggle(self.saved['id'], False)
        self.assertEqual(self.engine.last_error, '')

    def test_status_signal_deduped(self):
        changes = []
        self.engine.statusChanged.connect(lambda: changes.append(self.engine.last_error))
        self.engine.set_error('same')
        self.engine.set_error('same')
        self.engine.set_error('other')
        self.engine._clear_error()
        self.engine._clear_error()
        self.assertEqual(changes, ['same', 'other', ''])

    def test_test_reminder(self):
        self.engine.test()
        self.assertIn('test', self.engine.active)
        self.engine.dismiss('test')
        self.assertFalse(self.engine.active)

    def test_catch_up_grace(self):
        self.engine.dismiss(self.ring_bed()[0])
        self.clock = self.clock.replace(day=6, hour=6, minute=30)
        self.engine.tick()
        self.assertIn('wake', [r['event']['kind'] for r in self.engine.active.values()])
        for key in list(self.engine.active):
            self.engine.dismiss(key)
        self.clock = self.clock.replace(day=7, hour=8, minute=0)
        self.engine.tick()
        self.assertFalse(self.engine.active)


if __name__ == '__main__':
    unittest.main()
