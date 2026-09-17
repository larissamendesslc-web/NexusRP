local active, profile, guide = false, nil, nil
local page, frozenBefore, cursorBefore = nil, false, false
local buttons = {}
local hidden = { "health", "armour", "money", "clock", "area_name", "vehicle_name" }
local previousHud = {}
local white, muted, purple = tocolor(245,244,252), tocolor(170,171,190), tocolor(139,92,246)
local function hud(visible)
    for _, component in ipairs(hidden) do
        if visible then
            if previousHud[component] == nil then previousHud[component] = isPlayerHudComponentVisible(component) end
            setPlayerHudComponentVisible(component, false)
        elseif previousHud[component] ~= nil then
            setPlayerHudComponentVisible(component, previousHud[component])
        end
    end
    if not visible then previousHud = {} end
end
local function endDialog(mark, restore)
    if not page then return end
    page = nil
    buttons = {}
    if restore ~= false then
        setElementFrozen(localPlayer, frozenBefore)
        showCursor(cursorBefore)
    end
    if mark and active then
        profile.tutorialDone = true
        triggerServerEvent("nexusCity:finishTutorial", localPlayer)
    end
end
local function startDialog()
    if not active or page or isPedDead(localPlayer) or isPedInVehicle(localPlayer) then return end
    page = 1
    frozenBefore = isElementFrozen(localPlayer)
    cursorBefore = isCursorShowing()
    setElementFrozen(localPlayer, true)
    showCursor(true)
end
local function hide(restore)
    endDialog(false, restore)
    active, profile = false, nil
    hud(false)
end
local function nearGuide(distance)
    if getElementInterior(localPlayer) ~= 0 or getElementDimension(localPlayer) ~= 0 then return false end
    local x,y,z = getElementPosition(localPlayer)
    local g = NEXUS_CITY.guide
    return getDistanceBetweenPoints3D(x,y,z,g.x,g.y,g.z) <= distance
end
local function money(value)
    local s = tostring(math.floor(value))
    while true do
        local changed
        s, changed = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        if changed == 0 then break end
    end
    return "R$ " .. s
end
local function box(x,y,w,h,color) dxDrawRectangle(x,y,w,h,color) end
local function text(value,x,y,w,h,color,size,font,align,wrap)
    dxDrawText(value,x,y,x+w,y+h,color,size,font or "default",align or "left","center",true,wrap or false)
