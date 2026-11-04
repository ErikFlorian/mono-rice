import QtQuick

// "vol  [██████████░░░░░░░░] 45%"  - drag, click or scroll to change.
Item {
    id: s
    property string label: ""
    property real value: 0          // 0..1
    property bool muted: false
    property int cells: 26
    signal moved(real v)
    signal labelClicked

    implicitHeight: 24
    implicitWidth: row.implicitWidth

    readonly property int filled: Math.round(Math.max(0, Math.min(1, value)) * cells)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Txt {
            width: 34
            text: s.label
            color: labelMa.containsMouse ? Theme.fg : Theme.outline
            MouseArea { id: labelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.labelClicked() }
        }
        Txt {
            id: bar
            text: "[" + "█".repeat(s.filled) + "░".repeat(s.cells - s.filled) + "]"
            color: s.muted ? Theme.line : barMa.containsMouse || barMa.pressed ? Theme.fg : Theme.fgDim
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea {
                id: barMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function set(x) { s.moved(Math.max(0, Math.min(1, (x - 8) / (width - 16)))); }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x); }
                onWheel: wheel => s.moved(Math.max(0, Math.min(1, s.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Txt {
            width: 40
            horizontalAlignment: Text.AlignRight
            text: s.muted ? "mute" : Math.round(s.value * 100) + "%"
            color: Theme.fgDim
        }
    }
}
