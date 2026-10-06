import QtQuick
import org.kde.plasma.components as PC

PC.Button {
    property bool primary: false
    property bool selected: false
    checkable: false
    checked: selected
}
