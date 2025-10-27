import QtQuick 2.15
import QtQuick.Layouts
import QtQuick.Controls

import "../../engine" as Engine
import "../../lib" as Lib

Engine.GameDragItem {
    required property var gameScene
    required property var itemName
    Layout.fillWidth: true
    Layout.fillHeight: true
}
