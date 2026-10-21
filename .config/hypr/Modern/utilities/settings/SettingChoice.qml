import QtQuick
import "../common"

Picker {
    id: control

    property var def
    readonly property var raw: Store.values[def.key]

    label: def.label
    // Options can name palette slots (stops) to be shown as swatches from the live colors.
    options: def.options.map(o => o.stops
        ? Object.assign({}, o, { swatch: o.stops.map(i => Theme.wal ? Theme.wal.colors["color" + i] : "#888888") })
        : o)
    ready: raw !== undefined && raw !== null
    // Hyprland reports an unset option as "", which means the option flagged as the default.
    current: {
        if (raw === "") {
            const d = def.options.find(o => o.dflt === true)
            return d ? d.v : raw
        }
        return raw
    }
    onPicked: v => Store.set(def.key, v)

    // Right-click puts the setting back to the profile's own value.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.reset(def.key)
    }
}
