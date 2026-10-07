"""Local calendar diary storage shared by all Aurora frontends."""
from __future__ import annotations

import os
import sqlite3
from contextlib import closing
from datetime import date
from pathlib import Path

KINDS = ('dream', 'waking', 'bedtime')
MAX_TEXT = 20000


class DiaryStore:
    def __init__(self, path):
        self.path = Path(path)

    def connect(self):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        # Create with private permissions before SQLite opens it.
        descriptor = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o600)
        os.close(descriptor)
        connection = sqlite3.connect(self.path, timeout=5)
        try:
            connection.execute('CREATE TABLE IF NOT EXISTS entries '
                               '(day TEXT NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, '
                               'PRIMARY KEY(day, kind))')
        except sqlite3.Error:
            connection.close()
            raise
        return connection

    def request(self, payload):
        try:
            action = payload.get('action')
            day = payload.get('date')
            if not isinstance(day, str) or date.fromisoformat(day).isoformat() != day:
                raise ValueError('Choose a valid calendar date.')
            if action not in ('diary_load', 'diary_save'):
                raise ValueError('Unknown diary action.')
            with closing(self.connect()) as connection, connection:
                if action == 'diary_save':
                    kind, text = payload.get('kind'), payload.get('text')
                    if kind not in KINDS or not isinstance(text, str):
                        raise ValueError('Invalid diary entry.')
                    if len(text) > MAX_TEXT:
                        raise ValueError('Keep each entry under 20,000 characters.')
                    if text.strip():
                        connection.execute('INSERT OR REPLACE INTO entries VALUES (?, ?, ?)', (day, kind, text))
                    else:
                        connection.execute('DELETE FROM entries WHERE day = ? AND kind = ?', (day, kind))
                entries = dict.fromkeys(KINDS, '')
                entries.update(connection.execute('SELECT kind, text FROM entries WHERE day = ?', (day,)))
                month = payload.get('month', day[:7])
                if not isinstance(month, str) or len(month) != 7 or date.fromisoformat(month + '-01').isoformat()[:7] != month:
                    raise ValueError('Choose a valid calendar month.')
                days = [row[0] for row in connection.execute(
                    'SELECT DISTINCT day FROM entries WHERE day LIKE ? ORDER BY day', (month + '-%',))]
            return dict(ok=True, date=day, entries=entries, days=days)
        except (ValueError, TypeError, AttributeError) as error:
            return dict(ok=False, error=str(error))
        except (OSError, sqlite3.Error) as error:
            return dict(ok=False, error=f'Could not save or read the diary: {error}')
