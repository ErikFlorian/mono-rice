import QtQuick

// "[■] wifi" / "[ ] wifi"
Item {
    id: t
    property string label: ""
    property bool checked: false
    property string sub: ""
    signal toggled

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Theme.surfaceHigh : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Row {
        id: row
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Txt {
            text: t.checked ? "[■]" : "[ ]"
            color: t.checked ? Theme.fg : Theme.line
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Txt {
            text: t.label
            color: t.checked ? Theme.fg : Theme.fgDim
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Txt { visible: t.sub !== ""; text: t.sub; color: Theme.outline }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled() }
}
