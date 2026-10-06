import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: control
    color: "#f3f4fb"
    placeholderTextColor: "#a3afc4"
    implicitHeight: 38
    leftPadding: 12; rightPadding: 12
    background: Rectangle {
        radius: 8; color: "#101622"
        border.color: control.activeFocus ? "#a77aff" : "#35425a"
    }
}
