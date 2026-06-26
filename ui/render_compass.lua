local imgui = require('imgui');
require('common');
local panelStyle = require('panelStyle');
local textShadow = require('textShadow');
local glamMinimap = require('minimap');

local M = {};

local function get_window_suffix()
    if (gParty.Party[1] ~= nil and gParty.Party[1].Name ~= nil) then
        return gParty.Party[1].Name;
    end
    return 'Init';
end

local function imgui_calc_text_width(str)
    if (str == nil or str == '') then
        return 0;
    end
    local w, h = imgui.CalcTextSize(str);
    if (type(w) == 'number') then
        return w;
    end
    if (type(w) == 'table') then
        return tonumber(w[1]) or tonumber(w.x) or 0;
    end
    return 0;
end

local function wrap_deg_180(d)
    local v = (tonumber(d) or 0) % 360;
    if (v > 180) then v = v - 360; end
    return v;
end

local function wrap_deg_360(d)
    local v = (tonumber(d) or 0) % 360;
    if (v < 0) then v = v + 360; end
    return v;
end

local COMPASS_NORTH_ZERO_OFFSET_DEG = 90;

local function compass_rad_to_deg(rad)
    return wrap_deg_360((tonumber(rad) or 0) * (180.0 / math.pi) + COMPASS_NORTH_ZERO_OFFSET_DEG);
end

local compass_player_entity_idx = { idx = nil, sid = nil };

local function movement_local_yaw(ent)
    if (ent == nil) then
        return nil;
    end
    local mov = ent.Movement or ent.movement;
    if (mov == nil) then
        return nil;
    end
    local lp = mov.LocalPosition or mov.local_position;
    if (lp == nil) then
        return nil;
    end
    return tonumber(lp.Yaw or lp.yaw);
end

local function heading_byte_or_rad(n)
    n = tonumber(n);
    if (n == nil) then
        return nil;
    end
    if (n >= 0 and n <= 255 and n == math.floor(n)) then
        return n * (math.pi / 128.0);
    end
    return n;
end

local function try_read_heading_rad(ent)
    if (ent == nil or ent.GetHeading == nil) then
        return nil;
    end
    local ok, v = pcall(function()
        return ent:GetHeading(0);
    end);
    if (ok and v ~= nil) then
        return heading_byte_or_rad(v);
    end
    local ok2, v2 = pcall(function()
        return ent:GetHeading();
    end);
    if (ok2 and v2 ~= nil) then
        return heading_byte_or_rad(v2);
    end
    return nil;
end

local function pcall_em_local_yaw(em, entityIndex)
    if (em == nil or em.GetLocalPositionYaw == nil) then
        return nil;
    end
    local ei = tonumber(entityIndex) or 0;
    local ok, y = pcall(function()
        return em:GetLocalPositionYaw(ei);
    end);
    if (not ok) then
        return nil;
    end
    return tonumber(y);
end

local function pcall_em_last_yaw(em, entityIndex)
    if (em == nil or em.GetLastPositionYaw == nil) then
        return nil;
    end
    local ei = tonumber(entityIndex) or 0;
    local ok, y = pcall(function()
        return em:GetLastPositionYaw(ei);
    end);
    if (not ok) then
        return nil;
    end
    return tonumber(y);
end

local function pcall_em_heading(em, entityIndex)
    if (em == nil or em.GetHeading == nil) then
        return nil;
    end
    local ei = tonumber(entityIndex) or 0;
    local ok, h = pcall(function()
        return em:GetHeading(ei);
    end);
    if (not ok or h == nil) then
        return nil;
    end
    return heading_byte_or_rad(h);
end

