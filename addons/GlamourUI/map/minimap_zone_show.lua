require('common');
local imgui = require('imgui');
local settings = require('settings');
local mapcore = require('mapcore');

local M = {};

local SETTINGS_NAME = 'minimap_zone_show';

local HOVER_FLAGS = bit.bor(
    ImGuiHoveredFlags_ChildWindows,
    ImGuiHoveredFlags_AllowWhenBlockedByActiveItem
);

local default_store = T{
    zones = T{},
};

local TOGGLE_ROWS = {
    {
        { key = 'show_npcs', envKey = 'minimap_show_npcs', label = 'NPCs' },
        { key = 'show_mobs', envKey = 'minimap_show_mobs', label = 'Mobs' },
        { key = 'show_party', envKey = 'minimap_show_party', label = 'Party' },
    },
    {
        { key = 'show_alliance', envKey = 'minimap_show_alliance', label = 'Alliance' },
        { key = 'show_other_players', envKey = 'minimap_show_other_players', label = 'Players' },
        { key = 'show_target', envKey = 'minimap_show_target', label = 'Target' },
    },
};

M._toggle_bar_visible = false;
M._toggle_bar_hide_after = 0;
M._ui_state = nil;
M._ui_state_zone = nil;

local function save_store()
    pcall(function()
        settings.save(SETTINGS_NAME);
    end);
end

local function current_zone_id()
    return tonumber(mapcore.get_player_zone());
end

local function vec2_xy(v, fallbackX, fallbackY)
    if (type(v) == 'table') then
        return tonumber(v[1]) or tonumber(v.x) or fallbackX, tonumber(v[2]) or tonumber(v.y) or fallbackY;
    end
    return fallbackX, fallbackY;
end

local function bool_from_env(env, envKey, defaultTrue)
    if (env == nil) then
        return defaultTrue == true;
    end
    local v = env[envKey];
    if (v == nil) then
        return defaultTrue == true;
    end
    return v == true;
end

function M.defaults_from_env(env)
    return {
        show_npcs = bool_from_env(env, 'minimap_show_npcs', true),
        show_mobs = bool_from_env(env, 'minimap_show_mobs', true),
        show_party = bool_from_env(env, 'minimap_show_party', true),
        show_alliance = bool_from_env(env, 'minimap_show_alliance', true),
        show_other_players = bool_from_env(env, 'minimap_show_other_players', true),
        show_target = bool_from_env(env, 'minimap_show_target', true),
    };
end

local function normalize_zone_entry(entry)
    if (entry == nil) then
        return nil;
    end
    return {
        show_npcs = entry.show_npcs == true,
        show_mobs = entry.show_mobs == true,
        show_party = entry.show_party == true,
        show_alliance = entry.show_alliance == true,
        show_other_players = entry.show_other_players == true,
        show_target = entry.show_target ~= false,
    };
end

local function get_stored_zone(zones, zoneId)
    zoneId = tonumber(zoneId);
    if (zoneId == nil or zones == nil) then
        return nil;
    end
    local entry = zones[zoneId] or zones[tostring(zoneId)];
    if (entry == nil) then
        return nil;
    end
    return normalize_zone_entry(entry);
end

function M.init()
    M.store = settings.load(default_store, SETTINGS_NAME);
    if (M.store.zones == nil) then
        M.store.zones = T{};
    end
    M._cache_zone = nil;
    M._toggle_bar_visible = false;
    M._toggle_bar_hide_after = 0;
    M._ui_state = nil;
    M._ui_state_zone = nil;
end

function M.on_zone_changed(_zoneId)
    M._cache_zone = nil;
    M._ui_state = nil;
    M._ui_state_zone = nil;
end

function M.has_zone_override(zoneId)
    if (M.store == nil) then
        return false;
    end
    return get_stored_zone(M.store.zones, zoneId or current_zone_id()) ~= nil;
end

function M.get_effective(env, zoneId)
    zoneId = tonumber(zoneId) or current_zone_id();
    local defaults = M.defaults_from_env(env);
    if (M.store == nil) then
        return defaults;
    end
    local stored = get_stored_zone(M.store.zones, zoneId);
    if (stored == nil) then
        return defaults;
    end
    return stored;
end

local function refresh_ui_state(env, zoneId)
    zoneId = tonumber(zoneId) or current_zone_id();
    local eff = M.get_effective(env, zoneId);
    M._ui_state = T{
        show_npcs = eff.show_npcs,
        show_mobs = eff.show_mobs,
        show_party = eff.show_party,
        show_alliance = eff.show_alliance,
        show_other_players = eff.show_other_players,
        show_target = eff.show_target,
    };
    M._ui_state_zone = zoneId;
