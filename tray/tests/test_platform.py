import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from aurora_tray import platform_support

OVERRIDES = ('AURORA_DATA_DIR', 'AURORA_CACHE_DIR', 'AURORA_AUTOSTART_DIR', 'AURORA_AUTOSTART_REGPATH')


class PlatformSupport(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.previous = {name: os.environ.get(name) for name in OVERRIDES}
        os.environ['AURORA_DATA_DIR'] = str(Path(self.temp.name) / 'data')
        os.environ['AURORA_CACHE_DIR'] = str(Path(self.temp.name) / 'cache')
        os.environ['AURORA_AUTOSTART_DIR'] = str(Path(self.temp.name) / 'autostart')
        os.environ['AURORA_AUTOSTART_REGPATH'] = r'Software\DralkTest\AuroraTray'

    def tearDown(self):
        if sys.platform == 'win32':
            import winreg
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, os.environ['AURORA_AUTOSTART_REGPATH'])
            except FileNotFoundError:
                pass
        for name, value in self.previous.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
        self.temp.cleanup()

    def test_data_and_cache_overrides(self):
        self.assertEqual(platform_support.data_path('alarms.json'),
                         Path(self.temp.name) / 'data/alarms.json')
        self.assertTrue(platform_support.data_path('alarms.json').parent.is_dir())
        self.assertEqual(platform_support.cache_dir(), Path(self.temp.name) / 'cache')

    def test_local_zone(self):
        zone = platform_support.local_zone()
        self.assertIsNotNone(zone)
        self.assertIsNotNone(datetime.now(zone))

    def test_autostart_round_trip(self):
        platform_support.set_enabled(True)
        self.assertTrue(platform_support.is_enabled())
        if sys.platform != 'win32':
            self.assertEqual(len(list(Path(os.environ['AURORA_AUTOSTART_DIR']).iterdir())), 1)
        platform_support.set_enabled(False)
        self.assertFalse(platform_support.is_enabled())
        if sys.platform != 'win32':
            self.assertFalse(any(Path(os.environ['AURORA_AUTOSTART_DIR']).iterdir()))

    @unittest.skipUnless(sys.platform.startswith('linux'), 'linux desktop entry')
    def test_linux_entry_runs_runner(self):
        platform_support.set_enabled(True)
        content = (Path(os.environ['AURORA_AUTOSTART_DIR']) / 'aurora-tray.desktop').read_text()
        self.assertIn('run.py', content)
        self.assertIn('Type=Application', content)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS launch agent')
    def test_mac_plist_runs_runner(self):
        import plistlib
        platform_support.set_enabled(True)
        payload = plistlib.loads((Path(os.environ['AURORA_AUTOSTART_DIR']) / f'{platform_support.AUTOSTART_LABEL}.plist').read_bytes())
        self.assertTrue(payload['RunAtLoad'])
        self.assertIn('run.py', ' '.join(payload['ProgramArguments']))


if __name__ == '__main__':
    unittest.main()
