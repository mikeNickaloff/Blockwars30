import QtQuick 2.15
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "./ui" as UI
import "." as Scenes
Engine.GameScene {
    id: mainMenuSceneRoot
    signal singlePlayerChosen(var loadout)
    signal multiPlayerChosen()
    signal powerupEditorChosen()
    signal optionsChosen()
    signal debugChosen()
    signal exitChosen()
    anchors.fill: parent

    property UI.MatchSetup matchSetup
    property Scenes.DebugScene debugScene
    property var pendingDebugLoadout: []
    property string pendingMatchMode: ""

    function openMatchSetup(mode) {
        if (matchSetupLoader.active || debugSceneLoader.active)
            return
        pendingMatchMode = mode || "debug"
        matchSetupLoader.active = true
    }

    function closeMatchSetup(preserveSelection) {
        if (!matchSetupLoader.active)
            return
        matchSetupLoader.active = false
        if (!preserveSelection) {
            pendingDebugLoadout = []
            pendingMatchMode = ""
        }
    }


    function beginDebugScene(loadout) {
        pendingDebugLoadout = loadout || []
        closeMatchSetup(true)

        if (debugScene) {
            debugScene.destroy()
            debugScene = null
        }

        debugScene = debugSceneComponent.createObject(mainMenuSceneRoot, { providedLoadout: loadout,  z: 5 })
        debugScene.anchors.fill = mainMenuSceneRoot
        if (debugScene && debugScene.battleOutcomeDismissed) {
            const createdScene = debugScene
            createdScene.battleOutcomeDismissed.connect(function(result) {
                if (mainMenuSceneRoot.debugScene === createdScene)
                    mainMenuSceneRoot.debugScene = null
                createdScene.destroy()
            })
        }
       // debugSceneLoader.active = true
    }

    function beginSinglePlayerScene(loadout) {
        closeMatchSetup(true)
        singlePlayerChosen(loadout || [])
    }

    function handleMatchSetupProceed(loadout) {
        if (pendingMatchMode === "single")
            beginSinglePlayerScene(loadout)
        else
            beginDebugScene(loadout)
    }

    Engine.GameLayout {
        id: menuLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 1
        UI.MenuButton {
            parentItem: mainMenuSceneRoot
            buttonText: "Single Player"
            onClicked: { mainMenuSceneRoot.openMatchSetup("single") }
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
                mainMenuSceneRoot.openMatchSetup("debug")
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
            item.proceedRequested.connect(mainMenuSceneRoot.handleMatchSetupProceed)
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
