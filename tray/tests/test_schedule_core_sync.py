import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / 'package/contents/code/schedule_core.py'
VENDORED = ROOT / 'tray/aurora_tray/schedule_core.py'


class VendoredCore(unittest.TestCase):
    def test_vendored_copy_matches_canonical(self):
        self.assertEqual(CANONICAL.read_bytes(), VENDORED.read_bytes())


if __name__ == '__main__':
    unittest.main()
