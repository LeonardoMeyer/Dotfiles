import QtQuick
import "../common"

// hyprglass can't reach the lock surface, so no glass here
Rectangle {
    property real u: 1
    radius: Theme.rounding * u
    color: Lock.card
    border.width: 1
    border.color: Lock.edge
}
