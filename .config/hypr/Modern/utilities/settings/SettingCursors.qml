import QtQuick

Dropdown {
    id: control

    property var def

    label: "Cursor theme"
    options: Store.cursors.map(c => ({ v: c.toLowerCase(), l: c }))
    current: String(Store.values["cursor.theme"] || "").toLowerCase()
    onPicked: v => Store.set("cursor.theme", Store.cursors.find(c => c.toLowerCase() === v))

    // Right-click puts the setting back to the profile's own value.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.reset("cursor.theme")
    }
}
