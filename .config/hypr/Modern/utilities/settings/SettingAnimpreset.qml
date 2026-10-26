import QtQuick
import "Schema.js" as Schema

Dropdown {
    id: control

    property var def
    readonly property var curve: Store.values["animation.curve"] || [0.15, 0.85, 0.25, 1]

    label: "Preset"
    current: Store.values["animation.preset"] || "theme"
    options: [
        { v: "theme", l: "Profile" }, { v: "calm", l: "Calm" }, { v: "balanced", l: "Balanced" },
        { v: "snappy", l: "Snappy" }, { v: "bouncy", l: "Bouncy" }, { v: "custom", l: "Custom" }
    ]

    onPicked: v => {
        if (v === "theme") {
            Store.setValues({ "animation.preset": "theme" })
            Store.setMany({ "animation": null })
        } else if (v === "custom") {
            Store.setMany({ "animation.preset": "custom", "animation.curve": control.curve })
        } else {
            const p = Schema.PRESETS[v]
            Store.setMany({
                "animation.preset": v, "animation.curve": p.curve, "animation.speed": p.speed,
                "animation.window": p.window, "animation.workspace": p.workspace
            })
        }
    }

    // right-click resets to the profile value
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.reset("animation")
    }
}
