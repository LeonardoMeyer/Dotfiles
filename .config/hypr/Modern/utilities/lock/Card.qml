import QtQuick

// hyprglass can't reach the lock surface, so no glass here
Rectangle {
    radius: Lock.rounding
    color: Lock.card
    border.width: 1
    border.color: Lock.edge
}
