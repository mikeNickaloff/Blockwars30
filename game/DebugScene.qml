import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "ui" as UI
Engine.GameScene {
    id: debugScene
    anchors.fill: parent
    Engine.GameDragItem {
        dragParent: debugScene
        gameScene: debugScene
        itemName: "test_rect"
        width: 120
        height: 120
        entry: myRect
        Rectangle {
            id: myRect
                    color: "red"
                   width:  120
                   height: 120
                }
    }
    Engine.GameDropItem {
        width: 200
        height: 200
        x: 100
        y: 100
    }
    Engine.GameDynamicItem {
        itemName: "test_button"
        gameScene: debugScene
        Button {
            text: "click here"
            width: 200
            height: 200
            x: 300
            y: 300
            onClicked: function(evt) {
                console.log(debugScene.getSceneItem("test_button"), debugScene.getSceneItem("test_rect"))
            }
        }
    }
}
