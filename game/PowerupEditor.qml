import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts
import "ui" as UI
import "../engine" as Engine

Engine.GameScene {
    id: powerupEditor
    anchors.fill: parent

    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "#1b2838"
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: Math.min(parent.width * 0.6, 420)

        Label {
            text: qsTr("Powerup Editor")
            font.pixelSize: 28
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Build and tweak powerups here. WIP placeholder.")
            wrapMode: Text.WordWrap
            color: "#d0d4dc"
            Layout.fillWidth: true
        }

        UI.MenuButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            height: 48
            buttonText: qsTr("Return to Menu")
            onClicked: powerupEditor.closeRequested()
        }
    }
}
