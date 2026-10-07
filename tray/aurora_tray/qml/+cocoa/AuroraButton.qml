import QtQuick
import QtQuick.Controls
import ".." as Shared

Button {
    property bool primary: false
    property bool selected: false
    property color accent: palette.accent
    Shared.AuroraTheme { id: theme }
    palette.buttonText: !enabled ? theme.disabledColors.buttonText : highlighted ? theme.highlightText : theme.text
    palette.highlightedText: theme.highlightText
    highlighted: primary || selected
    checked: selected
}
