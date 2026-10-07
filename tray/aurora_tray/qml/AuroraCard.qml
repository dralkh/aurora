import QtQuick
import QtQuick.Controls.Basic

Pane {
    id: card
    AuroraTheme { id: theme }
    padding: 12
    background: Rectangle {
        radius: 12
        color: theme.surface
        border.color: theme.border
    }
}
