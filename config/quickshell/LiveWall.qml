import QtQuick
import Quickshell
import Quickshell.Wayland

// "Live wallpaper": faint columns of glyphs drifting down over the wallpaper,
// on the same character grid as the ASCII wallpapers. Toggle: Prefs.liveWall
// (control panel). Sits in the background layer, takes no input.
PanelWindow {
    id: lw
    required property var modelData

    screen: modelData
    visible: Prefs.liveWall
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "rice-livewall"
    color: "transparent"

    readonly property string glyphs: ".:-=+*!ic7?vxzoYJ0UOX#%@"
    readonly property int cw: 6     // glyph cell of the ASCII wallpapers (JetBrains Mono 10px)
    readonly property int ch: 12
    readonly property int cols: Math.floor(width / cw)

    function glyph() { return glyphs[Math.floor(Math.random() * glyphs.length)]; }
    function column(n) { let s = []; for (let i = 0; i < n; i++) s.push(glyph()); return s.join("\n"); }

    Repeater {
        id: rep
        model: lw.visible ? 34 : 0

        Text {
            id: drop
            property int len: 0
            property real fx: Math.random()   // column, as a fraction of the width
            x: Math.floor(fx * lw.cols) * lw.cw

            function reseed() {
                len = 5 + Math.floor(Math.random() * 12);
                text = lw.column(len);
                fx = Math.random();
                opacity = 0.18 + Math.random() * 0.3;
                fall.duration = 9000 + Math.random() * 16000;
            }

            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 10
            lineHeightMode: Text.FixedHeight
            lineHeight: lw.ch
            renderType: Text.NativeRendering
            y: -height

            Component.onCompleted: { reseed(); start.interval = Math.random() * 12000; start.start(); }
            Timer { id: start; onTriggered: fallLoop.start() }

            SequentialAnimation {
                id: fallLoop
                loops: Animation.Infinite
                NumberAnimation { id: fall; target: drop; property: "y"; from: -drop.height; to: lw.height }
                ScriptAction { script: drop.reseed() }
            }

            // the head glyph keeps changing, like it is being typed
            Timer {
                interval: 280 + Math.random() * 400
                running: fallLoop.running
                repeat: true
                onTriggered: {
                    const lines = drop.text.split("\n");
                    lines[lines.length - 1] = lw.glyph();
                    if (Math.random() < 0.3) lines[Math.floor(Math.random() * lines.length)] = lw.glyph();
                    drop.text = lines.join("\n");
                }
            }
        }
    }
}
