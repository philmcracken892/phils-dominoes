let gameState = {
    myTiles: [],
    board: [],
    openEnds: [],
    spinner: null,
    players: [],
    currentTurn: null,
    selectedTile: null,
    tileOrientations: {},
    isMyTurn: false,
    resourceName: 'phils-dominoes',
    playerIndex: null,
    isAITurn: false,
    boneyardCount: 28,
    isDragging: false,
    dragTileIndex: null,
    dragOffsetX: 0,
    dragOffsetY: 0,
    isResizing: false,
    resizeDirection: null,
    resizeStartX: 0,
    resizeStartY: 0,
    startWidth: 0,
    startHeight: 0,
	isDraggingUI: false,
    dragUIStartX: 0,
    dragUIStartY: 0,
    containerStartX: 0,
    containerStartY: 0
};

const CELL_SIZE = 120;
const TILE_WIDTH = 100;
const TILE_HEIGHT = 50;

(function() {
    try {
        if (typeof GetParentResourceName === 'function') {
            gameState.resourceName = GetParentResourceName();
        }
    } catch (e) {}
})();

document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('close-btn').addEventListener('click', leaveTable);
    document.getElementById('ready-btn').addEventListener('click', playerReady);
    document.getElementById('draw-btn').addEventListener('click', drawTile);
    document.getElementById('pass-btn').addEventListener('click', passTurn);
    document.getElementById('leave-btn').addEventListener('click', leaveTable);
    document.querySelector('.game-header').addEventListener('mousedown', startDragUI);
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    document.addEventListener('keydown', onKeyDown);
    
    setupResizeHandles();
    loadUISize();
	loadUIPosition();  
});

window.addEventListener('message', function(event) {
    const data = event.data;
    switch(data.action) {
        case 'openUI': openUI(); break;
        case 'closeUI': forceCloseUI(); break;
        case 'startGame': startGame(data.data); break;
        case 'updateGame': updateGame(data.data); break;
        case 'updatePlayers': updatePlayersList(data.data); break;
        case 'drewTile': addTileToHand(data.data); break;
        case 'roundEnd': showRoundEnd(data.data); break;
		case 'gameEnd': showGameEnd(data.data); break; 
    }
});

// ==================== RESIZE ====================

// ==================== UI DRAGGING ====================

function startDragUI(e) {
    // Don't drag if clicking buttons
    if (e.target.closest('button')) return;
    
    e.preventDefault();
    
    const container = document.getElementById('dominos-container');
    const rect = container.getBoundingClientRect();
    
    gameState.isDraggingUI = true;
    gameState.dragUIStartX = e.clientX;
    gameState.dragUIStartY = e.clientY;
    gameState.containerStartX = rect.left;
    gameState.containerStartY = rect.top;
    
    document.body.style.cursor = 'grabbing';
}

function showGameEnd(data) {
  
    document.querySelectorAll('.round-end-overlay, .game-end-overlay').forEach(o => o.remove());
    
    const overlay = document.createElement('div');
    overlay.className = 'game-end-overlay';
    
    const scores = (data.scores || []).map(s => `
        <div class="score-item ${s.isWinner ? 'winner' : ''}">
            <span>${s.isAI ? '🤖' : '👤'} ${s.name} ${s.isWinner ? '👑' : ''}</span>
            <span>${s.score} pips left</span>
        </div>
    `).join('');
    
    const isWinner = !data.isAIWinner;
    const winMessage = isWinner 
        ? `🏆 YOU WON $${data.pot}! 🏆` 
        : `🤖 ${data.winner} won the pot`;
    
    overlay.innerHTML = `
        <div class="game-end-content ${isWinner ? 'victory' : 'defeat'}">
            <h2>${isWinner ? '🎉 VICTORY! 🎉' : '💀 GAME OVER 💀'}</h2>
            <p class="win-message">${winMessage}</p>
            <div class="scores-list">
                <h3>Final Scores</h3>
                ${scores}
            </div>
            <p class="closing-message">Closing in <span id="countdown">5</span> seconds...</p>
        </div>
    `;
    
    document.getElementById('dominos-container').appendChild(overlay);
    
    // Countdown
    let count = 5;
    const countdownEl = document.getElementById('countdown');
    const countdownInterval = setInterval(() => {
        count--;
        if (countdownEl) countdownEl.textContent = count;
        if (count <= 0) {
            clearInterval(countdownInterval);
        }
    }, 1000);
    
    // Auto-close after 5 seconds
    setTimeout(() => {
        overlay.remove();
        postNUI('closeUI', {});
        forceCloseUI();
    }, 5000);
}

