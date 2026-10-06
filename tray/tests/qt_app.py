import os

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')

from PySide6.QtCore import QCoreApplication
from PySide6.QtWidgets import QApplication


def application():
    app = QCoreApplication.instance()
    if app is None:
        app = QApplication([])
    QCoreApplication.setOrganizationName('DralkTest')
    QCoreApplication.setApplicationName('AuroraTest')
    return app
