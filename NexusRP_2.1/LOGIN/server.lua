local attempts = {}
local readyPlayers = {}
local lastSubmission = {}

addEvent("nexusAuth:onPlayerAuthenticated", false)

local function cleanText(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end

local function isValidUsername(username)
    local config = NEXUS_AUTH_CONFIG

    if #username < config.usernameMinLength or #username > config.usernameMaxLength then
        return false, ("O usuário deve ter entre %d e %d caracteres."):format(
            config.usernameMinLength,
            config.usernameMaxLength
        )
    end

    if not username:match("^[%w_.%-]+$") then
        return false, "Use apenas letras, números, ponto, hífen ou underline no usuário."
    end

    return true
end


local function isValidPassword(password)
    local config = NEXUS_AUTH_CONFIG

    if #password < config.passwordMinLength or #password > config.passwordMaxLength then
        return false, ("A senha deve ter entre %d e %d caracteres."):format(
            config.passwordMinLength,
            config.passwordMaxLength
        )
    end

    return true
end

local function isValidCharacterName(name)
    local config = NEXUS_AUTH_CONFIG

    if #name < config.characterNameMinLength or #name > config.characterNameMaxLength then
        return false, ("O nome deve ter entre %d e %d caracteres."):format(
            config.characterNameMinLength,
            config.characterNameMaxLength
        )
    end

    if name:find("[%d%c]") then
        return false, "O nome do personagem não pode conter números."
    end

    if not name:find(" ", 1, true) then
        return false, "Digite o nome e o sobrenome do personagem."
    end

    return true
end

local function characterNameExists(name)
    local key = name:lower()

    for _, account in ipairs(getAccounts()) do
        if getAccountData(account, "nexus.characterNameKey") == key then
            return true
        end
    end

    return false
end

local function getAttemptState(player)
    local state = attempts[player]

    if not state then
        state = { count = 0, blockedUntil = 0 }
        attempts[player] = state
    end

    return state
end

local function recordFailure(player)
    local state = getAttemptState(player)
    state.count = state.count + 1

    if state.count >= NEXUS_AUTH_CONFIG.maxAttempts then
        state.count = 0
        state.blockedUntil = getTickCount() + (NEXUS_AUTH_CONFIG.blockSeconds * 1000)
    end
end

local function reply(player, data)
    triggerClientEvent(player, "nexusAuth:result", resourceRoot, data)
end

local function finishAuthentication(player, account)
    local sex = getAccountData(account, "nexus.characterSex")
    local character = NEXUS_AUTH_CONFIG.characters[sex]
    local spawn = NEXUS_AUTH_CONFIG.airportSpawn
    local skin = character and character.skin or NEXUS_AUTH_CONFIG.characters.male.skin
    local characterName = getAccountData(account, "nexus.characterName")
    local characterAge = getAccountData(account, "nexus.characterAge")

    attempts[player] = nil

    setElementData(player, "character:name", characterName, true)
    setElementData(player, "character:age", characterAge, true)
    setElementData(player, "character:sex", sex, true)

    spawnPlayer(
        player,
        spawn.x,
        spawn.y,
        spawn.z,
        spawn.rotation,
        skin,
        spawn.interior,
        spawn.dimension
    )

    setElementFrozen(player, false)
    setElementAlpha(player, 255)
    setCameraTarget(player, player)
    fadeCamera(player, true, 1.5)

    triggerEvent("nexusAuth:onPlayerAuthenticated", player, account, {
        name = characterName,
        age = characterAge,
        sex = sex,
        skin = skin
    })
end

addEvent("nexusAuth:clientReady", true)
addEventHandler("nexusAuth:clientReady", root, function()
    if not client or source ~= client then
        outputDebugString("[LOGIN] clientReady recusado por origem inválida.", 2)
        return
    end

    if readyPlayers[client] then return end
    readyPlayers[client] = true
    local account = getPlayerAccount(client)

    if account and not isGuestAccount(account) then
        if getAccountData(account, "nexus.characterName") then
            triggerClientEvent(client, "nexusAuth:alreadyAuthenticated", resourceRoot)
            return
        end

        logOut(client)
    end

    setElementFrozen(client, true)
    setElementAlpha(client, 0)
end)

addEvent("nexusAuth:submit", true)
addEventHandler("nexusAuth:submit", root, function(mode, rawUsername, rawPassword, rawCharacterName, rawAge, rawSex)
    if not client or source ~= client then
        outputDebugString("[LOGIN] Formulário recusado por origem inválida.", 2)
        return
    end

    outputDebugString(("[LOGIN] Formulário '%s' recebido de %s."):format(
        tostring(mode),
        getPlayerName(client)
    ), 3)

    if mode ~= "login" and mode ~= "register" then
        return
    end

    local account = getPlayerAccount(client)
    if account and not isGuestAccount(account) then
        reply(client, { ok = false, mode = mode, message = "Você já está conectado a uma conta." })
        return
    end
    local now = getTickCount()
    if lastSubmission[client] and now - lastSubmission[client] < 1500 then
        reply(client, { ok = false, mode = mode, message = "Aguarde um instante antes de enviar novamente." })
        return
    end
    lastSubmission[client] = now
    local state = getAttemptState(client)

    if state.blockedUntil > now then
        local seconds = math.ceil((state.blockedUntil - now) / 1000)
        reply(client, {
            ok = false,
            mode = mode,
            message = ("Aguarde %d segundos para tentar novamente."):format(seconds)
        })
        return
    end

    local username = cleanText(rawUsername)
    local password = type(rawPassword) == "string" and rawPassword or ""
    local validUsername, usernameError = isValidUsername(username)
    local validPassword, passwordError = isValidPassword(password)

    if not validUsername or not validPassword then
        reply(client, {
            ok = false,
            mode = mode,
            message = usernameError or passwordError
        })
        return
    end

    if mode == "register" then
        local characterName = cleanText(rawCharacterName)
        local age = tonumber(rawAge)
        local sex = type(rawSex) == "string" and rawSex:lower() or ""
        local validName, nameError = isValidCharacterName(characterName)

        if not validName then
            reply(client, { ok = false, mode = mode, message = nameError })
            return
        end

        if not age or age % 1 ~= 0 or age < NEXUS_AUTH_CONFIG.minimumAge or age > NEXUS_AUTH_CONFIG.maximumAge then
            reply(client, {
                ok = false,
                mode = mode,
                message = ("A idade deve estar entre %d e %d anos."):format(
                    NEXUS_AUTH_CONFIG.minimumAge,
                    NEXUS_AUTH_CONFIG.maximumAge
                )
            })
            return
        end

        if not NEXUS_AUTH_CONFIG.characters[sex] then
            reply(client, { ok = false, mode = mode, message = "Escolha o personagem masculino ou feminino." })
            return
        end

        if getAccount(username) then
            recordFailure(client)
            reply(client, { ok = false, mode = mode, message = "Esse nome de usuário já está em uso." })
            return
        end

        if characterNameExists(characterName) then
            reply(client, { ok = false, mode = mode, message = "Já existe um personagem com esse nome." })
            return
        end

        local account = addAccount(username, password)

        if not account then
            recordFailure(client)
            reply(client, { ok = false, mode = mode, message = "Não foi possível criar sua conta agora." })
            return
        end

        setAccountData(account, "nexus.characterName", characterName)
        setAccountData(account, "nexus.characterNameKey", characterName:lower())
        setAccountData(account, "nexus.characterAge", age)
        setAccountData(account, "nexus.characterSex", sex)
        setAccountData(account, "nexus.characterSkin", NEXUS_AUTH_CONFIG.characters[sex].skin)
        setAccountData(account, "nexus.registeredAt", getRealTime().timestamp)

        reply(client, {
            ok = true,
            registered = true,
            mode = mode,
            username = username,
            message = "Personagem criado! Agora entre com sua conta."
        })
        return
    end

    local account = getAccount(username, password)

    if not account or not logIn(client, account, password) then
        recordFailure(client)
        reply(client, { ok = false, mode = mode, message = "Usuário ou senha incorretos." })
        return
    end

    if not getAccountData(account, "nexus.characterName") then
        logOut(client)
        reply(client, {
            ok = false,
            mode = mode,
            message = "Essa conta ainda não possui um personagem cadastrado."
        })
        return
    end

    reply(client, {
        ok = true,
        mode = mode,
        message = "Login realizado. Entrando no NexusRP..."
    })
    finishAuthentication(client, account)
end)

addEventHandler("onPlayerLogout", root, function()
    setElementFrozen(source, true)
    setElementAlpha(source, 0)
    triggerClientEvent(source, "nexusAuth:loggedOut", resourceRoot)
end)

addEventHandler("onPlayerQuit", root, function()
    attempts[source] = nil
    readyPlayers[source] = nil
    lastSubmission[source] = nil
end)

-- Se o resource for parado durante o login, não deixe jogadores invisíveis/congelados.
addEventHandler("onResourceStop", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        local account = getPlayerAccount(player)
        if not account or isGuestAccount(account) then
            setElementFrozen(player, false)
            setElementAlpha(player, 255)
        end
    end
end)