function handleDragUI(e) {
    if (!gameState.isDraggingUI) return;
    
    const dx = e.clientX - gameState.dragUIStartX;
    const dy = e.clientY - gameState.dragUIStartY;
    
    const container = document.getElementById('dominos-container');
    
    // Calculate new position
    let newX = gameState.containerStartX + dx;
    let newY = gameState.containerStartY + dy;
    
    // Keep within screen bounds
    const rect = container.getBoundingClientRect();
    newX = Math.max(0, Math.min(newX, window.innerWidth - rect.width));
    newY = Math.max(0, Math.min(newY, window.innerHeight - rect.height));
    
    // Remove the transform and use left/top positioning
    container.style.transform = 'none';
    container.style.left = newX + 'px';
    container.style.top = newY + 'px';
}

function stopDragUI() {
    if (gameState.isDraggingUI) {
        gameState.isDraggingUI = false;
        document.body.style.cursor = 'default';
        saveUIPosition();
    }
}

function saveUIPosition() {
    const c = document.getElementById('dominos-container');
    const pos = {
        left: c.style.left,
        top: c.style.top,
        transform: c.style.transform
    };
    localStorage.setItem('dominos_position', JSON.stringify(pos));
}

function loadUIPosition() {
    try {
        const pos = JSON.parse(localStorage.getItem('dominos_position'));
        if (pos) {
            const c = document.getElementById('dominos-container');
            if (pos.left) c.style.left = pos.left;
            if (pos.top) c.style.top = pos.top;
            if (pos.transform) c.style.transform = pos.transform;
        }
    } catch(e) {}
}

function resetUIPosition() {
    const c = document.getElementById('dominos-container');
    c.style.left = '50%';
    c.style.top = '50%';
    c.style.transform = 'translate(-50%, -50%)';
    localStorage.removeItem('dominos_position');
}

function setupResizeHandles() {
    const container = document.getElementById('dominos-container');
    ['nw','ne','sw','se','n','s','e','w'].forEach(dir => {
        const handle = document.createElement('div');
        handle.className = `resize-handle resize-${dir}`;
        handle.dataset.dir = dir;
        handle.addEventListener('mousedown', startResize);
        container.appendChild(handle);
    });
}

function startResize(e) {
    e.preventDefault();
    const container = document.getElementById('dominos-container');
    const rect = container.getBoundingClientRect();
    
    gameState.isResizing = true;
    gameState.resizeDirection = e.target.dataset.dir;
    gameState.resizeStartX = e.clientX;
    gameState.resizeStartY = e.clientY;
    gameState.startWidth = rect.width;
    gameState.startHeight = rect.height;
    document.body.style.cursor = getResizeCursor(gameState.resizeDirection);
}

function getResizeCursor(dir) {
    const cursors = {nw:'nw-resize',ne:'ne-resize',sw:'sw-resize',se:'se-resize',n:'n-resize',s:'s-resize',e:'e-resize',w:'w-resize'};
    return cursors[dir] || 'default';
}

function handleResize(e) {
    const container = document.getElementById('dominos-container');
    const dir = gameState.resizeDirection;
    const dx = e.clientX - gameState.resizeStartX;
    const dy = e.clientY - gameState.resizeStartY;
    
    let w = gameState.startWidth;
    let h = gameState.startHeight;
    
    if (dir.includes('e')) w = Math.max(800, w + dx);
    if (dir.includes('w')) w = Math.max(800, w - dx);
    if (dir.includes('s')) h = Math.max(500, h + dy);
    if (dir.includes('n')) h = Math.max(500, h - dy);
    
    container.style.width = w + 'px';
    container.style.height = h + 'px';
}

function stopResize() {
    gameState.isResizing = false;
    document.body.style.cursor = 'default';
    saveUISize();
}

function saveUISize() {
    const c = document.getElementById('dominos-container');
    localStorage.setItem('dominos_size', JSON.stringify({w: c.style.width, h: c.style.height}));
}

function loadUISize() {
    try {
        const s = JSON.parse(localStorage.getItem('dominos_size'));
        if (s) {
            const c = document.getElementById('dominos-container');
            if (s.w) c.style.width = s.w;
            if (s.h) c.style.height = s.h;
        }
    } catch(e) {}
}

