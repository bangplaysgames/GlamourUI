local imgui = require('imgui');
require('common');
local panelStyle = require('panelStyle');
local textShadow = require('textShadow');
local gBuffs = require('buffTable');
local compat = require('compat');
local enemy_debuff_tracker = require('enemy_debuff_tracker');
local target_mob_action = require('target_mob_action');
local chatPartyNames = require('chatPartyNames');

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
        local pushedStride = gResources.push_font_scale(fontTimer);
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
                    local pushedTimer = gResources.push_font_scale(fontTimer);
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

    return 'Lv. ' .. tostring(lv);
end

local draw_target_name = function(targetIndex, targetEntity, nameStatus, guiScale)
    local levelText = get_target_level_text(targetIndex, nameStatus);
    local nameText = targetEntity.Name;
    local textWidth = imgui.CalcTextSize(levelText ~= nil and (nameText .. levelText) or nameText) * GlamourUI.settings.PlayerStats.gui_scale;
    local xOffset = (GlamourUI.settings.TargetBar.hpBarDim.l - textWidth) * 0.5;

    if(nameStatus ~= nil)then
        gTarget.push_nameplate_color(targetIndex);
    end

    imgui.SetCursorPosX(xOffset * guiScale);
    imgui.Text(nameText);
    if(levelText ~= nil)then
        imgui.SameLine();
        imgui.Text(levelText);
    end

    if(nameStatus ~= nil)then
        imgui.PopStyleColor();
    end
end

local draw_target_subtarget = function(subTarget, hpBarTexture, hpFillTexture, yOffset)
    if(subTarget == nil)then
        return;
    end

    local fontPushed = gResources.push_font_scale(0.4 * GlamourUI.settings.TargetBar.gui_scale);
    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
    imgui.Text('Sub Target:   ');
    imgui.SameLine();
    gTarget.push_nameplate_color(subTarget);
    imgui.Text(subTarget.Name);
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

