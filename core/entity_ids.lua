require('common');

local M = {};

local MOB_INDEX_MASK = 0x7FF;
local NPC_INDEX_MASK = 0x0FFF;

local function high_type_byte(serverId)
    return bit.band(bit.rshift(tonumber(serverId) or 0, 24), 0xFF);
end

function M.infer_entity_kind(serverId)
    local hi = high_type_byte(serverId);
    if (hi == 0x10) then
        return 'mob';
    end
    if (hi == 0x01) then
        return 'npc';
    end
    return nil;
end

function M.get_filter_id(serverId, entityKind)
    local sid = tonumber(serverId) or 0;
    if (sid == 0) then
        return 0;
    end

    entityKind = entityKind and tostring(entityKind):lower() or nil;
    if (entityKind == 'mob') then
        return bit.band(sid, MOB_INDEX_MASK);
    end
    if (entityKind == 'npc' or entityKind == 'player') then
        return bit.band(sid, NPC_INDEX_MASK);
    end

    if (high_type_byte(sid) == 0x10) then
        return bit.band(sid, MOB_INDEX_MASK);
    end

    return bit.band(sid, NPC_INDEX_MASK);
end

function M.parse_filter_token(token)
    if (token == nil) then
        return nil, nil;
    end

    token = tostring(token);

    local hex = token:match('^0[xX]([%da-fA-F]+)$');
    if (hex ~= nil) then
        return 'id', tonumber(hex, 16);
    end

    if (token:match('^[%da-fA-F]+$') ~= nil) then
        return 'id', tonumber(token, 16);
    end

    if (token:match('^%d+$') ~= nil) then
        return 'id', tonumber(token);
    end

    return 'name', token;
end

function M.ids_match(entityServerId, filterId, entityKind)
    entityServerId = tonumber(entityServerId) or 0;
    filterId = tonumber(filterId) or 0;
    if (entityServerId == 0 or filterId == 0) then
        return false;
    end

    if (entityServerId == filterId) then
        return true;
    end

    entityKind = entityKind or M.infer_entity_kind(entityServerId);
    if (M.get_filter_id(entityServerId, entityKind) == filterId) then
        return true;
    end

    return false;
end

function M.list_matches_filter_id(list, entityServerId, entityKind)
    if (list == nil) then
        return false;
    end
    for i = 1, #list do
        if (M.ids_match(entityServerId, list[i], entityKind)) then
            return true;
        end
    end
    return false;
end

return M;
