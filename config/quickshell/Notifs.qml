pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Popups time out but stay in the history
// (server.trackedNotifications) until dismissed or cleared.
Singleton {
    id: root

    property var popups: []
    property var times: ({})  // notification id -> arrival time
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length

    function hide(n) { popups = popups.filter(p => p !== n); }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            root.times[n.id] = new Date();
            n.closed.connect(() => root.hide(n));
            if (Prefs.dnd && n.urgency !== NotificationUrgency.Critical) return;
            root.popups = [n, ...root.popups].slice(0, 5);
        }
    }
}
