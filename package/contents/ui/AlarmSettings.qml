import QtQuick
import org.kde.plasma.components

Popup {
    id: popup
    property var owner
    readonly property var backend: owner ? owner.backend : null
    padding: 0
    implicitWidth: 400
    implicitHeight: 640
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    contentItem: AuroraScheduleForm {
        owner: popup.owner
        schedules: popup.backend ? popup.backend.schedules : []
        pending: popup.backend ? popup.backend.pending : []
        available: popup.backend && popup.backend.available
        busy: popup.backend && popup.backend.busy
        message: popup.owner ? popup.owner.status || (popup.backend ? popup.backend.error || popup.backend.warning : "") : ""
        onCloseRequested: popup.close()
        onRemoveRequested: popup.backend.request({action: "remove", id: popup.owner.selectedId})
        onToggleRequested: function(enabled) { popup.backend.request({action: "toggle", id: popup.owner.selectedId, enabled: enabled}); }
        onTestRequested: popup.backend.request({action: "test"})
        onDismissRequested: function(key) { popup.backend.request({action: "dismiss", key: key}); }
        onSnoozeRequested: function(key) { popup.backend.request({action: "snooze", key: key}); }
    }
}
