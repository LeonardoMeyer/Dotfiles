import QtQuick

// Waybar styles shipped by the active style (hypr/<style>/waybar/<name>/), turned like the color wheel.
Item {
    id: control

    property var def

    implicitHeight: 300

    Wheel {
        id: wheel
        anchors.fill: parent
        anchors.margins: 8
        barH: 34
        fixedPitch: 58
        // An even count rests as two above and one below the centered style; shift down half a step so the whole stack is centered.
        centerFrac: 0.5 + (wheel.n % 2 === 0 ? 0.5 * wheel.pitch / wheel.stageH : 0)
        showHint: false
        titleAbove: true
        introDelay: 260
        entries: (Store.waybar.styles || []).map(s => ({ id: s.id, name: s.name, sub: "", image: s.image !== "" ? "file://" + s.image : "" }))
        activeId: Store.waybarActive
        onApplied: id => Store.applyWaybar(id)
    }
}
