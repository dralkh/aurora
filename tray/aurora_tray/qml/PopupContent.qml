import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SleepMath.js" as MathUtil

Item {
    id: view
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
    function savedIndex() {
        for (var i = 0; i < backend.schedules.length; i++)
            if (backend.schedules[i].id === view.selectedId) return i + 1;
        return 0;
    }
    function updateSelector() {
        selector.currentIndex = savedIndex();
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
            updateSelector();
        } else {
            status = response.error || "Could not set alarm.";
            statusError = true;
        }
    }
    function chooseSaved(schedule) {
        if (!schedule) {
            selectedId = "";
            alarmName = "Sleep schedule";
            return;
        }
        selectedId = schedule.id;
        alarmName = schedule.name;
        nameField.text = schedule.name;
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
            updateSelector();
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
        anchors.top: parent.top
        anchors.margins: theme.largeSpacing
        spacing: theme.spacing

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Aurora"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: theme.text
                Layout.fillWidth: true
            }
            Button {
                objectName: "setAlarm"
                text: "Set alarm"
                enabled: !view.busy
                onClicked: view.setAlarm()
                Accessible.name: "Set alarm"
            }
            Button {
                objectName: "configureAlarms"
                text: "Configure"
                onClicked: { view.settingsOpen = true; view.updateSelector(); }
                Accessible.name: "Configure alarms"
            }
            CheckBox {
                text: "24-hour"
                checked: backend.clock24
                onToggled: backend.clock24 = checked
                Accessible.name: "Use 24-hour clock"
            }
        }
        TabBar {
            Layout.fillWidth: true
            currentIndex: backend.mode
            onCurrentIndexChanged: {
                if (backend.mode !== currentIndex) backend.mode = currentIndex;
            }
            TabButton { text: "Wake at" }
            TabButton { text: "Bed at" }
            TabButton { text: "Sleep now" }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: theme.spacing
            Label {
                text: backend.mode === 0 ? "Wake time:" : backend.mode === 1 ? "Bedtime:" : "Current time:"
                color: theme.text
                Layout.fillWidth: true
            }
            TextField {
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
            ComboBox {
                visible: !backend.clock24
                enabled: backend.mode !== 2
                Layout.preferredWidth: 82
                Accessible.name: "AM or PM"
                model: ["AM", "PM"]
                Component.onCompleted: currentIndex = MathUtil.period(view.anchor) === "PM" ? 1 : 0
                onActivated: function(index) { view.setTarget(view.anchor % 720 + index * 720); }
                Connections {
                    target: view
                    function onAnchorChanged() {
                        parent.currentIndex = MathUtil.period(view.anchor) === "PM" ? 1 : 0;
                    }
                }
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
            SpinBox {
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
                Button {
                    id: tile
                    required property int index
                    readonly property int minutes: MathUtil.result(view.anchor, index + 1, backend.latency, backend.mode)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 110
                    Layout.minimumHeight: 46
                    font.pixelSize: theme.smallFontSize
                    checkable: true
                    checked: backend.cycles === index + 1
                    text: ((index + 1) * 1.5).toFixed(1) + "h · " + MathUtil.time(minutes, backend.clock24) + (backend.clock24 ? "" : " " + MathUtil.period(minutes))
                    onClicked: backend.cycles = index + 1
                    Accessible.name: (index + 1) + " cycles, " + ((index + 1) * 1.5) + " hours sleep, " + MathUtil.time(minutes, backend.clock24)
                }
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

    Rectangle {
        id: settings
        objectName: "alarmSettings"
        anchors.fill: parent
        color: theme.background
        visible: view.settingsOpen
        z: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: theme.largeSpacing
            spacing: theme.spacing
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Alarms"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: theme.text
                    Layout.fillWidth: true
                }
                Button {
                    text: "Close"
                    onClicked: view.settingsOpen = false
                    Accessible.name: "Close settings"
                }
            }
            Label {
                text: backend.error
                visible: backend.error !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: theme.negative
                font.pixelSize: theme.smallFontSize
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: form.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { }

                ColumnLayout {
                    id: form
                    width: parent.width
                    spacing: theme.spacing
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: selector
                            objectName: "savedAlarmSelector"
                            Layout.fillWidth: true
                            Accessible.name: "Saved alarms"
                            model: ["New alarm"].concat(backend.schedules.map(function(s) { return s.name; }))
                            onActivated: function(index) {
                                view.chooseSaved(index === 0 ? null : backend.schedules[index - 1]);
                            }
                        }
                        Button {
                            text: "Delete"
                            enabled: view.selectedId !== ""
                            onClicked: view.deleteSelected()
                            Accessible.name: "Delete this alarm"
                        }
                    }
                    TextField {
                        id: nameField
                        objectName: "alarmName"
                        Layout.fillWidth: true
                        placeholderText: "Alarm name"
                        maximumLength: 80
                        text: view.alarmName
                        onTextEdited: view.alarmName = text
                        Accessible.name: "Alarm name"
                    }
                    Label {
                        text: "Bed " + view.timeLabel(view.chosenBed) + " · Wake " + view.timeLabel(view.chosenWake)
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: theme.text
                        font.pixelSize: theme.smallFontSize
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
                    RowLayout {
                        Layout.fillWidth: true
                        CheckBox {
                            objectName: "bedAlarmEnabled"
                            text: "Bedtime reminder"
                            Layout.fillWidth: true
                            checked: view.bedEnabled
                            onToggled: view.bedEnabled = checked
                            Accessible.name: "Bedtime reminder"
                        }
                        CheckBox {
                            text: "Sound"
                            checked: view.bedSound
                            enabled: view.bedEnabled
                            onToggled: view.bedSound = checked
                            Accessible.name: "Bedtime sound"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Before bedtime"; color: theme.text; Layout.fillWidth: true }
                        SpinBox {
                            objectName: "bedAlarmLead"
                            from: 0
                            to: 120
                            editable: true
                            Layout.preferredWidth: 110
                            enabled: view.bedEnabled
                            value: view.bedLead
                            onValueModified: view.bedLead = value
                            Accessible.name: "Minutes before bedtime"
                        }
                        Label { text: "min"; color: theme.text }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        CheckBox {
                            objectName: "wakeAlarmEnabled"
                            text: "Wake-up alarm"
                            Layout.fillWidth: true
                            checked: view.wakeEnabled
                            onToggled: view.wakeEnabled = checked
                            Accessible.name: "Wake-up alarm"
                        }
                        CheckBox {
                            text: "Sound"
                            checked: view.wakeSound
                            enabled: view.wakeEnabled
                            onToggled: view.wakeSound = checked
                            Accessible.name: "Wake-up sound"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Snooze"; color: theme.text; Layout.fillWidth: true }
                        SpinBox {
                            from: 1
                            to: 60
                            editable: true
                            Layout.preferredWidth: 110
                            value: view.snooze
                            onValueModified: view.snooze = value
                            Accessible.name: "Snooze minutes"
                        }
                        Label { text: "min"; color: theme.text }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Volume"; color: theme.text }
                        Slider {
                            from: 0
                            to: 100
                            stepSize: 1
                            Layout.fillWidth: true
                            value: view.volume
                            onMoved: view.volume = Math.round(value)
                            Accessible.name: "Alarm volume"
                        }
                        Label { text: view.volume + "%"; color: theme.text; Layout.minimumWidth: 40 }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
                    Label {
                        text: "Repeat on wake-up days"
                        color: theme.text
                        font.pixelSize: theme.smallFontSize
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            Button {
                                required property int index
                                required property string modelData
                                text: modelData
                                font.pixelSize: theme.smallFontSize
                                checkable: true
                                Layout.fillWidth: true
                                Layout.preferredWidth: 40
                                checked: view.repeatDays.indexOf(index) >= 0
                                onClicked: {
                                    var days = view.repeatDays.slice(), at = days.indexOf(index);
                                    if (at >= 0) days.splice(at, 1); else days.push(index);
                                    view.repeatDays = days;
                                }
                                Accessible.name: "Repeat on " + modelData
                            }
                        }
                    }
                    Label {
                        text: view.repeatDays.length ? "Bedtime reminders fall on the preceding evening when needed." : "One-time alarm for the next wake-up time."
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: theme.muted
                        font.pixelSize: theme.smallFontSize
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        CheckBox {
                            visible: view.selectedId !== ""
                            text: "Enabled"
                            checked: {
                                for (var i = 0; i < backend.schedules.length; i++)
                                    if (backend.schedules[i].id === view.selectedId) return backend.schedules[i].enabled;
                                return true;
                            }
                            onToggled: backend.toggleSchedule(view.selectedId, checked)
                            Accessible.name: "Alarm enabled"
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Test"
                            enabled: backend.available
                            onClicked: backend.testReminder()
                            Accessible.name: "Test reminder"
                        }
                        Button {
                            text: "Set alarm"
                            enabled: !view.busy
                            onClicked: view.setAlarm()
                            Accessible.name: "Set alarm"
                        }
                    }
                    Repeater {
                        model: backend.pending
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label {
                                text: view.pendingLabel(modelData)
                                color: theme.text
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: theme.smallFontSize
                            }
                            Button {
                                text: "Dismiss"
                                onClicked: backend.dismissReminder(modelData.key)
                                Accessible.name: "Dismiss reminder"
                            }
                            Button {
                                visible: !modelData.snoozed
                                text: "Snooze"
                                onClicked: backend.snoozeReminder(modelData.key)
                                Accessible.name: "Snooze reminder"
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
                    CheckBox {
                        text: "Start Aurora at login"
                        checked: backend.startAtLogin
                        onToggled: backend.startAtLogin = checked
                        Accessible.name: "Start Aurora at login"
                    }
                    Button {
                        text: "Quit Aurora"
                        onClicked: backend.quit()
                        Accessible.name: "Quit Aurora"
                    }
                }
            }
        }
    }
}
