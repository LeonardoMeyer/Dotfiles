import QtQuick

// Rounded horizontal gradient through a list of colors; the whole look of a theme at a glance.
Canvas {
    id: bar

    property var colors: []
    property real radius: 12

    onColorsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (colors.length === 0 || width <= 0) return
        const g = ctx.createLinearGradient(0, 0, width, 0)
        const n = colors.length
        for (let i = 0; i < n; i++) g.addColorStop(n === 1 ? 0 : i / (n - 1), colors[i])
        const r = Math.min(radius, height / 2)
        ctx.beginPath()
        ctx.moveTo(r, 0)
        ctx.lineTo(width - r, 0)
        ctx.arcTo(width, 0, width, r, r)
        ctx.lineTo(width, height - r)
        ctx.arcTo(width, height, width - r, height, r)
        ctx.lineTo(r, height)
        ctx.arcTo(0, height, 0, height - r, r)
        ctx.lineTo(0, r)
        ctx.arcTo(0, 0, r, 0, r)
        ctx.closePath()
        ctx.fillStyle = g
        ctx.fill()
    }
}
