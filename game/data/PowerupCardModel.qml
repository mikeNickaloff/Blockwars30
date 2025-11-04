import QtQuick 2.15
import "." as Data

Data.PowerupItem {
    id: powerupCard

    // Runtime energy + hero state for battle usage
    property int currentEnergy: 0
    property bool activationReady: false
    property real energyProgress: powerupCardEnergyRequired > 0
                                      ? Math.min(1, currentEnergy / powerupCardEnergyRequired)
                                      : 0
    property bool heroPlaced: false
    property Item heroInstance: null
    property bool dragLocked: false

    signal energyChanged(int currentEnergy)

    function ensureEnergyWithinBounds() {
        var required = Math.max(0, powerupCardEnergyRequired)
        var clamped = currentEnergy
        if (required === 0)
            clamped = 0
        if (clamped < 0)
            clamped = 0
        if (required > 0 && clamped > required)
            clamped = required
        if (clamped !== currentEnergy) {
            currentEnergy = clamped
            return
        }
        energyChanged(currentEnergy)
        updateActivationState()
    }

    function updateActivationState() {
        var required = Math.max(0, powerupCardEnergyRequired)
        var ready = required === 0 ? true : currentEnergy >= required
        activationReady = ready
    }

    function gainEnergy(amount) {
        if (!amount || amount <= 0)
            return
        currentEnergy = currentEnergy + Math.floor(amount)
        ensureEnergyWithinBounds()
    }

    function resetRuntimeState() {
        currentEnergy = 0
        heroPlaced = false
        dragLocked = false
        heroInstance = null
        ensureEnergyWithinBounds()
    }

    function applyRecord(record) {
        if (!record)
            return
        powerupUuid = record.powerupUuid || ""
        powerupName = record.powerupName || ""
        powerupTarget = record.powerupTarget || targets.Self
        powerupTargetSpec = record.powerupTargetSpec || targetSpecs.PlayerHealth
        var specData = record.powerupTargetSpecData
        if (typeof specData === "string") {
            try {
                specData = JSON.parse(specData)
            } catch (err) {
                specData = specData
            }
        }
        powerupTargetSpecData = specData !== undefined ? specData : []
        powerupCardHealth = record.powerupCardHealth || 0
        powerupActualAmount = record.powerupActualAmount || 0
        powerupOperation = record.powerupOperation || operations.Increase
        powerupIsCustom = !!record.powerupIsCustom
        powerupCardColor = record.powerupCardColor || "blue"
        powerupHeroRowSpan = record.powerupHeroRowSpan || 1
        powerupHeroColSpan = record.powerupHeroColSpan || 1
        dragLocked = record.dragLocked || false
        updateEnergyRequirement()
        ensureEnergyWithinBounds()
    }

    function cloneRecord() {
        return {
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
            powerupCardColor: powerupCardColor,
            powerupHeroRowSpan: powerupHeroRowSpan,
            powerupHeroColSpan: powerupHeroColSpan,
            dragLocked: dragLocked
        }
    }

    onPowerupCardEnergyRequiredChanged: ensureEnergyWithinBounds()
    onCurrentEnergyChanged: ensureEnergyWithinBounds()
    onPowerupHeroRowSpanChanged: ensureHeroSpanDefaults()
    onPowerupHeroColSpanChanged: ensureHeroSpanDefaults()
}
