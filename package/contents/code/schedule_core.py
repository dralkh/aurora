"""Persistent local-time schedules. No desktop dependencies."""
from __future__ import annotations
from datetime import datetime, date, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo
import json
import copy
from functools import wraps
import os
import tempfile
import uuid


def local_zone():
    if os.environ.get('TZ'):
        try:
            return ZoneInfo(os.environ['TZ'])
        except (KeyError, ValueError):
            pass
    with open('/etc/localtime', 'rb') as stream:
        return ZoneInfo.from_file(stream)


def instant(day, minutes, zone):
    value = datetime.combine(day, time(minutes // 60, minutes % 60), zone)
    # Normalize nonexistent wall times through the system's timezone rules.
    return datetime.fromtimestamp(value.timestamp(), zone)


def validate_schedule(raw, now, existing=None):
    if not isinstance(raw, dict):
        raise ValueError('Invalid schedule.')
    def integer(key, minimum, maximum, default):
        value = raw.get(key, default)
        if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
            raise ValueError(f'Invalid {key}.')
        return value
    def boolean(key, default):
        value = raw.get(key, default)
        if not isinstance(value, bool):
            raise ValueError(f'Invalid {key}.')
        return value
    name = raw.get('name', 'Sleep schedule')
    if not isinstance(name, str) or not name.strip() or len(name) > 80:
        raise ValueError('Enter a schedule name (up to 80 characters).')
    days = raw.get('days', [])
    if not isinstance(days, list) or any(type(d) is not int or not 0 <= d <= 6 for d in days):
        raise ValueError('Invalid repeat days.')
    first = date.fromisoformat(raw.get('wakeDate', now.date().isoformat()))
    if first < now.date() and not (existing and days and first.isoformat() == existing['wakeDate']):
        raise ValueError('Choose today or a future wake-up date.')
    schedule = dict(id=existing['id'] if existing else uuid.uuid4().hex,
                    revision=uuid.uuid4().hex, name=name.strip(), days=sorted(set(days)),
                    wakeDate=first.isoformat(), bedMinutes=integer('bedMinutes', 0, 1439, 1320),
                    wakeMinutes=integer('wakeMinutes', 0, 1439, 360),
                    bedEnabled=boolean('bedEnabled', True), wakeEnabled=boolean('wakeEnabled', True),
                    bedSound=boolean('bedSound', True), wakeSound=boolean('wakeSound', True),
                    bedLead=integer('bedLead', 0, 120, 15), snooze=integer('snooze', 1, 60, 10),
                    volume=integer('volume', 0, 100, 70), enabled=boolean('enabled', True),
                    created=now.timestamp())
    if not schedule['bedEnabled'] and not schedule['wakeEnabled']:
        raise ValueError('Enable at least one reminder.')
    if not days and instant(first, schedule['wakeMinutes'], now.tzinfo).timestamp() <= now.timestamp():
        raise ValueError('The wake-up time has passed. Choose a future date.')
    if schedule["bedMinutes"] == schedule["wakeMinutes"]:
        raise ValueError("Bedtime and wake time must be different.")
    return schedule


def events(schedule, start, count=11):
    first = date.fromisoformat(schedule['wakeDate'])
    for offset in range(count):
        wake_day = start.date() + timedelta(days=offset - 1)
        if wake_day < first:
            continue
        if schedule['days']:
            if wake_day.weekday() not in schedule['days']:
                continue
        elif wake_day != first:
            continue
        wake = instant(wake_day, schedule['wakeMinutes'], start.tzinfo)
        bed_day = wake_day - timedelta(days=int(schedule['bedMinutes'] >= schedule['wakeMinutes']))
        bed = instant(bed_day, schedule['bedMinutes'], start.tzinfo)
        for kind, due, target in [('bed', bed - timedelta(minutes=schedule['bedLead']), bed), ('wake', wake, wake)]:
            if not schedule[kind + 'Enabled']:
                continue
            if kind == 'bed' and due.timestamp() < schedule['created'] <= target.timestamp():
                due = datetime.fromtimestamp(schedule['created'], start.tzinfo)
            yield dict(key=f"{schedule['id']}:{schedule['revision']}:{wake_day}:{kind}",
                       scheduleId=schedule['id'], kind=kind, due=due.timestamp(), target=target.timestamp(),
                       name=schedule['name'], snooze=schedule['snooze'], volume=schedule['volume'],
                       sound=schedule[kind + 'Sound'], soundUntil=due.timestamp() + 300)


def transaction(function):
    @wraps(function)
    def run(self, *args, **kwargs):
        previous = copy.deepcopy(self.data)
        try:
            return function(self, *args, **kwargs)
        except Exception:
            if self.data != previous:
                self.data = previous
            raise
    return run


class Store:
    def __init__(self, path):
        self.path = Path(path)
        self.data = {'schedules': [], 'delivered': {}, 'pending': {}}
        if self.path.exists():
            self.data = json.loads(self.path.read_text())
            if not all(k in self.data for k in ('schedules', 'delivered', 'pending')):
                raise ValueError('The saved alarm file is invalid.')

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor, temporary = tempfile.mkstemp(dir=self.path.parent, prefix='.alarms-')
        try:
            with os.fdopen(descriptor, 'w') as stream:
                json.dump(self.data, stream, ensure_ascii=False)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, self.path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    @transaction
    def put(self, raw, now):
        if not isinstance(raw, dict):
            raise ValueError("Invalid schedule.")
        existing = next((s for s in self.data['schedules'] if s['id'] == raw.get('id')), None)
        if raw.get('id') and existing is None:
            raise ValueError('That schedule no longer exists.')
        if existing is None and len(self.data['schedules']) >= 100:
            raise ValueError('The maximum is 100 schedules.')
        schedule = validate_schedule(raw, now, existing)
        self.cancel_pending(schedule['id'])
        self.data['schedules'] = [s for s in self.data['schedules'] if s['id'] != schedule['id']] + [schedule]
        self.save()
        return schedule

    def cancel_pending(self, schedule_id):
        self.data['pending'] = {k: e for k, e in self.data['pending'].items() if e['scheduleId'] != schedule_id}

    @transaction
    def remove(self, schedule_id):
        self.data['schedules'] = [s for s in self.data['schedules'] if s['id'] != schedule_id]
        self.cancel_pending(schedule_id)
        self.save()

    @transaction
    def toggle(self, schedule_id, enabled):
        for schedule in self.data['schedules']:
            if schedule['id'] == schedule_id:
                schedule['enabled'] = bool(enabled)
                if not enabled:
                    self.cancel_pending(schedule_id)
                self.save()
                return
        raise ValueError('That schedule no longer exists.')

    @transaction
    def due(self, now):
        found = []
        before = json.dumps(self.data, sort_keys=True)
        stamp = now.timestamp()
        for schedule in self.data['schedules']:
            if not schedule['enabled']:
                continue
            for event in events(schedule, now):
                key = event['key']
                if event['due'] > stamp or key in self.data['delivered'] or event['due'] < schedule['created']:
                    continue
                self.data['delivered'][key] = stamp
                # Resume/restart catch-up: never ring an alarm older than one hour.
                if stamp - event['due'] <= 3600:
                    event['soundUntil'] = stamp + 300
                    self.data['pending'][key] = event
                    found.append(event)
        for event in self.data['pending'].values():
            if event.get('snoozed') and event['due'] <= stamp:
                event['snoozed'] = False
                event['soundUntil'] = stamp + 300
                found.append(event)
        cutoff = stamp - 14 * 86400
        self.data['delivered'] = {k: t for k, t in self.data['delivered'].items() if t >= cutoff}
        if json.dumps(self.data, sort_keys=True) != before:
            self.save()
        return found

    @transaction
    def dismiss(self, key):
        self.data['pending'].pop(key, None)
        self.save()

    @transaction
    def snooze(self, key, now):
        event = self.data['pending'][key]
        event.update(due=now.timestamp() + event['snooze'] * 60, snoozed=True)
        event.pop('notificationId', None)
        event.pop('notificationOwner', None)
        self.save()

    def snapshot(self, now):
        schedules = []
        for schedule in self.data['schedules']:
            row = dict(schedule)
            upcoming = [e for e in events(schedule, now) if e['due'] > now.timestamp() and e['key'] not in self.data['delivered']]
            row['next'] = min((e['due'] for e in upcoming), default=None) if schedule['enabled'] else None
            schedules.append(row)
        return dict(ok=True, schedules=schedules, pending=list(self.data['pending'].values()))
