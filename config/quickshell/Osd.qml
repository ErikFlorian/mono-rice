import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume / brightness indicator: "vol [██████████░░░░░░░░░░] 45%"
Scope {
    id: root
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool ready: false

    function show(l, v, m) {
        label = l; value = v; muted = m ?? false;
        shown = true;
        hide.restart();
    }

    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Connections {
        target: root.sink
        function onVolumeChanged() { if (root.ready) root.show("vol", root.sink.volume, root.sink.muted); }
        function onMutedChanged() { if (root.ready) root.show("vol", root.sink.volume, root.sink.muted); }
    }
    Timer { running: true; interval: 1500; onTriggered: root.ready = true }
    Timer { id: hide; interval: 1400; onTriggered: { root.shown = false; linger.restart(); } }
    Timer { id: linger; interval: 220 }

    Process {
        id: bright
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(",");
                if (p.length >= 4) root.show("lum", parseInt(p[3]) / 100);
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { bright.running = true; }
    }

    PanelWindow {
        id: osdWin
        visible: root.shown || linger.running
        screen: Niri.screenFor(Niri.focusedOutput)
        anchors.bottom: true
        implicitWidth: 440
        margins.bottom: 80
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-osd"
        implicitHeight: 40
        color: "transparent"

        Rectangle {
            id: osdBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: row.implicitWidth + 32
            height: 38
            color: Theme.bg
            border.color: Theme.line
            border.width: 1
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            transform: Translate { y: root.shown ? 0 : 10; Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 10
                readonly property int cells: 24
                readonly property int filled: Math.round(Math.min(1, root.value) * cells)
                Txt { text: root.label; color: Theme.line }
                Txt {
                    text: "[" + "█".repeat(row.filled) + "░".repeat(row.cells - row.filled) + "]"
                    color: root.muted ? Theme.line : Theme.fgDim
                }
                Txt {
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: root.muted ? "mute" : Math.round(root.value * 100) + "%"
                    color: Theme.fgDim
                }
            }
        }
    }
}
