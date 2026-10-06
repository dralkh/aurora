"""Run with dbus-run-session; uses a real notify-send client and a simulated desktop."""
import asyncio
import base64
import json
import os
import shutil
import sys
import tempfile
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import quote
from zoneinfo import ZoneInfo

from dbus_next.aio import MessageBus
from dbus_next.constants import RequestNameReply
from dbus_next.service import ServiceInterface, method
from dbus_next.service import signal as dbus_signal
from PySide6.QtCore import QCoreApplication, QProcess
from PySide6.QtDBus import QDBusConnection
from PySide6.QtTest import QTest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'package/contents/code'))
from aurora_service import PATH, SERVICE, Scheduler
from schedule_core import Store

NOTIFICATIONS = 'org.freedesktop.Notifications'
NOTIFICATIONS_PATH = '/org/freedesktop/Notifications'


class Notifications(ServiceInterface):
    def __init__(self):
        super().__init__(NOTIFICATIONS)
        self.notices = {}
        self.count = 0
        self.closed = []

    @method()
    def GetCapabilities(self) -> 'as':
        return ['actions', 'body', 'persistence']

    @method()
    def GetServerInformation(self) -> 'ssss':
        return ['Aurora Test', 'Dralk', '1.0', '1.2']

    @method()
    def Notify(self, app_name: 's', replaces_id: 'u', app_icon: 's', summary: 's', body: 's',
               actions: 'as', hints: 'a{sv}', expire_timeout: 'i') -> 'u':
        self.count += 1
        self.notices[self.count] = dict(title=summary, body=body, actions=actions, hints=hints, expiry=expire_timeout)
        return self.count

    @method()
    def CloseNotification(self, identifier: 'u'):
        self.closed.append(identifier)
        self.NotificationClosed(identifier, 3)

    @dbus_signal()
    def ActionInvoked(self, identifier: 'u', action: 's') -> 'us':
        return [identifier, action]

    @dbus_signal()
    def NotificationClosed(self, identifier: 'u', reason: 'u') -> 'uu':
        return [identifier, reason]


class Desktop:
    def __init__(self):
        self.loop = None
        self.interface = None
        ready = threading.Event()

        def run():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            self.loop = loop

            async def setup():
                bus = await MessageBus().connect()
                self.interface = Notifications()
                bus.export(NOTIFICATIONS_PATH, self.interface)
                reply = await bus.request_name(NOTIFICATIONS)
                if reply != RequestNameReply.PRIMARY_OWNER:
                    raise RuntimeError('The simulated notification server could not own its name.')

            loop.run_until_complete(setup())
            ready.set()
            loop.run_forever()

        threading.Thread(target=run, daemon=True).start()
        if not ready.wait(10):
            raise RuntimeError('The simulated notification server did not start.')

    @property
    def notices(self):
        return self.interface.notices

    @property
    def count(self):
        return self.interface.count

    @property
    def closed(self):
        return self.interface.closed

    def invoke(self, identifier, action):
        self.loop.call_soon_threadsafe(self.interface.ActionInvoked, identifier, action)


def ensure_close_client():
    if shutil.which('qdbus6'):
        return
    directory = tempfile.mkdtemp(prefix='aurora-qdbus6-')
    shim = Path(directory) / 'qdbus6'
    shim.write_text('#!/bin/sh\n'
                    'service="$1"; object_path="$2"; member="$3"; shift 3\n'
                    'exec gdbus call --session --dest "$service" --object-path "$object_path" --method "$member" "$@"\n')
    shim.chmod(0o755)
    os.environ['PATH'] = directory + os.pathsep + os.environ.get('PATH', '')


def wait_until(condition, description):
    end = time.monotonic() + 8
    while not condition():
        if time.monotonic() > end:
            raise AssertionError(description)
        QTest.qWait(20)


def main():
    _app = QCoreApplication([])
    bus = QDBusConnection.sessionBus()
    assert bus.isConnected()
    desktop = Desktop()
    ensure_close_client()
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
            process.start(sys.executable, [str(Path(__file__).resolve().parents[1] / 'package/contents/code/aurora_service.py'), '--request', encoded])
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
        desktop.invoke(1, 'snooze')
        wait_until(lambda: next(iter(scheduler.store.data['pending'].values())).get('snoozed'), 'Snooze not persisted')
        wait_until(lambda: 1 in desktop.closed, 'Snoozed notification not closed')
        clock += timedelta(minutes=10)
        scheduler.tick()
        wait_until(lambda: desktop.count == 2, 'Snoozed notification did not return')
        desktop.invoke(2, 'dismiss')
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
