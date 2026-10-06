"""Run with dbus-run-session; uses a real notify-send client and a fake desktop."""
import base64
import json
import sys
import tempfile
import time
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import quote
from zoneinfo import ZoneInfo

from PySide6.QtCore import ClassInfo, QObject, QCoreApplication, QProcess, Signal, Slot
from PySide6.QtDBus import QDBusConnection
from PySide6.QtTest import QTest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'package/contents/code'))
from aurora_service import Scheduler, SERVICE, PATH
from schedule_core import Store


@ClassInfo(**{'D-Bus Interface': 'org.freedesktop.Notifications'})
class Desktop(QObject):
    ActionInvoked = Signal('uint', str)
    NotificationClosed = Signal('uint', 'uint')
    def __init__(self):
        super().__init__()
        self.notices = {}
        self.count = 0
        self.closed = []
    @Slot(result='QStringList')
    def GetCapabilities(self):
        return ['actions', 'body', 'persistence']
    @Slot(str, 'uint', str, str, str, 'QStringList', 'QVariantMap', int, result='uint')
    def Notify(self, app, replaces, icon, title, body, actions, hints, expiry):
        self.count += 1
        self.notices[self.count] = dict(title=title, body=body, actions=actions, hints=hints, expiry=expiry)
        return self.count
    @Slot('uint')
    def CloseNotification(self, identifier):
        self.closed.append(identifier)
        self.NotificationClosed.emit(identifier, 3)


def wait_until(condition, description):
    end = time.monotonic() + 8
    while not condition():
        if time.monotonic() > end:
            raise AssertionError(description)
        QTest.qWait(20)


def main():
    app = QCoreApplication([])
    bus = QDBusConnection.sessionBus()
    assert bus.isConnected()
    desktop = Desktop()
    assert bus.registerService('org.freedesktop.Notifications')
    assert bus.registerObject('/org/freedesktop/Notifications', desktop, QDBusConnection.ExportAllSlots | QDBusConnection.ExportAllSignals)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'alarms.json'
        scheduler = Scheduler(Store(path), bus)
        scheduler.timer.stop()
        clock = datetime(2026, 10, 5, 20, tzinfo=ZoneInfo('Asia/Riyadh'))
        scheduler.now = lambda: clock
        assert bus.registerService(SERVICE)
        assert bus.registerObject(PATH, scheduler, QDBusConnection.ExportAllSlots)
        def client(payload):
            encoded = base64.b64encode(quote(json.dumps(payload, ensure_ascii=False)).encode()).decode()
            process = QProcess()
            process.start('/usr/bin/python3', [str(Path(__file__).resolve().parents[1] / 'package/contents/code/aurora_service.py'), '--request', encoded])
            wait_until(lambda: process.state() == QProcess.NotRunning, 'Client did not finish')
            output = bytes(process.readAllStandardOutput()).decode()
            assert output, bytes(process.readAllStandardError()).decode()
            return json.loads(output)
        schedule = dict(name='ليلة العمل', bedMinutes=1320, wakeMinutes=360, wakeDate='2026-10-06', days=[],
                        bedEnabled=True, wakeEnabled=True, bedSound=False, wakeSound=False, bedLead=15,
                        snooze=10, volume=70, enabled=True)
        response = client(dict(action='save', schedule=schedule))
        assert response['ok'], response
        identifier = response['schedules'][0]['id']
        assert client(dict(action='list'))['schedules'][0]['name'] == schedule['name']
        bad = client(dict(action='save', schedule={**schedule, 'volume': 120}))
        assert not bad['ok'] and bad['available']
        clock = clock.replace(hour=21, minute=45)
        scheduler.tick()
        wait_until(lambda: desktop.count == 1 and next(iter(scheduler.active.values()))['event'].get('notificationId'), 'Bedtime notification missing')
        assert desktop.notices[1]['title'] == 'Bedtime reminder'
        assert desktop.notices[1]['expiry'] == 0
        assert desktop.notices[1]['actions'] == ['snooze', 'Snooze 10 min', 'dismiss', 'Dismiss']
        scheduler.tick()
        assert desktop.count == 1
        desktop.ActionInvoked.emit(1, 'snooze')
        wait_until(lambda: next(iter(scheduler.store.data['pending'].values())).get('snoozed'), 'Snooze not persisted')
        wait_until(lambda: 1 in desktop.closed, 'Snoozed notification not closed')
        clock += timedelta(minutes=10)
        scheduler.tick()
        wait_until(lambda: desktop.count == 2, 'Snoozed notification did not return')
        desktop.ActionInvoked.emit(2, 'dismiss')
        wait_until(lambda: not scheduler.store.data['pending'], 'Dismiss did not clear alarm')
        clock = clock.replace(day=6, hour=6, minute=0)
        scheduler.tick()
        wait_until(lambda: desktop.count == 3 and next(iter(scheduler.active.values()))['event'].get('notificationId'), 'Wake notification missing')
        assert desktop.notices[3]['title'] == 'Time to wake up'
        # A daemon restart retains a ringing reminder without re-firing its occurrence.
        for key in list(scheduler.active):
            scheduler.stop(key, close=False)
        recovered = Scheduler(Store(path), bus)
        recovered.timer.stop()
        recovered.now = lambda: clock
        wait_until(lambda: desktop.count == 4, 'Ringing alarm was not recovered')
        recovered.tick()
        assert desktop.count == 4
        recovered.dismiss(next(iter(recovered.store.data['pending'])))
        assert not recovered.store.data['pending']
        assert client(dict(action='toggle', id=identifier, enabled=False))['ok']
        assert client(dict(action='remove', id=identifier))['schedules'] == []
        print('Private D-Bus integration passed: Unicode client, confirmation, paired notifications, snooze, dismiss, restart recovery, pause and delete.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
