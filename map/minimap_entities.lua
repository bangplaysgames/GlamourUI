require('common');
local imgui = require('imgui');
local textShadow = require('textShadow');
local mapcore = require('mapcore');
local gmap = require('gmap');
local minimap_zone_show = require('minimap_zone_show');

local M = {};

M.zone_names = {};
M.npcs = {};
M.mobs = {};
M.other_players = {};
M.last_scan_time = -999;
M.current_zone_id = 0;
M.current_subzone_id = 0;

local function env_settings()
    return GlamourUI.settings and GlamourUI.settings.Env or nil;
end

local function zone_show_flags(s)
    if (s == nil) then
        return nil;
    end
    return minimap_zone_show.get_effective(s);
end

local function color_u32(rgba, alphaScale)
    if (type(rgba) ~= 'table') then
        return 0xFFFFFFFF;
    end
    alphaScale = tonumber(alphaScale) or 1;
    local r = math.floor(math.max(0, math.min(1, tonumber(rgba[1]) or 1)) * 255);
    local g = math.floor(math.max(0, math.min(1, tonumber(rgba[2]) or 1)) * 255);
    local b = math.floor(math.max(0, math.min(1, tonumber(rgba[3]) or 1)) * 255);
    local a = math.floor(math.max(0, math.min(1, tonumber(rgba[4]) or 1)) * 255 * alphaScale);
    return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r);
end

local function is_entity_rendered(entity)
    if (entity == nil or entity.Render == nil or entity.Render.Flags0 == nil) then
        return false;
    end
    local renderFlags = entity.Render.Flags0;
    return bit.band(renderFlags, 0x200) == 0x200 and bit.band(renderFlags, 0x4000) == 0;
end

local function entity_position(entity, useLast)
    if (entity == nil or entity.Movement == nil) then
        return nil;
    end

    if (useLast == true and entity.Movement.LastPosition ~= nil) then
        local lp = entity.Movement.LastPosition;
        return lp.X, lp.Y, lp.Z;
    end

    if (entity.Movement.LocalPosition ~= nil) then
        local lp = entity.Movement.LocalPosition;
        return lp.X, lp.Y, lp.Z;
    end

    return nil;
end

local function normalize_name(name)
    if (name == nil) then
        return nil;
    end
    name = tostring(name):trim();
    if (name == '' or name:sub(1, 10) == 'Home Point') then
        return nil;
    end
    return name;
end

local function get_entity_kind(entMgr, index)
    if (entMgr == nil) then
        return nil;
    end

    local spawnFlags = entMgr:GetSpawnFlags(index);
    if (bit.band(spawnFlags, 0x10) ~= 0) then
        return 'mob';
    end
    if (bit.band(spawnFlags, 0x0001) ~= 0) then
        return 'pc';
    end
    if (bit.band(spawnFlags, 0x0002) == 0x0002) then
        return 'npc';
    end
    return nil;
end

local function build_party_server_ids()
    local ids = {};
    local partyMgr = AshitaCore:GetMemoryManager():GetParty();
    if (partyMgr == nil) then
        return ids;
    end

    for i = 0, 17 do
        if (partyMgr:GetMemberIsActive(i) == 1) then
            local sid = partyMgr:GetMemberServerId(i);
            if (sid ~= nil and sid > 0) then
                ids[sid] = true;
            end
        end
    end

    return ids;
end

local function build_party_entity_indices()
    local indices = {};
    local partyMgr = AshitaCore:GetMemoryManager():GetParty();
    if (partyMgr == nil) then
        return indices;
    end

    for i = 0, 17 do
        if (partyMgr:GetMemberIsActive(i) == 1) then
            local idx = partyMgr:GetMemberTargetIndex(i);
            if (idx ~= nil and idx > 0) then
                indices[idx] = true;
            end
        end
    end

    local player = GetPlayerEntity();
    if (player ~= nil and player.TargetIndex ~= nil and player.TargetIndex > 0) then
        indices[player.TargetIndex] = true;
    end

    return indices;
end

local function is_mob_hostile(entity, partyEntityIndices)
    if (entity == nil or partyEntityIndices == nil) then
        return false;
    end

    local targetIndex = tonumber(entity.TargetIndex) or 0;
    if (targetIndex <= 0) then
        return false;
    end

    return partyEntityIndices[targetIndex] == true;
end