// ==================== DRAG ====================

function startDrag(e, index) {
    if (!gameState.isMyTurn) {
        showNotification('Not your turn!', 'error');
        return;
    }
    if (e.button !== 0) return;
    e.preventDefault();
    
    gameState.isDragging = true;
    gameState.dragTileIndex = index;
    
    const rect = e.currentTarget.getBoundingClientRect();
    gameState.dragOffsetX = e.clientX - rect.left;
    gameState.dragOffsetY = e.clientY - rect.top;
    
    const tile = gameState.myTiles[index];
    const orient = gameState.tileOrientations[index] || 'horizontal';
    
    const preview = document.getElementById('drag-preview');
    preview.innerHTML = '';
    preview.appendChild(createTileElement(tile, null, orient));
    preview.style.left = (e.clientX - gameState.dragOffsetX) + 'px';
    preview.style.top = (e.clientY - gameState.dragOffsetY) + 'px';
    preview.classList.add('visible');
    
    e.currentTarget.classList.add('dragging');
    document.body.classList.add('is-dragging');
    
    showValidDropZones(tile);
}

function onMouseMove(e) {
    // Handle UI dragging first
    if (gameState.isDraggingUI) {
        handleDragUI(e);
        return;
    }
    
    if (gameState.isResizing) {
        handleResize(e);
        return;
    }
    
    if (!gameState.isDragging) return;
    
    const preview = document.getElementById('drag-preview');
    preview.style.left = (e.clientX - gameState.dragOffsetX) + 'px';
    preview.style.top = (e.clientY - gameState.dragOffsetY) + 'px';
    
    highlightDropZone(e.clientX, e.clientY);
}

function onMouseUp(e) {
	
	if (gameState.isDraggingUI) {
        stopDragUI();
        return;
    }
	
    if (gameState.isResizing) {
        stopResize();
        return;
    }
    
    if (!gameState.isDragging) return;
    
    document.getElementById('drag-preview').classList.remove('visible');
    document.querySelectorAll('.domino-tile.dragging').forEach(t => t.classList.remove('dragging'));
    document.body.classList.remove('is-dragging');
    
    const target = getDropTarget(e.clientX, e.clientY);
    
    if (target) {
        const tile = gameState.myTiles[gameState.dragTileIndex];
        
        if (target.type === 'start') {
            playTile(gameState.dragTileIndex, null);
        } else if (tile.left === target.value || tile.right === target.value) {
            playTile(gameState.dragTileIndex, target.endId);
        } else {
            showNotification('Doesn\'t match!', 'error');
        }
    }
    
    gameState.isDragging = false;
    gameState.dragTileIndex = null;
    clearDropZones();
}

function getDropTarget(x, y) {
    // Check start zone
    const start = document.querySelector('.start-zone');
    if (start) {
        const r = start.getBoundingClientRect();
        if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
            return {type: 'start'};
        }
    }
    
    // Check drop zones
    for (const zone of document.querySelectorAll('.drop-zone')) {
        const r = zone.getBoundingClientRect();
        if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
            return {
                type: 'end',
                endId: parseInt(zone.dataset.endId),
                value: parseInt(zone.dataset.value)
            };
        }
    }
    
    return null;
}

function highlightDropZone(x, y) {
    document.querySelectorAll('.drop-zone.hover, .start-zone.hover').forEach(z => z.classList.remove('hover'));
    
    const target = getDropTarget(x, y);
    if (target) {
        if (target.type === 'start') {
            document.querySelector('.start-zone')?.classList.add('hover');
        } else {
            document.querySelector(`.drop-zone[data-end-id="${target.endId}"]`)?.classList.add('hover');
        }
    }
}

function showValidDropZones(tile) {
    document.querySelectorAll('.drop-zone').forEach(zone => {
        const val = parseInt(zone.dataset.value);
        zone.classList.toggle('valid', tile.left === val || tile.right === val);
        zone.classList.toggle('invalid', tile.left !== val && tile.right !== val);
    });
    
    document.querySelector('.start-zone')?.classList.add('valid');
}

function clearDropZones() {
    document.querySelectorAll('.drop-zone, .start-zone').forEach(z => {
        z.classList.remove('valid', 'invalid', 'hover');
    });
}

