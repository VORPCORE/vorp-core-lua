local firstSpawn = true
local active = false
local mapTypeOnMount = Config.mapTypeOnMount
local mapTypeOnFoot = Config.mapTypeOnFoot
local enableTypeRadar = Config.enableTypeRadar
local HealthData = {}
local pvp = Config.PVP
local playerHash = GetHashKey("PLAYER")

--===================================== FUNCTIONS ======================================--
setPVP = function()

    NetworkSetFriendlyFireOption(pvp)

    if not active then
        if pvp then
            SetRelationshipBetweenGroups(5, playerHash, playerHash)
        else
            SetRelationshipBetweenGroups(1, playerHash, playerHash)
        end
    else
        SetRelationshipBetweenGroups(1, playerHash, playerHash)
    end
end

local MapCheck = function()
    local player = PlayerPedId()
    local playerOnMout = IsPedOnMount(player)
    local playerOnVeh = IsPedInAnyVehicle(player)
    if enableTypeRadar then
        if not playerOnMout and not playerOnVeh then
            SetMinimapType(mapTypeOnFoot)
        elseif playerOnMout or playerOnVeh then
            SetMinimapType(mapTypeOnMount)
        end
    end
end

local TeleportToCoords = function(coords, heading)
    local playerPedId = PlayerPedId()
    SetEntityCoords(playerPedId, coords.x, coords.y, coords.z, true, true, true, false)
    if heading then
        SetEntityHeading(playerPedId, heading)
    end
end

--====================================== PLAYERSPAWN =======================================================--
AddEventHandler('playerSpawned', function()

    TriggerServerEvent('vorp_core:instanceplayers', tonumber(GetPlayerServerId(PlayerId())) + 45557) --instance players
    Wait(2000)
    Citizen.InvokeNative(0x1E5B70E53DB661E5, 0, 0, 0, Config.Langs.Hold, Config.Langs.Load, Config.Langs.Almost) -- try to hide arthur spawning
    DisplayRadar(false) --hide HUD on player select char
    SetMinimapHideFow(false) -- hide map fog of war
    Wait(2000)
    TriggerServerEvent("vorp:playerSpawn")
    Wait(6000) -- wait to load in
    ExecuteCommand("rc") --reload char
    Wait(2000)
    ShutdownLoadingScreen()

end)

--================================ EVENTS ============================================--

RegisterNetEvent('vorp:initCharacter', function(coords, heading, isdead)
    local player = PlayerPedId()
    TeleportToCoords(coords, heading) -- teleport player to coords
    if isdead then -- is player dead
        if not Config.CombatLogDeath then
            --start loading screen
            if Config.Loadinscreen then
                Citizen.InvokeNative(0x1E5B70E53DB661E5, 0, 0, 0, Config.Langs.forcedrespawn, Config.Langs.forced,
                    Config.Langs.Almost)
            end
            TriggerServerEvent("vorp:PlayerForceRespawn")
            TriggerEvent("vorp:PlayerForceRespawn")
            ResspawnPlayer()
            Wait(Config.LoadinScreenTimer)
            ExecuteCommand("rc")
            Wait(1000)
            ShutdownLoadingScreen()
            Wait(7000)
            HealPlayer() -- fill cores
        else
            if Config.Loadinscreen then
                Citizen.InvokeNative(0x1E5B70E53DB661E5, 0, 0, 0, Config.Langs.Holddead, Config.Langs.Loaddead,
                    Config.Langs.Almost)
            end
            Wait(8000) -- this is needed to ensure the player has enough time to load in their character before it kills them. other wise they revive when the character loads in
            TriggerEvent("vorp_inventory:CloseInv")
            SetEntityHealth(player, 0, 0) -- kil player
            Wait(4000)
            ShutdownLoadingScreen()
        end
    else -- is player not dead
        ExecuteCommand("rc")
        if Config.Loadinscreen then
            Citizen.InvokeNative(0x1E5B70E53DB661E5, 0, 0, 0, Config.Langs.Hold, Config.Langs.Load, Config.Langs.Almost)
            Wait(Config.LoadinScreenTimer)
            Wait(1000)
            ShutdownLoadingScreen()
        end
        if Config.SavePlayersStatus then
            TriggerServerEvent("vorp:GetValues")
            Wait(6000)
            Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, HealthData.hInner)
            SetEntityHealth(player, HealthData.hOuter + HealthData.hInner)
            Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, HealthData.sInner)
            Citizen.InvokeNative(0x675680D089BFA21F, player, HealthData.sOuter / 1065353215 * 100)
            if Config.DisableRecharge then
                Citizen.InvokeNative(0xDE1B1907A83A1550, player, 0) --SetHealthRechargeMultiplier
            end
            HealthData = {}
        else
            HealPlayer()
        end
    end
end)

