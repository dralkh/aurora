import QtQuick
import org.kde.plasma.components
import org.kde.kirigami as Kirigami
import QtQuick.Layouts

Pane {
    id: form
    property var owner
    property var schedules: []
    property var pending: []
    property bool available: true
    property bool busy: false
    property string message: ""
    property bool showLogin: false
    property bool startAtLogin: false
    signal closeRequested()
    signal removeRequested()
    signal toggleRequested(bool enabled)
    signal testRequested()
    signal dismissRequested(string key)
    signal snoozeRequested(string key)
    signal loginRequested(bool enabled)
    signal quitRequested()
    padding: Kirigami.Units.largeSpacing
    implicitWidth: 400
    implicitHeight: 640
    AuroraTheme { id: theme; colorSource: form }
    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon { source: Qt.resolvedUrl("../icons/aurora.svg"); isMask: true; color: theme.text; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Label { Layout.fillWidth: true; text: "Sleep schedule"; font.weight: Font.DemiBold; color: theme.text }
                Label { Layout.fillWidth: true; text: "Make room for rest."; font: Kirigami.Theme.smallFont; color: theme.muted }
            }
            AuroraButton { objectName: "settingsBack"; text: "Back"; onClicked: form.closeRequested(); Accessible.name: "Back to calculator" }
        }
        Label {
            objectName: "scheduleStatus"
            text: form.message
            visible: text !== ""
            color: owner && owner.statusError ? theme.negative : theme.muted
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: scroll.availableWidth
                spacing: Kirigami.Units.largeSpacing
                RowLayout {
                    Layout.fillWidth: true
                    AuroraComboBox {
                        objectName: "savedAlarmSelector"
                        Layout.fillWidth: true
                        model: ["New alarm"].concat(form.schedules.map(function(s) { return s.name; }))
                        currentIndex: {
                            for (var i = 0; i < form.schedules.length; i++)
                                if (owner && form.schedules[i].id === owner.selectedId) return i + 1;
                            return 0;
                        }
                        onActivated: function(index) { owner.chooseSaved(index === 0 ? null : form.schedules[index - 1]); }
                        Accessible.name: "Saved alarms"
                    }
                    AuroraButton { text: "Delete"; enabled: owner && owner.selectedId !== "" && !form.busy; onClicked: form.removeRequested(); Accessible.name: "Delete this alarm" }
                }
                AuroraTextField {
                    objectName: "alarmName"
                    Layout.fillWidth: true; placeholderText: "Alarm name"; maximumLength: 80
                    text: owner ? owner.alarmName : ""
                    onTextEdited: owner.alarmName = text
                    Accessible.name: "Alarm name"
                }
                AuroraCard {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "☾"; font.pixelSize: 24; color: theme.accent; Layout.preferredWidth: 28 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { Layout.fillWidth: true; text: "Bedtime reminder"; color: theme.text; font.weight: Font.DemiBold }
                                Label { text: owner ? owner.timeLabel(owner.chosenBed) : ""; color: theme.muted; font: Kirigami.Theme.smallFont }
                            }
                            AuroraSwitch { objectName: "bedAlarmEnabled"; checked: owner && owner.bedEnabled; onToggled: owner.bedEnabled = checked; Accessible.name: "Bedtime reminder" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Advance notice"; color: theme.muted; Layout.fillWidth: true }
                            AuroraSpinBox { objectName: "bedAlarmLead"; from: 0; to: 120; editable: true; Layout.preferredWidth: 105; enabled: owner && owner.bedEnabled; value: owner ? owner.bedLead : 15; onValueModified: owner.bedLead = value; Accessible.name: "Minutes before bedtime" }
                            Label { text: "min"; color: theme.muted }
                        }
                        AuroraSwitch { objectName: "bedAlarmSound"; text: "Play a sound"; checked: owner && owner.bedSound; enabled: owner && owner.bedEnabled; onToggled: owner.bedSound = checked; Accessible.name: "Bedtime sound" }
                    }
                }
                AuroraCard {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "☀"; font.pixelSize: 24; color: theme.cyan; Layout.preferredWidth: 28 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { Layout.fillWidth: true; text: "Wake-up reminder"; color: theme.text; font.weight: Font.DemiBold }
                                Label { text: owner ? owner.timeLabel(owner.chosenWake) : ""; color: theme.muted; font: Kirigami.Theme.smallFont }
                            }
                            AuroraSwitch { objectName: "wakeAlarmEnabled"; checked: owner && owner.wakeEnabled; onToggled: owner.wakeEnabled = checked; Accessible.name: "Wake-up reminder" }
                        }
                        AuroraSwitch { objectName: "wakeAlarmSound"; text: "Play a sound"; checked: owner && owner.wakeSound; enabled: owner && owner.wakeEnabled; onToggled: owner.wakeSound = checked; Accessible.name: "Wake-up sound" }
                    }
                }
                AuroraCard {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; spacing: 8
                        Label { text: "Repeat days"; color: theme.text; font.weight: Font.DemiBold }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 4
                            Repeater {
                                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                AuroraButton {
                                    required property int index
                                    required property string modelData
                                    objectName: "repeatDay" + index
                                    text: modelData; font: Kirigami.Theme.smallFont; 
                                    Layout.fillWidth: true; Layout.preferredWidth: 32
                                    selected: owner && owner.repeatDays.indexOf(index) >= 0
                                    onClicked: {
                                        var days = owner.repeatDays.slice(), at = days.indexOf(index);
                                        if (at >= 0) days.splice(at, 1); else days.push(index);
                                        owner.repeatDays = days;
                                    }
                                    Accessible.name: "Repeat on " + modelData
                                    Accessible.checkable: true
                                    Accessible.checked: selected
                                }
                            }
                        }
                        Label {
                            text: owner && owner.repeatDays.length ? "Wake-up days. Bedtime may be the evening before." : "One-time alarm at your next wake-up time."
                            color: theme.muted; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
                AuroraCard {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; spacing: 6
                        Label { text: "Sound & snooze"; font.weight: Font.DemiBold; color: theme.text }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Volume"; color: theme.muted }
                            AuroraSlider { objectName: "alarmVolume"; Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; value: owner ? owner.volume : 70; onMoved: owner.volume = Math.round(value); Accessible.name: "Alarm volume" }
                            Label { text: owner ? owner.volume + "%" : ""; color: theme.text; Layout.minimumWidth: 35 }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Snooze"; color: theme.muted; Layout.fillWidth: true }
                            AuroraSpinBox { objectName: "alarmSnooze"; from: 1; to: 60; editable: true; Layout.preferredWidth: 105; value: owner ? owner.snooze : 10; onValueModified: owner.snooze = value; Accessible.name: "Snooze minutes" }
                            Label { text: "min"; color: theme.muted }
                        }
                    }
                }
                AuroraSwitch {
                    visible: owner && owner.selectedId !== ""
                    text: "Schedule enabled"
                    checked: {
                        for (var i = 0; i < form.schedules.length; i++)
                            if (owner && form.schedules[i].id === owner.selectedId) return form.schedules[i].enabled;
                        return true;
                    }
                    onToggled: form.toggleRequested(checked)
                    Accessible.name: "Schedule enabled"
                }
                Repeater {
                    model: form.pending
                    AuroraCard {
                        required property var modelData
                        Layout.fillWidth: true
                        ColumnLayout {
                            anchors.left: parent.left; anchors.right: parent.right
                            Label { text: modelData.name + (modelData.snoozed ? " · Snoozed" : modelData.kind === "bed" ? " · Time to wind down" : " · Time to wake up"); color: theme.text; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            RowLayout {
                                AuroraButton { text: "Snooze"; visible: !modelData.snoozed; onClicked: form.snoozeRequested(modelData.key) }
                                AuroraButton { text: "Dismiss"; onClicked: form.dismissRequested(modelData.key) }
                            }
                        }
                    }
                }
                AuroraSwitch { visible: form.showLogin; text: "Start Aurora at login"; checked: form.startAtLogin; onToggled: form.loginRequested(checked) }
                AuroraButton { visible: form.showLogin; text: "Quit Aurora"; onClicked: form.quitRequested() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            AuroraButton { text: "Test reminder"; enabled: form.available && !form.busy; onClicked: form.testRequested() }
            AuroraButton { objectName: "saveSchedule"; text: owner && owner.selectedId !== "" ? "Update alarm" : "Set alarm"; primary: true; Layout.fillWidth: true; enabled: form.available && !form.busy; onClicked: owner.setAlarm(); Accessible.name: text }
        }
    }
}
