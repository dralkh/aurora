import QtQuick
import QtQuick.Window

QtObject {
    id: app
    property QtObject theme: Theme { }

    property QtObject popup: Window {
        id: popupWindow
        objectName: "popupWindow"
        width: app.theme.nativeMac ? 368 : 430
        height: app.theme.nativeMac ? 620 : 700
        visible: false
        color: "transparent"
        // macOS hides Tool panels while the menu bar agent is inactive.
        flags: (Qt.platform.os === "osx" ? Qt.Window : Qt.Tool)
               | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        property bool ready: false

        onActiveChanged: {
            if (active && visible) ready = true
            else if (ready && visible && !active) visible = false
        }
        onVisibleChanged: if (!visible) ready = false
        Rectangle {
            anchors.fill: parent
            radius: app.theme.radius
            color: app.theme.nativeMaterial ? "transparent" : app.theme.background
            border.width: app.theme.nativeMaterial ? 0 : 1
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
