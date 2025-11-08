import QtQuick 2.15
import QtQuick.Layouts

import "../../engine" as Engine
import "../data" as Data
import "../factory.js" as Factory
import "./" as UI

Item {
    id: sidebar

    property var gameScene
    property Item battleGrid: null
    property var loadout: []
    property int maxCards: 4
    property real baseCardWidth: 64 * 1.15
    property real baseCardHeight: 64 * 1.6
    property real slotWidth: {
        var available = width - contentPadding * 2
        if (available > baseCardWidth)
            return available
        return baseCardWidth
    }
    property real slotHeight: {
        var limit = battleGrid ? battleGrid.height / 4.5 : baseCardHeight
        return Math.min(baseCardHeight, limit)
    }
    property real cardSpacing: 8
    property real contentPadding: 3
    property real heroCellWidth: 40
    property real heroCellHeight: 40
    property real heroCellSpacing: 1
    property color backgroundColor: "#0b1422"
    property color frameColor: "#162236"
    property var sidebarCards: []
    property bool interactionsEnabled: true

    signal heroPreviewStarted(var cardData, var heroItem)
    signal heroPreviewMoved(var cardData, var heroItem)
    signal heroPreviewEnded(var cardData, var heroItem)
    signal heroPlacementRequested(var cardData, var heroItem, real sceneX, real sceneY)
    signal cardEnergyChanged(var cardData)
    signal powerupActivationRequested(var cardData)

    implicitWidth: baseCardWidth + contentPadding * 2
    implicitHeight: maxCards * slotHeight + Math.max(0, maxCards - 1) * cardSpacing + contentPadding * 2

    anchors.left: battleGrid ? battleGrid.right : undefined

    onLoadoutChanged: rebuildCards()
    onWidthChanged: repositionCards()
    onHeightChanged: repositionCards()
    onSlotHeightChanged: repositionCards()
    onBattleGridChanged: repositionCards()
    onInteractionsEnabledChanged: {
        for (var idx = 0; idx < sidebarCards.length; ++idx)
            updateDragEnabled(sidebarCards[idx]);
    }

    Connections {
        target: battleGrid
        enabled: !!battleGrid
        function onHeightChanged() {
            sidebar.repositionCards()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: backgroundColor
        border.color: frameColor
        border.width: 2
    }

    Item {
        id: cardLayer
        anchors.fill: parent
        clip: false
    }

    Item {
        id: heroLayer
        anchors.fill: parent
        z: 10
        clip: false
    }

    Component {
        id: cardComponent
        UI.PowerupCard {
        Layout.fillWidth: true
        }
    }

    Component {
        id: dragComponent
        Engine.GameDragItem { }
    }

    Component {
        id: heroComponent
        UI.PowerupHero { }
    }

    Component {
        id: cardDataComponent
        Data.PowerupCardModel {

        }
    }

    Component.onCompleted: rebuildCards()

    function repositionCards() {
        for (var i = 0; i < sidebarCards.length; ++i) {
            var slot = sidebarCards[i]
            slot.homeX = homeXForSlot()
            slot.homeY = homeYForSlot(slot.slotIndex)
            if (slot.dragItem) {
                slot.dragItem.width = slotWidth
                slot.dragItem.height = slotHeight
                slot.dragItem.Layout.fillWidth = true
            }
            if (slot.dragItem && slot.dragItem.entry) {
                slot.dragItem.entry.width = slotWidth
                slot.dragItem.entry.height = slotHeight
                slot.dragItem.entry.Layout.fillWidth = true
            }
            snapCardHome(slot)
        }
    }

    function homeXForSlot() {
        return contentPadding
    }

    function homeYForSlot(slotIndex) {
        return contentPadding + slotIndex * (slotHeight + cardSpacing)
    }

    function destroyCards() {
        for (var i = 0; i < sidebarCards.length; ++i) {
            var slot = sidebarCards[i]
            if (slot.dragItem)
                slot.dragItem.destroy()
            if (slot.hero && slot.hero !== slot.dragItem)
                slot.hero.destroy()
            if (slot.cardData)
                slot.cardData.destroy()
        }
        sidebarCards = []
    }

    function rebuildCards() {
        destroyCards()
        if (!Array.isArray(loadout))
            return
        for (var i = 0; i < Math.min(loadout.length, maxCards); ++i) {
            var entry = loadout[i]
            var record = entry && entry.powerup ? entry.powerup : entry
            if (!record || !record.powerupUuid)
                continue
            createCardSlot(i, record)
        }
    }

    function createCardSlot(slotIndex, record) {
        var cardData = cardDataComponent.createObject(sidebar)
        cardData.applyRecord(record)

        var creation = Factory.createBattleCardSidebarCard(
                    cardComponent,
                    dragComponent,
                    heroComponent,
                    cardLayer,
                    gameScene || sidebar,
                    {
                        width: slotWidth,
                        height: slotHeight,
                        x: homeXForSlot(),
                        y: homeYForSlot(slotIndex),
                        z: slotIndex + 1,
                        namePrefix: "battleCardSidebar",
                        cardProps: {
                            interactive: false,

                            runtimeData: cardData
                        },
                        heroProps: {
                            parent: heroLayer,
                            powerupName: cardData.powerupName,
                            powerupCardColor: cardData.powerupCardColor,
                            powerupHeroRowSpan: cardData.powerupHeroRowSpan,
                            powerupHeroColSpan: cardData.powerupHeroColSpan,
                            cellWidth: heroCellWidth,
                            cellHeight: heroCellHeight,
                            cellSpacing: heroCellSpacing
                        }
                    })
        if (!creation || !creation.dragItem) {
            if (cardData)
                cardData.destroy()
            return
        }
        var dragItem = creation.dragItem

        if (dragItem.entry && typeof dragItem.entry.applyRecord === "function")
            dragItem.entry.applyRecord(record)
        dragItem.homeX = dragItem.x
        dragItem.homeY = dragItem.y
        dragItem.enabled = cardData.activationReady && !cardData.dragLocked
        dragItem.Layout.fillWidth = true
        if (dragItem.entry) {
            dragItem.entry.runtimeData = cardData
            dragItem.entry.Layout.fillWidth = true
            dragItem.entry.width = slotWidth
            dragItem.entry.height = slotHeight
            if (dragItem.entry.activated) {
                dragItem.entry.activated.connect(function() {
                    requestHeroActivation(slot)
                })
            }
        }

        var hero = creation.heroEntry || null
        if (hero) {
            if (typeof hero.applyCard === "function")
                hero.applyCard(record)
            hero.visible = false
            hero.cardData = cardData
        }

        var slot = {
            slotIndex: slotIndex,
            dragItem: dragItem,
            cardData: cardData,
            hero: hero,
            homeX: dragItem.homeX,
            homeY: dragItem.homeY,
            dragging: false
        }

        sidebarCards.push(slot)
        cardData.activationReadyChanged.connect(function() { updateDragEnabled(slot) })
        cardData.energyChanged.connect(function() { cardEnergyChanged(cardData) })
        cardData.heroPlacedChanged.connect(function() { updateDragEnabled(slot) })
        cardData.heroDefeatedChanged.connect(function() { updateDragEnabled(slot) })
        cardData.heroCurrentHealthChanged.connect(function() {
            if (!cardData.heroAlive)
                updateDragEnabled(slot)
        })

        dragItem.itemDragging.connect(function() { handleCardDragStart(slot) })
        dragItem.itemDraggedTo.connect(function() { handleCardDragMove(slot) })
        dragItem.itemDropped.connect(function() { handleCardDragEnd(slot) })
        dragItem.entryDestroyed.connect(function() {
            if (slot.hero)
                slot.hero.destroy()
            slot.hero = null
        })
        updateDragEnabled(slot)
    }

    function updateDragEnabled(slot) {
        if (!slot || !slot.dragItem || !slot.cardData)
            return
        var cardData = slot.cardData
        var heroReady = cardData.heroPlaced && cardData.heroAlive && cardData.activationReady
        var allowDrag = cardData.activationReady && !cardData.dragLocked && !cardData.heroPlaced && !cardData.heroDefeated
        slot.dragItem.enabled = interactionsEnabled && (allowDrag || heroReady)
        if (slot.dragItem.entry && slot.dragItem.entry.interactive !== undefined)
            slot.dragItem.entry.interactive = interactionsEnabled && heroReady && !allowDrag
    }

    function snapCardHome(slot) {
        if (!slot || !slot.dragItem)
            return
        slot.dragItem.dragActive = false
        slot.dragItem.x = slot.homeX
        slot.dragItem.y = slot.homeY
    }

    function handleCardDragStart(slot) {
        if (!slot || !slot.cardData)
            return
        if (!interactionsEnabled) {
            slot.dragging = false
            snapCardHome(slot)
            return
        }
        if (slot.cardData.heroPlaced) {
            if (slot.cardData.heroAlive && slot.cardData.activationReady)
                requestHeroActivation(slot)
            slot.dragging = false
            snapCardHome(slot)
            return
        }
        if (!slot.cardData.activationReady || slot.cardData.dragLocked) {
            slot.dragging = false
            snapCardHome(slot)
            return
        }
        slot.dragging = true
        beginHeroPreview(slot)
    }

    function handleCardDragMove(slot) {
        if (!slot || !slot.dragging)
            return
        updateHeroPreview(slot)
    }

    function handleCardDragEnd(slot) {
        if (!slot)
            return
        var dropped = slot.dragging
        endHeroPreview(slot, dropped)
        snapCardHome(slot)
        if (dropped) {
            var dropItem = slot.hero || slot.dragItem
            var scenePoint = dropItem.mapToGlobal(dropItem.width / 2, dropItem.height / 2)
            heroPlacementRequested(slot.cardData, slot.hero || null, scenePoint.x, scenePoint.y)
        }
        slot.dragging = false
    }

    function beginHeroPreview(slot) {
        if (slot.hero) {
            slot.hero.previewMode = true
            slot.hero.visible = true
            positionHero(slot)
        }
        heroPreviewStarted(slot.cardData, slot.hero || null)
    }

    function updateHeroPreview(slot) {
        if (!slot || !slot.dragging)
            return
        if (slot.hero)
            positionHero(slot)
        heroPreviewMoved(slot.cardData, slot.hero || null)
    }

    function endHeroPreview(slot, wasDragging) {
        if (!slot)
            return
        if (slot.hero)
            slot.hero.visible = false
        if (wasDragging)
            heroPreviewEnded(slot.cardData, slot.hero || null)
    }

    function positionHero(slot) {
        if (!slot.hero || !slot.dragItem)
            return
        var point = slot.dragItem.mapToItem(heroLayer, slot.dragItem.width / 2, slot.dragItem.height / 2)
        slot.hero.x = point.x - slot.hero.width / 2
        slot.hero.y = point.y - slot.hero.height / 2
    }

    function distributeEnergy(blockColor, amount) {
        if (!blockColor || !amount || amount <= 0)
            return
        var key = blockColor.toString().toLowerCase()
        for (var i = 0; i < sidebarCards.length; ++i) {
            var slot = sidebarCards[i]
            if (!slot.cardData)
                continue
            if (slot.cardData.heroDefeated)
                continue
            if (slot.cardData.heroPlaced && !slot.cardData.heroAlive)
                continue
            var cardColor = (slot.cardData.powerupCardColor || "").toLowerCase()
            if (cardColor !== key)
                continue
            slot.cardData.gainEnergy(amount)
            updateDragEnabled(slot)
        }
    }
    function requestHeroActivation(slot, options) {
        var ignoreInteractions = options && options.ignoreInteractions;
        if (!slot || !slot.cardData)
            return false;
        if (!interactionsEnabled && !ignoreInteractions)
            return false;
        if (!slot.cardData.heroPlaced)
            return false;
        if (!slot.cardData.heroAlive)
            return false;
        if (!slot.cardData.activationReady)
            return false;
        powerupActivationRequested(slot.cardData);
        return true;
    }

    function forceHeroActivation(slot) {
        return requestHeroActivation(slot, { ignoreInteractions: true });
    }
}
