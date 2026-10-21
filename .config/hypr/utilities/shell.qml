import QtQuick
import Quickshell
import Quickshell.Io

// Hosts every utility in one qs process, so the Qt/QML engine is loaded once instead of once per
// utility. A utility is any folder here with a shell.qml, so adding one is just adding the folder
// (hypr-profile.sh links the active style's folders in). boot is left out since startup.lua runs it alone.
ShellRoot {
    id: root

    readonly property var standalone: ["boot"]

    Process {
        running: true
        command: ["sh", "-c", "for f in */shell.qml; do [ -f \"$f\" ] && echo \"${f%/shell.qml}\"; done"]
        workingDirectory: Quickshell.shellDir
        stdout: StdioCollector {
            onStreamFinished: root.load(text.split("\n").filter(s => s !== "" && !root.standalone.includes(s)))
        }
    }

    // Created directly rather than through LazyLoader, which drops some shells' IpcHandlers.
    function load(shells) {
        for (let i = 0; i < shells.length; i++) {
            const c = Qt.createComponent(shells[i] + "/shell.qml");
            if (c.status === Component.Error)
                console.warn("utilities:", shells[i], c.errorString());
            else
                c.createObject(root);
        }
    }
}
