#!/usr/bin/env python3
"""Aurora user-session alarm service and widget request client."""
import base64
import html
import json
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

from PySide6.QtCore import ClassInfo, QCoreApplication, QObject, QProcess, QTimer, QUrl, Slot
from PySide6.QtDBus import QDBusConnection, QDBusMessage
from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
from schedule_core import Store, datetime, local_zone

SERVICE = 'org.dralk.Aurora'
PATH = '/Scheduler'
INTERFACE = SERVICE


@ClassInfo(**{'D-Bus Interface': INTERFACE})
class Scheduler(QObject):
    def __init__(self, store, bus):
        super().__init__()
        self.store, self.bus = store, bus
        self.zone = local_zone()
        self.active = {}
        self.last_error = ''
        self.timer = QTimer(self)
        self.timer.setInterval(5000)
        self.timer.timeout.connect(self.tick)
        self.timer.start()
        QTimer.singleShot(0, self.restore_pending)

    def now(self):
        return datetime.now(self.zone)

    def owner(self):
        reply = self.bus.interface().serviceOwner('org.freedesktop.Notifications')
        return reply.value() if reply.isValid() else ''

    def restore_pending(self):
        for event in list(self.store.data['pending'].values()):
            if self.now().timestamp() - event['due'] > 86400:
                self.store.dismiss(event['key'])
                continue
            if not event.get('snoozed'):
                if event.get('notificationOwner') == self.owner():
                    self.close_notification(event.get('notificationId'))
                self.deliver(event)
        self.tick()

    @Slot(str, result=str)
    def Request(self, raw):
        try:
            request = json.loads(raw)
            if not isinstance(request, dict):
                raise ValueError('Invalid request.')
            action = request.get('action')
            saved_id = None
            if action == 'save':
                schedule = request['schedule']
                saved_id = self.store.put(schedule, self.now())["id"]
                if schedule.get('id'):
                    self.stop_schedule(schedule['id'])
                self.tick()
            elif action == 'remove':
                self.stop_schedule(request['id'])
                self.store.remove(request['id'])
            elif action == 'toggle':
                if type(request.get('enabled')) is not bool:
                    raise ValueError('Invalid enabled flag.')
                self.store.toggle(request['id'], request['enabled'])
                if not request['enabled']:
                    self.stop_schedule(request['id'])
            elif action == 'dismiss':
                self.dismiss(request['key'])
            elif action == 'snooze':
                self.snooze(request['key'])
            elif action == 'test':
                self.deliver(dict(key='test', scheduleId='test', kind='bed', name='Test reminder',
                                  due=self.now().timestamp(), target=self.now().timestamp(),
                                  sound=True, volume=70, snooze=10, soundUntil=self.now().timestamp() + 10))
            elif action != 'list':
                raise ValueError('Unknown request.')
            snapshot = self.store.snapshot(self.now())
            snapshot['warning'] = self.last_error
            if saved_id:
                snapshot['savedId'] = saved_id
            return json.dumps(snapshot, ensure_ascii=False)
        except (ValueError, KeyError, TypeError) as error:
            return json.dumps(dict(ok=False, available=True, error=str(error)))
        except OSError as error:
            return json.dumps(dict(ok=False, available=True, error=f'Could not save alarms: {error}'))

    def tick(self):
        try:
            for event in self.store.due(self.now()):
                self.deliver(event)
            # Notification-server downtime: retry delivery instead of dropping alarms.
            for event in list(self.store.data['pending'].values()):
                if not event.get('snoozed') and event['key'] not in self.active:
                    self.deliver(event)
        except (OSError, ValueError) as error:
            self.last_error = f'Alarm storage error: {error}'
            print(self.last_error, file=sys.stderr, flush=True)

    def deliver(self, event):
        key = event['key']
        if key in self.active:
            return
        process = QProcess(self)
        record = dict(process=process, event=event, buffer='', player=None, audio=None, timer=None)
        self.active[key] = record
        summary = 'Time to wake up' if event['kind'] == 'wake' else 'Bedtime reminder'
        target = datetime.fromtimestamp(event['target'], self.zone).strftime('%H:%M')
        body = html.escape(event['name']) + (' — wake time ' if event['kind'] == 'wake' else ' — bedtime ') + target
        process.readyReadStandardOutput.connect(lambda: self.output(key))
        process.finished.connect(lambda code, status: self.finished(key, code))
        process.errorOccurred.connect(lambda error: self.failed(key, 'Unable to start desktop notifications.'))
        icon = str(Path(__file__).parent.parent / 'icons/aurora.svg')
        args = ['--app-name=Aurora', '--urgency=critical', '--expire-time=0', '--print-id',
                '--hint=boolean:suppress-sound:true', '--hint=string:desktop-entry:org.dralk.Aurora', '--icon=' + icon,
                '--action=snooze=Snooze ' + str(event['snooze']) + ' min', '--action=dismiss=Dismiss', summary, body]
        command = 'notify-send'
        if shutil.which('stdbuf'):
            # Older libnotify waits for actions before flushing the printed id.
            command, args = 'stdbuf', ['-oL', 'notify-send'] + args
        process.start(command, args)

    def output(self, key):
        record = self.active.get(key)
        if not record:
            return
        record['buffer'] += bytes(record['process'].readAllStandardOutput()).decode('utf-8', errors='replace')
        while '\n' in record['buffer']:
            line, record['buffer'] = record['buffer'].split('\n', 1)
            if line.isdigit():
                event = record['event']
                event['notificationId'] = int(line)
                event['notificationOwner'] = self.owner()
                if key in self.store.data['pending']:
                    self.store.save()
                self.last_error = ''
                self.play(key)
            elif line == 'snooze':
                self.snooze(key)
            elif line in ('dismiss', 'default'):
                self.dismiss(key)

    def play(self, key):
        record = self.active.get(key)
        if not record or record['player'] or not record['event']['sound']:
            return
        event = record['event']
        remaining = event['soundUntil'] - self.now().timestamp()
        if remaining <= 0:
            return
        names = ['alarm-clock-elapsed.oga'] if event['kind'] == 'wake' else ['bell-window-system.oga', 'bell.oga']
        candidates = [Path('/usr/share/sounds') / theme / 'stereo' / name
                      for theme in ('ocean', 'freedesktop') for name in names]
        sound = next((p for p in candidates if p.exists()), None)
        if sound is None:
            self.last_error = 'The alarm sound is missing. Notifications still work.'
            return
        player, audio = QMediaPlayer(self), QAudioOutput(self)
        audio.setVolume(event['volume'] / 100)
        player.setAudioOutput(audio)
        player.setSource(QUrl.fromLocalFile(str(sound)))
        player.setLoops(QMediaPlayer.Infinite if event['kind'] == 'wake' else 1)
        record.update(player=player, audio=audio)
        player.errorOccurred.connect(lambda error, text: self.audio_error(text))
        timer = QTimer(self)
        timer.setSingleShot(True)
        timer.timeout.connect(player.stop)
        timer.start(max(1, int(remaining * 1000)))
        record['timer'] = timer
        player.play()

    def audio_error(self, text):
        self.last_error = 'Audio unavailable: ' + text + '. Desktop notifications remain active.'

    def failed(self, key, message):
        self.last_error = message
        self.stop(key, close=False)

    def finished(self, key, code):
        record = self.active.get(key)
        if not record:
            return
        self.output(key)
        if key not in self.active:
            return
        if code:
            error = bytes(record['process'].readAllStandardError()).decode('utf-8', errors='replace').strip()
            self.failed(key, 'Desktop notification delivery failed: ' + error)
        else:
            self.store.dismiss(key)
            self.stop(key, close=False)

    def close_notification(self, notification_id):
        if notification_id:
            QProcess.startDetached('qdbus6', ['org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                                            'org.freedesktop.Notifications.CloseNotification', str(notification_id)])

    def stop(self, key, close=True):
        record = self.active.pop(key, None)
        if record is None:
            return
        if close:
            self.close_notification(record['event'].get('notificationId'))
        if record['player']:
            record['player'].stop()
            record['player'].deleteLater()
            record['audio'].deleteLater()
        if record['timer']:
            record['timer'].stop()
            record['timer'].deleteLater()
        try:
            record['process'].terminate()
            record['process'].deleteLater()
        except RuntimeError:
            pass

    def stop_schedule(self, schedule_id):
        for key, record in list(self.active.items()):
            if record['event']['scheduleId'] == schedule_id:
                self.stop(key)

    def dismiss(self, key):
        self.store.dismiss(key)
        self.stop(key)

    def snooze(self, key):
        self.stop(key)
        if key in self.store.data['pending']:
            self.store.snooze(key, self.now())


def main():
    app = QCoreApplication(sys.argv)
    bus = QDBusConnection.sessionBus()
    if '--request' in sys.argv:
        try:
            raw = unquote(base64.b64decode(sys.argv[sys.argv.index('--request') + 1], validate=True).decode('ascii'))
            message = QDBusMessage.createMethodCall(SERVICE, PATH, INTERFACE, 'Request')
            message.setArguments([raw])
            response = bus.call(message, timeout=10000)
            if response.type() == QDBusMessage.ErrorMessage:
                raise RuntimeError('Alarm service is unavailable. Run Aurora’s installer in your desktop terminal. ' + response.errorMessage())
            print(response.arguments()[0])
            return 0
        except Exception as error:
            print(json.dumps(dict(ok=False, error=str(error))))
            return 1
    if not bus.isConnected():
        print('Aurora requires a user-session D-Bus connection.', file=sys.stderr)
        return 1
    if not shutil.which('notify-send') or not shutil.which('qdbus6'):
        print('Install notify-send (libnotify) and qdbus6 first.', file=sys.stderr)
        return 1
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'aurora/alarms.json'
    scheduler = Scheduler(Store(state), bus)
    if not bus.registerService(SERVICE):
        print('Aurora alarm service is already running or could not register.', file=sys.stderr)
        return 1
    if not bus.registerObject(PATH, scheduler, QDBusConnection.ExportAllSlots):
        print(bus.lastError().message(), file=sys.stderr)
        return 1
    return app.exec()


if __name__ == '__main__':
    raise SystemExit(main())
