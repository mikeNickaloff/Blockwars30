import QtQuick
import "engine"
import "game"
import "lib"
Window {
    width: 640
    height: 480
    visible: true
    title: qsTr("Hello World")
   MainMenuScene {
       anchors.fill: parent
       onDebugChosen: { debugScene.visible = true }
   }

   DebugScene {
       anchors.fill: parent
       id: debugScene
       visible: false
   }

}
