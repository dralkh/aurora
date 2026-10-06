import QtQuick 2.15
import QtQuick.Window 2.15
import QtTest 1.3
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import "../package/contents/ui"

Item {
    width: 420; height: 640
    SleepView { id: view; anchors.fill: parent }
    TestCase {
        name: "SleepInteraction"
        when: windowShown
        function init() {
            view.width = 420; view.height = 640;
            view.mode = 0; view.wakeMinutes = 360; view.bedMinutes = 1320;
            view.cycles = 5; view.latency = 14;
            wait(50);
        }
        function test_anchor_drag() {
            var dial = findChild(view, "sleepDial");
            var start = dial.point(360, dial.radius), end = dial.point(420, dial.radius);
            mousePress(dial, start.x, start.y);
            mouseMove(dial, end.x, end.y, 80);
            mouseRelease(dial, end.x, end.y);
            compare(view.wakeMinutes, 420);
            compare(view.result, -44);
        }
        function test_result_drag() {
            var dial = findChild(view, "sleepDial");
            var start = dial.point(view.result, dial.radius), end = dial.point(view.result + 30, dial.radius);
            mousePress(dial, start.x, start.y);
            mouseMove(dial, end.x, end.y, 80);
            mouseRelease(dial, end.x, end.y);
            compare(view.wakeMinutes, 390);
            compare(view.cycles, 5);
        }
        function test_marker_selection() {
            var dial = findChild(view, "sleepDial");
            var p = dial.point(360 - 90 - 14, dial.radius);
            mouseClick(dial, p.x, p.y);
            compare(view.cycles, 1);
        }
        function test_midnight_continuity() {
            var dial = findChild(view, "sleepDial");
            var p = dial.point(5, dial.radius);
            compare(dial.minutesAt(p.x, p.y, 1435), 1445);
            p = dial.point(-5, dial.radius);
            compare(dial.minutesAt(p.x, p.y, 5), -5);
        }
        function test_now_handle_fixed() {
            view.mode = 2;
            wait(20);
            var dial = findChild(view, "sleepDial");
            var saved = view.wakeMinutes;
            var p = dial.point(view.anchor, dial.radius), end = dial.point(view.anchor + 60, dial.radius);
            mousePress(dial, p.x, p.y); mouseMove(dial, end.x, end.y, 50); mouseRelease(dial, end.x, end.y);
            compare(view.wakeMinutes, saved);
        }
    }
}
