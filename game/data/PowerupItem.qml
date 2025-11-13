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
        PlayerPowerupInGameCards: "PlayerPowerupInGameCards",
        RelativeGridArea: "RelativeGridArea"
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
    property int powerupIcon: 0

    property int powerupCardEnergyRequired: 0

    signal energyRecalculated(int energyRequired)

    function setTarget(target) {
        if (target === targets.Enemy || target === targets.Self)
            powerupTarget = target
    }

    function setTargetSpec(spec, specData) {
        if (spec === targetSpecs.Blocks
                || spec === targetSpecs.PlayerHealth
                || spec === targetSpecs.PlayerPowerupInGameCards
                || spec === targetSpecs.RelativeGridArea) {
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
        } else if (powerupTargetSpec === targetSpecs.RelativeGridArea) {
            powerupTargetSpecData = sanitizedRelativeAreaSpecData(powerupTargetSpecData)
        }
    }

    function defaultRelativeAreaSpecData() {
        return {
            rows: 1,
            columns: 1,
            distance: 6
        }
    }

    function normalizedRelativeAreaDimension(value) {
        var dimension = Number(value)
        if (!isFinite(dimension))
            dimension = 1
        dimension = Math.floor(dimension)
        if (dimension < 1)
            dimension = 1
        if (dimension > 5)
            dimension = 5
        return dimension
    }

    function normalizedRelativeAreaDistance(value) {
        var distance = Number(value)
        if (!isFinite(distance))
            distance = 6
        distance = Math.floor(distance)
        if (distance < -6)
            distance = -6
        if (distance > 6)
            distance = 6
        return distance
    }

    function sanitizedRelativeAreaSpecData(value) {
        var normalized = defaultRelativeAreaSpecData()
        if (!value || typeof value !== "object")
            return normalized
        var hasRows = value.rows !== undefined ? value.rows : value.rowCount
        var hasColumns = value.columns !== undefined ? value.columns : value.colCount
        var hasDistance = value.distance !== undefined ? value.distance : value.rowOffset
        normalized.rows = normalizedRelativeAreaDimension(hasRows)
        normalized.columns = normalizedRelativeAreaDimension(hasColumns)
        normalized.distance = normalizedRelativeAreaDistance(hasDistance)
        return normalized
    }

    function relativeAreaDataEquals(a, b) {
        if (!a || !b)
            return false
        return a.rows === b.rows && a.columns === b.columns && a.distance === b.distance
    }

    function targetBlockCount() {
        if (powerupTargetSpec !== targetSpecs.Blocks)
            return 0
        if (!Array.isArray(powerupTargetSpecData))
            return 0
        return powerupTargetSpecData.length
    }

    function relativeAreaBlockCount(data) {
        var spec = sanitizedRelativeAreaSpecData(data)
        return Math.max(1, spec.rows) * Math.max(1, spec.columns)
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
            specMultiplier = blocks * 0.5
        } else if (powerupTargetSpec === targetSpecs.PlayerPowerupInGameCards) {
            specMultiplier = 8
        } else if (powerupTargetSpec === targetSpecs.RelativeGridArea) {
            var relativeBlocks = Math.max(1, relativeAreaBlockCount(powerupTargetSpecData))
            specMultiplier = relativeBlocks * 0.5
        }

        var operationMultiplier = powerupOperation === operations.Decrease ? 0.5 : 0.5
        var targetMultiplier = powerupTarget === targets.Enemy ? 0.5 : 0.5
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

    function applyRelativeAreaSanitization() {
        if (powerupTargetSpec !== targetSpecs.RelativeGridArea)
            return false
        var normalized = sanitizedRelativeAreaSpecData(powerupTargetSpecData)
        if (relativeAreaDataEquals(normalized, powerupTargetSpecData))
            return false
        powerupTargetSpecData = normalized
        return true
    }

    onPowerupTargetSpecDataChanged: {
        if (applyRelativeAreaSanitization())
            return
        updateEnergyRequirement()
    }
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
    function normalizePowerupIcon(value) {
        var normalized = Number(value)
        if (!isFinite(normalized))
            normalized = 0
        normalized = Math.floor(normalized)
        if (normalized < 0)
            normalized = 0
        if (normalized >= 25)
            normalized = normalized % 25
        return normalized
    }

    onPowerupIconChanged: {
        var normalizedIcon = normalizePowerupIcon(powerupIcon)
        if (normalizedIcon !== powerupIcon)
            powerupIcon = normalizedIcon
    }

    Component.onCompleted: {
        ensureSpecDataDefaults()
        powerupOperation = powerupTarget === targets.Enemy ? operations.Decrease : operations.Increase
        ensureHeroSpanDefaults()
        updateEnergyRequirement()
    }
}
