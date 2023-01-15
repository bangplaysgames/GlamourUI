--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

--[[Most, if not all, functions in this file were written by Heals / Shirk for the purposes of StatusTimers.  Unless otherwise noted, all credit for the functions contained in this file goes to her.
StatusTimers can be found at her github:  https://github.com/Shirk/statustimers ]]--

require('common');
local bit = require('bit');





-- check if the passed server_id is valid
---@return boolean is_valid
local function valid_server_id(server_id)
    return server_id > 0 and server_id < 0x4000000;
end

local module = {};

-- return a table of status ids for a party member based on server id.
---@param server_id number the party memer or target server id to check
---@return table status_ids a list of the targets status ids or nil
module.get_member_status = function(server_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil or not valid_server_id(server_id)) then
        return nil;
    end

    -- try and find a party member with a matching server id
    for i = 0,4,1 do
        if (party:GetStatusIconsServerId(i) == server_id) then
            local icons_lo = party:GetStatusIcons(i);
            local icons_hi = party:GetStatusIconsBitMask(i);
            local status_ids = T{};

            for j = 0,31,1 do
                --[[ FIXME: lua doesn't handle 64bit return values properly..
                --   FIXME: the next lines are a workaround by Thorny that cover most but not all cases..
                --   FIXME: .. to try and retrieve the high bits of the buff id.
                --   TODO:  revesit this once atom0s adjusted the API.
                --]]
                local high_bits;
                if j < 16 then
                    high_bits = bit.lshift(bit.band(bit.rshift(icons_hi, 2* j), 3), 8);
                else
                    local buffer = math.floor(icons_hi / 0xffffffff);
                    high_bits = bit.lshift(bit.band(bit.rshift(buffer, 2 * (j - 16)), 3), 8);
                end
                local buff_id = icons_lo[j+1] + high_bits;
                if (buff_id ~= 255) then
                    status_ids[#status_ids + 1] = buff_id;
                end
            end

            if (next(status_ids)) then
                return status_ids;
            end
            break;
        end
    end
    return nil;
end

-- return the server_id of a party member by name
---@param name string the name of the party member
---@return number server_id the memeber's server_id or 0 if name is not valid
module.get_member_id_by_name = function(name)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil or name == nil or name == '') then
        return 0;
    end

    -- try and find a party member with a matching name
    for i = 1,4,1 do
        if (party:GetMemberName(i) == name) then
            return party:GetMemberServerId(i);
        end
    end
    return 0;
end




return module;