local function get_current_target_info()
    local targetMgr = AshitaCore:GetMemoryManager():GetTarget();
    if (targetMgr == nil) then
        return nil;
    end

    local targetIndex = targetMgr:GetTargetIndex(targetMgr:GetIsSubTargetActive());
    if (targetIndex == nil or targetIndex == 0) then
        return nil;
    end

    local entity = GetEntity(targetIndex);
    if (not is_entity_rendered(entity)) then
        return nil;
    end

    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    local serverId = entMgr:GetServerId(targetIndex);
    if (serverId == nil or serverId <= 0) then
        return nil;
    end

    return {
        id = serverId,
        index = targetIndex,
        name = M.lookup_name(serverId, entity) or normalize_name(entity.Name) or 'Target',
        entity = entity,
        kind = get_entity_kind(entMgr, targetIndex),
    };
end

function M.clear_zone()
    M.zone_names = {};
    M.npcs = {};
    M.mobs = {};
    M.other_players = {};
    M.last_scan_time = -999;
end

function M.load_zone_names(zoneId, subZoneId)
    M.clear_zone();
    zoneId = tonumber(zoneId);
    subZoneId = tonumber(subZoneId) or 0;
    if (zoneId == nil) then
        return;
    end

    M.current_zone_id = zoneId;
    M.current_subzone_id = subZoneId;

    local ok, dats = pcall(require, 'ffxi.dats');
    if (not ok or dats == nil or dats.get_zone_npclist == nil) then
        return;
    end

    local file = dats.get_zone_npclist(zoneId, subZoneId);
    if (file == nil or file == '') then
        return;
    end

    local f = io.open(file, 'rb');
    if (f == nil) then
        return;
    end

    local size = f:seek('end');
    f:seek('set', 0);
    if (size == nil or size <= 0 or (size % 0x20) ~= 0) then
        f:close();
        return;
    end

    for _ = 0, ((size / 0x20) - 1) do
        local data = f:read(0x20);
        if (data ~= nil) then
            local name, id = struct.unpack('c28L', data);
            name = normalize_name(name and name:trim('\0'));
            id = tonumber(id);
            if (id ~= nil and id > 0 and name ~= nil) then
                M.zone_names[id] = name;
            end
        end
    end

    f:close();
end

function M.on_zone(zoneId, subZoneId)
    M.load_zone_names(zoneId, subZoneId);
end

function M.lookup_name(serverId, entity)
    local zoneName = M.zone_names[serverId];
    if (zoneName ~= nil) then
        return zoneName;
    end
    if (entity ~= nil) then
        return normalize_name(entity.Name);
    end
    return nil;
end

function M.scan()
    local s = env_settings();
    if (s == nil or s.minimap_enabled ~= true) then
        return;
    end

    local show = zone_show_flags(s);
    local showNpc = show.show_npcs == true;
    local showMob = show.show_mobs == true;
    local showPc = show.show_other_players == true;
    if (not showNpc and not showMob and not showPc) then
        return;
    end

    local interval = math.max(0.5, tonumber(s.minimap_scan_interval) or 2.0);
    local now = os.clock();
    if (now - M.last_scan_time < interval) then
        return;
    end
    M.last_scan_time = now;

    local player = GetPlayerEntity();
    local px, py, pz = entity_position(player, false);
    if (px == nil) then
        return;
    end

    local zoneId = mapcore.get_player_zone();
    if (zoneId == nil) then
        return;
    end

    local maxDist = math.max(10, tonumber(s.minimap_scan_distance) or 50);
    local maxDistSq = maxDist * maxDist;
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    local partyIds = build_party_server_ids();
    local partyEntityIndices = build_party_entity_indices();

    local foundNpc = {};
    local foundMob = {};
    local foundPc = {};

    for index = 0, 2303 do
        local entity = GetEntity(index);
        if (is_entity_rendered(entity)) then
            local ex, ey, ez = entity_position(entity, false);
            if (ex ~= nil) then
                local dx = ex - px;
                local dy = ey - py;
                if ((dx * dx + dy * dy) <= maxDistSq) then
                    local serverId = entMgr:GetServerId(index);
                    if (serverId ~= nil and serverId > 0) then
                        local kind = get_entity_kind(entMgr, index);
                        local name = M.lookup_name(serverId, entity);
                        if (name ~= nil) then
                            local row = {
                                id = serverId,
                                index = index,
                                name = name,
                                zoneId = zoneId,
                                lastSeen = now,
                                kind = kind,
                                hostile = (kind == 'mob') and is_mob_hostile(entity, partyEntityIndices),
                            };

                            if (gmap.entity_passes_filter(row)) then
                                if (kind == 'npc' and showNpc) then
                                    foundNpc[serverId] = row;
                                elseif (kind == 'mob' and showMob) then
                                    if (entity.HPPercent == nil or entity.HPPercent > 0) then
                                        foundMob[serverId] = row;
                                    end
                                elseif (kind == 'pc' and showPc and not partyIds[serverId]) then
                                    foundPc[serverId] = row;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    M.npcs = foundNpc;
    M.mobs = foundMob;
    M.other_players = foundPc;
