"""Alarm scheduling and delivery for the tray application."""
from __future__ import annotations

import logging
from datetime import datetime

from PySide6.QtCore import QObject, QTimer, Signal

from .platform_support import local_zone
from .schedule_core import Store
from .sounds import SoundPlayer

log = logging.getLogger('aurora.engine')


class AlarmEngine(QObject):
    changed = Signal()
    statusChanged = Signal()

    def __init__(self, store_path, sound_factory=SoundPlayer, start=True, parent=None):
        super().__init__(parent)
        self.store = Store(store_path)
        self.zone = local_zone()
        self.sound_factory = sound_factory
        self.active = {}
        self.last_error = ''
        self.timer = QTimer(self)
        self.timer.setInterval(5000)
        self.timer.timeout.connect(self.tick)
        if start:
            self.timer.start()
            QTimer.singleShot(0, self.restore_pending)

    def now(self) -> datetime:
        return datetime.now(self.zone)

    def restore_pending(self) -> None:
        for event in list(self.store.data['pending'].values()):
            if self.now().timestamp() - event['due'] > 86400:
                try:
                    self.store.dismiss(event['key'])
                except OSError as error:
                    self.set_error(f'Alarm storage error: {error}')
                continue
            if not event.get('snoozed'):
                self.deliver(event)
        self.tick()

    def tick(self) -> None:
        try:
            for event in self.store.due(self.now()):
                self.deliver(event)
            for event in list(self.store.data['pending'].values()):
                if not event.get('snoozed') and event['key'] not in self.active:
                    self.deliver(event)
        except (OSError, ValueError) as error:
            self.set_error(f'Alarm storage error: {error}')
            return
        if self.last_error.startswith('Alarm storage error'):
            self._clear_error()

    def set_error(self, message: str) -> None:
        if self.last_error == message:
            return
        self.last_error = message
        log.error(message)
        self.statusChanged.emit()

    def _clear_error(self) -> None:
        if self.last_error:
            self.last_error = ''
            self.statusChanged.emit()

    def deliver(self, event: dict) -> None:
        key = event['key']
        if key in self.active:
            return
        record = {'event': event, 'player': None}
        self.active[key] = record
        log.info('Delivering %s reminder %s', event['kind'], event.get('name', key))
        sound_ok = True
        if event.get('sound'):
            remaining = event.get('soundUntil', 0) - self.now().timestamp()
            if remaining > 0:
                try:
                    player = self.sound_factory(event, remaining)
                    if hasattr(player, 'failed'):
                        player.failed.connect(
                            lambda text: self.set_error(f'Audio unavailable: {text}. Reminders remain active.'))
                    record['player'] = player
                except Exception as error:
                    sound_ok = False
                    self.set_error(f'Audio unavailable: {error}. Reminders remain active.')
        if sound_ok:
            self._clear_error()
        self.changed.emit()

    def stop(self, key: str) -> None:
        record = self.active.pop(key, None)
        if record is None:
            return
        if record['player'] is not None:
            record['player'].stop()
        self.changed.emit()

    def dismiss(self, key: str) -> None:
        try:
            self.store.dismiss(key)
        except OSError as error:
            self.set_error(f'Alarm storage error: {error}')
            raise
        self.stop(key)

    def snooze(self, key: str) -> None:
        self.stop(key)
        if key in self.store.data['pending']:
            try:
                self.store.snooze(key, self.now())
            except OSError as error:
                self.set_error(f'Alarm storage error: {error}')
                raise
        self.changed.emit()

    def stop_schedule(self, schedule_id: str) -> None:
        for key, record in list(self.active.items()):
            if record['event']['scheduleId'] == schedule_id:
                self.stop(key)

    def save(self, raw: dict) -> dict:
        try:
            schedule = self.store.put(raw, self.now())
        except OSError as error:
            self.set_error(f'Alarm storage error: {error}')
            raise
        self._clear_error()
        if raw.get('id'):
            self.stop_schedule(raw['id'])
        self.tick()
        self.changed.emit()
        return schedule

    def remove(self, schedule_id: str) -> None:
        self.stop_schedule(schedule_id)
        try:
            self.store.remove(schedule_id)
        except OSError as error:
            self.set_error(f'Alarm storage error: {error}')
            raise
        self._clear_error()
        self.changed.emit()

    def toggle(self, schedule_id: str, enabled: bool) -> None:
        try:
            self.store.toggle(schedule_id, bool(enabled))
        except OSError as error:
            self.set_error(f'Alarm storage error: {error}')
            raise
        self._clear_error()
        if not enabled:
            self.stop_schedule(schedule_id)
        self.changed.emit()

    def test(self) -> None:
        stamp = self.now().timestamp()
        self.deliver(dict(key='test', scheduleId='test', kind='bed', name='Test reminder',
                          due=stamp, target=stamp, sound=True, volume=70, snooze=10,
                          soundUntil=stamp + 10))

    def reminders(self) -> list:
        return [record['event'] for record in self.active.values()]

    def snapshot(self) -> dict:
        return self.store.snapshot(self.now())

    def shutdown(self) -> None:
        self.timer.stop()
        for key in list(self.active):
            self.stop(key)
