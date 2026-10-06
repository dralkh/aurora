"""Rotating log file configuration."""
from __future__ import annotations

import logging
from logging.handlers import RotatingFileHandler

from .platform_support import data_path

LOGGER_NAME = 'aurora'


def configure(debug: bool = False) -> logging.Logger:
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(logging.DEBUG if debug else logging.INFO)
    if not logger.handlers:
        file_handler = RotatingFileHandler(data_path('aurora.log'), maxBytes=256 * 1024,
                                           backupCount=2, encoding='utf-8')
        file_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
        logger.addHandler(file_handler)
        if debug:
            stream_handler = logging.StreamHandler()
            stream_handler.setFormatter(logging.Formatter('%(levelname)s %(message)s'))
            logger.addHandler(stream_handler)
    logger.propagate = False
    return logger
