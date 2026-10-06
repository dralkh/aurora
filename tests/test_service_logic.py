import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfo
from PySide6.QtCore import QCoreApplication, QObject, Signal
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'package/contents/code'))
import aurora_service as service
from schedule_core import Store

APP = QCoreApplication.instance() or QCoreApplication([])

class Process(QObject):
    readyReadStandardOutput = Signal()
    finished = Signal(int, int)
    errorOccurred = Signal(int)
    detached = []
    def __init__(self, parent=None):
        super().__init__(parent)
        self.output = b''
        self.error = b'notification server unavailable'
        self.args = []
        self.terminated = False
    def start(self, command, args):
        self.command, self.args = command, args
    def readAllStandardOutput(self):
        output, self.output = self.output, b''
        return output
    def readAllStandardError(self):
        return self.error
    def emit_output(self, text):
        self.output += text.encode()
        self.readyReadStandardOutput.emit()
    def terminate(self):
        self.terminated = True
    @staticmethod
    def startDetached(command, args):
        Process.detached.append((command, args))

class Player(QObject):
    Infinite = -1
    errorOccurred = Signal(int, str)
    def __init__(self, parent=None):
        super().__init__(parent)
        self.played = False
        self.stopped = False
    def setAudioOutput(self, audio):
        self.audio = audio
    def setSource(self, source):
        self.source = source
    def setLoops(self, loops):
        self.loops = loops
    def play(self):
        self.played = True
    def stop(self):
        self.stopped = True

class Audio(QObject):
    def setVolume(self, volume):
        self.volume = volume

class ServiceLogic(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.clock = datetime(2026, 10, 5, 20, tzinfo=ZoneInfo('Asia/Riyadh'))
        self.patches = [patch.object(service, 'QProcess', Process), patch.object(service, 'QMediaPlayer', Player), patch.object(service, 'QAudioOutput', Audio)]
        for p in self.patches: p.start()
        self.scheduler = service.Scheduler(Store(Path(self.temp.name) / 'alarms.json'), None)
        self.scheduler.timer.stop()
        self.scheduler.now = lambda: self.clock
        self.scheduler.owner = lambda: ':test.notifications'
        self.value = dict(name='Weeknight', bedMinutes=1320, wakeMinutes=360, wakeDate='2026-10-06', days=[],
                          bedEnabled=True, wakeEnabled=True, bedSound=True, wakeSound=True, bedLead=15,
                          snooze=10, volume=70, enabled=True)
        saved = self.request('save', schedule=self.value)
        self.assertEqual(saved['savedId'], saved['schedules'][0]['id'])
        Process.detached.clear()
    def tearDown(self):
        for key in list(self.scheduler.active): self.scheduler.stop(key)
        self.scheduler.timer.stop()
        self.scheduler.deleteLater()
        for p in reversed(self.patches): p.stop()
        self.temp.cleanup()
    def request(self, action, **fields):
        return json.loads(self.scheduler.Request(json.dumps(dict(action=action, **fields))))
    def bed(self):
        self.clock = self.clock.replace(hour=21, minute=45)
        self.scheduler.tick()
        key = next(iter(self.scheduler.active))
        self.scheduler.active[key]['process'].emit_output('12\n')
        return key, self.scheduler.active[key]
    def test_paired_notification_options_and_sounds(self):
        key, bed = self.bed()
        self.assertIn('--expire-time=0', bed['process'].args)
        self.assertIn('--action=snooze=Snooze 10 min', bed['process'].args)
        self.assertEqual(bed['player'].loops, 1)
        self.assertEqual(bed['audio'].volume, 0.7)
        self.assertEqual(bed['event']['notificationId'], 12)
        self.scheduler.dismiss(key)
        self.clock = self.clock.replace(day=6, hour=6, minute=0)
        self.scheduler.tick()
        wake = next(iter(self.scheduler.active.values()))
        wake['process'].emit_output('13\n')
        self.assertEqual(wake['player'].loops, Player.Infinite)
        self.assertTrue(wake['player'].played)
        self.assertEqual(wake['event']['kind'], 'wake')
    def test_snooze_closes_notification_before_clearing_id(self):
        key, bed = self.bed()
        bed['process'].emit_output('snooze\n')
        self.assertFalse(self.scheduler.active)
        self.assertTrue(self.scheduler.store.data['pending'][key]['snoozed'])
        self.assertTrue(bed['player'].stopped)
        self.assertEqual(Process.detached[-1][1][-1], '12')
        self.clock += timedelta(minutes=10)
        self.scheduler.tick()
        self.assertIn(key, self.scheduler.active)
    def test_dismiss_stops_audio_and_removes_pending(self):
        key, bed = self.bed()
        response = self.request('dismiss', key=key)
        self.assertTrue(response['ok'])
        self.assertFalse(response['pending'])
        self.assertTrue(bed['player'].stopped)
    def test_failure_is_visible_and_pending_is_retried(self):
        self.clock = self.clock.replace(hour=21, minute=45)
        self.scheduler.tick()
        key, record = next(iter(self.scheduler.active.items()))
        record['process'].finished.emit(1, 0)
        self.assertNotIn(key, self.scheduler.active)
        self.assertIn(key, self.scheduler.store.data['pending'])
        self.assertIn('delivery failed', self.request('list')['warning'])
        self.scheduler.tick()
        self.assertIn(key, self.scheduler.active)
    def test_invalid_save_keeps_current_alarm_ringing(self):
        key, bed = self.bed()
        value = self.request('list')['schedules'][0]
        value['volume'] = 101
        response = self.request('save', schedule=value)
        self.assertFalse(response['ok'])
        self.assertTrue(response['available'])
        self.assertIn(key, self.scheduler.active)
        self.assertFalse(bed['player'].stopped)
    def test_pause_and_delete_stop_pending_sound(self):
        key, bed = self.bed()
        identifier = bed['event']['scheduleId']
        response = self.request('toggle', id=identifier, enabled=False)
        self.assertTrue(response['ok'])
        self.assertFalse(self.scheduler.active)
        self.assertFalse(response['pending'])
        self.assertTrue(bed['player'].stopped)
        self.assertFalse(self.request('remove', id=identifier)['schedules'])
    def test_notification_dismissal_and_audio_error(self):
        key, bed = self.bed()
        bed['player'].errorOccurred.emit(1, 'No output device')
        self.assertIn('Audio unavailable', self.request('list')['warning'])
        bed['process'].finished.emit(0, 0)
        self.assertFalse(self.scheduler.active)
        self.assertFalse(self.scheduler.store.data['pending'])

if __name__ == '__main__':
    unittest.main()
