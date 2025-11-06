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
    property var battleGrid: null

    readonly property int heroMaxHealth: Math.max(1, powerupCardHealth || 1)
    property int heroCurrentHealth: heroMaxHealth
    readonly property real heroHealthProgress: heroMaxHealth > 0
                                                ? Math.max(0, Math.min(heroCurrentHealth, heroMaxHealth)) / heroMaxHealth
                                                : 0
    readonly property bool heroAlive: heroCurrentHealth > 0
    property bool heroDefeated: false

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

    function ensureHeroWithinBounds() {
        var maxHealth = heroMaxHealth
        var adjusted = heroCurrentHealth
        if (adjusted > maxHealth)
            adjusted = maxHealth
        if (adjusted < 0)
            adjusted = 0
        if (adjusted !== heroCurrentHealth)
            heroCurrentHealth = adjusted
    }

    function resetHeroVitals() {
        heroCurrentHealth = heroMaxHealth
        ensureHeroWithinBounds()
    }

    function applyHeroDamage(amount) {
        var dmg = Math.max(0, Math.floor(amount))
        if (dmg <= 0)
            return heroCurrentHealth
        heroCurrentHealth = Math.max(0, heroCurrentHealth - dmg)
        return heroCurrentHealth
    }

    function applyHeroHealing(amount) {
        var heal = Math.max(0, Math.floor(amount))
        if (heroDefeated || heal <= 0)
            return heroCurrentHealth
        heroCurrentHealth = Math.min(heroMaxHealth, heroCurrentHealth + heal)
        return heroCurrentHealth
    }

    function consumeEnergy() {
        if (powerupCardEnergyRequired <= 0)
            return
        if (currentEnergy <= 0)
            return
        currentEnergy = Math.max(0, currentEnergy - powerupCardEnergyRequired)
        ensureEnergyWithinBounds()
    }

    function resetEnergy() {
        if (currentEnergy === 0)
            return
        currentEnergy = 0
        ensureEnergyWithinBounds()
    }

    function resetAfterHeroRemoval() {
        heroPlaced = false
        heroInstance = null
        dragLocked = false
        heroCurrentHealth = 0
        ensureHeroWithinBounds()
        battleGrid = null
        heroDefeated = false
    }

    function markHeroDefeated() {
        heroPlaced = false
        heroInstance = null
        dragLocked = true
        currentEnergy = 0
        activationReady = false
        heroCurrentHealth = 0
        heroDefeated = true
        battleGrid = null
        ensureHeroWithinBounds()
        ensureEnergyWithinBounds()
    }

    function markHeroPlacedState(alive) {
        heroPlaced = !!alive
        dragLocked = !!alive
        if (alive)
            heroDefeated = false
        if (alive)
            resetHeroVitals()
    }

    function updateActivationState() {
        var required = Math.max(0, powerupCardEnergyRequired)
        if (heroDefeated) {
            activationReady = false
            return
        }
        var ready = required === 0 ? true : currentEnergy >= required
        activationReady = ready
    }

    function gainEnergy(amount) {
        if (!amount || amount <= 0)
            return
        if (heroDefeated)
            return
        currentEnergy = currentEnergy + Math.floor(amount)
        ensureEnergyWithinBounds()
    }

    function resetRuntimeState() {
        currentEnergy = 0
        heroPlaced = false
        dragLocked = false
        heroInstance = null
        heroDefeated = false
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
        resetHeroVitals()
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
    onPowerupCardHealthChanged: {
        ensureHeroWithinBounds()
    }

    Component.onCompleted: {
        resetHeroVitals()
    }
}