function onKeyDown(e) {
    if (e.key === 'r' || e.key === 'R') {
        if (gameState.selectedTile !== null) rotateTile(gameState.selectedTile);
        if (gameState.isDragging && gameState.dragTileIndex !== null) {
            rotateTile(gameState.dragTileIndex);
            updateDragPreview();
        }
    }
    if (e.key === 'Escape') {
        cancelDrag();
        gameState.selectedTile = null;
        renderPlayerTiles();
    }
}

function cancelDrag() {
    gameState.isDragging = false;
    gameState.dragTileIndex = null;
    document.getElementById('drag-preview').classList.remove('visible');
    document.querySelectorAll('.domino-tile.dragging').forEach(t => t.classList.remove('dragging'));
    document.body.classList.remove('is-dragging');
    clearDropZones();
}

function updateDragPreview() {
    if (!gameState.isDragging || gameState.dragTileIndex === null) return;
    const tile = gameState.myTiles[gameState.dragTileIndex];
    const orient = gameState.tileOrientations[gameState.dragTileIndex] || 'horizontal';
    const preview = document.getElementById('drag-preview');
    preview.innerHTML = '';
    preview.appendChild(createTileElement(tile, null, orient));
}

// ==================== UI ====================

function openUI() {
    const c = document.getElementById('dominos-container');
    c.style.display = 'flex';
    
    gameState.tileOrientations = {};
    gameState.isDragging = false;
    gameState.isResizing = false;
    
    document.getElementById('ready-btn').style.display = 'block';
    document.getElementById('ready-btn').disabled = false;
    document.getElementById('ready-btn').textContent = '✓ Ready';
    document.getElementById('draw-btn').style.display = 'none';
    document.getElementById('pass-btn').style.display = 'none';
    
    loadUISize();
}

function forceCloseUI() {
    const container = document.getElementById('dominos-container');
    container.style.display = 'none';
    
   
    cancelDrag();
    gameState.isDraggingUI = false;
    gameState.isResizing = false;
    
    
    document.querySelectorAll('.round-end-overlay, .game-end-overlay').forEach(o => o.remove());
    
    
    gameState.myTiles = [];
    gameState.board = [];
    gameState.openEnds = [];
    gameState.selectedTile = null;
    gameState.isMyTurn = false;
    gameState.tileOrientations = {};
    gameState.players = [];
    gameState.currentTurn = null;
    gameState.playerIndex = null;
    gameState.boneyardCount = 28;
    gameState.spinner = null;
    gameState.isAITurn = false;
    
   
    document.getElementById('player-tiles').innerHTML = '';
    document.getElementById('board-grid').innerHTML = '';
    document.getElementById('players-list').innerHTML = '';
    document.getElementById('turn-indicator').innerHTML = 'Waiting for players...';
    document.getElementById('boneyard-count').textContent = '🦴 Boneyard: --';
    
   
    document.getElementById('ready-btn').style.display = 'block';
    document.getElementById('ready-btn').disabled = false;
    document.getElementById('ready-btn').textContent = '✓ Ready';
    document.getElementById('draw-btn').style.display = 'none';
    document.getElementById('pass-btn').style.display = 'none';
}

function leaveTable() {
    postNUI('leaveTable', {});
    forceCloseUI();
}

function playerReady() {
    postNUI('ready', {});
    document.getElementById('ready-btn').disabled = true;
    document.getElementById('ready-btn').textContent = '⏳ Waiting...';
}

function startGame(data) {
    gameState.myTiles = data.tiles || [];
    gameState.board = data.board || [];
    gameState.openEnds = data.openEnds || [];
    gameState.spinner = data.spinner;
    gameState.players = data.players || [];
    gameState.currentTurn = data.currentTurn;
    gameState.playerIndex = data.playerIndex;
    gameState.boneyardCount = data.boneyardCount || 14;
    gameState.tileOrientations = {};
    
    gameState.myTiles.forEach((_, i) => gameState.tileOrientations[i] = 'horizontal');
    
    document.getElementById('ready-btn').style.display = 'none';
    document.getElementById('draw-btn').style.display = 'inline-flex';
    document.getElementById('pass-btn').style.display = 'inline-flex';
    
    renderPlayerTiles();
    renderBoard();
    updateTurnIndicator();
    updatePlayersList(gameState.players);
    updateBoneyardCount(gameState.boneyardCount);
}

