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
        id: test_rect

        gameScene: debugScene
        itemName: "test_rect"
        width: 120
        height: 120
        entry: myRect
        payload: ["itemName"]
        Rectangle {
            id: myRect
            color: "red"
            width:  120
            height: 120
        }
    }
    Component.onCompleted: {
        addSceneDragItem("test_rect", test_rect)
        addSceneDropItem("drop_item", dropItem);
    }
    Engine.GameDropItem {
        id: dropItem
        itemName: "drop_item"
        gameScene: debugScene
        width: 200
        height: 200
        x: 100
        y: 100
        entry: blueRect


        Rectangle {
            id: blueRect
            color: "blue"
            width: 200
            height: 200
        }
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
