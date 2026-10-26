import QtQuick

Wheel {
    id: wheel

    readonly property var slots: [0, 1, 2, 3, 4, 5, 6, 9]

    centerFrac: 0.5

    entries: {
        const pw = Store.pywalPalette
        const list = [{ id: "pywal", name: "Pywal", sub: "from your wallpaper", colors: slots.map(i => pw[i]).filter(c => !!c) }]
        for (const t of Store.themes) list.push({ id: t.id, name: t.name, sub: "", colors: t.swatch })
        return list
    }
    activeId: Store.colorTheme
    onApplied: id => Store.applyTheme(id)
}
