import QtQuick 2.15
import "."
Item {
    id: abstractItemRoot
    anchors.fill: deriveParent()
    property var gameScene
    property var sceneX: 0
    property var sceneY: 0
    property var itemParent
    property var itemWidth
    property var itemHeight
    property var itemInstance
    property var itemName
    property alias itemComponent: abstractGameItemLoader.sourceComponent

    function deriveParent() {

        if (isUndefined(itemParent)) {
            if (isUndefined(gameScene)) {
                return parent
            } else {
                return gameScene
            }
        } else {
            return itemParent
        }
        return parent
    }

    function isUndefined(object) {
        if (typeof object == "undefined") { return true; } else { return false; }
    }

    function loadComponent(componentObject) {
        abstractGameItemLoader.sourceComponent = componentObject

    }
    Component.onCompleted: {
        if (!isUndefined(gameScene)) {
            gameScene.addSceneItem(itemName, abstractItemRoot)
        }
    }
    Loader {
        id: abstractGameItemLoader
        anchors.fill: parent
    }
}
