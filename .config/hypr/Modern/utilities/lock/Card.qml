import QtQuick

// A card like the home screen's: the background at half strength with a faint edge. hyprglass can't reach a
// lock surface, so the lock keeps this look whether glass is on or not.
Rectangle {
    radius: Lock.rounding
    color: Lock.card
    border.width: 1
    border.color: Lock.edge
}
