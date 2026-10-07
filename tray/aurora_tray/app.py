"""Tray application shell for Aurora."""
from __future__ import annotations

import logging
import os
import sys
import tempfile
from datetime import datetime

from PySide6.QtCore import QCoreApplication, QObject, QPoint, QSize, Qt, QTimer, QUrl
from PySide6.QtGui import QColor, QCursor, QGuiApplication, QIcon, QPainter, QPixmap
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine, QQmlFileSelector
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from . import __version__, logging_setup, platform_support
from .backend import Backend
from .engine import AlarmEngine

log = logging.getLogger('aurora.app')

INSTANCE_NAME = 'org.dralk.aurora.tray'
APP_VERSION = __version__


def tray_icon(alert: bool = False) -> QIcon:
    icon = QIcon()
    renderer = QSvgRenderer(str(platform_support.resource('icons', 'aurora.svg')))
    for size in (16, 22, 24, 32, 48, 64, 128):
        pixmap = QPixmap(QSize(size, size))
        pixmap.fill(Qt.transparent)
        painter = QPainter(pixmap)
        renderer.render(painter)
        if alert:
            painter.setRenderHint(QPainter.Antialiasing)
            radius = max(2.0, size * 0.16)
            painter.setBrush(QColor('#da4453'))
            painter.setPen(Qt.NoPen)
            center = QPoint(int(size - radius * 1.6), int(size - radius * 1.6))
            painter.drawEllipse(center, int(radius), int(radius))
        painter.end()
        icon.addPixmap(pixmap)
    if sys.platform == 'darwin':
        icon.setIsMask(True)
    return icon


def format_clock(stamp: float, zone, clock24: bool) -> str:
    moment = datetime.fromtimestamp(stamp, zone)
    if clock24:
        return moment.strftime('%H:%M')
    return moment.strftime('%I:%M %p').lstrip('0')


def reminder_text(event: dict, zone, clock24: bool) -> tuple:
    summary = 'Time to wake up' if event['kind'] == 'wake' else 'Bedtime reminder'
    label = 'wake time' if event['kind'] == 'wake' else 'bedtime'
    body = f"{event['name']} — {label} {format_clock(event['target'], zone, clock24)}"
    return summary, body


