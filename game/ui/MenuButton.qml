import QtQuick 2.15
import QtQuick.Controls.Universal
import QtQuick.Layouts
 Button {
      id: buttonRoot
     property var parentItem
     property alias buttonText: buttonRoot.text

     Layout.fillWidth: true
     Layout.fillHeight: true


}
