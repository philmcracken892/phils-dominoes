local RSGCore = exports['rsg-core']:GetCoreObject()
local currentTable = nil
local inGame = false
local gameUI = false
local showingPrompt = false
local currentPromptText = ""

CreateThread(function()
    Wait(2000) 
    
    for _, tableData in pairs(Config.Tables) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, tableData.coords.x, tableData.coords.y, tableData.coords.z)
        
        if blip and blip ~= 0 then
            Citizen.InvokeNative(0x74F74D3207ED525C, blip, joaat("blip_mg_dominoes"), true)
            Citizen.InvokeNative(0xD38744167B2FA257, blip, 0.2)
            local blipName = CreateVarString(10, "LITERAL_STRING", "Dominos Table")
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipName)
        end
    end
end)

-- Function to get table status from server
function GetTableStatus(tableId, callback)
    RSGCore.Functions.TriggerCallback('rsg-dominos:server:getTableStatus', function(status)
        callback(status)
    end, tableId)
end

-- Check for nearby tables
CreateThread(function()
    while true do
        local wait = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearAnyTable = false
        local nearTableData = nil
        
        for _, tableData in pairs(Config.Tables) do
            local distance = #(playerCoords - tableData.coords)
            
            if distance < Config.GameSettings.joinRadius then
                wait = 0
                nearAnyTable = true
                nearTableData = tableData
                break
            end
        end
        
        if nearAnyTable and nearTableData and not currentTable and not inGame then
            -- Check table status
            GetTableStatus(nearTableData.id, function(status)
                if currentTable or inGame then return end -- Double check we haven't joined
                
                local promptText = ""
                
                if status.hasWaitingGame then
                    -- Someone is waiting for players
                    promptText = '[G] Join Game ($' .. status.currentBet .. ') - ' .. status.playerCount .. '/' .. nearTableData.maxPlayers .. ' players'
                elseif status.inProgress then
                    -- Game is in progress, can't join
                    promptText = 'Game in Progress - ' .. status.playerCount .. ' players'
                else
                    -- No game, show normal prompt
                    promptText = '[G] Play Dominos ($' .. nearTableData.minBet .. ' - $' .. nearTableData.maxBet .. ')'
                end
                
                -- Only update if text changed or not showing
                if not showingPrompt or currentPromptText ~= promptText then
                    if showingPrompt then
                        lib.hideTextUI()
                    end
                    
                    if status.inProgress then
                        -- Show different style for in-progress games
                        lib.showTextUI(promptText, {
                            icon = 'clock',
                            style = {
                                backgroundColor = '#8B0000',
                                color = 'white'
                            }
                        })
                    elseif status.hasWaitingGame then
                        -- Show join style
                        lib.showTextUI(promptText, {
                            icon = 'user-plus',
                            style = {
                                backgroundColor = '#228B22',
                                color = 'white'
                            }
                        })
                    else
                        lib.showTextUI(promptText)
                    end
                    
                    showingPrompt = true
                    currentPromptText = promptText
                end
                
                -- Handle G key press
                if IsControlJustReleased(0, 0x760A9C6F) and not status.inProgress then -- G key
                    lib.hideTextUI()
                    showingPrompt = false
                    currentPromptText = ""
                    
                    if status.hasWaitingGame then
                        -- Join existing game directly
                        OpenJoinGameMenu(nearTableData, status.currentBet, status.playerCount)
                    else
                        -- Start new game
                        OpenTableMenu(nearTableData)
                    end
                end
            end)
        elseif not nearAnyTable and showingPrompt then
            lib.hideTextUI()
            showingPrompt = false
            currentPromptText = ""
        end
        
        Wait(wait)
    end
end)

-- Menu to join an existing waiting game
function OpenJoinGameMenu(tableData, currentBet, playerCount)
    lib.registerContext({
        id = 'dominos_join_game',
        title = 'Join Dominos Game',
        options = {
            {
                title = 'Join Game',
                description = 'Bet: $' .. currentBet .. ' | Players: ' .. playerCount .. '/' .. tableData.maxPlayers,
                icon = 'user-plus',
                onSelect = function()
                    TriggerServerEvent('rsg-dominos:server:joinTable', tableData.id, currentBet, false)
                end
            },
            {
                title = 'Cancel',
                description = 'Return to game',
                icon = 'times',
                onSelect = function()
                    -- Just close menu
                end
            }
        }
    })
    lib.showContext('dominos_join_game')
end

function OpenTableMenu(tableData)
    local menuOptions = {
        {
            type = 'number',
            label = 'Bet Amount',
            description = 'Min: $' .. tableData.minBet .. ' - Max: $' .. tableData.maxBet,
            required = true,
            min = tableData.minBet,
            max = tableData.maxBet
        },
        {
            type = 'select',
            label = 'Game Mode',
            description = 'Play with real players or add AI opponents',
            options = {
                {value = 'players', label = 'Wait for Players'},
                {value = 'ai', label = 'Play with AI'}
            },
            required = true
        }
    }
    
    local input = lib.inputDialog('Dominos Table', menuOptions)
    
    if input then
        if input[2] == 'ai' then
            OpenAISetupMenu(tableData, input[1])
        else
            TriggerServerEvent('rsg-dominos:server:joinTable', tableData.id, input[1], false)
        end
    end
end

