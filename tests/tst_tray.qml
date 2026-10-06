import QtQuick 2.15
import QtTest 1.3
import org.kde.kirigami as Kirigami
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
        function init() {
            icon.expanded = false;
            icon.Kirigami.Theme.inherit = true;
        }
        function test_theme_color_changes_in_place() {
            var glyph = findChild(icon, "trayGlyph");
            verify(glyph.isMask);
            icon.Kirigami.Theme.inherit = false;
            // Simulate the foreground colors supplied by light and dark panels.
            icon.Kirigami.Theme.textColor = "#232629";
            tryCompare(glyph, "color", "#232629");
            icon.Kirigami.Theme.textColor = "#eff0f1";
            tryCompare(glyph, "color", "#eff0f1");
            icon.Kirigami.Theme.textColor = "#232629";
            tryCompare(glyph, "color", "#232629");
        }
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
