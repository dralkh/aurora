import QtQuick
import org.kde.kirigami as Kirigami
import "SleepMath.js" as MathUtil

Item {
    id: dial
    objectName: "sleepDial"
    property int anchor: 360
    property int latency: 14
    property int selectedCycle: 5
    property int mode: 0
    property bool clock24: false
    property color accent: Kirigami.Theme.highlightColor
    property color foreground: Kirigami.Theme.textColor
    property color muted: Kirigami.Theme.disabledTextColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    property color highlightedTextColor: Kirigami.Theme.highlightedTextColor
    property real radius: Math.min(width, height) / 2 - 26
    readonly property int result: MathUtil.result(anchor, selectedCycle, latency, mode)
    signal cyclePicked(int cycle)
    signal anchorDragged(int minutes)
    signal resultDragged(int minutes)
    function angle(minutes) { return minutes / 720 * Math.PI * 2 - Math.PI / 2; }
    function point(minutes, r) {
        var a = angle(minutes);
        return Qt.point(width / 2 + Math.cos(a) * r, height / 2 + Math.sin(a) * r);
    }
    function minutesAt(x, y, reference) {
        var a = Math.atan2(y - height / 2, x - width / 2) + Math.PI / 2;
        var minutes = ((a / (2 * Math.PI) * 720) % 720 + 720) % 720;
        return Math.round(minutes + Math.round((reference - minutes) / 720) * 720);
    }
    onAnchorChanged: face.requestPaint()
    onLatencyChanged: face.requestPaint()
    onSelectedCycleChanged: face.requestPaint()
    onModeChanged: face.requestPaint()
    onAccentChanged: face.requestPaint()
    onForegroundChanged: face.requestPaint()
    onMutedChanged: face.requestPaint()

    Canvas {
        id: face
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), cx = width / 2, cy = height / 2, r = dial.radius;
            ctx.reset();
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = dial.muted; ctx.globalAlpha = 0.25; ctx.lineWidth = 2; ctx.stroke();
            ctx.globalAlpha = 1;
            for (var tick = 0; tick < 60; tick++) {
                var a = tick / 60 * Math.PI * 2 - Math.PI / 2;
                var major = tick % 5 === 0;
                ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * (r + 8), cy + Math.sin(a) * (r + 8));
                ctx.lineTo(cx + Math.cos(a) * (r + (major ? 15 : 11)), cy + Math.sin(a) * (r + (major ? 15 : 11)));
                ctx.strokeStyle = dial.muted; ctx.globalAlpha = major ? 0.8 : 0.35; ctx.lineWidth = 1; ctx.stroke();
            }
            ctx.globalAlpha = 1;
            ctx.beginPath();
            ctx.arc(cx, cy, r, dial.angle(dial.mode === 0 ? dial.result : dial.anchor), dial.angle(dial.mode === 0 ? dial.anchor : dial.result), false);
            ctx.strokeStyle = dial.accent; ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke();
        }
    }
    Repeater {
        model: 12
        Text {
            required property int index
            property point pos: dial.point((index + 1) * 60, dial.radius - 20)
            x: pos.x - width / 2
            y: pos.y - height / 2
            text: index + 1
            color: dial.muted
            font.pixelSize: 11
        }
    }
    Repeater {
        model: 6
        delegate: Item {
            id: marker
            required property int index
            readonly property bool selected: index + 1 === dial.selectedCycle
            property point pos: dial.point(MathUtil.result(dial.anchor, index + 1, dial.latency, dial.mode), dial.radius)
            x: pos.x - 15
            y: pos.y - 15
            width: 30
            height: 30
            z: selected ? 3 : 1
            Rectangle {
                anchors.centerIn: parent
                width: marker.selected ? 22 : 8
                height: width
                radius: width / 2
                color: marker.selected ? dial.accent : dial.backgroundColor
                border.color: dial.accent
                border.width: marker.selected ? 0 : 1.5
                Text {
                    visible: marker.selected
                    anchors.centerIn: parent
                    text: marker.index + 1
                    font.pixelSize: 11
                    color: dial.highlightedTextColor
                }
            }
            MouseArea {
                id: markerMouse
                anchors.fill: parent
                cursorShape: marker.selected && dial.mode !== 2 ? Qt.OpenHandCursor : Qt.PointingHandCursor
                property point pressPoint
                property bool moved: false
                property int reference: 0
                preventStealing: true
                onPressed: function(mouse) {
                    pressPoint = mapToItem(dial, mouse.x, mouse.y); moved = false;
                    reference = MathUtil.result(dial.anchor, marker.index + 1, dial.latency, dial.mode);
                }
                onPositionChanged: function(mouse) {
                    if (!pressed || !marker.selected || dial.mode === 2) return;
                    var p = mapToItem(dial, mouse.x, mouse.y);
                    if (Math.abs(p.x - pressPoint.x) + Math.abs(p.y - pressPoint.y) > 3) moved = true;
                    if (moved) { reference = dial.minutesAt(p.x, p.y, reference); dial.resultDragged(reference); }
                }
                onReleased: { if (!moved) dial.cyclePicked(marker.index + 1); }
                hoverEnabled: true
            }
        }
    }
    Item {
        id: anchorHandle
        property point pos: dial.point(dial.anchor, dial.radius)
        x: pos.x - 16
        y: pos.y - 16
        width: 32
        height: 32
        z: 4
        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 10
            color: dial.backgroundColor
            border.color: dial.foreground
            border.width: 2
            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: dial.foreground }
        }
        MouseArea {
            anchors.fill: parent
            enabled: dial.mode !== 2
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property int reference: 0
            preventStealing: true
            onPressed: reference = dial.anchor
            onPositionChanged: function(mouse) {
                if (!pressed) return;
                var p = mapToItem(dial, mouse.x, mouse.y);
                reference = dial.minutesAt(p.x, p.y, reference);
                dial.anchorDragged(reference);
            }
        }
    }
}
