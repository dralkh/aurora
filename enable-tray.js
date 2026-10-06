// Run through PlasmaShell.evaluateScript after installing the package.
var plugin = "org.dralk.aurorasleep";
var count = 0;
var panelList = panels();
function items(value) {
    if (Array.isArray(value)) return value;
    return String(value || "").split(",").filter(function(item) { return item.length > 0; });
}
for (var i = 0; i < panelList.length; i++) {
    var widgets = panelList[i].widgets();
    for (var j = 0; j < widgets.length; j++) {
        var tray = widgets[j];
        if (tray.type !== "org.kde.plasma.systemtray") continue;
        tray.currentConfigGroup = ["General"];
        for (var k = 0; k < 3; k++) {
            var key = ["extraItems", "knownItems", "shownItems"][k];
            var list = items(tray.readConfig(key, []));
            if (list.indexOf(plugin) < 0) { list.push(plugin); tray.writeConfig(key, list); }
        }
        var hidden = items(tray.readConfig("hiddenItems", []));
        tray.writeConfig("hiddenItems", hidden.filter(function(item) { return item !== plugin; }));
        count++;
    }
}
print("Aurora enabled in " + count + " system tray(s).");
