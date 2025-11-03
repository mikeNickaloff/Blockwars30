import QtQuick
import "engine"
import "game"
import "lib"

Window {
    width: 840
    height: 880
    visible: true
    title: qsTr("Hello World")

    MainMenuScene {
        id: mainMenu
        anchors.fill: parent
        onPowerupEditorChosen: {
            mainMenu.visible = false
            powerupEditor.visible = true
        }
        onDebugChosen: {
            debugScene.visible = true
        }
    }

    PowerupEditor {
        id: powerupEditor
        anchors.fill: parent
        visible: false
        onCloseRequested: {
            powerupEditor.visible = false
            mainMenu.visible = true
        }
    }

    DebugScene {
        anchors.fill: parent
        id: debugScene
        visible: false
    }
}
