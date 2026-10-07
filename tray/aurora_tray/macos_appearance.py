"""AppKit material behind a transparent Qt Quick window.

Keep Qt's content view and responder hierarchy intact. The material is a
sibling behind that view, owned by the native window. AppKit handles appearance
changes, Liquid Glass preferences, and accessibility transparency settings.
"""
from __future__ import annotations

import ctypes
import logging

log = logging.getLogger('aurora.appearance')


class _Point(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]


class _Size(ctypes.Structure):
    _fields_ = [('width', ctypes.c_double), ('height', ctypes.c_double)]


class _Rect(ctypes.Structure):
    _fields_ = [('origin', _Point), ('size', _Size)]


class MacMaterial:
    def __init__(self, window, radius: float):
        self.window = window
        self.radius = radius
        self._objc = ctypes.CDLL('/usr/lib/libobjc.A.dylib')
        self._objc.objc_getClass.argtypes = [ctypes.c_char_p]
        self._objc.objc_getClass.restype = ctypes.c_void_p
        self._objc.sel_registerName.argtypes = [ctypes.c_char_p]
        self._objc.sel_registerName.restype = ctypes.c_void_p
        self._calls = {}
        self._selectors = {}
        self.effect = None
        self.kind = None

    def _send(self, result, receiver, selector, *args):
        types = tuple(arg[0] for arg in args)
        key = (result, types)
        if key not in self._calls:
            self._calls[key] = ctypes.CFUNCTYPE(
                result, ctypes.c_void_p, ctypes.c_void_p, *types
            )(('objc_msgSend', self._objc))
        if selector not in self._selectors:
            self._selectors[selector] = self._objc.sel_registerName(selector.encode())
        return self._calls[key](receiver, self._selectors[selector], *(arg[1] for arg in args))

    def install(self) -> bool:
        pointer, integer, boolean = ctypes.c_void_p, ctypes.c_long, ctypes.c_bool
        # winId() is the NSView pointer on Qt's Cocoa platform.
        view = int(self.window.winId())
        parent = self._send(pointer, view, 'superview')
        native_window = self._send(pointer, view, 'window')
        if not parent or not native_window:
            return False

        glass_class = self._objc.objc_getClass(b'NSGlassEffectView')
        effect_class = glass_class or self._objc.objc_getClass(b'NSVisualEffectView')
        if not effect_class:
            return False
        allocated = self._send(pointer, effect_class, 'alloc')
        self.effect = self._send(pointer, allocated, 'initWithFrame:', (_Rect, self._frame()))
        if not self.effect:
            return False
        self.kind = 'Liquid Glass' if glass_class else 'popover material'
        self._send(None, self.effect, 'setAutoresizingMask:', (ctypes.c_ulong, 18))
        self._send(None, self.effect, 'setWantsLayer:', (boolean, True))
        if glass_class:
            self._send(None, self.effect, 'setStyle:', (integer, 0))  # Regular, for readable popovers.
            self._send(None, self.effect, 'setCornerRadius:', (ctypes.c_double, self.radius))
        else:
            self._send(None, self.effect, 'setMaterial:', (integer, 6))  # Popover.
            self._send(None, self.effect, 'setBlendingMode:', (integer, 0))  # Behind window.
            self._send(None, self.effect, 'setState:', (integer, 1))  # Active while the popup is visible.

        # Clip both the native material and Qt content to the same outer shape.
        for target in (view, self.effect):
            self._send(None, target, 'setWantsLayer:', (boolean, True))
            layer = self._send(pointer, target, 'layer')
            self._send(None, layer, 'setCornerRadius:', (ctypes.c_double, self.radius))
            self._send(None, layer, 'setMasksToBounds:', (boolean, True))
        clear_color = self._send(pointer, self._objc.objc_getClass(b'NSColor'), 'clearColor')
        self._send(None, native_window, 'setOpaque:', (boolean, False))
        self._send(None, native_window, 'setBackgroundColor:', (pointer, clear_color))
        self._send(None, native_window, 'setHasShadow:', (boolean, True))
        self._send(None, parent, 'addSubview:positioned:relativeTo:',
                   (pointer, self.effect), (integer, -1), (pointer, view))
        self._send(None, self.effect, 'release')  # The parent now owns the material.
        self.window.widthChanged.connect(self.resize)
        self.window.heightChanged.connect(self.resize)
        log.debug('Installed native macOS %s', self.kind)
        return True

    def _frame(self):
        return _Rect(_Point(0, 0), _Size(self.window.width(), self.window.height()))

    def resize(self, *args):
        if self.effect:
            self._send(None, self.effect, 'setFrame:', (_Rect, self._frame()))


def install_material(window, radius: float):
    """Return the installed material, or leave Qt's solid fallback in place."""
    try:
        material = MacMaterial(window, radius)
        return material if material.install() else None
    except (OSError, TypeError, ValueError):
        log.exception('Could not install native macOS material')
        return None
