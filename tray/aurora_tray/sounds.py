"""Generated alarm tones and a portable player wrapper."""
from __future__ import annotations

import math
import os
import wave
from array import array
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, QUrl, Signal

from .platform_support import cache_dir

RATE = 44100

WAKE_NOTES = [(523.25, 0.30), (659.25, 0.30), (783.99, 0.45), (0.0, 0.55)] * 3
BED_NOTES = [(659.25, 0.55), (523.25, 1.05)]


def _render(notes, decay, gain):
    samples = array('h')
    for frequency, duration in notes:
        count = int(RATE * duration)
        attack = max(1, int(RATE * 0.012))
        for index in range(count):
            if frequency <= 0:
                samples.append(0)
                continue
            time = index / RATE
            envelope = min(1.0, index / attack) * math.exp(-decay * time)
            tone = math.sin(2 * math.pi * frequency * time)
            overtone = 0.28 * math.sin(4 * math.pi * frequency * time) * math.exp(-2.2 * decay * time)
            value = max(-1.0, min(1.0, gain * envelope * (tone + overtone)))
            samples.append(int(value * 32767))
    return samples


def _write(path: Path, samples) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def ensure_sound(kind: str) -> Path:
    path = cache_dir() / 'sounds' / f'{kind}.wav'
    if path.exists() and path.stat().st_size > 44:
        return path
    if kind == 'wake':
        samples = _render(WAKE_NOTES, decay=3.1, gain=0.55)
    else:
        samples = _render(BED_NOTES, decay=2.4, gain=0.5)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    try:
        _write(temporary, samples)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return path


class SoundPlayer(QObject):
    failed = Signal(str)

    def __init__(self, event, duration, parent=None):
        super().__init__(parent)
        from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
        self.player = QMediaPlayer(self)
        self.audio = QAudioOutput(self)
        self.audio.setVolume(max(0, min(100, int(event.get('volume', 70)))) / 100)
        self.player.setAudioOutput(self.audio)
        self.player.setSource(QUrl.fromLocalFile(str(ensure_sound(event['kind']))))
        self.player.setLoops(QMediaPlayer.Infinite if event['kind'] == 'wake' else 1)
        self.player.errorOccurred.connect(self._error)
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self.stop)
        self.timer.start(max(1, int(duration * 1000)))
        self.player.play()

    def _error(self, error, text):
        if text:
            self.failed.emit(text)

    def stop(self):
        self.timer.stop()
        self.player.stop()
