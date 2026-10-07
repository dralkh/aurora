import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC
import org.kde.kirigami 2.20 as Kirigami
import "SleepMath.js" as MathUtil
import "AlarmModel.js" as AlarmModel

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
    property bool settingsOpen: false
    property bool diaryOpen: false
    onSettingsOpenChanged: if (settingsOpen) diaryOpen = false
    onDiaryOpenChanged: if (diaryOpen) settingsOpen = false
    readonly property var initialDraft: AlarmModel.defaults()
    property string selectedId: initialDraft.selectedId
    property string alarmName: initialDraft.alarmName
    property var repeatDays: initialDraft.repeatDays
    property bool bedEnabled: initialDraft.bedEnabled
    property bool wakeEnabled: initialDraft.wakeEnabled
    property bool bedSound: initialDraft.bedSound
    property bool wakeSound: initialDraft.wakeSound
    property int bedLead: initialDraft.bedLead
    property int snooze: initialDraft.snooze
    property int volume: initialDraft.volume
    property var submitted: ({})
    property string status: ""
    property bool statusError: false
    signal preferencesChanged()
    readonly property int chosenBed: MathUtil.wrap(calculator.mode === 0 ? calculator.result : calculator.anchor)
    readonly property int chosenWake: MathUtil.wrap(calculator.mode === 0 ? calculator.anchor : calculator.result)

    function dateString(date) { return AlarmModel.dateString(date); }
    function timeLabel(minutes) {
        return MathUtil.time(minutes, clock24) + (clock24 ? "" : " " + MathUtil.period(minutes));
    }
    function setAlarm() {
        if (!backend || !backend.available || backend.busy) return;
        if (calculator.mode === 2) calculator.now = new Date();
        var problem = AlarmModel.validationError(view);
        if (problem) {
            status = problem;
            statusError = true;
            settingsOpen = true;
            return;
        }
        var schedule = AlarmModel.makeSchedule(view, chosenBed, chosenWake, new Date());
        submitted = {bed: chosenBed, wake: chosenWake, bedEnabled: bedEnabled, wakeEnabled: wakeEnabled};
        backend.request({action: "save", schedule: schedule});
    }
    function chooseSaved(schedule) {
        var restored = AlarmModel.restore(schedule);
        AlarmModel.applyDraft(view, restored.draft);
        if (restored.calculator) {
            for (var key in restored.calculator) calculator[key] = restored.calculator[key];
        }
        if (restored.calculator) view.preferencesChanged();
        status = "";
        statusError = false;
    }
    function configure() {
        settingsOpen = true;
        if (backend) backend.refresh();
    }
    Shortcut {
        sequence: "Esc"
        enabled: view.visible && (view.settingsOpen || view.diaryOpen)
        onActivated: {
            if (view.diaryOpen) diaryPage.navigate({close: true});
            else view.settingsOpen = false;
        }
    }
    Component.onCompleted: if (backend) backend.refresh()
    onVisibleChanged: if (visible && backend) backend.refresh()
    Timer { interval: 15000; repeat: true; running: view.visible && view.backend !== null; onTriggered: if (view.backend) view.backend.refresh(); }
    Connections {
        target: view.backend
        function onCompleted(action, response) {
            if (action.indexOf("diary_") === 0) {
                diaryPage.acceptResponse(action, response);
                return;
            }
            if (action === "save" && response.ok) {
                if (response.savedId) view.selectedId = response.savedId;
                else if (response.schedules && response.schedules.length) view.selectedId = response.schedules[response.schedules.length - 1].id;
                var times = [];
                if (view.submitted.bedEnabled) times.push("Bed " + view.timeLabel(view.submitted.bed));
                if (view.submitted.wakeEnabled) times.push("Wake " + view.timeLabel(view.submitted.wake));
                view.status = "Alarm set · " + times.join(" · ");
                view.statusError = false;
                view.settingsOpen = false;
            } else if (action === "remove" && response.ok) {
                AlarmModel.applyDraft(view, AlarmModel.defaults());
                view.status = "Alarm removed."; view.statusError = false;
            } else if (!response.ok && action !== "list") {
                view.status = response.error || "Could not set alarm."; view.statusError = true;
            }
        }
    }
    StackLayout {
        objectName: "popupPages"
        anchors.fill: parent
        currentIndex: view.diaryOpen ? 2 : view.settingsOpen ? 1 : 0
        SleepView {
            id: calculator
            objectName: "calculatorPage"
            clockRunning: view.visible
            alarmReady: view.backend && view.backend.available
            alarmBusy: view.backend && view.backend.busy
            alarmMessage: view.status || (view.backend ? view.backend.error || view.backend.warning : "")
            alarmError: view.statusError || (view.backend && (view.backend.error !== "" || view.backend.warning !== ""))
            onPreferencesChanged: { view.status = ""; view.statusError = false; view.preferencesChanged(); }
            onSetAlarmRequested: view.setAlarm()
            onConfigureRequested: view.configure()
            onDiaryRequested: { view.diaryOpen = true; diaryPage.refresh(); }
        }
        AlarmSettings {
            objectName: "alarmSettings"
            owner: view
        }
        DiaryPage {
            id: diaryPage
            theme: AuroraTheme { colorSource: view }
            onCloseRequested: view.diaryOpen = false
            onRequested: function(payload) {
                if (view.backend) view.backend.request(payload);
                else acceptResponse(payload.action, {ok: false, error: "The diary service is unavailable."});
            }
        }
    }
}
