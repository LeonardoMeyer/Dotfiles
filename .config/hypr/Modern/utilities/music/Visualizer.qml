import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// A small cava spectrum: rounded bars rising from the bottom, colored along the pywal gradient.
// cava only runs while `running` is set, so a closed player costs nothing.
// Opening, the bars pop in center-out and ripple until cava is ready, then hand over to it bar by bar.
Item {
    id: viz

    property bool running: false
    // Opening progress: bars pop in from the center outward as it goes 0 -> 1.
    property real intro: 1
    readonly property int bars: 36
    property var levels: []

    readonly property real gap: Math.max(2, Math.round(width / bars * 0.32))
    readonly property real barW: (width - gap * (bars - 1)) / bars

    // cava takes a moment to deliver its first frame. Until then the bars ripple outward from the center,
    // and once it arrives `live` sweeps the same way, handing each bar over to its real level in turn.
    property bool ready: false
    property real live: 0
    property real phase: 0

    NumberAnimation on phase {
        running: viz.running && viz.live < 1
        from: 0
        to: Math.PI * 2
        duration: 1100
        loops: Animation.Infinite
    }
    NumberAnimation {
        id: liveAnim
        target: viz
        property: "live"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.InOutQuad
    }

    // 0 at the center bar, 1 at either end.
    function dist(i) { return Math.abs(i - (bars - 1) / 2) / ((bars - 1) / 2) }
    // A bar's share of a center-out sweep at progress p.
    function sweep(p, i) { return Math.max(0, Math.min(1, (p - 0.55 * dist(i)) / 0.45)) }
    function backOut(x) { const c = 2.2; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2) }

    Process {
        running: viz.running
        // Next to this file, so it works wherever the visualizer is used (the music player, the home screen).
        command: ["cava", "-p", decodeURIComponent(Qt.resolvedUrl("cava.conf").toString().replace(/^file:\/\//, ""))]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";")
                const out = new Array(viz.bars)
                for (let i = 0; i < viz.bars; i++) out[i] = Math.min(1, (parseInt(parts[i]) || 0) / 1000)
                viz.levels = out
                if (!viz.ready) { viz.ready = true; liveAnim.restart() }
            }
        }
        onRunningChanged: if (!running) { viz.levels = []; viz.ready = false; liveAnim.stop(); viz.live = 0 }
    }

    Repeater {
        model: viz.bars

        Rectangle {
            id: bar
            required property int index
            readonly property real pop: viz.backOut(viz.sweep(viz.intro, index))
            readonly property real handoff: viz.sweep(viz.live, index)
            readonly property real ripple: 0.12 + 0.18 * (0.5 + 0.5 * Math.sin(viz.phase - viz.dist(index) * Math.PI * 2))
            // Ripple until this bar's turn in the handoff, then the real level.
            readonly property real level: ripple * (1 - handoff) + (viz.levels[index] || 0) * handoff
            x: index * (viz.barW + viz.gap)
            anchors.bottom: parent.bottom
            width: viz.barW
            // Silence rests as a row of dots.
            height: Math.max(viz.barW, viz.height * level) * Math.max(0, pop)
            radius: viz.barW / 2
            color: Theme.along(Theme.spectrum, index / (viz.bars - 1))
            opacity: (0.35 + 0.6 * Math.min(1, level * 1.6)) * Math.min(1, viz.sweep(viz.intro, index) * 3)
            Behavior on height { enabled: bar.handoff >= 1; NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
    }
}
