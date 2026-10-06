import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    implicitWidth: indicator.implicitWidth + (text ? spacing + contentItem.implicitWidth - contentItem.leftPadding : 0) + leftPadding + rightPadding
    implicitHeight: 34
    spacing: 8
    indicator: Rectangle {
        implicitWidth: 38
        implicitHeight: 22
        x: control.leftPadding
        y: (control.height - height) / 2
        radius: 11
        color: control.checked ? "#955cff" : "#35425a"
        border.color: control.activeFocus ? "#63dbe5" : control.checked ? "#b693ff" : "#64718b"
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            width: 16; height: 16; radius: 8
            color: control.enabled ? "#ffffff" : "#a3afc4"
            Behavior on x { NumberAnimation { duration: 130 } }
        }
    }
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "#f3f4fb" : "#a3afc4"
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