local function resolve_player_entity_index()
    local mm = (MemoryManager ~= nil) and MemoryManager or AshitaCore:GetMemoryManager();
    if (mm == nil) then
        return 0;
    end
    local party = mm:GetParty();
    if (party == nil) then
        return tonumber(compass_player_entity_idx.idx) or 0;
    end
    local sid = tonumber(party:GetMemberServerId(0));
    if (sid == nil or sid == 0) then
        compass_player_entity_idx.idx = nil;
        compass_player_entity_idx.sid = nil;
        return 0;
    end
    if (compass_player_entity_idx.idx ~= nil and compass_player_entity_idx.sid == sid) then
        return compass_player_entity_idx.idx;
    end
    local em = mm:GetEntity();
    if (em == nil or em.GetServerId == nil) then
        return 0;
    end
    for i = 0, 1024 do
        local ok, esid = pcall(function()
            return em:GetServerId(i);
        end);
        if (ok) then
            local e = tonumber(esid);
            if (e ~= nil and e == sid) then
                compass_player_entity_idx.idx = i;
                compass_player_entity_idx.sid = sid;
                return i;
            end
        end
    end
    compass_player_entity_idx.idx = 0;
    compass_player_entity_idx.sid = sid;
    return 0;
end

local function get_player_heading_radians()
    local pe = GetPlayerEntity();
    local y0 = movement_local_yaw(pe);
    if (y0 ~= nil) then
        return y0;
    end

    local mm = (MemoryManager ~= nil) and MemoryManager or AshitaCore:GetMemoryManager();
    if (mm ~= nil) then
        local em = mm:GetEntity();
        if (em ~= nil) then
            local idx = resolve_player_entity_index();
            local y = pcall_em_local_yaw(em, idx);
            if (y ~= nil) then
                return y;
            end
            local yLast = pcall_em_last_yaw(em, idx);
            if (yLast ~= nil) then
                return yLast;
            end
            local h = pcall_em_heading(em, idx);
            if (h ~= nil) then
                return h;
            end
            if (idx ~= 0) then
                local yAlt = pcall_em_local_yaw(em, 0);
                if (yAlt ~= nil) then
                    return yAlt;
                end
            end
        end

        local okMem, entIdx0 = pcall(function()
            return mm:GetEntity(0);
        end);
        if (okMem and entIdx0 ~= nil) then
            local ys = movement_local_yaw(entIdx0);
            if (ys ~= nil) then
                return ys;
            end
        end
    end

    local ok, ez = pcall(function()
        return GetEntity(0);
    end);
    if (ok and ez ~= nil) then
        local ys2 = movement_local_yaw(ez);
        if (ys2 ~= nil) then
            return ys2;
        end
        local yaw = tonumber(ez.Yaw);
        if (yaw ~= nil) then
            return yaw;
        end
        local hb = heading_byte_or_rad(ez.Heading);
        if (hb ~= nil) then
            return hb;
        end
        local r = try_read_heading_rad(ez);
        if (r ~= nil) then
            return r;
        end
    end

    if (pe ~= nil) then
        local yaw = tonumber(pe.Yaw);
        if (yaw ~= nil) then
            return yaw;
        end
        local hb = heading_byte_or_rad(pe.Heading);
        if (hb ~= nil) then
            return hb;
        end
        return try_read_heading_rad(pe);
    end

    return nil;
end

local compass_d3d8_device = nil;
local compass_ffi = require('ffi');

local function get_camera_heading_radians()
    if (compass_d3d8_device == nil) then
        local ok, d3d8 = pcall(require, 'd3d8');
        if (not ok or d3d8 == nil) then
            return nil;
        end
        local okDev, dev = pcall(function()
            return d3d8.get_device();
        end);
        if (not okDev or dev == nil) then
            return nil;
        end
        compass_d3d8_device = dev;
    end

    local ok, view = pcall(function()
        local _, m = compass_d3d8_device:GetTransform(compass_ffi.C.D3DTS_VIEW);
        return m;
    end);
    if (not ok or view == nil) then
        return nil;
    end

    local lx = tonumber(view._13) or 0;
    local lz = tonumber(view._33) or 0;
    if (math.abs(lx) < 0.000001 and math.abs(lz) < 0.000001) then
        return nil;
    end
    -- View-matrix forward is 90° behind entity yaw; match player heading space.
    return math.atan2(lx, lz) + (math.pi * 0.5);
