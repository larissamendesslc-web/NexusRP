-- A sessão só é criada depois de uma conta Nexus válida ser autenticada.
local sessions = {}
local syncTicks = {}

local function validAccount(player)
    if not isElement(player) then return nil end
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) and getAccountData(account, "nexus.characterName") then
        return account
    end
end

local function number(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum and value <= maximum
end

local function savedState(account)
    local raw = getAccountData(account, "nexus.cityState")
    if type(raw) ~= "string" then return nil end
    local data = fromJSON(raw)
    if type(data) ~= "table" then return nil end
    if not (number(data.x, -10000, 10000) and number(data.y, -10000, 10000)
        and number(data.z, -100, 5000) and number(data.rotation, 0, 360)
        and number(data.interior, 0, 255) and number(data.dimension, 0, 65535)) then return nil end
    return data
end

local function save(player)
    local session = sessions[player]
    if not session then return end
    -- Mantém a conta da sessão para salvar também no evento de logout.
    local x, y, z = getElementPosition(player)
    local _, _, rotation = getElementRotation(player)
    local data = {
        x = x, y = y, z = z, rotation = rotation,
        interior = getElementInterior(player), dimension = getElementDimension(player),
        money = getPlayerMoney(player), health = getElementHealth(player),
        armor = getPedArmor(player), dead = isPedDead(player)
    }
    if not setAccountData(session.account, "nexus.cityState", toJSON(data, true)) then
        outputDebugString("[NexusRP] Falha ao salvar progresso de uma conta.", 1)
    end
end

local function initialize(player, account, restore)
    if sessions[player] then return end
    sessions[player] = { account = account, done = getAccountData(account, "nexus.tutorialDone") == true }
    if not restore then return end
    local data = savedState(account)
    if not data then return end
    if number(data.money, 0, 99999999) then setPlayerMoney(player, math.floor(data.money)) end
    if not data.dead then
        setElementInterior(player, data.interior)
        setElementDimension(player, data.dimension)
        setElementPosition(player, data.x, data.y, data.z)
        setElementRotation(player, 0, 0, data.rotation)
        if number(data.health, 1, 200) then setElementHealth(player, data.health) end
        if number(data.armor, 0, 100) then setPedArmor(player, data.armor) end
    end
end

addEventHandler("nexusAuth:onPlayerAuthenticated", root, function(account)
    if validAccount(source) ~= account then return end
    initialize(source, account, true)
end)

addEvent("nexusCity:sync", true)
addEventHandler("nexusCity:sync", root, function()
    if not client or source ~= client then return end
    local account = validAccount(client)
    if not account then return end
    local now = getTickCount()
    if syncTicks[client] and now - syncTicks[client] < 1000 then return end
    syncTicks[client] = now
    initialize(client, account, false)
    triggerClientEvent(client, "nexusCity:state", resourceRoot, {
        id = getAccountID(account), name = getAccountData(account, "nexus.characterName"),
        tutorialDone = sessions[client].done
    })
end)

addEvent("nexusCity:finishTutorial", true)
addEventHandler("nexusCity:finishTutorial", root, function()
    if not client or source ~= client then return end
    local session = sessions[client]
    if not session or session.account ~= validAccount(client) or session.done then return end
    if setAccountData(session.account, "nexus.tutorialDone", true) then
        session.done = true
    end
end)

addEventHandler("onPlayerQuit", root, function()
    save(source)
    sessions[source], syncTicks[source] = nil, nil
end)
addEventHandler("onPlayerLogout", root, function()
    save(source)
    sessions[source], syncTicks[source] = nil, nil
    triggerClientEvent(source, "nexusCity:hide", resourceRoot)
end)
addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(sessions) do save(player) end
end)
addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        local account = validAccount(player)
        if account then initialize(player, account, false) end
    end
end)
setTimer(function()
    for player in pairs(sessions) do
        if isElement(player) then save(player) end
    end
end, NEXUS_CITY.autosaveMs, 0)

-- Respawn provisório até existir um sistema de hospital.
addEventHandler("onPlayerWasted", root, function()
    local player, session = source, sessions[source]
    if not session then return end
    save(player)
    setTimer(function()
        if not isElement(player) or sessions[player] ~= session or not isPedDead(player) then return end
        local spawn = NEXUS_AUTH_CONFIG.airportSpawn
        local sex = getAccountData(session.account, "nexus.characterSex")
        local character = NEXUS_AUTH_CONFIG.characters[sex] or NEXUS_AUTH_CONFIG.characters.male
        spawnPlayer(player, spawn.x, spawn.y, spawn.z, spawn.rotation, character.skin, spawn.interior, spawn.dimension)
        setCameraTarget(player, player)
        fadeCamera(player, true)
        save(player)
    end, 5000, 1)
end)
