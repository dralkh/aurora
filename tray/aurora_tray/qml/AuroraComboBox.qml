import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    implicitHeight: 38
    leftPadding: 12; rightPadding: 28
    palette.text: "#f3f4fb"
    palette.buttonText: "#f3f4fb"
    palette.windowText: "#f3f4fb"
    palette.base: "#1b2433"
    palette.highlight: "#58407f"
    background: Rectangle { radius: 8; color: "#1b2433"; border.color: control.activeFocus ? "#a77aff" : "#35425a" }
    indicator: Text { x: control.width - width - 10; y: (control.height - height) / 2; text: "⌄"; font.pixelSize: 18; color: "#a3afc4" }
}
