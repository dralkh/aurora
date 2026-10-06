#!/usr/bin/env python3
"""Render application icons from the Aurora SVG."""
import sys
from pathlib import Path

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QGuiApplication, QImage, QPainter
from PySide6.QtSvg import QSvgRenderer

SIZES = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
ICONSET = {
    'icon_16x16.png': 16,
    'icon_16x16@2x.png': 32,
    'icon_32x32.png': 32,
    'icon_32x32@2x.png': 64,
    'icon_128x128.png': 128,
    'icon_128x128@2x.png': 256,
    'icon_256x256.png': 256,
    'icon_256x256@2x.png': 512,
    'icon_512x512.png': 512,
    'icon_512x512@2x.png': 1024,
}


def render(renderer, size):
    image = QImage(QSize(size, size), QImage.Format_ARGB32)
    image.fill(Qt.transparent)
    painter = QPainter(image)
    renderer.render(painter)
    painter.end()
    return image


def main():
    root = Path(__file__).resolve().parents[1]
    out = root / 'packaging/build'
    out.mkdir(parents=True, exist_ok=True)
    app = QGuiApplication([])
    renderer = QSvgRenderer(str(root / 'aurora_tray/icons/aurora.svg'))
    images = {size: render(renderer, size) for size in SIZES}
    for size, image in images.items():
        image.save(str(out / f'aurora-{size}.png'))
    iconset = out / 'aurora.iconset'
    iconset.mkdir(parents=True, exist_ok=True)
    for name, size in ICONSET.items():
        images[size].save(str(iconset / name))
    if sys.platform == 'win32':
        from PIL import Image
        base = Image.open(out / 'aurora-256.png').convert('RGBA')
        base.save(root / 'packaging/aurora.ico', sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print(out)
    return app.quit()


if __name__ == '__main__':
    sys.exit(main())
