import QtQuick
import QtQuick.Controls.Basic

TabButton {
    id: control
    implicitHeight: 38
    contentItem: Text {
        text: control.text; font: control.font
        color: control.checked ? "#f3f4fb" : "#a3afc4"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: control.hovered ? "#242e40" : "#1b2433"
        radius: 6
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 3; radius: 1.5; visible: control.checked; color: "#a77aff"
        }
        border.color: control.activeFocus ? "#63dbe5" : "transparent"
    }
}
