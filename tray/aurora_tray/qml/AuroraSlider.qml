import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: control
    background: Rectangle {
        x: control.leftPadding; y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth; height: 4; radius: 2; color: "#35425a"
        Rectangle { width: control.visualPosition * parent.width; height: parent.height; radius: 2; color: "#a77aff" }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 20; height: 20; radius: 10; color: control.pressed ? "#63dbe5" : "#a77aff"
        border.color: control.activeFocus ? "#63dbe5" : "#cbb0ff"
        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "#ffffff" }
    }
}
