import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from qt_app import application

application()

from aurora_tray.backend import Backend
from aurora_tray.engine import AlarmEngine
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPointF, QSettings, Qt, QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest


class QmlSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.TemporaryDirectory()
        os.environ['AURORA_DATA_DIR'] = cls.root.name
        os.environ['AURORA_CACHE_DIR'] = cls.root.name
        os.environ['AURORA_AUTOSTART_DIR'] = str(Path(cls.root.name) / 'autostart')
        os.environ['AURORA_AUTOSTART_REGPATH'] = r'Software\DralkTest\AuroraTrayQml'
        QSettings.setDefaultFormat(QSettings.Format.IniFormat)
        QSettings.setPath(QSettings.Format.IniFormat, QSettings.Scope.UserScope, cls.root.name)
        cls.engine = AlarmEngine(Path(cls.root.name) / 'alarms.json', start=False)
        cls.backend = Backend(cls.engine)
        cls.qml = QQmlApplicationEngine()
        cls.qml.rootContext().setContextProperty('backend', cls.backend)
        cls.warnings = []
        cls.qml.warnings.connect(cls.collect)
        app = Path(__file__).resolve().parents[1] / 'aurora_tray/qml/App.qml'
        cls.qml.load(QUrl.fromLocalFile(str(app)))
        cls.root_object = cls.qml.rootObjects()[0] if cls.qml.rootObjects() else None
        if cls.root_object is not None:
            cls.popup = cls.root_object.property('popup')
            assert isinstance(cls.popup, QQuickWindow)
            cls.popup.setProperty('visible', True)
            QTest.qWait(50)  # Complete delegate creation and layout before exercising controls.
            cls.popup.setProperty('visible', False)

    @classmethod
    def collect(cls, warnings):
        cls.warnings.extend(warning.toString() for warning in warnings)

    @classmethod
    def tearDownClass(cls):
        cls.engine.shutdown()
        cls.root.cleanup()

    def test_root_object_loaded(self):
        self.assertIsNotNone(self.root_object)

    def test_windows_resolve(self):
        self.assertIsNotNone(self.root_object.property('popup'))
        self.assertIsNotNone(self.root_object.property('reminder'))

    def test_cycle_buttons_update_dial_and_saved_times_in_every_mode(self):
        popup = self.root_object.property('popup')
        content = popup.findChild(QObject, 'popupContent')
        content.setProperty('settingsOpen', False)
        popup.setProperty('visible', True)
        QTest.qWait(30)
        # Repeater delegates live in the visual tree rather than the QObject ownership tree.
        def visual_child(item: QQuickItem, name):
            if item.objectName() == name:
                return item
            for child in item.childItems():
                found = visual_child(child, name)
                if found is not None:
                    return found
            return None

        def click(item):
            point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2)).toPoint()
            QTest.mouseClick(popup, Qt.LeftButton, Qt.NoModifier, point)

        content.setProperty('alarmName', 'Cycle choices')
        content.setProperty('selectedId', '')
        content.setProperty('bedEnabled', True)
        content.setProperty('wakeEnabled', True)
        self.backend.latency = 15
        for mode in range(3):
            self.backend.mode = mode
            for count in range(1, 7):
                choice = visual_child(content, f'cycleChoice{count}')
                self.assertIsNotNone(choice)
                click(choice)
                self.assertEqual(self.backend.cycles, count)
                self.assertEqual(popup.findChild(QObject, 'sleepDial').property('selectedCycle'), count)
                self.assertTrue(choice.property('selected'))
                click(choice)
                self.assertTrue(choice.property('selected'))
                for other in range(1, 7):
                    self.assertEqual(visual_child(content, f'cycleChoice{other}').property('selected'), other == count)
                bed, wake = content.property('chosenBed'), content.property('chosenWake')
                QMetaObject.invokeMethod(content, 'setAlarm')
                saved = next(s for s in self.backend.schedules if s['id'] == content.property('selectedId'))
                self.assertEqual((saved['bedMinutes'], saved['wakeMinutes']), (bed, wake))
                self.assertEqual((wake - bed) % 1440, count * 90 + 15)
        self.backend.removeSchedule(content.property('selectedId'))
        popup.setProperty('visible', False)

    def test_new_schedule_resets_reminder_options(self):
        content = self.root_object.property('popup').findChild(QObject, 'popupContent')
        content.setProperty('repeatDays', [0, 2])
        content.setProperty('bedEnabled', False)
        content.setProperty('volume', 20)
        QMetaObject.invokeMethod(content, 'chooseSaved', Q_ARG('QVariant', None))
        self.assertEqual(list(content.property('repeatDays').toVariant()), [])
        self.assertTrue(content.property('bedEnabled'))
        self.assertEqual(content.property('volume'), 70)

    def test_reminder_buttons_reach_backend(self):
        window = self.root_object.property('reminder')
        stamp = self.engine.now().timestamp()
        for action, kind in [('snoozeReminder', 'bed'), ('dismissReminder', 'wake')]:
            self.engine.deliver(dict(key='test', scheduleId='test', kind=kind,
                                     name='Quiet test', due=stamp, target=stamp,
                                     sound=False, volume=70, snooze=10))
            QTest.qWait(30)
            self.assertTrue(window.property('visible'))
            items = [window.contentItem()]
            button = None
            while items:
                item = items.pop()
                if item.objectName() == action:
                    button = item
                    break
                items.extend(item.childItems())
            self.assertIsNotNone(button)
            point = button.mapToScene(QPointF(button.width() / 2, button.height() / 2)).toPoint()
            QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
            self.assertEqual(self.backend.reminderCount, 0)
        self.assertEqual(self.warnings, [])

    def test_shared_sleep_math_matches_plasma_package(self):
        project = Path(__file__).resolve().parents[2]
        native = project / 'tray/aurora_tray/qml'
        plasma = project / 'package/contents/ui'
        for component in [native / 'SleepMath.js']:
            with self.subTest(component=component.name):
                self.assertEqual(component.read_bytes(), (plasma / component.name).read_bytes())

    def test_no_qml_warnings(self):
        self.assertEqual(self.warnings, [])

    def test_popup_contents_instantiate(self):
        popup = self.root_object.property('popup')
        self.assertIsNotNone(popup.findChild(QObject, 'sleepDial'))
        self.assertIsNotNone(popup.findChild(QObject, 'setAlarm'))
        self.assertIsNotNone(popup.findChild(QObject, 'alarmSettings'))

    def test_save_update_and_load_flow(self):
        popup = self.root_object.property('popup')
        content = popup.findChild(QObject, 'popupContent')
        self.assertIsNotNone(content)
        for schedule in list(self.backend.schedules):
            self.backend.removeSchedule(schedule['id'])
        self.backend.mode = 0
        self.backend.wakeMinutes = 420
        self.backend.cycles = 4
        self.backend.latency = 14
        content.setProperty('alarmName', 'Flow test')
        QMetaObject.invokeMethod(content, 'setAlarm')
        self.assertEqual(len(self.backend.schedules), 1)
        saved = self.backend.schedules[0]
        self.assertEqual(saved['name'], 'Flow test')
        self.assertEqual(saved['wakeMinutes'], 420)
        self.assertEqual(saved['bedMinutes'], (420 - (4 * 90 + 14)) % 1440)
        self.assertEqual(saved['days'], [])
        self.assertNotEqual(content.property('selectedId'), '')
        content.setProperty('repeatDays', [1, 3])
        QMetaObject.invokeMethod(content, 'setAlarm')
        self.assertEqual(len(self.backend.schedules), 1)
        self.assertEqual(list(self.backend.schedules[0]['days']), [1, 3])
        QMetaObject.invokeMethod(content, 'chooseSaved', Q_ARG('QVariant', self.backend.schedules[0]))
        self.assertEqual(content.property('alarmName'), 'Flow test')
        self.assertEqual(list(content.property('repeatDays').toVariant()), [1, 3])

    def test_save_rejects_missing_name(self):
        popup = self.root_object.property('popup')
        content = popup.findChild(QObject, 'popupContent')
        before = len(self.backend.schedules)
        content.setProperty('alarmName', '   ')
        QMetaObject.invokeMethod(content, 'setAlarm')
        self.assertIn('name', str(content.property('status')).lower())
        self.assertEqual(len(self.backend.schedules), before)


if __name__ == '__main__':
    unittest.main()
