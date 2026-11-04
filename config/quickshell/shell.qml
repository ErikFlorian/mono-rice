//@ pragma UseQApplication
//@ pragma IconTheme Tela-black-dark
import QtQuick
import Quickshell
import Quickshell.Io

// Monochrome TUI rice for niri.  IPC:  qs ipc call <launcher|clipboard|wallpaper|session> toggle
ShellRoot {
    id: shell

    property bool launcherOpen: false
    property bool clipboardOpen: false
    property bool wallpaperOpen: false
    property bool sessionOpen: false
    property bool dashboardOpen: false
    property bool windowsOpen: false

    function closeAll() { launcherOpen = clipboardOpen = wallpaperOpen = sessionOpen = dashboardOpen = windowsOpen = false; }

    Variants {
        model: Quickshell.screens
        Bar {
            onSessionRequested: { shell.closeAll(); shell.sessionOpen = true; }
            onDashboardRequested: { const o = !shell.dashboardOpen; shell.closeAll(); shell.dashboardOpen = o; }
        }
    }

    Variants {
        model: Quickshell.screens
        LiveWall {}
    }

    Notifications {}
    Osd {}

    // ── launcher ──────────────────────────────────────────────────────
    //   text      apps
    //   = 2^10    calculator (enter copies the result)
    //   > cmd     run a command          >> cmd   run it in a terminal
    //   : smile   emoji (enter copies)
    FileView {
        id: emojiFile
        path: Quickshell.env("HOME") + "/.local/share/rice/emoji.json"
        property var list: []
        onLoaded: { try { list = JSON.parse(text()); } catch (e) {} }
    }
    // app list for the launcher, built once (and again only when apps change)
    readonly property var appItems: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ text: e.name, sub: e.genericName || e.comment || "", icon: e.icon, data: { kind: "app", entry: e } }))
        .sort((a, b) => a.text.localeCompare(b.text))

    function calc(expr) {
        if (!/^[0-9a-z+\-*/%^().,\s]*$/i.test(expr)) return null;
        const names = { sqrt: "Math.sqrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", abs: "Math.abs",
                        log: "Math.log10", ln: "Math.log", round: "Math.round", floor: "Math.floor", ceil: "Math.ceil",
                        pi: "Math.PI", e: "Math.E", pow: "Math.pow", min: "Math.min", max: "Math.max" };
        let bad = false;
        const js = expr.replace(/,/g, ".").replace(/\^/g, "**").replace(/[a-z]+/gi, w => names[w.toLowerCase()] ?? (bad = true, w));
        if (bad || !js.trim()) return null;
        try {
            const v = Function("return (" + js + ")")();
            return typeof v === "number" && isFinite(v) ? String(+v.toPrecision(12)) : null;
        } catch (err) { return null; }
    }

    Panel {
        open: shell.launcherOpen
        Picker {
            id: launcher
            title: "run"
            placeholder: "app   = calc   > command   : emoji"
            showIcons: mode === "apps"
            readonly property string q: query.trim()
            readonly property string mode: q.startsWith("=") ? "calc" : q.startsWith(">") ? "cmd" : q.startsWith(":") ? "emoji" : "apps"
            filterEnabled: mode === "apps"
            hint: mode === "calc" ? "enter copies · esc" : mode === "cmd" ? "enter runs · >> in terminal · esc" : mode === "emoji" ? "enter copies · esc" : "↑↓ select · enter · esc"
            items: {
                if (mode === "calc") {
                    const r = shell.calc(q.slice(1));
                    return [{ text: r === null ? "…" : "= " + r, sub: q.slice(1).trim(), data: { kind: "calc", value: r } }];
                }
                if (mode === "cmd") {
                    const term = q.startsWith(">>");
                    const c = q.slice(term ? 2 : 1).trim();
                    return c ? [{ text: (term ? "terminal › " : "run › ") + c, data: { kind: "cmd", cmd: c, term: term } }] : [];
                }
                if (mode === "emoji") {
                    const t = q.slice(1).trim().toLowerCase();
                    return emojiFile.list.filter(e => !t || e[1].includes(t))
                        .sort((a, b) => (b[1].startsWith(t) - a[1].startsWith(t)))
                        .slice(0, 80)
                        .map(e => ({ text: e[0] + "  " + e[1], data: { kind: "emoji", value: e[0] } }));
                }
                return shell.appItems;
            }
            onAccepted: it => {
                const d = it.data;
                if (d.kind === "calc" && d.value === null) return;
                shell.launcherOpen = false;
                if (d.kind === "app") Niri.spawn(d.entry.runInTerminal ? ["foot", ...d.entry.command] : d.entry.command);
                else if (d.kind === "calc" || d.kind === "emoji")
                    Niri.spawn(["sh", "-c", "printf '%s' \"$1\" | wl-copy && notify-send -a launcher -t 1500 copied \"$1\"", "_", d.value]);
                else if (d.kind === "cmd")
                    Niri.spawn(d.term ? ["foot", "-H", "sh", "-c", d.cmd] : ["sh", "-c", d.cmd]);
            }
            onCloseRequested: shell.launcherOpen = false
        }
    }

    // ── window switcher (Mod+Tab) ─────────────────────────────────────
    Panel {
        open: shell.windowsOpen
        Picker {
            title: "windows"
            placeholder: "window"
            showIcons: true
            initialIndex: 1   // the previous window, like alt-tab
            items: Object.values(Niri.windows)
                .sort((a, b) => (b.focus_timestamp?.secs ?? 0) - (a.focus_timestamp?.secs ?? 0) || (b.focus_timestamp?.nanos ?? 0) - (a.focus_timestamp?.nanos ?? 0))
                .map(w => {
                    const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
                    const app = (w.app_id || "").split(".").pop().toLowerCase();
                    const de = DesktopEntries.heuristicLookup(w.app_id || "");
                    return { text: w.title || app, sub: app + (ws ? "  ·  " + ws.output + "/" + ws.idx : ""), icon: de ? de.icon : w.app_id, data: w.id };
                })
            onAccepted: it => { shell.windowsOpen = false; Niri.action("focus-window", "--id", String(it.data)); }
            onCloseRequested: shell.windowsOpen = false
        }
    }

    // ── clipboard (cliphist) ──────────────────────────────────────────
    Process {
        id: cliplist
        property var lines: []
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: cliplist.lines = this.text.split("\n").filter(l => l.length)
        }
    }
    Panel {
        open: shell.clipboardOpen
        Picker {
            title: "clipboard"
            placeholder: "history  (ctrl+shift+c in niri wipes it)"
            items: cliplist.lines.map(l => {
                const t = l.slice(l.indexOf("\t") + 1).replace(/\s+/g, " ");
                return { text: t.startsWith("[[ binary") ? "▣ " + t.slice(3, -3) : t, data: l };
            })
            onAccepted: it => {
                shell.clipboardOpen = false;
                Niri.spawn(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", it.data]);
            }
            onCloseRequested: shell.clipboardOpen = false
        }
    }

    Panel {
        open: shell.wallpaperOpen
        Wallpapers { onCloseRequested: shell.wallpaperOpen = false }
    }
    Panel {
        open: shell.sessionOpen
        Session { onCloseRequested: shell.sessionOpen = false }
    }

    Panel {
        open: shell.dashboardOpen
        Dashboard {
            onCloseRequested: shell.dashboardOpen = false
            onSessionRequested: { shell.closeAll(); shell.sessionOpen = true; }
        }
    }

    IpcHandler {
        target: "windows"
        function toggle(): void { const o = !shell.windowsOpen; shell.closeAll(); shell.windowsOpen = o; }
    }
    IpcHandler {
        target: "dashboard"
        function toggle(): void { const o = !shell.dashboardOpen; shell.closeAll(); shell.dashboardOpen = o; }
    }
    IpcHandler {
        target: "caffeine"
        function toggle(): void {
            Prefs.caffeine = !Prefs.caffeine;
            Niri.spawn(["notify-send", "-a", "caffeine", "-t", "1500", Prefs.caffeine ? "caffeine on" : "caffeine off", Prefs.caffeine ? "no auto lock / sleep" : "idle timers are back"]);
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { const o = !shell.launcherOpen; shell.closeAll(); shell.launcherOpen = o; }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            const o = !shell.clipboardOpen; shell.closeAll();
            if (o) cliplist.running = true;
            shell.clipboardOpen = o;
        }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { const o = !shell.wallpaperOpen; shell.closeAll(); shell.wallpaperOpen = o; }
    }
    IpcHandler {
        target: "session"
        function toggle(): void { const o = !shell.sessionOpen; shell.closeAll(); shell.sessionOpen = o; }
    }
}
