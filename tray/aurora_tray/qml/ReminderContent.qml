import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SleepMath.js" as MathUtil

Item {
    id: reminder
    objectName: "reminderContent"
    property QtObject theme
    implicitHeight: layout.implicitHeight + 2 * theme.largeSpacing

    Rectangle {
        anchors.fill: parent
        radius: theme.radius
        color: theme.surface
        border.width: 1
        border.color: theme.border

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: theme.largeSpacing
            spacing: theme.spacing

            Label {
                text: "Aurora reminder"
                font.pixelSize: theme.smallFontSize
                color: theme.muted
                Layout.fillWidth: true
            }
            Repeater {
                model: backend.reminders
                RowLayout {
                    id: entry
                    required property var modelData
                    readonly property int targetMinutes: {
                        var date = new Date(entry.modelData.target * 1000);
                        return date.getHours() * 60 + date.getMinutes();
                    }
                    Layout.fillWidth: true
                    spacing: theme.spacing
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            text: entry.modelData.kind === "wake" ? "Time to wake up" : "Bedtime reminder"
                            font.weight: Font.DemiBold
                            color: theme.text
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            text: entry.modelData.name + " · " + (backend.clock24
                                  ? MathUtil.time(entry.targetMinutes, true)
                                  : MathUtil.time(entry.targetMinutes, false) + " " + MathUtil.period(entry.targetMinutes))
                            color: theme.muted
                            font.pixelSize: theme.smallFontSize
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                    Button {
                        text: "Snooze " + entry.modelData.snooze + " min"
                        onClicked: backend.snoozeReminder(entry.modelData.key)
                        Accessible.name: "Snooze " + entry.modelData.snooze + " minutes"
                    }
                    Button {
                        text: "Dismiss"
                        onClicked: backend.dismissReminder(entry.modelData.key)
                        Accessible.name: "Dismiss reminder"
                    }
                }
            }
        }
    }
}
