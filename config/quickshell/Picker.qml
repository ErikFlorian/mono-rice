import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Effects

// Searchable list inside an Overlay.  items: [{ text, sub, icon, data }]
Overlay {
    id: picker

    property var items: []
    property string placeholder: "search"
    property bool showIcons: false
    property bool filterEnabled: true   // off: items are shown as given (calc, emoji...)
    property int initialIndex: 0        // row selected when the query is empty
    readonly property string query: input.text
    // kept-alive pickers (launcher) start fresh every time they are shown
    onShownChanged: if (shown) { input.text = ""; input.forceActiveFocus(); list.positionViewAtBeginning(); }
    signal accepted(var item)

    hint: "↑↓ select · enter · esc"

    function score(it, q) {
        if (!q) return 1;
        const t = it.text.toLowerCase();
        if (t.startsWith(q)) return 3;
        if (t.includes(q)) return 2;
        if ((it.sub || "").toLowerCase().includes(q)) return 1;
        // loose subsequence match ("ff" -> firefox)
        let i = 0;
        for (const c of t) if (c === q[i]) i++;
        return i === q.length ? 0.5 : 0;
    }
    readonly property var filtered: {
        if (!filterEnabled) return items.slice(0, 200);
        const q = input.text.trim().toLowerCase();
        return items.map(it => ({ it, s: score(it, q) }))
                    .filter(x => x.s > 0)
                    .sort((a, b) => (b.s - a.s) || (a.it.text.toLowerCase() < b.it.text.toLowerCase() ? -1 : 1))
                    .slice(0, 200)
                    .map(x => x.it);
    }
    onFilteredChanged: list.currentIndex = input.text === "" ? Math.min(initialIndex, filtered.length - 1) : 0

    Row {
        id: prompt
        width: parent.width
        height: 26
        spacing: 8
        Txt { text: ">"; color: Theme.outline; height: parent.height }
        TextInput {
            id: input
            width: parent.width - 60
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.fg
            selectedTextColor: Theme.bg
            font.family: Theme.font
            font.pixelSize: Theme.size + 1
            focus: true
            cursorDelegate: Rectangle {
                width: 8; color: Theme.fg
                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
            }
            Txt { visible: !input.text; text: picker.placeholder; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            Component.onCompleted: forceActiveFocus()

            Keys.onEscapePressed: picker.closeRequested()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onTabPressed: list.incrementCurrentIndex()
            Keys.onPressed: e => {
                if (e.modifiers & Qt.ControlModifier && e.key === Qt.Key_J) { list.incrementCurrentIndex(); e.accepted = true; }
                if (e.modifiers & Qt.ControlModifier && e.key === Qt.Key_K) { list.decrementCurrentIndex(); e.accepted = true; }
            }
            onAccepted: if (picker.filtered.length) picker.accepted(picker.filtered[list.currentIndex])
        }
        Txt { text: picker.filtered.length; color: Theme.outline; height: parent.height }
    }

    Rectangle { id: rule; anchors.top: prompt.bottom; anchors.topMargin: 6; width: parent.width; height: 1; color: Theme.line }

    ListView {
        id: list
        anchors.top: rule.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: picker.filtered
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        highlightFollowsCurrentItem: true
        highlight: Rectangle {
            width: list.width
            color: Theme.surfaceHigh
            Rectangle { width: 2; height: parent.height; color: Theme.fg }
        }
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: ListView.isCurrentItem
            width: list.width
            height: 26
            color: "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 10
                width: parent.width - 12
                Item {
                    visible: picker.showIcons
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        visible: false
                        source: picker.showIcons ? Quickshell.iconPath(row.modelData.icon || "", "application-x-executable") : ""
                    }
                    MultiEffect { anchors.fill: parent; source: appIcon; saturation: -1 }
                }
                Txt {
                    id: main
                    text: row.modelData.text
                    color: row.sel ? Theme.fg : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: 120 } }
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width * (row.modelData.sub ? 0.6 : 1) - 40)
                }
                Txt {
                    visible: !!row.modelData.sub
                    text: row.modelData.sub || ""
                    textFormat: Text.PlainText
                    color: row.sel ? Theme.outline : Theme.line
                    elide: Text.ElideRight
                    width: parent.width - main.width - 60
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: list.currentIndex = row.index
                onClicked: picker.accepted(row.modelData)
            }
        }
    }
}
