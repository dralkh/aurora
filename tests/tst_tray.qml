import QtQuick 2.15
import QtTest 1.3
import "../package/contents/ui"

Item {
    width: 80; height: 80
    TrayIcon {
        id: icon
        width: 48; height: 48
        onExpansionRequested: function(open) { expanded = open; }
    }
    TestCase {
        name: "TrayPopupToggle"
        when: windowShown
        function init() { icon.expanded = false; }
        function test_open_and_close() {
            mouseClick(icon, 24, 24);
            compare(icon.expanded, true);
            mouseClick(icon, 24, 24);
            compare(icon.expanded, false);
        }
        function test_dismissed_on_press_stays_closed() {
            icon.expanded = true;
            mousePress(icon, 24, 24);
            // Native popup deactivation can close it before mouse release.
            icon.expanded = false;
            mouseRelease(icon, 24, 24);
            compare(icon.expanded, false);
        }
        function test_forwarded_tray_events() {
            var area = findChild(icon, "trayMouseArea");
            ignoreWarning(/.*Property 'onPressed'.*signal handler.*/);
            area.onPressed(null);
            area.clicked(null);
            compare(icon.expanded, true);
            ignoreWarning(/.*Property 'onPressed'.*signal handler.*/);
            area.onPressed(null);
            icon.expanded = false;
            area.clicked(null);
            compare(icon.expanded, false);
        }
    }
}
