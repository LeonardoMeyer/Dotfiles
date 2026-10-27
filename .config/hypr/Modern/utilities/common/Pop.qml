import QtQuick

// quick bounce when a saved workspace gets renamed and slides to its new spot
SequentialAnimation {
    id: pop
    property Item target
    property string label
    // label goes "" -> name while the row gets built, so only bounce on a real rename. otherwise everything jiggles on open
    property string last
    onLabelChanged: { if (last !== "" && label !== "") restart(); last = label }
    NumberAnimation { target: pop.target; property: "scale"; to: 1.06; duration: Theme.fast; easing.type: Easing.OutCubic }
    NumberAnimation { target: pop.target; property: "scale"; to: 1; duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
}
