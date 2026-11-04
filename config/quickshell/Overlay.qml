import QtQuick
import Quickshell
import Quickshell.Wayland

// Centered TUI-style box over a dimmed screen. Click outside or Esc closes.
PanelWindow {
    id: win

    property string title: ""
    property string hint: ""
    property int boxWidth: 640
    property int boxHeight: 440
    default property alias content: box.data
    signal closeRequested

    // set by Panel: true while open, false while animating out
    property bool shown: false
    visible: shown || t > 0.01
    property real t: 0
    Component.onCompleted: t = Qt.binding(() => shown ? 1 : 0)
    Behavior on t { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    screen: Niri.screenFor(Niri.focusedOutput)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-overlay"
    color: "transparent"

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.45)
        opacity: win.t
        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }
    }

    Rectangle {
        id: frame
        anchors.centerIn: parent
        width: win.boxWidth
        height: win.boxHeight
        color: Theme.bg
        border.color: Theme.line
        border.width: 1
        opacity: win.t
        MouseArea { anchors.fill: parent }

        // title sits on the top border:  ┌─[ title ]──────┐
        Rectangle {
            x: 14
            y: -height / 2
            width: titleText.implicitWidth + 12
            height: titleText.implicitHeight
            color: Theme.bg
            visible: win.title !== ""
            Txt { id: titleText; anchors.centerIn: parent; text: win.title; color: Theme.fgDim }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: parent.height - height / 2
            width: hintText.implicitWidth + 12
            height: hintText.implicitHeight
            color: Theme.bg
            visible: win.hint !== ""
            Txt { id: hintText; anchors.centerIn: parent; text: win.hint; color: Theme.line; font.pixelSize: Theme.size - 1 }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            Item {
                id: box
                x: 15
                y: 17
                width: win.boxWidth - 32
                height: win.boxHeight - 34
            }
        }
    }
}
