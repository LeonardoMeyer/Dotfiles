import QtQuick
import "../common"

// The list the live settings come from: Default (no overrides, can't be deleted), each variant's own
// tweaks (desktop, laptop, ...) and named saved profiles. Style folders are presets and never change.
// Edits change the applied entry; on Default they go to the active variant's tweaks, which becomes applied.
// Deleting asks for a second click.
Item {
    id: control

    property var def
    readonly property var entries: Store.saved.entries || []
    readonly property string draft: input.text.trim()
    readonly property bool exists: entries.some(e => e.kind === "saved" && e.name.toLowerCase() === draft.toLowerCase())
    property string armed: ""

    implicitHeight: col.height

    Timer { id: disarm; interval: 2500; onTriggered: control.armed = "" }

    function arm(id) {
        if (armed === id) return true
        armed = id
        disarm.restart()
        return false
    }

    function submit() {
        if (!draft) return
        Store.savedRun("save", draft)
        input.text = ""
        release()
    }

    // Hands the keyboard back to the panel so h/j/k/l and Escape work again.
    function release() {
        let p = input.parent
        while (p && p.objectName !== "keyRoot") p = p.parent
        if (p) p.forceActiveFocus()
    }

    Column {
        id: col
        width: parent.width

        Repeater {
            model: control.entries

            Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool current: modelData.id === Store.saved.active
                // A variant without a tweaks file has nothing to apply yet; edits will create it.
                readonly property bool usable: modelData.exists
                readonly property bool deletable: modelData.kind !== "default" && modelData.exists
                readonly property bool hot: rowArea.containsMouse || binArea.containsMouse

                width: col.width
                height: 46
                opacity: usable || current ? 1 : 0.5

                Rectangle {
                    visible: entry.index > 0
                    x: Theme.pad
                    width: parent.width - Theme.pad * 2
                    height: 1
                    color: Theme.alpha(Theme.fg, 0.07)
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entry.usable && !entry.current
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Store.savedRun("apply", entry.modelData.id)
                }

                Rectangle {
                    id: dot
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: entry.current ? Theme.accent : Theme.alpha(Theme.fg, 0.2)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                Text {
                    id: label
                    anchors.left: dot.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, tag.x - x - kind.implicitWidth - 18)
                    text: entry.modelData.name
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: 13
                    color: entry.current || entry.hot ? Theme.bright : Theme.fg
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                Text {
                    id: kind
                    anchors.left: label.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.kind === "default" ? "no overrides"
                        : entry.modelData.kind === "variant" ? (entry.modelData.exists ? "variant tweaks" : "no tweaks yet")
                        : ""
                    font.family: Theme.sans
                    font.pixelSize: 10
                    color: Theme.dim
                }

                Text {
                    id: tag
                    anchors.right: bin.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.current ? "Applied" : rowArea.containsMouse ? "Apply" : ""
                    font.family: Theme.sans
                    font.pixelSize: 11
                    color: entry.current ? Theme.accent : Theme.dim
                }

                Rectangle {
                    id: bin
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad - 4
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool primed: control.armed === "del:" + entry.modelData.id
                    visible: entry.deletable
                    width: primed ? binText.implicitWidth + 18 : 28
                    height: 28
                    radius: Theme.r(8)
                    color: primed ? Theme.alpha("#e5566d", 0.45) : Theme.alpha(Theme.fg, binArea.containsMouse ? 0.14 : 0)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

                    Text {
                        id: binText
                        anchors.centerIn: parent
                        text: bin.primed ? "Delete?" : ""
                        font.family: Theme.sans
                        font.pixelSize: bin.primed ? 11 : 13
                        color: bin.primed || binArea.containsMouse ? Theme.bright : Theme.dim
                    }

                    MouseArea {
                        id: binArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (control.arm("del:" + entry.modelData.id)) {
                            control.armed = ""
                            Store.savedRun("delete", entry.modelData.id)
                        }
                    }
                }

                // Keeps the row height for entries without a delete button (Default).
                Item { visible: !entry.deletable; anchors.right: parent.right; width: Theme.pad + 24; height: 1 }
            }
        }

        Rectangle {
            x: Theme.pad
            width: parent.width - Theme.pad * 2
            height: 1
            color: Theme.alpha(Theme.fg, 0.07)
        }

        // Name field + save. Saving under an existing name overwrites it.
        Item {
            width: parent.width
            height: 52

            Rectangle {
                id: field
                anchors.left: parent.left
                anchors.leftMargin: Theme.pad - 4
                anchors.right: saveBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                radius: Theme.r(8)
                color: Theme.alpha(Theme.fg, input.activeFocus ? 0.12 : 0.07)
                border.width: input.activeFocus ? 1 : 0
                border.color: Theme.alpha(Theme.accent, 0.6)
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    maximumLength: 40
                    validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9 _-]*/ }
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: Theme.bright
                    selectionColor: Theme.alpha(Theme.accent, 0.5)
                    selectedTextColor: Theme.bright
                    onAccepted: control.submit()
                    Keys.onEscapePressed: { text = ""; control.release() }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text && !input.activeFocus
                        text: "New profile name"
                        font: input.font
                        color: Theme.dim
                    }
                }
            }

            Rectangle {
                id: saveBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.pad
                anchors.verticalCenter: parent.verticalCenter
                width: saveText.implicitWidth + 22
                height: 32
                radius: Theme.r(8)
                opacity: control.draft ? 1 : 0.4
                color: Theme.alpha(Theme.accent, saveArea.containsMouse && control.draft ? 0.45 : 0.3)
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                Text {
                    id: saveText
                    anchors.centerIn: parent
                    text: control.exists ? "Overwrite" : "Save"
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: Theme.bright
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !!control.draft
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.submit()
                }
            }
        }

        Text {
            x: Theme.pad
            width: parent.width - Theme.pad * 2
            height: implicitHeight + 10
            wrapMode: Text.WordWrap
            text: "Default runs " + (Store.active.style || "the style") + " / " + (Store.active.variant || "variant")
                + " with no overrides; changing anything there switches to " + control.variantName()
                + ". Changes update whichever entry is applied. Save under a new name to branch off a copy."
            font.family: Theme.sans
            font.pixelSize: 11
            color: Theme.dim
        }

        // Back to presets: every saved profile and every variant's tweaks go; style folders are untouched.
        Item {
            width: parent.width
            height: 52
            readonly property bool primed: control.armed === "wipe"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 9
                radius: Theme.r(8)
                color: parent.primed ? Theme.alpha("#e5566d", 0.45) : Theme.alpha(Theme.fg, wipeArea.containsMouse ? 0.14 : 0.07)
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                Text {
                    anchors.centerIn: parent
                    text: parent.parent.primed ? "Click again to delete everything" : "Delete all saved profiles and tweaks"
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: parent.parent.primed || wipeArea.containsMouse ? Theme.bright : Theme.fg
                }

                MouseArea {
                    id: wipeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (control.arm("wipe")) {
                        control.armed = ""
                        Store.savedRun("wipe")
                    }
                }
            }
        }
    }

    function variantName() {
        const v = Store.active.variant || "the variant"
        return v.charAt(0).toUpperCase() + v.slice(1)
    }
}
