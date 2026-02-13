local RSGCore = exports['rsg-core']:GetCoreObject()
local ActiveGames = {}
local PlayerGames = {}

function SetTimeout(ms, callback)
    Citizen.CreateThread(function()
        Citizen.Wait(ms)
        callback()
    end)
end

CreateThread(function()
    for _, tableData in pairs(Config.Tables) do
        ActiveGames[tableData.id] = CreateNewGame(tableData.id)
    end
    
end)

function CreateNewGame(tableId)
    return {
        id = tableId,
        players = {},
        gameState = 'waiting',
        currentTurn = nil,
        board = {},
        openEnds = {},
        boneyard = {},
        pot = 0,
        started = false,
        withAI = false,
        aiDifficulty = 'medium',
        spinner = nil,
        spinnerPlayed = false,
        nextEndId = 1  -- Unique ID counter for open ends
    }
end

function SafeAITurn(tableId, maxAttempts)
    
end


function ResetAITimer(tableId)
    
end

RSGCore.Functions.CreateCallback('rsg-dominos:server:getTableStatus', function(source, cb, tableId)
    local game = ActiveGames[tableId]
    
    if not game then
        cb({
            hasWaitingGame = false,
            inProgress = false,
            playerCount = 0,
            currentBet = 0
        })
        return
    end
    
    local humanPlayers = 0
    local currentBet = 0
    
    for _, p in ipairs(game.players) do
        if p.isHuman then
            humanPlayers = humanPlayers + 1
            currentBet = p.bet
        end
    end
    
    -- Check if it's an AI game (don't allow others to join AI games)
    local isAIGame = game.withAI
    
    cb({
        hasWaitingGame = humanPlayers > 0 and not game.started and not isAIGame,
        inProgress = game.started,
        playerCount = #game.players,
        currentBet = currentBet,
        isAIGame = isAIGame
    })
end)

function InitializeBoard(game, tile)
    game.board = {}
    game.openEnds = {}
    game.spinner = nil
    game.spinnerPlayed = false
    game.nextEndId = 1  
    
    local isDouble = tile.left == tile.right
    
    local boardTile = {
        x = 0,
        y = 0,
        left = tile.left,
        right = tile.right,
        orientation = isDouble and 'vertical' or 'horizontal',
        displayLeft = tile.left,
        displayRight = tile.right,
        isSpinner = isDouble
    }
    
    table.insert(game.board, boardTile)
    
    if isDouble then
        game.spinner = {x = 0, y = 0}
        game.spinnerPlayed = true
        
       
        table.insert(game.openEnds, {id = game.nextEndId, x = -1, y = 0, direction = 'left', value = tile.left})
        game.nextEndId = game.nextEndId + 1
        
        table.insert(game.openEnds, {id = game.nextEndId, x = 1, y = 0, direction = 'right', value = tile.left})
        game.nextEndId = game.nextEndId + 1
        
        table.insert(game.openEnds, {id = game.nextEndId, x = 0, y = -1, direction = 'up', value = tile.left})
        game.nextEndId = game.nextEndId + 1
        
        table.insert(game.openEnds, {id = game.nextEndId, x = 0, y = 1, direction = 'down', value = tile.left})
        game.nextEndId = game.nextEndId + 1
    else
       
        table.insert(game.openEnds, {id = game.nextEndId, x = -1, y = 0, direction = 'left', value = tile.left})
        game.nextEndId = game.nextEndId + 1
        
        table.insert(game.openEnds, {id = game.nextEndId, x = 1, y = 0, direction = 'right', value = tile.right})
        game.nextEndId = game.nextEndId + 1
    end
    
    
    
    
    for _, e in ipairs(game.openEnds) do
        
    end
    
    return true
end

function FindOpenEndById(game, endId)
    for i, openEnd in ipairs(game.openEnds) do
        if openEnd.id == endId then
            return i, openEnd
        end
    end
    return nil, nil
end

