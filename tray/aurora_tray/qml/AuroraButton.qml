import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    property bool primary: false
    property bool selected: false
    property color accent: "#a77aff"
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12
    opacity: enabled ? 1 : 0.45
    background: Rectangle {
        radius: 8
        border.width: 1
        border.color: control.activeFocus ? "#63dbe5" : control.selected || control.primary ? control.accent : control.hovered ? "#64718b" : "#35425a"
        gradient: Gradient {
            GradientStop { position: 0; color: control.down ? "#5c36aa" : control.primary ? "#955cff" : control.selected ? "#58407f" : control.hovered ? "#303e55" : "#252f40" }
            GradientStop { position: 1; color: control.primary ? "#7545e5" : control.selected ? "#3c2c5b" : "#1b2433" }
        }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
    contentItem: Text {
        text: control.text
        font: control.font
        color: "#f3f4fb"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
