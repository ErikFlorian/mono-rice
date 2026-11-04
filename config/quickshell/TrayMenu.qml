import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Tray context menu in the rice style (replaces Qt's default white menu).
// Click outside / Esc closes, submenus open in place with a "back" row.
PanelWindow {
    id: w

    required property var trayItem
    property real anchorX: 0
    property bool shown: true
    signal closeRequested

    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : trayItem.menu

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-menu"
    color: "transparent"

    property real t: 0
    Component.onCompleted: t = Qt.binding(() => shown ? 1 : 0)
    Behavior on t { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    function clean(s) { return (s || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_"); }

    QsMenuOpener { id: opener; menu: w.current }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: w.closeRequested()
    }

    Rectangle {
        id: box
        readonly property int pad: 6
        width: Math.max(200, col.implicitWidth + 2 * pad)
        height: fullHeight
        x: Math.max(8, Math.min(w.width - width - 8, w.anchorX - width + 20))
        y: Theme.barHeight + 6
        color: Theme.bg
        border.color: Theme.line
        border.width: 1
        opacity: w.t
        readonly property real fullHeight: col.implicitHeight + 2 * pad
        focus: true
        Keys.onEscapePressed: w.stack.length ? w.stack = w.stack.slice(0, -1) : w.closeRequested()
        clip: true

        MouseArea { anchors.fill: parent }  // clicks on padding don't close

        Column {
            id: col
            x: box.pad
            y: box.pad
            width: box.width - 2 * box.pad

            // "‹ back" when inside a submenu
            Rectangle {
                visible: w.stack.length > 0
                width: col.width
                height: 26
                color: backMa.containsMouse ? Theme.surfaceHigh : "transparent"
                Txt { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "‹  back"; color: Theme.outline }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: w.stack = w.stack.slice(0, -1) }
            }

            Repeater {
                model: opener.children
                Item {
                    id: entry
                    required property var modelData
                    readonly property var e: modelData
                    width: col.width
                    height: e.isSeparator ? 9 : 26
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Rectangle {
                        visible: entry.e.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.surfaceHigh
                    }

                    Rectangle {
                        visible: !entry.e.isSeparator
                        anchors.fill: parent
                        color: ma.containsMouse && entry.e.enabled ? Theme.surfaceHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Rectangle {
                            width: 2; height: parent.height; color: Theme.fg
                            opacity: ma.containsMouse && entry.e.enabled ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Txt {
                                // check / radio state
                                width: 10
                                text: entry.e.checkState === Qt.Checked ? (entry.e.buttonType === QsMenuButtonType.RadioButton ? "•" : "✓") : ""
                                color: Theme.fgDim
                            }
                            Item {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.e.icon !== ""
                                IconImage { id: ico; anchors.fill: parent; source: entry.e.icon; visible: false }
                                MultiEffect { anchors.fill: parent; source: ico; saturation: -1; opacity: 0.8 }
                            }
                            Txt {
                                text: w.clean(entry.e.text)
                                color: !entry.e.enabled ? Theme.line : ma.containsMouse ? Theme.fg : Theme.fgDim
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }
                        Txt {
                            visible: entry.e.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: Theme.outline
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.e.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.e.hasChildren) {
                                    w.stack = [...w.stack, entry.e];
                                } else {
                                    entry.e.triggered();
                                    w.closeRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
