import QtQuick

Item {
    id: control

    property var def
    readonly property var raw: Store.values[def.key]
    readonly property bool ready: raw !== undefined && raw !== null

    implicitHeight: 46
    opacity: ready ? 1 : 0.35

    Text {
        id: label
        text: control.def.label
        font.family: Theme.sans
        font.pixelSize: 13
        color: Theme.fg
    }

    Flow {
        anchors.top: label.bottom
        anchors.topMargin: 5
        width: parent.width
        spacing: 6
        enabled: control.ready

        Repeater {
            model: control.def.options
            Chip {
                required property var modelData
                text: modelData.l
                active: control.raw === modelData.v || (modelData.dflt === true && control.raw === "")
                onClicked: Store.set(control.def.key, modelData.v)
            }
        }
    }
}