local draw_environment_weather = function(weatherInfo)
    if(weatherInfo.Count == 0)then
        imgui.Text(weatherInfo.Type);
    elseif(weatherInfo.Count == 1)then
        imgui.Image(weatherInfo.Type, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
    elseif(weatherInfo.Count == 2)then
        imgui.Image(weatherInfo.Type, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
        imgui.SameLine();
        imgui.Image(weatherInfo.Type, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
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
    local currentColor = defaultColor;

    local function flush_buffer()
        if (#buffer == 0) then
            return;
        end

        local decoded = gChat.clean_str(table.concat(buffer));
        if (#decoded > 0) then
            table.insert(segments, { text = decoded, color = currentColor });
        end

        buffer = {};
    end

    local i = 1;
    while (i <= #rawMessage) do
        local b = rawMessage:byte(i);

        if (b == 0x1F and (i + 1) <= #rawMessage) then
            local modePrefix = rawMessage:byte(i + 1);
            if (modePrefix == 0x7F or modePrefix == 0x79 or modePrefix == 0x83) then
                flush_buffer();
                i = i + 2;
            else
                buffer[#buffer + 1] = rawMessage:sub(i, i);
                i = i + 1;
            end
        elseif (b == 0x1E and (i + 1) <= #rawMessage) then
            flush_buffer();
            local code = rawMessage:byte(i + 1);
            if (code == 0x01) then
                currentColor = defaultColor;
            else
                currentColor = gChat.get_code_color(code, defaultColor);
            end
            i = i + 2;
        elseif (b == 0xFD) then
            flush_buffer();

            if ((i + 5) <= #rawMessage and rawMessage:byte(i + 5) == 0xFD) then
                local b1 = rawMessage:byte(i + 1);
                local b2 = rawMessage:byte(i + 2);

                if (b1 == 0x07 and b2 == 0x02) then
                    local hi = rawMessage:byte(i + 3);
                    local lo = rawMessage:byte(i + 4);
                    local itemId = (hi * 256) + lo;
                    local info = get_at_item_info(itemId);
                    local tokenText = (info ~= nil and info.name) or tostring(itemId);
                    local tokenSegment = make_auto_translate_item_segment(tokenText, itemId);
                    tokenSegment.color = currentColor;
                    table.insert(segments, tokenSegment);
                    i = i + 6;
                elseif (b1 == 0x02 and b2 == 0x02) then
                    local cleanedToken = gChat.clean_str(rawMessage:sub(i, i + 5));
                    if (#cleanedToken > 1 and cleanedToken:sub(1, 1) == '{' and cleanedToken:sub(-1) == '}') then
                        local tokenSegment = make_auto_translate_segment(cleanedToken:sub(2, -2));
                        tokenSegment.color = currentColor;
                        table.insert(segments, tokenSegment);
                    elseif (#cleanedToken > 0) then
                        table.insert(segments, { text = cleanedToken, color = currentColor });
                    end
                    i = i + 6;
                else
                    i = i + 1;
                end
            else
                i = i + 1;
            end
        elseif (b == 0x7F and (i + 1) <= #rawMessage) then
            flush_buffer();
            i = i + 2;
        else
            local charLen = 1;
            if ((b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC)) and (i + 1) <= #rawMessage then
                charLen = 2;
            end
            buffer[#buffer + 1] = rawMessage:sub(i, i + charLen - 1);
            i = i + charLen;
        end
    end

    flush_buffer();

    if (#segments == 0) then
        return nil;
    end

    return segments;
end

local FFXI_STAR_CHAR = '★';
local FFXI_STAR_UTF8 = '\226\152\133';
local FFXI_STAR_ALT_UTF8 = '\xe2\x80\xbb';
local FFXI_STAR_COLOR = { 1.0, 0.88, 0.35, 1.0 };
local FFXI_STAR_FALLBACK = '*';
local FFXI_STAR_SCALE = 1.2;

local function ffxi_star_display_char()
    if (GlamourUI ~= nil and GlamourUI.starGlyphMerged == true) then
        return FFXI_STAR_CHAR;
    end
    return FFXI_STAR_FALLBACK;
end

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

local function normalize_star_markers_in_text(text)
    if (text == nil or text == '') then
        return text;
    end
    text = normalize_display_text(text);
    return text
        :gsub(FFXI_STAR_ALT_UTF8, FFXI_STAR_CHAR)
        :gsub(string.char(0x81, 0x9A), FFXI_STAR_CHAR);
end

local function append_segment_text_as_wrap_tokens(tokens, text, color)
    if (text == nil or text == '') then
        return;
    end
    text = normalize_star_markers_in_text(text);
    local starPos = text:find(FFXI_STAR_CHAR, 1, true) or text:find(FFXI_STAR_UTF8, 1, true);
    if (starPos ~= nil) then
        local starText = ffxi_star_display_char();
        local starColor = FFXI_STAR_COLOR;
        local i = 1;
        while i <= #text do
            local pos = text:find(FFXI_STAR_CHAR, i, true) or text:find(FFXI_STAR_UTF8, i, true);
            if (pos == nil) then
                append_segment_text_as_wrap_tokens(tokens, text:sub(i), color);
                break;
            end
            if (pos > i) then
                append_segment_text_as_wrap_tokens(tokens, text:sub(i, pos - 1), color);
            end
            local starLen = (text:sub(pos, pos + 2) == FFXI_STAR_UTF8) and 3 or #FFXI_STAR_CHAR;
            table.insert(tokens, {
                text = starText,
                color = starColor,
                newline = false,
                atomic = true,
                parts = T{ { draw = 'ffxi_star', text = starText, color = starColor } },
            });
            i = pos + starLen;
        end
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

local function ffxi_star_part_is_star(p)
    if (p == nil) then
        return false;
    end
    if (p.draw == 'ffxi_star') then
        return true;
    end
    local t = tostring(p.text or '');
    return (t == FFXI_STAR_CHAR) or (t == FFXI_STAR_FALLBACK) or (t == FFXI_STAR_UTF8);
end

local function ffxi_star_current_font_size()
    if (imgui.GetFontSize ~= nil) then
        local fs = imgui.GetFontSize();
        if (type(fs) == 'number' and fs > 0) then
            return fs;
        end
    end
    return imgui_calc_line_height();
end

local function ffxi_star_font_size()
    return math.max(1, ffxi_star_current_font_size() * FFXI_STAR_SCALE);
end

local function ffxi_star_scaled_text_width(text)
    text = text or ffxi_star_display_char();
    if (GlamourUI == nil or GlamourUI.font == nil or imgui.PushFont == nil) then
        return imgui_calc_text_width(text) * FFXI_STAR_SCALE;
    end
    imgui.PushFont(GlamourUI.font, ffxi_star_font_size());
    local w = imgui_calc_text_width(text);
    imgui.PopFont();
    return w;
end

local function draw_ffxi_star_text(color, text)
    text = text or ffxi_star_display_char();
    local pushed = false;
    if (GlamourUI ~= nil and GlamourUI.font ~= nil and imgui.PushFont ~= nil) then
        imgui.PushFont(GlamourUI.font, ffxi_star_font_size());
        pushed = true;
    end
    imgui.TextColored(color or FFXI_STAR_COLOR, text);
    if (pushed) then
        imgui.PopFont();
    end
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
    return rawMessage:find(string.char(0x1E), 1, true) ~= nil;
end

local function get_chat_draw_tokens(entry, message, rawMessage, defaultColor, prebuiltSegments)
    local segTag = (prebuiltSegments ~= nil) and ('s' .. tostring(#prebuiltSegments)) or 'n';
    local partyStamp = chatPartyNames.is_enabled() and tostring(chatPartyNames.get_roster_cache_stamp()) or 'off';
    local cacheKey = segTag .. '|v13|' .. partyStamp .. '|' .. tostring(message or '') .. '|' .. tostring(rawMessage ~= nil and #rawMessage or 0);

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
            local tokenWidth = 0;
            if (token.atomic == true and token.parts ~= nil) then
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
                    elseif (ffxi_star_part_is_star(p)) then
                        tokenWidth = tokenWidth + ffxi_star_scaled_text_width(p.text);
                    else
                        tokenWidth = tokenWidth + imgui_calc_text_width(p.text);
                    end
                end
            else
                tokenWidth = imgui_calc_text_width(token.text);
            end

            local trimmed = token.text:gsub('%s+$', '');
            local isWhitespaceOnly = (trimmed == '');

            if (not isWhitespaceOnly and lineWidth > 0 and (lineWidth + tokenWidth) > wrapWidth) then
                advance_line();
            end

            if (not firstOnLine) then
                imgui.SameLine(0, 0);
            end

            if (token.atomic == true and token.parts ~= nil) then
                for partIndex = 1, #token.parts do
                    if (partIndex > 1) then
                        imgui.SameLine(0, 0);
                    end
                    local p = token.parts[partIndex];
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
                    elseif (ffxi_star_part_is_star(p)) then
                        draw_ffxi_star_text(p.color, p.text);
                    else
                        local partText = normalize_display_text(p.text);
                        if (p ~= nil and p.draw == 'autotranslate_item') then
                            imgui.TextColored(p.color, partText);
                            if (imgui.IsItemHovered ~= nil and imgui.IsItemHovered()) then
                                show_at_item_tooltip(p.itemId);
                            end
                        else
                            imgui.TextColored(p.color, partText);
                        end
                    end
                end
            elseif (token.text == FFXI_STAR_CHAR or token.text == FFXI_STAR_FALLBACK) then
                draw_ffxi_star_text(token.color, token.text);
            else
                imgui.TextColored(token.color, token.text);
            end

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
    if (sender == nil or sender == '' or sender == 'System' or sender == 'Battle') then
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

local function render_chat_entries_loop(chatList)
    local mc = #chatList;
    if (mc <= 0) then
        return;
    end

    for i = 1, mc do
        render_chat_entry(chatList[i]);
    end
end

local function render_chat_entry_list(chatList)
    render_chat_entries_loop(chatList);

    local sm = imgui.GetScrollMaxY();
    local sy = imgui.GetScrollY();
    if (sm >= 0 and sy > sm + 0.5) then
        imgui.SetScrollY(sm);
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

local function expand_arrow_key_down(which)
    if (which == 'left') then
        return expand_vk_high_bit(0x25) or expand_poll_imgui_key_down(ImGuiKey_LeftArrow);
    end
    if (which == 'right') then
        return expand_vk_high_bit(0x27) or expand_poll_imgui_key_down(ImGuiKey_RightArrow);
    end
    if (which == 'up') then
        return expand_vk_high_bit(0x26) or expand_poll_imgui_key_down(ImGuiKey_UpArrow);
    end
    if (which == 'down') then
        return expand_vk_high_bit(0x28) or expand_poll_imgui_key_down(ImGuiKey_DownArrow);
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

    local fontPushed = gResources.push_font_scale((w1.font_scale or 1.0) * 0.5);
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

        imgui.BeginChild(
            ('GlamChatExpandScroll##%d'):fmt(tab),
            { -1, -1 },
            0,
            bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse)
        );

        do
            GlamourUI.expandLastLineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
                or imgui_calc_text_height();
            if (GlamourUI.expandLastLineH < 1) then
                GlamourUI.expandLastLineH = 16;
            end
        end

        local chatList = get_expand_chat_list(tab);

        render_chat_entries_loop(chatList);

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

        imgui.EndChild();
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
    local fontPushed = gResources.push_font_scale(fontScale * 0.5);
    local chatWinBgPops = panelStyle.push_panel_background(settingsTable);
    textShadow.suppress_begin();

    imgui.SetNextWindowSize({ settingsTable.width or 760, settingsTable.height or 260 }, ImGuiCond_Once);
    imgui.SetNextWindowPos({ settingsTable.x or 10, settingsTable.y or 10 }, ImGuiCond_Once);
    if (imgui.Begin(title, true, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoScrollbar))) then
        imgui.BeginChild(
            ('GlamChatScroll##%d'):fmt(winIdx),
            { -1, -1 },
            0,
            bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse)
        );

        local chatList = gChat.get_window_entries(winIdx);

        render_chat_entry_list(chatList);
        imgui.SetScrollY(imgui.GetScrollMaxY());

        imgui.EndChild();

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

    local fontPushed = gResources.push_font_scale((GlamourUI.settings.Party.pList.font_scale * 0.5) * GlamourUI.settings.Party.pList.gui_scale);
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
            imgui.SameLine();
            imgui.SetCursorPosX((gParty.layout.NamePosition.x + 150) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(member.JobDisplay);
            if(memberIndex ~= 0) then
                imgui.SameLine();
                local strOffset = imgui.CalcTextSize(tostring(distance));
                imgui.SetCursorPosX((gParty.layout.hpBarDim.l - strOffset) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(tostring(distance));
            end
            if(member.LevelSync == true)then
                imgui.SameLine();
                imgui.Image(levelSyncTexture, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
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

    local fontPushed = gResources.push_font_scale((GlamourUI.settings.Party.pList.font_scale * 0.5) * GlamourUI.settings.Party.pList.gui_scale);
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
            local detailFontPushed = gResources.push_font_scale(layout.detailFontScale);
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
    local lineHeight = select(2, imgui.CalcTextSize('Mg'));
    if(type(lineHeight) ~= 'number' or lineHeight <= 0)then
        lineHeight = 12 * guiScale;
    end
    local meritsRowY = infoRowY + lineHeight + rowGap;
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
        detailFontScale = fontScale * 0.3 * guiScale,
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

        local mainFontPushed = gResources.push_font_scale(layout.mainFontScale);
        pstats_draw_themed_stat_row(layout, {
            { hpbTex, hpfTex, playerMember.HP, playerMember.HPP },
            { mpbTex, mpfTex, playerMember.MP, playerMember.MPP },
            { tpbTex, tpfTex, playerMember.TP, nil },
        });
        gResources.pop_font(mainFontPushed);

        local detailFontPushed = gResources.push_font_scale(layout.detailFontScale);
        local expFillRatio = 0;
        local expLeftText = '';
        if(gParty.EXPMode == 'EXP')then
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

        if(gParty.EXPMode == 'LP')then
            local merits = tostring(player:GetMeritPoints()) .. '/' .. tostring(player:GetMeritPointsMax());
            pstats_draw_left_text('Merits:  ' .. merits, layout.meritsRowY, layout);
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
        local mainFontPushed = gResources.push_font_scale(layout.mainFontScale);
        pstats_draw_plain_stat_row(layout, {
            { { 1.0, 0.25, 0.25, 1.0 }, playerMember.HP, playerMember.HPP },
            { { 0.0, 0.5, 0.0, 1.0 }, playerMember.MP, playerMember.MPP },
            { { 0.0, 0.45, 1.0, 1.0 }, playerMember.TP, nil },
        });

        local detailFontPushed = gResources.push_font_scale(layout.detailFontScale);
        pstats_set_pos(pstats_centered_x(layout, layout.expBarWidth), layout.expBarY);
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 1.0, 0.25, 1.0 });
        local expRatio = (maxEXP ~= nil and maxEXP > 0) and (curEXP / maxEXP) or 0;
        imgui.ProgressBar(expRatio, { layout.expBarWidth, layout.expBarHeight }, '');
        imgui.PopStyleColor();
        pstats_ensure_panel_width(layout, layout.expBarY + layout.expBarHeight, 1);

        pstats_draw_exp_info_row(layout, tostring(curEXP) .. '/' .. tostring(maxEXP), job, '', nil, nil);
        gResources.pop_font(detailFontPushed);
        gResources.pop_font(mainFontPushed);
        contentHeight = layout.infoRowY + layout.lineHeight;
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
                local fontPushed = gResources.push_font_scale((GlamourUI.settings.rcPanel.font_scale * 0.4) * GlamourUI.settings.rcPanel.gui_scale);
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
                local mainFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .6) * GlamourUI.settings.TargetBar.gui_scale);
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

                    draw_target_name(targetIndex, targetEntity, nameStatus, GlamourUI.settings.TargetBar.gui_scale);

                    --Mob ID
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    gResources.pop_font(mainFontPushed);
                    local detailFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .4) * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Text(string.format('Mob ID:  %x', targetEntity.ServerId));

                    --Distance
                    imgui.SameLine();
                    imgui.SetCursorPosX(GlamourUI.settings.TargetBar.hpBarDim.l - imgui.CalcTextSize(get_target_distance_text(targetEntity)));
                    imgui.Text('     ' .. get_target_distance_text(targetEntity));

                    gResources.pop_font(detailFontPushed);
                    mainFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .6) * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
                    imgui.Image(hpBarTexture, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale});
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Image(hpFillTexture, {(GlamourUI.settings.TargetBar.hpBarDim.l*(targetEntity.HPPercent /100) * GlamourUI.settings.TargetBar.gui_scale),(GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale)}, {0, 0}, {targetEntity.HPPercent / 100, 1 });
                    imgui.SetCursorPosY(35 * GlamourUI.settings.TargetBar.gui_scale);
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
                    mainFontPushed = gResources.push_font_scale(1 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.ProgressBar(targetEntity.HPPercent / 100, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale}, tostring(targetEntity.HPPercent) .. '%');
                    imgui.PopStyleColor(1);

                    if(gTarget.is_target_locked() and GlamourUI.settings.TargetBar.lockIndicator == true) then
                        draw_target_lock_indicator(lockedTexture, (63 + GlamourUI.settings.TargetBar.hpBarDim.l) * GlamourUI.settings.TargetBar.gui_scale, 59 * GlamourUI.settings.TargetBar.gui_scale);
                    end
                end

                if (targetEntity ~= nil) then
                    local yAfterHp = imgui.GetCursorPosY();
                    if (nameStatus.type == 'mob') then
                        local mobAction = target_mob_action.get_label(targetEntity.ServerId);
                        if (mobAction ~= nil and mobAction ~= '') then
                            local tbScale = GlamourUI.settings.TargetBar.gui_scale;
                            local barW = GlamourUI.settings.TargetBar.hpBarDim.l * tbScale;
                            local xAnchor = 30 * tbScale;
                            local actionFontPushed = gResources.push_font_scale((GlamourUI.settings.TargetBar.font_scale * .5) * tbScale);
                            local textW = imgui.CalcTextSize(mobAction);
                            if (type(textW) == 'table') then
                                textW = tonumber(textW[1]) or tonumber(textW.x) or 0;
                            end
                            imgui.SetCursorPos({ xAnchor + barW - textW, yAfterHp + (2 * tbScale) });
                            imgui.TextColored({ 0.95, 0.82, 0.45, 1.0 }, mobAction);
                            gResources.pop_font(actionFontPushed);
                        end
                    end
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.SetCursorPosY(yAfterHp + (6 * GlamourUI.settings.TargetBar.gui_scale));
                    local iconSize = (14 * 1.3) * GlamourUI.settings.TargetBar.gui_scale;
                    local theme = (GlamourUI.settings.Party ~= nil and GlamourUI.settings.Party.pList ~= nil)
                        and GlamourUI.settings.Party.pList.buffTheme or nil;
                    local maxCol = 16;
                    local maxRow = 1;
                    local xAnchor = 30 * GlamourUI.settings.TargetBar.gui_scale;
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
                    elseif (nameStatus.type == 'mob') then
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
                            GlamourUI.settings.TargetBar.font_scale
                        );
                        bottomY = bottomY + (6 * GlamourUI.settings.TargetBar.gui_scale);
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
                            GlamourUI.settings.TargetBar.font_scale
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

render.render_invite = function()
    if(gPacket.InviteActive == true)then
        local inviteBgPops = panelStyle.push_panel_background(GlamourUI.settings.Party.pList);
        if(imgui.Begin('PartyInvite##GlamPI' .. get_window_suffix(), true, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            local fontPushed = gResources.push_font_scale(GlamourUI.settings.Party.pList.font_scale * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text('Party Invite From:  ' .. gPacket.inviter);

            gResources.pop_font(fontPushed);
            imgui.End();
        end
        panelStyle.pop_panel_background(inviteBgPops);
    end
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
            local fontPushed = gResources.push_font_scale(GlamourUI.settings.cBar.font_scale * 0.3);
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
        imgui.SetCursorPosX(50);
        if(not allPass and not allLot)then
            if(imgui.Button('Lot All##TPool'))then
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
            imgui.SameLine();
            imgui.SetCursorPosX(150);
            if(imgui.Button('Pass All##TPool'))then
                for i=1,#gInv.treasurePool do
                    local item = gInv.treasurePool[i];
                    if(not item.current.hasRolled)then
                        gInv.TPoolPass(gInv.treasurePool[i].slot);
                    end
                end
            end
        end
        local titleFontPushed = gResources.push_font_scale(0.7);
        imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize('Loot Table')) * 0.5);
        imgui.Text('Loot Table');
        gResources.pop_font(titleFontPushed);
        local bodyFontPushed = gResources.push_font_scale(0.4);
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

render.render_environment = function()
    local timeInfo = gEnv.GetTime();
    local weatherInfo = gEnv.GetWeather();
    local dayTexture = gResources.GetDayIcon(timeInfo.day);
    local moonTexture = gResources.getTex(GlamourUI.settings, 'Env', 'moon.png');
    local moonPhase, moonPercent = gEnv.GetMoon();
    local moonText = moonPhase .. ":  " .. tostring(moonPercent) .. '%';

    local envBgPops = panelStyle.push_panel_background(GlamourUI.settings.Env);
    if(imgui.Begin('Environment##GlamEnv' .. get_window_suffix(), gEnv.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
        local fontPushed = gResources.push_font_scale(0.6 * GlamourUI.settings.Env.font_scale);
        draw_environment_weather(weatherInfo);
        imgui.SameLine();
        imgui.Text('    ');
        imgui.SameLine();
        imgui.Image(moonTexture, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
        imgui.SameLine();
        imgui.Text(moonText);

        local dayTextOffset = (imgui.GetWindowWidth() - (imgui.CalcTextSize('Day:    :' .. tostring(timeInfo.hour) .. tostring(timeInfo.minute)) + 25)) * 0.5 ;
        imgui.SetCursorPosX(dayTextOffset);
        imgui.Text('Day:  ');
        imgui.SameLine();
        imgui.Image(dayTexture, {25 * GlamourUI.settings.Env.gui_scale,25 * GlamourUI.settings.Env.gui_scale});
        imgui.SameLine();
        imgui.Text('  ' .. tostring(timeInfo.hour) .. ':' .. tostring(timeInfo.minute));

        gResources.pop_font(fontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(envBgPops);
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

render.render_compass = function()
    local s = GlamourUI.settings and GlamourUI.settings.Compass or nil;
    if (s == nil or s.enabled ~= true) then
        return;
    end

    local headingRad = get_player_heading_radians();
    if (headingRad == nil) then
        return;
    end

    local north_zero_offset_deg = 90;

    local width = tonumber(s.width) or 540;
    local ribbonH = math.max(32, tonumber(s.height) or 58);
    width = math.max(160, width);
    local showDegFooter = (s.show_heading_value == true);
    local degFooterH = showDegFooter and math.max(18, math.floor(14 + 6 * (tonumber(s.font_scale) or 1))) or 0;
    local windowH = ribbonH + degFooterH;

    imgui.SetNextWindowSize({ width, windowH }, ImGuiCond_Once);
    imgui.SetNextWindowPos({ tonumber(s.x) or 700, tonumber(s.y) or 15 }, ImGuiCond_Once);

    local compassBgPops = panelStyle.push_panel_background(s);
    if (imgui.Begin('Compass##GlamCompass' .. get_window_suffix(), true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse))) then
        local fontPushed = gResources.push_font_scale((tonumber(s.font_scale) or 1) * 0.5);

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

        local rawHeadingDeg = (headingRad * (180.0 / math.pi));
        local headingDeg = wrap_deg_360(rawHeadingDeg + north_zero_offset_deg);

        local fov = math.max(30, math.min(240, tonumber(s.fov_deg) or 120));
        local tick = math.max(1, math.min(45, tonumber(s.tick_deg) or 5));
        local major = math.max(tick, tonumber(s.major_tick_deg) or 15);
        local labelStep = math.max(major, tonumber(s.label_deg) or 45);

        local innerW = math.max(1, br[1] - tl[1]);
        local halfRange = fov * 0.5;

        local startDeg = math.floor((headingDeg - halfRange) / tick) * tick;
        local endDeg = math.ceil((headingDeg + halfRange) / tick) * tick;

        local tickColor = s.tickColor or { 0.90, 0.90, 0.95, 0.90 };
        local labelColor = s.labelColor or { 0.95, 0.95, 0.98, 0.95 };
        local centerColor = s.centerColor or { 0.20, 0.55, 0.95, 0.95 };

        for d = startDeg, endDeg, tick do
            local rel = wrap_deg_180(d - headingDeg);
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

        dl:AddLine({ centerX, topY }, { centerX, botY }, imgui.GetColorU32(centerColor), 3.0);

        do
            local tr = (gPacket ~= nil) and gPacket.tracking or nil;
            if (tr ~= nil and tr.active == true and tr.actIndex ~= nil and tr.actIndex ~= 0) then
                local px, py, pz = get_entity_position_guess(GetPlayerEntity());
                local tx, tz = tonumber(tr.x), tonumber(tr.z);
                if (px ~= nil and pz ~= nil and tx ~= nil and tz ~= nil) then
                    local b = bearing_deg_north0(px, pz, tx, tz);
                    local rel = wrap_deg_180(b - headingDeg);
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
            local text = ('%03d°'):fmt(math.floor(headingDeg + 0.5));
            local tw = imgui_calc_text_width(text);
            local textY = winPos[2] + ribbonH + 2;
            textShadow.draw_list_add_text_shadowed(imgui, dl, { centerX - (tw * 0.5), textY }, imgui.GetColorU32(labelColor), text);
        end

        local pos = { imgui.GetWindowPos() };
        s.x = pos[1];
        s.y = pos[2];
        s.width = imgui.GetWindowWidth();
        s.height = math.max(32, imgui.GetWindowHeight() - degFooterH);

        gResources.pop_font(fontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(compassBgPops);
end

render.render_widescan_panel = function()
    if (gPacket == nil or gPacket.widescan_is_open ~= true) then
        return;
    end

    local entries = (gPacket.BuildWidescanEntries ~= nil) and gPacket.BuildWidescanEntries() or T{};
    local npcs = T{};
    local mobs = T{};
    for i = 1, #entries do
        local e = entries[i];
        local t = tonumber(e.type) or -1;
        if (t == 1) then
            npcs[#npcs + 1] = e;
        elseif (t == 2) then
            mobs[#mobs + 1] = e;
        end
    end

    local listH = 340;
    local btnW = 55;
    local btnGap = 8;
    local btnAreaW = btnW + btnGap + btnW + 14;

    local bgPops = panelStyle.push_panel_background(GlamourUI.settings.PlayerStats);
    local fontPushed = gResources.push_font_scale(0.45);

    local headerNpcW = imgui_calc_text_width(('NPCs (%d)'):fmt(#npcs));
    local headerMobW = imgui_calc_text_width(('Mobs (%d)'):fmt(#mobs));
    local maxNpcRow = headerNpcW;
    for i = 1, #npcs do
        local e = npcs[i];
        local row = ('%s  [0x%X]'):fmt(tostring(e.name), tonumber(e.actIndex) or 0);
        maxNpcRow = math.max(maxNpcRow, imgui_calc_text_width(row));
    end
    local maxMobRow = headerMobW;
    for i = 1, #mobs do
        local e = mobs[i];
        local row = ('%s  [0x%X]'):fmt(tostring(e.name), tonumber(e.actIndex) or 0);
        maxMobRow = math.max(maxMobRow, imgui_calc_text_width(row));
    end

    local colNpcW = math.max(200, math.ceil(maxNpcRow + btnAreaW));
    local colMobW = math.max(200, math.ceil(maxMobRow + btnAreaW));
    local gutter = 12;
    local padX = 28;
    local windowW = colNpcW + colMobW + gutter + padX;

    local toolbarH = 42;
    local windowH = toolbarH + listH + 24;
    imgui.SetNextWindowSize({ windowW, windowH }, ImGuiCond_Always);

    if (imgui.Begin('Wide Scan##GlamWS' .. get_window_suffix(), gPacket.widescan_is_open, ImGuiWindowFlags_NoDecoration)) then
        if (imgui.Button('Refresh##GlamWS', { 80, 0 })) then
            if (gPacket.RequestWidescanList ~= nil) then
                gPacket.RequestWidescanList();
            end
        end
        imgui.SameLine();
        if (imgui.Button('Cancel Track##GlamWS', { 110, 0 })) then
            if (gPacket.RequestTrackingEnd ~= nil) then
                gPacket.RequestTrackingEnd();
            end
        end

        imgui.Separator();

        imgui.BeginChild('WSNpcCol##GlamWS', { colNpcW, listH }, 0);
        imgui.Text(('NPCs (%d)'):fmt(#npcs));
        imgui.Separator();
        for i = 1, #npcs do
            local e = npcs[i];
            imgui.Text(('%s  [0x%X]'):fmt(tostring(e.name), tonumber(e.actIndex) or 0));
            imgui.SameLine();
            imgui.SetCursorPosX(math.max(0, colNpcW - btnAreaW));
            if (imgui.Button(('Focus##GlamWSNpc%d'):fmt(i), { btnW, 0 })) then
                if (gTarget ~= nil and gTarget.add_focus_target_by_index ~= nil) then
                    gTarget.add_focus_target_by_index(e.actIndex);
                end
            end
            imgui.SameLine();
            if (imgui.Button(('Track##GlamWSNpc%d'):fmt(i), { btnW, 0 })) then
                if (gPacket.RequestTrackingStart ~= nil) then
                    gPacket.RequestTrackingStart(e.actIndex);
                end
            end
        end
        imgui.EndChild();

        imgui.SameLine();

        imgui.BeginChild('WSMobCol##GlamWS', { colMobW, listH }, 0);
        imgui.Text(('Mobs (%d)'):fmt(#mobs));
        imgui.Separator();
        for i = 1, #mobs do
            local e = mobs[i];
            imgui.Text(('%s  [0x%X]'):fmt(tostring(e.name), tonumber(e.actIndex) or 0));
            imgui.SameLine();
            imgui.SetCursorPosX(math.max(0, colMobW - btnAreaW));
            if (imgui.Button(('Focus##GlamWSMob%d'):fmt(i), { btnW, 0 })) then
                if (gTarget ~= nil and gTarget.add_focus_target_by_index ~= nil) then
                    gTarget.add_focus_target_by_index(e.actIndex);
                end
            end
            imgui.SameLine();
            if (imgui.Button(('Track##GlamWSMob%d'):fmt(i), { btnW, 0 })) then
                if (gPacket.RequestTrackingStart ~= nil) then
                    gPacket.RequestTrackingStart(e.actIndex);
                end
            end
        end
        imgui.EndChild();

        gResources.pop_font(fontPushed);
        imgui.End();
    end
    panelStyle.pop_panel_background(bgPops);
end

render.render_f_target = function()
    local focusTargets = gTarget.ftTable;
    local hpBarTexture = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
    local hpFillTexture = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');

    if(focusTargets ~= nil and #focusTargets > 0)then
        imgui.SetNextWindowSize({0, 0});
        local ftBgPops = panelStyle.push_panel_background(GlamourUI.settings.PlayerStats);
        if(imgui.Begin('FocusTarget##GlamFT' .. get_window_suffix(), gTarget.ft_is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            local mainFontPushed = gResources.push_font_scale(0.5);
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
                local buttonFontPushed = gResources.push_font_scale(0.3);
                if(imgui.Button('-----##GlamFT' .. tostring(i), {30, 20}))then
                    gTarget.remove_focus_target(i);
                end
                gResources.pop_font(buttonFontPushed);
                mainFontPushed = gResources.push_font_scale(0.5);
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
            local fontPushed = gResources.push_font_scale(0.4);
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

local render_chat_input_window = function()
    local chatSettings = GlamourUI.settings.Chat;
    local cm = AshitaCore:GetChatManager();
    if (cm == nil or cm:IsInputOpen() <= 0) then
        return;
    end

    textShadow.suppress_begin();

    local fontScale = (chatSettings.inputFontScale or 1.0);
    local fontPushed = gResources.push_font_scale(fontScale * 0.5);
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
    local st = (gChat.get_input_display_state ~= nil) and gChat.get_input_display_state(inputText) or { purpose = 'Say', label = 'Input' };
    local purpose = st.purpose or 'Say';
    local label = st.label or 'Input';
    local purposeColor = gChat.get_purpose_color(purpose) or { 1.0, 1.0, 1.0, 1.0 };

    local usePurposeTint = (chatSettings.inputPanelBackground == nil);
    if (usePurposeTint) then
        local bg = { purposeColor[1] * 0.12, purposeColor[2] * 0.12, purposeColor[3] * 0.12, 0.78 };
        imgui.PushStyleColor(ImGuiCol_WindowBg, bg);
    end
    if (imgui.Begin('ChatInput##Glam' .. get_window_suffix(), true, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize))) then
        imgui.SetCursorPosX(5);
        imgui.TextColored(purposeColor, (label .. ':'));
        imgui.SetCursorPosX(15);
        local cleanedInput = (gChat ~= nil and gChat.clean_str ~= nil) and gChat.clean_str(inputText) or inputText;
        if (gChat ~= nil and gChat.normalize_backslash_for_display ~= nil) then
            cleanedInput = gChat.normalize_backslash_for_display(cleanedInput);
        end
        imgui.Text(cleanedInput);
        imgui.End();
    end
    if (usePurposeTint) then
        imgui.PopStyleColor();
    end

    panelStyle.pop_panel_background(inputBgPops);
    textShadow.suppress_end();
    gResources.pop_font(fontPushed);
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
    render_chat_input_window();
end

return render;