function PlaceTile(game, tile, endId)
    local idx, openEnd = FindOpenEndById(game, endId)
    
    if not openEnd then
        
        
        for _, e in ipairs(game.openEnds) do
           
        end
        return false
    end
    
    local matchValue = openEnd.value
    local direction = openEnd.direction
    
    
    
    
    if tile.left ~= matchValue and tile.right ~= matchValue then
        
        return false
    end
    
    local isDouble = tile.left == tile.right
    local newX, newY = openEnd.x, openEnd.y
    local orientation, displayLeft, displayRight
    
    
    if isDouble then
        orientation = (direction == 'left' or direction == 'right') and 'vertical' or 'horizontal'
        displayLeft = tile.left
        displayRight = tile.right
    else
        orientation = (direction == 'left' or direction == 'right') and 'horizontal' or 'vertical'
        
        -- Orient tile correctly
        if direction == 'left' then
            if tile.right == matchValue then
                displayLeft, displayRight = tile.left, tile.right
            else
                displayLeft, displayRight = tile.right, tile.left
            end
        elseif direction == 'right' then
            if tile.left == matchValue then
                displayLeft, displayRight = tile.left, tile.right
            else
                displayLeft, displayRight = tile.right, tile.left
            end
        elseif direction == 'up' then
            if tile.right == matchValue then
                displayLeft, displayRight = tile.left, tile.right
            else
                displayLeft, displayRight = tile.right, tile.left
            end
        else -- down
            if tile.left == matchValue then
                displayLeft, displayRight = tile.left, tile.right
            else
                displayLeft, displayRight = tile.right, tile.left
            end
        end
    end
    
    
    local boardTile = {
        x = newX,
        y = newY,
        left = tile.left,
        right = tile.right,
        orientation = orientation,
        displayLeft = displayLeft,
        displayRight = displayRight,
        isSpinner = isDouble and not game.spinnerPlayed
    }
    
    if boardTile.isSpinner then
        game.spinner = {x = newX, y = newY}
        game.spinnerPlayed = true
    end
    
    table.insert(game.board, boardTile)
    
    
    table.remove(game.openEnds, idx)
    
    
    if isDouble and boardTile.isSpinner then
        
        local dirs = {
            {dx = -1, dy = 0, dir = 'left'},
            {dx = 1, dy = 0, dir = 'right'},
            {dx = 0, dy = -1, dir = 'up'},
            {dx = 0, dy = 1, dir = 'down'}
        }
        for _, d in ipairs(dirs) do
            if d.dir ~= GetOppositeDirection(direction) then
                table.insert(game.openEnds, {
                    id = game.nextEndId,
                    x = newX + d.dx,
                    y = newY + d.dy,
                    direction = d.dir,
                    value = displayLeft
                })
                game.nextEndId = game.nextEndId + 1
            end
        end
    elseif isDouble then
        
        local dx, dy = GetDirectionDelta(direction)
        table.insert(game.openEnds, {
            id = game.nextEndId,
            x = newX + dx,
            y = newY + dy,
            direction = direction,
            value = displayLeft
        })
        game.nextEndId = game.nextEndId + 1
    else
       
        local dx, dy = GetDirectionDelta(direction)
        local newValue
        
        if displayLeft == matchValue then
            newValue = displayRight
        else
            newValue = displayLeft
        end
        
        table.insert(game.openEnds, {
            id = game.nextEndId,
            x = newX + dx,
            y = newY + dy,
            direction = direction,
            value = newValue
        })
        game.nextEndId = game.nextEndId + 1
    end
    
    
    
    
    for _, e in ipairs(game.openEnds) do
        
    end
    
    return true
end

function GetOppositeDirection(dir)
    local opposites = {left = 'right', right = 'left', up = 'down', down = 'up'}
    return opposites[dir]
end

function GetDirectionDelta(dir)
    local deltas = {left = {-1, 0}, right = {1, 0}, up = {0, -1}, down = {0, 1}}
    return deltas[dir][1], deltas[dir][2]
end

function CanPlayTile(game, tile)
    if #game.board == 0 then return true end
    
    for _, openEnd in ipairs(game.openEnds) do
        if tile.left == openEnd.value or tile.right == openEnd.value then
            return true
        end
    end
    return false
end

function GetValidMoves(game, tile)
    local moves = {}
    if #game.board == 0 then
        return {{id = 0, direction = 'center'}}
    end
    
    for _, openEnd in ipairs(game.openEnds) do
        if tile.left == openEnd.value or tile.right == openEnd.value then
            table.insert(moves, openEnd)
        end
    end
    return moves
end



