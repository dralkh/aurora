import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'package/contents/code'))
from schedule_core import Store, events, instant

ZONE = ZoneInfo('Asia/Riyadh')

def at(day, hour, minute=0):
    return datetime(2026, 10, day, hour, minute, tzinfo=ZONE)


def raw(**changes):
    value = dict(name='Work nights', bedMinutes=22*60, wakeMinutes=6*60, wakeDate='2026-10-06',
                 days=[], bedEnabled=True, wakeEnabled=True, bedLead=15, snooze=10,
                 bedSound=True, wakeSound=True, volume=70, enabled=True)
    value.update(changes)
    return value


class Schedules(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / 'alarms.json'
        self.store = Store(self.path)
    def tearDown(self):
        self.directory.cleanup()
    def test_overnight_pair_and_lead(self):
        schedule = self.store.put(raw(), at(5, 20))
        pair = list(events(schedule, at(5, 20)))
        self.assertEqual(len(pair), 2)
        self.assertEqual(pair[0]['due'], at(5, 21, 45).timestamp())
        self.assertEqual(pair[0]['target'], at(5, 22).timestamp())
        self.assertEqual(pair[1]['due'], at(6, 6).timestamp())
    def test_repeat_days_refer_to_wake_day(self):
        schedule = self.store.put(raw(days=[0]), at(5, 20))  # Monday
        pair = list(events(schedule, at(5, 20)))
        self.assertEqual(len(pair), 2)
        self.assertEqual(datetime.fromtimestamp(pair[0]['due'], ZONE).weekday(), 6)
        self.assertEqual(datetime.fromtimestamp(pair[1]['due'], ZONE).weekday(), 0)
    def test_due_exactly_once_even_after_restart(self):
        self.store.put(raw(), at(5, 20))
        self.assertEqual(self.store.due(at(5, 21, 44)), [])
        self.assertEqual(len(self.store.due(at(5, 21, 45))), 1)
        restarted = Store(self.path)
        self.assertEqual(restarted.due(at(5, 21, 46)), [])
        self.assertEqual(len(restarted.data['pending']), 1)
        self.assertEqual(len(restarted.due(at(6, 6))), 1)
        self.assertEqual(restarted.due(at(6, 6)), [])
    def test_snooze_survives_restart(self):
        self.store.put(raw(), at(5, 20))
        event = self.store.due(at(5, 21, 45))[0]
        self.store.snooze(event['key'], at(5, 21, 46))
        restarted = Store(self.path)
        self.assertEqual(restarted.due(at(5, 21, 55)), [])
        self.assertEqual(len(restarted.due(at(5, 21, 56))), 1)
        self.assertEqual(restarted.due(at(5, 21, 57)), [])
    def test_dismiss_and_pause_cancel_pending(self):
        schedule = self.store.put(raw(), at(5, 20))
        event = self.store.due(at(5, 21, 45))[0]
        self.store.dismiss(event['key'])
        self.assertFalse(self.store.data['pending'])
        self.store.toggle(schedule['id'], False)
        self.assertEqual(self.store.due(at(6, 6)), [])
        self.store.remove(schedule['id'])
        self.assertFalse(self.store.data['schedules'])
    def test_resume_grace_and_stale_skip(self):
        self.store.put(raw(), at(5, 20))
        self.assertEqual(len(self.store.due(at(5, 22, 30))), 1)
        self.assertEqual(self.store.due(at(6, 8)), [])
        self.assertEqual(self.store.due(at(6, 8)), [])
    def test_past_bedtime_is_not_armed(self):
        self.store.put(raw(), at(6, 1))
        self.assertEqual(self.store.due(at(6, 1)), [])
        self.assertEqual(len(self.store.due(at(6, 6))), 1)
    def test_future_start_and_disabled_reminder(self):
        self.store.put(raw(wakeDate='2026-10-10', days=list(range(7)), bedEnabled=False), at(5, 20))
        self.assertEqual(self.store.due(at(6, 6)), [])
        self.assertEqual(len(self.store.due(at(10, 6))), 1)
    def test_edit_replaces_pending_and_rearms(self):
        schedule = self.store.put(raw(), at(5, 20))
        self.store.due(at(5, 21, 45))
        updated = self.store.put(raw(id=schedule['id'], bedMinutes=23*60), at(5, 22))
        self.assertNotEqual(updated['revision'], schedule['revision'])
        self.assertFalse(self.store.data['pending'])
        self.assertEqual(len(self.store.due(at(5, 22, 45))), 1)
    def test_invalid_input_does_not_change_saved_file(self):
        self.store.put(raw(), at(5, 20))
        before = self.path.read_bytes()
        for change in [dict(volume=101), dict(days=[7]), dict(wakeDate='yesterday'), dict(wakeDate='2026-10-01'), dict(bedEnabled=False, wakeEnabled=False), dict(snooze=0), dict(wakeMinutes=True)]:
            with self.assertRaises((ValueError, TypeError)):
                self.store.put(raw(**change), at(5, 20))
            self.assertEqual(self.path.read_bytes(), before)
    def test_confirm_inside_lead_window_reminds_immediately(self):
        self.store.put(raw(), at(5, 21, 50))
        due = self.store.due(at(5, 21, 50))
        self.assertEqual(len(due), 1)
        self.assertEqual(due[0]["kind"], "bed")
        self.assertEqual(self.store.due(at(5, 21, 51)), [])
    def test_repeating_schedule_can_be_edited_after_start_date(self):
        schedule = self.store.put(raw(days=[0, 1, 2, 3, 4]), at(5, 20))
        updated = self.store.put(raw(id=schedule["id"], days=[0, 1, 2, 3, 4], volume=50), at(10, 12))
        self.assertEqual(updated["volume"], 50)
        self.assertEqual(updated["wakeDate"], "2026-10-06")
    def test_failed_save_does_not_arm_schedule(self):
        with patch.object(self.store, "save", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.store.put(raw(), at(5, 20))
        self.assertFalse(self.store.data["schedules"])
    def test_dst_gap_normalized_and_fold_only_once(self):
        zone = ZoneInfo('America/New_York')
        normalized = instant(datetime(2026, 3, 8).date(), 150, zone)
        self.assertEqual(normalized.hour, 3)
        self.assertEqual(normalized.minute, 30)
        before = datetime(2026, 10, 31, 20, tzinfo=zone)
        self.store.put(raw(wakeDate='2026-11-01', wakeMinutes=90, bedEnabled=False), before)
        first = datetime(2026, 11, 1, 1, 30, tzinfo=zone, fold=0)
        second = datetime(2026, 11, 1, 1, 30, tzinfo=zone, fold=1)
        self.assertEqual(len(self.store.due(first)), 1)
        self.assertEqual(self.store.due(second), [])

if __name__ == '__main__':
    unittest.main()
