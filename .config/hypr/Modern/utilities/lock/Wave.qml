import QtQuick
import Quickshell
import Quickshell.Io

// The quickshell bar's visualizer (bar/Module.qml's Wave): cava's levels as bars along the palette's spectrum.
Row {
    id: wave

    property bool playing: false
    property real u: 1
    property var levels: []
    readonly property int bars: 10

    spacing: 2 * u

    Process {
        running: wave.playing
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(";")
                if (parts.length < wave.bars) return
                const out = new Array(wave.bars)
                for (let i = 0; i < wave.bars; i++)
                    out[i] = Math.max(0, Math.min(1, (parseInt(parts[i]) || 0) / 1000))
                wave.levels = out
            }
        }
        onRunningChanged: if (!running) wave.levels = []
    }

    Repeater {
        model: wave.bars

        Rectangle {
            required property int index
            readonly property real level: wave.playing ? (wave.levels[index] || 0) : 0

            anchors.verticalCenter: parent.verticalCenter
            width: 2.5 * wave.u
            // Even pixel heights, so it never flickers between neighbours.
            height: Math.max(4, Math.round((3 + level * 12) * wave.u / 2) * 2)
            radius: width / 2
            color: Lock.along(Lock.spectrum, index / (wave.bars - 1))
            opacity: wave.playing ? 0.35 + 0.65 * level : 0.45

            Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
}
