import QtQuick 2.15
import "." as Scenes

Scenes.DebugScene {
    id: singlePlayerScene

    readonly property real edgePadding: Math.max(16, Math.round(width * 0.04))
    readonly property real sidebarWidthHint: Math.min(120, Math.max(78, Math.round(width * 0.14)))
    readonly property real sidebarMarginHint: Math.max(16, Math.round(width * 0.03))
    readonly property real desiredVerticalGap: Math.max(12, Math.round(height * 0.04))
    readonly property real maxGridWidth: Math.max(0, Math.floor(width - (edgePadding * 2) - sidebarWidthHint - sidebarMarginHint))
    readonly property real desiredGridWidth: Math.min(Math.round(width * 0.75), maxGridWidth)
    readonly property real maxGridHeight: Math.max(0, Math.floor((height - (edgePadding * 2) - desiredVerticalGap) / 2))
    readonly property real desiredGridHeight: Math.min(Math.round(height * 0.42), maxGridHeight)
    readonly property int gridCellSize: Math.max(10, Math.floor(Math.min((desiredGridWidth - (5 * gridGapX)) / 6,
                                                                        (desiredGridHeight - (5 * gridGapY)) / 6)))
    readonly property real gridVerticalGap: Math.max(12, Math.round((height - (edgePadding * 2) - (2 * gridHeight)) / 3))

    sidebarWidth: sidebarWidthHint
    sidebarMargin: sidebarMarginHint
    gridWidth: Math.round((gridCellSize * 6) + (5 * gridGapX))
    gridHeight: Math.round((gridCellSize * 6) + (5 * gridGapY))
    gridTopX: Math.round((width - (gridWidth + sidebarMargin + sidebarWidth)) / 2)
    gridBottomX: gridTopX
    gridTopY: Math.round(edgePadding + gridVerticalGap)
    gridBottomY: Math.round(gridTopY + gridHeight + gridVerticalGap)
    gridGapX: 1
    gridGapY: 1
    gridCellW: gridCellSize
    gridCellH: gridCellSize
    gridOriginX: Math.max(0, Math.round((gridWidth - ((6 * gridCellW) + (5 * gridGapX))) / 2))
    gridOriginY: Math.max(0, Math.round((gridHeight - ((6 * gridCellH) + (5 * gridGapY))) / 2))
}