RegisterNetEvent('rsg-dominos:server:joinTable', function(tableId, bet, withAI, aiCount, difficulty)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local game = ActiveGames[tableId]
    if not game then return end
    
    local tableConfig = nil
    for _, t in pairs(Config.Tables) do
        if t.id == tableId then tableConfig = t break end
    end
    if not tableConfig then return end
    
    if PlayerGames[src] then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Already playing', type = 'error'})
        return
    end
    
    if Player.PlayerData.money.cash < bet then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Not enough money', type = 'error'})
        return
    end
    
    if bet < tableConfig.minBet or bet > tableConfig.maxBet then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Invalid bet', type = 'error'})
        return
    end
    
    -- If joining existing game, match existing bet
    if #game.players > 0 and not game.started then
        local existingBet = game.players[1].bet
        if bet ~= existingBet then
            bet = existingBet -- Force match the existing bet
        end
    end
    
    if #game.players == 0 then
        ResetGame(tableId)
        game = ActiveGames[tableId]
    end
    
    if game.started then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Game in progress', type = 'error'})
        return
    end
    
    -- Don't allow joining AI games
    if game.withAI then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'This is an AI game', type = 'error'})
        return
    end
    
    if #game.players >= tableConfig.maxPlayers then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Table full', type = 'error'})
        return
    end
    
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Notify existing players that someone joined
    for _, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:playerJoined', p.id, playerName, #game.players + 1, tableConfig.maxPlayers)
        end
    end
    
    table.insert(game.players, {
        id = src,
        name = playerName,
        bet = bet,
        tiles = {},
        score = 0,
        ready = false,
        isAI = false,
        isHuman = true
    })
    
    Player.Functions.RemoveMoney('cash', bet, 'dominos-bet')
    game.pot = game.pot + bet
    
    if withAI and aiCount and aiCount > 0 then
        game.withAI = true
        game.aiDifficulty = difficulty or 'medium'
        
        local aiNames = Config.AINames or {"Wild Bill", "Doc Holliday", "Jesse James", "Wyatt Earp"}
        local used = {}
        
        for i = 1, math.min(aiCount, tableConfig.maxPlayers - #game.players) do
            local name
            repeat name = aiNames[math.random(#aiNames)] until not used[name]
            used[name] = true
            
            table.insert(game.players, {
                id = "AI_" .. tableId .. "_" .. i,
                name = name,
                bet = bet,
                tiles = {},
                score = 0,
                ready = true,
                isAI = true,
                isHuman = false,
                difficulty = difficulty or 'medium'
            })
            game.pot = game.pot + bet
        end
    end
    
    PlayerGames[src] = tableId
    UpdateTablePlayers(tableId)
    
    TriggerClientEvent('rsg-dominos:client:joinedTable', src, tableId, #game.players)
    TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Joined! Bet: $' .. bet, type = 'success'})
    
    if game.withAI and #game.players >= 2 then
        SetTimeout(2000, function()
            local g = ActiveGames[tableId]
            if g and not g.started and #g.players >= 2 then
                for _, p in ipairs(g.players) do p.ready = true end
                StartGame(tableId)
            end
        end)
    end
    
    -- Auto-start when 2+ human players ready (for non-AI games)
    if not game.withAI and #game.players >= 2 then
        local allHumansReady = true
        for _, p in ipairs(game.players) do
            if p.isHuman and not p.ready then
                allHumansReady = false
                break
            end
        end
        
        if allHumansReady then
            SetTimeout(2000, function()
                local g = ActiveGames[tableId]
                if g and not g.started and #g.players >= 2 then
                    StartGame(tableId)
                end
            end)
        end
    end
end)

RegisterNetEvent('rsg-dominos:server:leaveTable', function()
    local src = source
    local tableId = PlayerGames[src]
    if not tableId then return end
    
    local game = ActiveGames[tableId]
    if not game then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    
    for i, p in ipairs(game.players) do
        if p.id == src then
            if not game.started and Player then
                Player.Functions.AddMoney('cash', p.bet, 'dominos-refund')
                game.pot = game.pot - p.bet
            end
            table.remove(game.players, i)
            break
        end
    end
    
    PlayerGames[src] = nil
    TriggerClientEvent('rsg-dominos:client:leftTable', src)
    
    local hasHumans = false
    for _, p in ipairs(game.players) do
        if p.isHuman then hasHumans = true break end
    end
    
    if not hasHumans then
        ResetGame(tableId)
    else
        UpdateTablePlayers(tableId)
    end
end)

RegisterNetEvent('rsg-dominos:server:playerReady', function()
    local src = source
    local tableId = PlayerGames[src]
    if not tableId then return end
    
    local game = ActiveGames[tableId]
    if not game then return end
    
    for _, p in ipairs(game.players) do
        if p.id == src then p.ready = true break end
    end
    
    local allReady = #game.players >= 2
    for _, p in ipairs(game.players) do
        if not p.ready then allReady = false break end
    end
    
    if allReady then StartGame(tableId) end
    UpdateTablePlayers(tableId)
end)

RegisterNetEvent('rsg-dominos:server:drawTile', function()
    local src = source
    local tableId = PlayerGames[src]
    if not tableId then return end
    
    local game = ActiveGames[tableId]
    if not game or not game.started then return end
    
    local player = game.players[game.currentTurn]
    if not player or player.id ~= src then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Not your turn', type = 'error'})
        return
    end
    
    if #game.boneyard > 0 then
        local tile = table.remove(game.boneyard, 1)
        table.insert(player.tiles, tile)
        
        TriggerClientEvent('rsg-dominos:client:drewTile', src, tile)
        BroadcastBoneyardUpdate(tableId)
        UpdateTablePlayers(tableId)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Boneyard empty!', type = 'warning'})
    end
end)

RegisterNetEvent('rsg-dominos:server:makeMove', function(tileIndex, endId)
    local src = source
    local tableId = PlayerGames[src]
    if not tableId then return end
    
    local game = ActiveGames[tableId]
    if not game or not game.started then return end
    
    local player = game.players[game.currentTurn]
    if not player or player.id ~= src then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Not your turn', type = 'error'})
        return
    end
    
    local tile = player.tiles[tileIndex]
    if not tile then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Invalid tile', type = 'error'})
        return
    end
    
    
    
    
    if #game.board == 0 then
        table.remove(player.tiles, tileIndex)
        InitializeBoard(game, tile)
        BroadcastGameState(tableId, player.name, tile, 'center')
        CheckWinOrNextTurn(tableId, player)
        return
    end
    
   
    if not endId then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Select where to place', type = 'error'})
        return
    end
    
    if PlaceTile(game, tile, endId) then
        table.remove(player.tiles, tileIndex)
        BroadcastGameState(tableId, player.name, tile, 'placed')
        CheckWinOrNextTurn(tableId, player)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Invalid move', type = 'error'})
    end
end)

RegisterNetEvent('rsg-dominos:server:passTurn', function()
    local src = source
    local tableId = PlayerGames[src]
    if not tableId then return end
    
    local game = ActiveGames[tableId]
    if not game or not game.started then return end
    
    local player = game.players[game.currentTurn]
    if not player or player.id ~= src then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Not your turn', type = 'error'})
        return
    end
    
    -- Check valid moves
    for _, tile in ipairs(player.tiles) do
        if CanPlayTile(game, tile) then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'You can play!', type = 'error'})
            return
        end
    end
    
    if #game.boneyard > 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Dominos', description = 'Draw first!', type = 'error'})
        return
    end
    
    NextTurn(tableId)
end)



function BroadcastGameState(tableId, playerName, tile, action)
    local game = ActiveGames[tableId]
    if not game then return end
    
    for _, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:updateGame', p.id, {
                board = game.board,
                openEnds = game.openEnds,
                spinner = game.spinner,
                boneyardCount = #game.boneyard,
                lastMove = {
                    player = playerName,
                    tile = tile,
                    action = action,
                    isAI = false
                }
            })
        end
    end
    UpdateTablePlayers(tableId)
