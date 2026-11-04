import QtQuick
import Quickshell

Overlay {
    id: s
    title: "session"
    hint: "key or enter · esc"
    boxWidth: 300
    boxHeight: 206

    readonly property var options: [
        { key: "l", text: "lock", cmd: [Quickshell.env("HOME") + "/.local/bin/lock"] },
        { key: "s", text: "suspend", cmd: ["systemctl", "suspend"] },
        { key: "e", text: "logout", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { key: "r", text: "reboot", cmd: ["systemctl", "reboot"] },
        { key: "p", text: "poweroff", cmd: ["systemctl", "poweroff"] },
    ]
    property int current: 0

    function run(o) {
        s.closeRequested();
        Niri.spawn(o.cmd);
    }

    Column {
        id: col
        width: parent.width
        spacing: 2
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: s.closeRequested()
        Keys.onUpPressed: s.current = (s.current + s.options.length - 1) % s.options.length
        Keys.onDownPressed: s.current = (s.current + 1) % s.options.length
        Keys.onReturnPressed: s.run(s.options[s.current])
        Keys.onPressed: e => {
            const o = s.options.find(o => o.key === e.text);
            if (o) s.run(o);
        }

        Repeater {
            model: s.options
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool sel: index === s.current
                width: col.width
                height: 32
                color: sel ? Theme.surfaceHigh : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle { width: 2; height: parent.height; color: Theme.fg; opacity: parent.sel ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    textFormat: Text.StyledText
                    text: "<font color='" + (parent.sel ? Theme.outline : Theme.line) + "'>(" + modelData.key + ")</font>  " + modelData.text
                    color: parent.sel ? Theme.fg : Theme.fgDim
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: s.current = index
                    onClicked: s.run(modelData)
                }
            }
        }
    }
}
