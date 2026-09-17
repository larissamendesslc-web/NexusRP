root={};resourceRoot={};localPlayer={};local handlers={};local commands={};local binds={};local frozen=false;local cursor=false;local sent=0
function addEvent()end
function addEventHandler(e,r,f)handlers[e]=f end
function emit(e,...)handlers[e](...)end
function addCommandHandler(c,f)commands[c]=f end
function bindKey(k,s,f)binds[k]=f end
function tocolor(...)return 1 end
function isPlayerHudComponentVisible()return true end
function setPlayerHudComponentVisible()end
function triggerServerEvent(e)if e=='nexusCity:finishTutorial' then sent=sent+1 end end
function isElementFrozen()return frozen end
function setElementFrozen(p,v)frozen=v end
function isCursorShowing()return cursor end
function showCursor(v)cursor=v end
function isPedDead()return false end
function isPedInVehicle()return false end
function isChatBoxInputActive()return false end
function isConsoleActive()return false end
function cancelEvent()end
function guiGetScreenSize()return 1600,900 end
function dxDrawRectangle()end
function dxDrawText()end
function getPlayerMoney()return 123456 end
function getElementHealth()return 100 end
function getPedArmor()return 0 end
function getElementPosition()return 0,0,0 end
function getElementInterior()return 1 end
function getElementDimension()return 0 end
function getZoneName()return 'Los Santos' end
function getCursorPosition()return .5,.5 end
local hudCalls={}
function getResourceFromName(name)if name=='HUD' then return 'HUD_RESOURCE' end end
function call(resource,func,arg)hudCalls[#hudCalls+1]={resource,func,arg}end
dofile('LOGIN/welcome_config.lua');dofile('LOGIN/city_client.lua')
emit('nexusCity:state',{id=7,name='Alan Silva',tutorialDone=false});assert(frozen and cursor)
assert(nexusHud_getState()==true)
local last=hudCalls[#hudCalls];assert(last[1]=='HUD_RESOURCE' and last[2]=='nexusHud_setActive' and last[3]==true)
for i=1,4 do emit('onClientRender');emit('onClientClick','left','up',1000,780)end
assert(not frozen and not cursor and sent==1)
commands.tutorial();assert(frozen);emit('onClientKey','backspace',true);assert(not frozen and not cursor and sent==2)
commands.tutorial();emit('onClientResourceStop');assert(not frozen and not cursor)
assert(nexusHud_getState()==false)
last=hudCalls[#hudCalls];assert(last[1]=='HUD_RESOURCE' and last[2]=='nexusHud_setActive' and last[3]==false)
emit('nexusCity:state',{id=7,name='Alan Silva',tutorialDone=true});assert(not frozen);emit('onClientRender')
print('PASS: render HUD/diálogo, concluir quatro etapas, Backspace, rever tutorial, liberar ao parar e sincronizar HUD externo.')
