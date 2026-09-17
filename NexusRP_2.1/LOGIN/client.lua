local screenWidth, screenHeight = guiGetScreenSize()
local browser = nil
local browserReady = false
local interfaceVisible = false
local fallbackTimer = nil
local finishTimer = nil
local closeTimer = nil
local stopping = false

local downloadState = {
    receivedProgress = false,
    percentage = 0,
    downloaded = 0,
    total = 0,
    complete = false
}

local function setGameInterfaceVisible(visible)
    showChat(visible)
    setPlayerHudComponentVisible("all", visible)
    showCursor(not visible)
    guiSetInputMode(visible and "allow_binds" or "no_binds_when_editing")

    if not visible then
        setPlayerHudComponentVisible("radar", false)
    end
end

local function sendToBrowser(functionName, payload)
    if not browser or not browserReady then
        return
    end

    executeBrowserJavascript(browser, ("window.NexusAuth.%s((function(d){return Array.isArray(d)?d[0]:d;})(%s));"):format(
        functionName,
        toJSON(payload or {}, true)
    ))
end

local function formatBytes(bytes)
    if bytes >= 1024 * 1024 then
        return ("%.1f MB"):format(bytes / 1024 / 1024)
    end

    if bytes >= 1024 then
        return ("%.1f KB"):format(bytes / 1024)
    end

    return ("%d B"):format(bytes)
end

local function pushDownloadProgress()
    local status = "Preparando os sistemas do servidor..."

    if downloadState.total > 0 then
        status = ("Baixando dados e mods • %s / %s"):format(
            formatBytes(downloadState.downloaded),
            formatBytes(downloadState.total)
        )
    end

    sendToBrowser("updateProgress", {
        percentage = downloadState.percentage,
        status = status,
        real = downloadState.receivedProgress
    })
end

local function finishLoading()
    if downloadState.complete then
        return
    end

    downloadState.complete = true
    downloadState.percentage = 100
    pushDownloadProgress()
    sendToBrowser("completeLoading", {})

    if isTimer(fallbackTimer) then
        killTimer(fallbackTimer)
    end
end

local function scheduleFinish(delay)
    if downloadState.complete then
        return
    end

    if isTimer(finishTimer) then
        killTimer(finishTimer)
    end

    finishTimer = setTimer(finishLoading, delay or 650, 1)
end

