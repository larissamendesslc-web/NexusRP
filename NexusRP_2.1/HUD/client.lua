local screenWidth, screenHeight = guiGetScreenSize()
local startX, startY = 37, screenHeight - 36

local fonts = {
    dxCreateFont("assets/fonts/bold.ttf", 10),
    dxCreateFont("assets/fonts/bold.ttf", 13),
    dxCreateFont("assets/fonts/bold.ttf", 9),
}

local hudActive = false
local voice = false

-- Componentes nativos substituídos pelo desenho deste HUD. "money" fica de fora de propósito:
-- este HUD não desenha o saldo, então mantemos o componente nativo (dado real do MTA) visível.
local hiddenComponents = { "weapon", "ammo", "health", "clock", "breath", "armour", "wanted", "radar" }
local previousVisibility = {}

local function setHudComponentsHidden(hide)
    for _, component in ipairs(hiddenComponents) do
        if hide then
            if previousVisibility[component] == nil then
                previousVisibility[component] = isPlayerHudComponentVisible(component)
            end
            setPlayerHudComponentVisible(component, false)
        elseif previousVisibility[component] ~= nil then
            setPlayerHudComponentVisible(component, previousVisibility[component])
        end
    end
    if not hide then previousVisibility = {} end
end

-- Exportada: o resource LOGIN chama isto quando o jogador entra/sai da cidade (login concluído, logout, tela de auth).
function nexusHud_setActive(isActive)
    hudActive = isActive and true or false
    setHudComponentsHidden(hudActive)
end

local function draw_hud()
    if not hudActive then return end
    local alpha = 255
    dxDrawImage(screenWidth - 131, 33, 108, 101, "assets/logo.png", 0, 0, 0, tocolor(255, 255, 255, alpha))

    dxDrawImage(startX, startY, 12, 13, "assets/health.png", 0, 0, tocolor(255, 255, 255, alpha))
    dxDrawImageSection(startX, startY + 13, 12, -13 * (getElementHealth(localPlayer) / 100), 0, 0, 12, -13 * (getElementHealth(localPlayer) / 100), "assets/health.png", 0, 0, 0, tocolor(208, 46, 46, alpha))

    dxDrawImage(startX + 48, startY, 12, 14, "assets/armor.png", 0, 0, 0, tocolor(255, 255, 255, alpha))
    dxDrawImageSection(startX + 48, startY + 14, 12, -14 * (getPedArmor(localPlayer) / 100), 0, 0, 12, -14 * (getPedArmor(localPlayer) / 100), "assets/armor.png", 0, 0, 0, tocolor(93, 148, 38, alpha))

    dxDrawImage(startX + 96, startY, 12, 12, "assets/hunger.png", 0, 0, 0, tocolor(255, 255, 255, alpha))
    dxDrawImageSection(startX + 96, startY + 12, 12, -12 * ((getElementData(localPlayer, config.fome) or 100) / 100), 0, 0, 12, -12 * ((getElementData(localPlayer, config.fome) or 100) / 100), "assets/hunger.png", 0, 0, 0, tocolor(224, 157, 56, alpha))

    dxDrawImage(startX + 145, startY, 11, 14, "assets/thirst.png", 0, 0, 0, tocolor(255, 255, 255, alpha))
    dxDrawImageSection(startX + 145, startY + 14, 11, -14 * ((getElementData(localPlayer, config.sede) or 100) / 100), 0, 0, 11, -14 * ((getElementData(localPlayer, config.sede) or 100) / 100), "assets/thirst.png", 0, 0, 0, tocolor(7, 196, 237, alpha))

    dxDrawImage(startX + 193, startY, 12, 16, "assets/voice.png", 0, 0, 0, voice and tocolor(255, 255, 255, alpha) or tocolor(255, 255, 255, alpha * 0.5))

    if isPedInVehicle(localPlayer) then
        local vehicle = getPedOccupiedVehicle(localPlayer)
        if isElement(vehicle) then
            local kmh = getElementSpeed(vehicle, 1)
            local speedSweep = tonumber(kmh) < 400 and 241 * (kmh / 400) or 241

            hou_circle(startX + 235, startY - 40, 60, 60, tocolor(142, 142, 142, alpha * 0.47), 200, 241, 6)
            hou_circle(startX + 235, startY - 40, 60, 60, tocolor(255, 255, 255, alpha), 200, speedSweep, 6)

            hou_circle(startX + 265, startY - 20, 40, 40, tocolor(142, 142, 142, alpha * 0.65), 250, 216, 5)
            hou_circle(startX + 265, startY - 20, 40, 40, tocolor(224, 157, 56, alpha), 250, 216 * ((getElementData(vehicle, config.gasolina) or 100) / 100), 5)
            dxDrawText("GAS", (startX + 267) - (dxGetTextWidth("GAS", 1, fonts[1]) / 2), startY - 30, 0, 0, tocolor(255, 255, 255, alpha), 1, fonts[3])

            dxDrawText("km", (startX + 235) - (dxGetTextWidth("km", 1, fonts[1]) / 2), startY - 43, 0, 0, tocolor(255, 255, 255, alpha), 1, fonts[1])
            dxDrawText(math.floor(kmh), (startX + 235) - (dxGetTextWidth(math.floor(kmh), 1, fonts[2]) / 2), startY - 60, 0, 0, tocolor(255, 255, 255, alpha), 1, fonts[2])
        end
    end
end

addEventHandler("onClientRender", root, draw_hud)

addEventHandler("onClientPlayerVoiceStart", localPlayer, function() voice = true end)
addEventHandler("onClientPlayerVoiceStop", localPlayer, function() voice = false end)

-- Função utilitária padrão da comunidade MTA (não existe nativamente): calcula velocidade a partir da velocidade vetorial.
function getElementSpeed(theElement, unit)
    assert(isElement(theElement), "Bad argument 1 @ getElementSpeed (element expected, got " .. type(theElement) .. ")")
    local elementType = getElementType(theElement)
    assert(elementType == "player" or elementType == "ped" or elementType == "object" or elementType == "vehicle" or elementType == "projectile", "Invalid element type @ getElementSpeed (player/ped/object/vehicle/projectile expected, got " .. elementType .. ")")
    unit = unit == nil and 0 or ((not tonumber(unit)) and unit or tonumber(unit))
    local mult = (unit == 0 or unit == "m/s") and 50 or ((unit == 1 or unit == "km/h") and 180 or 111.84681456)
    return (Vector3(getElementVelocity(theElement)) * mult).length
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Se o HUD reiniciar sozinho (ex.: admin dá "restart HUD") com jogadores já dentro da cidade,
    -- pergunta ao LOGIN o estado atual em vez de esperar o próximo login/logout.
    local loginResource = getResourceFromName("LOGIN")
    if loginResource then
        local isActive = call(loginResource, "nexusHud_getState")
        if isActive then
            nexusHud_setActive(true)
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setHudComponentsHidden(false)
end)
