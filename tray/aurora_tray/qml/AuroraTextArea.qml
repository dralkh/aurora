import QtQuick
import QtQuick.Controls

TextArea {
    AuroraTheme { id: colors }
    color: colors.text
    placeholderTextColor: colors.muted
    selectionColor: colors.accent
    selectedTextColor: colors.highlightText
    padding: 10
    background: Rectangle {
        color: colors.surface
        radius: colors.radius
        border.width: 1
        border.color: parent.activeFocus ? colors.accent : colors.border
    }
}
