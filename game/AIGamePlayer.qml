import QtQuick 2.15
import QtQml 2.15

Item {
    id: aiPlayer

    property var battleGrid
    property var gameScene
    property var battleCardSidebar
    property string controlledTurn: "top"
    property bool enabled: true
    property int planningDelay: 220
    readonly property int heroPlacementRetries: 3

    signal swapRequested(int row1, int column1, int row2, int column2)

    readonly property int __minRun: 3

    Timer {
        id: planningTimer
        interval: aiPlayer.planningDelay
        repeat: false
        running: false
        onTriggered: aiPlayer.planMove()
    }

    onBattleGridChanged: {
        if (battleGrid && typeof battleGrid.ensureMatrix === "function")
            battleGrid.ensureMatrix();
        schedulePlanning("gridChanged");
    }

    onGameSceneChanged: schedulePlanning("sceneChanged");

    Connections {
        target: aiPlayer.gameScene
        ignoreUnknownSignals: true
        function onCurrentTurnChanged() {
            aiPlayer.schedulePlanning("turnChanged");
        }
        function onTurnsLeftChanged() {
            aiPlayer.schedulePlanning("turnBudgetChanged");
        }
    }

    Connections {
        target: aiPlayer.battleGrid
        ignoreUnknownSignals: true
        function onCurrentStateChanged() {
            aiPlayer.schedulePlanning("stateChanged");
        }
        function onPostSwapCascadingChanged() {
            aiPlayer.schedulePlanning("cascadeChanged");
        }
        function onBlockMatrixChanged() {
            aiPlayer.schedulePlanning("matrixChanged");
        }
    }

    function schedulePlanning(reason) {
        if (!canActNow())
            return;
        if (planningTimer.running)
            planningTimer.restart();
        else
            planningTimer.start();
    }

    function canActNow() {
        if (!enabled || !battleGrid || !gameScene)
            return false;
        var remaining = Number(gameScene.turnsLeft);
        if (!isFinite(remaining) || remaining <= 0)
            return false;
        if (gameScene.currentTurn !== controlledTurn)
            return false;
        const state = (battleGrid.currentState || "").toString().toLowerCase();
        if (state !== "idle")
            return false;
        if (battleGrid.postSwapCascading)
            return false;
        return true;
    }

    function planMove() {
        if (!canActNow())
            return;
        if (attemptPowerupActions()) {
            schedulePlanning("heroAction");
            return;
        }
        const matrix = captureColorMatrix();
        if (!matrix)
            return;
        const swaps = findCandidateSwaps(matrix);
        if (!swaps.length)
            return;
        const choice = swaps[Math.floor(Math.random() * swaps.length)];
        console.log("AI wants to swap", JSON.stringify(choice));
        swapRequested(choice.row1, choice.column1, choice.row2, choice.column2);
    }

    function attemptPowerupActions() {
        var slots = (battleCardSidebar && battleCardSidebar.sidebarCards) ? battleCardSidebar.sidebarCards : [];
        if (!slots.length)
            return false;
        var deployable = [];
        var activatable = [];
        for (var idx = 0; idx < slots.length; ++idx) {
            var slot = slots[idx];
            if (!slot || !slot.cardData)
                continue;
            var card = slot.cardData;
            if (card.heroDefeated || !card.activationReady)
                continue;
            if (!card.heroPlaced)
                deployable.push(slot);
            else if (card.heroAlive)
                activatable.push(slot);
        }
        if (deployable.length && tryPlaceHeroSlot(deployable[Math.floor(Math.random() * deployable.length)]))
            return true;
        if (activatable.length && tryActivateHeroSlot(activatable[Math.floor(Math.random() * activatable.length)]))
            return true;
        return false;
    }

    function tryPlaceHeroSlot(slot) {
        if (!slot || !slot.cardData || !battleGrid || !gameScene)
            return false;
        var card = slot.cardData;
        var gridRows = battleGrid.gridRows || 0;
        var gridCols = battleGrid.gridCols || 0;
        var heroRows = Math.max(1, card.powerupHeroRowSpan || 1);
        var heroCols = Math.max(1, card.powerupHeroColSpan || 1);
        if (heroRows > gridRows || heroCols > gridCols)
            return false;
        var maxRow = Math.max(0, gridRows - heroRows);
        var maxCol = Math.max(0, gridCols - heroCols);
        for (var attempt = 0; attempt < heroPlacementRetries; ++attempt) {
            var row = randomInt(maxRow);
            var column = randomInt(maxCol);
            if (typeof battleGrid.canPlaceHero === "function") {
                if (!battleGrid.canPlaceHero(card.powerupUuid, row, column, heroRows, heroCols))
                    continue;
            }
            if (typeof gameScene.attemptHeroPlacementAtCell === "function" && gameScene.attemptHeroPlacementAtCell(battleGrid, card, row, column)) {
                console.log("AI placed hero", card.powerupName, "at", row, column);
                return true;
            }
        }
        return false;
    }

    function tryActivateHeroSlot(slot) {
        if (!slot || !slot.cardData)
            return false;
        if (!cardReadyForActivation(slot.cardData))
            return false;
        if (battleCardSidebar) {
            if (typeof battleCardSidebar.forceHeroActivation === "function")
                return !!battleCardSidebar.forceHeroActivation(slot);
            if (typeof battleCardSidebar.requestHeroActivation === "function")
                return !!battleCardSidebar.requestHeroActivation(slot, { ignoreInteractions: true });
        }
        if (gameScene && typeof gameScene.triggerPowerupActivation === "function")
            return !!gameScene.triggerPowerupActivation(slot.cardData, { trigger: "ai" });
        return false;
    }

    function cardReadyForActivation(card) {
        if (!card)
            return false;
        if (!card.heroPlaced)
            return false;
        if (!card.heroAlive)
            return false;
        return !!card.activationReady;
    }

    function randomInt(maxInclusive) {
        if (!isFinite(maxInclusive) || maxInclusive <= 0)
            return 0;
        return Math.floor(Math.random() * (maxInclusive + 1));
    }

    function captureColorMatrix() {
        if (!battleGrid || !battleGrid.blockMatrix)
            return null;
        const rows = battleGrid.gridRows || battleGrid.blockMatrix.length;
        const columns = battleGrid.gridCols
                ? battleGrid.gridCols
                : ((rows > 0 && battleGrid.blockMatrix[0]) ? battleGrid.blockMatrix[0].length : 0);
        if (!rows || !columns)
            return null;
        const matrix = [];
        for (var row = 0; row < rows; ++row) {
            var rowColors = [];
            matrix.push(rowColors);
            var sourceRow = battleGrid.blockMatrix[row] || [];
            for (var column = 0; column < columns; ++column) {
                var wrapper = sourceRow[column] || null;
                var entry = wrapper && wrapper.entry ? wrapper.entry : null;
                rowColors.push(entry && entry.blockColor ? entry.blockColor.toString() : null);
            }
        }
        return matrix;
    }

    function findCandidateSwaps(matrix) {
        var candidates = [];
        var rows = matrix.length;
        var columns = rows ? matrix[0].length : 0;
        if (!rows || !columns)
            return candidates;
        for (var row = 0; row < rows; ++row) {
            for (var column = 0; column < columns; ++column) {
                var color = matrix[row][column];
                if (!color)
                    continue;
                if (column + 1 < columns && matrix[row][column + 1] && matrix[row][column + 1] !== color) {
                    if (swapCreatesMatch(matrix, row, column, row, column + 1))
                        candidates.push({ row1: row, column1: column, row2: row, column2: column + 1 });
                }
                if (row + 1 < rows && matrix[row + 1][column] && matrix[row + 1][column] !== color) {
                    if (swapCreatesMatch(matrix, row, column, row + 1, column))
                        candidates.push({ row1: row, column1: column, row2: row + 1, column2: column });
                }
            }
        }
        return candidates;
    }

    function swapCreatesMatch(matrix, row1, column1, row2, column2) {
        var temp = matrix[row1][column1];
        matrix[row1][column1] = matrix[row2][column2];
        matrix[row2][column2] = temp;
        var hasMatch = hasLineMatchAt(matrix, row1, column1) || hasLineMatchAt(matrix, row2, column2);
        temp = matrix[row1][column1];
        matrix[row1][column1] = matrix[row2][column2];
        matrix[row2][column2] = temp;
        return hasMatch;
    }

    function hasLineMatchAt(matrix, row, column) {
        var target = matrix[row][column];
        if (!target)
            return false;
        var rows = matrix.length;
        var columns = matrix[0].length;
        var count = 1;
        var cursor = column - 1;
        while (cursor >= 0 && matrix[row][cursor] === target) {
            count += 1;
            cursor -= 1;
        }
        cursor = column + 1;
        while (cursor < columns && matrix[row][cursor] === target) {
            count += 1;
            cursor += 1;
        }
        if (count >= __minRun)
            return true;
        count = 1;
        cursor = row - 1;
        while (cursor >= 0 && matrix[cursor][column] === target) {
            count += 1;
            cursor -= 1;
        }
        cursor = row + 1;
        while (cursor < rows && matrix[cursor][column] === target) {
            count += 1;
            cursor += 1;
        }
        return count >= __minRun;
    }
}
