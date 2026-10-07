import QtQuick
import QtQuick.Controls.Basic

TabButton {
    id: control
    AuroraTheme { id: theme }
    implicitHeight: theme.nativeMac ? 30 : 38
    contentItem: Text {
        text: control.text; font: control.font
        color: control.checked ? theme.text : theme.muted
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: theme.nativeMac ? (control.checked ? (theme.dark ? "#636363" : "#ffffff") : control.hovered ? theme.surface : "transparent")
                               : control.hovered ? theme.raised : theme.surface
        radius: 6
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 3; radius: 1.5; visible: control.checked && !theme.nativeMac; color: theme.accent
        }
        border.color: control.activeFocus ? theme.accent : "transparent"
    }
}
