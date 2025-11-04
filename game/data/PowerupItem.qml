import QtQuick 2.15

QtObject {
    id: powerupItem

    readonly property var targets: ({
        Enemy: "Enemy",
        Self: "Self"
    })

    readonly property var targetSpecs: ({
        Blocks: "Blocks",
        PlayerHealth: "PlayerHealth",
        PlayerPowerupInGameCards: "PlayerPowerupInGameCards"
    })

    readonly property var operations: ({
        Increase: "increase",
        Decrease: "decrease"
    })

    property string powerupUuid: ""
    property string powerupName: ""
    property string powerupTarget: targets.Self
    property string powerupTargetSpec: targetSpecs.PlayerHealth
    property var powerupTargetSpecData: []
    property int powerupCardHealth: 0
    property int powerupActualAmount: 0
    property string powerupOperation: operations.Increase
    property bool powerupIsCustom: false
    property string powerupCardColor: "blue"
    property int powerupHeroRowSpan: 1
    property int powerupHeroColSpan: 1

    property int powerupCardEnergyRequired: 0

    signal energyRecalculated(int energyRequired)

    function setTarget(target) {
        if (target === targets.Enemy || target === targets.Self)
            powerupTarget = target
    }

    function setTargetSpec(spec, specData) {
        if (spec === targetSpecs.Blocks || spec === targetSpecs.PlayerHealth || spec === targetSpecs.PlayerPowerupInGameCards) {
            powerupTargetSpec = spec
            if (specData !== undefined)
                powerupTargetSpecData = specData
            ensureSpecDataDefaults()
        }
    }

    function ensureSpecDataDefaults() {
        if (powerupTargetSpec === targetSpecs.Blocks) {
            if (!Array.isArray(powerupTargetSpecData))
                powerupTargetSpecData = []
        } else if (powerupTargetSpec === targetSpecs.PlayerPowerupInGameCards) {
            if (typeof powerupTargetSpecData !== "string" || !powerupTargetSpecData.length)
                powerupTargetSpecData = "blue"
        } else if (powerupTargetSpec === targetSpecs.PlayerHealth) {
            powerupTargetSpecData = null
        }
    }

    function targetBlockCount() {
        if (powerupTargetSpec !== targetSpecs.Blocks)
            return 0
        if (!Array.isArray(powerupTargetSpecData))
            return 0
        return powerupTargetSpecData.length
    }

    function effectiveAmount() {
        return Math.max(0, Math.abs(powerupActualAmount))
    }

    function calculateEnergyRequired() {
        var amount = effectiveAmount()
        var base = amount > 0 ? amount : 1

        var specMultiplier = 1
        if (powerupTargetSpec === targetSpecs.Blocks) {
            var blocks = Math.max(1, targetBlockCount())
            specMultiplier = blocks
        } else if (powerupTargetSpec === targetSpecs.PlayerPowerupInGameCards) {
            specMultiplier = 1.5
        }

        var operationMultiplier = powerupOperation === operations.Decrease ? 2 : 1
        var targetMultiplier = powerupTarget === targets.Enemy ? 1.5 : 1
        var healthBonus = Math.max(0, powerupCardHealth)

        var energy = (base + healthBonus * 0.5) * specMultiplier * operationMultiplier * targetMultiplier
        return Math.ceil(energy)
    }

    function updateEnergyRequirement() {
        var energy = calculateEnergyRequired()
        if (powerupCardEnergyRequired !== energy) {
            powerupCardEnergyRequired = energy
            energyRecalculated(energy)
        }
    }

    onPowerupTargetChanged: {
        powerupOperation = powerupTarget === targets.Enemy ? operations.Decrease : operations.Increase
        updateEnergyRequirement()
    }

    onPowerupTargetSpecChanged: {
        ensureSpecDataDefaults()
        updateEnergyRequirement()
    }

    onPowerupTargetSpecDataChanged: updateEnergyRequirement()
    onPowerupCardHealthChanged: updateEnergyRequirement()
    onPowerupActualAmountChanged: updateEnergyRequirement()
    onPowerupOperationChanged: updateEnergyRequirement()

    function normalizedHeroSpan(value) {
        var span = Number(value)
        if (!isFinite(span))
            span = 1
        span = Math.floor(span)
        if (span < 1)
            span = 1
        if (span > 6)
            span = 6
        return span
    }

    function ensureHeroSpanDefaults() {
        var normalizedRows = normalizedHeroSpan(powerupHeroRowSpan)
        if (normalizedRows !== powerupHeroRowSpan)
            powerupHeroRowSpan = normalizedRows
        var normalizedCols = normalizedHeroSpan(powerupHeroColSpan)
        if (normalizedCols !== powerupHeroColSpan)
            powerupHeroColSpan = normalizedCols
    }

    onPowerupHeroRowSpanChanged: ensureHeroSpanDefaults()
    onPowerupHeroColSpanChanged: ensureHeroSpanDefaults()

    Component.onCompleted: {
        ensureSpecDataDefaults()
        powerupOperation = powerupTarget === targets.Enemy ? operations.Decrease : operations.Increase
        ensureHeroSpanDefaults()
        updateEnergyRequirement()
    }
}
