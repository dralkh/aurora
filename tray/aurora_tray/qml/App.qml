import QtQuick
import QtQuick.Window

QtObject {
    id: app
    property QtObject theme: Theme { }

    property QtObject popup: Window {
        id: popupWindow
        objectName: "popupWindow"
        width: 430
        height: 700
        visible: false
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        property bool ready: false

        onActiveChanged: if (ready && visible && !active) visible = false
        onVisibleChanged: if (!visible) ready = false

        Timer {
            interval: 250
            running: popupWindow.visible
            onTriggered: popupWindow.ready = true
        }
        Rectangle {
            anchors.fill: parent
            radius: app.theme.radius
            color: app.theme.background
            border.width: 1
            border.color: app.theme.border
            PopupContent {
                anchors.fill: parent
                anchors.margins: 1
                theme: app.theme
            }
        }
    }

    property QtObject reminder: Window {
        id: reminderWindow
        objectName: "reminderWindow"
        width: 400
        height: Math.max(96, reminderContent.implicitHeight)
        visible: backend.reminderCount > 0
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

        ReminderContent {
            id: reminderContent
            width: reminderWindow.width
            theme: app.theme
        }
    }
}
