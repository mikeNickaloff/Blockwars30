import QtQuick 2.15

import "../../engine" as Engine
import "../data" as Data
import "../factory.js" as Factory
import "./" as UI

Item {
    id: sidebar

    property var gameScene
    property var loadout: []
    property int maxCards: 4
    property real cardWidth: 64 * 1.15
    property real cardHeight: 64 * 1.6
    property real cardSpacing: 8
    property real contentPadding: 3
    property real heroCellWidth: 40
    property real heroCellHeight: 40
    property real heroCellSpacing: 1
    property color backgroundColor: "#0b1422"
    property color frameColor: "#162236"
    property var sidebarCards: []

    signal heroPreviewStarted(var cardData, var heroItem)
    signal heroPreviewMoved(var cardData, var heroItem)
    signal heroPreviewEnded(var cardData, var heroItem)
    signal heroPlacementRequested(var cardData, var heroItem, real sceneX, real sceneY)
    signal cardEnergyChanged(var cardData)

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: maxCards * cardHeight + Math.max(0, maxCards - 1) * cardSpacing + contentPadding * 2

    onLoadoutChanged: rebuildCards()
    onWidthChanged: repositionCards()
    onHeightChanged: repositionCards()

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
        UI.PowerupCard { }
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
        Data.PowerupCardModel { }
    }

    Component.onCompleted: rebuildCards()

    function repositionCards() {
        for (var i = 0; i < sidebarCards.length; ++i) {
            var slot = sidebarCards[i]
            slot.homeX = homeXForSlot()
            slot.homeY = homeYForSlot(slot.slotIndex)
            snapCardHome(slot)
        }
    }

    function homeXForSlot() {
        return width - contentPadding - cardWidth
    }

    function homeYForSlot(slotIndex) {
        return contentPadding + slotIndex * (cardHeight + cardSpacing)
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
                        width: cardWidth,
                        height: cardHeight,
                        x: homeXForSlot(),
                        y: homeYForSlot(slotIndex),
                        z: slotIndex + 1,
                        namePrefix: "battleCardSidebar",
                        cardProps: {
                            interactive: false
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

        dragItem.itemDragging.connect(function() { handleCardDragStart(slot) })
        dragItem.itemDraggedTo.connect(function() { handleCardDragMove(slot) })
        dragItem.itemDropped.connect(function() { handleCardDragEnd(slot) })
        dragItem.entryDestroyed.connect(function() {
            if (slot.hero)
                slot.hero.destroy()
            slot.hero = null
        })
    }

    function updateDragEnabled(slot) {
        if (!slot || !slot.dragItem || !slot.cardData)
            return
        var enabled = slot.cardData.activationReady && !slot.cardData.dragLocked && !slot.cardData.heroPlaced
        slot.dragItem.enabled = enabled
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
            if (slot.cardData.heroPlaced)
                continue
            var cardColor = (slot.cardData.powerupCardColor || "").toLowerCase()
            if (cardColor !== key)
                continue
            slot.cardData.gainEnergy(amount)
            updateDragEnabled(slot)
        }
    }
}