end
local function button(label,x,y,w,h,action,primary,scale)
    local cx,cy = getCursorPosition()
    local sw,sh = guiGetScreenSize()
    local hover = cx and cx*sw >= x and cx*sw <= x+w and cy*sh >= y and cy*sh <= y+h
    box(x,y,w,h,primary and (hover and tocolor(157,118,255) or purple) or (hover and tocolor(62,60,80) or tocolor(39,38,53)))
    text(label,x,y,w,h,white,scale,"default-bold","center")
    buttons[#buttons+1] = {x=x,y=y,w=w,h=h,action=action}
end
addEvent("nexusAuth:screenClosed", false)
addEventHandler("nexusAuth:screenClosed", resourceRoot, function()
    triggerServerEvent("nexusCity:sync", localPlayer)
end)
addEvent("nexusAuth:screenOpened", false)
addEventHandler("nexusAuth:screenOpened", resourceRoot, function() hide(false) end)
addEvent("nexusCity:state", true)
addEventHandler("nexusCity:state", resourceRoot, function(data)
    if type(data) ~= "table" then return end
    profile, active = data, true
    hud(true)
    if not data.tutorialDone then startDialog() end
end)
addEvent("nexusCity:hide", true)
addEventHandler("nexusCity:hide", resourceRoot, function() hide(false) end)
addCommandHandler("tutorial", startDialog)
bindKey("e", "down", function()
    if active and not page and not isCursorShowing() and not isChatBoxInputActive() and not isConsoleActive() and nearGuide(3) then startDialog() end
end)
addEventHandler("onClientKey", root, function(key, pressed)
    if page and pressed and key == "backspace" and not isChatBoxInputActive() and not isConsoleActive() then
        endDialog(true)
        cancelEvent()
    end
end)
addEventHandler("onClientClick", root, function(key,state,x,y)
    if key ~= "left" or state ~= "up" or not page then return end
    for _, b in ipairs(buttons) do
        if x >= b.x and x <= b.x+b.w and y >= b.y and y <= b.y+b.h then b.action(); break end
    end
end)
addEventHandler("onClientPlayerWasted", localPlayer, function() endDialog(false) end)
addEventHandler("onClientResourceStart", resourceRoot, function()
    local g = NEXUS_CITY.guide
    guide = createPed(g.skin,g.x,g.y,g.z,g.rotation)
    if guide then
        setElementFrozen(guide,true)
        setElementCollisionsEnabled(guide,false)
        -- ISOLAMENTO TEMPORÁRIO: setPedAnimation e onClientPedDamage removidos para testar o crash ao socar o Alex.
    end
end)
addEventHandler("onClientResourceStop", resourceRoot, function() hide(true) end)

addEventHandler("onClientRender", root, function()
    if not active then return end
    local sw,sh = guiGetScreenSize()
    local s = math.min(sw/1600,sh/900)
    local x,y,w = sw-354*s,30*s,324*s
    box(x,y,w,176*s,tocolor(17,18,29,225))
    box(x,y,4*s,176*s,purple)
    text("NEXUS",x+20*s,y+12*s,160*s,30*s,white,1.65*s,"default-bold")
    text("ROLEPLAY",x+20*s,y+40*s,160*s,20*s,muted,.9*s,"default-bold")
    text("ID "..tostring(profile.id or "—"),x+212*s,y+18*s,92*s,24*s,purple,1.1*s,"default-bold","right")
    text(tostring(profile.name or "Cidadão"),x+20*s,y+65*s,w-40*s,24*s,white,1.15*s,"default-bold")
    text(money(getPlayerMoney(localPlayer)),x+20*s,y+93*s,w-40*s,32*s,white,1.55*s,"default-bold")
    local hp = math.max(0,math.min(100,getElementHealth(localPlayer)))
    local armor = math.max(0,math.min(100,getPedArmor(localPlayer)))
    text("VIDA  "..math.floor(hp).."%",x+20*s,y+133*s,134*s,18*s,muted,.85*s,"default-bold")
    text("COLETE  "..math.floor(armor).."%",x+171*s,y+133*s,133*s,18*s,muted,.85*s,"default-bold")
    box(x+20*s,y+158*s,133*s,5*s,tocolor(50,49,65))
    box(x+20*s,y+158*s,133*s*hp/100,5*s,tocolor(78,209,155))
    box(x+171*s,y+158*s,133*s,5*s,tocolor(50,49,65))
    box(x+171*s,y+158*s,133*s*armor/100,5*s,purple)
    local px,py,pz = getElementPosition(localPlayer)
    text(getZoneName(px,py,pz),x,y+181*s,w,24*s,white,.95*s,"default","right")
    if not page and nearGuide(18) and isElement(guide) then
        local g = NEXUS_CITY.guide
        local sx,sy = getScreenFromWorldPosition(g.x,g.y,g.z+1.15)
        if sx then
            box(sx-105*s,sy-18*s,210*s,42*s,tocolor(17,18,29,220))
            text("ALEX  •  GUIA DA CIDADE",sx-100*s,sy-15*s,200*s,35*s,white,s,"default-bold","center")
        end
        if nearGuide(3) then
            box(sw/2-170*s,sh-100*s,340*s,45*s,tocolor(17,18,29,235))
            text("[ E ]  Conversar com Alex",sw/2-165*s,sh-98*s,330*s,40*s,white,1.15*s,"default-bold","center")
        end
    end
    if not page then return end
    buttons = {}
    local item = NEXUS_CITY.welcome[page]
    local dw,dh = 820*s,320*s
    local dx,dy = (sw-dw)/2,sh-dh-42*s
    box(0,0,sw,sh,tocolor(5,6,15,80))
    box(dx,dy,dw,dh,tocolor(17,18,29,248))
    box(dx,dy,5*s,dh,purple)
    text("ALEX / GUIA DA CIDADE",dx+30*s,dy+20*s,620*s,25*s,purple,1.05*s,"default-bold")
    text(string.format("%02d / %02d",page,#NEXUS_CITY.welcome),dx+690*s,dy+20*s,100*s,25*s,muted,s,"default-bold","right")
    text(item.title,dx+30*s,dy+53*s,760*s,45*s,white,1.8*s,"default-bold")
    text(item.text,dx+30*s,dy+104*s,760*s,105*s,muted,1.2*s,"default","left",true)
    text("BACKSPACE para sair  •  /tutorial para rever",dx+30*s,dy+281*s,760*s,20*s,muted,.85*s)
    button("Pular",dx+30*s,dy+225*s,120*s,43*s,function() endDialog(true) end,false,s)
    if page > 1 then button("Voltar",dx+440*s,dy+225*s,120*s,43*s,function() page=page-1 end,false,s) end
    button(page == #NEXUS_CITY.welcome and "COMEÇAR MINHA HISTÓRIA" or "CONTINUAR",dx+575*s,dy+225*s,215*s,43*s,function()
        if page == #NEXUS_CITY.welcome then endDialog(true) else page=page+1 end
    end,true,s)
end)