end

function BroadcastBoneyardUpdate(tableId)
    local game = ActiveGames[tableId]
    if not game then return end
    
    for _, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:updateGame', p.id, {
                boneyardCount = #game.boneyard
            })
        end
    end
end

function CheckWinOrNextTurn(tableId, player)
    if #player.tiles == 0 then
        EndRound(tableId, ActiveGames[tableId].currentTurn)
    else
        NextTurn(tableId)
    end
end

function StartGame(tableId)
    local game = ActiveGames[tableId]
    if not game or game.started or #game.players < 2 then return end
    
    
    
    game.started = true
    game.board = {}
    game.openEnds = {}
    game.spinner = nil
    game.spinnerPlayed = false
    game.nextEndId = 1  
    
   
    local tiles = {}
    for i = 0, 6 do
        for j = i, 6 do
            table.insert(tiles, {left = i, right = j})
        end
    end
    
   
    math.randomseed(os.time())
    for i = #tiles, 2, -1 do
        local j = math.random(i)
        tiles[i], tiles[j] = tiles[j], tiles[i]
    end
    
   
    local idx = 1
    local deal = Config.GameSettings.startingTiles or 7
    for _, p in ipairs(game.players) do
        p.tiles = {}
        for i = 1, deal do
            if tiles[idx] then
                table.insert(p.tiles, tiles[idx])
                idx = idx + 1
            end
        end
    end
    
    
    game.boneyard = {}
    for i = idx, #tiles do
        table.insert(game.boneyard, tiles[i])
    end
    
    
    game.currentTurn = GetFirstPlayer(game)
    
   
    for i, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:startGame', p.id, {
                tiles = p.tiles,
                players = GetPlayerInfo(game),
                currentTurn = game.currentTurn,
                board = game.board,
                openEnds = game.openEnds,
                playerIndex = i,
                currentPlayerName = game.players[game.currentTurn].name,
                boneyardCount = #game.boneyard
            })
        end
    end
    
    
    if game.players[game.currentTurn].isAI then
        ProcessAITurn(tableId, 0) 
    end
