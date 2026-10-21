import QtQuick
import QtQuick.Shapes

// Play/pause glyph that morphs between a triangle and two bars: `m` is 0 for play, 1 for pause.
// The triangle is cut down the middle into two quads, and each quad's corners slide onto one bar's.
// A round stroke in the fill color softens the corners; the shape is inset by half of it.
Shape {
    id: g

    property real m: 0
    property color color: "white"

    preferredRendererType: Shape.CurveRenderer

    readonly property real sw: Math.max(1.5, width * 0.14)
    readonly property real w: width - sw
    readonly property real h: height - sw
    // A triangle's weight sits left of its box, so play is nudged right to look centered.
    readonly property real x0: sw / 2 + (1 - m) * w * 0.07
    readonly property real y0: sw / 2

    function lerp(a, b) { return a + (b - a) * m }
    function px(v) { return x0 + v }
    function py(v) { return y0 + v }

    // Left half of the triangle -> left bar.
    ShapePath {
        fillColor: g.color
        strokeColor: g.color
        strokeWidth: g.sw
        joinStyle: ShapePath.RoundJoin
        startX: g.px(0)
        startY: g.py(0)
        PathLine { x: g.px(g.lerp(g.w * 0.5, g.w * 0.34)); y: g.py(g.lerp(g.h * 0.25, 0)) }
        PathLine { x: g.px(g.lerp(g.w * 0.5, g.w * 0.34)); y: g.py(g.lerp(g.h * 0.75, g.h)) }
        PathLine { x: g.px(0); y: g.py(g.h) }
        PathLine { x: g.px(0); y: g.py(0) }
    }

    // Right half (the point) -> right bar.
    ShapePath {
        fillColor: g.color
        strokeColor: g.color
        strokeWidth: g.sw
        joinStyle: ShapePath.RoundJoin
        startX: g.px(g.lerp(g.w * 0.5, g.w * 0.66))
        startY: g.py(g.lerp(g.h * 0.25, 0))
        PathLine { x: g.px(g.w); y: g.py(g.lerp(g.h * 0.5, 0)) }
        PathLine { x: g.px(g.w); y: g.py(g.lerp(g.h * 0.5, g.h)) }
        PathLine { x: g.px(g.lerp(g.w * 0.5, g.w * 0.66)); y: g.py(g.lerp(g.h * 0.75, g.h)) }
        PathLine { x: g.px(g.lerp(g.w * 0.5, g.w * 0.66)); y: g.py(g.lerp(g.h * 0.25, 0)) }
    }
}
