import os
from pathlib import Path
os.chdir(Path(__file__).resolve().parent.parent)
import ctypes,pathlib,xml.etree.ElementTree as ET
l=ctypes.CDLL('liblua5.4.so.0');l.luaL_newstate.restype=ctypes.c_void_p
l.luaL_openlibs.argtypes=[ctypes.c_void_p];l.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p];l.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p];l.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];l.lua_tolstring.restype=ctypes.c_char_p;l.lua_close.argtypes=[ctypes.c_void_p]
for p in [*pathlib.Path('LOGIN').glob('*.lua'),*pathlib.Path('HUD').rglob('*.lua'),*pathlib.Path('validacao').glob('*_test.lua')]:
 s=l.luaL_newstate();l.luaL_openlibs(s);r=l.luaL_loadfilex(s,str(p).encode(),None)
 if r==0 and p.parent.name=='validacao':r=l.lua_pcallk(s,0,0,0,0,None)
 assert r==0,(str(p),l.lua_tolstring(s,-1,None));l.lua_close(s)
root=ET.parse('LOGIN/meta.xml').getroot()
for e in root:
 if e.tag in ('file','script'):assert (pathlib.Path('LOGIN')/e.attrib['src']).is_file()
assert root.find('aclrequest/right').attrib=={'name':'function.addAccount','access':'true'}
hudRoot=ET.parse('HUD/meta.xml').getroot()
for e in hudRoot:
 if e.tag in ('file','script'):assert (pathlib.Path('HUD')/e.attrib['src']).is_file()
print('PASS: sintaxe Lua, manifesto, referências e permissão addAccount')
