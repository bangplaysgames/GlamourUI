--[[
    MobDB icon strip for GlamourUI target bar (addons/mobdb/icons).
    Single horizontal row via draw-list positioning (avoids SameLine wrap issues).
]]

require('common');
local ffi = require('ffi');
local d3d8 = require('d3d8');
local imgui = require('imgui');
local mobdb_jobs = require('mobdb_jobs');
local gResources = require('resources');

local M = {};

local icon_cache = nil;
local icons_checked = false;
local d3d8_device = d3d8.get_device();

local PHYS_TYPES = { 'H2H', 'Impact', 'Piercing', 'Slashing' };
local MAGIC_TYPES = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' };
local BEHAVIOR_FLAGS = { 'Link', 'TrueSight', 'Sight', 'Sound', 'Scent', 'Magic', 'JA', 'Blood' };

local function ensure_icons()
    if (icons_checked == true) then
        return icon_cache ~= nil;
    end
    icons_checked = true;
    icon_cache = {};

    local directory = string.format('%saddons/mobdb/icons/', AshitaCore:GetInstallPath());
    if (ashita.fs.exists(directory) ~= true) then
        return false;
    end

    local contents = ashita.fs.get_directory(directory, '.*');
    if (contents == nil) then
        return false;
    end

    for _, file in pairs(contents) do
        local dot = string.find(file, '%.');
        if (dot ~= nil and dot > 1) then
            local key = string.sub(file, 1, dot - 1);
            local path = directory .. file;
            local tex_ptr = ffi.new('IDirect3DTexture8*[1]');
            if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, path, tex_ptr) == ffi.C.S_OK) then
                icon_cache[key] = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', tex_ptr[0]));
            end
        end
    end

    return next(icon_cache) ~= nil;
end

function M.estimate_row_height(iconSize, tbScale)
    iconSize = tonumber(iconSize) or 13;
    tbScale = tonumber(tbScale) or 1;
    return iconSize + math.max(2, math.floor(2 * tbScale));
end

local function format_potency(potency)
    potency = tonumber(potency) or 1;
    if (potency > 1) then
        return '+' .. string.format('%.2f', (potency - 1) * 100):gsub('0+$', ''):gsub('%.$', '') .. '%';
    end
    return '-' .. string.format('%.2f', (1 - potency) * 100):gsub('0+$', ''):gsub('%.$', '') .. '%';
end

local function collect_mods(modifiers, types)
    local mods = T{};
    if (modifiers == nil) then
        return mods;
    end
    for i = 1, #types do
        local name = types[i];
        local potency = tonumber(modifiers[name]);
        if (potency ~= nil and potency ~= 1.0) then
            mods:append({ Type = name, Potency = potency });
        end
    end
    table.sort(mods, function(a, b)
        return a.Potency > b.Potency;
    end);
    return mods;
end

local function calc_text_width(text)
    local w = imgui.CalcTextSize(text);
    if (type(w) == 'table') then
        return tonumber(w[1]) or tonumber(w.x) or 0;
    end
    return tonumber(w) or 0;
end

--- Draw mobdb icons in one horizontal row. Returns { drew = bool, rowHeight = number }.
function M.draw_target_icons(targetIndex, opts)
    opts = opts or {};
    local iconSize = tonumber(opts.iconSize) or 13;
    local textScale = tonumber(opts.textScale) or 0.35;
    local xAnchor = tonumber(opts.xAnchor) or 0;
    local yPos = tonumber(opts.yPos) or 0;
    local tbScale = tonumber(opts.tbScale) or 1;
    local fontSettings = opts.fontSettings;
    local iconGap = math.max(2, math.floor(2 * tbScale));
    local rowHeight = M.estimate_row_height(iconSize, tbScale);

    if (iconSize <= 0) then
        return { drew = false, rowHeight = 0 };
    end

    local record = mobdb_jobs.get_record(targetIndex);
    if (record == nil) then
        return { drew = false, rowHeight = 0 };
    end

    local iconsReady = ensure_icons();

    local winPos = { imgui.GetWindowPos() };
    local screenX = winPos[1] + xAnchor;
    local screenY = winPos[2] + yPos;
    local x = screenX;
    local drew = false;

    local dl = imgui.GetWindowDrawList();
    local textColor = imgui.GetColorU32({ 0.95, 0.95, 0.95, 1.0 });
    local fontPushed = nil;
    if (fontSettings ~= nil and textScale ~= nil and textScale > 0) then
        fontPushed = gResources.push_font_scale(textScale, fontSettings);
    end
    local textLineH = imgui.GetTextLineHeight();

    local function add_icon(name)
        local tex = icon_cache[name];
        if (tex == nil) then
            return false;
        end
        dl:AddImage(
            tonumber(ffi.cast('uint32_t', tex)),
            { x, screenY },
            { x + iconSize, screenY + iconSize },
            { 0, 0 },
            { 1, 1 },
            0xFFFFFFFF
        );
        x = x + iconSize + iconGap;
        drew = true;
        return true;
    end

    local function add_text(label)
        if (label == nil or label == '') then
            return;
        end
        local textY = screenY + math.max(0, (iconSize - textLineH) * 0.5);
        dl:AddText({ x, textY }, textColor, label);
        x = x + calc_text_width(label) + iconGap;
        drew = true;
    end

    local function add_text_right(label)
        if (label == nil or label == '') then
            return false;
        end
        local barWidth = tonumber(opts.barWidth) or 0;
        if (barWidth <= 0) then
            return false;
        end
        local tw = calc_text_width(label);
        local textX = screenX + barWidth - tw;
        local textY = screenY + math.max(0, (iconSize - textLineH) * 0.5);
        dl:AddText({ textX, textY }, textColor, label);
        drew = true;
        return true;
    end

    if (iconsReady == true) then
        if (record.Notorious == true) then
            if (record.Aggro == true) then
                add_icon('AggroHQ');
            else
                add_icon('PassiveHQ');
            end
        else
            if (record.Aggro == true) then
                add_icon('AggroNQ');
            else
                add_icon('PassiveNQ');
            end
        end

        for i = 1, #BEHAVIOR_FLAGS do
            local flag = BEHAVIOR_FLAGS[i];
            if (record[flag] == true) then
                add_icon(flag);
            end
        end

        local modifiers = record.Modifiers;
        if (modifiers ~= nil) then
            local allMods = T{};
            local physical = collect_mods(modifiers, PHYS_TYPES);
            local magical = collect_mods(modifiers, MAGIC_TYPES);
            for i = 1, #physical do
                allMods:append(physical[i]);
            end
            for i = 1, #magical do
                allMods:append(magical[i]);
            end

            for index = 1, #allMods do
                local mod = allMods[index];
                if (add_icon(mod.Type) == true) then
                    if (index == #allMods or allMods[index + 1].Potency ~= mod.Potency) then
                        local outstring = format_potency(mod.Potency);
                        if (index < #allMods) then
                            outstring = outstring .. ' ';
                        end
                        add_text(outstring);
                    end
                end
            end
        end
    end

    add_text_right(mobdb_jobs.format_level_range_text(record));

    if (fontPushed ~= nil) then
        gResources.pop_font(fontPushed);
    end

    if (drew == true) then
        local barWidth = tonumber(opts.barWidth) or 0;
        local totalW = math.max(barWidth, math.max(1, x - screenX));
        imgui.SetCursorPos({ xAnchor, yPos });
        imgui.Dummy({ totalW, rowHeight });
    end

    return { drew = drew, rowHeight = drew and rowHeight or 0 };
end

return M;
