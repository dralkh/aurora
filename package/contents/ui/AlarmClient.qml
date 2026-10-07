import QtQuick 2.15
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

Item {
    id: client
    property var schedules: []
    property var pending: []
    property bool available: false
    property bool busy: false
    property string error: ""
    property string warning: ""
    property var queue: []
    property var current
    signal completed(string action, var response)

    function quote(value) { return "'" + value.replace(/'/g, "'\\''") + "'"; }
    function request(payload) {
        if (payload.action === "list" && (busy || queue.length)) return;
        queue.push(payload);
        next();
    }
    function refresh() { request({action: "list"}); }
    function next() {
        if (busy || !queue.length) return;
        current = queue.shift();
        busy = true;
        var path = decodeURIComponent(Qt.resolvedUrl("../code/aurora_service.py").toString().replace(/^file:\/\//, ""));
        var encoded = Qt.btoa(encodeURIComponent(JSON.stringify(current)));
        executor.connectSource("/usr/bin/python3 " + quote(path) + " --request " + quote(encoded));
    }
    Plasma5Support.DataSource {
        id: executor
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            var response;
            try { response = JSON.parse(data.stdout); }
            catch (exception) { response = {ok: false, error: data.stderr || "The alarm service did not respond."}; }
            client.available = response.available === true || response.ok === true;
            client.error = response.ok ? "" : response.error || "Could not update alarms.";
            if (response.ok && client.current.action.indexOf("diary_") !== 0) {
                client.schedules = response.schedules || [];
                client.pending = response.pending || [];
                client.warning = response.warning || "";
            }
            var action = client.current.action;
            client.busy = false;
            client.completed(action, response);
            client.next();
        }
    }
}
