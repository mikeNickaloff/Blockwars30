import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts

import "../data" as Data
import "." as UI

Item {
    id: catalog

    property alias database: database
    property alias model: powerupModel

    signal powerupChosen(var record)

    Data.PowerupDatabase {
        id: database
    }

    ListModel {
        id: powerupModel
    }

    function refresh() {
        database.ensureSchema()
        var records = database.fetchAllPowerups() || []
        powerupModel.clear()
        for (var i = 0; i < records.length; ++i) {
            var record = records[i]
            powerupModel.append({
                powerupUuid: record.powerupUuid || "",
                powerupName: record.powerupName || "",
                powerupTarget: record.powerupTarget || "Self",
                powerupTargetSpec: record.powerupTargetSpec || "PlayerHealth",
                powerupTargetSpecData: record.powerupTargetSpecData || [],
                powerupCardHealth: record.powerupCardHealth || 0,
                powerupActualAmount: record.powerupActualAmount || 0,
                powerupOperation: record.powerupOperation || "increase",
                powerupIsCustom: !!record.powerupIsCustom,
                powerupCardColor: record.powerupCardColor || "blue"
            })
        }
    }

    Component.onCompleted: refresh()

    GridView {
        id: grid
        anchors.fill: parent
        cellWidth: 200
        cellHeight: 280
        model: powerupModel
        delegate: powerupDelegate
        clip: true
        interactive: true
        ScrollBar.vertical: ScrollBar {}
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
    }

    Component {
        id: powerupDelegate
        UI.PowerupCard {
            width: grid.cellWidth - 24
            height: grid.cellHeight - 24
            anchors.margins: 12
            powerupUuid: model.powerupUuid
            powerupName: model.powerupName
            powerupTarget: model.powerupTarget
            powerupTargetSpec: model.powerupTargetSpec
            powerupTargetSpecData: model.powerupTargetSpecData
            powerupCardHealth: model.powerupCardHealth
            powerupActualAmount: model.powerupActualAmount
            powerupOperation: model.powerupOperation
            powerupIsCustom: model.powerupIsCustom
            powerupCardColor: model.powerupCardColor
            onActivated: {
                powerupChosen({
                    powerupUuid: powerupUuid,
                    powerupName: powerupName,
                    powerupTarget: powerupTarget,
                    powerupTargetSpec: powerupTargetSpec,
                    powerupTargetSpecData: powerupTargetSpecData,
                    powerupCardHealth: powerupCardHealth,
                    powerupActualAmount: powerupActualAmount,
                    powerupOperation: powerupOperation,
                    powerupIsCustom: powerupIsCustom,
                    powerupCardEnergyRequired: powerupCardEnergyRequired,
                    powerupCardColor: powerupCardColor
                })
            }
        }
    }
}
