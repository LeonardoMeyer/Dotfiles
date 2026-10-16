import QtQuick

// Style (the look: quickshells, animation, layer rules) and variant (laptop, desktop, ...).
// Both come from folders under ~/.config/hypr, so adding a style needs no code.
Item {
    id: control

    property var def
    readonly property var styleNames: Object.keys(Store.styles).sort()
    readonly property var variants: Store.styles[Store.active.style] || []

    function title(name) {
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    function pickStyle(style) {
        const list = Store.styles[style] || []
        Store.applyProfile(style, list.indexOf(Store.active.variant) >= 0 ? Store.active.variant : list[0])
    }

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 10

        Row {
            spacing: 12
            Text {
                width: 64
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: "Style"
                font.family: Theme.sans
                font.pixelSize: 13
                color: Theme.fg
            }
            Flow {
                width: column.width - 76
                spacing: 6
                Repeater {
                    model: control.styleNames
                    Chip {
                        required property string modelData
                        text: control.title(modelData)
                        active: Store.active.style === modelData
                        onClicked: if (!active) control.pickStyle(modelData)
                    }
                }
            }
        }

        Row {
            spacing: 12
            Text {
                width: 64
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: "Variant"
                font.family: Theme.sans
                font.pixelSize: 13
                color: Theme.fg
            }
            Flow {
                width: column.width - 76
                spacing: 6
                Repeater {
                    model: control.variants
                    Chip {
                        required property string modelData
                        text: control.title(modelData)
                        active: Store.active.variant === modelData
                        onClicked: if (!active) Store.applyProfile(Store.active.style, modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "A style carries its own quickshells, animations and layout. Switching loads the profile's defaults and clears your tweaks."
            font.family: Theme.sans
            font.pixelSize: 12
            color: Theme.dim
        }
    }
}
