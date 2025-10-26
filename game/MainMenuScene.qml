import QtQuick 2.15
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "ui" as UI
Engine.GameScene {
    id: mainMenuSceneRoot
    signal singlePlayerChosen()
    signal multiPlayerChosen()
    signal powerupEditorChosen()
    signal optionsChosen()
    signal debugChosen()
    signal exitChosen()
    anchors.fill: parent
    Engine.GameLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 1
        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Single Player"
            onClicked: { mainMenuSceneRoot.singlePlayerChosen() }
        }

        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "MultiPlayer"
            onClicked: { mainMenuSceneRoot.multiPlayerChosen() }
        }

        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Powerup Editor"
            onClicked: { mainMenuSceneRoot.powerupEditorChosen() }
        }

        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Options"
            onClicked: { mainMenuSceneRoot.optionsChosen() }
        }
        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Debug"
            onClicked: {
                onClicked: { mainMenuSceneRoot.debugChosen() }
            }
        }
        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Exit"
            onClicked: { mainMenuSceneRoot.exitChosen() }
        }
    }
    Component.onCompleted: {

    }

}
