import QtQuick
import QtQuick.Controls.Basic

SpinBox {
    id: control
    implicitHeight: 36
    palette.text: "#f3f4fb"
    palette.base: "#101622"
    background: Rectangle { radius: 8; color: "#101622"; border.color: control.activeFocus ? "#a77aff" : "#35425a" }
    up.indicator: Rectangle {
        x: control.width - width; width: 30; height: control.height; radius: 6
        color: control.up.pressed ? "#58407f" : control.up.hovered ? "#303e55" : "#242e40"
        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 20; color: "#f3f4fb" }
    }
    down.indicator: Rectangle {
        width: 30; height: control.height; radius: 6
        color: control.down.pressed ? "#58407f" : control.down.hovered ? "#303e55" : "#242e40"
        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 20; color: "#f3f4fb" }
    }
}
