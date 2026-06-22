require('common');

local chat = require('chat');
local settings = require('settings');
local imgui = require('imgui');
local mapcore = require('mapcore');

local M = {};

local SETTINGS_NAME = 'gmap_grid';

local default_store = T{
    zones = T{},
};

local grid_settings = settings.load(default_store, SETTINGS_NAME);

local function save_grid_settings()
    pcall(function()
        settings.save(SETTINGS_NAME);
    end);
end

local function zone_key()
    return mapcore.get_zone_key();
end

function M.tuning_for_zone_key(zoneKey)
    if (zoneKey == nil or grid_settings.zones == nil) then
        return nil;
    end
    return grid_settings.zones[zoneKey];
end

function M.tuning_for_current()
    return M.tuning_for_zone_key(zone_key());
end

function M.clear_tuning(zoneKey)
    zoneKey = zoneKey or zone_key();
    if (zoneKey == nil or grid_settings.zones == nil) then
        return false;
    end
    grid_settings.zones[zoneKey] = nil;
    save_grid_settings();
    return true;
end

local function ensure_zone_tuning(zoneKey)
    if (zoneKey == nil) then
        return nil;
    end
    if (grid_settings.zones == nil) then
        grid_settings.zones = T{};
    end
    if (grid_settings.zones[zoneKey] == nil) then
        grid_settings.zones[zoneKey] = T{};
    end
    return grid_settings.zones[zoneKey];
end

function M.set_tuning_field(field, value, zoneKey)
    zoneKey = zoneKey or zone_key();
    local t = ensure_zone_tuning(zoneKey);
    if (t == nil) then
        return false, 'no zone';
    end
    t[field] = value;
    save_grid_settings();
    return true;
end

