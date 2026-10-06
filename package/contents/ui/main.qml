import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.icon: Qt.resolvedUrl("../icons/aurora.svg").toString()
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground
    // Leave preferredRepresentation unset: Plasma 6.7 only hosts popups
    // for applets without an explicit preferred representation.
    activationTogglesExpanded: true
    toolTipMainText: "Aurora"
    toolTipSubText: "Find your bedtime or wake time"
    compactRepresentation: TrayIcon {
        expanded: root.expanded
        onExpansionRequested: function(open) { root.expanded = open; }
    }
    AlarmClient { id: alarms }
    fullRepresentation: AuroraView {
        backend: alarms
        Layout.minimumWidth: 380
        Layout.preferredWidth: 420
        Layout.minimumHeight: Math.max(360, Kirigami.Units.gridUnit * 21)
        Layout.preferredHeight: Math.max(690, Kirigami.Units.gridUnit * 38)
        wakeMinutes: Plasmoid.configuration.wakeMinutes
        bedMinutes: Plasmoid.configuration.bedMinutes
        latency: Plasmoid.configuration.latency
        cycles: Plasmoid.configuration.cycles
        mode: Plasmoid.configuration.mode
        clock24: Plasmoid.configuration.clock24
        onPreferencesChanged: {
            Plasmoid.configuration.wakeMinutes = wakeMinutes;
            Plasmoid.configuration.bedMinutes = bedMinutes;
            Plasmoid.configuration.latency = latency;
            Plasmoid.configuration.cycles = cycles;
            Plasmoid.configuration.mode = mode;
            Plasmoid.configuration.clock24 = clock24;
        }
    }
}
