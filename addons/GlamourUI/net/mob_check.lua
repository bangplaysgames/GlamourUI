--[[
    /check (0x29 message basic) parsing — mob level for target bar and chat log.
    Based on Ashita checker addon layout (message at 0x18, target index at 0x16).
]]

local M = {};

M.CHECK_CONDITIONS = {
    [0xAA] = 'High Evasion, High Defense',
    [0xAB] = 'High Evasion',
    [0xAC] = 'High Evasion, Low Defense',
    [0xAD] = 'High Defense',
    [0xAE] = '',
    [0xAF] = 'Low Defense',
    [0xB0] = 'Low Evasion, High Defense',
    [0xB1] = 'Low Evasion',
    [0xB2] = 'Low Evasion, Low Defense',
};

M.CHECK_TYPES = {
    [0x40] = 'too weak to be worthwhile',
    [0x41] = 'like incredibly easy prey',
    [0x42] = 'like easy prey',
    [0x43] = 'like a decent challenge',
    [0x44] = 'like an even match',
    [0x45] = 'tough',
    [0x46] = 'very tough',
    [0x47] = 'incredibly tough',
};

local MOB_NAME_COLOR_CODE = 0x44;
local NM_NAME_COLOR_CODE = 0x52;
local MOB_NAME_RGBA = { 1.0, 0.35, 0.35, 1.0 };
local NM_NAME_RGBA = { 1.0, 0.82, 0.20, 1.0 };

local DIFF_GREEN = { 0.25, 0.90, 0.30, 1.0 };
local DIFF_RED = { 1.0, 0.28, 0.28, 1.0 };
local COND_GREEN = { 0.25, 0.90, 0.30, 1.0 };
local COND_RED = { 1.0, 0.28, 0.28, 1.0 };
local TOO_WEAK_FILL = { 0.18, 0.18, 0.18, 1.0 };
local TOO_WEAK_GLOW = { 1.0, 1.0, 1.0, 1.0 };

local CONDITION_SCORE = {
    [0xAA] = 1.00,
    [0xAB] = 0.85,
    [0xAC] = 0.55,
    [0xAD] = 0.85,
    [0xAE] = 0.50,
    [0xAF] = 0.15,
    [0xB0] = 0.55,
    [0xB1] = 0.15,
    [0xB2] = 0.00,
};

local function lerp_rgba(a, b, t)
    t = math.max(0, math.min(1, tonumber(t) or 0));
    return {
        (a[1] or 1) + ((b[1] or 1) - (a[1] or 1)) * t,
        (a[2] or 1) + ((b[2] or 1) - (a[2] or 1)) * t,
        (a[3] or 1) + ((b[3] or 1) - (a[3] or 1)) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    };
end

function M.difficulty_color(checkType, bodyColor)
    local ct = tonumber(checkType) or 0;
    if (ct == 0x40) then
        return TOO_WEAK_FILL, true;
    end
    if (ct < 0x41 or ct > 0x47) then
        return bodyColor or { 0.92, 0.92, 0.88, 1.0 }, false;
    end
    local t = (ct - 0x41) / 6;
    return lerp_rgba(DIFF_GREEN, DIFF_RED, t), false;
end

function M.condition_color(messageId, bodyColor)
    local score = CONDITION_SCORE[tonumber(messageId) or 0];
    if (score == nil) then
        return bodyColor or { 0.92, 0.92, 0.88, 1.0 };
    end
    return lerp_rgba(COND_GREEN, COND_RED, score);
end

local function append_segment(segments, text, color, opts)
    if (text == nil or text == '') then
        return;
    end
    segments[#segments + 1] = {
        text = text,
        color = color,
        atomic = opts and opts.atomic or false,
        parts = opts and opts.parts or nil,
    };
end

local function build_type_segment(segments, typeText, checkType, bodyColor)
    if (typeText == nil or typeText == '') then
        return;
    end
    local diffColor, outlined = M.difficulty_color(checkType, bodyColor);
    if (outlined) then
        append_segment(segments, typeText, diffColor, {
            atomic = true,
            parts = T{
                {
                    draw = 'check_outlined',
                    text = typeText,
                    color = diffColor,
                    glowColor = TOO_WEAK_GLOW,
                },
            },
        });
        return;
    end
    append_segment(segments, typeText, diffColor);