--========================================= PLAYER SPAWN AFTER SELECT CHARACTER =======================================--
RegisterNetEvent('vorp:SelectedCharacter')
AddEventHandler("vorp:SelectedCharacter", function()
    local playerId = PlayerId()
    local pedCoords = GetEntityCoords(playerId)
    local area = Citizen.InvokeNative(0x43AD8FC02B429D33, pedCoords, 10)
    firstSpawn = false
    setPVP()
    if Config.ActiveEagleEye then
        Citizen.InvokeNative(0xA63FCAD3A6FEC6D2, playerId, true)
    end
    if Config.ActiveDeadEye then
        Citizen.InvokeNative(0x95EE1DEE1DCD9070, playerId, true)
    end
    if Config.HideUi then
        TriggerEvent("vorp:showUi", false) -- hide Core UI
    else
        TriggerEvent("vorp:showUi", true)
    end
    DisplayRadar(true) -- show HUD
    SetMinimapHideFow(true) -- enable FOW
    TriggerServerEvent("vorp:chatSuggestion") --- chat add suggestion trigger
    TriggerServerEvent('vorp_core:instanceplayers', 0) -- remove instanced players
    TriggerServerEvent("vorp:SaveDate") -- Saves the date when logging in
    Wait(10000)
    if area == -512529193 then -- if player is in guarma and relogs there we call the map
        Citizen.InvokeNative(0xA657EC9DBC6CC900, 1935063277) --guarma map
        Citizen.InvokeNative(0xE8770EE02AEE45C2, 1) --guarma water
        Citizen.InvokeNative(0x74E2261D2A66849A, true)
    end
end)

RegisterNetEvent("vorp:GetHealthFromCore")
AddEventHandler("vorp:GetHealthFromCore", function(healthData)
    HealthData = healthData
end)

--================================= THREADS ============================================--

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local pped = PlayerPedId()
        DisableControlAction(0, 0x580C4473, true) -- Disable hud
        DisableControlAction(0, 0xCF8A4ECA, true) -- Disable hud
        DisableControlAction(0, 0x9CC7A1A4, true) -- disable special ability when open hud
        DisableControlAction(0, 0x1F6D95E5, true) -- diable f4 key that contains HUD

        if not firstSpawn then
            if IsControlPressed(0, 0xCEFD9220) then
                active = true
                setPVP()
                Citizen.Wait(4000)
            end

            if not IsPedOnMount(pped) and not IsPedInAnyVehicle(pped, false) and active then
                -- When you press E to get off a horse or carriage
                active = false
                setPVP()
            elseif active and IsPedOnMount(pped) or IsPedInAnyVehicle(pped, false) then
                if IsPedInAnyVehicle(pped, false) then
                    --Nothing?
                elseif GetPedInVehicleSeat(GetMount(pped), -1) == pped then
                    active = false
                    setPVP()
                end
            else
                setPVP() --Set pvp defaults
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(3000)

        if not firstSpawn then -- save players coords after char select
            MapCheck()
            local player = PlayerPedId()
            local playerCoords = GetEntityCoords(player, true, true)
            local playerHeading = GetEntityHeading(player)
            TriggerServerEvent("vorp:saveLastCoords", playerCoords, playerHeading)
        end
    end
end)

-- config this to allow other resources to use it
CreateThread(function()
    while Config.SavePlayersStatus do
        Wait(1000)
        local player = PlayerPedId()
        local innerCoreHealth = Citizen.InvokeNative(0x36731AC041289BB1, player, 0)
        local outerCoreStamina = Citizen.InvokeNative(0x22F2A386D43048A9, player)
        local innerCoreStamina = Citizen.InvokeNative(0x36731AC041289BB1, player, 1)
        local getHealth = GetEntityHealth(player)
        TriggerServerEvent("vorp:HealthCached", getHealth, innerCoreHealth, outerCoreStamina,
            innerCoreStamina)
    end
end)

-- config this to allow other resources to use it
CreateThread(function()
    while Config.SavePlayersStatus do
        local player = PlayerPedId()
        Wait(300000) -- wont be accurate as it waits for too long
        local innerCoreHealth = Citizen.InvokeNative(0x36731AC041289BB1, player, 0, Citizen.ResultAsInteger())
        local outerCoreStamina = Citizen.InvokeNative(0x22F2A386D43048A9, player)
        local innerCoreStamina = Citizen.InvokeNative(0x36731AC041289BB1, player, 1, Citizen.ResultAsInteger())
        local getHealth = GetEntityHealth(player)
        local innerHealth = tonumber(innerCoreHealth)
        local innerStamina = tonumber(innerCoreStamina)
        TriggerServerEvent("vorp:SaveHealth", getHealth, innerHealth)
        TriggerServerEvent("vorp:SaveStamina", outerCoreStamina, innerStamina)
    end
end)

-- save players hours, tx admin already has this
CreateThread(function()
    while Config.SavePlayersHours do
        Wait(1800000) -- isnt this too long ? if player leaves hours wont be accurate
        TriggerServerEvent("vorp:SaveHours")
    end
end)
