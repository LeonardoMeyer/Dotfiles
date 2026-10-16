import QtQuick

// Collapsed row that expands in place into a list; used when there are five or more options.
// options: [{ v, l, swatch?: [colors], image?: url }]
Item {
    id: dd

    property string label
    property var options: []
    property var current
    property bool open: false
    signal picked(var value)

    readonly property int rowH: 34
    readonly property int headH: 46
    readonly property var selected: {
        for (let i = 0; i < options.length; i++)
            if (options[i].v === current) return options[i]
        return null
    }

    implicitHeight: headH + list.height

    Item {
        id: head
        width: parent.width
        height: dd.headH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            text: dd.label
            font.family: Theme.sans
            font.pixelSize: 13
            color: headArea.containsMouse ? Theme.bright : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        Rectangle {
            id: pill
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            height: 28
            width: pillRow.implicitWidth + 22
            radius: 8
            color: dd.open ? Theme.alpha(Theme.accent, 0.3) : Theme.alpha(Theme.fg, headArea.containsMouse ? 0.14 : 0.08)
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 8

                Row {
                    visible: !!dd.selected && !!dd.selected.swatch
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: dd.selected && dd.selected.swatch ? dd.selected.swatch.slice(0, 5) : []
                        Rectangle { required property string modelData; width: 7; height: 12; radius: 2; color: modelData }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dd.selected ? dd.selected.l : "—"
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: Theme.bright
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf078"
                    font.family: Theme.sans
                    font.pixelSize: 9
                    color: Theme.fg
                    rotation: dd.open ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: headArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dd.open = !dd.open
        }
    }

    Item {
        id: list
        y: dd.headH
        width: parent.width
        height: dd.open ? col.height + 8 : 0
        clip: true
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            id: col
            width: parent.width - Theme.pad * 2
            x: Theme.pad
            spacing: 2

            Repeater {
                model: dd.options

                Rectangle {
                    required property var modelData
                    readonly property bool on: modelData.v === dd.current
                    width: col.width
                    height: dd.rowH
                    radius: 8
                    color: on ? Theme.alpha(Theme.accent, 0.28) : Theme.alpha(Theme.fg, rowArea.containsMouse ? 0.1 : 0)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Row {
                            visible: !!modelData.swatch
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: modelData.swatch || []
                                Rectangle { required property string modelData; width: 9; height: 14; radius: 3; color: modelData }
                            }
                        }

                        Rectangle {
                            visible: !!modelData.image
                            width: 24
                            height: 24
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.fg, 0.12)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.image || ""
                                sourceSize.width: 48
                                sourceSize.height: 48
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.l
                            font.family: Theme.sans
                            font.pixelSize: 13
                            color: on || rowArea.containsMouse ? Theme.bright : Theme.fg
                        }
                    }

                    Text {
                        visible: on
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf00c"
                        font.family: Theme.sans
                        font.pixelSize: 11
                        color: Theme.accent
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { dd.picked(modelData.v); dd.open = false }
                    }
                }
            }
        }
    }
}
