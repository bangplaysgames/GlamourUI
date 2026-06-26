local imgui = require('imgui');
require('common');
local panelStyle = require('panelStyle');
local textShadow = require('textShadow');
local gBuffs = require('buffTable');
local compat = require('compat');
local enemy_debuff_tracker = require('enemy_debuff_tracker');
local target_mob_action = require('target_mob_action');
local mobdb_jobs = require('mobdb_jobs');
local mobdb_icons = require('mobdb_icons');
local chatPartyNames = require('chatPartyNames');
local glamMinimap = require('minimap');
local map_grid = require('map_grid');
local mapcore = require('mapcore');
local entity_ids = require('entity_ids');
local minimap_zone_show = require('minimap_zone_show');
local fullscreen_map = require('fullscreen_map');
local dynamis_tracker = require('dynamis_tracker');
local mob_check = require('mob_check');
local ffxi_glyphs = require('ffxi_glyphs');
local render_compass = require('render_compass');
local toasts = require('toasts');
local combat_toasts = require('combat_toasts');
local skillchain_data = require('skillchain_data');
local parse_window = require('parse_window');

local function can_cancel_status(statusId)
    if (statusId == nil or statusId < 1 or statusId > 0x3FF or statusId == 255) then
        return false;
    end
    local icon = AshitaCore:GetResourceManager():GetStatusIconByIndex(statusId);
    return icon ~= nil and icon.CanCancel ~= 0;
end

local function get_status_name(statusId)
    return AshitaCore:GetResourceManager():GetString(compat.buffs_table(), statusId, 2) or ('Status #' .. tostring(statusId));
end

local function render_status_tooltip(statusId, hintText)
    if (statusId == nil or statusId < 1 or statusId > 0x3FF or statusId == 255) then
        return;
    end
    local info = AshitaCore:GetResourceManager():GetStatusIconByIndex(statusId);
    local name = get_status_name(statusId);
    local tipName = ('%s (#%d)'):fmt(tostring(name or '???'), tonumber(statusId) or 0);
    local tipDesc = (info ~= nil and info.Description ~= nil and info.Description[1] ~= nil and info.Description[1] ~= '') and info.Description[1] or '???';

    imgui.BeginTooltip();
    imgui.Text(tipName);
    imgui.Text(tipDesc);
    if (hintText ~= nil and hintText ~= '') then
        imgui.TextDisabled(hintText);
    end
    imgui.EndTooltip();
end

local function render_status_tooltip_at_screen_pos(statusId, hintText, screenX, screenY, iconSize)
    if (statusId == nil or statusId < 1 or statusId > 0x3FF or statusId == 255) then
        return;
    end
    local info = AshitaCore:GetResourceManager():GetStatusIconByIndex(statusId);
    local name = get_status_name(statusId);
    local tipName = ('%s (#%d)'):fmt(tostring(name or '???'), tonumber(statusId) or 0);
    local tipDesc = (info ~= nil and info.Description ~= nil and info.Description[1] ~= nil and info.Description[1] ~= '') and info.Description[1] or '???';

    local ix = tonumber(screenX) or 0;
    local iy = tonumber(screenY) or 0;
    local isz = tonumber(iconSize) or 0;

 
    local vx, vy = 0, 0;
    local vw, vh = 1920, 1080;
    local io = imgui.GetIO and imgui.GetIO() or nil;
    if (io ~= nil and io.DisplaySize ~= nil) then
        if (type(io.DisplaySize) == 'table') then
            vw = tonumber(io.DisplaySize[1]) or tonumber(io.DisplaySize.x) or vw;
            vh = tonumber(io.DisplaySize[2]) or tonumber(io.DisplaySize.y) or vh;
        end
    end

    local px = ix + isz + 10;
    local py = iy;
    if (px > (vx + vw - 260)) then
        px = ix - 260;
    end
    if (px < vx + 4) then px = vx + 4; end
    if (py < vy + 4) then py = vy + 4; end
    if (py > (vy + vh - 120)) then py = vy + vh - 120; end

    imgui.SetNextWindowPos({ px, py }, ImGuiCond_Always);
    imgui.SetNextWindowBgAlpha(1.0);
    if (imgui.SetNextWindowFocus ~= nil) then
        imgui.SetNextWindowFocus();
    end
    local flags = bit.bor(
        ImGuiWindowFlags_Tooltip,
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoInputs
    );
    if (imgui.Begin(('BuffTooltip##%d'):fmt(statusId), true, flags)) then
        imgui.Text(tipName);
        imgui.Text(tipDesc);
        if (hintText ~= nil and hintText ~= '') then
            imgui.TextDisabled(hintText);
        end
        imgui.End();
    end
end

local function try_cancel_status(statusId)
    local status_hi = bit.rshift(statusId, 8);
    local status_lo = bit.band(statusId, 0xff);
    AshitaCore:GetPacketManager():AddOutgoingPacket(0xf1, { 0x00, 0x00, 0x00, 0x00, status_lo, status_hi, 0x00, 0x00 });
end

local function draw_rect_abs(top_left, bot_right, color, radius, filled)
    local color_u32 = imgui.GetColorU32(color);
    local dl = imgui.GetWindowDrawList();
    if (filled) then
        dl:AddRectFilled(top_left, bot_right, color_u32, radius or 0.0, 0);
    else
        dl:AddRect(top_left, bot_right, color_u32, radius or 0.0, 0, 1.0);
    end
end

local function imgui_calc_text_height()
    local w, h = imgui.CalcTextSize('Mg');
    if (type(h) == 'number') then
        return math.max(1, h);
    end
    if (type(w) == 'table') then
        local nh = tonumber(w[2]) or tonumber(w.y);
        if (nh ~= nil and nh > 0) then
            return nh;
        end
    end
    local fh = imgui.GetFontSize();
    if (type(fh) == 'number') then
        return math.max(1, fh);
    end
    return 12;
end

local function fmt_time(t)
    local time = t;
    local h = math.floor(time / (60 * 60));
    local m = math.floor(time / 60 - h * 60);
    local s = math.floor(time - (m + h * 60) * 60);
    if(h > 0) then
        return ('%02i:%02i:%02i'):fmt(h, m, s);
    elseif(m > 0) then
        return ('%02i:%02i'):fmt(m, s);
    else
        return('%02i'):fmt(s);
    end
end

