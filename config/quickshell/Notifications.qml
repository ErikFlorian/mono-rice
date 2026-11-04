import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notification popups (top right of the focused screen); daemon lives in Notifs.qml.
Scope {
    id: root

    PanelWindow {
        visible: Notifs.popups.length > 0
        screen: Niri.screenFor(Niri.focusedOutput)
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-notifications"
        implicitWidth: 380
        implicitHeight: Math.max(1, col.implicitHeight)
        color: "transparent"

        Column {
            id: col
            width: parent.width
            spacing: 8

            Repeater {
                model: Notifs.popups
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool critical: n.urgency === NotificationUrgency.Critical
                    width: col.width
                    height: inner.implicitHeight + 20
                    color: Theme.bg
                    border.width: 1
                    border.color: critical ? Theme.danger : Theme.line

                    // slide in from the right, slide back out before closing
                    property bool leaving: false
                    x: 40; opacity: 0
                    Component.onCompleted: { x = 0; opacity = 1; }
                    function close(fn) {
                        if (leaving) return;
                        leaving = true; x = 60; opacity = 0;
                        outTimer.fn = fn; outTimer.start();
                    }
                    Timer { id: outTimer; property var fn; interval: 200; onTriggered: fn() }
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle { width: 1; height: parent.height; color: card.critical ? Theme.danger : Theme.outline }

                    Timer {
                        running: !card.critical && !hover.containsMouse
                        interval: card.n.expireTimeout > 0 ? card.n.expireTimeout * 1000 : 6000
                        onTriggered: card.close(() => Notifs.hide(card.n))
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            const def = card.n.actions.find(a => a.identifier === "default");
                            if (mouse.button === Qt.LeftButton && def) def.invoke();
                            card.close(() => card.n.dismiss());
                        }
                    }

                    Column {
                        id: inner
                        x: 14; y: 10
                        width: parent.width - 28
                        spacing: 3
                        Row {
                            width: parent.width
                            Txt {
                                width: parent.width - time.width
                                text: (card.n.appName || "notify").toLowerCase()
                                color: Theme.outline
                                font.pixelSize: Theme.size - 1
                                elide: Text.ElideRight
                            }
                            Txt { id: time; text: Qt.formatTime(Notifs.times[card.n.id] ?? new Date(), "HH:mm"); color: Theme.outline; font.pixelSize: Theme.size - 1 }
                        }
                        Txt {
                            width: parent.width
                            text: card.n.summary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: card.n.body
                            textFormat: Text.StyledText
                            color: Theme.fgDim
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 12
                            topPadding: 4
                            visible: card.n.actions.some(a => a.identifier !== "default")
                            Repeater {
                                model: card.n.actions.filter(a => a.identifier !== "default")
                                Txt {
                                    required property var modelData
                                    text: "[ " + modelData.text.toLowerCase() + " ]"
                                    color: am.containsMouse ? Theme.accent : Theme.fgDim
                                    MouseArea {
                                        id: am
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { modelData.invoke(); card.close(() => card.n.dismiss()); }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
