import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "SleepMath.js" as MathUtil

Pane {
    id: view
    padding: 0
    palette.text: theme.text
    palette.windowText: theme.text
    palette.buttonText: theme.text
    palette.base: theme.background
    palette.button: theme.raised
    palette.highlight: theme.accent
    palette.highlightedText: theme.highlightText
    background: Rectangle { radius: theme.radius; color: theme.background }
    objectName: "popupContent"
    signal closeRequested()
    property QtObject theme
    property bool settingsOpen: false
    property bool busy: false
    property string status: ""
    property bool statusError: false
    property string selectedId: ""
    property string alarmName: "Sleep schedule"
    property var repeatDays: []
    property bool bedEnabled: true
    property bool wakeEnabled: true
    property bool bedSound: true
    property bool wakeSound: true
    property int bedLead: 15
    property int snooze: 10
    property int volume: 70
    property var submitted: ({})
    property date now: new Date()

    readonly property int anchor: backend.mode === 0 ? backend.wakeMinutes
                               : backend.mode === 1 ? backend.bedMinutes
                               : now.getHours() * 60 + now.getMinutes()
    readonly property int result: MathUtil.result(anchor, backend.cycles, backend.latency, backend.mode)
    readonly property int chosenBed: MathUtil.wrap(backend.mode === 0 ? result : anchor)
    readonly property int chosenWake: MathUtil.wrap(backend.mode === 0 ? anchor : result)

    Timer {
        interval: 1000
        running: view.visible && backend.mode === 2
        repeat: true
        onTriggered: view.now = new Date()
    }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (view.settingsOpen) view.settingsOpen = false;
            else view.closeRequested();
        }
    }

    function chooseCycle(count) {
        if (count < 1 || count > 6) return;
        backend.cycles = count;
        view.status = "";
        view.statusError = false;
    }
    function setTarget(value) {
        if (backend.mode === 2) return;
        if (backend.mode === 0) backend.wakeMinutes = MathUtil.wrap(value);
        else backend.bedMinutes = MathUtil.wrap(value);
    }
    function dayLabel(value) {
        var offset = MathUtil.dayOffset(value);
        return offset < 0 ? "Previous day" : offset > 0 ? "Next day" : "Same day";
    }
    function dateString(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
    }
    function timeLabel(minutes) {
        return MathUtil.time(minutes, backend.clock24) + (backend.clock24 ? "" : " " + MathUtil.period(minutes));
    }
    function setAlarm() {
        if (busy) return;
        if (!alarmName.trim() || (!bedEnabled && !wakeEnabled)) {
            status = !alarmName.trim() ? "Enter an alarm name in Configure." : "Enable a bedtime or wake-up alarm in Configure.";
            statusError = true;
            settingsOpen = true;
            return;
        }
        var day = new Date();
        day.setHours(Math.floor(chosenWake / 60), chosenWake % 60, 0, 0);
        if (day.getTime() <= Date.now()) day.setDate(day.getDate() + 1);
        var schedule = {name: alarmName.trim(), bedMinutes: chosenBed, wakeMinutes: chosenWake,
                        wakeDate: dateString(day), days: repeatDays.slice(), enabled: true,
                        bedEnabled: bedEnabled, wakeEnabled: wakeEnabled, bedLead: bedLead,
                        bedSound: bedSound, wakeSound: wakeSound, snooze: snooze, volume: volume};
        if (selectedId) schedule.id = selectedId;
        submitted = {bed: chosenBed, wake: chosenWake, bedEnabled: bedEnabled, wakeEnabled: wakeEnabled};
        busy = true;
        var response = backend.saveSchedule(schedule);
        busy = false;
        if (response.ok) {
            if (response.savedId) selectedId = response.savedId;
            var times = [];
            if (submitted.bedEnabled) times.push("Bed " + timeLabel(submitted.bed));
            if (submitted.wakeEnabled) times.push("Wake " + timeLabel(submitted.wake));
            status = "Alarm set · " + times.join(" · ");
            statusError = false;
            settingsOpen = false;
        } else {
            status = response.error || "Could not set alarm.";
            statusError = true;
        }
    }
    function chooseSaved(schedule) {
        if (!schedule) {
        selectedId = ""; alarmName = "Sleep schedule";
        repeatDays = []; bedEnabled = true; wakeEnabled = true;
        bedSound = true; wakeSound = true; bedLead = 15; snooze = 10; volume = 70;
        status = ""; statusError = false;
            return;
        }
        selectedId = schedule.id;
        alarmName = schedule.name;
        repeatDays = schedule.days.slice();
        bedEnabled = schedule.bedEnabled;
        wakeEnabled = schedule.wakeEnabled;
        bedSound = schedule.bedSound;
        wakeSound = schedule.wakeSound;
        bedLead = schedule.bedLead;
        snooze = schedule.snooze;
        volume = schedule.volume;
        var duration = (schedule.wakeMinutes - schedule.bedMinutes + 1440) % 1440;
        var count = Math.max(1, Math.min(6, Math.floor(duration / 90)));
        backend.mode = 0;
        backend.wakeMinutes = schedule.wakeMinutes;
        backend.cycles = count;
        backend.latency = Math.max(0, Math.min(120, duration - count * 90));
        status = "";
        statusError = false;
        updateSelector();
    }
    function deleteSelected() {
        if (!selectedId) return;
        var response = backend.removeSchedule(selectedId);
        if (response.ok) {
            selectedId = "";
            alarmName = "Sleep schedule";
            repeatDays = [];
            status = "Alarm removed.";
            statusError = false;
        } else {
            status = response.error || "Could not remove the alarm.";
            statusError = true;
        }
    }
    function alarmMessage() {
        if (status) return status;
        if (backend.error) return backend.error;
        return "";
    }
    function pendingLabel(event) {
        return event.name + (event.snoozed ? " · Snoozed" : " · " + (event.kind === "bed" ? "Bedtime" : "Wake up"));
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: parent.top
        anchors.margins: theme.largeSpacing
        spacing: theme.spacing

        RowLayout {
            Layout.fillWidth: true
            Image { source: "../icons/aurora-mark.svg"; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Label {
                text: "Aurora Sleep"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: theme.text
                Layout.fillWidth: true
            }
            AuroraSwitch {
                font.pixelSize: 11
                text: "24-hour"
                checked: backend.clock24
                onToggled: backend.clock24 = checked
                Accessible.name: "Use 24-hour clock"
            }
        }
        TabBar {
            background: Rectangle { radius: 8; color: theme.surface }
            spacing: 2
            Layout.fillWidth: true
            currentIndex: backend.mode
            onCurrentIndexChanged: {
                if (backend.mode !== currentIndex) backend.mode = currentIndex;
            }
            AuroraTabButton { text: "Wake at" }
            AuroraTabButton { text: "Bed at" }
            AuroraTabButton { text: "Sleep now" }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: theme.spacing
            Label {
                text: backend.mode === 0 ? "Wake time:" : backend.mode === 1 ? "Bedtime:" : "Current time:"
                color: theme.text
                Layout.fillWidth: true
            }
            AuroraTextField {
                id: targetInput
                objectName: "targetInput"
                Layout.preferredWidth: 86
                text: MathUtil.time(view.anchor, backend.clock24).padStart(5, "0")
                horizontalAlignment: TextInput.AlignHCenter
                readOnly: backend.mode === 2
                selectByMouse: true
                maximumLength: 5
                validator: RegularExpressionValidator {
                    regularExpression: backend.clock24 ? /([01]?[0-9]|2[0-3]):[0-5][0-9]/ : /(0?[1-9]|1[0-2]):[0-5][0-9]/
                }
                onEditingFinished: {
                    var parsed = MathUtil.parse(text, backend.clock24, MathUtil.period(view.anchor) === "PM");
                    if (parsed >= 0) view.setTarget(parsed);
                    text = Qt.binding(function() { return MathUtil.time(view.anchor, backend.clock24).padStart(5, "0"); });
                }
                Accessible.name: "Time, hours colon minutes"
            }
            AuroraComboBox {
                visible: !backend.clock24
                enabled: backend.mode !== 2
                Layout.preferredWidth: 82
                Accessible.name: "AM or PM"
                model: ["AM", "PM"]
                currentIndex: MathUtil.period(view.anchor) === "PM" ? 1 : 0
                onActivated: function(index) { view.setTarget(view.anchor % 720 + index * 720); }

            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            SleepDial {
                id: dial
                Accessible.name: "Sleep time dial"
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                anchor: view.anchor
                latency: backend.latency
                selectedCycle: backend.cycles
                mode: backend.mode
                clock24: backend.clock24
                accent: theme.accent
                foreground: theme.text
                muted: theme.muted
                backgroundColor: theme.background
                highlightedTextColor: theme.highlightText
                onCyclePicked: function(cycle) { backend.cycles = cycle; }
                onAnchorDragged: function(minutes) { view.setTarget(minutes); }
                onResultDragged: function(minutes) {
                    view.setTarget(minutes + (backend.mode === 0 ? 1 : -1) * (backend.cycles * 90 + backend.latency));
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                width: dial.width * 0.55
                spacing: 4
                Label {
                    text: backend.mode === 0 ? "Go to bed at" : "Wake up at"
                    color: theme.muted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: MathUtil.time(view.result, backend.clock24) + (backend.clock24 ? "" : " " + MathUtil.period(view.result))
                    font.pixelSize: Math.min(30, dial.width * 0.09)
                    font.weight: Font.DemiBold
                    color: theme.text
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: (backend.cycles * 1.5).toFixed(1) + " hours · " + backend.cycles + " cycles"
                    font.pixelSize: theme.smallFontSize
                    color: theme.text
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: view.dayLabel(view.result)
                    color: theme.muted
                    font.pixelSize: theme.smallFontSize
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        Label {
            text: backend.mode === 2 ? "Choose a cycle count below." : "Drag either handle to adjust the time."
            color: theme.muted
            font.pixelSize: theme.smallFontSize
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: theme.spacing
            Label { text: "Time to fall asleep:"; color: theme.text; Layout.fillWidth: true }
            AuroraSpinBox {
                objectName: "latencyInput"
                from: 0
                to: 120
                editable: true
                value: backend.latency
                Layout.preferredWidth: 120
                onValueModified: backend.latency = value
                Accessible.name: "Minutes to fall asleep"
            }
            Label { text: "min"; color: theme.text }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: theme.spacing
            rowSpacing: theme.spacing
            Repeater {
                model: 6
                AuroraButton {
                    id: tile
                    objectName: "cycleChoice" + (index + 1)
                    required property int index
                    readonly property int minutes: MathUtil.result(view.anchor, index + 1, backend.latency, backend.mode)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 110
                    Layout.minimumHeight: 48
                    font.pixelSize: theme.smallFontSize
                    selected: backend.cycles === index + 1
                    Accessible.checkable: true
                    Accessible.checked: selected
                    text: ((index + 1) * 1.5).toFixed(1) + "h · " + MathUtil.time(minutes, backend.clock24) + (backend.clock24 ? "" : " " + MathUtil.period(minutes))
                    onClicked: view.chooseCycle(index + 1)
                    Accessible.name: (index + 1) + " cycles, " + ((index + 1) * 1.5) + " hours sleep, " + MathUtil.time(minutes, backend.clock24)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            AuroraButton {
                Layout.fillWidth: true
                objectName: "setAlarm"
                primary: true
                text: "Set alarm"
                enabled: !view.busy
                onClicked: view.setAlarm()
                Accessible.name: "Set alarm"
            }
            AuroraButton {
                objectName: "configureAlarms"
                text: "Configure"
                onClicked: { view.settingsOpen = true; }
                Accessible.name: "Configure alarms"
            }
        }
        Label {
            objectName: "alarmStatus"
            visible: view.alarmMessage() !== ""
            text: view.alarmMessage()
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: theme.smallFontSize
            color: view.statusError ? theme.negative : theme.text
        }
        Label {
            text: "Based on 90-minute cycles. Times are estimates."
            color: theme.muted
            font.pixelSize: theme.smallFontSize
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: theme.spacing
        }
    }

    AuroraScheduleForm {
        objectName: "alarmSettings"
        anchors.fill: parent
        visible: view.settingsOpen
        z: 10
        owner: view
        schedules: backend.schedules
        pending: backend.pending
        available: backend.available
        busy: view.busy
        message: view.status || backend.error
        showLogin: true
        startAtLogin: backend.startAtLogin
        onCloseRequested: view.settingsOpen = false
        onRemoveRequested: view.deleteSelected()
        onToggleRequested: function(enabled) { backend.toggleSchedule(view.selectedId, enabled); }
        onTestRequested: backend.testReminder()
        onDismissRequested: function(key) { backend.dismissReminder(key); }
        onSnoozeRequested: function(key) { backend.snoozeReminder(key); }
        onLoginRequested: function(enabled) { backend.startAtLogin = enabled; }
        onQuitRequested: backend.quit()
    }
}
