local ffi = require('ffi');
local imgui = require('imgui');
local mapcore = require('mapcore');
local maptexture = require('maptexture');
local minimap_entities = require('minimap_entities');

local M = {};

M.map_zoom = -1.0;
M.last_zone_key = nil;
M.heading_fn = nil;

function M.set_heading_fn(fn)
    M.heading_fn = fn;
end

local function env_settings()
    return GlamourUI.settings and GlamourUI.settings.Env or nil;
end

local function enabled()
    local s = env_settings();
    return s ~= nil and s.minimap_enabled == true;
end

local function zone_key_from_data()
    return mapcore.get_zone_key();
end

local function load_saved_zoom(zoneKey)
    local s = env_settings();
    if (zoneKey ~= nil and s ~= nil and s.minimap_zone_zoom ~= nil and s.minimap_zone_zoom[zoneKey] ~= nil) then
        local z = tonumber(s.minimap_zone_zoom[zoneKey]);
        if (z ~= nil and z > 0) then
            return z;
        end
    end
    return nil;
end

local function save_zoom(zoneKey, zoom)
    local s = env_settings();
    if (s == nil or zoneKey == nil or zoom == nil) then
        return;
    end
    if (s.minimap_zone_zoom == nil) then
        s.minimap_zone_zoom = {};
    end
    s.minimap_zone_zoom[zoneKey] = zoom;
end

local function default_zoom_multiplier()
    local s = env_settings();
    return math.max(1.0, math.min(10.0, tonumber(s and s.minimap_default_zoom) or 1.0));
end

local function zoom_step()
    local s = env_settings();
    return math.max(0.01, math.min(1.0, tonumber(s and s.minimap_zoom_step) or 0.1));
end

local function apply_zoom_for_active_map()
    local zoneKey = zone_key_from_data();
    if (zoneKey ~= nil and zoneKey ~= M.last_zone_key) then
        M.last_zone_key = zoneKey;
        local saved = load_saved_zoom(zoneKey);
        M.map_zoom = (saved ~= nil) and saved or -1.0;
    end
end

function M.reload_map()
    local ok, err = maptexture.activate_current_floor();
    if (not ok) then
        M.map_zoom = -1.0;
        M.last_zone_key = nil;
        return false, err;
    end

    apply_zoom_for_active_map();
    return true;
end

function M.on_zone_changed(zoneId, subZoneId)
    zoneId = tonumber(zoneId) or mapcore.get_player_zone();
    subZoneId = tonumber(subZoneId) or 0;
    require('minimap_zone_show').on_zone_changed(zoneId);
    if (zoneId ~= nil) then
        minimap_entities.on_zone(zoneId, subZoneId);
        maptexture.cache_zone(zoneId);
    end
    return M.reload_map();
end

function M.on_floor_changed(zoneId, floorId)
    zoneId = tonumber(zoneId) or mapcore.get_player_zone();
    floorId = tonumber(floorId);
    if (zoneId == nil or floorId == nil) then
        return M.reload_map();
    end

    maptexture.cache_zone(zoneId);
    local ok, err = maptexture.activate(zoneId, floorId);
    if (not ok) then
        return false, err;
    end

    apply_zoom_for_active_map();
    return true;
end

function M.init()
    require('gmap').init();
    require('minimap_zone_show').init();
    mapcore.on_zone_changed = function(zoneId)
        M.on_zone_changed(zoneId);
    end;
    mapcore.on_floor_changed = function(zoneId, floorId)
        M.on_floor_changed(zoneId, floorId);
    end;
    mapcore.on_zone_cache_clear = function()
        maptexture.clear_all();
        minimap_entities.clear_zone();
    end;
    mapcore.on_map_reload = function()
        M.reload_map();
    end;
    mapcore.init();
    ashita.tasks.once(1, function()
        local zoneId = mapcore.get_player_zone();
        if (zoneId ~= nil) then
            minimap_entities.on_zone(zoneId, 0);
        end
        M.reload_map();
    end);
end

