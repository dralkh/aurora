# -*- mode: python ; coding: utf-8 -*-
import re
import sys
from pathlib import Path

from PyInstaller.utils.hooks import collect_data_files

ROOT = Path(SPECPATH).resolve().parent
ICON = Path(SPECPATH).resolve() / ('aurora.ico' if sys.platform == 'win32' else 'aurora.icns')
VERSION = re.search(r"__version__ = '([^']+)'", (ROOT / 'aurora_tray/__init__.py').read_text(encoding='utf-8')).group(1)

datas = [
    (str(ROOT / 'aurora_tray/qml'), 'aurora_tray/qml'),
    (str(ROOT / 'aurora_tray/icons'), 'aurora_tray/icons'),
]
hiddenimports = [
    'PySide6.QtQuick',
    'PySide6.QtQuickControls2',
    'PySide6.QtMultimedia',
    'tzlocal',
]
try:
    import tzdata  # noqa: F401
except ImportError:
    pass
else:
    datas += collect_data_files('tzdata')
    hiddenimports.append('tzdata')

a = Analysis(
    [str(Path(SPECPATH).resolve() / 'entry.py')],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'PySide6.QtWebEngineCore',
        'PySide6.QtWebEngineWidgets',
        'PySide6.QtWebEngineQuick',
        'PySide6.Qt3DCore',
        'PySide6.QtCharts',
        'PySide6.QtDataVisualization',
        'PySide6.QtDesigner',
        'PySide6.QtPdf',
        'PySide6.QtSql',
        'PySide6.QtTest',
    ],
    noarchive=False,
)

DROP_QML_ROOTS = {
    'QtWebEngine', 'QtWebChannel', 'QtQuick3D', 'QtCharts', 'QtLocation', 'QtPositioning',
    'QtSensors', 'QtTextToSpeech', 'QtScxml', 'QtTest', 'QtWayland', 'Qt5Compat',
    'QtMultimedia', 'QtNetwork', 'QtCore', 'SddmComponents', 'SSO', 'QML', 'QmlTime', 'org',
}
DROP_BINARY_PREFIXES = (
    'libQt6WebEngine', 'libQt6WebChannel', 'libQt6Quick3D', 'libQt6Charts', 'libQt6DataVisualization',
    'libQt6Location', 'libQt6Positioning', 'libQt6Sensors', 'libQt6TextToSpeech', 'libQt6Scxml',
    'libQt6Test', 'libQt6Wayland', 'libQt6ShaderTools', 'libQt6Designer', 'Qt6WebEngine',
    'Qt6WebChannel', 'Qt6Quick3D', 'Qt6Charts',
)


def drop_qml(path):
    normalized = path.replace('\\', '/')
    if '/qml/' not in normalized:
        return False
    relative = normalized.split('/qml/', 1)[1]
    return relative.split('/', 1)[0] in DROP_QML_ROOTS


def drop_binary(path):
    normalized = path.replace('\\', '/')
    if drop_qml(normalized):
        return True
    name = normalized.rsplit('/', 1)[-1]
    return name.startswith(DROP_BINARY_PREFIXES)


a.datas = [entry for entry in a.datas if not drop_qml(entry[0])]
a.binaries = [entry for entry in a.binaries if not drop_binary(entry[0])]

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Aurora',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ICON) if ICON.exists() else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='Aurora',
)

if sys.platform == 'darwin':
    app = BUNDLE(
        coll,
        name='Aurora.app',
        icon=str(ICON) if ICON.exists() else None,
        bundle_identifier='org.dralk.aurora',
        info_plist={
            'CFBundleName': 'Aurora',
            'CFBundleDisplayName': 'Aurora',
            'CFBundleShortVersionString': VERSION,
            'CFBundleVersion': VERSION,
            'LSMinimumSystemVersion': '11.0',
            'LSUIElement': True,
            'NSHighResolutionCapable': True,
            'NSHumanReadableCopyright': 'MIT',
        },
    )
