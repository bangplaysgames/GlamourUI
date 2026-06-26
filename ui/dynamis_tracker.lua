require('common');
local struct = require('struct');

local dynamis_tracker = {};

local DYNAMIS_EXTENSION_ORIG = { 600, 600, 600, 900, 900 };
local DYNAMIS_EXTENSION_DREAM = { 600, 600, 600, 600, 1200 };

local ZONE_EXTENSIONS = {
    [134] = DYNAMIS_EXTENSION_ORIG,
    [135] = DYNAMIS_EXTENSION_ORIG,
    [185] = DYNAMIS_EXTENSION_ORIG,
    [186] = DYNAMIS_EXTENSION_ORIG,
    [187] = DYNAMIS_EXTENSION_ORIG,
    [188] = DYNAMIS_EXTENSION_ORIG,
    [39] = DYNAMIS_EXTENSION_DREAM,
    [40] = DYNAMIS_EXTENSION_DREAM,
    [41] = DYNAMIS_EXTENSION_DREAM,
    [42] = DYNAMIS_EXTENSION_DREAM,
};

local KI_RESOURCE_NAMES = {
    'crimson granules of time',
    'azure granules of time',
    'amber granules of time',
    'alabaster granules of time',
    'obsidian granules of time',
};

local OBTAINED_KI_NAMES = {
    ['Crimson granules of time'] = 1,
    ['Azure granules of time'] = 2,
    ['Amber granules of time'] = 3,
    ['Alabaster granules of time'] = 4,
    ['Obsidian granules of time'] = 5,
};

local RE_DYNA_TIME_UPDATE = 'will be expelled from Dynamis in (\\d+) (minute|minutes|second|seconds)';
local RE_OBTAINED_KI = 'Obtained key item: \x1E\x03(.*)\x1E\x01';

local DEFAULT_TIME = 3600;

local last_zone = 0;
local event_timer = 0;
local key_items = { false, false, false, false, false };
local zoning = false;
local tick_second = 0;

local function extensions_for_zone(zoneId)
    return ZONE_EXTENSIONS[tonumber(zoneId)];
end

local function key_item_id(name)
    local id = AshitaCore:GetResourceManager():GetString('keyitems.names', name, 2);
    return tonumber(id) or -1;
end

local function format_timer(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0));
    local h = math.floor(seconds / 3600);
    local m = math.floor((seconds % 3600) / 60);
    local s = seconds % 60;
    return ('%02d:%02d:%02d'):fmt(h, m, s);
end

local function sync_key_items_from_player(add_extensions)
    local mm = AshitaCore:GetMemoryManager();
    local player = mm and mm:GetPlayer();
    if (player == nil) then
        return;
    end

    local ext = extensions_for_zone(last_zone);
    for i = 1, #KI_RESOURCE_NAMES do
        local id = key_item_id(KI_RESOURCE_NAMES[i]);
        if (id >= 0) then
            local has = player:HasKeyItem(id);
            if (add_extensions == true and ext ~= nil and has and not key_items[i]) then
                event_timer = event_timer + ext[i];
            end
            key_items[i] = has;
        end
    end
end

local function update_key_items(partial)
    local ext = extensions_for_zone(last_zone);
    if (ext == nil) then
        return;
    end

    for i, v in pairs(partial) do
        if (v ~= nil) then
            if (not key_items[i] and v) then
                event_timer = event_timer + ext[i];
            end
            key_items[i] = v;
        end
    end
end

local function reset_for_zone(zoneId, reset_timer)
    zoneId = tonumber(zoneId) or 0;
    last_zone = zoneId;

    if (extensions_for_zone(zoneId) ~= nil) then
        if (reset_timer == true) then
            event_timer = DEFAULT_TIME;
        end
        sync_key_items_from_player(false);
    else
        event_timer = 0;
        for i = 1, #key_items do
            key_items[i] = false;
        end
    end
end

local function current_zone()
    local mm = AshitaCore:GetMemoryManager();
    local party = mm and mm:GetParty();
    if (party == nil) then
        return 0;
    end
    return party:GetMemberZone(0) or 0;
end

function dynamis_tracker.is_dynamis_zone(zoneId)
    return extensions_for_zone(zoneId) ~= nil;
end

function dynamis_tracker.is_active()
    return dynamis_tracker.is_dynamis_zone(last_zone);
end

function dynamis_tracker.get_timer_text()
    return format_timer(event_timer);
end

function dynamis_tracker.get_timer_color()
    if (event_timer <= 60) then
        return { 0.85, 0.15, 0.15, 1.0 };
    elseif (event_timer <= 300) then
        return { 1.0, 0.78, 0.15, 1.0 };
    end
    return nil;
end

function dynamis_tracker.get_key_items()
    return key_items;
end

function dynamis_tracker.get_ki_labels()
    return { 'TE1', 'TE2', 'TE3', 'TE4', 'TE5' };
end

function dynamis_tracker.init()
    reset_for_zone(current_zone(), dynamis_tracker.is_dynamis_zone(current_zone()));
end

function dynamis_tracker.tick()
    local mm = AshitaCore:GetMemoryManager();
    local player = mm and mm:GetPlayer();
    if (player ~= nil and not player.isZoning and player:GetMainJob() ~= 0) then
        local zoneId = current_zone();
        if (zoning) then
            zoning = false;
            reset_for_zone(zoneId, true);
        elseif (zoneId ~= 0 and zoneId ~= last_zone) then
            reset_for_zone(zoneId, true);
        end
    end

    if (player ~= nil and (player.isZoning or player:GetMainJob() == 0)) then
        return;
    end

    local now = os.time();
    if (now >= tick_second + 1) then
        tick_second = now;
        if (event_timer > 0) then
            event_timer = event_timer - 1;
        end
    end
end

ashita.events.register('packet_in', 'glam_dynamis_tracker', function(e)
    if (e.id == 0x00A) then
        zoning = true;
    elseif (e.id == 0x055) then
        local ptype = struct.unpack('B', e.data, 0x85);
        if (ptype == 3 and dynamis_tracker.is_active()) then
            local dynaKI = struct.unpack('B', e.data, 0x06);
            update_key_items({
                [1] = bit.band(dynaKI, 2) > 0,
                [2] = bit.band(dynaKI, 4) > 0,
                [3] = bit.band(dynaKI, 8) > 0,
                [4] = bit.band(dynaKI, 16) > 0,
                [5] = bit.band(dynaKI, 32) > 0,
            });
        end
    end
end);

ashita.events.register('text_in', 'glam_dynamis_tracker', function(e)
    if (not dynamis_tracker.is_active() or e.mode <= 600 or e.injected) then
        return;
    end

    local results = ashita.regex.search(e.message, RE_DYNA_TIME_UPDATE);
    if (results ~= nil) then
        local timeLeft = tonumber(results[1][2]);
        local unit = results[1][3];
        if (unit == 'minute' or unit == 'minutes') then
            event_timer = timeLeft * 60;
        else
            event_timer = timeLeft;
        end
        return;
    end

    results = ashita.regex.search(e.message, RE_OBTAINED_KI);
    if (results ~= nil) then
        local kiIndex = OBTAINED_KI_NAMES[results[1][2]];
        if (kiIndex ~= nil) then
            local partial = { nil, nil, nil, nil, nil };
            partial[kiIndex] = true;
            update_key_items(partial);
        end
    end
end);

return dynamis_tracker;
