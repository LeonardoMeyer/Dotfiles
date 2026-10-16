import QtQuick

// Color themes as a wheel: Pywal (from the wallpaper) plus every scheme in ~/.config/wal/colorschemes.
Wheel {
    id: wheel

    // Background plus the six hues and the accent: the same slots every scheme is built from.
    readonly property var slots: [0, 1, 2, 3, 4, 5, 6, 9]

    centerFrac: 0.4

    entries: {
        const pw = Store.pywalPalette
        const list = [{ id: "pywal", name: "Pywal", sub: "from your wallpaper", colors: slots.map(i => pw[i]).filter(c => !!c) }]
        for (const t of Store.themes) list.push({ id: t.id, name: t.name, sub: "", colors: t.swatch })
        return list
    }
    activeId: Store.colorTheme
    onApplied: id => Store.applyTheme(id)
}
