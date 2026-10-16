import QtQuick

Item {
    id: control

    property var def

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 6

        Text {
            text: "Cursor theme"
            font.family: Theme.sans
            font.pixelSize: 13
            color: Theme.fg
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: Store.cursors
                Chip {
                    required property string modelData
                    text: modelData
                    active: (Store.values["cursor.theme"] || "").toLowerCase() === modelData.toLowerCase()
                    onClicked: Store.set("cursor.theme", modelData)
                }
            }
        }
    }
}