local function compute_map_offset(availWidth, availHeight, texW, texH, zoom, centerOnPlayer)
    local texWidth = texW * zoom;
    local texHeight = texH * zoom;

    if (centerOnPlayer ~= true) then
        return (availWidth - texWidth) * 0.5, (availHeight - texHeight) * 0.5;
    end

    local mapData = mapcore.current_map_data;
    if (mapData == nil or mapData.entry == nil) then
        return nil, nil;
    end

    local playerX, playerY, playerZ = mapcore.get_player_position();
    if (playerX == nil) then
        return nil, nil;
    end

    local mapX, mapY = mapcore.world_to_map_coords(mapData.entry, playerX, playerY, playerZ);
    if (mapX == nil) then
        return nil, nil;
    end

    local texX, texY = mapcore.map_coords_to_texture(mapData.entry, mapX, mapY, texW);
    local offsetX = (availWidth * 0.5) - (texX * zoom);
    local offsetY = (availHeight * 0.5) - (texY * zoom);

    if (texWidth > availWidth) then
        offsetX = math.min(0, offsetX);
        offsetX = math.max(availWidth - texWidth, offsetX);
    else
        offsetX = (availWidth - texWidth) * 0.5;
    end

    if (texHeight > availHeight) then
        offsetY = math.min(0, offsetY);
        offsetY = math.max(availHeight - texHeight, offsetY);
    else
        offsetY = (availHeight - texHeight) * 0.5;
    end

    return offsetX, offsetY;
end

local function map_offset_bounds(availWidth, availHeight, texW, texH, zoom)
    local texWidth = texW * zoom;
    local texHeight = texH * zoom;
    local minX, maxX, minY, maxY;

    if (texWidth > availWidth) then
        minX = availWidth - texWidth;
        maxX = 0;
    else
        minX = (availWidth - texWidth) * 0.5;
        maxX = minX;
    end

    if (texHeight > availHeight) then
        minY = availHeight - texHeight;
        maxY = 0;
    else
        minY = (availHeight - texHeight) * 0.5;
        maxY = minY;
    end

    return minX, maxX, minY, maxY;
end

local function clamp_map_offset(offsetX, offsetY, minX, maxX, minY, maxY)
    return math.max(minX, math.min(maxX, offsetX)), math.max(minY, math.min(maxY, offsetY));
end

local function step_pan_axis(current, target, maxStep)
    local delta = target - current;
    if (math.abs(delta) <= maxStep) then
        return target, true;
    end
    if (delta > 0) then
        return current + maxStep, false;
    end
    return current - maxStep, false;
end

--- Fullscreen map pan: auto-follow player (clamped), then unlock axes for manual drag.
local function update_fullscreen_pan(panState, availW, availH, texW, texH, zoom, mouseX, mouseY, hovered, interactive)
    local idealX, idealY = compute_map_offset(availW, availH, texW, texH, zoom, true);
    if (idealX == nil) then
        return nil, nil;
    end

    local minX, maxX, minY, maxY = map_offset_bounds(availW, availH, texW, texH, zoom);
    local zoneKey = zone_key_from_data();

    if (panState.zoneKey ~= zoneKey) then
        panState.offsetX = nil;
        panState.offsetY = nil;
        panState.unlockX = false;
        panState.unlockY = false;
        panState.zoneKey = zoneKey;
    end

    if (panState.lastZoom ~= nil and math.abs((tonumber(panState.lastZoom) or 0) - zoom) > 0.0001) then
        panState.unlockX = false;
        panState.unlockY = false;
    end
    panState.lastZoom = zoom;

    if (panState.lastIdealX ~= nil) then
        if (math.abs(idealX - panState.lastIdealX) > 0.5 or math.abs(idealY - panState.lastIdealY) > 0.5) then
            panState.unlockX = false;
            panState.unlockY = false;
        end
    end
    panState.lastIdealX = idealX;
    panState.lastIdealY = idealY;

    if (panState.offsetX == nil or panState.offsetY == nil) then
        panState.offsetX = idealX;
        panState.offsetY = idealY;
    end

    panState.offsetX, panState.offsetY = clamp_map_offset(panState.offsetX, panState.offsetY, minX, maxX, minY, maxY);

    local io = imgui.GetIO();
    local dt = tonumber(io and io.DeltaTime) or (1 / 60);
    local panStep = math.max(4, math.min(availW, availH) * 2.5 * dt);

    if (panState.unlockX ~= true) then
        local arrived;
        panState.offsetX, arrived = step_pan_axis(panState.offsetX, idealX, panStep);
        if (arrived) then
            panState.unlockX = true;
        end
    end

    if (panState.unlockY ~= true) then
        local arrived;
        panState.offsetY, arrived = step_pan_axis(panState.offsetY, idealY, panStep);
        if (arrived) then
            panState.unlockY = true;
        end
    end

    panState.offsetX, panState.offsetY = clamp_map_offset(panState.offsetX, panState.offsetY, minX, maxX, minY, maxY);

    if (interactive and hovered and imgui.IsMouseDown(0)) then
        if (panState.dragMouseX ~= nil and panState.dragMouseY ~= nil) then
            local dx = mouseX - panState.dragMouseX;
            local dy = mouseY - panState.dragMouseY;
            if (panState.unlockX == true and math.abs(dx) > 0.01) then
                panState.offsetX = panState.offsetX + dx;
            end
            if (panState.unlockY == true and math.abs(dy) > 0.01) then
                panState.offsetY = panState.offsetY + dy;
            end
        end
        panState.dragMouseX = mouseX;
        panState.dragMouseY = mouseY;
    else
        panState.dragMouseX = nil;
        panState.dragMouseY = nil;
    end

    panState.offsetX, panState.offsetY = clamp_map_offset(panState.offsetX, panState.offsetY, minX, maxX, minY, maxY);
    return panState.offsetX, panState.offsetY;
