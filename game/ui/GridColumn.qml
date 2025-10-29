import QtQuick 2.15
import "../../engine" as Engine
import "." as UI
import QtQml.Models
import QtQuick.Layouts
ListView {
    id: columnRoot
    property var cellModel: []
    property var rowCount: 6
    property var root
    property int columnIndex: 0
    property var gameScene
    width: parent.width / 6
    height: parent.height
    interactive: false
    model: ListModel {
        ListElement {
            row: 0

        }
        ListElement {
            row: 1

        }
        ListElement {
            row: 2

        }
        ListElement {
            row: 3

        }
        ListElement {
            row: 4

        }
        ListElement {
            row: 5

        }
    }
    delegate:        Engine.GameDragItem {
        id: iRoot
        gameScene: columnRoot.gameScene
        itemName: "block_" + index + "_" + Math.random() * 2000
        entry: gCell
        required property int index

        required property var model
        UI.Block {
        id: gCell
        blockColor: "yellow"
        width: 60
        height: 60
        gameScene: columnRoot.gameScene
        Component.onCompleted: {
            console.log("Added drop Cell",iRoot.index, columnIndex, iRoot.model);
            columnRoot.gameScene.addSceneDragItem("cell_" + iRoot.model.row + "_" + columnIndex, iRoot);
        }
        }
    }
    reuseItems: true
        spacing: 0
    snapMode: ListView.NoSnap
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    displaced: Transition {
        NumberAnimation {
            properties: "x,y"

            duration: 700
        }
    }
    move: Transition {
        NumberAnimation {
            properties: "x,y"

            duration: 100
        }
    }
    populate: Transition {
        NumberAnimation {
            properties: "y"

            duration: 1700
        }
    }


}


