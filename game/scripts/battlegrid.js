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

function randomPaletteColor(palette) {
    var colors = (palette && palette.length > 0) ? palette : ["red", "green", "yellow", "blue"];
    return colors[Math.floor(Math.random() * colors.length)];
}

function createsHorizontalRun(rowColors, column, color) {
    if (!rowColors)
        return false;
    var left1 = column > 0 ? rowColors[column - 1] : null;
    var left2 = column > 1 ? rowColors[column - 2] : null;
    if (left1 === color && left2 === color)
        return true;
    var right1 = column + 1 < rowColors.length ? rowColors[column + 1] : null;
    var right2 = column + 2 < rowColors.length ? rowColors[column + 2] : null;
    if (right1 === color && right2 === color)
        return true;
    if (left1 === color && right1 === color)
        return true;
    return false;
}

function createsVerticalRun(matrix, row, column, color) {
    var up1 = row > 0 && matrix[row - 1] ? matrix[row - 1][column] : null;
    var up2 = row > 1 && matrix[row - 2] ? matrix[row - 2][column] : null;
    if (up1 === color && up2 === color)
        return true;
    var down1 = matrix[row + 1] ? matrix[row + 1][column] : null;
    var down2 = matrix[row + 2] ? matrix[row + 2][column] : null;
    if (down1 === color && down2 === color)
        return true;
    if (up1 === color && down1 === color)
        return true;
    return false;
}

function selectAlternateColor(matrix, row, column, palette, previousColor) {
    var pool = (palette && palette.slice) ? palette.slice(0) : ["red", "green", "yellow", "blue"];
    while (pool.length > 0) {
        var candidateIdx = Math.floor(Math.random() * pool.length);
        var candidate = pool[candidateIdx];
        pool.splice(candidateIdx, 1);
        if (candidate === previousColor)
            continue;
        var rowColors = matrix[row];
        if (createsHorizontalRun(rowColors, column, candidate))
            continue;
        if (createsVerticalRun(matrix, row, column, candidate))
            continue;
        return candidate;
    }
    return randomPaletteColor(palette);
}

function buildMatchSafeMatrix(grid, palette) {
    var matrix = [];
    if (!grid)
        return matrix;
    for (var row = 0; row < grid.gridRows; ++row) {
        var rowColors = [];
        matrix[row] = rowColors;
        for (var column = 0; column < grid.gridCols; ++column) {
            if (grid.isHeroOccupiedCell && grid.isHeroOccupiedCell(row, column)) {
                rowColors[column] = null;
                continue;
            }
            rowColors[column] = selectAlternateColor(matrix, row, column, palette, null);
        }
    }
    return matrix;
}

function rerollRowMatches(matrix, palette) {
    var mutated = false;
    for (var row = 0; row < matrix.length; ++row) {
        var rowColors = matrix[row] || [];
        var runColor = null;
        var runLength = 0;
        for (var column = 0; column < rowColors.length; ++column) {
            var color = rowColors[column];
            if (!color) {
                runColor = null;
                runLength = 0;
                continue;
            }
            if (color === runColor)
                runLength++;
            else {
                runColor = color;
                runLength = 1;
            }
            if (runLength >= 3) {
                rowColors[column] = selectAlternateColor(matrix, row, column, palette, color);
                runColor = rowColors[column];
                runLength = 1;
                mutated = true;
            }
        }
    }
    return mutated;
}

function rerollColumnMatches(matrix, palette) {
    if (!matrix || matrix.length === 0)
        return false;
    var gridRows = matrix.length;
    var gridCols = matrix[0] ? matrix[0].length : 0;
    var mutated = false;
    for (var column = 0; column < gridCols; ++column) {
        var runColor = null;
        var runLength = 0;
        for (var row = 0; row < gridRows; ++row) {
            var cellRow = matrix[row] || [];
            var color = cellRow[column];
            if (!color) {
                runColor = null;
                runLength = 0;
                continue;
            }
            if (color === runColor)
                runLength++;
            else {
                runColor = color;
                runLength = 1;
            }
            if (runLength >= 3) {
                cellRow[column] = selectAlternateColor(matrix, row, column, palette, color);
                runColor = cellRow[column];
                runLength = 1;
                mutated = true;
            }
        }
    }
    return mutated;
}

function matrixHasMatches(matrix) {
    if (!matrix || matrix.length === 0)
        return false;
    var cols = matrix[0] ? matrix[0].length : 0;
    for (var row = 0; row < matrix.length; ++row) {
        var rowColors = matrix[row] || [];
        var runColor = null;
        var runLength = 0;
        var flattened = rowColors.join("");
        if (flattened.indexOf("redredred") !== -1 || flattened.indexOf("greengreengreen") !== -1 ||
                flattened.indexOf("yellowyellowyellow") !== -1 || flattened.indexOf("blueblueblue") !== -1)
            return true;
        for (var column = 0; column < rowColors.length; ++column) {
            var color = rowColors[column];
            if (!color) {
                runColor = null;
                runLength = 0;
                continue;
            }
            if (color === runColor)
                runLength++;
            else {
                runColor = color;
                runLength = 1;
            }
            if (runLength >= 3)
                return true;
        }
    }

    for (var columnIdx = 0; columnIdx < cols; ++columnIdx) {
        var vRunColor = null;
        var vRunLength = 0;
        for (var rowIdx = 0; rowIdx < matrix.length; ++rowIdx) {
            var vRow = matrix[rowIdx] || [];
            var vColor = vRow[columnIdx];
            if (!vColor) {
                vRunColor = null;
                vRunLength = 0;
                continue;
            }
            if (vColor === vRunColor)
                vRunLength++;
            else {
                vRunColor = vColor;
                vRunLength = 1;
            }
            if (vRunLength >= 3)
                return true;
        }
    }
    return false;
}

function scrubMatrixMatches(matrix, palette) {
    var guard = 0;
    while (guard < 8) {
        var mutated = false;
        mutated = rerollRowMatches(matrix, palette) || mutated;
        mutated = rerollColumnMatches(matrix, palette) || mutated;
        if (!mutated)
            break;
        guard++;
    }
    return matrix;
}

function generateMatchFreeMatrix(grid, palette) {
    var matrix = buildMatchSafeMatrix(grid, palette);
    scrubMatrixMatches(matrix, palette);
    return matrix;
}
