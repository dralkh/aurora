import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    property QtObject colorSource
    readonly property color background: colorSource ? colorSource.Kirigami.Theme.backgroundColor : Kirigami.Theme.backgroundColor
    readonly property color surface: colorSource ? colorSource.Kirigami.Theme.alternateBackgroundColor : Kirigami.Theme.alternateBackgroundColor
    readonly property color raised: colorSource ? colorSource.Kirigami.Theme.backgroundColor : Kirigami.Theme.backgroundColor
    readonly property color text: colorSource ? colorSource.Kirigami.Theme.textColor : Kirigami.Theme.textColor
    readonly property color muted: colorSource ? colorSource.Kirigami.Theme.disabledTextColor : Kirigami.Theme.disabledTextColor
    readonly property color accent: colorSource ? colorSource.Kirigami.Theme.highlightColor : Kirigami.Theme.highlightColor
    readonly property color accentDeep: colorSource ? colorSource.Kirigami.Theme.highlightColor : Kirigami.Theme.highlightColor
    readonly property color cyan: colorSource ? colorSource.Kirigami.Theme.linkColor : Kirigami.Theme.linkColor
    readonly property color negative: colorSource ? colorSource.Kirigami.Theme.negativeTextColor : Kirigami.Theme.negativeTextColor
    readonly property color border: colorSource ? colorSource.Kirigami.Theme.disabledTextColor : Kirigami.Theme.disabledTextColor
    readonly property color highlightText: colorSource ? colorSource.Kirigami.Theme.highlightedTextColor : Kirigami.Theme.highlightedTextColor
    readonly property int smallFontSize: Kirigami.Theme.smallFont.pixelSize
    readonly property int spacing: Kirigami.Units.smallSpacing
    readonly property int largeSpacing: Kirigami.Units.largeSpacing
    readonly property int radius: Kirigami.Units.cornerRadius
}
