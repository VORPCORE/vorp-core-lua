_whitelist = {}

local T = Translation[Lang].MessageOfSystem

function AddUserToWhitelistById(id)
    _whitelist[id].GetEntry().setStatus(true)
end

function RemoveUserFromWhitelistById(id)
    _whitelist[id].GetEntry().setStatus(false)
end

local function LoadWhitelist()
    Wait(5000)
    MySQL.query('SELECT * FROM whitelist', {}, function(result)
        if #result > 0 then
            for _, v in ipairs(result) do
                _whitelist[v.id] = Whitelist(v.id, v.identifier, v.status, v.firstconnection)
            end
        end
    end)
end

local function SetUpdateWhitelistPolicy() -- this needs a source to only get these values if player is joining
    while Config.AllowWhitelistAutoUpdate do
        Wait(3600000)                     -- this needs to be changed and saved on players drop
        _whitelist = {}
        MySQL.query("SELECT * FROM whitelist", {},
            function(result) -- why are we loading all the entries into memmory ? so we are adding to a table even players that are not playing or have been banned or whatever.
                if #result > 0 then
                    for _, v in ipairs(result) do
                        _whitelist[v.id] = Whitelist(v.id, v.identifier, v.status, v.firstconnection)
                    end
                end
            end)
    end
end

function GetSteamID(src)
    local steamId = GetPlayerIdentifierByType(src, 'steam')
    return steamId
end

function GetDiscordID(src)
    local discordIdentifier = GetPlayerIdentifierByType(src, 'discord')
    local discordId = discordIdentifier and discordIdentifier:sub(9) or ""
    return discordId
end

local function GetLicenseID(src)
    local sid = GetPlayerIdentifiers(src)[2] or false
    if (sid == false or sid:sub(1, 5) ~= "license") then
        return false
    end
    return sid
end


function GetUserId(identifier)
    for k, v in pairs(_whitelist) do
        if v.GetEntry().getIdentifier() == identifier then
            return v.GetEntry().getId()
        end
    end
end

local function InsertIntoWhitelist(identifier)
    if GetUserId(identifier) then
        return GetUserId(identifier)
    end

    MySQL.prepare.await("INSERT INTO whitelist (identifier, status, firstconnection) VALUES (?,?,?)",
        { identifier, false, true })
    local entryList = MySQL.single.await('SELECT * FROM whitelist WHERE identifier = ?', { identifier })
    _whitelist[entryList.id] = Whitelist(entryList.id, identifier, 0, true)

    return entryList.id
end

CreateThread(function()
    if not Config.Whitelist then
        return
    end
    LoadWhitelist()
    SetUpdateWhitelistPolicy()
end)

AddEventHandler("playerConnecting", function(playerName, setKickReason, deferrals)
    local _source = source
    local userEntering = false
    deferrals.defer()
    local playerWlId = nil
    local steamIdentifier = GetSteamID(_source)

    if not steamIdentifier then
        deferrals.done(T.NoSteam)
        userEntering = false
        CancelEvent()
        return
    end

    if _users[steamIdentifier] then
        deferrals.done("You have been caught trying to enter with another account")
        return CancelEvent()
    end

    --[[  if steamIdentifier and _users[steamIdentifier] and not _usersLoading[steamIdentifier] then --Save and delete
        _users[steamIdentifier].SaveUser()
        _users[steamIdentifier] = nil
    end ]]

    if Config.Whitelist then
        playerWlId = GetUserId(steamIdentifier)
        if _whitelist[playerWlId] and _whitelist[playerWlId].GetEntry().getStatus() then
            deferrals.done()
            userEntering = true
        else
            playerWlId = InsertIntoWhitelist(steamIdentifier)
            deferrals.done(T.NoInWhitelist .. playerWlId)
            setKickReason(T.NoInWhitelist .. playerWlId)
        end
    else
        userEntering = true
    end

    if userEntering then
        deferrals.update(T.LoadingUser)
        LoadUser(_source, setKickReason, deferrals, steamIdentifier, GetLicenseID(_source))
    end

    local getPlayer = GetPlayerName(_source)
    if getPlayer and Config.PrintPlayerInfoOnEnter then
        print("Player ^2" .. getPlayer .. " ^7steam: ^3" .. steamIdentifier .. "^7 Loading...")
    end
    --When player is fully connected then load!!!!
end)
