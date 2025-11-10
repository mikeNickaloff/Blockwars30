import QtQuick 2.15
import QtQuick.Controls 2.15
import "../engine" as Engine

Engine.GameScene {
    id: outcomeScene
    anchors.fill: parent

    property string titleText: ""
    property string subtitleText: ""
    property color accentColor: "#64ffda"
    property string buttonText: qsTr("Return to Menu")

    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "#AA050A1A"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.AllButtons
        onClicked: { /* swallow */ }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.6, 420)
        height: Math.min(parent.height * 0.5, 320)
        radius: 18
        color: "#101b2c"
        border.width: 2
        border.color: accentColor
        opacity: 0.96

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18
            Text {
                text: titleText
                font.pixelSize: 36
                font.bold: true
                color: accentColor
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
            Text {
                text: subtitleText
                font.pixelSize: 18
                color: "#f5f5f5"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
            Item {
                width: 1
                height: 12
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: buttonText
                onClicked: closeRequested()
            }
        }
    }
}