end

local function player_marker_screen_pos(childMinX, childMinY, offsetX, offsetY, zoom, texW)
    local mapData = mapcore.current_map_data;
    if (mapData == nil or mapData.entry == nil) then
        return nil, nil;
    end

    local playerX, playerY, playerZ = mapcore.get_player_position();
    if (playerX == nil) then
        return nil, nil;
    end

    return mapcore.world_to_screen(
        mapData.entry, playerX, playerY, playerZ, texW,
        childMinX, childMinY, offsetX, offsetY, zoom
    );
end

local function draw_player_marker(dl, centerX, centerY, headingRad, size, opacity)
    opacity = math.max(0.0, math.min(1.0, tonumber(opacity) or 1.0));
    if (headingRad == nil) then
        local alpha = math.floor(opacity * 255);
        dl:AddCircleFilled({ centerX, centerY }, size, bit.bor(bit.lshift(alpha, 24), 0x0020AAFF), 12);
        return;
    end

    local north_zero_offset = math.pi * 0.5;
    local a = headingRad + north_zero_offset;
    local tipX = centerX + math.sin(a) * size;
    local tipY = centerY - math.cos(a) * size;
    local wing = size * 0.55;
    local leftX = centerX + math.sin(a + 2.4) * wing;
    local leftY = centerY - math.cos(a + 2.4) * wing;
    local rightX = centerX + math.sin(a - 2.4) * wing;
    local rightY = centerY - math.cos(a - 2.4) * wing;
    local color = imgui.GetColorU32({ 0.15, 0.75, 1.0, 0.95 * opacity });
    dl:AddTriangleFilled({ tipX, tipY }, { leftX, leftY }, { rightX, rightY }, color);
    local dotAlpha = math.floor(opacity * 255);
    dl:AddCircleFilled({ centerX, centerY }, 2.5, bit.bor(bit.lshift(dotAlpha, 24), 0x00FFFFFF), 8);
end

