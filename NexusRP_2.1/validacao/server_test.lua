root={};resourceRoot={};local handlers={};local timers={};local db={};local tick=10000
local player={account={data={['nexus.characterName']='Alan Silva'},id=7}, x=1686,y=-2334,z=13.55,rot=0,int=0,dim=0,hp=100,armor=0,money=250,dead=false}
function addEvent() end
function addEventHandler(e,r,f) handlers[e]=f end
function emit(e,p,...) source=p;handlers[e](...) end
function isElement(p)return p==player end
function getPlayerAccount(p)return p.account end
function isGuestAccount(a)return a.guest end
function getAccountData(a,k)return a.data[k] end
function setAccountData(a,k,v)a.data[k]=v;return true end
function toJSON(d)local key=tostring(#db+1);db[#db+1]=d;return key end
function fromJSON(k)return db[tonumber(k)] end
function getElementPosition(p)return p.x,p.y,p.z end
function getElementRotation(p)return 0,0,p.rot end
function getElementInterior(p)return p.int end
function getElementDimension(p)return p.dim end
function getPlayerMoney(p)return p.money end
function getElementHealth(p)return p.hp end
function getPedArmor(p)return p.armor end
function isPedDead(p)return p.dead end
function setPlayerMoney(p,v)p.money=v end
function setElementHealth(p,v)p.hp=v end
function setPedArmor(p,v)p.armor=v end
function setElementInterior(p,v)p.int=v end
function setElementDimension(p,v)p.dim=v end
function setElementPosition(p,x,y,z)p.x,p.y,p.z=x,y,z end
function setElementRotation(p,a,b,v)p.rot=v end
function getTickCount()return tick end
function getAccountID(a)return a.id end
local last
function triggerClientEvent(p,e,r,d)last={e=e,d=d}end
function outputDebugString()end
function getElementsByType()return {player}end
function setTimer(f,ms,n)timers[#timers+1]=f end
function spawnPlayer(p,x,y,z,r,skin,int,dim)p.x,p.y,p.z,p.hp,p.dead=x,y,z,100,false end
function setCameraTarget()end
function fadeCamera()end
dofile('LOGIN/config.lua');dofile('LOGIN/welcome_config.lua');dofile('LOGIN/city_server.lua')
emit('nexusAuth:onPlayerAuthenticated',player,player.account)
client=player;emit('nexusCity:sync',player);assert(last.d.id==7 and not last.d.tutorialDone)
emit('nexusCity:finishTutorial',{});assert(not player.account.data['nexus.tutorialDone'])
emit('nexusCity:finishTutorial',player);assert(player.account.data['nexus.tutorialDone'])
player.x=120;player.y=200;player.money=456;player.hp=78;player.armor=35
emit('onPlayerQuit',player)
player.x=1686;player.money=0;player.hp=100;player.armor=0
emit('nexusAuth:onPlayerAuthenticated',player,player.account)
assert(player.x==120 and player.money==456 and player.hp==78 and player.armor==35)
tick=tick+2000;emit('nexusCity:sync',player);assert(last.d.tutorialDone)
-- Sincronização não deve teleportar nem recuperar saldo antigo novamente.
player.x=555;player.money=600;tick=tick+2000;emit('nexusCity:sync',player);assert(player.x==555 and player.money==600)
-- Logout salva na conta anterior.
local account=player.account;player.account={guest=true,data={}}
emit('onPlayerLogout',player);assert(fromJSON(account.data['nexus.cityState']).money==600)
player.account=account;emit('nexusAuth:onPlayerAuthenticated',player,account)
player.dead=true;emit('onPlayerWasted',player);timers[#timers]();assert(not player.dead and player.hp==100)
print('PASS: restauração, logout, dinheiro/vida/colete, tutorial persistente, origem inválida, sync idempotente e respawn.')
