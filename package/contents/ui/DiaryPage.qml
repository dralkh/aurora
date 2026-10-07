import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "DiaryModel.js" as Diary

Item {
    id: page
    objectName: "diaryPage"
    property QtObject theme
    property date selectedDate: new Date()
    property date month: new Date()
    property string kind: "dream"
    property var entries: ({dream: "", waking: "", bedtime: ""})
    property var days: []
    property bool loaded: false
    property bool busy: false
    property bool dirty: false
    property bool changingText: false
    property string submittedText: ""
    property bool failed: false
    property string message: ""
    property var nextNavigation: null
    readonly property string dateKey: Diary.dayKey(selectedDate)
    readonly property var cells: Diary.calendar(month)
    signal requested(var payload)
    signal closeRequested()

    function load() {
        if (busy) return;
        busy = true;
        requested({action: "diary_load", date: dateKey, month: Diary.monthKey(month)});
    }
    function refresh() {
        if (!loaded && !busy && !dirty) load();
    }
    function save() {
        autosave.stop();
        if (busy || !loaded) return;
        if (!dirty) { finishNavigation(); return; }
        submittedText = editor.text;
        busy = true;
        message = "Saving…";
        requested({action: "diary_save", date: dateKey, month: Diary.monthKey(month), kind: kind, text: editor.text});
    }
    function navigate(destination) {
        if (busy) return;
        nextNavigation = destination;
        if (dirty) save();
        else finishNavigation();
    }
    function finishNavigation() {
        var destination = nextNavigation;
        nextNavigation = null;
        if (!destination) return;
        if (destination.close) { closeRequested(); return; }
        if (destination.kind) {
            kind = destination.kind;
            changingText = true;
            editor.text = entries[kind] || "";
            changingText = false;
        } else {
            selectedDate = destination.date || selectedDate;
            month = destination.month || selectedDate;
            loaded = false;
            load();
        }
    }
    function acceptResponse(action, response) {
        if (action !== "diary_load" && action !== "diary_save") return;
        busy = false;
        failed = !response.ok;
        if (!response.ok) {
            message = response.error || "Could not save the diary.";
            nextNavigation = null;
            return;
        }
        entries = response.entries;
        days = response.days;
        if (action === "diary_load") {
            changingText = true;
            editor.text = entries[kind] || "";
            changingText = false;
            loaded = true;
            dirty = false;
            message = "Only on this device";
        } else {
            dirty = editor.text !== submittedText;
            message = dirty ? "Unsaved" : "Saved";
        }
        if (dirty) autosave.restart();
        else finishNavigation();
    }
    onVisibleChanged: if (visible) refresh()
    Timer { id: autosave; interval: 800; onTriggered: page.save() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.largeSpacing
        spacing: theme.spacing
        RowLayout {
            Layout.fillWidth: true
            AuroraButton { objectName: "diaryBack"; text: "Back"; enabled: !page.busy; onClicked: page.navigate({close: true}) }
            Label { text: "Diary"; color: theme.text; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
            AuroraButton { text: "Today"; enabled: !page.busy; onClicked: page.navigate({date: new Date()}) }
        }
        RowLayout {
            Layout.fillWidth: true
            AuroraButton { objectName: "diaryPreviousMonth"; text: "‹"; Accessible.name: "Previous month"; enabled: !page.busy; onClicked: page.navigate({date: Diary.shiftMonth(page.month, -1)}) }
            Label { text: Qt.formatDate(page.month, "MMMM yyyy"); color: theme.text; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.weight: Font.DemiBold }
            AuroraButton { objectName: "diaryNextMonth"; text: "›"; Accessible.name: "Next month"; enabled: !page.busy; onClicked: page.navigate({date: Diary.shiftMonth(page.month, 1)}) }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 2
            rowSpacing: 2
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Label { required property string modelData; text: modelData; color: theme.muted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; Layout.preferredWidth: 1; font.pixelSize: theme.smallFontSize }
            }
            Repeater {
                model: page.cells
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 27
                    AbstractButton {
                        id: dayButton
                        objectName: "diaryDate" + modelData.key
                        anchors.fill: parent
                        text: modelData.number
                        opacity: modelData.currentMonth ? 1 : 0.4
                        readonly property bool selected: modelData.key === page.dateKey
                        background: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height)
                                height: width
                                radius: width / 2
                                color: dayButton.selected ? theme.accent : dayButton.hovered ? theme.surface : "transparent"
                            }
                        }
                        contentItem: Label {
                            text: dayButton.text
                            font: dayButton.font
                            color: dayButton.selected ? theme.highlightText : theme.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        font.bold: modelData.key === Diary.dayKey(new Date())
                        enabled: !page.busy
                        onClicked: page.navigate({date: modelData.date})
                        Accessible.name: Qt.formatDate(modelData.date, "dddd, d MMMM yyyy") + (page.days.indexOf(modelData.key) >= 0 ? ", has entries" : "")
                    }
                    Rectangle {
                        visible: page.days.indexOf(modelData.key) >= 0
                        width: 3; height: 3; radius: 1.5
                        color: modelData.key === page.dateKey ? theme.highlightText : theme.accent
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
        Label { text: Qt.formatDate(page.selectedDate, "dddd, d MMMM"); color: theme.text; font.pixelSize: theme.smallFontSize; Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{key: "dream", label: "Dream"}, {key: "waking", label: "Waking"}, {key: "bedtime", label: "Bedtime"}]
                AuroraButton {
                    required property var modelData
                    objectName: "diaryKind" + modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: modelData.label
                    selected: page.kind === modelData.key
                    enabled: !page.busy && page.loaded
                    onClicked: page.navigate({kind: modelData.key})
                }
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            AuroraTextArea {
                id: editor
                objectName: "diaryEditor"
                enabled: page.loaded
                placeholderText: page.kind === "dream" ? "What do you remember from your dream?" : page.kind === "waking" ? "How did you feel when you woke up?" : "A thought before you go to sleep…"
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                Accessible.name: "Diary entry"
                onTextChanged: {
                    if (!page.changingText && page.loaded) {
                        page.dirty = true;
                        page.message = "Unsaved";
                        page.failed = false;
                        autosave.restart();
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: page.message; color: page.failed ? theme.negative : theme.muted; wrapMode: Text.WordWrap; font.pixelSize: theme.smallFontSize; Layout.fillWidth: true }
            AuroraButton { objectName: "diarySave"; text: page.failed && !page.loaded ? "Retry" : "Save"; primary: true; enabled: !page.busy && (page.dirty || !page.loaded); onClicked: page.loaded ? page.save() : page.load() }
        }
    }
}
