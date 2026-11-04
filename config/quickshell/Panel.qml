import QtQuick
import Quickshell

// Creates its content (an Overlay) while open and keeps it alive a moment
// after closing, so the Overlay can fade out. keepAlive: build it once at
// startup and only show/hide it afterwards (instant launcher).
Scope {
    id: p
    property bool open: false
    default property Component content

    property bool keepAlive: false
    property bool alive: keepAlive
    onOpenChanged: {
        if (open) { closeTimer.stop(); alive = true; }
        else if (!keepAlive) closeTimer.restart();
    }
    Timer { id: closeTimer; interval: 150; onTriggered: p.alive = false }

    LazyLoader {
        id: loader
        active: p.alive
        component: p.content
    }
    Binding {
        when: loader.item !== null
        target: loader.item
        property: "shown"
        value: p.open
    }
}