local function split_status_icons_from_slots(icons)
    local debuffs = T{};
    local buffs = T{};
    if (icons == nil) then
        return debuffs, buffs;
    end
    for j = 1, 32 do
        local id = icons[j];
        if (id == nil or id == -1 or id == 255 or id <= 0) then
            break;
        end
        if (gBuffs.IsBuff(id) == true) then
            buffs[#buffs + 1] = id;
        else
            debuffs[#debuffs + 1] = id;
        end
    end
    return debuffs, buffs;
end

local function party_slot_for_server_id(server_id)
    local mm = MemoryManager or AshitaCore:GetMemoryManager();
    local party = mm and mm:GetParty();
    if (party == nil or server_id == nil) then
        return nil;
    end
    for p = 0, 5 do
        if (party:GetMemberServerId(p) == server_id) then
            return p;
        end
    end
    return nil;
end

local function format_buff_duration_remaining(sec)
    if (sec == nil) then
        return '';
    end
    if (sec < 0) then
        return '--';
    end
    if (sec == 0) then
        return '0';
    end

    local wholeHours = math.floor(sec / 3600);
    if (wholeHours >= 1) then
        return ('%dh'):fmt(wholeHours);
    end

    local m = math.floor(sec / 60);
    local s = math.floor(sec - m * 60);
    return ('%d:%02d'):fmt(m, s);
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
    return tonumber(w) or 0;
end

local function draw_party_buff_icon_grid(statusIds, iconSize, maxColumns, maxRows, theme, anchorXGui, startYGui, guiScale, buffGuiScale, timerSecsList, memberIndex, timerBelowIcon, timerFontScale)
    if (timerBelowIcon == nil) then
        timerBelowIcon = false;
    end
    local anchorX = anchorXGui;
    if (anchorX == nil) then
        anchorX = (30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale;
    end

    local gapX = math.max(8, math.floor(13 * buffGuiScale));
    local gapY = math.max(6, math.floor(9 * buffGuiScale));
    local timerUnderGap = math.max(1, math.floor(2 * buffGuiScale));

    if (timerFontScale == nil) then
        timerFontScale = GlamourUI.settings.Party.pList.font_scale;
    end
    local fontTimer = math.max(0.14, (timerFontScale * 0.34) * guiScale * buffGuiScale);

    local plist = GlamourUI.settings.Party.pList;
    local nav = GlamourUI ~= nil and GlamourUI.PartyList ~= nil and GlamourUI.PartyList.BuffNav or nil;
    local navActive = nav ~= nil and nav.active == true;
    local highlightEnabled = navActive;

    local rowStride = iconSize + gapY;
    if (timerBelowIcon == true and timerSecsList ~= nil) then
        local pushedStride = gResources.push_font_scale(fontTimer, GlamourUI.settings.Party.pList);
        local lh = imgui.GetTextLineHeight();
        gResources.pop_font(pushedStride);
        local lineH = 12;
        if (type(lh) == 'number') then
            lineH = lh;
        elseif (type(lh) == 'table') then
            lineH = tonumber(lh.y) or tonumber(lh[2]) or lineH;
        end
        rowStride = iconSize + gapY + math.ceil(lineH + timerUnderGap);
    end

    local displayIndex = 0;
    local bottomY = startYGui;

    for idx = 1, #statusIds do
        local statusId = statusIds[idx];
        local icon = gResources.get_icon_from_theme(theme, statusId);
        if (icon ~= nil) then
            local row = math.floor(displayIndex / maxColumns);
            local col = displayIndex % maxColumns;
            if (row >= maxRows) then
                break;
            end

            local px = anchorX + col * (iconSize + gapX);
            local py = startYGui + row * rowStride;

            imgui.SetCursorPos({ px, py });
            local abs = { imgui.GetCursorScreenPos() };
            local absX = abs[1];
            local absY = abs[2];
            local isCancellable = (memberIndex == 0) and can_cancel_status(statusId);

            local sel = (GlamourUI ~= nil and GlamourUI.PartyList ~= nil) and GlamourUI.PartyList.BuffSelection or nil;
            local isSelected = false;
            if (navActive and nav ~= nil and memberIndex == 0 and nav.list ~= nil and #nav.list > 0) then
                local idxSel = math.max(1, math.min(nav.index or 1, #nav.list));
                isSelected = (nav.list[idxSel] == statusId);
            elseif (sel ~= nil and sel.memberIndex == memberIndex and sel.statusId == statusId) then
                isSelected = true;
            end

            if (highlightEnabled and isSelected) then
                local pad = math.max(1, math.floor(2 * buffGuiScale));
                local tl = { absX - pad, absY - pad };
                local br = { absX + iconSize + pad, absY + iconSize + pad };
                local color = isCancellable and { 1.0, 0.25, 0.25, 0.25 } or { 0.20, 0.55, 0.95, 0.22 };
                draw_rect_abs(tl, br, color, 6.0, true);
                local border = isCancellable and { 1.0, 0.25, 0.25, 0.85 } or { 0.20, 0.55, 0.95, 0.75 };
                draw_rect_abs(tl, br, border, 6.0, false);
            end

            imgui.Image(icon, { iconSize, iconSize }, { 0, 0 }, { 1, 1 });

            bottomY = math.max(bottomY, py + iconSize);

            if (navActive and isSelected and memberIndex == 0) then
                local hint = isCancellable and '(enter to cancel)' or nil;
                render_status_tooltip_at_screen_pos(statusId, hint, absX, absY, iconSize);
            end

            if (imgui.IsItemHovered()) then
                local hint = nil;
                if (isCancellable) then
                    hint = navActive and '(enter to cancel)' or '(right click to cancel)';
                end
                render_status_tooltip(statusId, hint);
            end

            if (navActive) then
            elseif (sel ~= nil and imgui.IsItemHovered()) then
                if (highlightEnabled and sel.locked ~= true) then
                    sel.memberIndex = memberIndex;
                    sel.statusId = statusId;
                end
                if (highlightEnabled and imgui.IsItemClicked(ImGuiMouseButton_Left)) then
                    if (sel.locked == true and sel.memberIndex == memberIndex and sel.statusId == statusId) then
                        sel.locked = false;
                    else
                        sel.locked = true;
                        sel.memberIndex = memberIndex;
                        sel.statusId = statusId;
                    end
                end
                if (imgui.IsItemClicked(ImGuiMouseButton_Right)) then
                    if (isCancellable) then
                        try_cancel_status(statusId);
                    end
                    if (highlightEnabled) then
                        sel.locked = false;
                        sel.memberIndex = nil;
                        sel.statusId = nil;
                    end
                end
            end

            if (timerSecsList ~= nil) then
                local txt = format_buff_duration_remaining(timerSecsList[idx]);
                if (txt ~= nil and txt ~= '') then
                    local pushedTimer = gResources.push_font_scale(fontTimer, GlamourUI.settings.Party.pList);
                    local tw = imgui_calc_text_width(txt);
                    local th = imgui_calc_text_height();
                    local lh = imgui.GetTextLineHeight();
                    if (type(lh) == 'number' and lh > th) then
                        th = lh;
                    end
                    local pad = math.max(1, math.floor(2 * buffGuiScale));
                    local tx = px + (iconSize - tw) * 0.5;
                    local ty;
                    if (timerBelowIcon == true) then
                        ty = py + iconSize + timerUnderGap;
                    else
                        ty = py + iconSize - th - pad;
                    end

                    if (tx < px) then
                        tx = px;
                    end

                    imgui.SetCursorPos({ tx, ty });
                    imgui.PushStyleColor(ImGuiCol_Text, { 0.02, 0.02, 0.02, 1.0 });
                    for ox = -1, 1 do
                        for oy = -1, 1 do
                            if (ox ~= 0 or oy ~= 0) then
                                imgui.SetCursorPos({ tx + ox, ty + oy });
                                imgui.Text(txt);
                            end
                        end
                    end
                    imgui.PopStyleColor();

                    imgui.SetCursorPos({ tx, ty });
                    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 0.72, 1.0 });
                    imgui.Text(txt);
                    imgui.PopStyleColor();

                    gResources.pop_font(pushedTimer);

                    bottomY = math.max(bottomY, ty + th);
                end
            end

            displayIndex = displayIndex + 1;
        end
    end

    imgui.SetCursorPos({ anchorX, bottomY });
    return bottomY;
end

local render = {}
render.render_compass = render_compass.render;

local get_party_member_y_offset = function(memberIndex)
    if(memberIndex <= 0)then
        return 0;
    end

    return (55 + gParty.layout.padding) * memberIndex;
end

local draw_member_target_markers = function(targetEntity, selectedTarget, selectedTargetActive, subTarget, memberIndex, member, targetTexture, subTargetTexture, markerSize)
    local markerX = (5 + gParty.layout.jobIconPos.x) * GlamourUI.settings.Party.pList.gui_scale;
    local markerY = (get_party_member_y_offset(memberIndex) + gParty.layout.jobIconPos.y) * GlamourUI.settings.Party.pList.gui_scale;

    if(targetEntity ~= nil and targetEntity.ServerId == member.Id)then
        imgui.SetCursorPosX(markerX);
        imgui.SetCursorPosY(markerY);
        imgui.Image(targetTexture, {markerSize, markerSize});
    end

    if((selectedTargetActive == true and selectedTarget == memberIndex) or subTarget.ServerId == member.Id)then
        imgui.SetCursorPosX(markerX);
        imgui.SetCursorPosY(markerY);
        imgui.Image(subTargetTexture, {markerSize, markerSize});
    end
end

local draw_member_buffs = function(member, yOffset, memberIndex)
    if(member.Buffs == nil)then
        return;
    end

    local plist = GlamourUI.settings.Party.pList;
    local guiScale = plist.gui_scale;
    local buffGuiScale = plist.buff_gui_scale;
    if (buffGuiScale == nil) then
        buffGuiScale = guiScale;
    end

    local iconSize = (20 * plist.buff_scale) * buffGuiScale;
    local anchorX = (30 + gParty.layout.BuffPos.x) * guiScale;

    local buffs = {};
    local debuffs = {};
    for i = 0,#member.Buffs do
        local buff = member.Buffs[i];
        if(buff == -1)then
            break;
        end

        if(gBuffs.IsBuff(buff) == true)then
            table.insert(buffs, buff);
        else
            table.insert(debuffs, buff);
        end
    end

    if (memberIndex == 0 and GlamourUI ~= nil and GlamourUI.PartyList ~= nil and GlamourUI.PartyList.BuffNav ~= nil) then
        local nav = GlamourUI.PartyList.BuffNav;
        if (nav.active == true) then
            nav.list = T{};
            for i = 1, #buffs do
                nav.list:insert(buffs[i]);
            end
            for i = 1, #debuffs do
                nav.list:insert(debuffs[i]);
            end
            if (#nav.list <= 0) then
                nav.index = 1;
            else
                nav.index = math.max(1, math.min(nav.index or 1, #nav.list));
            end

            if (GlamourUI.PartyList.BuffSelection ~= nil) then
                GlamourUI.PartyList.BuffSelection.memberIndex = 0;
                GlamourUI.PartyList.BuffSelection.statusId = nav.list[nav.index];
                GlamourUI.PartyList.BuffSelection.locked = true;
            end
        end
    end

    local buffTimerSecs = T{};
    local debuffTimerSecs = T{};
    if (memberIndex == 0) then
        buffTimerSecs, debuffTimerSecs = gResources.get_player_buff_timer_seconds_split();
    end

    local maxCol = 8;
    local maxRow = 2;
    local baseY = (yOffset + gParty.layout.BuffPos.y) * guiScale;
    local yNext = baseY;

    local timerForBuffRow = nil;
    local timerForDebuffRow = nil;
    if (memberIndex == 0) then
        timerForBuffRow = buffTimerSecs;
        timerForDebuffRow = debuffTimerSecs;
    end

    if (#buffs > 0) then
        yNext = draw_party_buff_icon_grid(buffs, iconSize, maxCol, maxRow, plist.buffTheme, anchorX, yNext, guiScale, buffGuiScale, timerForBuffRow, memberIndex);
        yNext = yNext + math.ceil(5 * guiScale);
    elseif (#debuffs > 0) then
        yNext = baseY + math.ceil(25 * guiScale);
    end

    if (#debuffs > 0) then
        yNext = draw_party_buff_icon_grid(debuffs, iconSize, maxCol, maxRow, plist.buffTheme, anchorX, yNext, guiScale, buffGuiScale, timerForDebuffRow, memberIndex);
    end
end

local draw_pet_degradation_bar = function(barTexture, fillTexture)
    if(gRecast.PetDeg.time <= 0)then
        return;
    end

    local progress = ((gRecast.PetDeg.endtime - gRecast.PetDeg.time) / gRecast.PetDeg.max);
    imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
    if(GlamourUI.settings.Party.pList.themed == true)then
        imgui.Image(barTexture, {200 * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale});
        imgui.SameLine();
        imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
        imgui.Image(fillTexture, {(200 * progress) * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {progress, 1});
    else
        imgui.ProgressBar(progress, {200 * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale}, '');
    end

    imgui.SameLine();
    imgui.SetCursorPosX((100 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
    imgui.Text(fmt_time(gRecast.PetDeg.endtime - gRecast.PetDeg.time));
end

local get_target_distance_text = function(targetEntity)
    return tostring(math.floor(math.sqrt(targetEntity.Distance) * 100) / 100);
end

local get_target_level_text = function(targetIndex, nameStatus)
    if(nameStatus == nil or nameStatus.type ~= 'mob')then
        return nil;
    end

    local charInfo = gPacket.CharInfo[targetIndex];
    if (charInfo ~= nil) then
        local ent = GetEntity(targetIndex);
        if (ent == nil or ent.ServerId == nil or ent.ServerId == 0) then
            gPacket.CharInfo[targetIndex] = nil;
            charInfo = nil;
        elseif (charInfo.ServerId ~= nil and charInfo.ServerId ~= 0 and ent.ServerId ~= charInfo.ServerId) then
            gPacket.CharInfo[targetIndex] = nil;
            charInfo = nil;
        end
    end
    local lv = charInfo ~= nil and tonumber(charInfo.Level) or nil;
    if(lv == nil or lv <= 0)then
        return nil;
    end

    return mobdb_jobs.format_level_text(lv, targetIndex);
end

local draw_target_name = function(targetIndex, targetEntity, nameStatus, guiScale)
    local levelText = get_target_level_text(targetIndex, nameStatus);
    local rawName = targetEntity.Name;
    local nameText, hadStar = mob_check.split_mob_name_prefix(rawName);
    if (not hadStar) then
        nameText, hadStar = mob_check.split_mob_name_prefix(ffxi_glyphs.normalize_mob_check_markers(rawName));
    end
    local starPart = ffxi_glyphs.mob_check_star_part();
    local starWidth = 0;
    if (hadStar) then
        starWidth = ffxi_glyphs.star_scaled_text_width(starPart.text);
    end
    local levelSep = '   '; -- gap between the mob name and its level/job text
    local textWidth = imgui.CalcTextSize(levelText ~= nil and (nameText .. levelSep .. levelText) or nameText) * GlamourUI.settings.PlayerStats.gui_scale;
    textWidth = textWidth + starWidth;
    local xOffset = (GlamourUI.settings.TargetBar.hpBarDim.l - textWidth) * 0.5;

    if(nameStatus ~= nil)then
        gTarget.push_nameplate_color(targetIndex);
    end

    local nameLift = (ffxi_glyphs.TARGET_BAR_NAME_Y_LIFT or 5) * guiScale;
    local baseY = imgui.GetCursorPosY();
    local baseX = imgui.GetCursorPosX();
    local rowX = xOffset * guiScale;
    local rowY = baseY - nameLift;
    local nameLineH = imgui.GetTextLineHeight();
    if (type(nameLineH) ~= 'number' or nameLineH <= 0) then
        nameLineH = imgui.GetFontSize() or 14;
    end

    if (hadStar) then
        ffxi_glyphs.draw_mob_check_star_beside_row(rowX, rowY, nameLineH);
    else
        imgui.SetCursorPos({ rowX, rowY });
    end
    imgui.Text(nameText);
    if(levelText ~= nil)then
        imgui.SameLine(0, 0);
        imgui.Text(levelSep .. levelText);
    end

    if(nameStatus ~= nil)then
        imgui.PopStyleColor();
    end

    -- Visual lift does not expand layout; reserve the lifted row plus accommodation
    -- so HP bar / percentage stay aligned below the name.
    imgui.SetCursorPos({ baseX, baseY });
    imgui.Dummy({ math.max(1, textWidth * guiScale), nameLineH + nameLift });
end

local draw_target_subtarget = function(subTarget, hpBarTexture, hpFillTexture, yOffset)
    if(subTarget == nil)then
        return;
    end

    local fontPushed = gResources.push_font_scale(0.4 * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar);
    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
    imgui.Text('Sub Target:   ');
    imgui.SameLine(0, 0);
    gTarget.push_nameplate_color(subTarget);
    local nameText, hadStar = mob_check.split_mob_name_prefix(subTarget.Name);
    if (not hadStar) then
        nameText, hadStar = mob_check.split_mob_name_prefix(ffxi_glyphs.normalize_mob_check_markers(subTarget.Name));
    end
    local rowX = imgui.GetCursorPosX();
    local rowY = imgui.GetCursorPosY();
    local nameLineH = imgui.GetTextLineHeight();
    if (type(nameLineH) ~= 'number' or nameLineH <= 0) then
        nameLineH = imgui.GetFontSize() or 14;
    end
    if (hadStar) then
        ffxi_glyphs.draw_mob_check_star_beside_row(rowX, rowY, nameLineH);
    else
        imgui.SetCursorPos({ rowX, rowY });
    end
    imgui.Text(nameText);
    imgui.PopStyleColor();
    local y = tonumber(yOffset) or (77 * GlamourUI.settings.TargetBar.gui_scale);
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(350 * GlamourUI.settings.TargetBar.gui_scale);

    if(GlamourUI.settings.TargetBar.themed == true)then
        imgui.Image(hpBarTexture, {(GlamourUI.settings.TargetBar.hpBarDim.l * 0.5), (GlamourUI.settings.TargetBar.hpBarDim.g * 0.5)});
        imgui.SameLine();
        imgui.SetCursorPosX(350 * GlamourUI.settings.TargetBar.gui_scale);
        imgui.Image(hpFillTexture, {(GlamourUI.settings.TargetBar.hpBarDim.l * 0.5 * (subTarget.HPPercent / 100)), (GlamourUI.settings.TargetBar.hpBarDim.g * 0.5)}, {0, 0}, {subTarget.HPPercent / 100, 1});
    else
        imgui.ProgressBar(subTarget.HPPercent / 100, {(GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale * 0.5), (GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale * 0.5)});
    end
    gResources.pop_font(fontPushed);
end

local draw_target_lock_indicator = function(lockedTexture, width, height)
    imgui.SetCursorPosX(0);
    imgui.SetCursorPosY(0);
    imgui.Image(lockedTexture, {width, height});
end

local get_focus_target_distance_text = function(targetEntity)
    return tostring(math.floor(math.sqrt(targetEntity.Distance) * 100) / 100);
end

local function env_icon_size(envSettings)
    local env = envSettings or (GlamourUI.settings and GlamourUI.settings.Env);
    if (env == nil) then
        return 15;
    end
    local guiScale = tonumber(env.gui_scale) or 1;
    local fontScale = tonumber(env.font_scale) or 1;
    return math.max(8, 25 * guiScale * fontScale * 0.6);
end

local draw_environment_weather = function(weatherInfo, iconSize)
    iconSize = tonumber(iconSize) or env_icon_size(GlamourUI.settings and GlamourUI.settings.Env);
    if(weatherInfo.Count == 0)then
        imgui.Text(weatherInfo.Type);
    elseif(weatherInfo.Count == 1)then
        imgui.Image(weatherInfo.Type, { iconSize, iconSize });
    elseif(weatherInfo.Count == 2)then
        imgui.Image(weatherInfo.Type, { iconSize, iconSize });
        imgui.SameLine();
        imgui.Image(weatherInfo.Type, { iconSize, iconSize });
    end
end

local draw_skill_row = function(skillName, skillData, valueOffset, rankText)
    imgui.Text(skillName);
    imgui.SameLine();
    imgui.SetCursorPosX(valueOffset);
    if(skillData:IsCapped())then
        imgui.PushStyleColor(ImGuiCol_Text, {0, 0.36, 0.79, 1});
    else
        imgui.PushStyleColor(ImGuiCol_Text, {1, 1, 1, 1});
    end
    imgui.Text(tostring(skillData:GetSkill()));
    imgui.PopStyleColor();

    if(rankText ~= nil)then
        imgui.SameLine();
        imgui.SetCursorPosX(valueOffset + 30);
        imgui.Text(rankText);
    end
end

local get_member_text_color = function(member)
    local color = member ~= nil and member.Color or nil;
    if(color == nil)then
        return {1.0, 1.0, 1.0, 1.0};
    end

    return {
        color[1] or color.r or 1.0,
        color[2] or color.g or 1.0,
        color[3] or color.b or 1.0,
        color[4] or color.a or 1.0,
    };
end

local get_window_suffix = function()
    if(gParty.Party[1] ~= nil and gParty.Party[1].Name ~= nil)then
        return gParty.Party[1].Name;
    end

    return 'Init';
end

local autoTranslateParenColor = {0.2, 1.0, 0.2, 1.0};
local autoTranslateCloseParenColor = {1.0, 0.2, 0.2, 1.0};
local autoTranslateTextColor = {1.0, 0.45, 0.65, 1.0};

local function normalize_display_text(text)
    if (text == nil or text == '') then
        return text;
    end
    text = tostring(text);
    if (gChat ~= nil and gChat.normalize_backslash_for_display ~= nil) then
        return gChat.normalize_backslash_for_display(text);
    end
    if (gChat ~= nil and gChat.normalize_sjis_yen_to_backslash ~= nil) then
        text = gChat.normalize_sjis_yen_to_backslash(text);
    end
    return text;
end

local at_item_cache = {};
local JOB_ABBR = {
    'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD',
    'RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH',
    'GEO','RUN',
};

local function jobs_from_bitmask(mask)
    local out = {};
    local m = tonumber(mask) or 0;
    for i = 1, #JOB_ABBR do
        if (bit.band(m, bit.lshift(1, i - 1)) ~= 0) then
            out[#out + 1] = JOB_ABBR[i];
        end
    end
    if (#out == 0) then
        return 'All Jobs';
    end
    return table.concat(out, ' ');
end

local function get_at_item_info(itemId)
    itemId = tonumber(itemId) or 0;
    if (itemId <= 0) then
        return nil;
    end
    local cached = at_item_cache[itemId];
    if (cached ~= nil) then
        return cached ~= false and cached or nil;
    end

    local res = AshitaCore:GetResourceManager();
    local item = res and res:GetItemById(itemId) or nil;
    if (item == nil) then
        at_item_cache[itemId] = false;
        return nil;
    end

    local name = (item.Name and item.Name[1]) or ('Item ' .. tostring(itemId));
    local desc = (item.Description and item.Description[1]) or '';
    local jobs = jobs_from_bitmask(item.Jobs);
    local level = tonumber(item.Level) or 0;
    local icon = (gResources and gResources.get_item_icon) and gResources.get_item_icon(itemId, item) or nil;

    local info = {
        id = itemId,
        name = tostring(name),
        desc = tostring(desc),
        jobs = tostring(jobs),
        level = level,
        icon = icon,
    };
    at_item_cache[itemId] = info;
    return info;
end

local function show_at_item_tooltip(itemId)
    local info = get_at_item_info(itemId);
    if (info == nil) then
        return;
    end
    if (imgui.BeginTooltip == nil) then
        return;
    end
    imgui.BeginTooltip();
    if (info.icon ~= nil) then
        imgui.Image(info.icon, { 32, 32 });
        imgui.SameLine();
    end
    imgui.Text(info.name);
    if (info.desc ~= nil and info.desc ~= '') then
        imgui.Separator();
        imgui.TextWrapped(info.desc);
    end
    imgui.Separator();
    if (info.level ~= nil and info.level > 0) then
        imgui.Text(('Lv. %d'):fmt(info.level));
    end
    imgui.Text(info.jobs);
    imgui.EndTooltip();
end

local function make_auto_translate_segment(tokenText)
    return {
        text = '(' .. tokenText .. ')',
        atomic = true,
        parts = {
            { text = '(', color = autoTranslateParenColor },
            { text = tokenText, color = autoTranslateTextColor },
            { text = ')', color = autoTranslateCloseParenColor },
        }
    };
end

local function make_auto_translate_item_segment(tokenText, itemId)
    return {
        text = '(' .. tokenText .. ')',
        atomic = true,
        parts = {
            { text = '(', color = autoTranslateParenColor },
            { text = tokenText, color = autoTranslateTextColor, draw = 'autotranslate_item', itemId = itemId },
            { text = ')', color = autoTranslateCloseParenColor },
        }
    };
end

local function make_chat_item_link_segment(tokenText, itemId, color)
    return {
        text = tokenText,
        atomic = true,
        parts = {
            { text = tokenText, color = color, draw = 'chat_item_link', itemId = itemId },
        },
    };
end

local chat_item_hover_id = 0;
local chat_item_hover_regions = {};

local function point_in_item_rect(mx, my, rmin, rmax)
    local x1 = tonumber(rmin[1]) or tonumber(rmin.x);
    local y1 = tonumber(rmin[2]) or tonumber(rmin.y);
    local x2 = tonumber(rmax[1]) or tonumber(rmax.x);
    local y2 = tonumber(rmax[2]) or tonumber(rmax.y);
    if (x1 == nil or y1 == nil or x2 == nil or y2 == nil) then
        return false;
    end
    return mx >= x1 and mx <= x2 and my >= y1 and my <= y2;
end

local function register_chat_item_hover_region(itemId)
    itemId = tonumber(itemId) or 0;
    if (itemId <= 0 or imgui.GetItemRectMin == nil or imgui.GetItemRectMax == nil) then
        return;
    end
    local rmin = { imgui.GetItemRectMin() };
    local rmax = { imgui.GetItemRectMax() };
    chat_item_hover_regions[#chat_item_hover_regions + 1] = {
        itemId = itemId,
        min = rmin,
        max = rmax,
    };
end

local function draw_chat_item_hovered_text(p, partText)
    partText = normalize_display_text(partText);
    if (partText == nil or partText == '') then
        return;
    end

    local itemId = tonumber(p.itemId) or 0;
    chat_item_hover_id = chat_item_hover_id + 1;
    imgui.PushID((itemId * 100000) + chat_item_hover_id);
    imgui.TextColored(p.color or { 1.0, 1.0, 1.0, 1.0 }, partText);
    register_chat_item_hover_region(itemId);
    imgui.PopID();
end

local function poll_chat_item_hover_regions()
    if (#chat_item_hover_regions == 0 or imgui.GetMousePos == nil) then
        return;
    end

    local mx, my = imgui.GetMousePos();
    if (type(mx) == 'table') then
        my = tonumber(mx[2]) or tonumber(mx.y);
        mx = tonumber(mx[1]) or tonumber(mx.x);
    end
    if (mx == nil or my == nil) then
        return;
    end

    for ri = 1, #chat_item_hover_regions do
        local region = chat_item_hover_regions[ri];
        if (region ~= nil and point_in_item_rect(mx, my, region.min, region.max)) then
            show_at_item_tooltip(region.itemId);
            return;
        end
    end
end

local function begin_chat_item_hover_pass()
    chat_item_hover_id = 0;
    chat_item_hover_regions = {};
end

local function build_message_segments(message, defaultColor)
    local segments = {};
    local startIndex = 1;

    while (startIndex <= #message) do
        local openIndex = message:find('{', startIndex, true);
        if (openIndex == nil) then
            local tail = message:sub(startIndex);
            if (#tail > 0) then
                table.insert(segments, { text = tail, color = defaultColor });
            end
            break;
        end

        if (openIndex > startIndex) then
            table.insert(segments, {
                text = message:sub(startIndex, openIndex - 1),
                color = defaultColor
            });
        end

        local closeIndex = message:find('}', openIndex + 1, true);
        if (closeIndex == nil) then
            table.insert(segments, {
                text = message:sub(openIndex),
                color = defaultColor
            });
            break;
        end

        local tokenText = message:sub(openIndex + 1, closeIndex - 1);
        local tokenSegment = make_auto_translate_segment(tokenText);
        tokenSegment.color = defaultColor;
        table.insert(segments, tokenSegment);

        startIndex = closeIndex + 1;
    end

    return segments;
end

local function build_raw_message_segments(rawMessage, defaultColor)
    if (rawMessage == nil or #rawMessage == 0) then
        return nil;
    end

    local segments = {};
    local buffer = {};
    local bufferStart = nil;
    local currentColor = defaultColor;

    local function flush_buffer(endIndex)
        if (#buffer == 0) then
            return;
        end

        local decoded = gChat.clean_str(table.concat(buffer));
        if (#decoded > 0) then
            table.insert(segments, {
                rawStart = bufferStart,
                rawEnd = endIndex,
                text = decoded,
                color = currentColor,
            });
        end

        buffer = {};
        bufferStart = nil;
    end

    local i = 1;
    while (i <= #rawMessage) do
        local b = rawMessage:byte(i);

        if (b == 0x1F and (i + 1) <= #rawMessage) then
            local modePrefix = rawMessage:byte(i + 1);
            if (modePrefix == 0x7F or modePrefix == 0x79 or modePrefix == 0x83) then
                flush_buffer(i - 1);
                i = i + 2;
            else
                if (bufferStart == nil) then
                    bufferStart = i;
                end
                buffer[#buffer + 1] = rawMessage:sub(i, i);
                i = i + 1;
            end
        elseif (b == 0x1E and (i + 1) <= #rawMessage) then
            flush_buffer(i - 1);
            local code = rawMessage:byte(i + 1);
            if (code == 0x01) then
                currentColor = defaultColor;
            else
                currentColor = gChat.get_code_color(code, defaultColor);
            end
            i = i + 2;
        elseif (b == 0xAB) then
            flush_buffer(i - 1);
            table.insert(segments, ffxi_glyphs.make_mob_check_prefix_segment(i, ffxi_glyphs.STAR_COLOR));
            i = i + 1;
        elseif (b == 0xFD) then
            flush_buffer(i - 1);

            if ((i + 5) <= #rawMessage and rawMessage:byte(i + 5) == 0xFD) then
                local b1 = rawMessage:byte(i + 1);
                local b2 = rawMessage:byte(i + 2);

                if (b1 == 0x07 and b2 == 0x02) then
                    local hi = rawMessage:byte(i + 3);
                    local lo = rawMessage:byte(i + 4);
                    local itemId = (hi * 256) + lo;
                    local cleanedToken = gChat.clean_str(rawMessage:sub(i, i + 5));
                    local tokenText;
                    if (#cleanedToken > 1 and cleanedToken:sub(1, 1) == '{' and cleanedToken:sub(-1) == '}') then
                        tokenText = cleanedToken:sub(2, -2);
                    elseif (#cleanedToken > 0) then
                        tokenText = cleanedToken;
                    else
                        local info = get_at_item_info(itemId);
                        tokenText = (info ~= nil and info.name) or tostring(itemId);
                    end
                    local tokenSegment = make_auto_translate_item_segment(tokenText, itemId);
                    tokenSegment.rawStart = i;
                    tokenSegment.rawEnd = i + 5;
                    tokenSegment.color = currentColor;
                    table.insert(segments, tokenSegment);
                    i = i + 6;
                elseif (b1 == 0x02 and b2 == 0x02) then
                    local cleanedToken = gChat.clean_str(rawMessage:sub(i, i + 5));
                    if (#cleanedToken > 1 and cleanedToken:sub(1, 1) == '{' and cleanedToken:sub(-1) == '}') then
                        local tokenSegment = make_auto_translate_segment(cleanedToken:sub(2, -2));
                        tokenSegment.rawStart = i;
                        tokenSegment.rawEnd = i + 5;
                        tokenSegment.color = currentColor;
                        table.insert(segments, tokenSegment);
                    elseif (#cleanedToken > 0) then
                        table.insert(segments, {
                            rawStart = i,
                            rawEnd = i + 5,
                            text = cleanedToken,
                            color = currentColor,
                        });
                    end
                    i = i + 6;
                else
                    i = i + 1;
                end
            else
                i = i + 1;
            end
        elseif (b == 0x7F and (i + 1) <= #rawMessage) then
            flush_buffer(i - 1);
            i = i + 2;
        else
            local charLen = 1;
            if ((b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC)) and (i + 1) <= #rawMessage then
                charLen = 2;
            end
            if (bufferStart == nil) then
                bufferStart = i;
            end
            buffer[#buffer + 1] = rawMessage:sub(i, i + charLen - 1);
            i = i + charLen;
        end
    end

    flush_buffer(#rawMessage);

    if (#segments == 0) then
        return nil;
    end

    return segments;
end

local function normalize_raw_caret_index(rawMessage, caretRaw)
    local len = #(rawMessage or '');
    caretRaw = math.floor(tonumber(caretRaw) or 0);
    -- IChatManager::GetInputTextRawCaretPosition is 0-based (0 = start, len = end).
    caretRaw = caretRaw + 1;
    if (caretRaw < 1) then
        caretRaw = 1;
    elseif (caretRaw > len + 1) then
        caretRaw = len + 1;
    end
    return caretRaw;
end

local function input_segment_to_token(seg, defaultColor)
    if (seg == nil) then
        return nil;
    end
    if (seg.atomic == true and seg.parts ~= nil) then
        return {
            text = normalize_display_text(seg.text),
            color = seg.color or defaultColor,
            atomic = true,
            parts = seg.parts,
        };
    end
    return {
        text = normalize_display_text(seg.text),
        color = seg.color or defaultColor,
    };
end

local function normalize_star_markers_in_text(text)
    if (text == nil or text == '') then
        return text;
    end
    text = normalize_display_text(text);
    return ffxi_glyphs.normalize_mob_check_markers(text);
end

local function make_empty_star_wrap_token(_starColor)
    return ffxi_glyphs.make_mob_check_star_wrap_token();
end

local function append_plain_text_wrap_tokens(tokens, text, color)
    if (text == nil or text == '') then
        return;
    end
    local chunkIndex = 1;
    local chunk = text;
    while (chunkIndex <= #chunk) do
        local spos, epos = chunk:find('%s+', chunkIndex);
        if (spos == chunkIndex) then
            table.insert(tokens, {
                text = chunk:sub(spos, epos),
                color = color,
                newline = false,
                atomic = false
            });
            chunkIndex = epos + 1;
        else
            local _, wordEnd, tokenText = chunk:find('([^%s]+%s*)', chunkIndex);
            if (tokenText == nil) then
                break;
            end
            table.insert(tokens, {
                text = tokenText,
                color = color,
                newline = false,
                atomic = false
            });
            chunkIndex = wordEnd + 1;
        end
    end
end

local function append_segment_text_as_wrap_tokens(tokens, text, color)
    if (text == nil or text == '') then
        return;
    end
    text = normalize_star_markers_in_text(text);
    local i = 1;
    while (i <= #text) do
        local pos, len = ffxi_glyphs.find_next_mob_check_star(text, i);
        if (pos == nil) then
            append_plain_text_wrap_tokens(tokens, text:sub(i), color);
            break;
        end
        if (pos > i) then
            append_plain_text_wrap_tokens(tokens, text:sub(i, pos - 1), color);
        end
        table.insert(tokens, make_empty_star_wrap_token());
        i = pos + len;
    end
end

local function imgui_calc_line_height()
    local h = imgui.GetTextLineHeightWithSpacing();
    if (type(h) == 'number') then
        return math.max(1, h);
    end
    if (type(h) == 'table') then
        local n = tonumber(h[2]) or tonumber(h.y);
        if (n ~= nil and n > 0) then
            return n;
        end
    end
    local fs = imgui.GetFontSize();
    if (type(fs) == 'number') then
        return math.max(1, fs + 2);
    end
    return 14;
end

local function draw_check_outlined_text(part)
    local partText = normalize_display_text(part.text or '');
    if (partText == '') then
        return;
    end
    local tw = imgui_calc_text_width(partText);
    local lh = imgui_calc_line_height();
    local tl = { imgui.GetCursorScreenPos() };
    local dl = imgui.GetWindowDrawList();
    local fillCol = imgui.GetColorU32(part.color or { 0.18, 0.18, 0.18, 1.0 });
    local glowBase = part.glowColor or part.outlineColor or { 1.0, 1.0, 1.0, 1.0 };
    if (dl.AddText ~= nil) then
        local glowLayers = {
            { radius = 3, alpha = 0.07 },
            { radius = 2, alpha = 0.12 },
            { radius = 1, alpha = 0.20 },
        };
        for li = 1, #glowLayers do
            local layer = glowLayers[li];
            local r = layer.radius;
            local glowCol = imgui.GetColorU32({
                glowBase[1] or 1.0,
                glowBase[2] or 1.0,
                glowBase[3] or 1.0,
                layer.alpha,
            });
            for ox = -r, r do
                for oy = -r, r do
                    if (ox ~= 0 or oy ~= 0) then
                        dl:AddText({ tl[1] + ox, tl[2] + oy }, glowCol, partText);
                    end
                end
            end
        end
        dl:AddText(tl, fillCol, partText);
    else
        imgui.TextColored(part.color or { 0.18, 0.18, 0.18, 1.0 }, partText);
        tw = imgui_calc_text_width(partText);
    end
    imgui.Dummy({ tw, lh });
end

local function imgui_get_item_spacing_x()
    if (imgui.GetStyle ~= nil) then
        local style = imgui.GetStyle();
        if (style ~= nil and style.ItemSpacing ~= nil) then
            if (type(style.ItemSpacing) == 'table') then
                return tonumber(style.ItemSpacing[1]) or tonumber(style.ItemSpacing.x) or 4;
            end
        end
    end
    return 4;
end

local function raw_message_has_color_codes(rawMessage)
    if (rawMessage == nil or #rawMessage == 0) then
        return false;
    end
    if (rawMessage:find(string.char(0x1E), 1, true) ~= nil) then
        return true;
    end
    if (rawMessage:find(string.char(0xFD), 1, true) ~= nil) then
        return true;
    end
    if (rawMessage:find(string.char(0x1F), 1, true) ~= nil) then
        return true;
    end
    return false;
end

local function get_chat_draw_tokens(entry, message, rawMessage, defaultColor, prebuiltSegments)
    local segTag = (prebuiltSegments ~= nil) and ('s' .. tostring(#prebuiltSegments)) or 'n';
    local partyStamp = chatPartyNames.is_enabled() and tostring(chatPartyNames.get_roster_cache_stamp()) or 'off';
    local cacheKey = segTag .. '|v15|' .. partyStamp .. '|' .. tostring(message or '') .. '|' .. tostring(rawMessage ~= nil and #rawMessage or 0);

    if (entry ~= nil and entry._chatTokenCacheKey == cacheKey and entry._chatDrawTokens ~= nil) then
        return entry._chatDrawTokens;
    end

    local segments = prebuiltSegments;
    if (segments == nil) then
        if (raw_message_has_color_codes(rawMessage)) then
            segments = build_raw_message_segments(rawMessage, defaultColor);
        elseif (message ~= nil and message ~= '') then
            segments = build_message_segments(message, defaultColor);
        elseif (rawMessage ~= nil and #rawMessage > 0) then
            segments = build_raw_message_segments(rawMessage, defaultColor);
        end
    end
    if (segments == nil) then
        segments = build_message_segments(message or '', defaultColor);
    end

    if (chatPartyNames.is_enabled() and (entry == nil or entry.customChat ~= true)) then
        segments = chatPartyNames.apply_to_segments(segments, message, defaultColor);
    end

    local tokens = {};
    for i = 1, #segments do
        local text = segments[i].text;
        local color = segments[i].color;

        if (segments[i].atomic == true) then
            table.insert(tokens, {
                text = normalize_display_text(text),
                color = color,
                newline = false,
                atomic = true,
                parts = segments[i].parts
            });
        else
            local index = 1;

            while (index <= #text) do
                local char = text:sub(index, index);
                if (char == '\n') then
                    table.insert(tokens, { text = '\n', color = color, newline = true });
                    index = index + 1;
                else
                    local nextNewline = text:find('\n', index, true);
                    local chunkEnd = nextNewline and (nextNewline - 1) or #text;
                    local chunk = text:sub(index, chunkEnd);
                    append_segment_text_as_wrap_tokens(tokens, chunk, color);

                    index = chunkEnd + 1;
                end
            end
        end
    end

    if (entry ~= nil) then
        entry._chatTokenCacheKey = cacheKey;
        entry._chatDrawTokens = tokens;
    end

    return tokens;
end

local function calc_chat_token_width(token)
    if (token.atomic == true and token.parts ~= nil) then
        local tokenWidth = 0;
        for pi = 1, #token.parts do
            local p = token.parts[pi];
            if (p ~= nil and p.draw == 'bust_x') then
                local lh = imgui_calc_line_height();
                local scale = tonumber(p.size_scale) or 1.15;
                local em = tonumber(p.width_em) or 1.2;
                tokenWidth = tokenWidth + (lh * scale * em);
            elseif (p ~= nil and p.draw == 'roll_badge') then
                local lh = imgui_calc_line_height();
                local scale = tonumber(p.size_scale) or 1.10;
                local em = tonumber(p.width_em) or 1.35;
                tokenWidth = tokenWidth + (lh * scale * em);
            elseif (ffxi_glyphs.star_part_is_star(p)) then
                tokenWidth = tokenWidth + ffxi_glyphs.star_scaled_text_width(p.text);
            elseif (ffxi_glyphs.empty_star_part_is_star(p)) then
                tokenWidth = tokenWidth + ffxi_glyphs.star_scaled_text_width(p.text);
            else
                tokenWidth = tokenWidth + imgui_calc_text_width(p.text);
            end
        end
        return tokenWidth;
    end
    return imgui_calc_text_width(token.text);
end

local function draw_chat_token_part(p)
    if (p ~= nil and p.draw == 'bust_x') then
        local lh = imgui_calc_line_height();
        local scale = tonumber(p.size_scale) or 1.15;
        local size = lh * scale;
        local width = size * (tonumber(p.width_em) or 1.2);
        local tl = { imgui.GetCursorScreenPos() };
        local br = { tl[1] + width, tl[2] + size };
        local dl = imgui.GetWindowDrawList();
        local col = imgui.GetColorU32(p.color or { 0.95, 0.20, 0.20, 1.0 });
        local pad = math.max(1.0, size * 0.12);
        dl:AddLine({ tl[1] + pad, tl[2] + pad }, { br[1] - pad, br[2] - pad }, col, math.max(1.0, size * 0.12));
        dl:AddLine({ tl[1] + pad, br[2] - pad }, { br[1] - pad, tl[2] + pad }, col, math.max(1.0, size * 0.12));
        imgui.Dummy({ width, size });
    elseif (p ~= nil and p.draw == 'roll_badge') then
        local lh = imgui_calc_line_height();
        local scale = tonumber(p.size_scale) or 1.10;
        local size = lh * scale;
        local width = size * (tonumber(p.width_em) or 1.35);
        local tl = { imgui.GetCursorScreenPos() };
        local br = { tl[1] + width, tl[2] + size };
        local dl = imgui.GetWindowDrawList();

        local borderCol = imgui.GetColorU32(p.color or { 1.0, 1.0, 1.0, 1.0 });
        local fillCol = imgui.GetColorU32({ 0.05, 0.05, 0.05, 0.65 });

        local cx = (tl[1] + br[1]) * 0.5;
        local cy = (tl[2] + br[2]) * 0.5;
        local r = math.min(width, size) * 0.48;
        local thick = math.max(1.0, size * 0.08);

        if (dl.AddCircleFilled ~= nil and dl.AddCircle ~= nil) then
            dl:AddCircleFilled({ cx, cy }, r, fillCol, 24);
            dl:AddCircle({ cx, cy }, r, borderCol, 24, thick);
        else
            dl:AddRectFilled(tl, br, fillCol, r, 0);
            dl:AddRect(tl, br, borderCol, r, 0, thick);
        end

        local rollText = tostring(p.roll or '');
        local tw, th = imgui.CalcTextSize(rollText);
        if (type(tw) == 'table') then
            th = tonumber(tw[2]) or tonumber(tw.y) or (size * 0.6);
            tw = tonumber(tw[1]) or tonumber(tw.x) or (width * 0.6);
        end
        local tx = cx - (tonumber(tw) or 0) * 0.5;
        local ty = cy - (tonumber(th) or 0) * 0.5;

        local textCol = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
        if (dl.AddText ~= nil) then
            textShadow.draw_list_add_text_shadowed(imgui, dl, { tx, ty }, textCol, rollText);
        end

        imgui.Dummy({ width, size });
    elseif (ffxi_glyphs.star_part_is_star(p)) then
        ffxi_glyphs.draw_star_text(p.color, p.text);
    elseif (ffxi_glyphs.empty_star_part_is_star(p)) then
        ffxi_glyphs.draw_mob_check_star_part(p);
    elseif (p ~= nil and p.draw == 'check_outlined') then
        draw_check_outlined_text(p);
    else
        local partText = normalize_display_text(p.text);
        if (p ~= nil and (p.draw == 'autotranslate_item' or p.draw == 'chat_item_link') and p.itemId ~= nil) then
            draw_chat_item_hovered_text(p, partText);
        else
            imgui.TextColored(p.color, partText);
        end
    end
end

local function draw_chat_token(token, firstOnLine)
    if (not firstOnLine) then
        imgui.SameLine(0, 0);
    end

    if (token.atomic == true and token.parts ~= nil) then
        for partIndex = 1, #token.parts do
            if (partIndex > 1) then
                imgui.SameLine(0, 0);
            end
            draw_chat_token_part(token.parts[partIndex]);
        end
    elseif (token.text == ffxi_glyphs.STAR_CHAR or token.text == ffxi_glyphs.STAR_FALLBACK) then
        ffxi_glyphs.draw_star_text(token.color, token.text);
    elseif (token.text == ffxi_glyphs.EMPTY_STAR_CHAR or token.text == ffxi_glyphs.EMPTY_STAR_FALLBACK) then
        ffxi_glyphs.draw_mob_check_star_part();
    else
        imgui.TextColored(token.color, token.text);
    end

    return calc_chat_token_width(token);
end

local function draw_dl_colored_text(dl, x, y, color, text)
    text = normalize_display_text(text);
    if (text == nil or text == '') then
        return 0;
    end
    local col = imgui.GetColorU32(color or { 1.0, 1.0, 1.0, 1.0 });
    if (textShadow ~= nil and textShadow.draw_list_add_text_shadowed ~= nil) then
        textShadow.draw_list_add_text_shadowed(imgui, dl, { x, y }, col, text);
    elseif (dl.AddText ~= nil) then
        dl:AddText({ x, y }, col, text);
    end
    return imgui_calc_text_width(text);
end

local function draw_dl_atomic_token(dl, x, y, token)
    if (token == nil or token.parts == nil) then
        return 0;
    end
    local w = 0;
    for pi = 1, #token.parts do
        local p = token.parts[pi];
        if (p ~= nil) then
            w = w + draw_dl_colored_text(dl, x + w, y, p.color, p.text);
        end
    end
    return w;
end

local function draw_input_text_line(rawMessage, caretRaw, defaultColor)
    local dl = imgui.GetWindowDrawList();
    if (dl == nil) then
        return;
    end

    local caretByte = normalize_raw_caret_index(rawMessage, caretRaw);
    local segments = build_raw_message_segments(rawMessage, defaultColor);
    if (segments == nil and rawMessage ~= nil and #rawMessage > 0) then
        segments = {
            {
                rawStart = 1,
                rawEnd = #rawMessage,
                text = gChat.clean_str(rawMessage),
                color = defaultColor,
            },
        };
    end
    if (segments == nil) then
        segments = {};
    end

    local origin = { imgui.GetCursorScreenPos() };
    local x = origin[1];
    local y = origin[2];
    local lh = imgui_calc_line_height();
    local caretW = math.max(2.0, lh * 0.08);
    local caretShown = false;

    local function show_caret()
        if (caretShown) then
            return;
        end
        local blinkOn = (math.floor(os.clock() * 2.0) % 2) == 0;
        if (blinkOn and dl.AddRectFilled ~= nil) then
            local col = imgui.GetColorU32(defaultColor or { 1.0, 1.0, 1.0, 1.0 });
            dl:AddRectFilled({ x, y }, { x + caretW, y + lh }, col);
        end
        x = x + caretW;
        caretShown = true;
    end

    for si = 1, #segments do
        local seg = segments[si];
        local rawStart = tonumber(seg.rawStart) or 1;
        local rawEnd = tonumber(seg.rawEnd) or rawStart;

        if (not caretShown and caretByte <= rawStart) then
            show_caret();
        end

        if (seg.atomic == true and seg.parts ~= nil) then
            local token = input_segment_to_token(seg, defaultColor);
            if (token ~= nil) then
                x = x + draw_dl_atomic_token(dl, x, y, token);
                if (not caretShown and caretByte > rawStart and caretByte <= rawEnd + 1) then
                    show_caret();
                end
            end
        elseif (caretByte > rawStart and caretByte <= rawEnd + 1) then
            local beforeRaw = '';
            local afterRaw = '';
            if (caretByte > rawStart) then
                beforeRaw = rawMessage:sub(rawStart, caretByte - 1);
            end
            if (caretByte <= rawEnd) then
                afterRaw = rawMessage:sub(caretByte, rawEnd);
            end
            local beforeText = (beforeRaw ~= '') and gChat.clean_str(beforeRaw) or '';
            local afterText = (afterRaw ~= '') and gChat.clean_str(afterRaw) or '';
            if (beforeText ~= '') then
                x = x + draw_dl_colored_text(dl, x, y, seg.color or defaultColor, beforeText);
            end
            show_caret();
            if (afterText ~= '') then
                x = x + draw_dl_colored_text(dl, x, y, seg.color or defaultColor, afterText);
            end
        else
            local text = seg.text or '';
            if (text ~= '') then
                x = x + draw_dl_colored_text(dl, x, y, seg.color or defaultColor, text);
            end
        end
    end

    if (not caretShown) then
        show_caret();
    end

    imgui.Dummy({ math.max(caretW, x - origin[1]), lh });
end

local function draw_chat_message(entry, message, rawMessage, defaultColor, prebuiltSegments)
    local avail = imgui.GetContentRegionAvail();
    local availW = imgui.GetWindowWidth() - imgui.GetCursorPosX() - 20;
    if (type(avail) == 'table') then
        availW = tonumber(avail[1]) or tonumber(avail.x) or availW;
    elseif (type(avail) == 'number') then
        availW = avail;
    end
    local wrapWidth = math.max(32, availW);
    local tokens = get_chat_draw_tokens(entry, message, rawMessage, defaultColor, prebuiltSegments);

    local startX = imgui.GetCursorPosX();
    local bodyStartY = imgui.GetCursorPosY();
    local wrapLineIdx = 0;
    local lineWidth = 0;
    local firstOnLine = true;

    local function advance_line()
        wrapLineIdx = wrapLineIdx + 1;
        lineWidth = 0;
        firstOnLine = true;
        local lh = imgui_calc_line_height();
        imgui.SetCursorPos({ startX, bodyStartY + wrapLineIdx * lh });
    end

    local pushedTextWrap = false;
    if (imgui.PushTextWrapPos ~= nil and imgui.PopTextWrapPos ~= nil) then
        imgui.PushTextWrapPos(-1.0);
        pushedTextWrap = true;
    end

    for ti = 1, #tokens do
        local token = tokens[ti];

        if (token.newline) then
            advance_line();
        else
            local tokenWidth = calc_chat_token_width(token);

            local trimmed = token.text:gsub('%s+$', '');
            local isWhitespaceOnly = (trimmed == '');

            if (not isWhitespaceOnly and lineWidth > 0 and (lineWidth + tokenWidth) > wrapWidth) then
                advance_line();
            end

            draw_chat_token(token, firstOnLine);

            lineWidth = lineWidth + tokenWidth;
            firstOnLine = false;
        end
    end

    if (pushedTextWrap == true) then
        imgui.PopTextWrapPos();
    end
end

local function draw_inline_name_segments(nameSegments, fallbackColor)
    if (nameSegments == nil or #nameSegments == 0) then
        imgui.TextColored(fallbackColor, '');
        return;
    end
    for i = 1, #nameSegments do
        if (i > 1) then
            imgui.SameLine(0, 0);
        end
        imgui.TextColored(nameSegments[i].color or fallbackColor, nameSegments[i].text or '');
    end
end

local function should_show_purpose_tag(entry, purpose)
    if (entry ~= nil and entry.channel == 'combat') then
        return false;
    end
    return purpose ~= 'None';
end

local function draw_sender_label(entry, purposeColor)
    local sender = entry.sender;
    if (sender == nil or sender == '' or sender == 'System' or sender == 'Battle' or sender == 'Check') then
        return false;
    end
    local nameSegs = chatPartyNames.is_enabled() and chatPartyNames.get_party_member_name_segments(sender) or nil;
    if (nameSegs ~= nil) then
        draw_inline_name_segments(nameSegs, purposeColor);
        imgui.SameLine(0, 0);
        imgui.TextColored(purposeColor, ':');
        imgui.SameLine();
        return true;
    end
    imgui.TextColored(purposeColor, (sender or '') .. ':');
    imgui.SameLine();
    return true;
end

local render_chat_entry = function(entry)
    local purpose = entry.purpose or 'None';
    local purposeColor = gChat.get_purpose_color(purpose);

    imgui.PushStyleColor(ImGuiCol_Text, {0.45, 0.3, 0.9, 1.0});
    imgui.Text(entry.time or '');
    imgui.PopStyleColor();
    imgui.SameLine();

    if (purpose == 'Tell' and entry.tellDirection ~= nil and entry.tellName ~= nil and entry.tellName ~= '') then
        imgui.TextColored(purposeColor, ('[' .. purpose .. ']'));
        imgui.SameLine();
        local arrow = '→';
        local tellSegs = chatPartyNames.is_enabled() and chatPartyNames.get_party_member_name_segments(entry.tellName) or nil;
        if (entry.tellDirection == 'out') then
            imgui.TextColored(purposeColor, arrow);
            imgui.SameLine(0, 0);
            if (tellSegs ~= nil) then
                draw_inline_name_segments(tellSegs, purposeColor);
            else
                imgui.TextColored(purposeColor, entry.tellName);
            end
            imgui.SameLine(0, 0);
            imgui.TextColored(purposeColor, ' : ');
        else
            if (tellSegs ~= nil) then
                draw_inline_name_segments(tellSegs, purposeColor);
            else
                imgui.TextColored(purposeColor, entry.tellName);
            end
            imgui.SameLine(0, 0);
            imgui.TextColored(purposeColor, (' ' .. arrow .. ' : '));
        end
        imgui.SameLine();
        draw_chat_message(entry, entry.message, entry.rawMessage, purposeColor, entry.segments);
        return;
    end

    if (should_show_purpose_tag(entry, purpose)) then
        local tag = entry.purposeLabel or ('[' .. purpose .. ']');
        imgui.TextColored(purposeColor, tag);
        imgui.SameLine();
    end

    draw_sender_label(entry, purposeColor);

    draw_chat_message(entry, entry.message, entry.rawMessage, purposeColor, entry.segments);
end

local function render_chat_entries_loop(chatList, stickToBottom)
    local mc = #chatList;
    if (mc <= 0) then
        return;
    end

    for i = 1, mc do
        render_chat_entry(chatList[i]);
        if (stickToBottom == true) then
            local sm = imgui.GetScrollMaxY();
            if (sm >= 0) then
                imgui.SetScrollY(sm);
            end
        end
    end
end

local function render_chat_entry_list(chatList, stickToBottom)
    begin_chat_item_hover_pass();
    render_chat_entries_loop(chatList, stickToBottom);

    local sm = imgui.GetScrollMaxY();
    if (sm < 0) then
        return;
    end

    if (stickToBottom == true) then
        imgui.SetScrollY(sm);
        poll_chat_item_hover_regions();
        return;
    end

    poll_chat_item_hover_regions();

    local sy = imgui.GetScrollY();
    if (sy > sm + 0.5) then
        imgui.SetScrollY(sm);
    elseif (sy >= sm - 2) then
        if (imgui.SetScrollHereY ~= nil) then
            imgui.SetScrollHereY(1.0);
        else
            imgui.SetScrollY(sm);
        end
    end
end

local function get_client_window_height()
    local fallback = 1080;
    do
        local io = imgui.GetIO and imgui.GetIO() or nil;
        if (io ~= nil and io.DisplaySize ~= nil) then
            local ds = io.DisplaySize;
            local h = tonumber(ds[2]) or tonumber(ds.y);
            if (h ~= nil and h > 0) then
                fallback = h;
            end
        end
    end
    if (imgui.GetMainViewport ~= nil) then
        local mv = imgui.GetMainViewport();
        if (mv ~= nil and type(mv) == 'table') then
            local sz = mv.Size or mv.WorkSize;
            if (type(sz) == 'table') then
                local h = tonumber(sz[2]) or tonumber(sz.y);
                if (h ~= nil and h > 0) then
                    return h;
                end
            end
        end
    end
    local ok, gm = pcall(function()
        return AshitaCore:GetGuiManager();
    end);
    if (ok and gm ~= nil and gm.GetMainViewport ~= nil) then
        local mv = gm.GetMainViewport();
        if (mv ~= nil and type(mv) == 'table') then
            local sz = mv.Size or mv.WorkSize;
            if (type(sz) == 'table') then
                local h = tonumber(sz[2]) or tonumber(sz.y);
                if (h ~= nil and h > 0) then
                    return h;
                end
            end
        end
    end
    return fallback;
end

local EXPAND_TAB_LABELS = { 'Chat 1', 'Chat 2', 'Say', 'Party', 'LS1', 'LS2', 'Shout', 'Yell' };

local function get_expand_chat_list(tabIdx)
    local ti = tonumber(tabIdx) or 1;
    if (ti == 1) then
        return gChat.get_window_entries(1);
    end
    if (ti == 2) then
        return gChat.get_window_entries(2);
    end
    local purposeMap = {
        [3] = 'Say',
        [4] = 'Party',
        [5] = 'LS[1]',
        [6] = 'LS[2]',
        [7] = 'Shout',
        [8] = 'Yell',
    };
    local p = purposeMap[ti];
    if (p ~= nil and gChat.get_entries_for_purpose ~= nil) then
        return gChat.get_entries_for_purpose(p);
    end
    return T{};
end

local expand_winkey_getstate_fn = nil;

local function expand_get_winkey_getstate()
    if (expand_winkey_getstate_fn == false) then
        return nil;
    end
    if (expand_winkey_getstate_fn == nil) then
        local ok, ffi = pcall(require, 'ffi');
        if (not ok or ffi == nil) then
            expand_winkey_getstate_fn = false;
            return nil;
        end
        local ok2 = pcall(function()
            ffi.cdef[[ short GetKeyState(int32_t vkey); ]];
        end);
        if (not ok2) then
            expand_winkey_getstate_fn = false;
            return nil;
        end
        expand_winkey_getstate_fn = ffi.C.GetKeyState;
    end
    return expand_winkey_getstate_fn;
end

local function expand_vk_high_bit(vk)
    local gs = expand_get_winkey_getstate();
    if (gs == nil) then
        return false;
    end
    local ok, r = pcall(function()
        return (bit.band(gs(vk), 0x8000) ~= 0);
    end);
    return ok and r;
end

local function expand_poll_imgui_key_down(imguiKey)
    if (imgui.IsKeyDown == nil or imguiKey == nil) then
        return false;
    end
    local ok, r = pcall(function()
        return imgui.IsKeyDown(imguiKey);
    end);
    return ok and r;
end

local function expand_gamepad_dpad_down(which)
    if (GlamourUI == nil or GlamourUI.gamepadDpadDown == nil) then
        return false;
    end
    return GlamourUI.gamepadDpadDown[which] == true;
end

local function expand_arrow_key_down(which)
    if (which == 'left') then
        return expand_vk_high_bit(0x25) or expand_poll_imgui_key_down(ImGuiKey_LeftArrow) or expand_gamepad_dpad_down('left');
    end
    if (which == 'right') then
        return expand_vk_high_bit(0x27) or expand_poll_imgui_key_down(ImGuiKey_RightArrow) or expand_gamepad_dpad_down('right');
    end
    if (which == 'up') then
        return expand_vk_high_bit(0x26) or expand_poll_imgui_key_down(ImGuiKey_UpArrow) or expand_gamepad_dpad_down('up');
    end
    if (which == 'down') then
        return expand_vk_high_bit(0x28) or expand_poll_imgui_key_down(ImGuiKey_DownArrow) or expand_gamepad_dpad_down('down');
    end
    return false;
end

local function expand_nav_modifiers_down()
    return expand_vk_high_bit(0x10) or expand_vk_high_bit(0x11) or expand_vk_high_bit(0x12);
end

local EXPAND_KEY_REPEAT_DELAY_SEC = 0.75;
local EXPAND_KEY_REPEAT_INTERVAL_SEC = 0.25;

local function poll_expand_arrow_scroll_keys()
    if (GlamourUI == nil or GlamourUI.chatExpandOpen ~= true) then
        return;
    end
    if (expand_nav_modifiers_down()) then
        return;
    end

    if (GlamourUI.expandArrowRepeat == nil) then
        GlamourUI.expandArrowRepeat = {
            prevDown = {},
            hold = {},
        };
    end
    local rep = GlamourUI.expandArrowRepeat;
    local prevDown = rep.prevDown;
    local hold = rep.hold;

    local arrows = T{
        { id = 'left', op = 'page_up' },
        { id = 'right', op = 'page_down' },
        { id = 'up', op = 'line_up' },
        { id = 'down', op = 'line_down' },
    };

    local now = os.clock();

    for i = 1, #arrows do
        local a = arrows[i];
        local down = expand_arrow_key_down(a.id);
        local was = prevDown[a.id] == true;
        prevDown[a.id] = down;
        local pressed = down and (not was);

        if (pressed) then
            GlamourUI.expandScrollOp = a.op;
            hold[a.id] = { anchor = now, lastBurst = now };
        elseif (down and hold[a.id] ~= nil) then
            local h = hold[a.id];
            local age = now - h.anchor;
            if (age >= EXPAND_KEY_REPEAT_DELAY_SEC) then
                if (now - h.lastBurst >= EXPAND_KEY_REPEAT_INTERVAL_SEC) then
                    GlamourUI.expandScrollOp = a.op;
                    h.lastBurst = now;
                end
            end
        elseif (not down) then
            hold[a.id] = nil;
        end
    end
end

local function chat_input_is_open()
    local cm = AshitaCore:GetChatManager();
    if (cm == nil or cm.IsInputOpen == nil) then
        return false;
    end
    local status = cm:IsInputOpen();
    if (status == nil or status == false) then
        return false;
    end
    return tonumber(status) ~= 0;
end

local CHAT_INPUT_MAX_CHARS = 120;

local function imgui_content_avail_width()
    local avail = imgui.GetContentRegionAvail();
    if (type(avail) == 'number') then
        return math.max(0, avail);
    end
    if (type(avail) == 'table') then
        return math.max(0, tonumber(avail[1]) or tonumber(avail.x) or 0);
    end
    return 0;
end

local function get_chat_input_max_chars(cm)
    if (cm ~= nil and cm.GetInputTextParsedLengthMax ~= nil) then
        local maxLen = tonumber(cm:GetInputTextParsedLengthMax());
        if (maxLen ~= nil and maxLen > 0) then
            return math.floor(maxLen);
        end
    end
    return CHAT_INPUT_MAX_CHARS;
end

local function get_chat_input_char_count(cm, inputText)
    if (cm ~= nil and cm.GetInputTextRawLength ~= nil) then
        local rawLen = tonumber(cm:GetInputTextRawLength());
        if (rawLen ~= nil) then
            return math.max(0, math.floor(rawLen));
        end
    end
    return #(inputText or '');
end

local function calc_chat_input_bar_height(chatSettings)
    local padY = tonumber(chatSettings.inputPanelPaddingY) or 4;
    local sepH = 2;
    if (imgui.GetStyle ~= nil) then
        local style = imgui.GetStyle();
        if (style ~= nil and style.ItemSpacing ~= nil) then
            local sp = style.ItemSpacing;
            local spY = tonumber(sp[2]) or tonumber(sp.y) or 0;
            sepH = math.max(sepH, (tonumber(style.SeparatorTextBorderSize) or 0) + spY * 0.5);
        end
    end
    local lh = imgui_calc_line_height();
    local counterH = lh;
    return sepH + counterH + padY + lh + padY + 2;
end

local function render_chat_input_bar_content(chatSettings)
    local cm = AshitaCore:GetChatManager();
    if (cm == nil) then
        return;
    end

    local inputStyle = {
        panelBackgroundEnabled = chatSettings.inputPanelBackgroundEnabled,
        panelBackground = chatSettings.inputPanelBackground,
        panelRounding = chatSettings.inputPanelRounding,
        panelPaddingX = chatSettings.inputPanelPaddingX,
        panelPaddingY = chatSettings.inputPanelPaddingY,
        panelBorderSize = chatSettings.inputPanelBorderSize,
    };
    local inputBgPops = panelStyle.push_panel_background(inputStyle);

    local inputText = cm:GetInputTextRaw();
    local st = (gChat.get_input_display_state ~= nil) and gChat.get_input_display_state(inputText)
        or { purpose = 'Say', label = 'Input' };
    local purpose = st.purpose or 'Say';
    local label = st.label or 'Input';
    local purposeColor = gChat.get_purpose_color(purpose) or { 1.0, 1.0, 1.0, 1.0 };

    imgui.Separator();

    local maxChars = get_chat_input_max_chars(cm);
    local charCount = get_chat_input_char_count(cm, inputText);
    local counterText = ('%d/%d'):fmt(charCount, maxChars);
    local counterW = select(1, imgui.CalcTextSize(counterText)) or 0;
    local counterX = imgui.GetCursorPosX() + math.max(0, imgui_content_avail_width() - counterW);
    imgui.SetCursorPosX(counterX);
    if (charCount >= maxChars) then
        imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, counterText);
    elseif (imgui.TextDisabled ~= nil) then
        imgui.TextDisabled(counterText);
    else
        imgui.TextColored({ 0.55, 0.55, 0.55, 1.0 }, counterText);
    end

    if (imgui.BeginGroup ~= nil) then
        imgui.BeginGroup();
    end
    imgui.TextColored(purposeColor, (label .. ':'));
    if (imgui.SameLine ~= nil) then
        imgui.SameLine(0, 6);
    end
    local caretRaw = 0;
    if (cm.GetInputTextRawCaretPosition ~= nil) then
        caretRaw = cm:GetInputTextRawCaretPosition() or 0;
    else
        caretRaw = #(inputText or '') + 1;
    end
    draw_input_text_line(inputText or '', caretRaw, purposeColor);
    if (imgui.EndGroup ~= nil) then
        imgui.EndGroup();
    end

    local padY = tonumber(chatSettings.inputPanelPaddingY) or 4;
    imgui.Dummy({ 0, padY });

    panelStyle.pop_panel_background(inputBgPops);
end

local function push_chat_input_font(chatSettings)
    local fontScale = (chatSettings.inputFontScale or 1.0);
    return gResources.push_font_scale(fontScale * 0.5, chatSettings);
end

local function measure_chat_input_bar_height(chatSettings)
    local fontPushed = push_chat_input_font(chatSettings);
    local barH = calc_chat_input_bar_height(chatSettings);
    gResources.pop_font(fontPushed);
    return barH;
end

local function render_chat_input_bar(chatSettings)
    textShadow.suppress_begin();
    local fontPushed = push_chat_input_font(chatSettings);
    render_chat_input_bar_content(chatSettings);
    gResources.pop_font(fontPushed);
    textShadow.suppress_end();
end

local function render_expanded_chat_panel()
    if (GlamourUI == nil or GlamourUI.chatExpandOpen ~= true) then
        return;
    end

    local w1 = gChat.get_window_settings(1);
    if (w1 == nil) then
        return;
    end

    local w = w1.width or 760;
    local vh = get_client_window_height();

    local fontPushed = gResources.push_font_scale((w1.font_scale or 1.0) * 0.5, w1);
    local chatWinBgPops = panelStyle.push_panel_background(w1);
    textShadow.suppress_begin();

    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ w, vh }, ImGuiCond_Always);
    local winFlags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoSavedSettings
    );
    if (imgui.Begin('GlamChatExpand##' .. get_window_suffix(), true, winFlags)) then
        poll_expand_arrow_scroll_keys();

        for ti = 1, #EXPAND_TAB_LABELS do
            if (ti > 1) then
                imgui.SameLine();
            end
            local sel = (tonumber(GlamourUI.chatExpandTab) or 1) == ti;
            if (sel) then
                imgui.PushStyleColor(ImGuiCol_Button, { 0.25, 0.45, 0.85, 1.0 });
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.35, 0.55, 0.95, 1.0 });
                imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.2, 0.4, 0.8, 1.0 });
            end
            if (imgui.Button((EXPAND_TAB_LABELS[ti] .. '##GlamExTab') .. ti)) then
                GlamourUI.chatExpandTab = ti;
                GlamourUI.chatExpandSnapBottomPending = true;
            end
            if (sel) then
                imgui.PopStyleColor(3);
            end
        end

        local tab = tonumber(GlamourUI.chatExpandTab) or 1;
        if (tab < 1) then tab = 1; end
        if (tab > 8) then tab = 8; end

        local chatSettings = GlamourUI.settings.Chat;
        local showInputBar = chat_input_is_open();
        local inputBarH = 0;
        if (showInputBar and chatSettings ~= nil) then
            inputBarH = measure_chat_input_bar_height(chatSettings);
        end

        local scrollH = -1;
        if (showInputBar and inputBarH > 0) then
            scrollH = -inputBarH;
        end

        imgui.BeginChild(
            ('GlamChatExpandScroll##%d'):fmt(tab),
            { -1, scrollH },
            0,
            ImGuiWindowFlags_NoScrollbar
        );

        do
            GlamourUI.expandLastLineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
                or imgui_calc_text_height();
            if (GlamourUI.expandLastLineH < 1) then
                GlamourUI.expandLastLineH = 16;
            end
        end

        local chatList = get_expand_chat_list(tab);

        begin_chat_item_hover_pass();
        render_chat_entries_loop(chatList, false);

        if (GlamourUI.chatExpandSnapBottomPending == true) then
            GlamourUI.expandScrollOp = nil;
            imgui.SetScrollY(imgui.GetScrollMaxY());
            GlamourUI.chatExpandSnapBottomPending = false;
        else
            local op = GlamourUI.expandScrollOp;
            if (op ~= nil) then
                GlamourUI.expandScrollOp = nil;
                local sy = imgui.GetScrollY();
                local sm = imgui.GetScrollMaxY();
                local pageH = tonumber(imgui.GetWindowHeight()) or tonumber(GlamourUI.expandLastViewportH) or 200;
                if (pageH < 1) then
                    pageH = 200;
                end
                GlamourUI.expandLastViewportH = pageH;
                local lh = tonumber(GlamourUI.expandLastLineH) or 16;
                if (op == 'page_up') then
                    imgui.SetScrollY(math.max(0, sy - pageH));
                elseif (op == 'page_down') then
                    imgui.SetScrollY(math.min(sm, sy + pageH));
                elseif (op == 'line_up') then
                    imgui.SetScrollY(math.max(0, sy - lh));
                elseif (op == 'line_down') then
                    imgui.SetScrollY(math.min(sm, sy + lh));
                end
            end
        end

        poll_chat_item_hover_regions();

        imgui.EndChild();

        if (showInputBar and chatSettings ~= nil) then
            render_chat_input_bar(chatSettings);
        end

        imgui.End();
    end

    textShadow.suppress_end();
    panelStyle.pop_panel_background(chatWinBgPops);
    gResources.pop_font(fontPushed);
end

local render_chat_window = function(title, settingsTable, windowIndex)
    if (settingsTable == nil or settingsTable.enabled ~= true) then
        return;
    end

    local winIdx = tonumber(windowIndex) or 1;

    local fontScale = settingsTable.font_scale or 1.0;
    local fontPushed = gResources.push_font_scale(fontScale * 0.5, settingsTable);
    local chatWinBgPops = panelStyle.push_panel_background(settingsTable);
    textShadow.suppress_begin();

    imgui.SetNextWindowSize({ settingsTable.width or 760, settingsTable.height or 260 }, ImGuiCond_Once);
    imgui.SetNextWindowPos({ settingsTable.x or 10, settingsTable.y or 10 }, ImGuiCond_Once);
    if (imgui.Begin(title, true, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoScrollbar))) then
        local chatSettings = GlamourUI.settings.Chat;
        local showInputBar = (winIdx == 1 and chat_input_is_open());
        local inputBarH = 0;
        if (showInputBar and chatSettings ~= nil) then
            inputBarH = measure_chat_input_bar_height(chatSettings);
        end

        local scrollH = -1;
        if (showInputBar and inputBarH > 0) then
            scrollH = -inputBarH;
        end

        imgui.BeginChild(
            ('GlamChatScroll##%d'):fmt(winIdx),
            { -1, scrollH },
            0,
            ImGuiWindowFlags_NoScrollbar
        );

        local chatList = gChat.get_window_entries(winIdx);

        render_chat_entry_list(chatList, true);

        imgui.EndChild();

        if (showInputBar and chatSettings ~= nil) then
            render_chat_input_bar(chatSettings);
        end

        if (winIdx == 1 and GlamourUI ~= nil and GlamourUI.chatLogFocus == true) then
            local wp = { imgui.GetWindowPos() };
            local ws = { imgui.GetWindowSize() };
            local fg = imgui.GetForegroundDrawList();
            if (fg ~= nil and fg.AddRect ~= nil) then
                local thick = 4.0;
                local pad = thick * 0.5;
                local white = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
                fg:AddRect(
                    { wp[1] - pad, wp[2] - pad },
                    { wp[1] + ws[1] + pad, wp[2] + ws[2] + pad },
                    white,
                    0.0,
                    0,
                    thick
                );
            end
        end

        local pos = { imgui.GetWindowPos() };
        settingsTable.x = pos[1];
        settingsTable.y = pos[2];
        settingsTable.width = imgui.GetWindowWidth();
        settingsTable.height = imgui.GetWindowHeight();
        imgui.End();
    end

    textShadow.suppress_end();
    panelStyle.pop_panel_background(chatWinBgPops);
    gResources.pop_font(fontPushed);
end

local function party_list_job_distance_x(jobText, distanceText, guiScale)
    guiScale = guiScale or 1.0;
    local gap = 8 * guiScale;
    local rightPad = 4 * guiScale;
    local jobX = (gParty.layout.NamePosition.x + 150) * guiScale;
    local barRight = (30 + gParty.layout.HPBarPosition.x + gParty.layout.hpBarDim.l) * guiScale;
    local jobW = select(1, imgui.CalcTextSize(tostring(jobText or ''))) or 0;
    local distW = select(1, imgui.CalcTextSize(tostring(distanceText or ''))) or 0;
    local distX = barRight - distW - rightPad;
    local minDistX = jobX + jobW + gap;
    if (distX < minDistX) then
        distX = minDistX;
    end
    return jobX, distX;
end

render.build_member_render_context = function(memberIndex, member, partyManager, memoryManager)
    local targetManager = memoryManager:GetTarget();
    local targetIndex = targetManager:GetTargetIndex(targetManager:GetIsSubTargetActive());
    local targetEntity = GetEntity(targetIndex);
    local selectedTarget, selectedTargetActive = gTarget.get_selected_alliance_member();
    local subTarget = gTarget.get_sub_target_entity();
    local entityManager = memoryManager:GetEntity();
    local playerZoneId = partyManager:GetMemberZone(0);
    local memberTargetIndex = partyManager:GetMemberTargetIndex(memberIndex);
    local distance = 0;

    if(subTarget == nil)then
        subTarget = { ServerId = 0 };
    end

    if(memberTargetIndex ~= nil and memberTargetIndex > 0)then
        local rawDistance = entityManager:GetDistance(memberTargetIndex);
        if(rawDistance ~= nil and rawDistance > 0)then
            distance = math.floor((math.sqrt(rawDistance)) * 100) / 100;
        end
    end

    return {
        targetEntity = targetEntity,
        selectedTarget = selectedTarget,
        selectedTargetActive = selectedTargetActive,
        subTarget = subTarget,
        playerZoneId = playerZoneId,
        sameZone = member.ZoneId == playerZoneId,
        distance = distance,
    };
end

render.render_player_themed = function(elementIndex, hpBarTexture, hpFillTexture, mpBarTexture, mpFillTexture, tpBarTexture, tpFillTexture, targetTexture, subTargetTexture, partyLeadTexture, levelSyncTexture, memberIndex, member, jobIconTexture, renderContext)
    local elementName = gParty.layout.Priority[elementIndex];
    local yOffset = get_party_member_y_offset(memberIndex);
    local targetEntity = renderContext.targetEntity;
    local selectedTarget = renderContext.selectedTarget;
    local selectedTargetActive = renderContext.selectedTargetActive;
    local subTarget = renderContext.subTarget;
    local distance = renderContext.distance;

    local fontPushed = gResources.push_font_scale((GlamourUI.settings.Party.pList.font_scale * 0.5) * GlamourUI.settings.Party.pList.gui_scale, GlamourUI.settings.Party.pList);
    local finish_render = function()
        gResources.pop_font(fontPushed);
        return;
    end

    if(GlamourUI.settings.Party.pList.themed == true)then
        if(elementName == 'name')then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            draw_member_target_markers(targetEntity, selectedTarget, selectedTargetActive, subTarget, memberIndex, member, targetTexture, subTargetTexture, 64 * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosX((gParty.layout.NamePosition.x + 27) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            gParty.GroupHeight1.x, gParty.GroupHeight1.y = imgui.GetCursorPos();
            if(gParty.Leader1 == member.Id)then
                imgui.Image(partyLeadTexture, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_Text, get_member_text_color(member));
            imgui.Text(member.Name);
            imgui.PopStyleColor();
            local plistScale = GlamourUI.settings.Party.pList.gui_scale;
            local nameRowY = (yOffset + gParty.layout.NamePosition.y) * plistScale;
            local jobX, distX = party_list_job_distance_x(member.JobDisplay, tostring(distance), plistScale);
            imgui.SetCursorPosX(jobX);
            imgui.SetCursorPosY(nameRowY);
            imgui.Text(member.JobDisplay);
            if(memberIndex ~= 0) then
                imgui.SetCursorPosX(distX);
                imgui.SetCursorPosY(nameRowY);
                imgui.Text(tostring(distance));
            end
            if(member.LevelSync == true)then
                imgui.SetCursorPosY(nameRowY);
                imgui.SameLine();
                imgui.Image(levelSyncTexture, {10 * plistScale, 10 * plistScale});
            end

            return finish_render();
        elseif(elementName == 'hp')then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpBarTexture, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(renderContext.sameZone)then
                imgui.Image(hpFillTexture, {(member.HPP * gParty.layout.hpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {member.HPP, 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                imgui.SetCursorPosX((50 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(member.Zone);
                return finish_render();
            end
            imgui.Text(tostring(member.HP));
            return finish_render();
        elseif(elementName == 'mp')then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpBarTexture, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(renderContext.sameZone) then
                imgui.Image(mpFillTexture, {(member.MPP * gParty.layout.mpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {member.MPP, 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                return finish_render();
            end
            imgui.Text(tostring(member.MP));
            return finish_render();
        elseif(elementName == 'tp')then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpBarTexture, {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(renderContext.sameZone)then
                imgui.Image(tpFillTexture, {(math.clamp((member.TP / 1000), 0, 1) *gParty.layout.tpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(math.clamp((member.TP / 1000), 0, 1)), 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                return finish_render();
            end
            imgui.Text(tostring(member.TP));
            return finish_render();
        elseif(elementName == 'buffs')then
            draw_member_buffs(member, yOffset, memberIndex);
            return finish_render();
        elseif(elementName == 'jobIcon')then
            if(jobIconTexture ~= nil)then
                imgui.SetCursorPosX((5 + gParty.layout.jobIconPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.SetCursorPosY((yOffset + gParty.layout.jobIconPos.y) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Image(jobIconTexture, {64 * GlamourUI.settings.Party.pList.gui_scale, 64 * GlamourUI.settings.Party.pList.gui_scale});
            end
        end
    else
        if(elementName == 'name')then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY(yOffset + gParty.layout.NamePosition.y * GlamourUI.settings.Party.pList.gui_scale);
            draw_member_target_markers(targetEntity, selectedTarget, selectedTargetActive, subTarget, memberIndex, member, targetTexture, subTargetTexture, 25 * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosX((gParty.layout.NamePosition.x + 27) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(gParty.Leader1 == member.Id)then
                imgui.Image(partyLeadTexture, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_Text, get_member_text_color(member));
            imgui.Text(member.Name);
            imgui.PopStyleColor();
            if(member.LevelSync == true)then
                imgui.SameLine();
                imgui.Image(levelSyncTexture, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SameLine();
            imgui.Text(tostring(distance));
            return finish_render();
        elseif(elementName == 'hp')then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, {1.0, 0.25, 0.25, 1.0});
            imgui.ProgressBar(member.HPP, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                imgui.SetCursorPosX(50 + gParty.layout.HPBarPosition.x);
                imgui.Text(member.Zone);
                return finish_render();
            end
            imgui.Text(tostring(member.HP));
            return finish_render();
        elseif(elementName == 'mp')then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, {0.0, 0.5, 0.0, 1.0});
            imgui.ProgressBar(member.MPP, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                return finish_render();
            end
            imgui.Text(tostring(member.MP));
            return finish_render();
        elseif(elementName == 'tp')then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, {0.0, 0.45, 1.0, 1.0});
            imgui.ProgressBar((math.clamp((member.TP / 1000), 0, 1)), {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(not renderContext.sameZone)then
                return finish_render();
            end
            imgui.Text(tostring(member.TP));
            return finish_render();
        elseif(elementName == 'buffs')then
            draw_member_buffs(member, yOffset, memberIndex);
            return finish_render();
        end
    end
    return finish_render();
end

render.render_pet_themed = function(elementIndex, hpBarTexture, hpFillTexture, mpBarTexture, mpFillTexture, tpBarTexture, tpFillTexture, targetTexture, subTargetTexture, pet, petIndex)
    local memoryManager = MemoryManager or AshitaCore:GetMemoryManager();
    local playerManager = memoryManager:GetPlayer();
    local targetManager = memoryManager:GetTarget();
    local elementName = gParty.layout.Priority[elementIndex];
    local yOffset = (petIndex * 55) + (petIndex * gParty.layout.padding);
    local targetIndex = targetManager:GetTargetIndex(targetManager:GetIsSubTargetActive());
    local targetEntity = GetEntity(targetIndex);
    local selectedTarget, selectedTargetActive = gTarget.get_selected_alliance_member();
    local petMpPercent = playerManager:GetPetMPPercent();
    local petTp = playerManager:GetPetTP();

    local fontPushed = gResources.push_font_scale((GlamourUI.settings.Party.pList.font_scale * 0.5) * GlamourUI.settings.Party.pList.gui_scale, GlamourUI.settings.Party.pList);
    local function finish_render()
        gResources.pop_font(fontPushed);
        return;
    end

    if elementName == 'name' then
        imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
        imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
        if(targetEntity ~= nil)then
            if(targetEntity.ServerId == pet.ServerId)then
                imgui.Image(targetTexture, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
            end
        end

        if((selectedTargetActive == true and selectedTarget == pet) or gTarget.get_sub_target_entity() == pet)then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(subTargetTexture, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
        end
        imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
        imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
        imgui.Text(pet.Name);
        draw_pet_degradation_bar(hpBarTexture, hpFillTexture);
        return finish_render();
    end

    if(GlamourUI.settings.Party.pList.themed == true)then
        if elementName == 'hp' then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpBarTexture, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpFillTexture, {(gParty.layout.hpBarDim.l * (pet.HPPercent / 100)) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(pet.HPPercent / 100), 1});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(pet.HPPercent) .. '%');
            return finish_render();
        end

        if elementName == 'mp' then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpBarTexture, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpFillTexture, {(gParty.layout.mpBarDim.l * (petMpPercent / 100)) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0,0},{(petMpPercent / 100),1});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(petMpPercent));
            return finish_render();
        end

        if elementName == 'tp' then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpBarTexture, {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpFillTexture, {(gParty.layout.tpBarDim.l * (math.clamp((petTp / 1000), 0, 1))) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(math.clamp((petTp / 1000), 0, 1)), 1});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX)* GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(petTp));
            return finish_render();
        end
    else
        if elementName == 'hp' then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar(pet.HPPercent, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(pet.HPPercent) .. '%%');
            return finish_render();
        end

        if elementName == 'mp' then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar(petMpPercent / 100, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(petMpPercent));
            return finish_render();
        end

        if elementName == 'tp' then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar((math.clamp((petTp / 1000), 0, 1)), {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX)* GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(petTp));
            return finish_render();
        end
    end
    return finish_render();
end

-- Alliance panel layout (base units; multiplied by gui_scale unless noted).
local APANEL_LEFT_COL = 50;
local APANEL_COL_GAP = 50;
local APANEL_NAME_X = 45;
local APANEL_BAR_X = 35;
local APANEL_ROW_PAD = 16;
local APANEL_SECTION_GAP = 8;
local APANEL_ROW_BAR_MULT = 2;
local APANEL_RIGHT_PAD = 55;
local APANEL_TP_X = 55;
local APANEL_MP_PAD = 15;
local APANEL_LEAD_ICON = 10;

render.get_apanel_layout = function(aPanel)
    local guiScale = aPanel.gui_scale or 1.0;
    local fontScale = aPanel.font_scale or 1.0;
    local barLen = aPanel.hpBarDim.l;
    local barHeight = aPanel.hpBarDim.g;
    local barWidth = barLen * guiScale;
    local barHeightScaled = barHeight * guiScale;
    local col1X = APANEL_LEFT_COL * guiScale;
    local col2X = (APANEL_LEFT_COL + barLen + APANEL_COL_GAP) * guiScale;
    local rowStride = (APANEL_ROW_BAR_MULT * barHeight + 4) * guiScale;
    local rowTopPad = APANEL_ROW_PAD * guiScale;
    local sectionGap = APANEL_SECTION_GAP * guiScale;
    local sectionHeight = rowTopPad + (3 * rowStride);
    local panelWidth = col2X + barWidth + (APANEL_RIGHT_PAD * guiScale);

    return {
        guiScale = guiScale,
        fontScale = fontScale,
        barWidth = barWidth,
        barHeight = barHeightScaled,
        colX = { col1X, col2X },
        rowStride = rowStride,
        rowTopPad = rowTopPad,
        sectionGap = sectionGap,
        sectionHeight = sectionHeight,
        panelWidth = panelWidth,
        nameX = APANEL_NAME_X * guiScale,
        barX = APANEL_BAR_X * guiScale,
        tpX = APANEL_TP_X * guiScale,
        mpPad = APANEL_MP_PAD * guiScale,
        detailFontScale = 0.25 * fontScale * guiScale,
        leadIcon = APANEL_LEAD_ICON * guiScale,
    };
end

render.render_alliance_member = function(hpBarTexture, hpFillTexture, partyLeadTexture, layout, member, memberIndex, column)
    local memoryManager = MemoryManager or AshitaCore:GetMemoryManager();
    local playerZoneId = memoryManager:GetParty():GetMemberZone(0);
    local aPanel = GlamourUI.settings.Party.aPanel;
    local colX = layout.colX[(column or 0) + 1];
    local setColX = function(offset)
        imgui.SetCursorPos({ colX + offset, imgui.GetCursorPosY() });
    end;
    local growMemberBounds = function()
        local extentX = colX + layout.barWidth + (APANEL_RIGHT_PAD * layout.guiScale);
        local extentY = imgui.GetCursorPosY() + layout.barHeight + (4 * layout.guiScale);
        imgui.SetCursorPos({ extentX, extentY });
        imgui.Dummy({ 1, 1 });
    end;

    if(member == nil or member.Name == nil)then
        growMemberBounds();
        return;
    end

    local hpTextOffset = (layout.barWidth - select(1, imgui.CalcTextSize(tostring(member.HP)))) * 0.5;
    local menu = gHelper.getMenu();
    if(aPanel.themed == true)then
        setColX(layout.nameX);
        imgui.Text(tostring(member.Name));

        setColX(layout.barX);
        imgui.Image(hpBarTexture, { layout.barWidth, layout.barHeight });
        if(member.ZoneId ~= playerZoneId)then
            imgui.SameLine();
            setColX(layout.nameX);
            imgui.Text(tostring(member.Zone));
        else
            imgui.SameLine();
            setColX(layout.barX);
            imgui.Image(hpFillTexture, { layout.barWidth * member.HPP, layout.barHeight }, { 0, 0 }, { member.HPP, 1 });
            imgui.SameLine();
            setColX(layout.barX + hpTextOffset);
            imgui.Text(tostring(member.HP));

            imgui.SameLine();
            local detailFontPushed = gResources.push_font_scale(layout.detailFontScale, GlamourUI.settings.Party.aPanel);
            setColX(layout.tpX);
            imgui.PushStyleColor(ImGuiCol_Text, { 0.4, 0.6, 1.0, 1.0 });
            imgui.Text(tostring(member.TP));
            imgui.PopStyleColor();

            local mpOffset = select(1, imgui.CalcTextSize(tostring(member.MP)));
            imgui.SameLine();
            setColX(layout.mpPad + layout.barWidth - mpOffset);
            imgui.PushStyleColor(ImGuiCol_Text, { 0.35, 1.0, 0.4, 1.0 });
            imgui.Text(tostring(member.MP));
            imgui.PopStyleColor();
            gResources.pop_font(detailFontPushed);
        end

        if(member.Id == gParty.Leader2 or member.Id == gParty.Leader3)then
            imgui.SameLine();
            setColX(layout.barX);
            imgui.Image(partyLeadTexture, { layout.leadIcon, layout.leadIcon });
        end
    else
        setColX(layout.nameX);
        imgui.Text(tostring(member.Name));

        if(menu == 'loot')then
            imgui.SameLine();
            imgui.Text('     ');
            imgui.SameLine();
            imgui.Text(tostring(gParty.get_lot(memberIndex)));
        end

        setColX(layout.barX);
        imgui.ProgressBar(member.HPP, { layout.barWidth, layout.barHeight }, tostring(member.HP));
        if(member.ZoneId ~= playerZoneId)then
            imgui.SameLine();
            setColX(layout.nameX);
            imgui.Text(tostring(member.Zone));
        end
        if(member.Id == gParty.Leader2 or member.Id == gParty.Leader3)then
            imgui.SameLine();
            setColX(layout.barX);
            imgui.Image(partyLeadTexture, { layout.leadIcon, layout.leadIcon });
        end
    end
    growMemberBounds();
end

local function pstats_set_pos(x, y)
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(x);
    imgui.Dummy({ 1, 1 });
end

local function pstats_ensure_panel_width(layout, y, height)
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(layout.panelWidth);
    imgui.Dummy({ 1, height or 1 });
end

local function pstats_centered_x(layout, width)
    return math.max(0, (layout.panelWidth - width) * 0.5);
end

local function pstats_text_width(text)
    local width = select(1, imgui.CalcTextSize(text));
    if(type(width) ~= 'number')then
        return 0;
    end
    return width;
end

local function pstats_format_rate(rate)
    if(rate >= 1000000)then
        return tostring(math.floor((rate / 1000000) * 100) / 100) .. 'M';
    end
    return tostring(rate);
end

render.get_pstats_layout = function(pstats)
    local guiScale = pstats.gui_scale or 1.0;
    local fontScale = pstats.font_scale or 1.0;
    local statBarLen = pstats.BarDim.l;
    local statBarGirth = pstats.BarDim.g;
    local statBarWidth = statBarLen * guiScale;
    local statBarHeight = statBarGirth * guiScale;
    local barPadding = (pstats.barPadding or 50) * guiScale;
    local statGroupWidth = (3 * statBarWidth) + (2 * barPadding);
    local expBarWidth = pstats.expBarDim.l * guiScale;
    local expBarHeight = pstats.expBarDim.g * guiScale;
    local rowGap = (pstats.rowGap or 8) * guiScale;
    local panelWidth = math.max(statGroupWidth, expBarWidth);
    local statGroupX = (panelWidth - statGroupWidth) * 0.5;
    local expBarX = (panelWidth - expBarWidth) * 0.5;
    local statBarsY = 0;
    local expBarY = statBarHeight + rowGap;
    local infoRowY = expBarY + expBarHeight + rowGap;
    local baseLineHeight = select(2, imgui.CalcTextSize('Mg'));
    if(type(baseLineHeight) ~= 'number' or baseLineHeight <= 0)then
        baseLineHeight = 12;
    end
    -- The EXP/job line + merits line are drawn with `detailFontScale`, so measure spacing using that scale.
    local detailFontScale = fontScale * 0.3 * guiScale;
    local lineHeight = math.max(8 * guiScale, baseLineHeight * detailFontScale);
    -- Keep merits tucked just below the EXP info row (no big extra gap).
    local meritsGap = math.max(2 * guiScale, math.floor(rowGap * 0.25));
    local meritsRowY = infoRowY + lineHeight + meritsGap;
    local cpBarY = meritsRowY;
    local cpInfoRowY = cpBarY + expBarHeight + rowGap;
    local panelHeight = infoRowY + lineHeight + rowGap;

    return {
        guiScale = guiScale,
        fontScale = fontScale,
        panelWidth = panelWidth,
        statBarWidth = statBarWidth,
        statBarHeight = statBarHeight,
        statGroupX = statGroupX,
        statGroupWidth = statGroupWidth,
        barPadding = barPadding,
        statBarsY = statBarsY,
        expBarX = expBarX,
        expBarY = expBarY,
        expBarWidth = expBarWidth,
        expBarHeight = expBarHeight,
        infoRowY = infoRowY,
        meritsRowY = meritsRowY,
        cpBarY = cpBarY,
        cpInfoRowY = cpInfoRowY,
        rowGap = rowGap,
        lineHeight = lineHeight,
        panelHeight = panelHeight,
        mainFontScale = fontScale * 0.5 * guiScale,
        detailFontScale = detailFontScale,
        fontSettings = pstats,
    };
end

local function pstats_draw_themed_stat_column(layout, barTexture, fillTexture, value, percentage)
    local startX, startY = imgui.GetCursorPos();
    imgui.Image(barTexture, { layout.statBarWidth, layout.statBarHeight });
    imgui.SetCursorPosY(startY);
    imgui.SetCursorPosX(startX);
    if(percentage ~= nil)then
        imgui.Image(fillTexture, { layout.statBarWidth * percentage, layout.statBarHeight }, { 0, 0 }, { percentage, 1 });
    else
        local tpFill = math.clamp(value / 1000, 0, 1);
        imgui.Image(fillTexture, { layout.statBarWidth * tpFill, layout.statBarHeight }, { 0, 0 }, { tpFill, 1 });
    end
    local textWidth = pstats_text_width(tostring(value));
    imgui.SetCursorPosY(startY);
    imgui.SetCursorPosX(startX + ((layout.statBarWidth - textWidth) * 0.5));
    imgui.Text(tostring(value));
    imgui.SetCursorPosY(startY);
    imgui.SetCursorPosX(startX + layout.statBarWidth);
    imgui.Dummy({ 1, layout.statBarHeight });
end

local function pstats_draw_themed_stat_row(layout, barDefs)
    pstats_set_pos(pstats_centered_x(layout, layout.statGroupWidth), layout.statBarsY);
    for col = 1, #barDefs do
        if(col > 1)then
            imgui.SameLine(0, layout.barPadding);
        end
        local def = barDefs[col];
        pstats_draw_themed_stat_column(layout, def[1], def[2], def[3], def[4]);
    end
end

local function pstats_draw_plain_stat_column(layout, color, value, percentage)
    local startX, startY = imgui.GetCursorPos();
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, color);
    if(percentage ~= nil)then
        imgui.ProgressBar(percentage, { layout.statBarWidth, layout.statBarHeight }, tostring(value));
        imgui.PopStyleColor();
    else
        imgui.ProgressBar(value / 1000, { layout.statBarWidth, layout.statBarHeight }, '');
        imgui.PopStyleColor();
        if(value > 1000)then
            imgui.SetCursorPosY(startY);
            imgui.SetCursorPosX(startX);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0 });
            imgui.ProgressBar((value - 1000) / 1000, { layout.statBarWidth, layout.statBarHeight }, '');
            imgui.PopStyleColor();
        end
        if(value > 2000)then
            imgui.SetCursorPosY(startY);
            imgui.SetCursorPosX(startX);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0 });
            imgui.ProgressBar((value - 2000) / 1000, { layout.statBarWidth, layout.statBarHeight }, '');
            imgui.PopStyleColor();
        end
        local textWidth = pstats_text_width(tostring(value));
        imgui.SetCursorPosY(startY);
        imgui.SetCursorPosX(startX + ((layout.statBarWidth - textWidth) * 0.5));
        imgui.Text(tostring(value));
    end
    imgui.SetCursorPosY(startY);
    imgui.SetCursorPosX(startX + layout.statBarWidth);
    imgui.Dummy({ 1, layout.statBarHeight });
end

local function pstats_draw_plain_stat_row(layout, barDefs)
    pstats_set_pos(pstats_centered_x(layout, layout.statGroupWidth), layout.statBarsY);
    for col = 1, #barDefs do
        if(col > 1)then
            imgui.SameLine(0, layout.barPadding);
        end
        local def = barDefs[col];
        pstats_draw_plain_stat_column(layout, def[1], def[2], def[3]);
    end
end

local function pstats_grow_bounds(layout, contentHeight)
    imgui.SetCursorPosY(contentHeight + layout.rowGap);
    imgui.SetCursorPosX(layout.panelWidth);
    imgui.Dummy({ 1, 1 });
end

local function pstats_draw_left_text(text, y, layout)
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(0);
    imgui.Text(text);
end

local function pstats_draw_center_text(text, y, layout)
    local textWidth = pstats_text_width(text);
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(math.max(0, (layout.panelWidth - textWidth) * 0.5));
    imgui.Text(text);
end

local function pstats_draw_right_text(text, y, layout)
    local textWidth = pstats_text_width(text);
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(math.max(0, layout.panelWidth - textWidth));
    imgui.Text(text);
end

local function pstats_draw_three_column_row(layout, y, leftText, centerText, rightText, rightHoverText, onReset)
    pstats_draw_left_text(leftText, y, layout);
    if(centerText ~= nil and centerText ~= '')then
        pstats_draw_center_text(centerText, y, layout);
    end
    if(onReset ~= nil and rightText ~= nil and rightText ~= '')then
        local hoverWidth = pstats_text_width('     ');
        imgui.SetCursorPosY(y);
        imgui.SetCursorPosX(math.max(0, layout.panelWidth - hoverWidth));
        imgui.Text('     ');
        if(imgui.IsItemHovered())then
            pstats_draw_right_text(rightHoverText or 'Reset?', y, layout);
            if(imgui.IsItemClicked())then
                onReset();
            end
        else
            pstats_draw_right_text(rightText, y, layout);
        end
    elseif(rightText ~= nil and rightText ~= '')then
        pstats_draw_right_text(rightText, y, layout);
    end
    pstats_ensure_panel_width(layout, y + layout.lineHeight, 1);
end

local function pstats_draw_themed_progress_bar(layout, y, width, height, bgTexture, fillTexture, fillRatio)
    local x = pstats_centered_x(layout, width);
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(x);
    imgui.Image(bgTexture, { width, height });
    imgui.SetCursorPosY(y);
    imgui.SetCursorPosX(x);
    imgui.Image(fillTexture, { width * fillRatio, height }, { 0, 0 }, { fillRatio, 1 });
    pstats_ensure_panel_width(layout, y + height, 1);
end

local function pstats_draw_exp_info_row(layout, leftText, centerText, rightText, rightHoverText, onReset)
    pstats_draw_three_column_row(layout, layout.infoRowY, leftText, centerText, rightText, rightHoverText, onReset);
end

render.render_player_stats_panel = function(player, playerMember)
    local pstats = GlamourUI.settings.PlayerStats;
    local layout = render.get_pstats_layout(pstats);
    local curEXP = player:GetExpCurrent();
    local maxEXP = player:GetExpNeeded();
    local curLP = player:GetLimitPoints();
    local job = playerMember.JobDisplay;
    local expModeStr = gParty.EXPMode .. ' / hr';
    local contentHeight = layout.infoRowY + layout.lineHeight;
    local locked = player:GetIsExperiencePointsLocked();
    local isLPMode = (gParty.EXPMode == 'LP') or (locked == true) or (tonumber(locked) ~= nil and tonumber(locked) ~= 0);

    pstats_ensure_panel_width(layout, 0, 1);

    if(pstats.themed == true)then
        local hpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
        local hpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');
        local mpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpBar.png');
        local mpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpFill.png');
        local tpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpBar.png');
        local tpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpFill.png');
        local ebTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'expBar.png');
        local efTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'expFill.png');

        local mainFontPushed = gResources.push_font_scale(layout.mainFontScale, layout.fontSettings);
        pstats_draw_themed_stat_row(layout, {
            { hpbTex, hpfTex, playerMember.HP, playerMember.HPP },
            { mpbTex, mpfTex, playerMember.MP, playerMember.MPP },
            { tpbTex, tpfTex, playerMember.TP, nil },
        });
        gResources.pop_font(mainFontPushed);

        local detailFontPushed = gResources.push_font_scale(layout.detailFontScale, layout.fontSettings);
        local expFillRatio = 0;
        local expLeftText = '';
        if(not isLPMode)then
            expLeftText = tostring(curEXP) .. '/' .. tostring(maxEXP);
            expFillRatio = (maxEXP ~= nil and maxEXP > 0) and (curEXP / maxEXP) or 0;
        else
            expLeftText = tostring(curLP) .. '/10000';
            expFillRatio = curLP / 10000;
        end
        pstats_draw_themed_progress_bar(layout, layout.expBarY, layout.expBarWidth, layout.expBarHeight, ebTex, efTex, expFillRatio);

        local expRateLabel = pstats_format_rate(gParty.EXPperHour) .. ' ' .. expModeStr;
        pstats_draw_exp_info_row(layout, expLeftText, job, expRateLabel, 'Reset?', function()
            gParty.EXPReset = true;
        end);

        if(isLPMode)then
            local merits = tostring(player:GetMeritPoints()) .. ' / ' .. tostring(player:GetMeritPointsMax());
            pstats_draw_center_text('Merits: ' .. merits, layout.meritsRowY, layout);
            contentHeight = layout.meritsRowY + layout.lineHeight;

            local cp = player:GetCapacityPoints(playerMember.Job);
            local jp = player:GetJobPoints(playerMember.Job);
            if(playerMember.Level == 99 or cp > 0 or jp > 0)then
                layout.cpBarY = layout.meritsRowY + layout.lineHeight + layout.rowGap;
                layout.cpInfoRowY = layout.cpBarY + layout.expBarHeight + layout.rowGap;
                contentHeight = layout.cpInfoRowY + layout.lineHeight;

                if(not playerMember.Mastered)then
                    pstats_draw_themed_progress_bar(layout, layout.cpBarY, layout.expBarWidth, layout.expBarHeight, ebTex, efTex, cp / 30000);
                    local cpLeftText = 'CP:  ' .. tostring(cp) .. ' / 30000 : (' .. tostring(jp) .. ' JP)';
                    pstats_draw_three_column_row(layout, layout.cpInfoRowY, cpLeftText, '', pstats_format_rate(gParty.CPperHour) .. ' CP/Hr', nil, nil);
                else
                    local exemP = playerMember.ExemP;
                    local mltnl = playerMember.MLTNL;
                    local exemPRatio = (mltnl ~= nil and mltnl > 0) and (exemP / mltnl) or 0;
                    pstats_draw_themed_progress_bar(layout, layout.cpBarY, layout.expBarWidth, layout.expBarHeight, ebTex, efTex, exemPRatio);
                    local exemPLeftText = 'ExemP:  ' .. tostring(exemP) .. ' / ' .. tostring(mltnl) .. ' | Master Level:  ' .. tostring(playerMember.ML);
                    pstats_draw_three_column_row(layout, layout.cpInfoRowY, exemPLeftText, '', pstats_format_rate(gParty.ExemPperHour) .. ' ExemP/Hr', nil, nil);
                end
            end
        end
        gResources.pop_font(detailFontPushed);
    else
        local mainFontPushed = gResources.push_font_scale(layout.mainFontScale, layout.fontSettings);
        pstats_draw_plain_stat_row(layout, {
            { { 1.0, 0.25, 0.25, 1.0 }, playerMember.HP, playerMember.HPP },
            { { 0.0, 0.5, 0.0, 1.0 }, playerMember.MP, playerMember.MPP },
            { { 0.0, 0.45, 1.0, 1.0 }, playerMember.TP, nil },
        });

        local detailFontPushed = gResources.push_font_scale(layout.detailFontScale, layout.fontSettings);
        pstats_set_pos(pstats_centered_x(layout, layout.expBarWidth), layout.expBarY);
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 1.0, 0.25, 1.0 });
        local expRatio = 0;
        local expLeftText = '';
        if (isLPMode) then
            expLeftText = tostring(curLP) .. '/10000';
            expRatio = curLP / 10000;
        else
            expLeftText = tostring(curEXP) .. '/' .. tostring(maxEXP);
            expRatio = (maxEXP ~= nil and maxEXP > 0) and (curEXP / maxEXP) or 0;
        end
        imgui.ProgressBar(expRatio, { layout.expBarWidth, layout.expBarHeight }, '');
        imgui.PopStyleColor();
        pstats_ensure_panel_width(layout, layout.expBarY + layout.expBarHeight, 1);

        pstats_draw_exp_info_row(layout, expLeftText, job, '', nil, nil);
        contentHeight = layout.infoRowY + layout.lineHeight;

        if (isLPMode) then
            local merits = tostring(player:GetMeritPoints()) .. ' / ' .. tostring(player:GetMeritPointsMax());
            pstats_draw_center_text('Merits: ' .. merits, layout.meritsRowY, layout);
            contentHeight = layout.meritsRowY + layout.lineHeight;
        end
        gResources.pop_font(detailFontPushed);
        gResources.pop_font(mainFontPushed);
    end

    pstats_grow_bounds(layout, contentHeight);
end

render.render_recast = function()
    local menu = gHelper.getMenu();
    local recastBarTexture = gResources.getTex(GlamourUI.settings, 'rcPanel', 'recastBar.png');
    local recastFillTexture = gResources.getTex(GlamourUI.settings, 'rcPanel', 'recastFill.png');

    local chatOpen = false;
    if(menu == 'fulllog')then
        chatOpen = true;
    elseif(menu == 'logwindo' or menu == nil)then
        chatOpen = false;
    end

    if(GlamourUI.settings.rcPanel.enabled == true and chatOpen == false)then
        local actions, timers, progressList = gRecast.makeTimers();
        if(progressList[1] ~= nil) then
            local rcBgPops = panelStyle.push_panel_background(GlamourUI.settings.rcPanel);
            if(imgui.Begin('Recast##GlamRCPanel' .. get_window_suffix(), gRecast.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
                local fontPushed = gResources.push_font_scale((GlamourUI.settings.rcPanel.font_scale * 0.4) * GlamourUI.settings.rcPanel.gui_scale, GlamourUI.settings.rcPanel);
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
                for i = 1,#timers,1 do
                    local timer = timers[i];
                    local actionName = actions[i];
                    local progress = progressList[i];
                    local textOffset = (imgui.GetWindowSize() - (imgui.CalcTextSize(timer) / 2 )) - 50 ;

                    imgui.Text(actionName .. " :  ");
                    imgui.SameLine();
                    imgui.SetCursorPosX(textOffset);
                    imgui.Text(tostring(timer));
                    if(GlamourUI.settings.rcPanel.themed == true)then
                        imgui.SetCursorPosX(10);
                        imgui.Image(recastBarTexture, {260, 6});
                        imgui.SameLine();
                        imgui.SetCursorPosX(10);
                        imgui.Image(recastFillTexture, {260 * progress, 6}, {0,0}, {progress, 1});
                    else
                        imgui.ProgressBar(progress, {260, 6}, '');
                    end
                end
                imgui.PopStyleColor()
                gResources.pop_font(fontPushed);
                imgui.End();
            end
            panelStyle.pop_panel_background(rcBgPops);
        end
    end
end

render.render_target_bar = function()
    gResources.pokeCache(GlamourUI.settings);
    if (GlamourUI.settings.TargetBar.enabled) then
        local memoryManager = MemoryManager or AshitaCore:GetMemoryManager();
        local targetManager = memoryManager:GetTarget();
        local targetIndex = targetManager:GetTargetIndex(0);
        local targetEntity = GetEntity(targetIndex);
        local subTarget = gTarget.get_sub_target_entity();
        local nameStatus = gTarget.get_name_status();


        imgui.SetNextWindowSize({ -1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({GlamourUI.settings.TargetBar.x, GlamourUI.settings.TargetBar.y}, ImGuiCond_FirstUseEver);

        if(targetEntity ~= nil) then
            local tbBgPops = panelStyle.push_panel_background(GlamourUI.settings.TargetBar);
            if(imgui.Begin('TargetBar##GlamTB' .. get_window_suffix(), gTarget.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
                local mainFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .6) * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar);
                local targHPLen = (imgui.CalcTextSize(tostring(targetEntity.HPPercent)) * GlamourUI.settings.PlayerStats.gui_scale);
                local hpBarTexture = gResources.getTex(GlamourUI.settings, 'TargetBar', 'hpBar.png');
                local hpFillTexture = gResources.getTex(GlamourUI.settings, 'TargetBar', 'hpFill.png');


                imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                imgui.SetCursorPosY(10 * GlamourUI.settings.TargetBar.gui_scale);

                if(GlamourUI.settings.TargetBar.themed == true) then

                    local lockedTexture = gResources.getTex(GlamourUI.settings, 'TargetBar', 'LockOn.png');

                    if(hpBarTexture == nil or hpFillTexture == nil or lockedTexture == nil) then
                        GlamourUI.settings.TargetBar.themed = false;
                        gResources.pop_font(mainFontPushed);
                        imgui.End();
                        panelStyle.pop_panel_background(tbBgPops);
                        return;
                    end
                    local targHPOffset = (GlamourUI.settings.TargetBar.hpBarDim.l - targHPLen) * 0.5;

                    local nameLift = (ffxi_glyphs.TARGET_BAR_NAME_Y_LIFT or 5) * GlamourUI.settings.TargetBar.gui_scale;

                    draw_target_name(targetIndex, targetEntity, nameStatus, GlamourUI.settings.TargetBar.gui_scale);

                    --Mob ID
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    gResources.pop_font(mainFontPushed);
                    local detailFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .4) * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar);
                    local kind = (nameStatus ~= nil) and nameStatus.type or nil;
                    local filterId = entity_ids.get_filter_id(targetEntity.ServerId, kind);
                    imgui.Text(string.format('%x', filterId));

                    --Distance
                    imgui.SameLine();
                    imgui.SetCursorPosX(GlamourUI.settings.TargetBar.hpBarDim.l - imgui.CalcTextSize(get_target_distance_text(targetEntity)));
                    imgui.Text('     ' .. get_target_distance_text(targetEntity));

                    gResources.pop_font(detailFontPushed);
                    mainFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .6) * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar);
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
                    imgui.Image(hpBarTexture, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale});
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Image(hpFillTexture, {(GlamourUI.settings.TargetBar.hpBarDim.l*(targetEntity.HPPercent /100) * GlamourUI.settings.TargetBar.gui_scale),(GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale)}, {0, 0}, {targetEntity.HPPercent / 100, 1 });
                    imgui.SetCursorPosY((35 + nameLift - 5) * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.SetCursorPosX(targHPOffset * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Text(tostring(targetEntity.HPPercent) .. '%');
                    imgui.PopStyleColor();
                    if(gTarget.is_target_locked()) then
                        draw_target_lock_indicator(lockedTexture, (GlamourUI.settings.TargetBar.hpBarDim.l + 60) * GlamourUI.settings.TargetBar.gui_scale, (GlamourUI.settings.TargetBar.hpBarDim.g + 50) * GlamourUI.settings.TargetBar.gui_scale);
                    end

                else
                    local lockedTexture = gResources.getTex(GlamourUI.settings, 'TargetBar', 'LockOn.png');
                    imgui.Text(targetEntity.Name);
                    if(gTarget.is_target_locked() and GlamourUI.settings.TargetBar.lockIndicator == true) then
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0 });
                    else
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                    end
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    gResources.pop_font(mainFontPushed);
                    mainFontPushed = gResources.push_font_scale(1 * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar);
                    imgui.ProgressBar(targetEntity.HPPercent / 100, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale}, tostring(targetEntity.HPPercent) .. '%');
                    imgui.PopStyleColor(1);

                    if(gTarget.is_target_locked() and GlamourUI.settings.TargetBar.lockIndicator == true) then
                        draw_target_lock_indicator(lockedTexture, (63 + GlamourUI.settings.TargetBar.hpBarDim.l) * GlamourUI.settings.TargetBar.gui_scale, 59 * GlamourUI.settings.TargetBar.gui_scale);
                    end
                end

                if (targetEntity ~= nil) then
                    local yAfterHp = imgui.GetCursorPosY();
                    local tb = GlamourUI.settings.TargetBar;
                    local tbScale = tb.gui_scale;
                    local xAnchor = 30 * tbScale;
                    local barW = tb.hpBarDim.l * tbScale;
                    local mobdbRowH = 0;

                    if (nameStatus ~= nil and nameStatus.type == 'mob' and tb.mobdbIcons ~= false) then
                        local mobdbIconSize = 13 * (tonumber(tb.mobdbIconScale) or 1.0) * tbScale;
                        local mobdbTextScale = (tonumber(tb.font_scale) or 1.0)
                            * (tonumber(tb.mobdbTextScale) or 0.4) * tbScale;
                        local mobdbY = yAfterHp + (2 * tbScale);
                        local mobdbResult = mobdb_icons.draw_target_icons(targetIndex, {
                            xAnchor = xAnchor,
                            yPos = mobdbY,
                            barWidth = barW,
                            iconSize = mobdbIconSize,
                            textScale = mobdbTextScale,
                            tbScale = tbScale,
                            fontSettings = tb,
                        });
                        if (mobdbResult.drew == true) then
                            mobdbRowH = mobdbResult.rowHeight + (4 * tbScale);
                            yAfterHp = mobdbY + mobdbRowH;
                        end
                    end

                    if (nameStatus ~= nil and nameStatus.type == 'mob') then
                        local mobAction = target_mob_action.get_label(targetEntity.ServerId);
                        if (mobAction ~= nil and mobAction ~= '') then
                            local actionFontPushed = gResources.push_font_scale((tb.font_scale * .5) * tbScale, tb);
                            local textW = imgui.CalcTextSize(mobAction);
                            if (type(textW) == 'table') then
                                textW = tonumber(textW[1]) or tonumber(textW.x) or 0;
                            end
                            imgui.SetCursorPos({ xAnchor + barW - textW, yAfterHp + (2 * tbScale) });
                            imgui.TextColored({ 0.95, 0.82, 0.45, 1.0 }, mobAction);
                            gResources.pop_font(actionFontPushed);
                        end
                    end
                    imgui.SetCursorPosX(xAnchor);
                    imgui.SetCursorPosY(yAfterHp + (6 * tbScale));
                    local iconSize = (14 * 1.3) * tbScale;
                    local theme = (GlamourUI.settings.Party ~= nil and GlamourUI.settings.Party.pList ~= nil)
                        and GlamourUI.settings.Party.pList.buffTheme or nil;
                    local maxCol = 16;
                    local maxRow = 1;
                    local startY = imgui.GetCursorPosY();

                    local debuffs = T{};
                    local buffs = T{};
                    local timerDebuffRow = nil;
                    local timerBuffRow = nil;

                    local playerEnt = GetPlayerEntity();
                    local partySlot = party_slot_for_server_id(targetEntity.ServerId);

                    if (playerEnt ~= nil and targetEntity.ServerId == playerEnt.ServerId) then
                        local ok, icons = pcall(function()
                            return playerEnt:GetBuffs();
                        end);
                        if (ok and icons ~= nil) then
                            debuffs, buffs = split_status_icons_from_slots(icons);
                        end
                        timerBuffRow, timerDebuffRow = gResources.get_player_buff_timer_seconds_split();
                    elseif (partySlot ~= nil) then
                        local plist = gResources.get_member_status(targetEntity.ServerId, partySlot);
                        if (plist ~= nil) then
                            debuffs, buffs = split_status_icons_from_slots(plist);
                        end
                    elseif (nameStatus ~= nil and nameStatus.type == 'mob') then
                        local ids, times = enemy_debuff_tracker.GetActiveDebuffs(targetEntity.ServerId);
                        if (ids ~= nil) then
                            debuffs = ids;
                            timerDebuffRow = times;
                        end
                    end

                    if (#debuffs == 0 and #buffs == 0 and gEffects ~= nil and gEffects.get_status_ids_by_kind ~= nil) then
                        debuffs = gEffects.get_status_ids_by_kind(targetEntity.ServerId, 'debuff');
                        buffs = gEffects.get_status_ids_by_kind(targetEntity.ServerId, 'buff');
                    end

                    local function build_timer_list(kind)
                        if (kind == 'debuff') then
                            if (timerDebuffRow ~= nil) then
                                return timerDebuffRow;
                            end
                        else
                            if (timerBuffRow ~= nil) then
                                return timerBuffRow;
                            end
                        end
                        if (gEffects == nil or gEffects.get_remaining_seconds_for_status_id == nil) then
                            return nil;
                        end
                        local ids = (kind == 'debuff') and debuffs or buffs;
                        local out = T{};
                        for i = 1, #ids do
                            out[i] = gEffects.get_remaining_seconds_for_status_id(targetEntity.ServerId, ids[i]);
                        end
                        return out;
                    end

                    local bottomY = startY;
                    if (#debuffs > 0) then
                        bottomY = draw_party_buff_icon_grid(
                            debuffs,
                            iconSize,
                            maxCol,
                            maxRow,
                            theme,
                            xAnchor,
                            bottomY,
                            GlamourUI.settings.TargetBar.gui_scale,
                            1.0,
                            build_timer_list('debuff'),
                            1,
                            true,
                            tb.font_scale
                        );
                        bottomY = bottomY + (6 * tbScale);
                    end

                    if (#buffs > 0) then
                        bottomY = draw_party_buff_icon_grid(
                            buffs,
                            iconSize,
                            maxCol,
                            maxRow,
                            theme,
                            xAnchor,
                            bottomY,
                            GlamourUI.settings.TargetBar.gui_scale,
                            1.0,
                            build_timer_list('buff'),
                            1,
                            true,
                            tb.font_scale
                        );
                    end

                    imgui.SetCursorPos({ xAnchor, bottomY });
                end

                draw_target_subtarget(subTarget, hpBarTexture, hpFillTexture, (imgui.GetCursorPosY() + (8 * GlamourUI.settings.TargetBar.gui_scale)));

                do
                    local y = imgui.GetCursorPosY();
                    imgui.SetCursorPosY(y + 1);
                    imgui.Dummy({ 1, 1 });
                end
                gResources.pop_font(mainFontPushed);
                imgui.End();
            end
            panelStyle.pop_panel_background(tbBgPops);
        end
    end
end

-- Party/alliance invites now surface as a non-combat toast (see packetHandler.PartyInvite
-- + ui/toasts.lua), so this legacy dedicated invite window is intentionally a no-op. Kept
-- as a stub in case anything still references gUI.render_invite.
render.render_invite = function()
end

render.render_cast_bar = function()
    local memoryManager = MemoryManager or AshitaCore:GetMemoryManager();
    local castBar = memoryManager:GetCastBar();
    local progress = castBar:GetPercent();
    local castBarTexture = gResources.getTex(GlamourUI.settings, 'cBar', 'castBar.png');
    local castFillTexture = gResources.getTex(GlamourUI.settings, 'cBar', 'castFill.png');

    if(progress == nil)then
        progress = .35;
    end

    if((GlamourUI.settings.cBar.enabled == true and gPacket.action.Casting == true) or gCBar.cBarDummy == true) then
        local actionName;
        if(gCBar.cBarDummy == true)then
            actionName = gCBar.dummySpellName or 'Awesome Spell';
        else
            actionName = gPacket.action.castBarSpellName;
            if (actionName == nil or actionName == '') then
                local res = gPacket.action.Resource;
                if (res ~= nil and res.Name ~= nil) then
                    local n = res.Name;
                    if (type(n) == 'table') then
                        actionName = tostring(n[1] or n[2] or '');
                    elseif (type(n) == 'string') then
                        actionName = n;
                    else
                        local ok, a, b = pcall(function()
                            return n[1], n[2];
                        end);
                        if (ok) then
                            if (a ~= nil) then
                                local s = tostring(a);
                                if (s ~= '' and s ~= 'nil') then
                                    actionName = s;
                                end
                            end
                            if ((actionName == nil or actionName == '') and b ~= nil) then
                                local s = tostring(b);
                                if (s ~= '' and s ~= 'nil') then
                                    actionName = s;
                                end
                            end
                        end
                    end
                end
                if (actionName == nil or actionName == '') then
                    actionName = '';
                end
            end
        end
        local targetIndex = gPacket.action.Target;
        if(gCBar.cBarDummy == true)then
            targetIndex = gCBar.dummyTargetIndex;
        end
        local targetName = memoryManager:GetEntity():GetName(targetIndex);
        if(targetName == nil)then
            targetName = '';
        end
        local castBarText = actionName .. ' → ' .. targetName;
        imgui.SetNextWindowPos({GlamourUI.settings.cBar.x, GlamourUI.settings.cBar.y}, ImGuiCond_FirstUseEver);
        local cbarBgPops = panelStyle.push_panel_background(GlamourUI.settings.cBar);
        if(imgui.Begin('CastBar##GlamCBar' .. get_window_suffix(), true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            local fontPushed = gResources.push_font_scale(GlamourUI.settings.cBar.font_scale * 0.3, GlamourUI.settings.cBar);
            if(GlamourUI.settings.cBar.themed == true)then
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(50 * GlamourUI.settings.cBar.font_scale * 0.3);
                imgui.Image(castBarTexture, {GlamourUI.settings.cBar.BarDim.l * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale});
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(50 * GlamourUI.settings.cBar.font_scale * 0.3);

                if(gPacket.action.Interrupt == true)then
                    local interruptOffset = imgui.CalcTextSize('Interrupted');
                    imgui.SetCursorPosX((imgui.GetWindowSize() - interruptOffset) * 0.5);
                    imgui.Text('Interrupted');
                else
                    imgui.Image(castFillTexture, {GlamourUI.settings.cBar.BarDim.l * progress * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale}, {0, 0}, {progress, 1});
                end
            else
                imgui.ProgressBar(progress, { GlamourUI.settings.cBar.BarDim.l * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale }, '');
            end
            local windowWidth = imgui.GetWindowWidth();
            local textWidth = imgui.CalcTextSize(castBarText);
            local textOffset = ((windowWidth - textWidth) * 0.5);
            imgui.SetCursorPosX(textOffset);
            imgui.SetCursorPosY(5);
            imgui.Text(castBarText);
            gResources.pop_font(fontPushed);
            imgui.End();
        end
        panelStyle.pop_panel_background(cbarBgPops);
    end
end

render.render_lot = function()
    local memoryManager = MemoryManager or AshitaCore:GetMemoryManager();
    local treasurePoolSize = memoryManager:GetInventory():GetTreasurePoolItemCount();
    if(treasurePoolSize == 0)then
        return;
    end
    if (gInv ~= nil and gInv.getTreasurePool ~= nil) then
        gInv.getTreasurePool();
    end
    imgui.SetNextWindowSize({200,1}, ImGuiCond_FirstUseEver);
    local lotBgPops = panelStyle.push_panel_background(GlamourUI.settings.Inv);
    if(imgui.Begin('Lots##GlamParty' .. get_window_suffix(), gParty.tpoolis_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
        local passCount = 0;
        local lotCount = 0;
        for i=1,#gInv.treasurePool do
            local item = gInv.treasurePool[i];
            if(item.current.hasRolled)then
               lotCount = lotCount + 1;
            end
            if(item.current.hasPassed)then
                passCount = passCount +1;
            end
        end
        local allPass = passCount == #gInv.treasurePool;
        local allLot = lotCount == #gInv.treasurePool;
        local allBtnFontPushed = gResources.push_font_scale(0.35, GlamourUI.settings.Inv);
        local function tpool_all_button_size(label)
            local style = imgui.GetStyle();
            local framePadX = (tonumber(style.FramePadding.x) or 4) * 2;
            local framePadY = (tonumber(style.FramePadding.y) or 4) * 2;
            local tw, th = imgui.CalcTextSize(label);
            tw = tonumber(tw) or 0;
            th = tonumber(th) or 12;
            return {
                math.ceil(tw + framePadX + 8),
                math.max(18, math.ceil(th + framePadY)),
            };
        end
        imgui.SetCursorPosX(50);
        if(not allPass and not allLot)then
            if(imgui.Button('Lot All##TPool', tpool_all_button_size('Lot All')))then
                for i=1,#gInv.treasurePool do
                    if(not gInv.treasurePool[i].current.hasRolled)then
                        if (gInv.tryLotDrop ~= nil) then
                            gInv.tryLotDrop(gInv.treasurePool[i]);
                        else
                            gInv.TPoolLot(gInv.treasurePool[i].slot);
                        end
                    end
                end
            end
        end
        if(not allPass)then
            imgui.SameLine(0, 8);
            if(imgui.Button('Pass All##TPool', tpool_all_button_size('Pass All')))then
                for i=1,#gInv.treasurePool do
                    local item = gInv.treasurePool[i];
                    if(not item.current.hasRolled)then
                        gInv.TPoolPass(gInv.treasurePool[i].slot);
                    end
                end
            end
        end
        gResources.pop_font(allBtnFontPushed);
        local titleFontPushed = gResources.push_font_scale(0.7, GlamourUI.settings.Inv);
        imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize('Loot Table')) * 0.5);
        imgui.Text('Loot Table');
        gResources.pop_font(titleFontPushed);
        local bodyFontPushed = gResources.push_font_scale(0.4, GlamourUI.settings.Inv);
        for i=1,#gInv.treasurePool do
            local item = gInv.treasurePool[i];
            local offset = 0;
            local remaining = 0;
            if(item.expiresAt ~= nil)then
                remaining = math.max(item.expiresAt - os.time(), 0);
            end
            imgui.SetCursorPosX(offset + 10);
            if(item.name ~= nil)then
                imgui.BeginChild('TPool'..tostring(i)..'##TPOOL', {450, 60 }, 0);
                imgui.Image(item.icon, {25,25});
                imgui.SameLine();
                imgui.Text(tostring(item.slot) .. ':  ' .. item.name);
                imgui.SameLine();
                imgui.SetCursorPosX(200);
                imgui.Text('Time till Drop: ' .. string.format('%4i', remaining));
                if(not item.current.hasRolled and not item.current.hasPassed and (gInv.canLot == nil or select(1, gInv.canLot(item))))then
                    imgui.SameLine();
                    imgui.SetCursorPosX(350);
                    if(imgui.Button('Lot##TPool' .. i, {35, 25}))then
                        if (gInv.tryLotDrop ~= nil) then
                            gInv.tryLotDrop(item);
                        else
                            gInv.TPoolLot(item.slot);
                        end
                    end
                end
                if(not item.current.hasPassed)then
                    imgui.SameLine();
                    imgui.SetCursorPosX(390);
                    if(imgui.Button('Pass##TPool' .. i, {35, 25}))then
                        gInv.TPoolPass(item.slot);
                    end
                end
                imgui.Text('  Current Lot: ' .. tostring(item.current.lot));
                imgui.SameLine();
                imgui.SetCursorPosX(200);
                imgui.Text('Winning Lot: ' .. item.winner.name);
                if(item.winner.exists)then
                    imgui.SameLine();
                    imgui.SetCursorPosX(350);
                    imgui.Text(tostring(item.winner.lot));
                end
                imgui.EndChild();
            end
        end
        gResources.pop_font(bodyFontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(lotBgPops);
end

local function env_center_cursor_for_width(rowWidth, contentWidth)
    local style = imgui.GetStyle();
    local pad = tonumber(style.WindowPadding.x) or 8;
    rowWidth = tonumber(rowWidth) or 0;
    contentWidth = tonumber(contentWidth);
    if (contentWidth == nil) then
        contentWidth = math.max(0, imgui.GetWindowWidth() - pad * 2);
    end
    imgui.SetCursorPosX(pad + math.max(0, (contentWidth - rowWidth) * 0.5));
end

local function env_image_item_width(iconSize)
    return tonumber(iconSize) or 0;
end

local function env_measure_moon_suffix_width(moonText, iconSize, itemSpacing)
    local style = imgui.GetStyle();
    local sp = itemSpacing;
    local innerSp = tonumber(style.ItemInnerSpacing.x) or sp;
    local imgW = env_image_item_width(iconSize);
    return imgui_calc_text_width('    ') + sp + imgW + innerSp + imgui_calc_text_width(moonText);
end

local function env_measure_weather_row_width(weatherInfo, moonText, iconSize, itemSpacing)
    local style = imgui.GetStyle();
    local sp = itemSpacing;
    local innerSp = tonumber(style.ItemInnerSpacing.x) or sp;
    local imgW = env_image_item_width(iconSize);
    local moonSuffix = env_measure_moon_suffix_width(moonText, iconSize, itemSpacing);

    if (weatherInfo == nil) then
        return moonSuffix;
    end

    if (weatherInfo.Count == 0) then
        return imgui_calc_text_width(tostring(weatherInfo.Type)) + innerSp + moonSuffix;
    elseif (weatherInfo.Count == 1) then
        return imgW + innerSp + moonSuffix;
    elseif (weatherInfo.Count == 2) then
        return imgW + sp + imgW + innerSp + moonSuffix;
    end

    return moonSuffix;
end

local function env_player_grid_label()
    return mapcore.get_player_grid_label(map_grid.tuning_for_current());
end

local function env_measure_zone_row_width(zoneName, gridLabel, timerText, itemSpacing, showTimer)
    local innerSp = tonumber(imgui.GetStyle().ItemInnerSpacing.x) or itemSpacing;
    local leftW = imgui_calc_text_width(zoneName or '???')
        + innerSp
        + imgui_calc_text_width(gridLabel or 'H-12');
    if (showTimer == true) then
        return leftW + (itemSpacing * 2) + imgui_calc_text_width(timerText or '00:00:00');
    end
    return leftW;
end

local function env_draw_zone_row(zoneName, gridLabel, timerText, contentW, itemSpacing, showTimer, timerColor)
    local style = imgui.GetStyle();
    local pad = tonumber(style.WindowPadding.x) or 8;
    local sp = itemSpacing;
    local innerSp = tonumber(style.ItemInnerSpacing.x) or sp;
    local nameText = zoneName or '???';
    local coordText = gridLabel or '—';
    local lineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
        or (imgui.GetTextLineHeight() + (tonumber(style.ItemSpacing.y) or 4));

    imgui.SetCursorPosX(pad);
    imgui.Text(nameText);
    imgui.SameLine(0, innerSp);
    if (gridLabel ~= nil) then
        imgui.Text(coordText);
    else
        imgui.TextDisabled(coordText);
    end

    if (showTimer == true) then
        local timerLabel = timerText or '00:00:00';
        local timerW = imgui_calc_text_width(timerLabel);
        local timerOffset = pad + math.max(0, contentW - timerW);
        if (timerOffset > imgui.GetCursorPosX() + sp) then
            imgui.SameLine(timerOffset, 0);
        else
            imgui.SameLine(0, sp);
        end
        if (timerColor ~= nil) then
            imgui.TextColored(timerColor, timerLabel);
        else
            imgui.Text(timerLabel);
        end
    end

    imgui.SameLine(pad + contentW, 0);
    imgui.Dummy({ 1, lineH });
end

local function env_measure_dynamis_ki_row_width(itemSpacing)
    local innerSp = tonumber(imgui.GetStyle().ItemInnerSpacing.x) or itemSpacing;
    local labels = dynamis_tracker.get_ki_labels();
    local width = imgui_calc_text_width('Dynamis KI:');
    for i = 1, #labels do
        width = width + innerSp + imgui_calc_text_width(labels[i]);
        if (i < #labels) then
            width = width + itemSpacing;
        end
    end
    return width;
end

local function env_draw_dynamis_ki_row(contentW, itemSpacing)
    local style = imgui.GetStyle();
    local pad = tonumber(style.WindowPadding.x) or 8;
    local sp = itemSpacing;
    local innerSp = tonumber(style.ItemInnerSpacing.x) or sp;
    local labels = dynamis_tracker.get_ki_labels();
    local keyItems = dynamis_tracker.get_key_items();
    local lineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
        or (imgui.GetTextLineHeight() + (tonumber(style.ItemSpacing.y) or 4));
    local grey = { 0.55, 0.55, 0.55, 1.0 };
    local blue = { 0.45, 0.72, 1.0, 1.0 };

    imgui.SetCursorPosX(pad);
    imgui.Text('Dynamis KI:');
    for i = 1, #labels do
        imgui.SameLine(0, sp);
        if (keyItems[i] == true) then
            imgui.TextColored(blue, labels[i]);
        else
            imgui.TextColored(grey, labels[i]);
        end
    end

    imgui.SameLine(pad + contentW, 0);
    imgui.Dummy({ 1, lineH });
end

local function env_measure_day_row_width(dayTimeText, iconSize, itemSpacing)
    local innerSp = tonumber(imgui.GetStyle().ItemInnerSpacing.x) or itemSpacing;
    local imgW = env_image_item_width(iconSize);
    return imgui_calc_text_width('Day:  ') + innerSp + imgW + itemSpacing + imgui_calc_text_width(dayTimeText);
end

local function env_center_cursor_in_region(rowWidth, regionWidth, regionX)
    rowWidth = tonumber(rowWidth) or 0;
    regionWidth = tonumber(regionWidth) or 0;
    regionX = tonumber(regionX) or 0;
    imgui.SetCursorPosX(regionX + math.max(0, (regionWidth - rowWidth) * 0.5));
end

local function env_draw_day_row(dayTexture, dayTimeText, iconSize, itemSpacing, contentW)
    local style = imgui.GetStyle();
    local pad = tonumber(style.WindowPadding.x) or 8;
    local sp = itemSpacing;
    local innerSp = tonumber(style.ItemInnerSpacing.x) or sp;
    local imgW = env_image_item_width(iconSize);
    local dayW = imgui_calc_text_width('Day:  ') + innerSp + imgW + sp + imgui_calc_text_width(dayTimeText);
    local lineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
        or (imgui.GetTextLineHeight() + (tonumber(style.ItemSpacing.y) or 4));

    env_center_cursor_in_region(dayW, contentW, pad);
    imgui.Text('Day:  ');
    imgui.SameLine();
    imgui.Image(dayTexture, { iconSize, iconSize });
    imgui.SameLine();
    imgui.Text(dayTimeText);

    imgui.SameLine(pad + contentW, 0);
    imgui.Dummy({ 1, lineH });
end

local function env_panel_content_width(envSettings, weatherInfo, moonText, iconSize, itemSpacing, dayTimeText, gridLabel, includeMinimap, zoneName, zoneTimerText, showTimer, showDynamisKi)
    local weatherW = env_measure_weather_row_width(weatherInfo, moonText, iconSize, itemSpacing);
    local dayW = env_measure_day_row_width(dayTimeText or '  00:00', iconSize, itemSpacing);
    local zoneW = env_measure_zone_row_width(zoneName, gridLabel, zoneTimerText, itemSpacing, showTimer == true);
    local dynamisKiW = (showDynamisKi == true) and env_measure_dynamis_ki_row_width(itemSpacing) or 0;
    local contentW = math.max(weatherW, dayW, zoneW, dynamisKiW);
    if (includeMinimap == true and envSettings ~= nil and envSettings.minimap_enabled == true) then
        local guiScale = tonumber(envSettings.gui_scale) or 1;
        local mapW = math.max(80, math.floor((tonumber(envSettings.minimap_width) or 180) * guiScale));
        local childBorder = (tonumber(imgui.GetStyle().ChildBorderSize) or 1) * 2;
        contentW = math.max(contentW, mapW + childBorder);
    end
    return contentW, weatherW, dayW;
end

render.render_environment = function()
    local timeInfo = gEnv.GetTime();
    local weatherInfo = gEnv.GetWeather();
    local dayTexture = gResources.GetDayIcon(timeInfo.day);
    local moonTexture = gResources.getTex(GlamourUI.settings, 'Env', 'moon.png');
    local moonPhase, moonPercent = gEnv.GetMoon();
    local moonText = moonPhase .. ":  " .. tostring(moonPercent) .. '%';
    local envSettings = GlamourUI.settings.Env;
    local iconSize = env_icon_size(envSettings);
    local itemSpacing = tonumber(imgui.GetStyle().ItemSpacing.x) or 8;
    local showDynamisTracker = (envSettings.dynamis_tracker_enabled ~= false);
    local inDynamis = showDynamisTracker and dynamis_tracker.is_active();
    local showZoneTimer = (envSettings.zone_timer_enabled ~= false) and not inDynamis;
    local zoneName = gEnv.GetZoneName();
    local zoneTimerText = nil;
    local zoneTimerColor = nil;
    if (inDynamis) then
        zoneTimerText = dynamis_tracker.get_timer_text();
        zoneTimerColor = dynamis_tracker.get_timer_color();
    elseif (showZoneTimer) then
        zoneTimerText = gEnv.GetZoneTimerText();
    end
    local showRightTimer = inDynamis or showZoneTimer;

    local envBgPops = panelStyle.push_panel_background(envSettings);
    if(imgui.Begin('Environment##GlamEnv' .. get_window_suffix(), gEnv.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
        local fontPushed = gResources.push_font_scale(0.6 * envSettings.font_scale, envSettings);
        local dayTimeText = ('  %s:%s'):fmt(tostring(timeInfo.hour), tostring(timeInfo.minute));
        local gridLabel = env_player_grid_label();
        local includeMinimap = not fullscreen_map.is_open();
        local contentW, weatherRowW = env_panel_content_width(
            envSettings, weatherInfo, moonText, iconSize, itemSpacing, dayTimeText, gridLabel, includeMinimap,
            zoneName, zoneTimerText, showRightTimer, inDynamis
        );

        imgui.Dummy({ contentW, 0 });

        env_center_cursor_for_width(weatherRowW, contentW);
        draw_environment_weather(weatherInfo, iconSize);
        imgui.SameLine();
        imgui.Text('    ');
        imgui.SameLine();
        imgui.Image(moonTexture, { iconSize, iconSize });
        imgui.SameLine();
        imgui.Text(moonText);

        env_draw_day_row(dayTexture, dayTimeText, iconSize, itemSpacing, contentW);
        env_draw_zone_row(zoneName, gridLabel, zoneTimerText, contentW, itemSpacing, showRightTimer, zoneTimerColor);
        if (inDynamis) then
            env_draw_dynamis_ki_row(contentW, itemSpacing);
        end

        if (not fullscreen_map.is_open()) then
            glamMinimap.draw();
            minimap_zone_show.draw_hover_toggles(GlamourUI.settings.Env);
        end

        gResources.pop_font(fontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(envBgPops);
end

render.render_f_target = function()
    local focusTargets = gTarget.ftTable;
    local hpBarTexture = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
    local hpFillTexture = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');

    if(focusTargets ~= nil and #focusTargets > 0)then
        imgui.SetNextWindowSize({0, 0});
        local ftBgPops = panelStyle.push_panel_background(GlamourUI.settings.PlayerStats);
        if(imgui.Begin('FocusTarget##GlamFT' .. get_window_suffix(), gTarget.ft_is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            local mainFontPushed = gResources.push_font_scale(0.5, GlamourUI.settings.PlayerStats);
            imgui.Text('   Focus Targets');
            for i=1,#focusTargets do
                local focusTarget = focusTargets[i];
                if(focusTarget == nil or focusTarget.Name == nil)then
                    gTarget.remove_focus_target(i);
                    break;
                end
                imgui.Text(focusTarget.Name);
                imgui.SameLine()
                local distanceText = get_focus_target_distance_text(focusTarget);
                local dOffset = imgui.CalcTextSize(distanceText);
                imgui.SetCursorPosX(imgui.GetWindowWidth() - dOffset - 25);
                imgui.Text(distanceText);
                imgui.SetCursorPosX(10);
                imgui.Image(hpBarTexture, {150, 20});
                imgui.SameLine();
                imgui.SetCursorPosX(10);
                imgui.Image(hpFillTexture, {150 * (focusTarget.HPPercent / 100), 20}, {0,0}, {focusTarget.HPPercent / 100, 1});
                imgui.SameLine();
                imgui.SetCursorPosX(175);
                imgui.Text('     ');
                imgui.SameLine();
                gResources.pop_font(mainFontPushed);
                local buttonFontPushed = gResources.push_font_scale(0.3, GlamourUI.settings.PlayerStats);
                if(imgui.Button('-----##GlamFT' .. tostring(i), {30, 20}))then
                    gTarget.remove_focus_target(i);
                end
                gResources.pop_font(buttonFontPushed);
                mainFontPushed = gResources.push_font_scale(0.5, GlamourUI.settings.PlayerStats);
            end
            gResources.pop_font(mainFontPushed);
            imgui.End();
        end
        panelStyle.pop_panel_background(ftBgPops);
    end
end

render.render_skills = function()
    local combatSkills, craftSkills = gParty.player_skills();
    local skillOffset = 400 * GlamourUI.settings.Party.pList.gui_scale;

    if(gParty.ShowSkills == true)then
        local skillsBgPops = panelStyle.push_panel_background(GlamourUI.settings.Party.pList);
        if(imgui.Begin('Skills##GlamPT' .. get_window_suffix(), gParty.Skill_Is_Open, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            local fontPushed = gResources.push_font_scale(0.4, GlamourUI.settings.Party.pList);
            imgui.BeginTabBar('SkillsTB##GlamPT');
            if(imgui.BeginTabItem('Melee Skills##GlamPTSkills'))then
                for skillName, skillData in pairs(combatSkills.Melee) do
                    draw_skill_row(skillName, skillData, skillOffset);
                end
                imgui.EndTabItem();
            end
            if(imgui.BeginTabItem('Ranged Skills##GlamPTSkills'))then
                for skillName, skillData in pairs(combatSkills.Ranged) do
                    draw_skill_row(skillName, skillData, skillOffset);
                end
                imgui.EndTabItem();
            end
            if(imgui.BeginTabItem('Defensive Skills##GlamPTSkills'))then
                for skillName, skillData in pairs(combatSkills.Defensive) do
                    draw_skill_row(skillName, skillData, skillOffset);
                end
                imgui.EndTabItem();
            end
            if(imgui.BeginTabItem('Magic Skills##GlamPTSkills'))then
                for skillName, skillData in pairs(combatSkills.Magic) do
                    draw_skill_row(skillName, skillData, skillOffset);
                end
                imgui.EndTabItem();
            end
            if(imgui.BeginTabItem('Craft Skills##GlamPTSkills'))then
                for skillName, skillData in pairs(craftSkills) do
                    draw_skill_row(skillName, skillData, skillOffset - 10, tostring(gParty.get_craft_rank(skillData:GetRank() + 1)));
                end
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
            gResources.pop_font(fontPushed);
            imgui.End();
        end
        panelStyle.pop_panel_background(skillsBgPops);
    end
end

render.render_chat_logs = function()
    if (GlamourUI.settings.Chat == nil or GlamourUI.settings.Chat.enabled ~= true) then
        return;
    end

    if (GlamourUI.chatExpandOpen == true) then
        render_expanded_chat_panel();
    else
        render_chat_window('Chat Window 1', gChat.get_window_settings(1), 1);
        render_chat_window('Chat Window 2', gChat.get_window_settings(2), 2);
    end
end

--- "You obtained X" toasts (EXP/Limit Points/Capacity Points/Spoils). Slides in from the
--- right, shows a gradient bar baked into its background that drains as the toast's
--- lifetime runs out, then fades out over the last fadeOutDuration seconds. Width is
--- fixed (settings.width); height auto-fits the (possibly multi-line) message.
local function is_valid_toast_icon(icon)
    icon = tonumber(icon);
    return icon ~= nil and icon > 0;
end

render.render_toasts = function()
    local s = GlamourUI.settings.Toasts;
    if (s == nil or s.enabled ~= true) then
        return;
    end

    toasts.tick();
    local list = toasts.get_active();
    if (#list == 0) then
        render._toastAnchorDragging = false;
        return;
    end

    local width = math.max(120, tonumber(s.width) or 320);
    local spacing = math.max(0, tonumber(s.spacing) or 8);
    local baseX = tonumber(s.x) or 1550;
    local baseY = tonumber(s.y) or 60;
    local iconSize = 24;
    local fontScale = (tonumber(s.font_scale) or 1) * 0.45;
    local now = os.clock();
    local anchorDragging = render._toastAnchorDragging == true;

    local lockedFlags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize
    );
    -- Newest toast, once slid in, can be dragged to reposition the anchor for future toasts.
    local draggableFlags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize
    );

    local estW = width + 16;
    local estH = tonumber(render._toastH) or 30;

    local yCursor = baseY;
    -- Newest toast on top; iterate the queue end-to-start so the most recent stacks above older ones.
    for i = #list, 1, -1 do
        local entry = list[i];
        local slideT, alpha, remainingRatio = toasts.get_visual_state(entry, now);
        -- x settles to exactly baseX once the slide finishes; pin every frame so settings.x/y
        -- never accumulate drift from reading GetWindowPos back (see render_combat_toasts).
        local x = baseX + (width * (1.0 - slideT));
        local draggable = (i == #list) and (slideT >= 0.999);

        local drawW = tonumber(entry.w) or estW;
        local drawH = tonumber(entry.h) or estH;

        if (not anchorDragging or not draggable) then
            imgui.SetNextWindowPos({ x, yCursor }, ImGuiCond_Always);
        end
        imgui.SetNextWindowBgAlpha(0.0);
        if (imgui.Begin(('Toast##GlamToast%u'):fmt(entry.id), true, draggable and draggableFlags or lockedFlags)) then
            local wp = { imgui.GetWindowPos() };
            local ws = { imgui.GetWindowSize() };
            local x0, y0 = wp[1], wp[2];
            -- Ignore the bogus first-frame auto-resize size; adopting it shifts the
            -- whole stack next frame (the flicker). Trust it from frame 2 on.
            entry.framesShown = (tonumber(entry.framesShown) or 0) + 1;
            if (entry.framesShown >= 2) then
                entry.w = ws[1];
                entry.h = ws[2];
                render._toastH = ws[2];
            end

            if (draggable) then
                if (anchorDragging and imgui.IsMouseDown(0) ~= true) then
                    s.x = x0;
                    s.y = y0;
                    render._toastAnchorDragging = false;
                    anchorDragging = false;
                elseif (imgui.IsWindowHovered() and imgui.IsMouseDragging(0)) then
                    render._toastAnchorDragging = true;
                    anchorDragging = true;
                end
            end

            local dl = imgui.GetWindowDrawList();

            local bg = s.panelBackground or { 0.05, 0.05, 0.05, 0.85 };
            local bgCol = imgui.GetColorU32({ bg[1], bg[2], bg[3], (tonumber(bg[4]) or 0.85) * alpha });
            dl:AddRectFilled({ x0, y0 }, { x0 + drawW, y0 + drawH }, bgCol, 4.0, 0);

            local accent = entry.color or { 1.0, 1.0, 1.0, 1.0 };
            local barW = drawW * remainingRatio;
            if (barW > 0) then
                local colLeft = imgui.GetColorU32({ accent[1], accent[2], accent[3], 0.35 * alpha });
                local colRight = imgui.GetColorU32({ accent[1], accent[2], accent[3], 0.05 * alpha });
                local gradientOk = pcall(function()
                    dl:AddRectFilledMultiColor({ x0, y0 }, { x0 + barW, y0 + drawH }, colLeft, colRight, colRight, colLeft);
                end);
                if (not gradientOk) then
                    dl:AddRectFilled({ x0, y0 }, { x0 + barW, y0 + drawH }, colLeft, 4.0, 0);
                end
            end

            imgui.Dummy({ width, 0 });

            if (is_valid_toast_icon(entry.icon)) then
                imgui.Image(entry.icon, { iconSize, iconSize });
                if (entry.tooltip ~= nil and entry.tooltip ~= '' and imgui.IsItemHovered()) then
                    imgui.BeginTooltip();
                    imgui.Image(entry.icon, { 32, 32 });
                    imgui.SameLine();
                    imgui.Text(entry.text);
                    imgui.Separator();
                    imgui.TextWrapped(entry.tooltip);
                    imgui.EndTooltip();
                end
                imgui.SameLine();
            end

            local fontPushed = gResources.push_font_scale(fontScale, s);
            local avail = { imgui.GetContentRegionAvail() };
            local availW = tonumber(avail[1]) or (width - iconSize);
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + availW);
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, alpha });
            imgui.TextWrapped(entry.text);
            imgui.PopStyleColor();
            imgui.PopTextWrapPos();
            gResources.pop_font(fontPushed);

            imgui.End();
        end

        yCursor = yCursor + drawH + spacing;
    end
end

--- Party member weapon skill use / damaging elemental spell casts. Same slide/gradient/
--- fade visuals as render_toasts, separate queue+settings (CombatToasts) so it's an
--- independently positioned window.
render.render_combat_toasts = function()
    local s = GlamourUI.settings.CombatToasts;
    if (s == nil or s.enabled ~= true) then
        return;
    end

    combat_toasts.tick();
    local list = combat_toasts.get_active();
    if (#list == 0) then
        return;
    end

    local width = math.max(120, tonumber(s.width) or 320);
    local spacing = math.max(0, tonumber(s.spacing) or 8);
    local baseX = tonumber(s.x) or 1550;
    local baseY = tonumber(s.y) or 420;
    local fontScale = (tonumber(s.font_scale) or 1) * 0.45;
    local now = os.clock();

    local lockedFlags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize
    );

    -- Fallback sizes used only for a toast's very first frame, before imgui has measured
    -- its auto-resized size. estH carries the last measured height so a fresh toast slots
    -- in at ~the right height instead of jumping (a brand-new AlwaysAutoResize window
    -- reports a bogus size on frame 1, which is what made the whole stack flicker low).
    local estW = width + 16;
    local estH = tonumber(render._combatToastH) or 30;

    local yCursor = baseY;
    for i = #list, 1, -1 do
        local entry = list[i];
        local slideT, alpha, remainingRatio = combat_toasts.get_visual_state(entry, now);
        -- x naturally settles to exactly baseX once the slide finishes (width * 0), so every
        -- toast is hard-pinned to the configured anchor every frame -- nothing reads the window
        -- position back, so the anchor (settings.x/y) can never accumulate drift.
        local x = baseX + (width * (1.0 - slideT));

        -- Layout/draw with the size measured LAST frame (or an estimate for a brand-new
        -- toast); never the unsettled size imgui reports this frame for a fresh window.
        local drawW = tonumber(entry.w) or estW;
        local drawH = tonumber(entry.h) or estH;

        imgui.SetNextWindowPos({ x, yCursor }, ImGuiCond_Always);
        imgui.SetNextWindowBgAlpha(0.0);
        if (imgui.Begin(('CombatToast##GlamCombatToast%u'):fmt(entry.id), true, lockedFlags)) then
            local wp = { imgui.GetWindowPos() };
            local ws = { imgui.GetWindowSize() };
            local x0, y0 = wp[1], wp[2];
            -- A brand-new AlwaysAutoResize window reports a bogus size on its first
            -- frame; adopting it would shift the whole stack next frame (the flicker).
            -- Only trust the measured size from the second frame on; until then the
            -- estimate (estH) is used for both draw and layout.
            entry.framesShown = (tonumber(entry.framesShown) or 0) + 1;
            if (entry.framesShown >= 2) then
                entry.w = ws[1];
                entry.h = ws[2];
                render._combatToastH = ws[2];
            end

            local dl = imgui.GetWindowDrawList();

            local bg = s.panelBackground or { 0.05, 0.05, 0.05, 0.85 };
            local bgCol = imgui.GetColorU32({ bg[1], bg[2], bg[3], (tonumber(bg[4]) or 0.85) * alpha });
            dl:AddRectFilled({ x0, y0 }, { x0 + drawW, y0 + drawH }, bgCol, 4.0, 0);

            local accent = entry.color or { 1.0, 1.0, 1.0, 1.0 };
            local barW = drawW * remainingRatio;
            if (barW > 0) then
                local colLeft = imgui.GetColorU32({ accent[1], accent[2], accent[3], 0.35 * alpha });
                local colRight = imgui.GetColorU32({ accent[1], accent[2], accent[3], 0.05 * alpha });
                local gradientOk = pcall(function()
                    dl:AddRectFilledMultiColor({ x0, y0 }, { x0 + barW, y0 + drawH }, colLeft, colRight, colRight, colLeft);
                end);
                if (not gradientOk) then
                    dl:AddRectFilled({ x0, y0 }, { x0 + barW, y0 + drawH }, colLeft, 4.0, 0);
                end
            end

            imgui.Dummy({ width, 0 });

            local fontPushed = gResources.push_font_scale(fontScale, s);
            local avail = { imgui.GetContentRegionAvail() };
            local availW = tonumber(avail[1]) or width;
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + availW);

            local headerText = entry.header;
            local detailText = entry.detail or entry.text;
            if (headerText ~= nil and headerText ~= '') then
                imgui.PushStyleColor(ImGuiCol_Text, { accent[1], accent[2], accent[3], alpha });
                imgui.Text(headerText);
                imgui.PopStyleColor();
            end
            if (detailText ~= nil and detailText ~= '') then
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, alpha });
                imgui.TextWrapped(detailText);
                imgui.PopStyleColor();
            end

            imgui.PopTextWrapPos();
            gResources.pop_font(fontPushed);

            imgui.End();
        end

        yCursor = yCursor + drawH + spacing;
    end
end

--- Combat parser meter / detail window (gParseDB). See ui/parse_window.lua.
render.render_parse_window = function()
    parse_window.render();
end

--- Skillchain helper panel: anchored to the right of the combat toasts window, shows
--- the most recent party weapon skill and every weapon skill the *local* player could
--- use (given their currently equipped weapon) to continue or close the resulting chain.
--- Persistent (not a timed toast) -- always reflects the latest known weapon skill.
render.render_skillchain_panel = function()
    local s = GlamourUI.settings.CombatToasts;
    if (s == nil or s.enabled ~= true or s.showSkillchainPanel ~= true) then
        return;
    end

    local lastWS = combat_toasts.get_last_weaponskill();
    if (lastWS == nil) then
        return;
    end

    -- Skillchain window phase/countdown (thotbar timing model, see combat_toasts).
    local phase, secsRemaining, windowAlpha = combat_toasts.get_chain_window(lastWS);
    if (phase == 'closed') then
        return; -- window closed and faded out
    end

    local width = math.max(120, tonumber(s.width) or 320);
    local px = (tonumber(s.x) or 1550) + width + 16;
    local py = tonumber(s.y) or 420;
    local fontScale = (tonumber(s.font_scale) or 1) * 0.45;

    imgui.SetNextWindowPos({ px, py }, ImGuiCond_FirstUseEver);
    local flags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize
    );
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, windowAlpha);
    if (imgui.Begin('SkillchainPanel##GlamSkillchain', true, flags)) then
        local bgPops = panelStyle.push_panel_background(s);
        local fontPushed = gResources.push_font_scale(fontScale, s);

        local headerLabel = (lastWS.kind == 'spell') and 'Last Chain Spell'
            or (lastWS.kind == 'pet') and 'Last Pet Move' or 'Last WS';
        local headerText = ('%s: %s'):fmt(headerLabel, lastWS.name);
        if (lastWS.casterName ~= nil and lastWS.casterName ~= '') then
            headerText = headerText .. (' (%s)'):fmt(lastWS.casterName);
        end
        imgui.Text(headerText);
        if (lastWS.targetName ~= nil and lastWS.targetName ~= '') then
            imgui.TextDisabled(('vs %s'):fmt(lastWS.targetName));
        end

        -- Skillchain window countdown: before it opens, time until open; while open, time
        -- until close; once closed it's fading out (see combat_toasts.get_chain_window).
        if (phase == 'pending') then
            imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, ('Window opens in %.1fs'):fmt(secsRemaining));
        elseif (phase == 'open') then
            imgui.TextColored({ 0.4, 1.0, 0.4, 1.0 }, ('Window closes in %.1fs'):fmt(secsRemaining));
        else
            imgui.TextColored({ 1.0, 0.5, 0.4, 1.0 }, 'Window closed');
        end
        imgui.Separator();

        local options = skillchain_data.get_chain_options(lastWS.skillchain);
        if (#options == 0) then
            imgui.TextDisabled('No chains available with your current weapon/spells/pet.');
        else
            local kindTag = { ws = '[WS]', spell = '[Spell]', pet = '[Pet]' };
            for i = 1, #options do
                local opt = options[i];
                local color = skillchain_data.colors[opt.skillchain] or { 1.0, 1.0, 1.0, 1.0 };
                local tag = kindTag[opt.kind] or '[WS]';
                -- BLU/SCH options listed for planning may need a buff (Chain Affinity /
                -- Immanence) popped first -- flag those so they read as "set up, then use".
                local suffix = opt.requiresBuff and ' *(buff)' or '';
                local lineText = ('%s %s >> Lv.%u %s%s'):fmt(tag, opt.en, opt.level, opt.skillchain, suffix);
                -- Dark skillchains (Darkness / Umbra) read as near-black on the panel bg, so
                -- give them the same black-text + white-glow treatment as Too Weak mob checks.
                if (opt.skillchain == 'Darkness' or opt.skillchain == 'Umbra') then
                    draw_check_outlined_text({ text = lineText, color = { 0.0, 0.0, 0.0, windowAlpha }, glowColor = { 1.0, 1.0, 1.0, 1.0 } });
                else
                    imgui.TextColored(color, lineText);
                end
            end
        end

        gResources.pop_font(fontPushed);
        panelStyle.pop_panel_background(bgPops);
        imgui.End();
    end
    imgui.PopStyleVar();
end

return render;
