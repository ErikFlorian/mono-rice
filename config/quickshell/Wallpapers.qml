import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Wallpaper picker: grid of ~/Wallpapers, enter applies (awww + matugen), tab = mono/color.
Overlay {
    id: w
    title: "wallpaper"
    hint: busy ? "asciifying…" : "arrows · enter · a ascii · tab " + (mode === "mono" ? "[mono] color" : "mono [color]") + " · esc"
    boxWidth: Math.min(screen.width - 120, 1180)
    boxHeight: Math.min(screen.height - 160, 700)

    property string mode: "mono"
    readonly property string dir: Quickshell.env("HOME") + "/Wallpapers"

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/mode"
        onLoaded: w.mode = text().trim() || "mono"
    }

    // A: turn the selected picture into an ASCII wallpaper and apply it
    property bool busy: false
    Process {
        id: asciify
        property string src: ""
        command: ["sh", "-c", "out=$(python3 -I \"$HOME/.local/share/ascii-wall/asciify.py\" \"$1\") && exec \"$HOME/.config/quickshell/scripts/setwall.sh\" \"$out\" \"$2\"", "_", src, w.mode]
        onExited: w.busy = false
    }
    function asciifyPath(path) {
        if (busy || path.indexOf("/ascii-") >= 0) return;
        busy = true;
        asciify.src = path;
        asciify.running = true;
    }

    function apply(path) {
        Niri.spawn([Quickshell.env("HOME") + "/.config/quickshell/scripts/setwall.sh", path, w.mode]);
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        focus: true
        cellWidth: Math.floor(width / 5)
        cellHeight: Math.floor(cellWidth * 9 / 16) + 24
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 80
        Component.onCompleted: forceActiveFocus()

        model: FolderListModel {
            folder: "file://" + w.dir
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
            showDirs: false
            sortField: FolderListModel.Name
        }

        Keys.onEscapePressed: w.closeRequested()
        Keys.onTabPressed: w.mode = w.mode === "mono" ? "color" : "mono"
        Keys.onReturnPressed: if (currentItem) w.apply(currentItem.path)
        Keys.onPressed: e => { if (e.key === Qt.Key_A && currentItem) { w.asciifyPath(currentItem.path); e.accepted = true; } }

        delegate: Item {
            id: cell
            required property string filePath
            required property string fileName
            required property int index
            readonly property string path: filePath
            readonly property bool sel: GridView.isCurrentItem
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                color: Theme.surfaceLow
                border.width: 1
                border.color: cell.sel ? Theme.fg : Theme.line

                Image {
                    id: img
                    anchors.fill: parent
                    anchors.margins: 1
                    anchors.bottomMargin: 20
                    source: "file://" + cell.filePath
                    sourceSize.width: 320
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    opacity: status === Image.Ready ? (cell.sel ? 1 : 0.75) : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Txt {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    height: 16
                    text: (cell.sel ? "▸ " : "") + cell.fileName
                    elide: Text.ElideMiddle
                    font.pixelSize: Theme.size - 2
                    color: cell.sel ? Theme.fg : Theme.outline
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { grid.currentIndex = cell.index; w.apply(cell.filePath); }
            }
        }
    }
}
