import QtQuick

// Waybar styles shipped by the active style (hypr/<style>/waybar/<name>/), turned like the color wheel.
Item {
    id: control

    property var def

    implicitHeight: 300

    Wheel {
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 6
        anchors.bottomMargin: 24
        barH: 34
        fixedPitch: 58
        centerFrac: 0.5
        showHint: false
        introDelay: 260
        entries: (Store.waybar.styles || []).map(s => ({ id: s.id, name: s.name, sub: "", image: s.image !== "" ? "file://" + s.image : "" }))
        activeId: Store.waybarActive
        onApplied: id => Store.applyWaybar(id)
    }
}
