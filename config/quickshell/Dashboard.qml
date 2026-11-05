import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

// Control panel dropping from the right of the bar (Mod+A or click on the status area).
PanelWindow {
    id: w
    property bool shown: true
    signal closeRequested
    signal sessionRequested

    screen: Niri.screenFor(Niri.focusedOutput)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-dashboard"
    color: "transparent"

    property real t: 0
    Component.onCompleted: t = Qt.binding(() => shown ? 1 : 0)
    Behavior on t { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    function sh(cmd, ...args) { Niri.spawn(["sh", "-c", cmd, "_", ...args]); }
    function fmt(s) {
        if (!isFinite(s) || s < 0) return "-:--";
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ── data ──────────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    property real brightness: 0
    Process {
        id: brightGet
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector { onStreamFinished: { const p = this.text.trim().split(","); if (p.length >= 4) w.brightness = parseInt(p[3]) / 100; } }
    }
    function setBrightness(v) {
        w.brightness = Math.max(0.01, v);
        sh("brightnessctl -q set \"$1\"%", String(Math.round(w.brightness * 100)));
    }

    property bool wifiOn: true
    property var networks: []
    Process {
        id: wifiGet
        running: true
        // radio state, visible networks, then (after ---) the names of saved wifi connections
        command: ["sh", "-c", "nmcli radio wifi; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null; echo ---; nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':802-11-wireless$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = this.text.trim().split("\n");
                const cut = all.indexOf("---");
                const lines = cut >= 0 ? all.slice(0, cut) : all;
                const saved = (cut >= 0 ? all.slice(cut + 1) : []).map(l => l.replace(/:802-11-wireless$/, "").replace(/\\:/g, ":"));
                w.wifiOn = lines[0] === "enabled";
                // one row per SSID: connected if any access point is in use, strongest signal
                const by = {};
                for (const l of lines.slice(1)) {
                    const p = l.replace(/\\:/g, "\u0001").split(":").map(x => x.replace(/\u0001/g, ":"));
                    if (!p[1]) continue;
                    const n = by[p[1]] ?? (by[p[1]] = { ssid: p[1], active: false, signal: 0, secure: !!p[3], saved: saved.includes(p[1]) });
                    n.active = n.active || p[0] === "*";
                    n.signal = Math.max(n.signal, parseInt(p[2]) || 0);
                }
                w.networks = Object.values(by)
                    .sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                    .slice(0, 7);
            }
        }
    }
    Timer { interval: 8000; running: w.shown; repeat: true; onTriggered: wifiGet.running = true }

    // connecting: saved / open networks go straight away, new secured ones ask for the
    // password inline (row expands), errors are shown under the network
    property string askSsid: ""        // network whose password field is open
    property string busySsid: ""       // network being connected right now
    property string wifiError: ""
    property string errorSsid: ""
    function connectWifi(n, password) {
        if (busySsid !== "") return;
        if (n.secure && !n.saved && password === undefined) { askSsid = n.ssid; errorSsid = ""; return; }
        busySsid = n.ssid; errorSsid = ""; wifiError = "";
        wifiConnect.command = n.saved ? ["nmcli", "connection", "up", "id", n.ssid]
                            : password ? ["nmcli", "device", "wifi", "connect", n.ssid, "password", password]
                            : ["nmcli", "device", "wifi", "connect", n.ssid];
        wifiConnect.running = true;
    }
    Process {
        id: wifiConnect
        stderr: StdioCollector { id: wifiErr }
        onExited: code => {
            if (code === 0) { w.askSsid = ""; }
            else {
                w.errorSsid = w.busySsid;
                const e = wifiErr.text.toLowerCase();
                w.wifiError = e.includes("secrets") || e.includes("password") || e.includes("802-1x") ? "wrong password?" : "could not connect";
                // a failed new network leaves a half-made profile behind; drop it so the password is asked again
                if (w.askSsid === w.busySsid) Quickshell.execDetached(["nmcli", "connection", "delete", "id", w.busySsid]);
            }
            w.busySsid = "";
            wifiGet.running = true;
        }
    }

    property string profile: ""
    Process {
        id: profGet
        running: true
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector { onStreamFinished: w.profile = this.text.trim() }
    }

    property string mode: "mono"
    FileView { path: Quickshell.env("HOME") + "/.local/state/rice/mode"; watchChanges: true; onFileChanged: reload(); onLoaded: w.mode = text().trim() || "mono" }

    property string hostname: ""
    FileView { path: "/etc/hostname"; onLoaded: w.hostname = text().trim() }

    property string uptime: ""
    FileView {
        id: up
        path: "/proc/uptime"
        onLoaded: {
            const s = Math.floor(parseFloat(text()));
            const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
            w.uptime = "up " + (h ? h + "h " : "") + m + "m";
        }
    }

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    Timer { interval: 1000; running: w.shown && w.player !== null && w.player.isPlaying; repeat: true; onTriggered: w.player.positionChanged() }

    readonly property var bt: Bluetooth.defaultAdapter

    // ── layout ────────────────────────────────────────────────────────
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: w.closeRequested() }

    Rectangle {
        id: box
        width: 440
        readonly property real fullHeight: Math.min(w.height - Theme.barHeight - 20, flick.contentHeight + 28)
        height: fullHeight
        clip: true
        x: w.width - width - 8
        y: Theme.barHeight + 6
        color: Theme.bg
        border.color: Theme.line
        border.width: 1
        opacity: w.t
        focus: true
        Keys.onEscapePressed: w.closeRequested()
        MouseArea { anchors.fill: parent }

        Flickable {
            id: flick
            x: 14
            y: 14
            width: parent.width - 28
            height: box.fullHeight - 28
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: flick.width
                spacing: 6

                // header
                Item {
                    width: parent.width
                    height: 26
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Txt { text: Quickshell.env("USER") + "@" + w.hostname }
                        Txt { text: w.uptime; color: Theme.outline }
                    }
                    Txt {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⏻"
                        color: pw.containsMouse ? Theme.fg : Theme.outline
                        MouseArea { id: pw; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.sessionRequested() }
                    }
                }

                // sliders
                Section { title: "levels" }
                TuiSlider {
                    label: "vol"
                    value: w.sink ? w.sink.volume : 0
                    muted: w.sink ? w.sink.muted : false
                    onMoved: v => { if (w.sink) { w.sink.muted = false; w.sink.volume = v; } }
                    onLabelClicked: if (w.sink) w.sink.muted = !w.sink.muted
                }
                TuiSlider {
                    label: "mic"
                    value: w.source ? w.source.volume : 0
                    muted: w.source ? w.source.muted : false
                    onMoved: v => { if (w.source) { w.source.muted = false; w.source.volume = v; } }
                    onLabelClicked: if (w.source) w.source.muted = !w.source.muted
                }
                TuiSlider {
                    label: "lum"
                    value: w.brightness
                    onMoved: v => w.setBrightness(v)
                }

                // toggles
                Section { title: "toggles" }
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 0
                    rowSpacing: 2
                    TuiToggle { width: col.width / 2; label: "wifi"; checked: w.wifiOn; onToggled: { w.sh(w.wifiOn ? "nmcli radio wifi off" : "nmcli radio wifi on"); w.wifiOn = !w.wifiOn; } }
                    TuiToggle {
                        width: col.width / 2; label: "bluetooth"
                        checked: w.bt ? w.bt.enabled : false
                        onToggled: if (w.bt) w.bt.enabled = !w.bt.enabled
                    }
                    TuiToggle { width: col.width / 2; label: "caffeine"; sub: Prefs.caffeine ? "no sleep" : ""; checked: Prefs.caffeine; onToggled: Prefs.caffeine = !Prefs.caffeine }
                    TuiToggle { width: col.width / 2; label: "do not disturb"; checked: Prefs.dnd; onToggled: Prefs.dnd = !Prefs.dnd }
                    TuiToggle { width: col.width / 2; label: "live wallpaper"; checked: Prefs.liveWall; onToggled: Prefs.liveWall = !Prefs.liveWall }
                    TuiToggle {
                        width: col.width / 2; label: "color theme"; sub: w.mode
                        checked: w.mode === "color"
                        onToggled: w.sh(Quickshell.env("HOME") + "/.config/quickshell/scripts/setwall.sh \"\" \"$1\"", w.mode === "mono" ? "color" : "mono")
                    }
                }

                // power profile
                Item {
                    width: parent.width
                    height: 28
                    Row {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Txt { text: "power"; color: Theme.outline; width: 50 }
                        Repeater {
                            model: [["power-saver", "saver"], ["balanced", "balanced"], ["performance", "perf"]]
                            Txt {
                                required property var modelData
                                readonly property bool on: w.profile === modelData[0]
                                text: on ? "[" + modelData[1] + "]" : " " + modelData[1] + " "
                                color: on ? Theme.fg : pm.containsMouse ? Theme.fgDim : Theme.line
                                Behavior on color { ColorAnimation { duration: 120 } }
                                MouseArea {
                                    id: pm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { w.profile = modelData[0]; w.sh("powerprofilesctl set \"$1\"", modelData[0]); }
                                }
                            }
                        }
                    }
                }

                // media
                Section { title: "media"; visible: w.player !== null; action: w.player ? (w.player.identity || "").toLowerCase() : "" }
                Column {
                    visible: w.player !== null
                    width: parent.width
                    spacing: 4
                    leftPadding: 6
                    Txt {
                        width: parent.width - 12
                        text: w.player ? (w.player.trackTitle || "unknown") : ""
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                    Txt {
                        width: parent.width - 12
                        text: w.player ? [w.player.trackArtist, w.player.trackAlbum].filter(x => x).join(" · ") : ""
                        color: Theme.outline
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                    Row {
                        spacing: 8
                        readonly property real frac: w.player && w.player.length > 0 ? w.player.position / w.player.length : 0
                        readonly property int cells: 24
                        Txt { text: w.player ? w.fmt(w.player.position) : ""; color: Theme.outline; width: 40 }
                        Txt {
                            text: "[" + "█".repeat(Math.round(parent.frac * parent.cells)) + "░".repeat(parent.cells - Math.round(parent.frac * parent.cells)) + "]"
                            color: Theme.fgDim
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => { if (w.player && w.player.canSeek && w.player.length > 0) w.player.position = (mouse.x / width) * w.player.length; }
                            }
                        }
                        Txt { text: w.player ? w.fmt(w.player.length) : ""; color: Theme.outline }
                    }
                    Row {
                        spacing: 22
                        topPadding: 2
                        Repeater {
                            model: [["⏮", () => w.player.previous()], [w.player && w.player.isPlaying ? "⏸" : "▶", () => w.player.togglePlaying()], ["⏭", () => w.player.next()]]
                            Txt {
                                required property var modelData
                                text: modelData[0]
                                font.pixelSize: Theme.size + 2
                                color: mm.containsMouse ? Theme.fg : Theme.fgDim
                                scale: mm.pressed ? 0.85 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                MouseArea { id: mm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (w.player) modelData[1]() }
                            }
                        }
                    }
                }

                // wifi networks
                Section {
                    title: "wifi"
                    visible: w.wifiOn
                    action: "rescan"
                    onActionClicked: { w.sh("nmcli dev wifi rescan"); rescan.start(); }
                    Timer { id: rescan; interval: 3500; onTriggered: wifiGet.running = true }
                }
                Repeater {
                    model: w.wifiOn ? w.networks : []
                    Column {
                        id: net
                        required property var modelData
                        readonly property bool asking: w.askSsid === modelData.ssid
                        width: col.width

                        Rectangle {
                            width: col.width
                            height: 24
                            color: nm.containsMouse || net.asking ? Theme.surfaceHigh : "transparent"
                            Row {
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Txt {
                                    text: "▂▄▆█".slice(0, Math.max(1, Math.ceil(net.modelData.signal / 25))).padEnd(4, " ")
                                    color: net.modelData.active ? Theme.fg : Theme.outline
                                }
                                Txt { text: net.modelData.ssid; color: net.modelData.active ? Theme.fg : Theme.fgDim }
                                Txt {
                                    color: w.errorSsid === net.modelData.ssid ? Theme.danger : Theme.outline
                                    text: w.busySsid === net.modelData.ssid ? "connecting…"
                                        : w.errorSsid === net.modelData.ssid ? w.wifiError
                                        : net.modelData.active ? "connected"
                                        : !net.modelData.secure ? "open"
                                        : net.modelData.saved ? "saved" : ""
                                }
                            }
                            MouseArea {
                                id: nm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (net.modelData.active) return;
                                    if (net.asking) { w.askSsid = ""; return; }
                                    w.connectWifi(net.modelData);
                                }
                            }
                        }

                        // password row for a new secured network
                        Rectangle {
                            visible: net.asking
                            width: col.width
                            height: 30
                            color: Theme.surfaceHigh
                            Row {
                                x: 30
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Txt { text: "password"; color: Theme.outline }
                                Rectangle {
                                    width: col.width - 170
                                    height: 22
                                    color: Theme.bg
                                    border.color: pw.activeFocus ? Theme.outline : Theme.line
                                    border.width: 1
                                    TextInput {
                                        id: pw
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        passwordCharacter: "•"
                                        color: Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.size
                                        clip: true
                                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                        Keys.onEscapePressed: w.askSsid = ""
                                        onAccepted: if (text.length) w.connectWifi(net.modelData, text)
                                    }
                                }
                                Txt {
                                    text: "[ ok ]"
                                    color: okMa.containsMouse ? Theme.fg : Theme.fgDim
                                    MouseArea { id: okMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (pw.text.length) w.connectWifi(net.modelData, pw.text) }
                                }
                            }
                        }
                    }
                }

                // bluetooth
                Section { title: "bluetooth"; visible: w.bt && w.bt.enabled }
                Repeater {
                    model: w.bt && w.bt.enabled ? w.bt.devices.values.filter(d => d.paired).sort((a, b) => b.connected - a.connected) : []
                    Rectangle {
                        required property var modelData
                        width: col.width
                        height: 24
                        color: bm.containsMouse ? Theme.surfaceHigh : "transparent"
                        Row {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Txt { text: modelData.connected ? "●" : "○"; color: modelData.connected ? Theme.fg : Theme.line }
                            Txt { text: modelData.name || modelData.deviceName; color: modelData.connected ? Theme.fg : Theme.fgDim }
                            Txt { visible: modelData.batteryAvailable; text: Math.round(modelData.battery * 100) + "%"; color: Theme.outline }
                        }
                        MouseArea {
                            id: bm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                }
                Txt {
                    visible: w.bt && w.bt.enabled && !w.bt.devices.values.some(d => d.paired)
                    x: 6
                    text: "no paired devices"
                    color: Theme.line
                }

                // notifications
                Section {
                    title: "notifications" + (Notifs.count ? " (" + Notifs.count + ")" : "")
                    action: Notifs.count ? "clear" : ""
                    onActionClicked: Notifs.clearAll()
                }
                Txt { visible: Notifs.count === 0; x: 6; text: Prefs.dnd ? "do not disturb is on" : "nothing new"; color: Theme.line; height: 24 }
                Repeater {
                    model: Notifs.history
                    Rectangle {
                        id: nc
                        required property var modelData
                        readonly property var n: modelData
                        width: col.width
                        height: ncol.implicitHeight + 12
                        color: ncm.containsMouse ? Theme.surfaceHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Rectangle { width: 1; height: parent.height; color: nc.n.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.line }
                        MouseArea {
                            id: ncm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                const def = nc.n.actions.find(a => a.identifier === "default");
                                if (mouse.button === Qt.LeftButton && def) { def.invoke(); w.closeRequested(); }
                                nc.n.dismiss();
                            }
                        }
                        Column {
                            id: ncol
                            x: 12; y: 6
                            width: parent.width - 24
                            spacing: 2
                            Row {
                                width: parent.width
                                Txt { width: parent.width - tm.width; text: (nc.n.appName || "notify").toLowerCase(); color: Theme.outline; font.pixelSize: Theme.size - 1; elide: Text.ElideRight }
                                Txt { id: tm; text: Qt.formatTime(Notifs.times[nc.n.id] ?? new Date(), "HH:mm"); color: Theme.line; font.pixelSize: Theme.size - 1 }
                            }
                            Txt { width: parent.width; text: nc.n.summary; elide: Text.ElideRight }
                            Txt { width: parent.width; visible: text !== ""; text: nc.n.body; textFormat: Text.StyledText; color: Theme.fgDim; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
