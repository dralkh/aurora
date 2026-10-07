import QtQuick

AuroraScheduleForm {
    id: page
    readonly property var backend: owner ? owner.backend : null
    schedules: backend ? backend.schedules : []
    pending: backend ? backend.pending : []
    available: backend && backend.available
    busy: backend && backend.busy
    message: owner ? owner.status || (backend ? backend.error || backend.warning : "") : ""
    onCloseRequested: if (owner) owner.settingsOpen = false
    onRemoveRequested: if (backend) backend.request({action: "remove", id: owner.selectedId})
    onToggleRequested: function(enabled) { if (backend) backend.request({action: "toggle", id: owner.selectedId, enabled: enabled}); }
    onTestRequested: if (backend) backend.request({action: "test"})
    onDismissRequested: function(key) { if (backend) backend.request({action: "dismiss", key: key}); }
    onSnoozeRequested: function(key) { if (backend) backend.request({action: "snooze", key: key}); }
}
