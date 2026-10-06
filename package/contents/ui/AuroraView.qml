import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC
import org.kde.kirigami 2.20 as Kirigami
import "SleepMath.js" as MathUtil

Item {
    id: view
    implicitWidth: 420
    implicitHeight: 650
    property alias wakeMinutes: calculator.wakeMinutes
    property alias bedMinutes: calculator.bedMinutes
    property alias latency: calculator.latency
    property alias cycles: calculator.cycles
    property alias mode: calculator.mode
    property alias clock24: calculator.clock24
    property var backend
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
    property string status: ""
    property bool statusError: false
    signal preferencesChanged()
    readonly property int chosenBed: MathUtil.wrap(calculator.mode === 0 ? calculator.result : calculator.anchor)
    readonly property int chosenWake: MathUtil.wrap(calculator.mode === 0 ? calculator.anchor : calculator.result)

    function dateString(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
    }
    function timeLabel(minutes) {
        return MathUtil.time(minutes, clock24) + (clock24 ? "" : " " + MathUtil.period(minutes));
    }
    function setAlarm() {
        if (!backend || !backend.available || backend.busy) return;
        if (!alarmName.trim() || (!bedEnabled && !wakeEnabled)) {
            status = !alarmName.trim() ? "Enter an alarm name in Configure." : "Enable a bedtime or wake-up alarm in Configure.";
            statusError = true;
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
        backend.request({action: "save", schedule: schedule});
    }
    function chooseSaved(schedule) {
        if (!schedule) { selectedId = ""; alarmName = "Sleep schedule"; return; }
        selectedId = schedule.id; alarmName = schedule.name;
        repeatDays = schedule.days.slice(); bedEnabled = schedule.bedEnabled; wakeEnabled = schedule.wakeEnabled;
        bedSound = schedule.bedSound; wakeSound = schedule.wakeSound; bedLead = schedule.bedLead;
        snooze = schedule.snooze; volume = schedule.volume;
        var duration = (schedule.wakeMinutes - schedule.bedMinutes + 1440) % 1440;
        var count = Math.max(1, Math.min(6, Math.floor(duration / 90)));
        calculator.mode = 0;
        calculator.wakeMinutes = schedule.wakeMinutes;
        calculator.cycles = count;
        calculator.latency = Math.max(0, Math.min(120, duration - count * 90));
        view.preferencesChanged();
        status = ""; statusError = false;
    }
    function configure(button) {
        if (settings.opened) { settings.close(); return; }
        var point = button.mapToItem(view, 0, button.height);
        settings.x = Math.max(8, Math.min(point.x + button.width - settings.width, view.width - settings.width - 8));
        settings.y = point.y + 4;
        settings.open();
        if (backend) backend.refresh();
    }
    Component.onCompleted: if (backend) backend.refresh()
    onVisibleChanged: if (visible && backend) backend.refresh()
    Timer { interval: 15000; repeat: true; running: view.visible && view.backend !== null; onTriggered: if (view.backend) view.backend.refresh(); }
    Connections {
        target: view.backend
        function onCompleted(action, response) {
            if (action === "save" && response.ok) {
                if (response.savedId) view.selectedId = response.savedId;
                else if (response.schedules && response.schedules.length) view.selectedId = response.schedules[response.schedules.length - 1].id;
                var times = [];
                if (view.submitted.bedEnabled) times.push("Bed " + view.timeLabel(view.submitted.bed));
                if (view.submitted.wakeEnabled) times.push("Wake " + view.timeLabel(view.submitted.wake));
                view.status = "Alarm set · " + times.join(" · ");
                view.statusError = false;
                settings.close();
            } else if (action === "remove" && response.ok) {
                view.selectedId = ""; view.alarmName = "Sleep schedule";
                view.status = "Alarm removed."; view.statusError = false;
            } else if (!response.ok && action !== "list") {
                view.status = response.error || "Could not set alarm."; view.statusError = true;
            }
        }
    }
    SleepView {
        id: calculator
        anchors.fill: parent
        alarmReady: view.backend && view.backend.available
        alarmBusy: view.backend && view.backend.busy
        alarmMessage: view.status || (view.backend && view.backend.error ? "Alarm service unavailable. Open Configure for details." : "")
        alarmError: view.statusError || (view.backend && view.backend.error !== "")
        onPreferencesChanged: view.preferencesChanged()
        onSetAlarmRequested: view.setAlarm()
        onConfigureRequested: function(button) { view.configure(button); }
    }
    AlarmSettings {
        id: settings
        objectName: "alarmSettings"
        owner: view
        width: Math.min(380, view.width - 16)
        height: Math.min(implicitHeight, view.height - y - 12)
    }
}
