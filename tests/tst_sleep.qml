import QtQuick 2.15
import QtQuick.Window 2.15
import QtTest 1.3
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import "../package/contents/ui"

Item {
    id: surface
    width: 420; height: 640
    SleepView { id: view; anchors.fill: parent }
    TestCase {
        name: "SleepInteraction"
        when: windowShown
        function init() {
            surface.width = 420; surface.height = 640;
            view.mode = 0; view.wakeMinutes = 360; view.bedMinutes = 1320;
            view.cycles = 5; view.latency = 14;
            wait(50);
        }
        function test_cycle_choices_all_modes() {
            for (var mode = 0; mode < 3; mode++) {
                view.mode = mode;
                for (var count = 1; count <= 6; count++) {
                    var tile = findChild(view, "cycleChoice" + count);
                    mouseClick(tile, tile.width / 2, tile.height / 2);
                    compare(view.cycles, count);
                    compare(findChild(view, "sleepDial").selectedCycle, count);
                    compare(tile.minutes, view.result);
                    verify(tile.selected);
                    mouseClick(tile, tile.width / 2, tile.height / 2);
                    verify(tile.selected); // Clicking the active choice never deselects it.
                    for (var other = 1; other <= 6; other++)
                        compare(findChild(view, "cycleChoice" + other).selected, other === count);
                }
            }
        }
        function test_all_controls_fit_without_scrolling_data() {
            return [
                {tag: "compact-380", width: 380, height: 360},
                {tag: "compact-420", width: 420, height: 380},
                {tag: "medium", width: 420, height: 450},
                {tag: "tall", width: 420, height: 690}
            ];
        }
        function test_all_controls_fit_without_scrolling(data) {
            surface.width = data.width; surface.height = data.height;
            wait(50);
            compare(findChild(view, "calculatorScroll"), null);
            var names = ["sleepDial", "targetInput", "latencyInput", "setAlarm", "configureAlarms"];
            for (var count = 1; count <= 6; count++) names.push("cycleChoice" + count);
            for (var i = 0; i < names.length; i++) {
                var control = findChild(view, names[i]);
                var topLeft = control.mapToItem(view, 0, 0);
                var bottomRight = control.mapToItem(view, control.width, control.height);
                verify(topLeft.x >= -1 && topLeft.y >= -1, names[i] + " starts outside the popup");
                verify(bottomRight.x <= view.width + 1 && bottomRight.y <= view.height + 1, names[i] + " ends outside the popup");
            }
            var choice = findChild(view, "cycleChoice6");
            mouseClick(choice, choice.width / 2, choice.height / 2);
            compare(view.cycles, 6);
        }
        function test_dial_follows_plasma_theme() {
            var dial = findChild(view, "sleepDial");
            compare(dial.accent, view.Kirigami.Theme.highlightColor);
            compare(dial.foreground, view.Kirigami.Theme.textColor);
            compare(dial.backgroundColor, view.Kirigami.Theme.backgroundColor);
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
            // Whole-pixel mouse coordinates can quantize the dial by one minute.
            verify(Math.abs(view.wakeMinutes - 390) <= 1);
            compare(view.result, view.wakeMinutes - (5 * 90 + 14));
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
