import QtQuick 2.15


    DropArea {
        onDropped: {
            console.log("Dropped!");
        }
        Rectangle {
            color: "blue"
            anchors.fill: parent
        }
    }

