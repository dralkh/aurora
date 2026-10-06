import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import "package/contents/ui"
Window {
    width: 420; height: 640; visible: true
    title: "Aurora — preview"
    color: view.Kirigami.Theme.backgroundColor
    SleepView { id: view; anchors.fill: parent }
    Timer {
        interval: 1200; running: Qt.application.arguments.indexOf("--capture") >= 0
        onTriggered: view.grabToImage(function(result) { result.saveToFile("/home/dralk/projects/aurora-sleep/dist/preview.png"); Qt.quit(); })
    }
}
