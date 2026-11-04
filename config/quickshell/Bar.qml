import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

PanelWindow {
    id: bar
    required property var modelData
    signal sessionRequested
    signal dashboardRequested

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg
    WlrLayershell.namespace: "rice-bar"

    readonly property bool focusedHere: Niri.focusedOutput === modelData.name

    // caffeine: keep the session from idling (swayidle lock/suspend) while on
    IdleInhibitor { window: bar; enabled: Prefs.caffeine }

    // tray context menu (TrayMenu.qml); menuItem survives the close animation
    property var menuItem: null
    property bool menuOpen: false
    property real menuX: 0
    Panel {
        open: bar.menuOpen
        TrayMenu {
            screen: bar.screen
            trayItem: bar.menuItem
            anchorX: bar.menuX
            onCloseRequested: bar.menuOpen = false
        }
    }

    // Small text module: dim label, value brightens on hover.
    component Module: Item {
        id: m
        property string label: ""
        property string value: ""
        property color valueColor: Theme.fgDim
        signal clicked(var mouse)
        signal scrolled(int delta)
        implicitWidth: row.implicitWidth
        implicitHeight: bar.height
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Txt { text: m.label; color: Theme.line; visible: m.label !== "" }
            Txt {
                id: val
                text: m.value
                color: ma.containsMouse ? Theme.fg : m.valueColor
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => m.clicked(mouse)
            onWheel: wheel => m.scrolled(wheel.angleDelta.y)
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.surfaceHigh }

    // whole bar content drops in at startup
    Item {
        id: content
        width: parent.width
        height: parent.height
        opacity: 0
        y: -8
        Component.onCompleted: { opacity = 1; y = 0; }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        // ── left: workspaces + focused window ─────────────────────────
        Row {
            id: left
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Item {
                id: wsBox
                readonly property var list: Niri.forOutput(bar.modelData.name)
                readonly property int activeIndex: list.findIndex(w => w.is_active)
                width: wsRow.width
                height: bar.height

                Row {
                    id: wsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        id: wsRep
                        model: wsBox.list
                        Item {
                            id: wsItem
                            required property var modelData
                            readonly property bool active: modelData.is_active
                            readonly property bool busy: Niri.occupied(modelData.id)
                            width: 18
                            height: bar.height
                            Txt {
                                anchors.centerIn: parent
                                text: modelData.idx
                                color: modelData.is_urgent ? Theme.danger
                                     : active ? (bar.focusedHere ? Theme.fg : Theme.fgDim)
                                     : busy ? Theme.outline : Theme.line
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: wsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Niri.action("focus-workspace", String(modelData.id))
                            }
                        }
                    }
                }
                // sliding underline under the active workspace
                Rectangle {
                    id: underline
                    readonly property var target: wsRep.count, wsBox.activeIndex >= 0 ? wsRep.itemAt(wsBox.activeIndex) : null
                    visible: target !== null
                    y: bar.height - 5
                    height: 1
                    x: target ? wsRow.x + target.x + 4 : 0
                    width: target ? target.width - 8 : 0
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    color: bar.focusedHere ? Theme.fg : Theme.outline
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // focused window: crossfades when it changes
            Item {
                id: title
                readonly property var w: Niri.focusedWindow
                readonly property bool here: w && wsBox.list.some(x => x.id === w.workspace_id)
                readonly property string app: here ? (w.app_id || "").split(".").pop().toLowerCase() : ""
                readonly property string name: here ? w.title : ""
                width: Math.min(titleRow.implicitWidth, bar.width * 0.3)
                height: bar.height
                clip: true
                onAppChanged: swap.restart()
                SequentialAnimation {
                    id: swap
                    NumberAnimation { target: titleRow; property: "opacity"; to: 0.2; duration: 70 }
                    NumberAnimation { target: titleRow; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                }
                Row {
                    id: titleRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Txt { text: title.app; color: Theme.outline; visible: text !== "" }
                    Txt {
                        text: title.name
                        color: Theme.fgDim
                        width: Math.min(implicitWidth, bar.width * 0.3 - 80)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ── center: clock (date slides out on hover) ──────────────────
        SystemClock { id: clock; precision: SystemClock.Seconds }
        Item {
            id: clockBox
            anchors.centerIn: parent
            width: clockRow.width
            height: bar.height
            Row {
                id: clockRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Item {
                    // date, collapsed until hover
                    width: clockHover.containsMouse ? dateText.implicitWidth + 14 : 0
                    height: bar.height
                    clip: true
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Txt {
                        id: dateText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale("cs_CZ").toString(clock.date, "dddd d. MMMM").toLowerCase()
                        color: Theme.outline
                        opacity: clockHover.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }
                }
                Txt {
                    text: Qt.formatDateTime(clock.date, "HH")
                    font.pixelSize: Theme.size + 1
                }
                Txt {
                    // colon breathes once a second
                    text: ":"
                    font.pixelSize: Theme.size + 1
                    color: Theme.outline
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                    }
                }
                Txt {
                    text: Qt.formatDateTime(clock.date, "mm")
                    font.pixelSize: Theme.size + 1
                }
            }
            MouseArea { id: clockHover; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true }
        }

        // ── right: status ─────────────────────────────────────────────
        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

        Process {
            id: wifi
            property string text: "--"
            command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -1; nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -m1 '^ethernet:connected'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const l = this.text.trim().split("\n");
                    if (l.some(x => x.startsWith("ethernet"))) wifi.text = "eth";
                    else if (l[0].startsWith("yes")) {
                        const p = l[0].split(":");
                        wifi.text = p.slice(1, -1).join(":");
                    } else wifi.text = "offline";
                }
            }
        }
        Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: wifi.running = true }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: bar.height
            spacing: 20

            Module {
                readonly property var p: Mpris.players.values.find(p => p.isPlaying) ?? null
                visible: p !== null && bar.width >= 1600
                label: "♪"
                value: {
                    if (!p) return "";
                    const t = (p.trackArtist ? p.trackArtist + " – " : "") + p.trackTitle;
                    return t.length > 32 ? t.slice(0, 31) + "…" : t;
                }
                onClicked: mouse => { if (mouse.button === Qt.MiddleButton) { if (p) p.togglePlaying(); } else bar.dashboardRequested(); }
            }
            // small state marks: caffeine / dnd / unread notifications
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Txt {
                    visible: Prefs.caffeine
                    text: "󰅶"
                    color: Theme.fg
                    SequentialAnimation on opacity {
                        running: Prefs.caffeine
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.caffeine = false }
                }
                Txt {
                    text: Prefs.dnd ? "󰂛" : Notifs.count ? "󰂚 " + Notifs.count : ""
                    visible: text !== ""
                    color: Prefs.dnd ? Theme.outline : Theme.fgDim
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.dashboardRequested() }
                }
            }

            Module {
                readonly property var a: Pipewire.defaultAudioSink?.audio ?? null
                label: "vol"
                value: !a ? "--" : a.muted ? "mute" : Math.round(a.volume * 100) + "%"
                valueColor: a && a.muted ? Theme.line : Theme.fgDim
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Niri.spawn(["pavucontrol"]);
                    else if (mouse.button === Qt.MiddleButton) { if (a) a.muted = !a.muted; }
                    else bar.dashboardRequested();
                }
                onScrolled: d => { if (a) a.volume = Math.max(0, Math.min(1.5, a.volume + (d > 0 ? 0.05 : -0.05))); }
            }
            Module {
                label: "net"
                value: wifi.text
                valueColor: wifi.text === "offline" ? Theme.line : Theme.fgDim
                onClicked: bar.dashboardRequested()
            }
            Module {
                readonly property var dev: UPower.displayDevice
                readonly property int pct: dev ? Math.round(dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
                readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
                visible: dev && dev.isLaptopBattery
                label: charging ? "ac" : "bat"
                value: pct + "%"
                valueColor: pct <= 15 && !charging ? Theme.danger : Theme.fgDim
                onClicked: bar.dashboardRequested()
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: SystemTray.items.values.length > 0
                Repeater {
                    model: SystemTray.items
                    Item {
                        id: trayItem
                        required property var modelData
                        width: 14; height: 14
                        IconImage { id: icon; anchors.fill: parent; source: trayItem.modelData.icon; visible: false }
                        MultiEffect {
                            anchors.fill: icon
                            source: icon
                            saturation: -1  // keep the bar monochrome
                            opacity: trayMa.containsMouse ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }
                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const it = trayItem.modelData;
                                if (mouse.button === Qt.RightButton || it.onlyMenu) {
                                    if (it.hasMenu) {
                                        bar.menuItem = it;
                                        bar.menuX = trayItem.mapToItem(bar.contentItem, trayItem.width / 2, 0).x;
                                        bar.menuOpen = true;
                                    }
                                } else if (mouse.button === Qt.MiddleButton) it.secondaryActivate();
                                else it.activate();
                            }
                        }
                    }
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "⏻"
                color: powerMa.containsMouse ? Theme.fg : Theme.outline
                rotation: powerMa.containsMouse ? 90 : 0
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                MouseArea { id: powerMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.sessionRequested() }
            }
        }
    }
}
