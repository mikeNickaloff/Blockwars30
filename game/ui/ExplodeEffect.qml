import QtQuick 2.15

Item {
    id: root
    // Public API
    property Item sourceItem            // the thing to explode
    property real radius: 100           // max outward displacement in px
    property int gridX: 24              // columns for shard grid
    property int gridY: 16              // rows for shard grid
    property real duration: 150         // ms for full blast
    property real seed: 1.2345          // randomization seed
    property alias running: boom.running

    // Expand bbox so shards can fly outside the original bounds
    implicitWidth: (sourceItem ? sourceItem.width  : 0) + radius * 2
    implicitHeight: (sourceItem ? sourceItem.height : 0) + radius * 2

    // Center the source inside the expanded effect area
    readonly property real _offsetX: (width  - (sourceItem ? sourceItem.width  : 0)) * 0.5
    readonly property real _offsetY: (height - (sourceItem ? sourceItem.height : 0)) * 0.5

    // 1) Snapshot the source as a texture
    ShaderEffectSource {
        id: snap
        anchors.centerIn: parent
        width:  sourceItem ? sourceItem.width  : 0
        height: sourceItem ? sourceItem.height : 0
        sourceItem: root.sourceItem
        hideSource: true
        live: false            // capture a static frame
        recursive: true        // include children/layers
    }

    // 2) Shatter shader
    ShaderEffect {
        id: fx
        anchors.fill: parent

        // position so the snapshot is centered inside the padded area
        property var  source: snap
        property real u_progress: 0.0
        property real u_radius: root.radius
        property real u_seed: root.seed
        property vector2d u_itemSize: Qt.vector2d(snap.width, snap.height)
        property vector2d u_grid: Qt.vector2d(root.gridX, root.gridY)
        property vector2d u_offset: Qt.vector2d(root._offsetX, root._offsetY)

        // Make the effect draw only where the snapshot exists
        // but allow vertex-displaced shards to fly out
        supportsAtlasTextures: true

        // Grid mesh so each cell behaves like one shard
        mesh: GridMesh { resolution: Qt.size(root.gridX + 1, root.gridY + 1) }

        // Vertex shader (GLSL, Qt Quick compat)
        vertexShader: "../shaders/explode.vert.qsb"
            fragmentShader: "../shaders/explode.frag.qsb"
    }

    // 3) One-liner API to run the explosion
    SequentialAnimation {
        id: boom
        running: false
        PropertyAction { target: snap; property: "live"; value: false } // lock the frame
        NumberAnimation {
            target: fx; property: "u_progress";
            from: 0; to: 1; duration: root.duration; easing.type: Easing.OutCubic
        }
    }

    function arm() {
        // Refresh the snapshot if the source changed visually
        snap.scheduleUpdate();
    }

    function detonate() {
        // Ensure we have a fresh frame, then run
        arm();
        boom.restart();
    }
}
