--[[This file is entirely written by at0mos.  It has be slightly modified to fit the intent of GlamourUI.  I take no credit for any of the functionality of this file.
The original addon this file was written for can be found in #v4-beta-plugins in the Ashita Discord server.  The contents of this file are subject to the same license
used by at0mos as the original creator.]]

require('common');
local chat = require('chat');

-- Addon Variables
local hideparty = {
    show = 1,
    ptrs = {
        party0 = 0,
        party1 = 0,
        party2 = 0,
    },
};

local hide = {}

--[[
* Sets a game primitives visibility.
*
* @param {number} p - The pointer of the primitive object.
* @param {boolean} v - The visibility status to set.
--]]
local function set_primitive_visibility(p, v)
    local ptr = ashita.memory.read_uint32(p);
    if (ptr ~= 0) then
        ptr = ashita.memory.read_uint32(ptr + 0x08);
        if (ptr ~= 0) then
            ashita.memory.write_uint8(ptr + 0x69, v);
            ashita.memory.write_uint8(ptr + 0x6A, v);
        end
    end
end

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
hide.Load = function()
    -- Find the needed pointers for the main party and target frames..
    local ptr1 = ashita.memory.find('FFXiMain.dll', 0, '66C78182000000????C7818C000000????????C781900000', 0, 0);
    if (ptr1 == 0) then
        error(chat.header(addon.name):append(chat.error('Error: Failed to locate required pointer. (1)')));
    end

    -- Find the needed pointers for the alliance party frames..
    local ptr2 = ashita.memory.find('FFXiMain.dll', 0, 'A1????????8B0D????????89442424A1????????33DB89', 0, 0);
    if (ptr2 == 0) then
        error(chat.header(addon.name):append(chat.error('Error: Failed to locate required pointer. (2)')));
    end

    -- Read the base object pointers..
    hideparty.ptrs.party0 = ashita.memory.read_uint32(ptr1 + 0x19);
    hideparty.ptrs.party1 = ashita.memory.read_uint32(ptr2 + 0x01);
    hideparty.ptrs.party2 = ashita.memory.read_uint32(ptr2 + 0x07);

    set_primitive_visibility(hideparty.ptrs.party0, 1);
end



--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
hide.HideParty = function(setting)
    if(setting == true)then
        set_primitive_visibility(hideparty.ptrs.party0, 0);
        set_primitive_visibility(hideparty.ptrs.party1, 0);
        set_primitive_visibility(hideparty.ptrs.party2, 0);
    else
        set_primitive_visibility(hideparty.ptrs.party0, 1);
        set_primitive_visibility(hideparty.ptrs.party1, 1);
        set_primitive_visibility(hideparty.ptrs.party2, 1);
    end
end

return hide;