import QtQuick
import Quickshell

// Hosts every utility in one qs process, so the Qt/QML engine is loaded once instead of once per
// utility. Each utility stays in its own folder; boot is left out since startup.lua runs it alone.
ShellRoot {
    id: root

    readonly property var shells: ["home-screen", "launcher", "music", "osd", "settings", "wallpaper-picker"]

    // Created directly rather than through LazyLoader, which drops some shells' IpcHandlers.
    Component.onCompleted: {
        for (let i = 0; i < shells.length; i++) {
            const c = Qt.createComponent(shells[i] + "/shell.qml");
            if (c.status === Component.Error)
                console.warn("utilities:", shells[i], c.errorString());
            else
                c.createObject(root);
        }
    }
}
