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
        onSinglePlayerChosen: function(loadout) {
            powerupEditor.visible = false
            mainMenu.visible = false
            if (singlePlayerScene.hasOwnProperty("providedLoadout"))
                singlePlayerScene.providedLoadout = loadout || []
            singlePlayerScene.visible = true
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

    SinglePlayerScene {
        id: singlePlayerScene
        anchors.fill: parent
        visible: false
        onBattleOutcomeDismissed: {
            singlePlayerScene.visible = false
            mainMenu.visible = true
        }
    }

}
