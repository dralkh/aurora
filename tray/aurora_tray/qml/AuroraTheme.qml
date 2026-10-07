import QtQuick

QtObject {
    readonly property bool nativeMac: Qt.platform.os === "osx"
    property bool nativeMaterial: false
    readonly property SystemPalette systemColors: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property SystemPalette disabledColors: SystemPalette { colorGroup: SystemPalette.Disabled }
    readonly property color background: nativeMac ? systemColors.window : "#101622"
    readonly property bool dark: background.hslLightness < 0.5
    readonly property color surface: nativeMac ? Qt.rgba(text.r, text.g, text.b, dark ? 0.08 : 0.045) : "#1b2433"
    readonly property color raised: nativeMac ? systemColors.button : "#242e40"
    readonly property color text: nativeMac ? systemColors.windowText : "#f3f4fb"
    readonly property color muted: nativeMac ? Qt.rgba(text.r, text.g, text.b, 0.68) : "#a3afc4"
    readonly property color accent: nativeMac ? systemColors.accent : "#a77aff"
    readonly property color accentDeep: nativeMac ? Qt.darker(accent, 1.15) : "#7545e5"
    readonly property color cyan: nativeMac ? accent : "#63dbe5"
    readonly property color negative: nativeMac ? (dark ? "#ff6961" : "#c62828") : "#ff9cae"
    readonly property color border: nativeMac ? Qt.rgba(text.r, text.g, text.b, 0.14) : "#35425a"
    function linear(channel) {
        return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    }
    readonly property real accentLuminance: 0.2126 * linear(accent.r) + 0.7152 * linear(accent.g) + 0.0722 * linear(accent.b)
    readonly property color highlightText: nativeMac && accentLuminance > 0.179 ? "#000000" : "#ffffff"
    readonly property int smallFontSize: 11
    readonly property int spacing: 6
    readonly property int largeSpacing: 16
    readonly property int radius: nativeMac ? 20 : 14
}