end

local function compass_label_for_deg(deg)
    local d = wrap_deg_360(deg);
    if (d == 0) then return 'N'; end
    if (d == 90) then return 'E'; end
    if (d == 180) then return 'S'; end
    if (d == 270) then return 'W'; end
    if (d == 45) then return 'NE'; end
    if (d == 135) then return 'SE'; end
    if (d == 225) then return 'SW'; end
    if (d == 315) then return 'NW'; end
    return nil;
end

local function compass_nearest_label_for_deg(deg)
    local d = wrap_deg_360(deg);
    local snapped = (math.floor((d + 22.5) / 45.0) % 8) * 45;
    return compass_label_for_deg(snapped);
end

local GEO_CARDINAL_DEFAULT_COLORS = {
    Water = { 0.0, 0.42307734489440918, 1.0, 1.0 },
    Fire = { 1.0, 0.23529410362243652, 0.0, 1.0 },
    Dark = { 0.0, 0.0, 0.0, 1.0 },
    Light = { 1.0, 1.0, 1.0, 1.0 },
    Ice = { 0.55, 0.90, 1.0, 1.0 },
    Wind = { 0.0, 0.93013101816177368, 0.18602624535560608, 1.0 },
    Earth = { 0.98689955472946167, 0.64557880163192749, 0.13359779119491577, 1.0 },
    Lightning = { 0.78388655185699463, 0.095230832695960999, 0.99126636981964111, 1.0 },
};

local function resolve_geo_cardinal_color(compassSettings, element)
    local defaults = GEO_CARDINAL_DEFAULT_COLORS[element];
    if (defaults == nil) then
        return nil;
    end
    local colors = compassSettings ~= nil and compassSettings.geoCardinalColors or nil;
    local c = colors ~= nil and colors[element] or nil;
    if (type(c) ~= 'table') then
        return { defaults[1], defaults[2], defaults[3], defaults[4] };
    end
    return {
        tonumber(c[1]) or defaults[1],
        tonumber(c[2]) or defaults[2],
        tonumber(c[3]) or defaults[3],
        tonumber(c[4]) or defaults[4],
    };
end

-- Cardinal Chant element mapping from GeoCompass (textureAngle sectors).
local GEO_TEXTURE_ANGLE_OFFSET = (4.0 * math.pi / 3.0) - 1.0;

local function geo_cardinal_element_for_heading_deg(headingDeg)
    local playerDir = math.rad((tonumber(headingDeg) or 0) - 90.0);
    local textureAngle = playerDir + GEO_TEXTURE_ANGLE_OFFSET;
    local twoPi = 2.0 * math.pi;
    textureAngle = textureAngle % twoPi;
    if (textureAngle < 0) then
        textureAngle = textureAngle + twoPi;
    end

    if (textureAngle >= (15.0 / 16.0) * twoPi or textureAngle < (1.0 / 16.0) * twoPi) then
        return 'Water';
    elseif (textureAngle < (3.0 / 16.0) * twoPi) then
        return 'Fire';
    elseif (textureAngle < (5.0 / 16.0) * twoPi) then
        return 'Dark';
    elseif (textureAngle < (7.0 / 16.0) * twoPi) then
        return 'Light';
    elseif (textureAngle < (9.0 / 16.0) * twoPi) then
        return 'Ice';
    elseif (textureAngle < (11.0 / 16.0) * twoPi) then
        return 'Wind';
    elseif (textureAngle < (13.0 / 16.0) * twoPi) then
        return 'Earth';
    elseif (textureAngle < (15.0 / 16.0) * twoPi) then
        return 'Lightning';
    end
    return 'Water';
end

local function player_is_geo_job()
    local mm = (MemoryManager ~= nil) and MemoryManager or AshitaCore:GetMemoryManager();
    if (mm == nil) then
        return false;
    end
    local player = mm:GetPlayer();
    if (player == nil) then
        return false;
    end
    return player:GetMainJob() == 21 or player:GetSubJob() == 21;
end

