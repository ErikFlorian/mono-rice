import QtQuick

// "── title ─────────────── action"
Item {
    id: sec
    property string title: ""
    property string action: ""
    signal actionClicked

    width: parent ? parent.width : 300
    height: 26

    Txt { id: t; anchors.verticalCenter: parent.verticalCenter; text: "── " + sec.title + " "; color: Theme.outline }
    Rectangle {
        anchors.left: t.right
        anchors.right: act.visible ? act.left : parent.right
        anchors.rightMargin: act.visible ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.surfaceHigh
    }
    Txt {
        id: act
        visible: sec.action !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: sec.action
        color: am.containsMouse ? Theme.fg : Theme.line
        MouseArea { id: am; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.actionClicked() }
    }
}
