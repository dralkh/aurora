import QtQuick 2.15
import QtTest 1.3
import "../package/contents/ui"

Item {
    width: 420; height: 690
    QtObject {
        id: backend
        property var schedules: []
        property var pending: []
        property bool available: true
        property bool busy: false
        property string error: ""
        property string warning: ""
        property var requests: []
        signal completed(string action, var response)
        function request(payload) { requests = requests.concat([payload]); }
        function refresh() { request({action: "list"}); }
    }
    AuroraView { id: view; anchors.fill: parent; backend: backend }
    TestCase {
        name: "InlineAlarms"
        when: windowShown
        function init() {
            findChild(view, "alarmSettings").close();
            view.mode = 0; view.wakeMinutes = 360; view.cycles = 5; view.latency = 14;
            view.selectedId = ""; view.alarmName = "Sleep schedule";
            view.repeatDays = []; view.bedEnabled = true; view.wakeEnabled = true;
            view.bedLead = 15; view.bedSound = true; view.wakeSound = true;
            backend.available = true; backend.error = ""; backend.requests = []; backend.schedules = [];
            wait(20);
        }
        function test_set_current_choices_without_navigation() {
            var button = findChild(view, "setAlarm");
            mouseClick(button, button.width / 2, button.height / 2);
            var request = backend.requests[backend.requests.length - 1];
            compare(request.action, "save");
            compare(request.schedule.bedMinutes, 1336);
            compare(request.schedule.wakeMinutes, 360);
            verify(request.schedule.bedEnabled && request.schedule.wakeEnabled);
            verify(!findChild(view, "alarmSettings").opened);
            backend.completed("save", {ok: true, savedId: "saved-one"});
            compare(view.selectedId, "saved-one");
            verify(button.visible);
            verify(findChild(view, "sleepDial").visible);
            verify(findChild(view, "alarmStatus").text.indexOf("Alarm set") >= 0);
        }
        function test_configure_dropdown_keeps_clock_visible() {
            var button = findChild(view, "configureAlarms");
            mouseClick(button, button.width / 2, button.height / 2);
            var popup = findChild(view, "alarmSettings");
            tryCompare(popup, "opened", true);
            verify(findChild(view, "sleepDial").visible);
            var enabled = findChild(view, "bedAlarmEnabled");
            mouseClick(enabled, enabled.width / 2, enabled.height / 2);
            compare(view.bedEnabled, false);
            popup.close();
            view.setAlarm();
            var request = backend.requests[backend.requests.length - 1];
            compare(request.schedule.bedEnabled, false);
            compare(request.schedule.wakeEnabled, true);
        }
        function test_saved_alarm_updates_instead_of_duplicating() {
            view.chooseSaved({id: "existing", name: "Work nights", days: [0, 1, 2, 3, 4], bedEnabled: true, wakeEnabled: true,
                              bedSound: false, wakeSound: true, bedLead: 10, snooze: 5, volume: 60, bedMinutes: 1336, wakeMinutes: 360});
            view.setAlarm();
            var request = backend.requests[backend.requests.length - 1];
            compare(request.schedule.id, "existing");
            compare(request.schedule.days.length, 5);
            compare(request.schedule.bedMinutes, 1336);
            compare(request.schedule.bedLead, 10);
            compare(request.schedule.bedSound, false);
            view.chooseSaved(null);
            view.setAlarm();
            verify(backend.requests[backend.requests.length - 1].schedule.id === undefined);
        }
        function test_bed_mode_current_choices() {
            view.mode = 1; view.bedMinutes = 1320;
            view.setAlarm();
            var schedule = backend.requests[backend.requests.length - 1].schedule;
            compare(schedule.bedMinutes, 1320);
            compare(schedule.wakeMinutes, 344);
        }
        function test_unavailable_or_invalid_configuration_not_saved() {
            backend.available = false;
            verify(!findChild(view, "setAlarm").enabled);
            view.setAlarm();
            compare(backend.requests.length, 0);
            backend.available = true;
            view.alarmName = "";
            view.setAlarm();
            compare(backend.requests.length, 0);
            verify(view.statusError);
        }
    }
}
