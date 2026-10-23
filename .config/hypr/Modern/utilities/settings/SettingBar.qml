import QtQuick

// Which bar runs: waybar or the quickshell bar (utilities/bar); the style list below follows it.
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
