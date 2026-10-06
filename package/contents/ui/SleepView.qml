import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PC
import "SleepMath.js" as MathUtil

Item {
    id: view
    implicitWidth: 420
    implicitHeight: 640
    property int wakeMinutes: 360
    property int bedMinutes: 1320
    property int latency: 14
    property int cycles: 5
    property int mode: 0
    property bool clock24: false
    property date now: new Date()
    readonly property int anchor: mode === 0 ? wakeMinutes : mode === 1 ? bedMinutes : now.getHours() * 60 + now.getMinutes()
    readonly property int result: MathUtil.result(anchor, cycles, latency, mode)
    signal preferencesChanged()
    property bool alarmReady: true
    property bool alarmBusy: false
    property string alarmMessage: ""
    property bool alarmError: false
    signal setAlarmRequested()
    signal configureRequested(var button)
    function setTarget(value) {
        if (mode === 2) return;
        if (mode === 0) wakeMinutes = MathUtil.wrap(value); else bedMinutes = MathUtil.wrap(value);
        preferencesChanged();
    }
    function dayLabel(value) {
        var offset = MathUtil.dayOffset(value);
        return offset < 0 ? "Previous day" : offset > 0 ? "Next day" : "Same day";
    }
    Timer { interval: 1000; running: view.visible && view.mode === 2; repeat: true; onTriggered: view.now = new Date() }
    onModeChanged: now = new Date()
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -6
        width: Math.min(view.width - 2 * Kirigami.Units.largeSpacing, 460)
        height: Math.min(view.height - 2 * Kirigami.Units.largeSpacing - 12, 640)
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { text: "Aurora"; level: 3; Layout.fillWidth: true }
            PC.Button {
                objectName: "setAlarm"
                text: "Set alarm"; enabled: view.alarmReady && !view.alarmBusy
                onClicked: view.setAlarmRequested()
            }
            PC.ToolButton {
                id: configureButton
                objectName: "configureAlarms"
                icon.name: "configure"
                onClicked: view.configureRequested(configureButton)
                Accessible.name: "Configure alarms"
                QQC2.ToolTip.visible: hovered; QQC2.ToolTip.text: "Configure alarms"
            }
            PC.CheckBox {
                text: "24-hour"; checked: view.clock24
                onToggled: { view.clock24 = checked; view.preferencesChanged(); }
            }
        }
        PC.TabBar {
            Layout.fillWidth: true
            currentIndex: view.mode
            onCurrentIndexChanged: {
                if (view.mode !== currentIndex) { view.mode = currentIndex; view.preferencesChanged(); }
            }
            PC.TabButton { text: "Wake at" }
            PC.TabButton { text: "Bed at" }
            PC.TabButton { text: "Sleep now" }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            PC.Label { text: view.mode === 0 ? "Wake time:" : view.mode === 1 ? "Bedtime:" : "Current time:"; Layout.fillWidth: true }
            PC.TextField {
                id: targetInput
                objectName: "targetInput"
                Layout.preferredWidth: 82
                text: MathUtil.time(view.anchor, view.clock24).padStart(5, "0")
                horizontalAlignment: TextInput.AlignHCenter
                readOnly: view.mode === 2
                selectByMouse: true
                maximumLength: 5
                validator: RegularExpressionValidator { regularExpression: view.clock24 ? /([01]?[0-9]|2[0-3]):[0-5][0-9]/ : /(0?[1-9]|1[0-2]):[0-5][0-9]/ }
                onEditingFinished: {
                    var parsed = MathUtil.parse(text, view.clock24, MathUtil.period(view.anchor) === "PM");
                    if (parsed >= 0) view.setTarget(parsed);
                    text = Qt.binding(function() { return MathUtil.time(view.anchor, view.clock24).padStart(5, "0"); });
                }
                Accessible.name: "Time, hours colon minutes"
            }
            PC.ComboBox {
                visible: !view.clock24
                enabled: view.mode !== 2
                Layout.preferredWidth: 77
                model: ["AM", "PM"]
                currentIndex: MathUtil.period(view.anchor) === "PM" ? 1 : 0
                onActivated: function(index) { view.setTarget(view.anchor % 720 + index * 720); }
                Accessible.name: "AM or PM"
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            SleepDial {
                id: dial
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                anchor: view.anchor; latency: view.latency; selectedCycle: view.cycles; mode: view.mode
                clock24: view.clock24
                onCyclePicked: function(cycle) { view.cycles = cycle; view.preferencesChanged(); }
                onAnchorDragged: function(minutes) { view.setTarget(minutes); }
                onResultDragged: function(minutes) {
                    view.setTarget(minutes + (view.mode === 0 ? 1 : -1) * (view.cycles * 90 + view.latency));
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                width: dial.width * 0.55
                spacing: 4
                PC.Label {
                    text: view.mode === 0 ? "Go to bed at" : "Wake up at"
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    color: Kirigami.Theme.disabledTextColor
                }
                PC.Label {
                    text: MathUtil.time(view.result, view.clock24) + (view.clock24 ? "" : " " + MathUtil.period(view.result))
                    font.pixelSize: Math.min(30, dial.width * 0.09)
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                }
                PC.Label {
                    text: (view.cycles * 1.5).toFixed(1) + " hours · " + view.cycles + " cycles"
                    font: Kirigami.Theme.smallFont
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                }
                PC.Label {
                    text: view.dayLabel(view.result)
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        PC.Label {
            text: view.mode === 2 ? "Choose a cycle count below." : "Drag either handle to adjust the time."
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            PC.Label { text: "Time to fall asleep:"; Layout.fillWidth: true }
            PC.SpinBox {
                objectName: "latencyInput"
                from: 0; to: 120; value: view.latency; editable: true
                Layout.preferredWidth: 115
                onValueModified: { view.latency = value; view.preferencesChanged(); }
                Accessible.name: "Minutes to fall asleep"
            }
            PC.Label { text: "min" }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: 6
                PC.Button {
                    id: tile
                    required property int index
                    readonly property int minutes: MathUtil.result(view.anchor, index + 1, view.latency, view.mode)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 110
                    Layout.minimumHeight: 46
                    font: Kirigami.Theme.smallFont
                    checkable: true
                    checked: view.cycles === index + 1
                    text: ((index + 1) * 1.5).toFixed(1) + "h · " + MathUtil.time(minutes, view.clock24) + (view.clock24 ? "" : " " + MathUtil.period(minutes))
                    onClicked: { view.cycles = index + 1; view.preferencesChanged(); }
                    Accessible.name: (index + 1) + " cycles, " + ((index + 1) * 1.5) + " hours sleep, " + MathUtil.time(minutes, view.clock24) + " " + MathUtil.period(minutes)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: (index + 1) + " cycles · " + view.dayLabel(minutes)
                }
            }
        }
        PC.Label {
            objectName: "alarmStatus"
            visible: view.alarmMessage !== ""
            text: view.alarmMessage
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: view.alarmError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        }
        PC.Label {
            text: "Based on 90-minute cycles. Times are estimates."
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
        }
    }
}
