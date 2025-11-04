import QtQuick 2.15
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "./ui" as UI
import "." as Scenes
Engine.GameScene {
    id: mainMenuSceneRoot
    signal singlePlayerChosen()
    signal multiPlayerChosen()
    signal powerupEditorChosen()
    signal optionsChosen()
    signal debugChosen()
    signal exitChosen()
    anchors.fill: parent

    property UI.MatchSetup matchSetup
    property Scenes.DebugScene debugScene
    property var pendingDebugLoadout: []

    function openMatchSetup() {
        if (matchSetupLoader.active || debugSceneLoader.active)
            return
        matchSetupLoader.active = true
    }

    function closeMatchSetup(preserveSelection) {
        if (!matchSetupLoader.active)
            return
        matchSetupLoader.active = false
        if (!preserveSelection)
            pendingDebugLoadout = []
    }


    function beginDebugScene(loadout) {
        pendingDebugLoadout = loadout || []
        closeMatchSetup(true)

        debugScene = debugSceneComponent.createObject(mainMenuSceneRoot, { providedLoadout: loadout,  z: 5 })
        debugScene.anchors.fill = mainMenuSceneRoot
       // debugSceneLoader.active = true
    }

    Engine.GameLayout {
        id: menuLayout
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
                mainMenuSceneRoot.openMatchSetup()
            }
        }
        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Exit"
            onClicked: { mainMenuSceneRoot.exitChosen() }
        }
    }
    Loader {
        id: matchSetupLoader
        anchors.fill: parent
        z: 10
        active: false
        sourceComponent: matchSetupComponent
        onLoaded: {
            if (!item)
                return
            item.closeRequested.connect(mainMenuSceneRoot.closeMatchSetup)
            item.proceedRequested.connect(mainMenuSceneRoot.beginDebugScene)
        }
    }

    Loader {
        id: debugSceneLoader
        anchors.fill: parent
        z: 5
        active: false
        sourceComponent: debugSceneComponent
        onLoaded: {
            if (!item)
                return
            if (item.hasOwnProperty("providedLoadout"))
                item.providedLoadout = mainMenuSceneRoot.pendingDebugLoadout || []
        }
        onStatusChanged: {
            if (status === Loader.Ready) {
                mainMenuSceneRoot.debugChosen()
                mainMenuSceneRoot.pendingDebugLoadout = []
            }
        }
    }

    Component {
        id: matchSetupComponent
        UI.MatchSetup {
            anchors.fill: parent
        }
    }

    Component {
        id: debugSceneComponent
        Scenes.DebugScene {
            anchors.fill: parent
        }
    }
    Component.onCompleted: {

    }

}
