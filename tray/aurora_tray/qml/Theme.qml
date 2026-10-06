import QtQuick
import QtQuick.Controls

QtObject {
    readonly property bool dark: Application.styleHints.colorScheme === Qt.Dark
    readonly property color background: dark ? "#1c1e21" : "#fcfcfc"
    readonly property color surface: dark ? "#26282c" : "#ffffff"
    readonly property color text: dark ? "#eff0f1" : "#232629"
    readonly property color muted: dark ? "#8d9095" : "#7a7d81"
    readonly property color accent: dark ? "#3daee9" : "#1d99f3"
    readonly property color negative: dark ? "#f28b8b" : "#c0392b"
    readonly property color border: dark ? "#3b3e42" : "#d5d7d9"
    readonly property color highlightText: "#ffffff"
    readonly property int smallFontSize: 11
    readonly property int spacing: 6
    readonly property int largeSpacing: 12
    readonly property int radius: 10
}
