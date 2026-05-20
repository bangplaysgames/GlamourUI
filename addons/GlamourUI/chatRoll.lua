--[[
    Corsair roll parsing, enrichment, deduplication, and display logic.
    All roll state and helpers live here; chatlog.lua wires up the color
    callback via M.init() and delegates to these functions at runtime.
]]

local rollData = require('roll_data');

local M = {};

local getPurposeColor = function(_) return { 1.0, 1.0, 1.0, 1.0 }; end;

function M.init(colorFn)
    if (colorFn ~= nil) then
        getPurposeColor = colorFn;
    end
end

local recentRollEvent = {};
M.recentRollEvent = recentRollEvent;

function M.prune_roll_events(now)
    local rollStale = 45.0;
    for name, ev in pairs(recentRollEvent) do
        if (ev == nil or ev.time == nil or (now - ev.time) > rollStale) then
            recentRollEvent[name] = nil;
        end
    end
end

local function normalize_roll_name(name)
    if (name == nil) then
        return nil;
    end
    name = tostring(name);
    name = name:gsub('^%s+', ''):gsub('%s+$', '');
    name = name:gsub('^Bust!%s*', '');
    name = name:gsub('%s+', ' ');
    return name;
end
M.normalize_roll_name = normalize_roll_name;

local FF_ARROW = string.char(129, 168);

local function try_parse_add_effect_roll_line(msg)
    if (msg == nil) then
        return nil;
    end
    local fixed = msg
        :gsub(FF_ARROW, '→')
        :gsub('çŤăť', '→')
        :gsub('â', '→')
        :gsub('竊・', '→');

    local roller, rollNum, rollName, rest = fixed:match('^%[([^%]]+)%]%s+(%d+)%s+([^%[]- Roll)%s*→%s*(.+)$');
    if (roller == nil or rollNum == nil or rollName == nil) then
        return nil;
    end
    return {
        roller = roller,
        rollName = normalize_roll_name(rollName),
        roll = tonumber(rollNum),
        rest = rest,
    };
end

local function color_for_roll_number(rollName, roll)
    if (roll == nil) then
        return { 1.0, 1.0, 1.0, 1.0 };
    end
    if (roll == 11) then
        return { 0.95, 0.78, 0.20, 1.0 }; -- gold
    end
    local data = rollData and rollData.corsair_roll_data and rollData.corsair_roll_data[rollName];
    if (data ~= nil) then
        if (roll == data.lucky) then
            return { 0.20, 0.95, 0.20, 1.0 }; -- green
        end
        if (roll == data.unlucky) then
            return { 0.95, 0.20, 0.20, 1.0 }; -- red
        end
    end
    return { 1.0, 1.0, 1.0, 1.0 }; -- white
end