end

function M.get_ui_state(env, zoneId)
    zoneId = tonumber(zoneId) or current_zone_id();
    if (M._ui_state == nil or M._ui_state_zone ~= zoneId) then
        refresh_ui_state(env, zoneId);
    end
    return M._ui_state;
end

local function ensure_zone_entry(zoneId, env)
    if (M.store == nil) then
        M.init();
    end
    zoneId = tonumber(zoneId) or current_zone_id();
    if (zoneId == nil) then
        return nil;
    end

    local entry = M.store.zones[zoneId];
    if (entry == nil) then
        entry = M.store.zones[tostring(zoneId)];
    end
    if (entry == nil) then
        local src = M._ui_state or M.defaults_from_env(env);
        entry = T{
            show_npcs = src.show_npcs == true,
            show_mobs = src.show_mobs == true,
            show_party = src.show_party == true,
            show_alliance = src.show_alliance == true,
            show_other_players = src.show_other_players == true,
            show_target = src.show_target ~= false,
        };
        M.store.zones[zoneId] = entry;
        save_store();
    else
        entry = normalize_zone_entry(entry);
        M.store.zones[zoneId] = entry;
    end
    M._cache_zone = nil;
    return entry;
end

function M.set_zone_toggle(zoneId, env, key, value)
    local entry = ensure_zone_entry(zoneId, env);
    if (entry == nil) then
        return;
    end
    entry[key] = value == true;
    save_store();
    M._cache_zone = nil;
end

local function environment_panel_hovered()
    return imgui.IsWindowHovered(0)
        or imgui.IsWindowHovered(HOVER_FLAGS);
end

local function mouse_inside_current_window()
    local mx, my = vec2_xy(imgui.GetMousePos(), 0, 0);
    local wx, wy = vec2_xy(imgui.GetWindowPos(), 0, 0);
    local ww, wh = vec2_xy(imgui.GetWindowSize(), 0, 0);
    if (ww <= 0 or wh <= 0) then
        return false;
    end
    return mx >= wx and mx < (wx + ww) and my >= wy and my < (wy + wh);
end

local function update_toggle_bar_visibility()
    local now = os.clock();
    if (environment_panel_hovered() or mouse_inside_current_window()) then
        M._toggle_bar_visible = true;
        M._toggle_bar_hide_after = now + 0.2;
        return;
    end

    if (imgui.IsMouseDown(0) and M._toggle_bar_visible) then
        M._toggle_bar_hide_after = now + 0.2;
        return;
    end

    if (M._toggle_bar_visible and now < (M._toggle_bar_hide_after or 0)) then
        return;
    end

    M._toggle_bar_visible = false;
end

local function content_avail_width()
    local avail = imgui.GetContentRegionAvail();
    if (type(avail) == 'table') then
        return math.max(1, tonumber(avail[1]) or tonumber(avail.x) or 1);
    end
    return math.max(1, tonumber(avail) or 1);
end

local function draw_toggle_row(row, uiState, zoneId, env, rowWidth, guiScale)
    local count = #row;
    local gap = math.max(4, math.floor(8 * guiScale));
    local itemW = (rowWidth - gap * (count - 1)) / count;

    for i = 1, count do
        local def = row[i];
        if (i > 1) then
            imgui.SameLine(0, gap);
        end
        imgui.SetNextItemWidth(itemW);
        local checked = { uiState[def.key] == true };
        if (imgui.Checkbox(('%s##GlamEnvZone%s'):fmt(def.label, def.key), checked)) then
            uiState[def.key] = checked[1] == true;
            M.set_zone_toggle(zoneId, env, def.key, checked[1]);
        end
    end
end

function M.draw_hover_toggles(env)
    if (env == nil or env.minimap_enabled ~= true) then
        M._toggle_bar_visible = false;
        return;
    end
    if (M.store == nil) then
        M.init();
    end

    update_toggle_bar_visibility();
    if (not M._toggle_bar_visible) then
        return;
    end

    local zoneId = current_zone_id();
    if (zoneId == nil) then
        return;
    end

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    local guiScale = tonumber(env.gui_scale) or 1;
    local rowWidth = content_avail_width();
    local uiState = M.get_ui_state(env, zoneId);

    for r = 1, #TOGGLE_ROWS do
        if (r > 1) then
            imgui.Spacing();
        end
        draw_toggle_row(TOGGLE_ROWS[r], uiState, zoneId, env, rowWidth, guiScale);
    end
end

return M;
