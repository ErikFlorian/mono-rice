pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Toggles that survive restarts (~/.local/state/rice/state.json).
Singleton {
    id: root

    property bool caffeine: false
    property bool dnd: false
    property bool liveWall: false

    property bool loaded: false
    function save() {
        if (!loaded) return;
        adapter.caffeine = caffeine;
        adapter.dnd = dnd;
        adapter.liveWall = liveWall;
        file.writeAdapter();
    }
    onCaffeineChanged: save()
    onDndChanged: save()
    onLiveWallChanged: save()

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/rice/state.json"
        onLoaded: {
            root.caffeine = adapter.caffeine;
            root.dnd = adapter.dnd;
            root.liveWall = adapter.liveWall;
            root.loaded = true;
        }
        onLoadFailed: { root.loaded = true; root.save(); }
        JsonAdapter {
            id: adapter
            property bool caffeine: false
            property bool dnd: false
            property bool liveWall: false
        }
    }
}