function updateGame(data) {
    if (data.board !== undefined) gameState.board = data.board;
    if (data.openEnds !== undefined) gameState.openEnds = data.openEnds;
    if (data.spinner !== undefined) gameState.spinner = data.spinner;
    if (data.currentTurn !== undefined) {
        gameState.currentTurn = data.currentTurn;
        gameState.isAITurn = data.isAITurn || false;
        updateTurnIndicator();
    }
    if (data.boneyardCount !== undefined) updateBoneyardCount(data.boneyardCount);
    
    renderBoard();
    
    if (data.lastMove && data.lastMove.isAI) showAIMove(data.lastMove);
}

function updateBoneyardCount(count) {
    gameState.boneyardCount = count;
    document.getElementById('boneyard-count').textContent = '🦴 Boneyard: ' + count;
}

// ==================== BOARD ====================

function renderBoard() {
    const grid = document.getElementById('board-grid');
    grid.innerHTML = '';
    
    // Empty board
    if (!gameState.board || gameState.board.length === 0) {
        const startZone = document.createElement('div');
        startZone.className = 'start-zone';
        startZone.innerHTML = '<div class="start-label">🎲</div>';
        startZone.addEventListener('click', () => {
            if (gameState.selectedTile !== null && gameState.isMyTurn) {
                playTile(gameState.selectedTile, null);
            }
        });
        grid.appendChild(startZone);
        return;
    }
    
    // Calculate bounds
    let minX = 0, maxX = 0, minY = 0, maxY = 0;
    
    gameState.board.forEach(t => {
        minX = Math.min(minX, t.x);
        maxX = Math.max(maxX, t.x);
        minY = Math.min(minY, t.y);
        maxY = Math.max(maxY, t.y);
    });
    
    gameState.openEnds.forEach(e => {
        minX = Math.min(minX, e.x);
        maxX = Math.max(maxX, e.x);
        minY = Math.min(minY, e.y);
        maxY = Math.max(maxY, e.y);
    });
    
    minX--; maxX++; minY--; maxY++;
    
    const w = (maxX - minX + 1) * CELL_SIZE;
    const h = (maxY - minY + 1) * CELL_SIZE;
    
    grid.style.width = Math.max(w, 300) + 'px';
    grid.style.height = Math.max(h, 200) + 'px';
    
    // Render tiles
    gameState.board.forEach(bt => {
        const el = createBoardTile(bt);
        const tw = bt.orientation === 'horizontal' ? TILE_WIDTH : TILE_HEIGHT;
        const th = bt.orientation === 'horizontal' ? TILE_HEIGHT : TILE_WIDTH;
        const left = (bt.x - minX) * CELL_SIZE + (CELL_SIZE - tw) / 2;
        const top = (bt.y - minY) * CELL_SIZE + (CELL_SIZE - th) / 2;
        el.style.cssText = `position:absolute;left:${left}px;top:${top}px;`;
        if (bt.isSpinner) el.classList.add('spinner');
        grid.appendChild(el);
    });
    
    // Render drop zones (clean - no arrows or numbers)
    gameState.openEnds.forEach(end => {
        const zone = document.createElement('div');
        const isVert = end.direction === 'up' || end.direction === 'down';
        zone.className = `drop-zone ${isVert ? 'vertical' : 'horizontal'}`;
        
        const zw = isVert ? 60 : 110;
        const zh = isVert ? 110 : 60;
        const left = (end.x - minX) * CELL_SIZE + (CELL_SIZE - zw) / 2;
        const top = (end.y - minY) * CELL_SIZE + (CELL_SIZE - zh) / 2;
        
        zone.style.cssText = `position:absolute;left:${left}px;top:${top}px;`;
        zone.dataset.endId = end.id;
        zone.dataset.value = end.value;
        zone.dataset.direction = end.direction;
        
        zone.addEventListener('click', () => {
            if (gameState.selectedTile !== null && gameState.isMyTurn) {
                const tile = gameState.myTiles[gameState.selectedTile];
                if (tile.left === end.value || tile.right === end.value) {
                    playTile(gameState.selectedTile, end.id);
                } else {
                    showNotification('Doesn\'t match!', 'error');
                }
            }
        });
        
        grid.appendChild(zone);
    });
}

