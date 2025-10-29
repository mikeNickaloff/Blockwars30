// Layout.js
.pragma library

/**
 * Compute grid position for a linear index.
 * @param {number} index  0..N-1
 * @param {object} o      { cols, cellW, cellH, gapX, gapY, originX, originY }
 * @return {object}       { x, y, row, col }
 */
function gridPos(index, o) {
    const cols   = o.cols   || 6;
    const cellW  = o.cellW  || 64;
    const cellH  = o.cellH  || 64;
    const gapX   = o.gapX   || 8;
    const gapY   = o.gapY   || 8;
    const originX= o.originX|| 0;
    const originY= o.originY|| 0;

    const col = index % cols;
    const row = Math.floor(index / cols);
    const x = originX + col * (cellW + gapX);
    const y = originY + row * (cellH + gapY);
    return { x, y, row, col };
}