class AuroraTray(QObject):
    def __init__(self, app: QApplication, self_test: bool = False):
        super().__init__(app)
        self.app = app
        self.self_test = self_test
        self.engine = AlarmEngine(platform_support.data_path('alarms.json'))
        self.backend = Backend(self.engine)
        self.qml = QQmlApplicationEngine()
        self.qml_selector = QQmlFileSelector(self.qml)
        if sys.platform == 'darwin' and QGuiApplication.platformName() == 'cocoa':
            self.qml_selector.setExtraSelectors(['cocoa'])
        self.qml.rootContext().setContextProperty('backend', self.backend)
        self.qml.load(QUrl.fromLocalFile(str(platform_support.resource('qml', 'App.qml'))))
        roots = self.qml.rootObjects()
        if not roots:
            raise RuntimeError('Could not load the Aurora interface.')
        root = roots[0]
        self.popup = root.property('popup')
        self.reminder = root.property('reminder')
        self.native_material = None
        if sys.platform == 'darwin' and QGuiApplication.platformName() == 'cocoa':
            from .macos_appearance import install_material
            theme = root.property('theme')
            self.native_material = install_material(self.popup, int(theme.property('radius')))
            theme.setProperty('nativeMaterial', self.native_material is not None)
        self.popup_content = self.popup.findChild(QObject, 'popupContent')
        if self.popup_content is not None:
            self.popup_content.closeRequested.connect(self.hide_popup)
        self.tray = None
        self.menu = None
        self.server = None
        self._shown_error = ''
        self.backend.remindersChanged.connect(self.update_icon)
        if not self_test:
            self.engine.statusChanged.connect(self.show_error)

    def acquire(self) -> bool:
        socket = QLocalSocket()
        socket.connectToServer(INSTANCE_NAME)
        if socket.waitForConnected(300):
            socket.write(b'open')
            socket.flush()
            socket.waitForBytesWritten(300)
            return False
        QLocalServer.removeServer(INSTANCE_NAME)
        self.server = QLocalServer(self)
        self.server.newConnection.connect(self.peer_connected)
        self.server.listen(INSTANCE_NAME)
        return True

    def peer_connected(self) -> None:
        connection = self.server.nextPendingConnection()
        if connection is not None:
            connection.disconnected.connect(connection.deleteLater)
            self.show_popup()

    def start(self) -> None:
        self.tray = QSystemTrayIcon(tray_icon(), self)
        self.tray.setToolTip('Aurora')
        self.tray.activated.connect(self.tray_activated)
        self.menu = QMenu()
        open_action = self.menu.addAction('Open Aurora')
        open_action.triggered.connect(self.show_popup)
        configure_action = self.menu.addAction('Configure alarms…')
        configure_action.triggered.connect(self.open_settings)
        test_action = self.menu.addAction('Test reminder')
        test_action.triggered.connect(self.backend.testReminder)
        login_action = self.menu.addAction('Start at login')
        login_action.setCheckable(True)
        login_action.setChecked(self.backend.startAtLogin)
        login_action.toggled.connect(self.set_login)
        self.menu.addSeparator()
        quit_action = self.menu.addAction('Quit Aurora')
        quit_action.triggered.connect(self.app.quit)
        self.login_action = login_action
        self.backend.loginItemChanged.connect(self.sync_login)
        self.backend.reminderStarted.connect(self.reminder_started)
        self.engine.changed.connect(self.place_reminder)
        self.app.aboutToQuit.connect(self.engine.shutdown)
        self.tray.show()
        self.update_icon()

    def set_login(self, enabled: bool) -> None:
        if self.backend.startAtLogin == enabled:
            return
        self.backend.startAtLogin = enabled

    def sync_login(self) -> None:
        enabled = self.backend.startAtLogin
        if self.login_action.isChecked() != enabled:
            self.login_action.blockSignals(True)
            self.login_action.setChecked(enabled)
            self.login_action.blockSignals(False)

    def update_icon(self) -> None:
        if self.tray is not None:
            self.tray.setIcon(tray_icon(self.backend.reminderCount > 0))

    def show_error(self) -> None:
        if self.tray is None:
            return
        message = self.backend.error
        if not message:
            self._shown_error = ''
            return
        if message == self._shown_error:
            return
        self._shown_error = message
        self.tray.showMessage('Aurora', message, QSystemTrayIcon.MessageIcon.Warning, 8000)

    def reminder_started(self, key: str) -> None:
        self.place_reminder()
        record = self.engine.active.get(key)
        if record is None or self.tray is None:
            return
        summary, body = reminder_text(record['event'], self.engine.zone, self.backend.clock24)
        self.tray.showMessage(summary, body, QSystemTrayIcon.MessageIcon.Information, 10000)

    def tray_activated(self, reason) -> None:
        log.debug('Tray icon activated: %r', reason)
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            # Some native callbacks do not carry a usable activation reason.
            QSystemTrayIcon.ActivationReason.Unknown,
        ):
            self.toggle_popup()
        elif reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            self.show_popup()
        elif reason == QSystemTrayIcon.ActivationReason.Context:
            self.menu.popup(QCursor.pos())

    def toggle_popup(self) -> None:
        visible = bool(self.popup.property('visible'))
        log.debug('Popup toggle requested; currently visible=%s', visible)
        if visible:
            self.hide_popup()
            return
        self.show_popup()

    def show_popup(self) -> None:
        if not bool(self.popup.property('visible')):
            self.place_window(self.popup)
            self.popup.setProperty('visible', True)
        # On macOS, requestActivate only makes the window key. Raising the
        # window also activates the agent application, even after a tray click.
        self.popup.raise_()
        self.popup.requestActivate()
        if log.isEnabledFor(logging.DEBUG):
            QTimer.singleShot(500, self.log_popup_state)

    def log_popup_state(self) -> None:
        log.debug(
            'Popup state after activation: visible=%s active=%s exposed=%s',
            bool(self.popup.property('visible')),
            bool(self.popup.property('active')),
            self.popup.isExposed(),
        )

    def hide_popup(self) -> None:
        log.debug('Hiding popup')
        self.popup.setProperty('visible', False)

    def open_settings(self) -> None:
        self.show_popup()
        if self.popup_content is not None:
            self.popup_content.setProperty('settingsOpen', True)

    def place_window(self, window) -> None:
        width = int(window.property('width'))
        height = int(window.property('height'))
        geometry = self.tray.geometry() if self.tray is not None else None
        screen = None
        if geometry is not None and not geometry.isNull():
            screen = QGuiApplication.screenAt(geometry.center())
        screen = screen or QGuiApplication.primaryScreen()
        area = screen.availableGeometry()
        if geometry is None or geometry.isNull() or geometry.width() <= 0:
            x = area.right() - width - 8
            y = area.top() + 8
        else:
            x = geometry.center().x() - width // 2
            if geometry.center().y() > area.center().y():
                y = geometry.top() - height - 6
            else:
                y = geometry.bottom() + 6
        x = max(area.left() + 6, min(x, area.right() - width - 6))
        y = max(area.top() + 6, min(y, area.bottom() - height - 6))
        window.setProperty('x', x)
        window.setProperty('y', y)

    def place_reminder(self) -> None:
        if self.self_test or self.backend.reminderCount == 0:
            return
        self.place_window(self.reminder)