function createBoardTile(bt) {
    const div = document.createElement('div');
    div.className = `domino-tile ${bt.orientation} board-tile`;
    if (bt.displayLeft === bt.displayRight) div.classList.add('double');
    
    div.appendChild(createPipSection(bt.displayLeft));
    
    const divider = document.createElement('div');
    divider.className = 'tile-divider';
    div.appendChild(divider);
    
    div.appendChild(createPipSection(bt.displayRight));
    
    return div;
}

// ==================== PLAYER TILES ====================

function renderPlayerTiles() {
    const container = document.getElementById('player-tiles');
    container.innerHTML = '';
    
    document.getElementById('tile-count').textContent = gameState.myTiles.length;
    
    if (!gameState.myTiles.length) {
        container.innerHTML = '<p class="empty-hand">No tiles</p>';
        return;
    }
    
    gameState.myTiles.forEach((tile, i) => {
        const orient = gameState.tileOrientations[i] || 'horizontal';
        const el = createTileElement(tile, i, orient);
        
        el.addEventListener('mousedown', e => startDrag(e, i));
        el.addEventListener('contextmenu', e => { e.preventDefault(); rotateTile(i); });
        el.addEventListener('click', () => { if (!gameState.isDragging) selectTile(i); });
        
        if (gameState.selectedTile === i) el.classList.add('selected');
        
        container.appendChild(el);
    });
}

function createTileElement(tile, index, orient) {
    const div = document.createElement('div');
    div.className = `domino-tile ${orient}`;
    if (index !== null) div.dataset.index = index;
    if (tile.left === tile.right) div.classList.add('double');
    
    div.appendChild(createPipSection(tile.left));
    
    const divider = document.createElement('div');
    divider.className = 'tile-divider';
    div.appendChild(divider);
    
    div.appendChild(createPipSection(tile.right));
    
    return div;
}

function createPipSection(num) {
    const section = document.createElement('div');
    section.className = 'pip-section';
    
    const positions = {
        0: [],
        1: [5],
        2: [1, 9],
        3: [1, 5, 9],
        4: [1, 3, 7, 9],
        5: [1, 3, 5, 7, 9],
        6: [1, 3, 4, 6, 7, 9]
    };
    
    const pos = positions[num] || [];
    for (let i = 1; i <= 9; i++) {
        const pip = document.createElement('div');
        pip.className = pos.includes(i) ? 'pip' : 'pip empty';
        section.appendChild(pip);
    }
    
    return section;
}

// ==================== TILE ACTIONS ====================

function selectTile(index) {
    if (!gameState.isMyTurn) {
        showNotification('Not your turn!', 'error');
        return;
    }
    
    if (gameState.selectedTile === index) {
        gameState.selectedTile = null;
    } else {
        gameState.selectedTile = index;
        
        // Auto-play if board empty
        if (!gameState.board || gameState.board.length === 0) {
            playTile(index, null);
            return;
        }
    }
    
    renderPlayerTiles();
}

function rotateTile(index) {
    const cur = gameState.tileOrientations[index] || 'horizontal';
    gameState.tileOrientations[index] = cur === 'horizontal' ? 'vertical' : 'horizontal';
    renderPlayerTiles();
}

function playTile(tileIndex, endId) {
    if (!gameState.isMyTurn) return;
    
    postNUI('makeMove', {
        tileIndex: tileIndex + 1,
        endId: endId
    });
    
    gameState.myTiles.splice(tileIndex, 1);
    
    const newOrient = {};
    Object.keys(gameState.tileOrientations).forEach(k => {
        const key = parseInt(k);
        if (key < tileIndex) newOrient[key] = gameState.tileOrientations[k];
        else if (key > tileIndex) newOrient[key - 1] = gameState.tileOrientations[k];
    });
    gameState.tileOrientations = newOrient;
    
    gameState.selectedTile = null;
    renderPlayerTiles();
}

// ==================== GAME ACTIONS ====================

function drawTile() {
    if (!gameState.isMyTurn) {
        showNotification('Not your turn!', 'error');
        return;
    }
    if (gameState.boneyardCount <= 0) {
        showNotification('Boneyard empty!', 'warning');
        return;
    }
    postNUI('drawTile', {});
}

function passTurn() {
    if (!gameState.isMyTurn) {
        showNotification('Not your turn!', 'error');
        return;
    }
    postNUI('passTurn', {});
}

