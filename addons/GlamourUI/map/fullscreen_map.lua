require('common');

local imgui = require('imgui');
local mapcore = require('mapcore');
local minimap = require('minimap');

local M = {};

M.open = false;
M.player_moving = false;
M.last_pos = nil;
M.pan = nil;

local function reset_pan()
    M.pan = {
        offsetX = nil,
        offsetY = nil,
        unlockX = false,
        unlockY = false,
        lastIdealX = nil,
        lastIdealY = nil,
        dragMouseX = nil,
        dragMouseY = nil,
        lastZoom = nil,
        zoneKey = nil,
    };
end

local function env_settings()
    return GlamourUI.settings and GlamourUI.settings.Env or nil;
end

local function sync_open_state()
    if (GlamourUI ~= nil) then
        GlamourUI.fullscreenMapOpen = M.open == true;
    end
end

local function display_size()
    local ok, io = pcall(function()
        return imgui.GetIO();
    end);
    if (not ok or io == nil or io.DisplaySize == nil) then
        return 1920, 1080;
    end
    local ds = io.DisplaySize;
    local w = tonumber(ds.x) or tonumber(ds[1]) or 1920;
    local h = tonumber(ds.y) or tonumber(ds[2]) or 1080;
    return w, h;
end

local function transit_opacity()
    local s = env_settings();
    local v = tonumber(s and s.minimap_transit_opacity) or 0.45;
    return math.max(0.05, math.min(1.0, v));
end

function M.is_open()
    return M.open == true;
end

function M.is_player_moving()
    return M.player_moving == true;
end

function M.should_block_escape()
    return M.is_open() and not M.is_player_moving();
end

function M.tick_movement()
    if (not M.is_open()) then
        M.player_moving = false;
        M.last_pos = nil;
        return;
    end

    local x, y, z = mapcore.get_player_position();
    if (x == nil) then
        M.player_moving = false;
        return;
    end
    if (M.last_pos ~= nil) then
        M.player_moving = (M.last_pos[1] ~= x) or (M.last_pos[2] ~= y) or (M.last_pos[3] ~= z);
    else
        M.player_moving = false;
    end
    M.last_pos = { x, y, z };
end

function M.open_map()
    if (M.open) then
        return;
    end
    M.open = true;
    reset_pan();
    sync_open_state();
end

function M.close()
    if (not M.open) then
        return;
    end
    M.open = false;
    M.player_moving = false;
    M.last_pos = nil;
    M.pan = nil;
    sync_open_state();
end

function M.toggle()
    if (M.open) then
        M.close();
    else
        M.open_map();
    end
end

function M.handle_escape_key()
    if (not M.should_block_escape()) then
        return false;
    end
    M.close();
    return true;
end

function M.draw()
    if (not M.is_open()) then
        return;
    end

    local screenW, screenH = display_size();
    local mapW = math.floor(screenW * 0.9);
    local mapH = math.floor(screenH * 0.9);
    local posX = math.floor((screenW - mapW) * 0.5);
    local posY = math.floor((screenH - mapH) * 0.5);

    local mapOpacity = tonumber(env_settings() and env_settings().minimap_opacity) or 1.0;
    if (M.is_player_moving()) then
        mapOpacity = transit_opacity();
    end

    local flags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoBackground
    );

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ posX, posY }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ mapW, mapH }, ImGuiCond_Always);

    if (imgui.Begin('GlamourUI Full Map##GlamFSM', true, flags)) then
        if (not minimap.draw_viewport({
            width = mapW,
            height = mapH,
            mapOpacity = mapOpacity,
            fadeOverlayWithMapOpacity = true,
            interactive = true,
            persistZoom = true,
            panState = M.pan,
        })) then
            imgui.TextDisabled('Map unavailable');
        end
        imgui.End();
    end
end

return M;