end

function GetFirstPlayer(game)
    local best = {idx = 1, double = -1, total = -1}
    
    for i, p in ipairs(game.players) do
        for _, t in ipairs(p.tiles) do
            if t.left == t.right and t.left > best.double then
                best = {idx = i, double = t.left, total = t.left + t.right}
            elseif best.double < 0 and t.left + t.right > best.total then
                best = {idx = i, double = -1, total = t.left + t.right}
            end
        end
    end
    
    return best.idx
end

function NextTurn(tableId)
    local game = ActiveGames[tableId]
    if not game or not game.started then return end
	
	ResetAITimer(tableId)
    
   
    local blocked = 0
    for _, p in ipairs(game.players) do
        local canPlay = false
        for _, t in ipairs(p.tiles) do
            if CanPlayTile(game, t) then 
                canPlay = true 
                break 
            end
        end
        if not canPlay and #game.boneyard == 0 then
            blocked = blocked + 1
        end
    end
    
   
    if blocked == #game.players then
       
        
        local lowest = {idx = 1, pips = 999}
        for i, p in ipairs(game.players) do
            local pips = 0
            for _, t in ipairs(p.tiles) do 
                pips = pips + t.left + t.right 
            end
           
            if pips < lowest.pips then 
                lowest = {idx = i, pips = pips} 
            end
        end
        
        EndRound(tableId, lowest.idx)
        return
    end
    
    
    game.currentTurn = (game.currentTurn % #game.players) + 1
    
    for _, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:updateGame', p.id, {
                currentTurn = game.currentTurn,
                currentPlayerName = game.players[game.currentTurn].name,
                isAITurn = game.players[game.currentTurn].isAI,
                openEnds = game.openEnds
            })
        end
    end
    
    UpdateTablePlayers(tableId)
    
    if game.players[game.currentTurn].isAI then
        ProcessAITurn(tableId)
    end
end



function ProcessAITurn(tableId, attempts)
    attempts = attempts or 0
    attempts = attempts + 1
    
   
    if attempts > 20 then
       
        local game = ActiveGames[tableId]
        if game and game.started then
            NextTurn(tableId)
        end
        return
    end
    
    local game = ActiveGames[tableId]
    if not game or not game.started then 
        
        return 
    end
    
    local ai = game.players[game.currentTurn]
    if not ai or not ai.isAI then 
        
        return 
    end
    
    local aiId = ai.id
    local aiName = ai.name
    
  
    
    SetTimeout(math.random(800, 1500), function()
        -- Re-verify game state
        local g = ActiveGames[tableId]
        if not g or not g.started then 
           
            return 
        end
        
        -- Verify it's still this AI's turn
        local currentPlayer = g.players[g.currentTurn]
        if not currentPlayer or currentPlayer.id ~= aiId then
          
            return
        end
        
        local currentAI = currentPlayer
        
        -- Find best move
        local bestMove = nil
        local bestScore = -1
        
        for i, tile in ipairs(currentAI.tiles) do
            local moves = GetValidMoves(g, tile)
            if moves and #moves > 0 then
                for _, move in ipairs(moves) do
                    local score = tile.left + tile.right
                    if tile.left == tile.right then 
                        score = score + 10 
                    end
                    if score > bestScore then
                        bestScore = score
                        bestMove = {tileIdx = i, tile = tile, endId = move.id}
                    end
                end
            end
        end
        
        if bestMove then
            
           
            
            local tileToPlay = table.remove(currentAI.tiles, bestMove.tileIdx)
            
            local success = false
            if #g.board == 0 then
                success = InitializeBoard(g, tileToPlay)
            else
                success = PlaceTile(g, tileToPlay, bestMove.endId)
            end
            
            if not success then
                
                table.insert(currentAI.tiles, tileToPlay)
                NextTurn(tableId)
                return
            end
            
            
            for _, p in ipairs(g.players) do
                if p.isHuman then
                    TriggerClientEvent('rsg-dominos:client:updateGame', p.id, {
                        board = g.board,
                        openEnds = g.openEnds,
                        spinner = g.spinner,
                        boneyardCount = #g.boneyard,
                        lastMove = {
                            player = aiName,
                            tile = bestMove.tile,
                            isAI = true
                        }
                    })
                end
            end
            
            UpdateTablePlayers(tableId)
            
          
            if #currentAI.tiles == 0 then
                
                EndRound(tableId, g.currentTurn)
            else
                NextTurn(tableId)
            end
            
        elseif #g.boneyard > 0 then
            
            local drawnTile = table.remove(g.boneyard, 1)
            table.insert(currentAI.tiles, drawnTile)
            
           
            
            BroadcastBoneyardUpdate(tableId)
            UpdateTablePlayers(tableId)
            
           
            SetTimeout(500, function() 
                ProcessAITurn(tableId, attempts) 
            end)
            
        else
            
            NextTurn(tableId)
        end
    end)
