import QtQuick

// Pywal (wallpaper-derived, the default) plus every scheme in ~/.config/wal/colorschemes.
Item {
    id: control

    property var def

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 8

        Text {
            text: "Pywal follows the wallpaper; the others pin a fixed palette."
            font.family: Theme.sans
            font.pixelSize: 12
            color: Theme.dim
        }

        Flow {
            width: parent.width
            spacing: 6

            Chip {
                text: "Pywal"
                image: Store.wallpaper !== "" ? "file://" + Store.wallpaper : ""
                active: Store.colorTheme === "pywal"
                onClicked: Store.applyTheme("pywal")
            }

            Repeater {
                model: Store.themes
                Chip {
                    required property var modelData
                    text: modelData.name
                    swatch: modelData.swatch
                    active: Store.colorTheme === modelData.id
                    onClicked: Store.applyTheme(modelData.id)
                }
            }
        }
    }
}
