local info = debug.getinfo(1, 'S');
local src = info.source or '';
local dir = '';
if (src:sub(1, 1) == '@') then
    dir = src:sub(2):match('^(.*[/\\])') or '';
end
package.path = dir .. 'combatParse/?.lua;' .. package.path;

local chunk, err = loadfile(dir .. 'combatParse/init.lua');
if (chunk == nil) then
    error(err or 'loadfile combatParse/init.lua failed');
end
return chunk();