local function renderBrowser()
    if browser and interfaceVisible then
        dxDrawImage(0, 0, screenWidth, screenHeight, browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function forwardCursorMove(_, _, absoluteX, absoluteY)
    if interfaceVisible and browserReady and isElement(browser) then
        injectBrowserMouseMove(browser, absoluteX, absoluteY)
    end
end

local function forwardMouseClick(button, state)
    if not interfaceVisible or not browserReady or not isElement(browser) then
        return
    end

    if button ~= "left" and button ~= "middle" and button ~= "right" then
        return
    end

    focusBrowser(browser)

    if state == "down" then
        injectBrowserMouseDown(browser, button)
    else
        injectBrowserMouseUp(browser, button)
    end
end

local function forwardMouseWheel(button, pressed)
    if not pressed or not interfaceVisible or not browserReady or not isElement(browser) then
        return
    end

    if button == "mouse_wheel_up" then
        injectBrowserMouseWheel(browser, 40, 0)
    elseif button == "mouse_wheel_down" then
        injectBrowserMouseWheel(browser, -40, 0)
    end
end

function openAuthScreen(resetLoading)
    if interfaceVisible then
        return
    end

    if resetLoading then
        downloadState.complete = true
        downloadState.percentage = 100
    end

    triggerEvent("nexusAuth:screenOpened", resourceRoot)
    interfaceVisible = true
    setGameInterfaceVisible(false)
    fadeCamera(false, 0)

    local camera = NEXUS_AUTH_CONFIG.camera
    setCameraMatrix(camera.x, camera.y, camera.z, camera.lookX, camera.lookY, camera.lookZ)
    addEventHandler("onClientRender", root, renderBrowser)

    if browser then
        return
    end

    browser = createBrowser(screenWidth, screenHeight, true, true)
    if not isElement(browser) then
        closeAuthScreen()
        outputChatBox("[NexusRP] Não foi possível abrir o navegador. Reconecte ao servidor.", 255, 90, 90)
        return
    end

    addEventHandler("onClientBrowserCreated", browser, function()
        loadBrowserURL(source, "http://mta/local/html/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", browser, function()
        browserReady = true
        focusBrowser(browser)
        sendToBrowser("configure", {
            brand = NEXUS_AUTH_CONFIG.brand,
            subtitle = NEXUS_AUTH_CONFIG.subtitle,
            accent = NEXUS_AUTH_CONFIG.accent,
            minimumAge = NEXUS_AUTH_CONFIG.minimumAge,
            maximumAge = NEXUS_AUTH_CONFIG.maximumAge
        })
        pushDownloadProgress()

        if downloadState.complete then
            sendToBrowser("completeLoading", {})
        end
    end)
end

function closeAuthScreen()
    if isTimer(closeTimer) then killTimer(closeTimer) end
    closeTimer = nil
    if not interfaceVisible and not browser then
        return
    end

    interfaceVisible = false
    browserReady = false
    removeEventHandler("onClientRender", root, renderBrowser)
    setGameInterfaceVisible(true)
    showCursor(false)
    setCameraTarget(localPlayer)
    fadeCamera(true, 1.5)
    setTransferBoxVisible(true)

    if isElement(browser) then
        destroyElement(browser)
    end

    browser = nil
    if not stopping then triggerEvent("nexusAuth:screenClosed", resourceRoot) end
end

addEventHandler("onClientTransferBoxProgressChange", root, function(downloadedSize, totalSize)
    if downloadState.complete or not totalSize or totalSize <= 0 then
        return
    end

    downloadState.receivedProgress = true
    downloadState.downloaded = downloadedSize
    downloadState.total = totalSize
    downloadState.percentage = math.min((downloadedSize / totalSize) * 100, 100)
    pushDownloadProgress()

    if downloadState.percentage >= 99.9 then
        scheduleFinish(700)
    end
end)

addEventHandler("onClientTransferBoxVisibilityChange", root, function(isVisible)
    if not isVisible and downloadState.receivedProgress and downloadState.percentage > 0 then
        scheduleFinish(700)
    end
end)

addEventHandler("onClientCursorMove", root, forwardCursorMove)
addEventHandler("onClientClick", root, forwardMouseClick)
addEventHandler("onClientKey", root, forwardMouseWheel)

addEvent("nexusAuth:submitFromBrowser", true)
addEventHandler("nexusAuth:submitFromBrowser", root, function(mode, username, password, characterName, age, sex)
    if source ~= browser or not interfaceVisible then
        outputDebugString("[LOGIN] Envio do formulário recusado: navegador inválido.", 2)
        return
    end

    outputDebugString(("[LOGIN] Enviando formulário '%s' ao servidor."):format(tostring(mode)), 3)
    triggerServerEvent(
        "nexusAuth:submit",
        localPlayer,
        mode,
        username,
        password,
        characterName,
        age,
        sex
    )
end)

addEvent("nexusAuth:result", true)
addEventHandler("nexusAuth:result", resourceRoot, function(result)
    sendToBrowser("receive", result)

    if result and result.ok and not result.registered then
        if isTimer(closeTimer) then killTimer(closeTimer) end
        closeTimer = setTimer(closeAuthScreen, 1700, 1)
    end
end)

addEvent("nexusAuth:alreadyAuthenticated", true)
addEventHandler("nexusAuth:alreadyAuthenticated", resourceRoot, function()
    closeAuthScreen()
end)

addEvent("nexusAuth:loggedOut", true)
addEventHandler("nexusAuth:loggedOut", resourceRoot, function()
    downloadState.complete = true
    downloadState.percentage = 100
    openAuthScreen(true)
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    setTransferBoxVisible(false)
    openAuthScreen(false)

    fallbackTimer = setTimer(function()
        if not downloadState.receivedProgress then
            finishLoading()
        end
    end, NEXUS_AUTH_CONFIG.noDownloadFallbackMs, 1)

    triggerServerEvent("nexusAuth:clientReady", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    stopping = true
    setTransferBoxVisible(true)
    closeAuthScreen()
end)
