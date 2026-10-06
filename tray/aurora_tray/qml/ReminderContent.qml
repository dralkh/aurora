import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "SleepMath.js" as MathUtil

Pane {
    id: reminder
    objectName: "reminderContent"
    property QtObject theme
    padding: 16
    implicitHeight: layout.implicitHeight + 2 * padding
    background: Rectangle {
        radius: theme.radius; color: theme.background; border.color: theme.accent
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 1; height: 3; radius: 1.5; color: theme.accent }
    }
    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 12
        RowLayout {
            Image { source: "../icons/aurora-mark.svg"; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
            Label { text: "Aurora Sleep"; color: theme.muted; font.pixelSize: 11 }
        }
        Repeater {
            model: backend.reminders
            ColumnLayout {
                id: entry
                required property var modelData
                readonly property int targetMinutes: {
                    var date = new Date(entry.modelData.target * 1000);
                    return date.getHours() * 60 + date.getMinutes();
                }
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 48; Layout.preferredHeight: 48
                        radius: 24; color: "#302547"
                        Label { anchors.centerIn: parent; text: entry.modelData.kind === "wake" ? "☀" : "☾"; font.pixelSize: 28; color: entry.modelData.kind === "wake" ? theme.cyan : theme.accent }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Label { text: entry.modelData.kind === "wake" ? "Time to wake up" : "Time to wind down"; font.pixelSize: 17; font.weight: Font.DemiBold; color: theme.text; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        Label {
                            text: entry.modelData.name + " · " + MathUtil.time(entry.targetMinutes, backend.clock24) + (backend.clock24 ? "" : " " + MathUtil.period(entry.targetMinutes))
                            color: theme.muted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    AuroraButton { objectName: "snoozeReminder"; text: "Snooze " + entry.modelData.snooze + " min"; primary: true; Layout.fillWidth: true; onClicked: backend.snoozeReminder(entry.modelData.key); Accessible.name: "Snooze " + entry.modelData.snooze + " minutes" }
                    AuroraButton { objectName: "dismissReminder"; text: "Dismiss"; Layout.fillWidth: true; onClicked: backend.dismissReminder(entry.modelData.key); Accessible.name: "Dismiss reminder" }
                }
            }
        }
    }
}
