function heroCellFulfillsIdle(grid, row, column, entry) {
    if (grid.isHeroOccupiedCell(row, column))
        return true;
    if (entry && (entry.powerupHeroLinked || entry.heroLinked || entry.heroBindingKey || entry.powerupHeroUuid))
        return true;
    return false;
}

function allEntriesIdleAllowMissing(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry)
                continue;
            if (grid.normalizeStateName(entry.blockState) !== "idle") {
                if (heroCellFulfillsIdle(grid, row, column, entry))
                    continue;
                return false;
            }
        }
    }
    return true;
}

function allEntriesIdleNoMissing(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry) {
                if (heroCellFulfillsIdle(grid, row, column, entry))
                    continue;
                return false;
            }
            if (grid.normalizeStateName(entry.blockState) !== "idle") {
                if (heroCellFulfillsIdle(grid, row, column, entry))
                    continue;
                return false;
            }
        }
    }
    return true;
}

function allEntriesIdleDestroyedOrMissing(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry)
                continue;
            var state = grid.normalizeStateName(entry.blockState);
            if (state !== "idle" && state !== "destroyed") {
                if (heroCellFulfillsIdle(grid, row, column, entry))
                    continue;
                return false;
            }
        }
    }
    return true;
}

function hasMissingOrDestroyedBlocks(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry)
                return true;
            var state = grid.normalizeStateName(entry.blockState);
            if (state === "destroyed")
                return true;
        }
    }
    return false;
}

function hasActiveNonIdleBlocks(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry)
                continue;
            var state = grid.normalizeStateName(entry.blockState);
            if (state === "launch" || state === "match" || state === "explode")
                return true;
        }
    }
    return false;
}

function handlePostSwapCascadeResolution(grid) {
    if (!grid.postSwapCascading)
        return false;
    if (hasMissingOrDestroyedBlocks(grid))
        return false;
    if (hasActiveNonIdleBlocks(grid))
        return false;
    grid.postSwapCascading = false;
    grid.requestState("idle");
    return true;
}

function hasMatchedBlocks(grid) {
    grid.ensureMatrix();
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var entry = grid.getBlockEntryAt(row, column);
            if (!entry)
                continue;
            if (grid.normalizeStateName(entry.blockState) === "matched")
                return true;
        }
    }
    return false;
}

function markMatchedBlocks(grid) {
    grid.ensureMatrix();

    var matchedWrappers = [];
    var matrix = grid.blockMatrix || [];
    var registerMatch = function(wrapper) {
        if (!wrapper)
            return;
        if (matchedWrappers.indexOf(wrapper) === -1)
            matchedWrappers.push(wrapper);
    };

    for (var row = 0; row < grid.gridRows; ++row) {
        var runColor = null;
        var runWrappers = [];
        for (var column = 0; column <= grid.gridCols; ++column) {
            var wrapper = column < grid.gridCols && matrix[row] ? matrix[row][column] : null;
            var entry = wrapper && wrapper.entry ? wrapper.entry : null;
            var heroBlocked = column < grid.gridCols ? heroCellFulfillsIdle(grid, row, column, entry) : false;
            var color = (!heroBlocked && entry) ? entry.blockColor : null;

            if (color && color === runColor) {
                runWrappers.push(wrapper);
            } else {
                if (runColor && runWrappers.length >= 3) {
                    for (var idx = 0; idx < runWrappers.length; ++idx)
                        registerMatch(runWrappers[idx]);
                }
                runColor = color;
                runWrappers = color ? [wrapper] : [];
            }
        }
    }

    for (var column = 0; column < grid.gridCols; ++column) {
        var vRunColor = null;
        var vRunWrappers = [];
        for (var rowIdx = 0; rowIdx <= grid.gridRows; ++rowIdx) {
            var wrapperVertical = rowIdx < grid.gridRows && matrix[rowIdx] ? matrix[rowIdx][column] : null;
            var entryVertical = wrapperVertical && wrapperVertical.entry ? wrapperVertical.entry : null;
            var heroBlockedVertical = rowIdx < grid.gridRows ? heroCellFulfillsIdle(grid, rowIdx, column, entryVertical) : false;
            var vColor = (!heroBlockedVertical && entryVertical) ? entryVertical.blockColor : null;

            if (vColor && vColor === vRunColor) {
                vRunWrappers.push(wrapperVertical);
            } else {
                if (vRunColor && vRunWrappers.length >= 3) {
                    for (var vIdx = 0; vIdx < vRunWrappers.length; ++vIdx)
                        registerMatch(vRunWrappers[vIdx]);
                }
                vRunColor = vColor;
                vRunWrappers = vColor ? [wrapperVertical] : [];
            }
        }
    }

    for (var applyRow = 0; applyRow < grid.gridRows; ++applyRow) {
        for (var applyColumn = 0; applyColumn < grid.gridCols; ++applyColumn) {
            var applyWrapper = matrix[applyRow] ? matrix[applyRow][applyColumn] : null;
            if (!applyWrapper || !applyWrapper.entry)
                continue;
            if (matchedWrappers.indexOf(applyWrapper) !== -1)
                applyWrapper.entry.blockState = "matched";
            else if (applyWrapper.entry.blockState === "matched")
                applyWrapper.entry.blockState = "idle";
        }
    }

    var matches = [];
    for (var mIdx = 0; mIdx < matchedWrappers.length; ++mIdx) {
        var matchEntry = matchedWrappers[mIdx] && matchedWrappers[mIdx].entry;
        if (matchEntry && matchEntry.itemName)
            matches.push(matchEntry.itemName);
    }

    return { matches: matches };
}

function serializeBlocks(grid) {
    grid.ensureMatrix();
    var serialized = [];
    for (var row = 0; row < grid.gridRows; ++row) {
        for (var column = 0; column < grid.gridCols; ++column) {
            var wrapper = grid.blockMatrix[row] ? grid.blockMatrix[row][column] : null;
            if (!wrapper || !wrapper.entry)
                continue;
            if (typeof wrapper.entry.serialize === "function")
                serialized.push(wrapper.entry.serialize());
            else
                serialized.push({
                    blockColor: wrapper.entry.blockColor || "",
                    row: wrapper.entry.row,
                    column: wrapper.entry.column,
                    health: wrapper.entry.health
                });
        }
    }
    return serialized;
}
