import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PC

PC.Popup {
    id: popup
    property var owner
    readonly property var backend: owner ? owner.backend : null
    padding: Kirigami.Units.largeSpacing
    implicitWidth: 380
    implicitHeight: fields.implicitHeight + topPadding + bottomPadding
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    contentItem: PC.ScrollView {
        id: scroller
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
        QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded
        contentWidth: availableWidth
        contentHeight: fields.implicitHeight
        ColumnLayout {
            id: fields
            width: scroller.availableWidth
            spacing: Kirigami.Units.smallSpacing
            PC.Label {
                text: popup.backend ? popup.backend.error || popup.backend.warning : ""
                visible: text !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
            }
            RowLayout {
                Layout.fillWidth: true
                PC.ComboBox {
                    objectName: "savedAlarmSelector"
                    Layout.fillWidth: true
                    model: ["New alarm"].concat(popup.backend ? popup.backend.schedules.map(function(s) { return s.name; }) : [])
                    currentIndex: {
                        if (!popup.owner || !popup.backend) return 0;
                        for (var i = 0; i < popup.backend.schedules.length; i++)
                            if (popup.backend.schedules[i].id === popup.owner.selectedId) return i + 1;
                        return 0;
                    }
                    onActivated: function(index) { popup.owner.chooseSaved(index === 0 ? null : popup.backend.schedules[index - 1]); }
                    Accessible.name: "Saved alarms"
                }
                PC.ToolButton {
                    icon.name: "edit-delete"; enabled: popup.owner && popup.owner.selectedId !== "" && popup.backend && !popup.backend.busy
                    onClicked: popup.backend.request({action: "remove", id: popup.owner.selectedId})
                    QQC2.ToolTip.visible: hovered; QQC2.ToolTip.text: "Delete this alarm"
                    Accessible.name: "Delete this alarm"
                }
            }
            PC.TextField {
                objectName: "alarmName"
                Layout.fillWidth: true; placeholderText: "Alarm name"; maximumLength: 80
                text: popup.owner ? popup.owner.alarmName : ""
                onTextEdited: popup.owner.alarmName = text
            }
            PC.Label { text: popup.owner ? "Bed " + popup.owner.timeLabel(popup.owner.chosenBed) + " · Wake " + popup.owner.timeLabel(popup.owner.chosenWake) : ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont }
            Kirigami.Separator { Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                PC.CheckBox { objectName: "bedAlarmEnabled"; text: "Bedtime reminder"; Layout.fillWidth: true; checked: popup.owner && popup.owner.bedEnabled; onToggled: popup.owner.bedEnabled = checked }
                PC.CheckBox { text: "Sound"; checked: popup.owner && popup.owner.bedSound; enabled: popup.owner && popup.owner.bedEnabled; onToggled: popup.owner.bedSound = checked }
            }
            RowLayout {
                Layout.fillWidth: true
                PC.Label { text: "Before bedtime"; Layout.fillWidth: true }
                PC.SpinBox { objectName: "bedAlarmLead"; from: 0; to: 120; editable: true; Layout.preferredWidth: 100; enabled: popup.owner && popup.owner.bedEnabled; value: popup.owner ? popup.owner.bedLead : 15; onValueModified: popup.owner.bedLead = value }
                PC.Label { text: "min" }
            }
            RowLayout {
                Layout.fillWidth: true
                PC.CheckBox { objectName: "wakeAlarmEnabled"; text: "Wake-up alarm"; Layout.fillWidth: true; checked: popup.owner && popup.owner.wakeEnabled; onToggled: popup.owner.wakeEnabled = checked }
                PC.CheckBox { text: "Sound"; checked: popup.owner && popup.owner.wakeSound; enabled: popup.owner && popup.owner.wakeEnabled; onToggled: popup.owner.wakeSound = checked }
            }
            RowLayout {
                Layout.fillWidth: true
                PC.Label { text: "Snooze"; Layout.fillWidth: true }
                PC.SpinBox { from: 1; to: 60; editable: true; Layout.preferredWidth: 100; value: popup.owner ? popup.owner.snooze : 10; onValueModified: popup.owner.snooze = value }
                PC.Label { text: "min" }
            }
            RowLayout {
                Layout.fillWidth: true
                PC.Label { text: "Volume" }
                PC.Slider { from: 0; to: 100; stepSize: 1; Layout.fillWidth: true; value: popup.owner ? popup.owner.volume : 70; onMoved: popup.owner.volume = Math.round(value) }
                PC.Label { text: popup.owner ? popup.owner.volume + "%" : ""; Layout.minimumWidth: 35 }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            PC.Label { text: "Repeat on wake-up days"; font: Kirigami.Theme.smallFont }
            RowLayout {
                Layout.fillWidth: true; spacing: 2
                Repeater {
                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    PC.Button {
                        required property int index
                        required property string modelData
                        text: modelData; font: Kirigami.Theme.smallFont; checkable: true
                        Layout.fillWidth: true; Layout.preferredWidth: 38
                        checked: popup.owner && popup.owner.repeatDays.indexOf(index) >= 0
                        onClicked: {
                            var days = popup.owner.repeatDays.slice(), at = days.indexOf(index);
                            if (at >= 0) days.splice(at, 1); else days.push(index);
                            popup.owner.repeatDays = days;
                        }
                    }
                }
            }
            PC.Label { text: popup.owner && popup.owner.repeatDays.length ? "Bedtime reminders fall on the preceding evening when needed." : "One-time alarm for the next wake-up time."; Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
            RowLayout {
                Layout.fillWidth: true
                PC.CheckBox {
                    visible: popup.owner && popup.owner.selectedId !== ""
                    text: "Enabled"
                    checked: {
                        if (popup.backend && popup.owner) for (var i = 0; i < popup.backend.schedules.length; i++)
                            if (popup.backend.schedules[i].id === popup.owner.selectedId) return popup.backend.schedules[i].enabled;
                        return true;
                    }
                    onToggled: popup.backend.request({action: "toggle", id: popup.owner.selectedId, enabled: checked})
                }
                Item { Layout.fillWidth: true }
                PC.ToolButton { text: "Test"; enabled: popup.backend && popup.backend.available && !popup.backend.busy; onClicked: popup.backend.request({action: "test"}); }
                PC.Button { text: "Set alarm"; enabled: popup.backend && popup.backend.available && !popup.backend.busy; onClicked: popup.owner.setAlarm(); }
            }
            Repeater {
                model: popup.backend ? popup.backend.pending : []
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    PC.Label { text: modelData.name + (modelData.snoozed ? " · Snoozed" : " · " + (modelData.kind === "bed" ? "Bedtime" : "Wake up")); Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont }
                    PC.ToolButton { text: "Dismiss"; onClicked: popup.backend.request({action: "dismiss", key: modelData.key}); }
                    PC.ToolButton { visible: !modelData.snoozed; text: "Snooze"; onClicked: popup.backend.request({action: "snooze", key: modelData.key}); }
                }
            }
        }
    }
}