end

local function draw_circle_marker(dl, screenX, screenY, radius, fillColor, outlineColor)
    dl:AddCircleFilled({ screenX, screenY }, radius, fillColor, 16);
    if (outlineColor ~= nil) then
        dl:AddCircle({ screenX, screenY }, radius, outlineColor, 16, 1.5);
    end
end

local function draw_diamond_marker(dl, screenX, screenY, radius, fillColor)
    local r = radius;
    dl:AddQuadFilled(
        { screenX, screenY - r },
        { screenX + r, screenY },
        { screenX, screenY + r },
        { screenX - r, screenY },
        fillColor
    );
end

local function draw_target_marker(dl, screenX, screenY, radius, fillColor, outlineColor)
    local r = radius;
    dl:AddCircle({ screenX, screenY }, r, outlineColor or fillColor, 24, 2.5);
    dl:AddLine({ screenX - r, screenY }, { screenX + r, screenY }, fillColor, 2.0);
    dl:AddLine({ screenX, screenY - r }, { screenX, screenY + r }, fillColor, 2.0);
    dl:AddCircleFilled({ screenX, screenY }, math.max(2, r * 0.35), fillColor, 12);
end

local LabelState = {};

local function label_state_reset()
    LabelState.drawn = {};
    LabelState.queue = {};
    LabelState.mouseX = nil;
    LabelState.mouseY = nil;
    LabelState.hoverOnly = false;
end

local function marker_under_mouse(screenX, screenY, radius)
    local mx = LabelState.mouseX;
    local my = LabelState.mouseY;
    if (mx == nil or my == nil or screenX == nil or screenY == nil) then
        return false;
    end
    local r = math.max(2, tonumber(radius) or 4) + 2;
    local dx = mx - screenX;
    local dy = my - screenY;
    return (dx * dx + dy * dy) <= (r * r);
end

local function label_color_rgba(s, row, targetInfo)
    if (targetInfo ~= nil and row ~= nil and row.id == targetInfo.id) then
        return s.minimap_label_color_target or { 1.0, 0.92, 0.2, 1.0 };
    end

    if (row ~= nil and row.hostile == true) then
        return s.minimap_label_color_hostile or { 1.0, 0.45, 0.35, 1.0 };
    end

    if (row ~= nil and row.kind == 'mob') then
        return s.minimap_label_color_mobs or { 1.0, 0.55, 0.50, 1.0 };
    end

    if (row ~= nil and row.kind == 'npc') then
        return s.minimap_label_color_npcs or { 0.98, 0.94, 0.55, 1.0 };
    end

    if (row ~= nil and row.kind == 'pc') then
        return s.minimap_label_color_players or { 0.65, 0.82, 1.0, 1.0 };
    end

    return { 1.0, 1.0, 1.0, 1.0 };
end

local function label_wants(s, row, targetInfo)
    if (row == nil or row.name == nil or row.name == '') then
        return false;
    end

    if (targetInfo ~= nil and row.id == targetInfo.id and s.minimap_label_target == true) then
        return true;
    end

    if (row.hostile == true and s.minimap_label_hostile == true) then
        return true;
    end

    if (row.kind == 'mob' and s.minimap_label_mobs == true) then
        return true;
    end

    if (row.kind == 'npc' and s.minimap_label_npcs == true) then
        return true;
    end

    if (row.kind == 'pc' and s.minimap_label_players == true) then
        return true;
    end

    return false;
end

local function label_queue(dl, row, screenX, screenY, markerSize, targetInfo, s, overlayAlpha)
    if (not label_wants(s, row, targetInfo)) then
        return;
    end

    if (LabelState.hoverOnly == true and not marker_under_mouse(screenX, screenY, markerSize)) then
        return;
    end

    local key = tonumber(row.id) or row.name;
    if (LabelState.drawn[key] == true) then
        return;
    end
    LabelState.drawn[key] = true;

    LabelState.queue[#LabelState.queue + 1] = {
        name = row.name,
        x = screenX,
        y = screenY,
        size = markerSize,
        color = color_u32(label_color_rgba(s, row, targetInfo), overlayAlpha),
    };
end

local function calc_label_text_size(text)
    local ts = imgui.CalcTextSize(text);
    if (type(ts) == 'table') then
        return tonumber(ts[1]) or tonumber(ts.x) or 0,
            tonumber(ts[2]) or tonumber(ts.y) or 0;
    end
    local w = tonumber(ts) or 0;
    return w, w;
