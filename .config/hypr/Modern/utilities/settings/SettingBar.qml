import QtQuick

Dropdown {
    id: control

    property var def

    label: "Bar"
    options: [
        { v: "waybar", l: "Waybar" },
        { v: "quickshell", l: "Quickshell bar" }
    ]
    current: Store.bar
    onPicked: v => { if (v !== Store.bar) Store.applyBar(v) }
}