end



function EndRound(tableId, winnerId)
    local game = ActiveGames[tableId]
    if not game then return end
    
    local winner = game.players[winnerId]
    
   
    
   
    if winner.isHuman then
        local Player = RSGCore.Functions.GetPlayer(winner.id)
        if Player then 
            Player.Functions.AddMoney('cash', game.pot, 'dominos-win')
           
        end
    else
       
    end
    
    
    local scores = {}
    for _, p in ipairs(game.players) do
        local pts = 0
        for _, t in ipairs(p.tiles) do 
            pts = pts + t.left + t.right 
        end
        table.insert(scores, {
            name = p.name, 
            score = pts, 
            isAI = p.isAI,
            isWinner = (p.id == winner.id)
        })
    end
    
    
    local humanPlayers = {}
    for _, p in ipairs(game.players) do
        if p.isHuman then
            table.insert(humanPlayers, p.id)
        end
    end
    
    
    for _, playerId in ipairs(humanPlayers) do
        TriggerClientEvent('rsg-dominos:client:gameEnd', playerId, {
            winner = winner.name,
            pot = game.pot,
            isAIWinner = winner.isAI,
            scores = scores
        })
    end
    
    SetTimeout(500, function()
        for _, playerId in ipairs(humanPlayers) do
            PlayerGames[playerId] = nil
        end
        
       
        ResetGame(tableId)
       
    end)
end


function EndGame(tableId, winner)
    
    local game = ActiveGames[tableId]
    if not game then return end
    
    local winnerId = 1
    for i, p in ipairs(game.players) do
        if p.id == winner.id then
            winnerId = i
            break
        end
    end
    
    EndRound(tableId, winnerId)
end

-- ==================== HELPERS ====================

function ResetGame(tableId)
    ActiveGames[tableId] = CreateNewGame(tableId)
end

function UpdateTablePlayers(tableId)
    local game = ActiveGames[tableId]
    if not game then return end
    
    local info = GetPlayerInfo(game)
    for _, p in ipairs(game.players) do
        if p.isHuman then
            TriggerClientEvent('rsg-dominos:client:updatePlayers', p.id, info)
        end
    end
end

function GetPlayerInfo(game)
    local info = {}
    for _, p in ipairs(game.players) do
        table.insert(info, {
            name = p.name,
            score = p.score or 0,
            ready = p.ready,
            tileCount = #p.tiles,
            isAI = p.isAI
        })
    end
    return info
end

function GetScores(game)
    local scores = {}
    for _, p in ipairs(game.players) do
        table.insert(scores, {name = p.name, score = p.score or 0, isAI = p.isAI})
    end
    return scores
end

-- ==================== CLEANUP ====================

AddEventHandler('playerDropped', function()
    local src = source
    local tableId = PlayerGames[src]
    if tableId and ActiveGames[tableId] then
        local game = ActiveGames[tableId]
        for i, p in ipairs(game.players) do
            if p.id == src then table.remove(game.players, i) break end
        end
        
        local hasHumans = false
        for _, p in ipairs(game.players) do
            if p.isHuman then hasHumans = true break end
        end
        
        if not hasHumans then ResetGame(tableId)
        else UpdateTablePlayers(tableId) end
    end
    PlayerGames[src] = nil
end)

print("^2[Dominos] ^7Server loaded!")
