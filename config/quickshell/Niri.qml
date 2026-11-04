pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// niri state from `niri msg --json event-stream`.
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property int focusedWindowId: -1
    property var layouts: []
    property int layoutIdx: 0
    property bool overview: false

    readonly property var focusedWindow: windows[focusedWindowId] ?? null
    readonly property string focusedOutput: {
        const w = workspaces.find(w => w.is_focused);
        return w ? w.output : "";
    }
    readonly property string layoutShort: {
        const n = layouts[layoutIdx] ?? "";
        if (n.startsWith("Czech")) return "cz";
        if (n.startsWith("English")) return "us";
        return n.slice(0, 2).toLowerCase();
    }

    function forOutput(out) {
        return workspaces.filter(w => w.output === out).sort((a, b) => a.idx - b.idx);
    }
    function occupied(wsId) {
        for (const id in windows)
            if (windows[id].workspace_id === wsId) return true;
        return false;
    }
    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }
    // start a program through niri, so it lives in its own scope and not inside
    // quickshell.service (restarting the shell must never kill apps or the lock)
    function spawn(args) {
        Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", ...args]);
    }
    function screenFor(name) {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    function handle(line) {
        let ev;
        try { ev = JSON.parse(line); } catch (e) { return; }
        const k = Object.keys(ev)[0];
        const d = ev[k];
        switch (k) {
        case "WorkspacesChanged":
            workspaces = d.workspaces;
            break;
        case "WorkspaceActivated": {
            const t = workspaces.find(w => w.id === d.id);
            if (!t) break;
            workspaces = workspaces.map(w => {
                const n = Object.assign({}, w);
                if (w.output === t.output) n.is_active = w.id === d.id;
                if (d.focused) n.is_focused = w.id === d.id;
                return n;
            });
            break;
        }
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(w => w.id === d.id ? Object.assign({}, w, { is_urgent: d.urgent }) : w);
            break;
        case "WindowsChanged": {
            const m = {};
            let f = -1;
            for (const w of d.windows) { m[w.id] = w; if (w.is_focused) f = w.id; }
            windows = m;
            focusedWindowId = f;
            break;
        }
        case "WindowOpenedOrChanged": {
            const m = Object.assign({}, windows);
            m[d.window.id] = d.window;
            windows = m;
            if (d.window.is_focused) focusedWindowId = d.window.id;
            break;
        }
        case "WindowClosed": {
            const m = Object.assign({}, windows);
            delete m[d.id];
            windows = m;
            if (focusedWindowId === d.id) focusedWindowId = -1;
            break;
        }
        case "WindowFocusChanged":
            focusedWindowId = d.id === null ? -1 : d.id;
            break;
        case "KeyboardLayoutsChanged":
            layouts = d.keyboard_layouts.names;
            layoutIdx = d.keyboard_layouts.current_idx;
            break;
        case "KeyboardLayoutSwitched":
            layoutIdx = d.idx;
            break;
        case "OverviewOpenedOrClosed":
            overview = d.is_open;
            break;
        }
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser { onRead: line => root.handle(line) }
        onExited: retry.start()
    }
    Timer { id: retry; interval: 1000; onTriggered: stream.running = true }
}