end

local function label_flush(dl, s)
    if (#LabelState.queue == 0) then
        return;
    end

    local fontPushed = nil;
    if (gResources ~= nil and gResources.push_font_scale ~= nil) then
        local scale = (tonumber(s.font_scale) or 1) * (tonumber(s.minimap_label_font_scale) or 0.85);
        fontPushed = gResources.push_font_scale(scale, s);
    end

    local labelGap = 1;

    for i = 1, #LabelState.queue do
        local item = LabelState.queue[i];
        local tw, th = calc_label_text_size(item.name);
        local textH = th;
        if (imgui.GetTextLineHeight ~= nil) then
            textH = tonumber(imgui.GetTextLineHeight()) or textH;
        end
        local markerRadius = math.max(2, tonumber(item.size) or 4);
        -- Top-left above marker: bottom of text sits labelGap px above marker top.
        local pos = {
            item.x - tw * 0.5,
            item.y - markerRadius - labelGap - textH,
        };
        textShadow.draw_list_add_text_shadowed(imgui, dl, pos, item.color, item.name);
    end

    if (fontPushed ~= nil and gResources.pop_font ~= nil) then
        gResources.pop_font(fontPushed);
    end
end

local function draw_entity_at(
    dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
    row, iconSize, fillColor, outlineColor, targetInfo, s, drawMarkerFn
)
    local entity = (row.index ~= nil) and GetEntity(row.index) or nil;
    if (not is_entity_rendered(entity)) then
        return;
    end

    local wx, wy, wz = entity_position(entity, false);
    if (wx == nil) then
        return;
    end

    local sx, sy = mapcore.world_to_screen(
        mapData.entry, wx, wy, wz, texW, originX, originY, offsetX, offsetY, zoom
    );
    if (sx == nil) then
        return;
    end

    drawMarkerFn(dl, sx, sy, iconSize, fillColor, outlineColor);
    label_queue(dl, row, sx, sy, iconSize, targetInfo, s, LabelState.overlayAlpha or 1.0);
end

local function draw_entity_list(
    dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
    list, iconSize, color, overlayAlpha, targetInfo, s, skipTargetId
)
    if (list == nil or mapData == nil or mapData.entry == nil) then
        return;
    end

    local fill = color_u32(color, overlayAlpha);
    local outline = color_u32({ 0, 0, 0, 0.85 }, overlayAlpha);

    for _, ent in pairs(list) do
        if (skipTargetId == nil or ent.id ~= skipTargetId) then
            draw_entity_at(
                dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
                ent, iconSize, fill, outline, targetInfo, s, draw_circle_marker
            );
        end
    end
end

local function draw_party_and_alliance(
    dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
    s, overlayAlpha, targetInfo, skipTargetId
)
    local show = zone_show_flags(s);
    local showParty = show.show_party == true;
    local showAlliance = show.show_alliance == true;
    if (not showParty and not showAlliance) then
        return;
    end

    local partyMgr = AshitaCore:GetMemoryManager():GetParty();
    if (partyMgr == nil) then
        return;
    end

    local partyColor = color_u32(s.minimap_color_party or { 0.2, 0.85, 0.35, 0.95 }, overlayAlpha);
    local allianceColor = color_u32(s.minimap_color_alliance or { 0.35, 0.65, 1.0, 0.95 }, overlayAlpha);
    local partySize = math.max(3, tonumber(s.minimap_icon_party) or 6);
    local allianceSize = math.max(3, tonumber(s.minimap_icon_alliance) or 5);

    local playerEnt = GetPlayerEntity();
    local playerSid = (playerEnt ~= nil) and playerEnt.ServerId or nil;

    for i = 0, 17 do
        if (partyMgr:GetMemberIsActive(i) == 1) then
            local drawThis = (i <= 5 and showParty) or (i >= 6 and showAlliance);
            if (drawThis and i ~= 0) then
                local entityIndex = partyMgr:GetMemberTargetIndex(i);
                local sid = partyMgr:GetMemberServerId(i);
                if (entityIndex ~= nil and entityIndex > 0 and sid ~= playerSid and sid ~= skipTargetId) then
                    local entity = GetEntity(entityIndex);
                    if (is_entity_rendered(entity)) then
                        local wx, wy, wz = entity_position(entity, true);
                        if (wx ~= nil) then
                            local sx, sy = mapcore.world_to_screen(
                                mapData.entry, wx, wy, wz, texW, originX, originY, offsetX, offsetY, zoom
                            );
                            if (sx ~= nil) then
                                local c = (i <= 5) and partyColor or allianceColor;
                                local sz = (i <= 5) and partySize or allianceSize;
                                local row = {
                                    id = sid,
                                    index = entityIndex,
                                    name = partyMgr:GetMemberName(i) or normalize_name(entity.Name) or 'Player',
                                    kind = 'pc',
                                };
                                if (gmap.entity_passes_filter(row)) then
                                    draw_diamond_marker(dl, sx, sy, sz, c);
                                    label_queue(dl, row, sx, sy, sz, targetInfo, s, overlayAlpha);
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function draw_current_target(
    dl, mapData, texW, originX, originY, offsetX, offsetY, zoom, s, overlayAlpha, targetInfo
)
    if (targetInfo == nil or mapData == nil or mapData.entry == nil) then
        return;
    end

    local entity = targetInfo.entity or GetEntity(targetInfo.index);
    local wx, wy, wz = entity_position(entity, false);
    if (wx == nil) then
        return;
    end

    local sx, sy = mapcore.world_to_screen(
        mapData.entry, wx, wy, wz, texW, originX, originY, offsetX, offsetY, zoom
    );
    if (sx == nil) then
        return;
    end

    local guiScale = tonumber(s.gui_scale) or 1;
    local size = math.max(5, (tonumber(s.minimap_icon_target) or 8) * guiScale);
    local fill = color_u32(s.minimap_color_target or { 1.0, 0.92, 0.2, 1.0 }, overlayAlpha);
    local outline = color_u32({ 0, 0, 0, 1.0 }, overlayAlpha);

    draw_target_marker(dl, sx, sy, size, fill, outline);

    local row = {
        id = targetInfo.id,
        index = targetInfo.index,
        name = targetInfo.name,
        kind = targetInfo.kind,
        hostile = false,
    };
    label_queue(dl, row, sx, sy, size, targetInfo, s, overlayAlpha);
end

function M.draw(dl, originX, originY, offsetX, offsetY, zoom, texW, mouseX, mouseY, overlayAlphaOverride)
    local s = env_settings();
    if (s == nil or s.minimap_enabled ~= true) then
        return;
    end

    local mapData = mapcore.current_map_data;
    if (mapData == nil or mapData.entry == nil) then
        return;
    end

    label_state_reset();
    LabelState.mouseX = tonumber(mouseX);
    LabelState.mouseY = tonumber(mouseY);
    LabelState.hoverOnly = s.minimap_label_hover_only == true;

    local overlayAlpha = overlayAlphaOverride;
    if (overlayAlpha == nil) then
        overlayAlpha = tonumber(s.minimap_overlay_opacity) or 1.0;
    end
    overlayAlpha = math.max(0.0, math.min(1.0, tonumber(overlayAlpha) or 1.0));
    LabelState.overlayAlpha = overlayAlpha;
    local guiScale = tonumber(s.gui_scale) or 1;
    local targetInfo = get_current_target_info();
    local skipTargetId = (targetInfo ~= nil) and targetInfo.id or nil;
    local show = zone_show_flags(s);

    if (show.show_npcs == true) then
        local size = math.max(2, (tonumber(s.minimap_icon_npc) or 4) * guiScale);
        draw_entity_list(
            dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
            M.npcs, size, s.minimap_color_npc or { 0.95, 0.90, 0.25, 0.95 },
            overlayAlpha, targetInfo, s, skipTargetId
        );
    end

    if (show.show_mobs == true) then
        local size = math.max(2, (tonumber(s.minimap_icon_mob) or 4) * guiScale);
        draw_entity_list(
            dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
            M.mobs, size, s.minimap_color_mob or { 0.95, 0.35, 0.30, 0.95 },
            overlayAlpha, targetInfo, s, skipTargetId
        );
    end

    if (show.show_other_players == true) then
        local size = math.max(2, (tonumber(s.minimap_icon_player) or 5) * guiScale);
        draw_entity_list(
            dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
            M.other_players, size, s.minimap_color_player or { 0.55, 0.75, 1.0, 0.95 },
            overlayAlpha, targetInfo, s, skipTargetId
        );
    end

    draw_party_and_alliance(
        dl, mapData, texW, originX, originY, offsetX, offsetY, zoom,
        s, overlayAlpha, targetInfo, skipTargetId
    );

    if (show.show_target ~= false) then
        draw_current_target(dl, mapData, texW, originX, originY, offsetX, offsetY, zoom, s, overlayAlpha, targetInfo);
    end

    label_flush(dl, s);
end

return M;