end

local function packet_injection_enabled()
    return GlamourUI ~= nil
        and GlamourUI.settings ~= nil
        and GlamourUI.settings.packet_injection_enabled == true;
end

local function ffxi_color_reset()
    return string.char(0x1E, 0x01);
end

local function ffxi_color_code(codeByte)
    return string.char(0x1E, codeByte);
end

function M.is_check_message(messageId, checkType)
    local m = tonumber(messageId) or 0;
    if (m == 0xF9) then
        return true;
    end
    local p2 = tonumber(checkType) or 0;
    return M.CHECK_CONDITIONS[m] ~= nil and M.CHECK_TYPES[p2] ~= nil;
end

function M.should_block_native(messageId, checkType)
    return M.is_check_message(messageId, checkType);
end

function M.is_notorious(entity, messageId)
    if (tonumber(messageId) == 0xF9) then
        return true;
    end
    if (entity == nil) then
        return false;
    end
    local spawnFlags = tonumber(entity.SpawnFlags) or 0;
    if (bit.band(spawnFlags, 0x10) == 0x10 and bit.band(spawnFlags, 0x20) == 0x20) then
        return true;
    end
    return false;
end

function M.parse_0x29(e)
    if (e == nil or e.data == nil or #e.data < 0x18 + 1) then
        return nil;
    end
    local d = e.data;
    return {
        targetIndex = struct.unpack('H', d, 0x16 + 1),
        level = struct.unpack('l', d, 0x0C + 1),
        checkType = struct.unpack('l', d, 0x10 + 1),
        messageId = struct.unpack('H', d, 0x18 + 1),
    };
end

function M.resolve_level(targetIndex, levelParam)
    local p1 = tonumber(levelParam) or 0;
    if (p1 > 0 and p1 < 200) then
        return p1;
    end
    if (gPacket ~= nil and gPacket.CharInfo ~= nil) then
        local cached = gPacket.CharInfo[targetIndex];
        if (cached ~= nil and cached.Level ~= nil) then
            local lv = tonumber(cached.Level);
            if (lv ~= nil and lv > 0) then
                return lv;
            end
        end
    end
    if (packet_injection_enabled() and gPacket ~= nil and gPacket.CharInfo ~= nil) then
        local ws = gPacket.CharInfo[targetIndex];
        if (ws ~= nil and ws.Level ~= nil) then
            local lv = tonumber(ws.Level);
            if (lv ~= nil and lv > 0) then
                return lv;
            end
        end
    end
    return nil;
end

function M.clear_char_info()
    if (gPacket ~= nil) then
        gPacket.CharInfo = {};
        if (gPacket.ClearWidescanPending ~= nil) then
            gPacket.ClearWidescanPending();
        end
    end
end

function M.purge_target_index(targetIndex)
    if (gPacket == nil or gPacket.CharInfo == nil or targetIndex == nil or targetIndex == 0) then
        return;
    end
    gPacket.CharInfo[targetIndex] = nil;
end

function M.purge_server_id(serverId)
    if (gPacket == nil or gPacket.CharInfo == nil or serverId == nil or serverId == 0) then
        return;
    end
    for idx, info in pairs(gPacket.CharInfo) do
        if (info ~= nil and info.ServerId == serverId) then
            gPacket.CharInfo[idx] = nil;
        end
    end
end

function M.ingest_check(targetIndex, entity, messageId, levelParam, checkType)
    if (targetIndex == nil or targetIndex == 0) then
        return;
    end
    if (not M.is_check_message(messageId, checkType)) then
        return;
    end

    if (gPacket == nil) then
        return;
    end
    if (gPacket.CharInfo == nil) then
        gPacket.CharInfo = {};
    end

    local info = gPacket.CharInfo[targetIndex];
    if (info == nil) then
        info = {};
        gPacket.CharInfo[targetIndex] = info;
    end

    info.Type = 2;
    info.CheckMessage = tonumber(messageId);
    info.CheckType = tonumber(checkType);
    info.CheckCondition = M.CHECK_CONDITIONS[info.CheckMessage];
    info.CheckTypeText = M.CHECK_TYPES[info.CheckType];
    info.ImpossibleGauge = (info.CheckMessage == 0xF9);
    info.IsNotorious = M.is_notorious(entity, messageId);

    if (entity ~= nil) then
        if (entity.Name ~= nil and entity.Name ~= '') then
            info.Name = entity.Name;
        end
        if (entity.ServerId ~= nil and entity.ServerId ~= 0) then
            info.ServerId = entity.ServerId;
        end
    end

    if (info.ImpossibleGauge == true) then
        info.Level = nil;
        return;
    end

    local lv = M.resolve_level(targetIndex, levelParam);
    if (lv ~= nil) then
        info.Level = lv;
    end
end

function M.build_chat_display(entity, messageId, levelParam, checkType, targetIndex, bodyColor)
    bodyColor = bodyColor or { 0.92, 0.92, 0.88, 1.0 };
    local m = tonumber(messageId) or 0;
    local name = tostring((entity ~= nil and entity.Name ~= nil and entity.Name ~= '') and entity.Name or 'Unknown');
    local isNm = M.is_notorious(entity, messageId);
    local nameColor = isNm and NM_NAME_RGBA or MOB_NAME_RGBA;
    local nameCode = isNm and NM_NAME_COLOR_CODE or MOB_NAME_COLOR_CODE;

    if (m == 0xF9) then
        local tail = ' — Impossible to gauge!';
        local plain = name .. tail;
        local raw = ffxi_color_code(nameCode) .. name .. ffxi_color_reset() .. tail;
        local segments = {
            { text = name, color = nameColor },
            { text = tail, color = bodyColor },
        };
        return plain, raw, segments;
    end

    if (not M.is_check_message(m, checkType)) then
        return nil, nil, nil;
    end

    local lv = M.resolve_level(targetIndex, levelParam);
    local lvText = (lv ~= nil and lv > 0) and tostring(lv) or '???';
    local typeText = M.CHECK_TYPES[tonumber(checkType) or 0] or '';
    local condText = M.CHECK_CONDITIONS[m] or '';
    local condColor = M.condition_color(m, bodyColor);

    local segments = {};
    append_segment(segments, name, nameColor);
    append_segment(segments, (' (Lv. %s)'):fmt(lvText), bodyColor);
    if (typeText ~= '') then
        append_segment(segments, ' ', bodyColor);
        build_type_segment(segments, typeText, checkType, bodyColor);
    end
    if (condText ~= nil and condText ~= '') then
        append_segment(segments, ' ', bodyColor);
        append_segment(segments, ('(%s)'):fmt(condText), condColor);
    end

    local plainParts = T{ name, (' (Lv. %s)'):fmt(lvText) };
    if (typeText ~= '') then
        plainParts:append(typeText);
    end
    if (condText ~= nil and condText ~= '') then
        plainParts:append(('(%s)'):fmt(condText));
    end
    local plain = plainParts:concat(' ');
    local raw = ffxi_color_code(nameCode) .. name .. ffxi_color_reset() .. plain:sub(#name + 1);
    return plain, raw, segments;
end

function M.format_chat_line(entityName, messageId, levelParam, checkType, targetIndex)
    local entity = nil;
    if (targetIndex ~= nil and targetIndex ~= 0) then
        entity = GetEntity(targetIndex);
    end
    if (entity == nil and entityName ~= nil) then
        entity = { Name = entityName };
    end
    local plain, _raw, _segments = M.build_chat_display(entity, messageId, levelParam, checkType, targetIndex, { 0.92, 0.92, 0.88, 1.0 });
    return plain;
end

function M.try_handle_packet_in(e)
    local parsed = M.parse_0x29(e);
    if (parsed == nil) then
        return false, nil;
    end
    if (not M.should_block_native(parsed.messageId, parsed.checkType)) then
        return false, nil;
    end

    local entity = GetEntity(parsed.targetIndex);
    M.ingest_check(parsed.targetIndex, entity, parsed.messageId, parsed.level, parsed.checkType);

    local plain = M.format_chat_line(
        (entity ~= nil and entity.Name) or 'Unknown',
        parsed.messageId,
        parsed.level,
        parsed.checkType,
        parsed.targetIndex
    );
    return true, plain;
end

return M;
