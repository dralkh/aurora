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
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QSettings, QUrl
from PySide6.QtQml import QQmlApplicationEngine


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