local function draw_geo_cardinal_glow(dl, viewHeadingDeg, facingHeadingDeg, centerX, innerW, halfRange, topY, botY, opacity, compassSettings)
    local glowScale = math.max(0, math.min(1, tonumber(opacity) or 1.0));
    if (glowScale <= 0) then
        return;
    end

    local facingElement = geo_cardinal_element_for_heading_deg(facingHeadingDeg);
    local startDeg = math.floor(viewHeadingDeg - halfRange);
    local endDeg = math.ceil(viewHeadingDeg + halfRange);
    local ribbonH = botY - topY;

    for d = startDeg, endDeg do
        local bearing = wrap_deg_360(d);
        local rel = wrap_deg_180(bearing - viewHeadingDeg);
        if (math.abs(rel) <= halfRange + 0.001) then
            local element = geo_cardinal_element_for_heading_deg(bearing);
            local base = resolve_geo_cardinal_color(compassSettings, element);
            if (base ~= nil) then
                local alpha = 0.22 * glowScale;
                if (element == facingElement) then
                    alpha = alpha + (0.18 * glowScale);
                end
                local x0 = centerX + (rel / halfRange) * (innerW * 0.5);
                local relNext = wrap_deg_180((bearing + 1) - viewHeadingDeg);
                local x1 = centerX + (relNext / halfRange) * (innerW * 0.5);
                if (x1 < x0) then
                    x1 = x0 + 1;
                end
                dl:AddRectFilled(
                    { x0, topY + ribbonH * 0.05 },
                    { x1 + 1, botY - ribbonH * 0.05 },
                    imgui.GetColorU32({ base[1], base[2], base[3], alpha }),
                    2.0,
                    0
                );
            end
        end
    end

    do
        local base = resolve_geo_cardinal_color(compassSettings, facingElement);
        if (base ~= nil) then
            local playerRel = wrap_deg_180(facingHeadingDeg - viewHeadingDeg);
            local halfW = innerW * 0.5;
            local thumbX = centerX + (playerRel / halfRange) * halfW;
            if (playerRel > halfRange + 0.001) then
                thumbX = centerX + halfW;
            elseif (playerRel < -halfRange - 0.001) then
                thumbX = centerX - halfW;
            end
            local bandW = math.max(8, innerW * 0.06);
            dl:AddRectFilled(
                { thumbX - (bandW * 0.5), topY },
                { thumbX + (bandW * 0.5), botY },
                imgui.GetColorU32({ base[1], base[2], base[3], 0.30 * glowScale }),
                3.0,
                0
            );
        end
    end
end

local function get_entity_position_guess(ent)
    if (ent == nil) then
        return nil;
    end
    local x = tonumber(ent.X) or tonumber(ent.x) or tonumber(ent.PosX) or tonumber(ent.pos_x);
    local y = tonumber(ent.Y) or tonumber(ent.y) or tonumber(ent.PosY) or tonumber(ent.pos_y);
    local z = tonumber(ent.Z) or tonumber(ent.z) or tonumber(ent.PosZ) or tonumber(ent.pos_z);
    if (x ~= nil and z ~= nil) then
        return x, (y or 0), z;
    end
    local methods = {
        { 'GetX', 'GetY', 'GetZ' },
        { 'GetPositionX', 'GetPositionY', 'GetPositionZ' },
    };
    for i = 1, #methods do
        local mx, my, mz = ent[methods[i][1]], ent[methods[i][2]], ent[methods[i][3]];
        if (mx ~= nil and my ~= nil and mz ~= nil) then
            local ok, rx, ry, rz = pcall(function()
                return ent[methods[i][1]](ent), ent[methods[i][2]](ent), ent[methods[i][3]](ent);
            end);
            if (ok) then
                local nx = tonumber(rx);
                local ny = tonumber(ry);
                local nz = tonumber(rz);
                if (nx ~= nil and nz ~= nil) then
                    return nx, (ny or 0), nz;
                end
            end
        end
    end
    return nil;
end