function addTileToHand(tile) {
    const idx = gameState.myTiles.length;
    gameState.myTiles.push(tile);
    gameState.tileOrientations[idx] = 'horizontal';
    gameState.boneyardCount--;
    updateBoneyardCount(gameState.boneyardCount);
    renderPlayerTiles();
    showNotification('Drew a tile!', 'success');
}

// ==================== PLAYERS ====================

function updatePlayersList(players) {
    const container = document.getElementById('players-list');
    if (!container) return;
    
    container.innerHTML = '';
    gameState.players = players;
    
    if (!players.length) {
        container.innerHTML = '<p style="color:#999;">Waiting...</p>';
        return;
    }
    
    players.forEach((p, i) => {
        const div = document.createElement('div');
        div.className = 'player-item';
        
        const num = i + 1;
        const isTurn = num === gameState.currentTurn;
        const isMe = num === gameState.playerIndex;
        
        if (isTurn) {
            div.classList.add('current-turn');
            gameState.isMyTurn = isMe;
        }
        if (p.isAI) div.classList.add('ai-player');
        
        const icon = p.isAI ? '🤖' : (isMe ? '👤' : '🎭');
        const name = isMe ? `${p.name} (You)` : p.name;
        
        div.innerHTML = `<span>${icon} ${name}${isTurn ? ' 🎯' : ''}</span><span>🎴 ${p.tileCount || '?'}</span>`;
        container.appendChild(div);
    });
    
    updateTurnIndicator();
}

function updateTurnIndicator() {
    const el = document.getElementById('turn-indicator');
    const drawBtn = document.getElementById('draw-btn');
    const passBtn = document.getElementById('pass-btn');
    
    if (gameState.isAITurn) {
        el.innerHTML = '<span style="color:#ffc107;">🤖 AI thinking...</span>';
        drawBtn.disabled = passBtn.disabled = true;
    } else if (gameState.isMyTurn) {
        el.innerHTML = '<span style="color:#28a745;">🎯 Your Turn!</span>';
        drawBtn.disabled = passBtn.disabled = false;
    } else {
        el.innerHTML = '<span style="color:#ffc107;">⏳ Waiting...</span>';
        drawBtn.disabled = passBtn.disabled = true;
    }
}

// ==================== NOTIFICATIONS ====================

function showAIMove(move) {
    const el = document.createElement('div');
    el.className = 'ai-move-indicator';
    el.innerHTML = `
        <div style="text-align:center;">
            <div style="font-size:2em;">🤖</div>
            <div style="margin:8px 0;">${move.player}</div>
            <div style="font-size:1.6em;">[${move.tile.left}|${move.tile.right}]</div>
        </div>
    `;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 2000);
}

function showRoundEnd(data) {
    const overlay = document.createElement('div');
    overlay.className = 'round-end-overlay';
    
    const scores = (data.scores || []).map(s => `
        <div class="score-item">
            <span>${s.isAI ? '🤖' : '👤'} ${s.name}</span>
            <span>${s.score} pts</span>
        </div>
    `).join('');
    
    overlay.innerHTML = `
        <div class="round-end-content">
            <h2>🎲 Round Over!</h2>
            <p style="font-size:1.4em;margin:15px 0;">
                ${data.isAIWinner ? '🤖' : '🏆'} <strong>${data.winner}</strong> wins!
            </p>
            <div class="scores-list"><h3>Scores</h3>${scores}</div>
            <p style="margin-top:15px;opacity:0.7;">Next round soon...</p>
        </div>
    `;
    
    document.getElementById('dominos-container').appendChild(overlay);
    setTimeout(() => overlay.remove(), 5000);
}

function showNotification(msg, type = 'info') {
    document.querySelectorAll('.game-notification').forEach(n => n.remove());
    
    const colors = {error:'#dc3545',success:'#28a745',warning:'#ffc107',info:'#007bff'};
    const icons = {error:'❌',success:'✅',warning:'⚠️',info:'ℹ️'};
    
    const el = document.createElement('div');
    el.className = 'game-notification';
    el.style.background = colors[type];
    el.style.color = type === 'warning' ? '#000' : '#fff';
    el.innerHTML = `${icons[type]} ${msg}`;
    
    document.body.appendChild(el);
    setTimeout(() => {
        el.style.opacity = '0';
        setTimeout(() => el.remove(), 300);
    }, 2500);
}

function postNUI(event, data) {
    fetch(`https://${gameState.resourceName}/${event}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(data)
    }).catch(console.error);
}