def run_self_test(controller: 'AuroraTray') -> None:
    from datetime import datetime, timedelta
    from zoneinfo import ZoneInfo
    ZoneInfo('America/New_York')
    engine = controller.engine
    tomorrow = (datetime.now(engine.zone).date() + timedelta(days=1)).isoformat()
    saved = engine.save(dict(name='Self test', bedMinutes=1320, wakeMinutes=360, wakeDate=tomorrow,
                             days=[], bedEnabled=True, wakeEnabled=True, bedSound=True, wakeSound=True,
                             bedLead=15, snooze=10, volume=70, enabled=True))
    if not any(item['id'] == saved['id'] for item in engine.snapshot()['schedules']):
        raise RuntimeError('Saving an alarm did not persist.')
    engine.remove(saved['id'])
    controller.backend.testReminder()
    if controller.backend.reminderCount != 1:
        raise RuntimeError('Reminder delivery failed.')
    controller.backend.dismissReminder('test')
    controller.popup.setProperty('visible', True)


def install_excepthook(logger) -> None:
    def handler(exc_type, exc_value, exc_traceback):
        logger.critical('Unhandled exception', exc_info=(exc_type, exc_value, exc_traceback))
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
    sys.excepthook = handler


def main(argv=None) -> int:
    argv = list(sys.argv if argv is None else argv)
    if '--uninstall-autostart' in argv:
        platform_support.set_enabled(False)
        return 0
    self_test = '--self-test' in argv
    if self_test:
        os.environ.setdefault('AURORA_DATA_DIR', tempfile.mkdtemp(prefix='aurora-selftest-'))
    QCoreApplication.setOrganizationName(platform_support.ORG_NAME)
    QCoreApplication.setApplicationName(platform_support.APP_NAME)
    QCoreApplication.setApplicationVersion(APP_VERSION)
    app = QApplication(argv)
    if sys.platform == 'darwin' and QGuiApplication.platformName() == 'cocoa':
        from PySide6.QtQuickControls2 import QQuickStyle
        QQuickStyle.setStyle('macOS')
    app.setQuitOnLastWindowClosed(False)
    app.setWindowIcon(tray_icon())
    logger = logging_setup.configure('--debug' in argv)
    install_excepthook(logger)
    logger.info('Aurora %s starting', APP_VERSION)
    try:
        controller = AuroraTray(app, self_test=self_test)
    except RuntimeError as error:
        logger.critical('Could not start: %s', error)
        print(error, file=sys.stderr)
        return 1
    if self_test:
        try:
            run_self_test(controller)
        except Exception as error:
            logger.critical('Self-test failed: %s', error)
            print(f'self-test failed: {error}', file=sys.stderr)
            return 1
        QTimer.singleShot(600, app.quit)
        code = app.exec()
        if code == 0:
            print('self-test ok')
        return code
    if not controller.acquire():
        logger.info('Another instance is already running; asked it to open.')
        return 0
    controller.start()
    logger.info('Ready with %d schedules.', len(controller.backend.schedules))
    return app.exec()