function OpenAISetupMenu(tableData, bet)
    local aiOptions = {
        {
            type = 'slider',
            label = 'Number of AI Players',
            description = 'How many AI opponents?',
            min = 1,
            max = math.min(3, tableData.maxPlayers - 1),
            default = 1
        },
        {
            type = 'select',
            label = 'AI Difficulty',
            description = 'How challenging should the AI be?',
            options = {
                {value = 'easy', label = 'Easy - Beginner AI'},
                {value = 'medium', label = 'Medium - Average AI'},
                {value = 'hard', label = 'Hard - Expert AI'}
            },
            default = 'medium'
        }
    }
    
    local aiInput = lib.inputDialog('AI Game Setup', aiOptions)
    
    if aiInput then
        TriggerServerEvent('rsg-dominos:server:joinTable', tableData.id, bet, true, aiInput[1], aiInput[2])
    end
end

RegisterNetEvent('rsg-dominos:client:joinedTable', function(tableId, playerCount)
    currentTable = tableId
    inGame = true
    lib.hideTextUI()
    showingPrompt = false
    currentPromptText = ""
    OpenDominosUI()
    
    if playerCount > 1 then
        lib.notify({
            title = 'Dominos',
            description = 'Game will start shortly...',
            type = 'info'
        })
    else
        lib.notify({
            title = 'Dominos',
            description = 'Waiting for other players to join...',
            type = 'info'
        })
    end
end)

RegisterNetEvent('rsg-dominos:client:leftTable', function()
    currentTable = nil
    inGame = false
    showingPrompt = false
    currentPromptText = ""
    CloseDominosUI()
    ClearPedTasks(PlayerPedId())
    lib.hideTextUI()
    
    lib.notify({
        title = 'Dominos',
        description = 'You left the table',
        type = 'info'
    })
end)

RegisterNetEvent('rsg-dominos:client:startGame', function(gameData)
    SendNUIMessage({
        action = 'startGame',
        data = gameData
    })
    
    lib.notify({
        title = 'Dominos',
        description = 'Game started! First player: ' .. gameData.currentPlayerName,
        type = 'success'
    })
end)

RegisterNetEvent('rsg-dominos:client:updateGame', function(updateData)
    SendNUIMessage({
        action = 'updateGame',
        data = updateData
    })
    
    if updateData.lastMove and updateData.lastMove.isAI then
        lib.notify({
            title = 'Dominos',
            description = updateData.lastMove.player .. ' played a tile',
            type = 'info',
            duration = 2000
        })
    end
end)

RegisterNetEvent('rsg-dominos:client:updatePlayers', function(players)
    SendNUIMessage({
        action = 'updatePlayers',
        data = players
    })
end)

RegisterNetEvent('rsg-dominos:client:drewTile', function(tile)
    SendNUIMessage({
        action = 'drewTile',
        data = tile
    })
end)

RegisterNetEvent('rsg-dominos:client:roundEnd', function(data)
    SendNUIMessage({
        action = 'roundEnd',
        data = data
    })
    
    local winnerText = data.winner
    if data.isAIWinner then
        winnerText = data.winner .. ' (AI)'
    end
    
    lib.notify({
        title = 'Round Over',
        description = winnerText .. ' won the round!',
        type = 'info'
    })
end)

RegisterNetEvent('rsg-dominos:client:gameEnd', function(data)
    SendNUIMessage({
        action = 'gameEnd',
        data = data
    })
    
    local winnerText = data.winner
    if data.isAIWinner then
        lib.notify({
            title = 'Game Over',
            description = winnerText .. ' (AI) won! Better luck next time!',
            type = 'error',
            duration = 5000
        })
    else
        lib.notify({
            title = 'You Won!',
            description = 'You won $' .. data.pot .. '!',
            type = 'success',
            duration = 5000
        })
    end
    
    SetTimeout(6000, function()
        if inGame then
            currentTable = nil
            inGame = false
            gameUI = false
            showingPrompt = false
            currentPromptText = ""
            SetNuiFocus(false, false)
            ClearPedTasks(PlayerPedId())
            lib.hideTextUI()
        end
    end)
end)

-- Notify waiting player when someone joins
RegisterNetEvent('rsg-dominos:client:playerJoined', function(playerName, playerCount, maxPlayers)
    lib.notify({
        title = 'Dominos',
        description = playerName .. ' joined! (' .. playerCount .. '/' .. maxPlayers .. ')',
        type = 'success'
    })
end)

function OpenDominosUI()
    gameUI = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openUI'
    })
end

function CloseDominosUI()
    gameUI = false
    inGame = false
    currentTable = nil
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeUI'
    })
    ClearPedTasks(PlayerPedId())
end

RegisterNUICallback('ready', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:playerReady')
    cb('ok')
end)

RegisterNUICallback('makeMove', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:makeMove', data.tileIndex, data.endId)
    cb('ok')
end)

RegisterNUICallback('drawTile', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:drawTile')
    cb('ok')
end)

RegisterNUICallback('leaveTable', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:leaveTable')
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:leaveTable')
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if gameUI then
            if IsControlJustReleased(0, 0x156F7119) then -- Backspace
                TriggerServerEvent('rsg-dominos:server:leaveTable')
            end
        end
    end
end)

RegisterNUICallback('passTurn', function(data, cb)
    TriggerServerEvent('rsg-dominos:server:passTurn')
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if inGame then
            TriggerServerEvent('rsg-dominos:server:leaveTable')
        end
        lib.hideTextUI()
        showingPrompt = false
        currentPromptText = ""
        SetNuiFocus(false, false)
    end
end)