function M.enrich_add_effect_roll_message(msg)
    local parsed = try_parse_add_effect_roll_line(msg);
    if (parsed == nil) then
        return nil;
    end

    local now = os.clock();
    recentRollEvent[parsed.rollName] = { time = now, bust = false };
    local data = rollData and rollData.corsair_roll_data and rollData.corsair_roll_data[parsed.rollName];
    local lucky = data and data.lucky or nil;
    local unlucky = data and data.unlucky or nil;

    local extra = '';
    if (lucky ~= nil and unlucky ~= nil) then
        extra = extra .. (' (Lucky %d / Unlucky %d)'):fmt(lucky, unlucky);
    end
    if (data ~= nil and data.rolls ~= nil and parsed.roll ~= nil and parsed.roll >= 1 and parsed.roll <= 11) then
        local amt = data.rolls[parsed.roll];
        if (amt ~= nil) then
            local unit = data.unit or '';
            local desc = data.desc or '';
            if (desc ~= '') then
                extra = extra .. string.format(' (+%s%s %s)', tostring(amt), tostring(unit), desc);
            else
                extra = extra .. string.format(' (+%s%s)', tostring(amt), tostring(unit));
            end
        end
    end

    local fixedRest = (parsed.rest or '')
        :gsub(FF_ARROW, '→')
        :gsub('çŤăť', '→')
        :gsub('â', '→')
        :gsub('竊・', '→');
    local newMsg = ('[%s] %d %s → %s%s'):fmt(parsed.roller, parsed.roll or 0, parsed.rollName, fixedRest, extra);

    local defaultColor = getPurposeColor('Add Effect');
    local rollColor = color_for_roll_number(parsed.rollName, parsed.roll);
    local isBust = (tonumber(parsed.roll) ~= nil and tonumber(parsed.roll) > 11);
    local segments = T{
        { text = ('[' .. parsed.roller .. '] '), color = defaultColor, lockedColor = true },
        {
            atomic = true,
            parts = T{
                isBust
                    and { draw = 'bust_x', color = { 0.95, 0.20, 0.20, 1.0 }, size_scale = 1.15, width_em = 1.25 }
                    or { draw = 'roll_badge', roll = tonumber(parsed.roll), color = rollColor, size_scale = 1.10, width_em = 1.35 },
            },
            text = tostring(parsed.roll or ''),
            color = rollColor,
            lockedColor = true,
        },
        { text = (' ' .. parsed.rollName .. ' → ' .. fixedRest .. extra), color = defaultColor, lockedColor = true },
    };

    return newMsg, segments;
end

local function try_parse_bust_roll_line(msg)
    if (msg == nil or msg == '') then
        return nil;
    end
    local fixed = tostring(msg)
        :gsub(FF_ARROW, '→')
        :gsub('çŤăť', '→')
        :gsub('â', '→')
        :gsub('竊・', '→');

    local roller, rollName, rest = fixed:match('^%[([^%]]+)%]%s*Bust!%s+([^%[]- Roll)%s*→%s*(.+)$');
    if (roller == nil or rollName == nil or rest == nil) then
        return nil;
    end
    return roller, normalize_roll_name(rollName), rest;
end

function M.enrich_bust_roll_message(msg)
    if (msg == nil or msg == '') then
        return nil;
    end
    local roller, rollName, rest = try_parse_bust_roll_line(msg);
    if (roller == nil or rollName == nil or rest == nil) then
        return nil;
    end

    local now = os.clock();
    if (rollName ~= nil) then
        recentRollEvent[rollName] = { time = now, bust = true };
    end

    local defaultColor = getPurposeColor('Add Effect');
    local bustColor = { 0.95, 0.20, 0.20, 1.0 };

    local newMsg = ('[%s] Bust! %s → %s'):fmt(roller, rollName or 'Roll', rest);
    local segments = T{
        { text = ('[' .. roller .. '] '), color = defaultColor, lockedColor = true },
        {
            atomic = true,
            parts = T{
                { draw = 'bust_x', color = bustColor, size_scale = 1.15, width_em = 1.25 },
            },
            text = 'X',
            color = bustColor,
            lockedColor = true,
        },
        { text = (' Bust! ' .. (rollName or 'Roll') .. ' → ' .. rest), color = defaultColor, lockedColor = true },
    };

    return newMsg, segments, rollName;
end

function M.combat_special_is_allowed_roll_line(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    local m = tostring(msg);
    if (m:find('Bust!', 1, true)) then
        return true;
    end
    if (m:find('Roll', 1, true) ~= nil and m:find('→', 1, true) ~= nil) then
        return true;
    end
    return false;
end

function M.message_looks_like_corsair_roll(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    if (M.combat_special_is_allowed_roll_line(msg)) then
        return true;
    end
    if (try_parse_add_effect_roll_line(msg) ~= nil) then
        return true;
    end
    if (try_parse_bust_roll_line(msg) ~= nil) then
        return true;
    end
    return false;
end

M.try_parse_add_effect_roll_line = try_parse_add_effect_roll_line;

return M;