--- Draw map into the current ImGui region. opts: width, height, mapOpacity, interactive, persistZoom, centerOnPlayer.
--- Returns true when map was drawn, false when unavailable (caller may show a message).
function M.draw_viewport(opts)
    opts = opts or {};
    local availW = math.max(1, math.floor(tonumber(opts.width) or 1));
    local availH = math.max(1, math.floor(tonumber(opts.height) or 1));
    local mapOpacityOverride = opts.mapOpacity;
    local interactive = (opts.interactive ~= false);
    local persistZoom = (opts.persistZoom == true);
    local centerOnPlayer = (opts.centerOnPlayer ~= false);
    local panState = opts.panState;
    local fadeOverlayWithMapOpacity = (opts.fadeOverlayWithMapOpacity == true);

    if (not maptexture.is_ready()) then
        return false;
    end

    local s = env_settings();
    local guiScale = tonumber(s and s.gui_scale) or 1;

    local zoneKey = zone_key_from_data();
    if (zoneKey ~= nil and zoneKey ~= M.last_zone_key) then
        M.last_zone_key = zoneKey;
        local saved = load_saved_zoom(zoneKey);
        M.map_zoom = (saved ~= nil) and saved or -1.0;
    end

    local childMinX, childMinY = imgui.GetCursorScreenPos();
    local texW = maptexture.width;
    local texH = maptexture.height;
    local minZoom = math.min(availW / texW, availH / texH);

    if (M.map_zoom < 0) then
        M.map_zoom = math.min(minZoom * default_zoom_multiplier(), 5.0);
    end
    M.map_zoom = math.max(minZoom, math.min(M.map_zoom, 5.0));

    local mouseX, mouseY = imgui.GetMousePos();
    local hovered = mouseX >= childMinX and mouseX <= (childMinX + availW)
        and mouseY >= childMinY and mouseY <= (childMinY + availH);

    if (interactive) then
        local wheel = imgui.GetIO().MouseWheel;
        if (hovered and wheel ~= 0) then
            local oldZoom = M.map_zoom;
            local newZoom = math.max(minZoom, math.min(oldZoom + wheel * zoom_step(), 5.0));
            if (math.abs(newZoom - oldZoom) > 0.0001) then
                M.map_zoom = newZoom;
                if (persistZoom and zoneKey ~= nil) then
                    save_zoom(zoneKey, M.map_zoom);
                end
            end
        end
    end

    local offsetX, offsetY;
    if (panState ~= nil) then
        offsetX, offsetY = update_fullscreen_pan(
            panState, availW, availH, texW, texH, M.map_zoom, mouseX, mouseY, hovered, interactive
        );
    else
        offsetX, offsetY = compute_map_offset(availW, availH, texW, texH, M.map_zoom, centerOnPlayer);
    end
    if (offsetX == nil) then
        return false;
    end

    local texWidth = texW * M.map_zoom;
    local texHeight = texH * M.map_zoom;
    local posX = childMinX + offsetX;
    local posY = childMinY + offsetY;

    local clipX1 = childMinX;
    local clipY1 = childMinY;
    local clipX2 = childMinX + availW;
    local clipY2 = childMinY + availH;

    local dl = imgui.GetWindowDrawList();
    dl:PushClipRect({ clipX1, clipY1 }, { clipX2, clipY2 }, true);

    local texturePointer = tonumber(ffi.cast('uint32_t', maptexture.texture_id));
    if (texturePointer ~= nil) then
        local opacity = mapOpacityOverride;
        if (opacity == nil) then
            opacity = tonumber(s and s.minimap_opacity) or 1.0;
        end
        opacity = math.max(0.0, math.min(1.0, tonumber(opacity) or 1.0));
        local alpha = math.floor(opacity * 255);
        local tint = bit.bor(bit.lshift(alpha, 24), 0x00FFFFFF);
        dl:AddImage(
            texturePointer,
            { posX, posY },
            { posX + texWidth, posY + texHeight },
            { 0, 0 }, { 1, 1 },
            tint
        );
    end

    local overlayAlpha = tonumber(s and s.minimap_overlay_opacity) or 1.0;
    if (fadeOverlayWithMapOpacity and mapOpacityOverride ~= nil) then
        local baseMapOpacity = math.max(0.001, tonumber(s and s.minimap_opacity) or 1.0);
        overlayAlpha = overlayAlpha * (tonumber(mapOpacityOverride) or 1.0) / baseMapOpacity;
        overlayAlpha = math.max(0.0, math.min(1.0, overlayAlpha));
    end

    minimap_entities.draw(dl, childMinX, childMinY, offsetX, offsetY, M.map_zoom, texW, mouseX, mouseY, overlayAlpha);

    local headingRad = (M.heading_fn ~= nil) and M.heading_fn() or nil;
    local markerX, markerY;
    if (centerOnPlayer and panState == nil) then
        markerX = childMinX + availW * 0.5;
        markerY = childMinY + availH * 0.5;
    else
        markerX, markerY = player_marker_screen_pos(childMinX, childMinY, offsetX, offsetY, M.map_zoom, texW);
    end
    if (markerX ~= nil and markerY ~= nil) then
        local markerOpacity = tonumber(mapOpacityOverride) or tonumber(s and s.minimap_opacity) or 1.0;
        draw_player_marker(dl, markerX, markerY, headingRad, 14 * guiScale, markerOpacity);
    end

    dl:PopClipRect();
    imgui.Dummy({ availW, availH });
    return true;
end

function M.draw()
    if (not enabled()) then
        return;
    end

    local s = env_settings();
    local guiScale = tonumber(s.gui_scale) or 1;
    local mapW = math.max(80, math.floor((tonumber(s.minimap_width) or 180) * guiScale));
    local mapH = math.max(80, math.floor((tonumber(s.minimap_height) or 180) * guiScale));

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    imgui.BeginChild(
        'EnvMinimap##Glam',
        { mapW, mapH },
        ImGuiChildFlags_Borders,
        bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse)
    );

    if (not M.draw_viewport({
        width = mapW,
        height = mapH,
        interactive = true,
        persistZoom = true,
    })) then
        imgui.TextDisabled('Map unavailable');
    end

    imgui.EndChild();
end

function M.tick()
    if (not enabled()) then
        return;
    end
    minimap_entities.scan();
    mapcore.tick();
end

ashita.events.register('packet_in', 'glam_minimap_zone_cb', function(e)
    mapcore.on_zone_packet(e);
end);

return M;
