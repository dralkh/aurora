import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PC
import "SleepMath.js" as MathUtil

Item {
    id: view
    implicitWidth: 420
    implicitHeight: Math.max(640, Kirigami.Units.gridUnit * 36)
    readonly property bool compact: height < Kirigami.Units.gridUnit * 30
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
    function chooseCycle(count) {
        if (count < 1 || count > 6) return;
        view.cycles = count;
        view.preferencesChanged();
    }
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
        id: calculatorLayout
        objectName: "calculatorLayout"
        anchors.fill: parent
        anchors.margins: view.compact ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/aurora.svg")
                isMask: true
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            Kirigami.Heading { text: "Aurora Sleep"; level: 3; Layout.fillWidth: true }
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
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: view.compact ? 2 : 1
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            RowLayout {
                Layout.row: 0
                Layout.column: view.compact ? 1 : 0
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                PC.Label { visible: !view.compact; text: view.mode === 0 ? "Wake time:" : view.mode === 1 ? "Bedtime:" : "Current time:"; Layout.fillWidth: true }
                PC.TextField {
                    id: targetInput
                    objectName: "targetInput"
                    Layout.preferredWidth: view.compact ? 75 : 82
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
                    Layout.preferredWidth: view.compact ? 65 : 77
                    model: ["AM", "PM"]
                    currentIndex: MathUtil.period(view.anchor) === "PM" ? 1 : 0
                    onActivated: function(index) { view.setTarget(view.anchor % 720 + index * 720); }
                    Accessible.name: "AM or PM"
                }
            }
            Item {
                Layout.row: view.compact ? 0 : 1
                Layout.column: 0
                Layout.rowSpan: view.compact ? 3 : 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: view.compact ? 140 : 0
                Layout.preferredWidth: view.compact ? view.width * 0.44 : -1
                Layout.minimumHeight: view.compact ? 150 : 200
                SleepDial {
                    id: dial
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    accent: Kirigami.Theme.highlightColor
                    foreground: Kirigami.Theme.textColor
                    muted: Kirigami.Theme.disabledTextColor
                    backgroundColor: Kirigami.Theme.backgroundColor
                    highlightedTextColor: Kirigami.Theme.highlightedTextColor
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
                    width: dial.width * (view.compact ? 0.66 : 0.55)
                    spacing: view.compact ? 2 : 4
                    PC.Label {
                        text: view.mode === 0 ? (view.compact ? "Bedtime" : "Go to bed at") : (view.compact ? "Wake up" : "Wake up at")
                        font.pixelSize: view.compact ? Kirigami.Theme.smallFont.pixelSize : Kirigami.Theme.defaultFont.pixelSize
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PC.Label {
                        text: MathUtil.time(view.result, view.clock24) + (view.clock24 ? "" : " " + MathUtil.period(view.result))
                        font.pixelSize: Math.min(30, dial.width * (view.compact ? 0.10 : 0.09))
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    }
                    PC.Label {
                        text: (view.cycles * 1.5).toFixed(1) + (view.compact ? "h · " : " hours · ") + view.cycles + " cycles"
                        font: Kirigami.Theme.smallFont
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    }
                    PC.Label {
                        visible: !view.compact
                        text: view.dayLabel(view.result)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            PC.Label {
                Layout.row: 2
                Layout.column: 0
                visible: !view.compact
                text: view.mode === 2 ? "Choose a cycle count below." : "Drag either handle to adjust the time."
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            }
            RowLayout {
                Layout.row: view.compact ? 1 : 3
                Layout.column: view.compact ? 1 : 0
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                PC.Label { text: view.compact ? "Fall asleep:" : "Time to fall asleep:"; Layout.fillWidth: true }
                PC.SpinBox {
                    objectName: "latencyInput"
                    from: 0; to: 120; value: view.latency; editable: true
                    Layout.preferredWidth: view.compact ? 85 : 115
                    onValueModified: { view.latency = value; view.preferencesChanged(); }
                    Accessible.name: "Minutes to fall asleep"
                }
                PC.Label { text: "min" }
            }
            GridLayout {
                Layout.row: view.compact ? 2 : 4
                Layout.column: view.compact ? 1 : 0
                Layout.fillWidth: true
                columns: view.compact ? 2 : 3
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: 6
                    PC.Button {
                        id: tile
                        objectName: "cycleChoice" + (index + 1)
                        required property int index
                        readonly property int minutes: MathUtil.result(view.anchor, index + 1, view.latency, view.mode)
                        Layout.fillWidth: true
                        Layout.preferredWidth: view.compact ? 85 : 110
                        Layout.minimumHeight: view.compact ? 38 : 42
                        font: Kirigami.Theme.smallFont
                        readonly property bool selected: view.cycles === index + 1
                        // The model owns selection; clicking the active tile cannot deselect it.
                        checkable: false
                        checked: selected
                        Accessible.checkable: true
                        Accessible.checked: selected
                        text: ((index + 1) * 1.5).toFixed(1) + (view.compact ? "h\n" : "h · ") + MathUtil.time(minutes, view.clock24) + (view.clock24 ? "" : " " + MathUtil.period(minutes))
                        onClicked: view.chooseCycle(index + 1)
                        Accessible.name: (index + 1) + " cycles, " + ((index + 1) * 1.5) + " hours sleep, " + MathUtil.time(minutes, view.clock24) + " " + MathUtil.period(minutes)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: (index + 1) + " cycles · " + view.dayLabel(minutes)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PC.Button {
                objectName: "setAlarm"
                Layout.fillWidth: true
                text: "Set alarm"; enabled: view.alarmReady && !view.alarmBusy
                onClicked: view.setAlarmRequested()
            }
            PC.Button {
                id: configureButton
                objectName: "configureAlarms"
                text: "Configure"
                onClicked: view.configureRequested(configureButton)
                Accessible.name: "Configure alarms"
                QQC2.ToolTip.visible: hovered; QQC2.ToolTip.text: "Configure alarms"
            }
        }
        PC.Label {
            objectName: "alarmStatus"
            visible: view.alarmMessage !== ""
            text: view.alarmMessage
            Layout.fillWidth: true; wrapMode: view.compact ? Text.NoWrap : Text.WordWrap
            elide: Text.ElideRight
            QQC2.ToolTip.visible: statusMouse.containsMouse
            QQC2.ToolTip.text: text
            MouseArea { id: statusMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            font: Kirigami.Theme.smallFont
            color: view.alarmError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        }
        PC.Label {
            text: view.compact ? view.dayLabel(view.result) + " · 90-minute cycles · Estimates" : "Based on 90-minute cycles. Times are estimates."
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
        }
    }
}