local function bearing_deg_north0(fromX, fromZ, toX, toZ)
    local dx = (tonumber(toX) or 0) - (tonumber(fromX) or 0);
    local dz = (tonumber(toZ) or 0) - (tonumber(fromZ) or 0);
    local a = math.atan2(dx, dz) * (180.0 / math.pi);
    return wrap_deg_360(a);
end

function M.render()
    local s = GlamourUI.settings and GlamourUI.settings.Compass or nil;
    if (s == nil or s.enabled ~= true) then
        return;
    end

    local playerHeadingRad = get_player_heading_radians();
    if (playerHeadingRad == nil) then
        return;
    end

    local cameraHeadingRad = get_camera_heading_radians();
    if (cameraHeadingRad == nil) then
        cameraHeadingRad = playerHeadingRad;
    end

    local width = tonumber(s.width) or 540;
    local ribbonH = math.max(32, tonumber(s.height) or 58);
    width = math.max(160, width);
    local showDegFooter = (s.show_heading_value == true);
    local degFooterH = showDegFooter and math.max(18, math.floor(14 + 6 * (tonumber(s.font_scale) or 1))) or 0;
    local windowH = ribbonH + degFooterH;

    imgui.SetNextWindowSize({ width, windowH }, ImGuiCond_Always);
    imgui.SetNextWindowPos({ tonumber(s.x) or 700, tonumber(s.y) or 15 }, ImGuiCond_Once);

    local compassBgPops = panelStyle.push_panel_background(s);
    if (imgui.Begin('Compass##GlamCompass' .. get_window_suffix(), true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse))) then
        local fontPushed = gResources.push_font_scale((tonumber(s.font_scale) or 1) * 0.5, s);

        local dl = imgui.GetWindowDrawList();
        local winPos = { imgui.GetWindowPos() };
        local winW = imgui.GetWindowWidth();
        local winH = imgui.GetWindowHeight();

        local guiScale = tonumber(s.gui_scale) or 1;
        local padX = math.max(6, math.floor(10 * guiScale));
        local padY = math.max(5, math.floor(8 * guiScale));
        local tl = { winPos[1] + padX, winPos[2] + padY };
        local br = { winPos[1] + winW - padX, winPos[2] + ribbonH - padY };
        local brFull = { winPos[1] + winW - padX, winPos[2] + winH - padY };

        local bg = s.ribbonColor or { 0.05, 0.05, 0.05, 0.35 };
        dl:AddRectFilled(tl, brFull, imgui.GetColorU32(bg), 6.0, 0);

        local centerX = (tl[1] + br[1]) * 0.5;
        local topY = tl[2];
        local botY = br[2];

        local cameraHeadingDeg = compass_rad_to_deg(cameraHeadingRad);
        local playerHeadingDeg = compass_rad_to_deg(playerHeadingRad);

        local fov = math.max(30, math.min(240, tonumber(s.fov_deg) or 120));
        local tick = math.max(1, math.min(45, tonumber(s.tick_deg) or 5));
        local major = math.max(tick, tonumber(s.major_tick_deg) or 15);
        local labelStep = math.max(major, tonumber(s.label_deg) or 45);

        local innerW = math.max(1, br[1] - tl[1]);
        local halfRange = fov * 0.5;

        if (s.geoCardinalGlow ~= false and player_is_geo_job()) then
            draw_geo_cardinal_glow(dl, cameraHeadingDeg, playerHeadingDeg, centerX, innerW, halfRange, topY, botY, s.geoCardinalGlowOpacity, s);
        end

        local startDeg = math.floor((cameraHeadingDeg - halfRange) / tick) * tick;
        local endDeg = math.ceil((cameraHeadingDeg + halfRange) / tick) * tick;

        local tickColor = s.tickColor or { 0.90, 0.90, 0.95, 0.90 };
        local labelColor = s.labelColor or { 0.95, 0.95, 0.98, 0.95 };
        local centerColor = s.centerColor or { 0.20, 0.55, 0.95, 0.95 };

        for d = startDeg, endDeg, tick do
            local rel = wrap_deg_180(d - cameraHeadingDeg);
            if (math.abs(rel) <= halfRange + 0.001) then
                local x = centerX + (rel / halfRange) * (innerW * 0.5);

                local isMajor = (math.abs((d % major + major) % major) < 0.001);
                local isLabel = (math.abs((d % labelStep + labelStep) % labelStep) < 0.001);
                local lineH = isMajor and (botY - topY) * 0.55 or (botY - topY) * 0.30;
                local y1 = topY + (botY - topY) * 0.10;
                local y2 = y1 + lineH;

                dl:AddLine({ x, y1 }, { x, y2 }, imgui.GetColorU32(tickColor), isMajor and 2.0 or 1.0);

                if (isLabel) then
                    local nd = wrap_deg_360(d);
                    local lbl = compass_label_for_deg(nd);
                    if (lbl == nil and s.show_degrees == true) then
                        lbl = tostring(math.floor(nd + 0.5));
                    end
                    if (lbl ~= nil) then
                        local tw = imgui_calc_text_width(lbl);
                        textShadow.draw_list_add_text_shadowed(imgui, dl, { x - (tw * 0.5), y2 + 2 }, imgui.GetColorU32(labelColor), lbl);
                    end
                end
            end
        end

        local playerRel = wrap_deg_180(playerHeadingDeg - cameraHeadingDeg);
        local halfW = innerW * 0.5;
        local markerX = centerX + (playerRel / halfRange) * halfW;
        local markerClamped = false;
        if (playerRel > halfRange + 0.001) then
            markerX = br[1];
            markerClamped = true;
        elseif (playerRel < -halfRange - 0.001) then
            markerX = tl[1];
            markerClamped = true;
        end

        dl:AddLine({ markerX, topY }, { markerX, botY }, imgui.GetColorU32(centerColor), 3.0);

        if (markerClamped) then
            local facingLbl = compass_nearest_label_for_deg(playerHeadingDeg);
            if (facingLbl ~= nil) then
                local tw = imgui_calc_text_width(facingLbl);
                textShadow.draw_list_add_text_shadowed(imgui, dl, { markerX - (tw * 0.5), botY + 2 }, imgui.GetColorU32(centerColor), facingLbl);
            end
        end

        do
            local tr = (gPacket ~= nil) and gPacket.tracking or nil;
            if (tr ~= nil and tr.active == true and tr.actIndex ~= nil and tr.actIndex ~= 0) then
                local px, py, pz = get_entity_position_guess(GetPlayerEntity());
                local tx, tz = tonumber(tr.x), tonumber(tr.z);
                if (px ~= nil and pz ~= nil and tx ~= nil and tz ~= nil) then
                    local b = bearing_deg_north0(px, pz, tx, tz);
                    local rel = wrap_deg_180(b - cameraHeadingDeg);
                    if (math.abs(rel) <= halfRange + 0.001) then
                        local mx = centerX + (rel / halfRange) * (innerW * 0.5);
                        local my = topY + 2;
                        local c = { 1.0, 0.35, 0.20, 0.95 };
                        local cu = imgui.GetColorU32(c);
                        dl:AddTriangleFilled(
                            { mx, my },
                            { mx - 6, my + 10 },
                            { mx + 6, my + 10 },
                            cu
                        );
                    end
                end
            end
        end

        if (showDegFooter) then
            local text = ('%03d°'):fmt(math.floor(playerHeadingDeg + 0.5));
            local tw = imgui_calc_text_width(text);
            local textY = winPos[2] + ribbonH + 2;
            textShadow.draw_list_add_text_shadowed(imgui, dl, { centerX - (tw * 0.5), textY }, imgui.GetColorU32(labelColor), text);
        end

        local pos = { imgui.GetWindowPos() };
        s.x = pos[1];
        s.y = pos[2];
        s.height = math.max(32, imgui.GetWindowHeight() - degFooterH);

        gResources.pop_font(fontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(compassBgPops);
end

glamMinimap.set_heading_fn(get_player_heading_radians);

return M;
