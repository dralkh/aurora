import QtQuick
import QtQuick.Controls

TextArea {
    id: control
    padding: 10
    background: Rectangle {
        color: control.palette.base
        radius: 8
        border.width: 1
        border.color: control.activeFocus ? control.palette.highlight : Qt.rgba(control.palette.text.r, control.palette.text.g, control.palette.text.b, 0.16)
    }
}