function M.describe_tuning(zoneKey)
    zoneKey = zoneKey or zone_key();
    local tuning = M.tuning_for_zone_key(zoneKey);
    local divisor, gridOffset, ref = mapcore.default_grid_metrics();
    local lines = {};
    lines[#lines + 1] = ('zone key: %s'):fmt(zoneKey or '(unknown)');
    lines[#lines + 1] = ('defaults (ref %d): divisor=%.3f offset=%.3f'):fmt(ref, divisor, gridOffset);
    if (tuning == nil) then
        lines[#lines + 1] = 'overrides: (none)';
        return table.concat(lines, '\n');
    end
    lines[#lines + 1] = 'overrides:';
    for _, key in ipairs({
        'grid_divisor', 'grid_offset', 'shift_x', 'shift_y', 'entry_offset_x', 'entry_offset_y',
    }) do
        if (tuning[key] ~= nil) then
            lines[#lines + 1] = ('  %s = %s'):fmt(key, tostring(tuning[key]));
        end
    end
    return table.concat(lines, '\n');
end

function M.debug_snapshot()
    local data = mapcore.current_map_data;
    if (data == nil or data.entry == nil) then
        return nil, 'no map loaded';
    end

    local x, y, z = mapcore.get_player_position();
    if (x == nil) then
        return nil, 'no player position';
    end

    local entry = data.entry;
    local mapX, mapY = mapcore.world_to_map_coords(entry, x, y, z);
    if (mapX == nil) then
        return nil, 'world→map failed (scale zero?)';
    end

    local tuning = M.tuning_for_current();
    local col, row = mapcore.map_coords_to_grid(entry, mapX, mapY, tuning);
    local divisor, gridOffset, ref = mapcore.default_grid_metrics();
    if (tuning ~= nil) then
        if (tuning.grid_divisor ~= nil) then divisor = tuning.grid_divisor; end
        if (tuning.grid_offset ~= nil) then gridOffset = tuning.grid_offset; end
    end

    local lines = {};
    lines[#lines + 1] = ('zone %d floor %d (table index %s)'):fmt(
        entry.ZoneId, entry.FloorId, tostring(entry._index));
    lines[#lines + 1] = ('world: X=%.2f Y=%.2f Z=%.2f'):fmt(x, y, z);
    lines[#lines + 1] = ('map:  X=%.2f Y=%.2f  Scale=%d  OffsetX=%d OffsetY=%d'):fmt(
        mapX, mapY, entry.Scale, entry.OffsetX, entry.OffsetY);
    lines[#lines + 1] = ('grid metrics: divisor=%.3f offset=%.3f ref=%d (512 map space)'):fmt(divisor, gridOffset, ref);
    lines[#lines + 1] = ('grid: %s'):fmt(mapcore.format_grid_label(col, row) or '(nil)');
    lines[#lines + 1] = 'Compare with in-game /echo position while standing still.';
    return table.concat(lines, '\n');
end

--- Draw grid label in the top-right of the map clip rect.
function M.draw_overlay(dl, clipX1, clipY1, clipX2, clipY2, textOpacity)
    if (dl == nil or dl.AddText == nil) then
        return;
    end

    local tuning = M.tuning_for_current();
    local label = mapcore.get_player_grid_label(tuning);
    if (label == nil) then
        return;
    end

    textOpacity = math.max(0.0, math.min(1.0, tonumber(textOpacity) or 1.0));
    local pad = 6;
    local textW, textH = imgui.CalcTextSize(label);
    local bgW = textW + pad * 2;
    local bgH = textH + pad * 2;
    local bgX2 = clipX2 - 4;
    local bgX1 = bgX2 - bgW;
    local bgY1 = clipY1 + 4;
    local bgY2 = bgY1 + bgH;
    local textX = bgX1 + pad;
    local textY = bgY1 + pad;

    if (dl.AddRectFilled ~= nil) then
        dl:AddRectFilled(
            { bgX1, bgY1 },
            { bgX2, bgY2 },
            imgui.GetColorU32({ 0.05, 0.07, 0.12, 0.72 * textOpacity }),
            3.0
        );
    end
    dl:AddText(
        { textX, textY },
        imgui.GetColorU32({ 0.95, 0.97, 1.0, textOpacity }),
        label
    );
end

local function print_header_msg(msg, isError)
    local h = chat.header('GlamourUI');
    if (isError) then
        print(h:append(chat.error(msg)));
    else
        print(h:append(chat.message(msg)));
    end
end

function M.print_help()
    print(chat.header('GlamourUI /gmap grid'));
    print(chat.message('/gmap grid — show grid position and tuning for this zone/floor'));
    print(chat.message('/gmap grid log — detailed map/grid debug (compare with /echo)'));
    print(chat.message('/gmap grid divisor <n> — cell size in 512 map pixels (default 32)'));
    print(chat.message('/gmap grid offset <n> — half-cell inset (default divisor/2)'));
    print(chat.message('/gmap grid shift <x> <y> — add to entry offsets for grid only'));
    print(chat.message('/gmap grid entry <offsetX> <offsetY> — replace entry offsets for grid'));
    print(chat.message('/gmap grid reset — clear overrides for current zone/floor'));
    print(chat.message('Overrides save to config/addons/GlamourUI/gmap_grid.lua'));
end

function M.handle_command(args)
    if (#args < 2 or not args[2]:any('grid')) then
        return false;
    end

    local zoneKey = zone_key();

    if (#args == 2 or (#args >= 3 and args[3]:any('status'))) then
        local label, err = mapcore.get_player_grid_label(M.tuning_for_current());
        if (label == nil) then
            print_header_msg(err or 'grid unavailable', true);
        else
            print_header_msg(('Grid position: %s'):fmt(label));
        end
        print(chat.message(M.describe_tuning(zoneKey)));
        return true;
    end

    if (#args >= 3 and args[3]:any('help')) then
        M.print_help();
        return true;
    end

    if (#args >= 3 and args[3]:any('reset')) then
        if (M.clear_tuning(zoneKey)) then
            print_header_msg(('Grid tuning cleared for %s.'):fmt(zoneKey or 'current zone'));
        else
            print_header_msg('Could not determine zone/floor.', true);
        end
        return true;
    end

    if (#args >= 3 and (args[3]:any('log') or args[3]:any('debug'))) then
        local snap, err = M.debug_snapshot();
        if (snap == nil) then
            print_header_msg(err or 'debug failed', true);
        else
            print(chat.header('GlamourUI grid debug'));
            for line in snap:gmatch('[^\n]+') do
                print(chat.message(line));
            end
        end
        return true;
    end

    if (#args >= 4 and args[3]:any('divisor')) then
        local n = tonumber(args[4]);
        if (n == nil or n <= 0) then
            print_header_msg('Usage: /gmap grid divisor <positive number>', true);
            return true;
        end
        M.set_tuning_field('grid_divisor', n);
        print_header_msg(('Grid divisor set to %.3f for %s.'):fmt(n, zoneKey or 'zone'));
        return true;
    end

    if (#args >= 4 and args[3]:any('offset')) then
        local n = tonumber(args[4]);
        if (n == nil) then
            print_header_msg('Usage: /gmap grid offset <number>', true);
            return true;
        end
        M.set_tuning_field('grid_offset', n);
        print_header_msg(('Grid offset set to %.3f for %s.'):fmt(n, zoneKey or 'zone'));
        return true;
    end

    if (#args >= 5 and args[3]:any('shift')) then
        local sx = tonumber(args[4]);
        local sy = tonumber(args[5]);
        if (sx == nil or sy == nil) then
            print_header_msg('Usage: /gmap grid shift <x> <y>', true);
            return true;
        end
        M.set_tuning_field('shift_x', sx);
        M.set_tuning_field('shift_y', sy);
        print_header_msg(('Grid shift set to (%.2f, %.2f) for %s.'):fmt(sx, sy, zoneKey or 'zone'));
        return true;
    end

    if (#args >= 5 and args[3]:any('entry')) then
        local ox = tonumber(args[4]);
        local oy = tonumber(args[5]);
        if (ox == nil or oy == nil) then
            print_header_msg('Usage: /gmap grid entry <offsetX> <offsetY>', true);
            return true;
        end
        M.set_tuning_field('entry_offset_x', ox);
        M.set_tuning_field('entry_offset_y', oy);
        print_header_msg(('Grid entry offsets set to (%d, %d) for %s.'):fmt(ox, oy, zoneKey or 'zone'));
        return true;
    end

    M.print_help();
    return true;
end

return M;
