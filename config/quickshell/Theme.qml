pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors come from matugen (~/.config/matugen/rice.toml -> ~/.local/state/rice/colors.json)
// and fade over when the wallpaper changes.
Singleton {
    id: root

    property color bg: "#131313"
    property color surface: "#131313"
    property color surfaceLow: "#1b1b1b"
    property color surfaceMid: "#1f1f1f"
    property color surfaceHigh: "#2a2a2a"
    property color fg: "#e2e2e2"
    property color fgDim: "#c6c6c6"
    property color outline: "#919191"
    property color line: "#474747"
    property color accent: "#ffffff"
    property color accentFg: "#1b1b1b"
    property color danger: "#ffb4ab"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int size: 12
    readonly property int barHeight: 26

    Behavior on bg { ColorAnimation { duration: 600 } }
    Behavior on surfaceLow { ColorAnimation { duration: 600 } }
    Behavior on surfaceHigh { ColorAnimation { duration: 600 } }
    Behavior on fg { ColorAnimation { duration: 600 } }
    Behavior on fgDim { ColorAnimation { duration: 600 } }
    Behavior on outline { ColorAnimation { duration: 600 } }
    Behavior on line { ColorAnimation { duration: 600 } }
    Behavior on accent { ColorAnimation { duration: 600 } }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                for (const k in c)
                    if (k in root) root[k] = c[k];
            } catch (e) {}
        }
    }
}
