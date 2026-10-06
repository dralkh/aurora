import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: icon
    implicitWidth: 32
    implicitHeight: 32
    property bool expanded: false
    property url source: Qt.resolvedUrl("../icons/aurora.svg")
    signal expansionRequested(bool open)

    Kirigami.Icon {
        objectName: "trayGlyph"
        anchors.fill: parent
        // The source viewBox removes the original padding.
        isMask: true
        color: Kirigami.Theme.textColor
        source: icon.source
        active: false
    }
    MouseArea {
        id: mouseArea
        objectName: "trayMouseArea"
        anchors.fill: parent
        hoverEnabled: true
        // Plasma may dismiss the popup between press and release. Its tray
        // also forwards these handlers when clicking the delegate margins.
        property bool wasExpanded: false
        onPressed: wasExpanded = icon.expanded
        onClicked: icon.expansionRequested(!wasExpanded)
    }
}
