local imgui = require('imgui');
require('common');
local chat = require('chat');
local gBuffs = require('buffTable');
local ffi = require('ffi');
local env = require('scaling');


local function DrawStatusIcons(statusIds, iconSize, maxColumns, maxRows, theme)
    if (statusIds ~= nil and #statusIds > 0) then
        local currentRow = 1;
        local currentColumn = 0;

        for i = 0,#statusIds do
            local icon = gResources.get_icon_from_theme(theme, statusIds[i]);
            if (icon ~= nil) then
                imgui.Image(icon, { iconSize, iconSize }, { 0, 0 }, { 1, 1 });

                currentColumn = currentColumn + 1;
                -- Handle multiple rows
                if (currentColumn < maxColumns) then
                    imgui.SameLine();
                else
                    currentRow = currentRow + 1;
                    if (currentRow > maxRows) then
                        return;
                    end
                    currentColumn = 0;
                    imgui.SetCursorPosX(30 + gParty.layout.BuffPos.x * GlamourUI.settings.Party.pList.gui_scale);
                end
            end
        end
    end
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

local render = {}

render.renderPlayerThemed = function(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, targ, starg, plead, lsync, p, Member)
    local element = gParty.layout.Priority;
    local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive());
    local targetEntity = GetEntity(target);
    local yOffset = 0
    local pZone = AshitaCore:GetResourceManager():GetString('zones.names', AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0));
    local sTarget, sTargActive = gTarget.GetSelectedAllianceMember();
    local menu = gHelper.getMenu();
    local subtarg = gTarget.getSubTargetEntity();
    local index = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(p);
    local distance = math.floor((math.sqrt(AshitaCore:GetMemoryManager():GetEntity():GetDistance(index))) * 100) / 100;

    --Easy Nil Catch
    if(subtarg == nil)then
        subtarg = {};
        subtarg.Id = 0;
    end

    --Calculate Y Offset
    if p > 0 then
        yOffset = (55 + gParty.layout.padding) * p;
    end

    --Draw Member Element
    imgui.SetWindowFontScale((GlamourUI.settings.Party.pList.font_scale * 0.5) * GlamourUI.settings.Party.pList.gui_scale);
    if(GlamourUI.settings.Party.pList.themed == true)then
        if(element[e] == 'name')then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);

            --Check Target and Set Cursor
            if(targetEntity ~= nil) then
                if(targetEntity.ServerId == Member.Id) then
                    imgui.Image(targ, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
                end
            end

            --Check for Sub Target and set cursor
            if((sTargActive == true and sTarget == p) or subtarg.ServerId == Member.Id)then
                imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
                imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Image(starg, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
            end

            --Set Name Position, Check if Party Leader, and Render Name
            imgui.SetCursorPosX((gParty.layout.NamePosition.x + 27) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            gParty.GroupHeight1.x, gParty.GroupHeight1.y = imgui.GetCursorPos();
            if(gParty.Leader1 == Member.Id)then
                imgui.Image(plead, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_Text, Member.Color);
            imgui.Text(Member.Name);
            imgui.PopStyleColor();
            if(p ~= 0) then
                imgui.SameLine();
                local strOffset = imgui.CalcTextSize(tostring(distance));
                imgui.SetCursorPosX((gParty.layout.hpBarDim.l - strOffset) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(tostring(distance));
            end
            if(gParty.IsLevelSync(p) == true)then
                imgui.SameLine();
                imgui.Image(lsync, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end

            return;

            --Render HP Bar and Text
        elseif(element[e] == 'hp')then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpbT, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);

            --Render Zone Name over empty bar if member is in a different zone
            if(Member.Zone == pZone)then
                imgui.Image(hpfT, {(Member.HPP * gParty.layout.hpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {Member.HPP, 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                imgui.SetCursorPosX((50 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(Member.Zone);
                return;
            end
            imgui.Text(tostring(Member.HP));
            return;

            --Render MP Bar
        elseif(element[e] == 'mp')then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpbT, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone == pZone) then
                imgui.Image(mpfT, {(Member.MPP * gParty.layout.mpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {Member.MPP, 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                return;
            end
            imgui.Text(tostring(Member.MP));
            return;

            --Render TP Bar
        elseif(element[e] == 'tp')then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpbT, {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone == pZone)then
                imgui.Image(tpfT, {(math.clamp((Member.TP / 1000), 0, 1) *gParty.layout.tpBarDim.l) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(math.clamp((Member.TP / 1000), 0, 1)), 1});
            end
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                return;
            end
            imgui.Text(tostring(Member.TP));
            return;

            --Render Buff Icons
        elseif(element[e] == 'buffs')then
            local buffs = {};
            local debuffs = {};

            if(Member.Buffs ~= nil) then
                for i = 0,#Member.Buffs do
                    local buff = Member.Buffs[i];
                    if(buff == -1) then break; end
                    if(gBuffs.IsBuff(buff) == true)then
                        table.insert(buffs, buff);
                    elseif(gBuffs.IsBuff(buff) == false)then
                        table.insert(debuffs, buff);
                    end
                end
                if(buffs ~= nil and #buffs > 0)then
                    imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.SetCursorPosY((yOffset + gParty.layout.BuffPos.y) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
                    DrawStatusIcons(buffs, (20 * GlamourUI.settings.Party.pList.buff_scale) * GlamourUI.settings.Party.pList.gui_scale, 8, 2, GlamourUI.settings.Party.pList.buffTheme);
                    imgui.PopStyleVar(1);
                end
                if(debuffs ~= nil and #debuffs > 0)then
                    imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.SetCursorPosY((yOffset + gParty.layout.BuffPos.y + 25) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
                    DrawStatusIcons(debuffs, (20 * GlamourUI.settings.Party.pList.buff_scale) * GlamourUI.settings.Party.pList.gui_scale, 8, 2, GlamourUI.settings.Party.pList.buffTheme);
                    imgui.PopStyleVar(1);
                end

                return;
            end
        end
    else
        if(element[e] == 'name')then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY(yOffset + gParty.layout.NamePosition.y * GlamourUI.settings.Party.pList.gui_scale);


            --Check Target and Set Cursor
            if(targetEntity ~= nil) then
                if(targetEntity.ServerId == Member.Id) then
                    imgui.Image(targ, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
                end
            end

            --Check for Sub Target and set cursor
            if((sTargActive == true and sTarget == p) or subtarg.ServerId == Member.Id)then
                imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
                imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Image(starg, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
            end

            --Set Name Position, Check if Party Leader, and Render Name
            imgui.SetCursorPosX((gParty.layout.NamePosition.x + 27) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            if(gParty.Leader1 == Member.Id)then
                imgui.Image(plead, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_Text, Member.Color);
            imgui.Text(Member.Name);
            imgui.PopStyleColor();
            if(gParty.IsLevelSync(p) == true)then
                imgui.SameLine();
                imgui.Image(lsync, {10 * GlamourUI.settings.Party.pList.gui_scale, 10 * GlamourUI.settings.Party.pList.gui_scale});
            end
            imgui.SameLine();

            imgui.Text(tostring(math.sqrt(AshitaCore:GetMemoryManager():GetEntity():GetDistance(p))));


            return;

            --Render HP Bar and Text
        elseif(element[e] == 'hp')then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
            imgui.ProgressBar(Member.HPP, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);

            --Render Zone Name over empty bar if member is in a different zone
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                imgui.SetCursorPosX(50 + gParty.layout.HPBarPosition.x);
                imgui.Text(Member.Zone);
                return;
            end
            imgui.Text(tostring(Member.HP));
            return;

            --Render MP Bar
        elseif(element[e] == 'mp')then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
            imgui.ProgressBar(Member.MPP, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                return;
            end
            imgui.Text(tostring(Member.MP));
            return;

            --Render TP Bar
        elseif(element[e] == 'tp')then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
            imgui.ProgressBar((math.clamp((Member.TP / 1000), 0, 1)), {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.PopStyleColor();
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            if(Member.Zone ~= pZone)then
                return;
            end
            imgui.Text(tostring(Member.TP));
            return;

            --Render Buff Icons
        elseif(element[e] == 'buffs')then
            local buffs = {};
            local debuffs = {};

            if(Member.Buffs ~= nil) then
                for i = 0,#Member.Buffs do
                    local buff = Member.Buffs[i];
                    if(buff == -1) then break; end
                    if(gBuffs.IsBuff(buff) == true)then
                        table.insert(buffs, buff);
                    elseif(gBuffs.IsBuff(buff) == false)then
                        table.insert(debuffs, buff);
                    end
                end
                if(buffs ~= nil and #buffs > 0)then
                    imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.SetCursorPosY((yOffset + gParty.layout.BuffPos.y) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
                    DrawStatusIcons(buffs, (20 * GlamourUI.settings.Party.pList.buff_scale) * GlamourUI.settings.Party.pList.gui_scale, 8, 2, GlamourUI.settings.Party.pList.buffTheme);
                    imgui.PopStyleVar(1);
                end
                if(debuffs ~= nil and #debuffs > 0)then
                    imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.SetCursorPosY((yOffset + gParty.layout.BuffPos.y + 25) * GlamourUI.settings.Party.pList.gui_scale);
                    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
                    DrawStatusIcons(debuffs, (20 * GlamourUI.settings.Party.pList.buff_scale) * GlamourUI.settings.Party.pList.gui_scale, 8, 2, GlamourUI.settings.Party.pList.buffTheme);
                    imgui.PopStyleVar(1);
                end
                return;
            end
        end
    end
end

render.renderPetThemed = function(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, targ, starg, p, c)
    local yOffset = (c * 55) + (c * gParty.layout.padding);
    local element = gParty.layout.Priority;
    local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    local targetEntity = GetEntity(target);
    local sTarget, sTargActive = gTarget.GetSelectedAllianceMember();

    --Render Name
    if element[e] == 'name' then
        imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
        imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);

        --Check Target and Set Cursor
        if(targetEntity ~= nil)then
            if(targetEntity.ServerId == p.ServerId)then
                imgui.Image(targ, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
            end
        end

        --Check for Sub Target and set cursor
        if((sTargActive == true and sTarget == p) or gTarget.getSubTargetEntity() == p)then
            imgui.SetCursorPosX(gParty.layout.NamePosition.x * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(starg, {25 * GlamourUI.settings.Party.pList.gui_scale, 25 * GlamourUI.settings.Party.pList.gui_scale});
        end
        imgui.SetCursorPosX((40 + gParty.layout.NamePosition.x) * GlamourUI.settings.Party.pList.gui_scale);
        imgui.SetCursorPosY((yOffset + gParty.layout.NamePosition.y) * GlamourUI.settings.Party.pList.gui_scale);
        imgui.Text(p.Name);

        --Render Pet Degredation Bar
        if(gRecast.PetDeg.time > 0)then
            local petdegprog = ((gRecast.PetDeg.endtime - gRecast.PetDeg.time) / gRecast.PetDeg.max);
            if(GlamourUI.settings.Party.pList.themed == true)then
                imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Image(hpbT, {200 * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale});
                imgui.SameLine();
                imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Image(hpfT, {(200 * petdegprog) * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale}, {0,0}, {petdegprog, 1});
                imgui.SameLine();
                imgui.SetCursorPosX((100 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(fmt_time(gRecast.PetDeg.endtime - gRecast.PetDeg.time));
            else
                imgui.SetCursorPosX((30 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.ProgressBar(petdegprog, {200 * GlamourUI.settings.Party.pList.gui_scale, 16 * GlamourUI.settings.Party.pList.gui_scale}, '');
                imgui.SameLine();
                imgui.SetCursorPosX((100 + gParty.layout.BuffPos.x) * GlamourUI.settings.Party.pList.gui_scale);
                imgui.Text(fmt_time(gRecast.PetDeg.endtime - gRecast.PetDeg.time));
            end
        end
        return;
    end

    if(GlamourUI.settings.Party.pList.themed == true)then
        --Render HP Bar
        if element[e] == 'hp' then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpbT, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(hpfT, {(gParty.layout.hpBarDim.l * (p.HPPercent / 100)) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(p.HPPercent / 100), 1});
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(p.HPPercent) .. '%%');
            return;
        end

        --Render MP Bar
        if element[e] == 'mp' then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpbT, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(mpfT, {(gParty.layout.mpBarDim.l * (AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100)) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0,0},{(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100),1});
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()));
            return;
        end

        --Render TP Bar
        if element[e] == 'tp' then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpbT, {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Image(tpfT, {(gParty.layout.tpBarDim.l * (math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1))) * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, {0, 0}, {(math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1)), 1});
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX)* GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP()));
            return;
        end
    else
        --Render HP Bar
        if element[e] == 'hp' then
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar(p.HPPercent, {gParty.layout.hpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.hpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.HPBarPosition.x + gParty.layout.HPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.HPBarPosition.y + gParty.layout.HPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(p.HPPercent) .. '%%');
            return;
        end

        --Render MP Bar
        if element[e] == 'mp' then
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100, {gParty.layout.mpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.mpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.MPBarPosition.x + gParty.layout.MPBarPosition.textX) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.MPBarPosition.y + gParty.layout.MPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()));
            return;
        end

        --Render TP Bar
        if element[e] == 'tp' then
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.ProgressBar((math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1)), {gParty.layout.tpBarDim.l * GlamourUI.settings.Party.pList.gui_scale, gParty.layout.tpBarDim.g * GlamourUI.settings.Party.pList.gui_scale}, '');
            imgui.SetCursorPosX((30 + gParty.layout.TPBarPosition.x + gParty.layout.TPBarPosition.textX)* GlamourUI.settings.Party.pList.gui_scale);
            imgui.SetCursorPosY((yOffset + gParty.layout.TPBarPosition.y + gParty.layout.TPBarPosition.textY) * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP()));
            return;
        end
    end
end

render.RenderAllianceMember = function(hpbT, hpfT, targ, sTarg, pLead, t, a, o, M, i)
    local pZone = AshitaCore:GetResourceManager():GetString('zones.names', AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0));
    local sTarget, sTargActive = gTarget.GetSelectedAllianceMember();
    local targetEntity = GetEntity(t);
    local yOffset = a * 25;
    local hpOffset =  GlamourUI.settings.Party.aPanel.hpBarDim.l - imgui.CalcTextSize(tostring(M.HP));
    local menu = gHelper.getMenu();
    if(GlamourUI.settings.Party.aPanel.themed == true)then
        if(M ~= nil)then
            if(M.Name ~= nil)then
                imgui.SetCursorPosX(o + 45);
                imgui.Text(tostring(M.Name));

                --[[if(menu == 'loot')then
                    imgui.SameLine();
                    imgui.Text('     ')
                    imgui.SameLine();
                    imgui.Text(tostring(gParty.getLot(i)));
                end]]

                imgui.SetCursorPosX(o + 35);
                imgui.Image(hpbT, {GlamourUI.settings.Party.aPanel.hpBarDim.l * GlamourUI.settings.Party.aPanel.gui_scale, GlamourUI.settings.Party.aPanel.hpBarDim.g * GlamourUI.settings.Party.aPanel.gui_scale});
                imgui.SameLine();
                imgui.SetCursorPosX(o + 35);
                if(M.Zone ~= pZone)then
                    imgui.SetCursorPosX(o + 45)
                    imgui.Text(tostring(M.Zone));
                else
                    imgui.Image(hpfT, {(GlamourUI.settings.Party.aPanel.hpBarDim.l * GlamourUI.settings.Party.aPanel.gui_scale) * M.HPP, GlamourUI.settings.Party.aPanel.hpBarDim.g * GlamourUI.settings.Party.aPanel.gui_scale}, {0, 0}, { M.HPP, 1});
                    imgui.SameLine();
                    imgui.SetCursorPosX((o + 35 + (hpOffset * 0.5)) * GlamourUI.settings.Party.aPanel.gui_scale);
                    imgui.Text(tostring(M.HP));

                    imgui.SameLine();
                    imgui.SetWindowFontScale((0.25 * GlamourUI.settings.Party.aPanel.font_scale) * GlamourUI.settings.Party.aPanel.gui_scale);
                    imgui.SetCursorPosX(o + 55);
                    imgui.PushStyleColor(ImGuiCol_Text, {0.4, 0.6, 1.0, 1.0});
                    imgui.Text(tostring(M.TP))
                    imgui.PopStyleColor();

                    local mpOffset = imgui.CalcTextSize(tostring(M.MP));
                    imgui.SameLine();
                    imgui.SetCursorPosX((o + 15 + GlamourUI.settings.Party.aPanel.hpBarDim.l - mpOffset) * GlamourUI.settings.Party.aPanel.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_Text, {0.35, 1.0, 0.4, 1.0});
                    imgui.Text(tostring(M.MP));
                    imgui.PopStyleColor();

                end

                if(M.Id == gParty.Leader2 or M.Id == gParty.Leader3)then
                    imgui.SameLine();
                    imgui.SetCursorPosX(o + 35);
                    imgui.Image(pLead, {10,10});
                end
                imgui.SameLine();
                imgui.SetCursorPosX(o + 45);
            end
        end
    else
        if(M ~= nil)then
            if(M.Name ~= nil)then
                imgui.SetCursorPosX(o + 45);
                imgui.Text(tostring(M.Name));

                if(menu == 'loot')then
                    imgui.SameLine();
                    imgui.Text('     ')
                    imgui.SameLine();
                    imgui.Text(tostring(gParty.getLot(i)));
                end

                imgui.SetCursorPosX(o + 35);
                imgui.ProgressBar(M.HPP, {GlamourUI.settings.Party.aPanel.hpBarDim.l * GlamourUI.settings.Party.aPanel.gui_scale, GlamourUI.settings.Party.aPanel.hpBarDim.g * GlamourUI.settings.Party.aPanel.gui_scale}, tostring(M.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(o + 35);
                if(M.Zone ~= pZone)then
                    imgui.SetCursorPosX(o + 45)
                    imgui.Text(tostring(M.Zone));
                end
                if(M.Id == gParty.Leader2 or M.Id == gParty.Leader3)then
                    imgui.SameLine();
                    imgui.SetCursorPosX(o + 35);
                    imgui.Image(pLead, {10,10});
                end
                imgui.SameLine();
                imgui.SetCursorPosX(o + 45);
            end
        end
    end
end

render.RenderPlayerStats = function(b, f, s, p, o)
    imgui.SetCursorPosX(o + 5);
    imgui.Image(b, {GlamourUI.settings.PlayerStats.BarDim.l * GlamourUI.settings.PlayerStats.gui_scale, GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(o + 5);
    if(p ~= nil)then
        imgui.Image(f, {((p * GlamourUI.settings.PlayerStats.BarDim.l) * GlamourUI.settings.PlayerStats.gui_scale), GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale}, { 0, 0 }, { p, 1 });
    else
        imgui.Image(f, {(math.clamp(s / 1000, 0, 1)) * GlamourUI.settings.PlayerStats.BarDim.l  * (GlamourUI.settings.PlayerStats.gui_scale), GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale}, { 0, 0 }, { math.clamp((s / 1000), 0, 1), 1 });
    end
    local strLen = imgui.CalcTextSize(tostring(s));
    imgui.SameLine();
    imgui.SetCursorPosX(o + ((GlamourUI.settings.PlayerStats.BarDim.l - strLen) * 0.5));
    imgui.Text(tostring(s));
end

render.renderRecast = function()
    local menu = gHelper.getMenu();
    local rcBarTex = gResources.getTex(GlamourUI.settings, 'rcPanel', 'recastBar.png');
    local rcFillTex = gResources.getTex(GlamourUI.settings, 'rcPanel', 'recastFill.png');

    local chatOpen = false;
    if(menu == 'fulllog')then
        chatOpen = true;
    elseif(menu == 'logwindo' or menu == nil)then
        chatOpen = false;
    end

    if(GlamourUI.settings.rcPanel.enabled == true and chatOpen == false)then
        local acts, timers, progs = gRecast.makeTimers();
        if(progs[1] ~= nil) then
            if(imgui.Begin('Recast##GlamRCPanel', gRecast.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
                imgui.SetWindowFontScale((GlamourUI.settings.rcPanel.font_scale * 0.4) * GlamourUI.settings.rcPanel.gui_scale);
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
                for i = 1,#timers,1 do
                    local timer = timers[i];
                    local act = acts[i];
                    local prog = progs[i];
                    local txtOffset = (imgui.GetWindowSize() - (imgui.CalcTextSize(timer) / 2 )) - 50 ;

                    imgui.Text(act .. " :  ");
                    imgui.SameLine();
                    imgui.SetCursorPosX(txtOffset);
                    imgui.Text(tostring(timer));
                    if(GlamourUI.settings.rcPanel.themed == true)then
                        imgui.SetCursorPosX(10);
                        imgui.Image(rcBarTex, {260, 6});
                        imgui.SameLine();
                        imgui.SetCursorPosX(10);
                        imgui.Image(rcFillTex, {260 * prog, 6}, {0,0}, {prog, 1});
                    else
                        imgui.ProgressBar(prog, {260, 6}, '');
                    end
                end
                imgui.PopStyleColor()
                imgui.End();
            end
        end
    end
end

render.RenderTargetBar = function()
    gResources.pokeCache(GlamourUI.settings);
    if (GlamourUI.settings.TargetBar.enabled) then
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
        local targetEntity = GetEntity(target);
        local subtarg = gTarget.getSubTargetEntity();


        imgui.SetNextWindowSize({ -1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({GlamourUI.settings.TargetBar.x, GlamourUI.settings.TargetBar.y}, ImGuiCond_FirstUseEver);

        if(targetEntity ~= nil) then
            if(imgui.Begin('TargetBar##GlamTB', gTarget.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
                imgui.SetWindowFontScale((GlamourUI.settings.TargetBar.font_scale * .6) * GlamourUI.settings.TargetBar.gui_scale);
                local targStrLen = imgui.CalcTextSize(targetEntity.Name);
                local targHPLen = imgui.CalcTextSize(tostring(targetEntity.HPPercent));
                local hpbTex = gResources.getTex(GlamourUI.settings, 'TargetBar', 'hpBar.png');
                local hpfTex = gResources.getTex(GlamourUI.settings, 'TargetBar', 'hpFill.png');


                imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                imgui.SetCursorPosY(10 * GlamourUI.settings.TargetBar.gui_scale);

                if(GlamourUI.settings.TargetBar.themed == true) then

                    local lockedTex = gResources.getTex(GlamourUI.settings, 'TargetBar', 'LockOn.png');

                    if(hpbTex == nil or hpfTex == nil or lockedTex == nil) then
                        -- missing textures, disable theming for this element and skips the current frame
                        GlamourUI.settings.TargetBar.themed = false;
                        imgui.End();
                        return;
                    end
                    local targOffset = (GlamourUI.settings.TargetBar.hpBarDim.l - targStrLen) * 0.5;
                    local targHPOffset = (GlamourUI.settings.TargetBar.hpBarDim.l - targHPLen) * 0.5;

                    --Returns a single PushStyleColor()
                    gTarget.GetNameplateColor(targetEntity);
                    imgui.SetCursorPosX(targOffset * GlamourUI.settings.TargetBar.gui_scale);;
                    imgui.Text(targetEntity.Name);
                    imgui.PopStyleColor();

                    --Mob ID
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Text(string.format('Mob ID:  %x', targetEntity.ServerId));

                    --Distance
                    imgui.SameLine();
                    imgui.SetCursorPosX(GlamourUI.settings.TargetBar.hpBarDim.l - imgui.CalcTextSize(tostring(math.floor(math.sqrt(targetEntity.Distance) * 100) / 100)));
                    imgui.Text('     ' .. tostring(math.floor(math.sqrt(targetEntity.Distance) * 100) / 100));

                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
                    imgui.Image(hpbTex, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale});
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Image(hpfTex, {(GlamourUI.settings.TargetBar.hpBarDim.l*(targetEntity.HPPercent /100) * GlamourUI.settings.TargetBar.gui_scale),(GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale)}, {0, 0}, {targetEntity.HPPercent / 100, 1 });
                    imgui.SetCursorPosY(35 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.SetCursorPosX(targHPOffset * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.Text(tostring(targetEntity.HPPercent) .. '%%');
                    imgui.PopStyleColor();
                    if(gTarget.IsTargetLocked()) then
                        imgui.SetCursorPosX(0);
                        imgui.SetCursorPosY(0);
                        imgui.Image(lockedTex, {(GlamourUI.settings.TargetBar.hpBarDim.l + 60) * GlamourUI.settings.TargetBar.gui_scale, (GlamourUI.settings.TargetBar.hpBarDim.g + 50) * GlamourUI.settings.TargetBar.gui_scale});
                    end

                else
                    local lockedTex = gResources.getTex(GlamourUI.settings, 'TargetBar', 'LockOn.png');
                    imgui.Text(targetEntity.Name);
                    if(gTarget.IsTargetLocked() and GlamourUI.settings.TargetBar.lockIndicator == true) then
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0 });
                    else
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                    end
                    imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.SetWindowFontScale(1 * GlamourUI.settings.TargetBar.gui_scale);
                    imgui.ProgressBar(targetEntity.HPPercent / 100, {GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale, GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale}, tostring(targetEntity.HPPercent) .. '%');
                    imgui.PopStyleColor(1);

                    if(gTarget.IsTargetLocked() and GlamourUI.settings.TargetBar.lockIndicator == true) then
                        imgui.SetCursorPosX(0);
                        imgui.SetCursorPosY(0);
                        imgui.Image(lockedTex, {(63 + GlamourUI.settings.TargetBar.hpBarDim.l) * GlamourUI.settings.TargetBar.gui_scale, 59 * GlamourUI.settings.TargetBar.gui_scale});
                    end
                end
                if(subtarg ~= nil)then
                    if(GlamourUI.settings.TargetBar.themed == true)then
                        imgui.SetWindowFontScale(0.4 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.Text('Sub Target:   ');
                        imgui.SameLine();
                        gTarget.GetNameplateColor(subtarg);
                        imgui.Text(subtarg.Name);
                        imgui.PopStyleColor();
                        imgui.SetCursorPosY(77);
                        imgui.SetCursorPosX(350 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.Image(hpbTex, {(GlamourUI.settings.TargetBar.hpBarDim.l * 0.5),(GlamourUI.settings.TargetBar.hpBarDim.g * 0.5)});
                        imgui.SameLine();
                        imgui.SetCursorPosX(350 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.Image(hpfTex, {(GlamourUI.settings.TargetBar.hpBarDim.l * 0.5 * (subtarg.HPPercent / 100)), (GlamourUI.settings.TargetBar.hpBarDim.g * 0.5)}, {0, 0}, {subtarg.HPPercent / 100, 1 });
                    else
                        imgui.SetWindowFontScale(0.4 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.SetCursorPosX(30 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.Text('Sub Target:   ');
                        imgui.SameLine();
                        gTarget.GetNameplateColor(subtarg);
                        imgui.Text(subtarg.Name);
                        imgui.PopStyleColor();
                        imgui.SetCursorPosY(77);
                        imgui.SetCursorPosX(350 * GlamourUI.settings.TargetBar.gui_scale);
                        imgui.ProgressBar(subtarg.HPPercent / 100, {(GlamourUI.settings.TargetBar.hpBarDim.l * GlamourUI.settings.TargetBar.gui_scale * 0.5),(GlamourUI.settings.TargetBar.hpBarDim.g * GlamourUI.settings.TargetBar.gui_scale * 0.5)});
                    end
                end
                imgui.End();
            end
        end
    end
end

render.renderPlayerNoTheme = function(o, c, p, pp)
    imgui.SetCursorPosX(o + 5);
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, c);
    if(pp ~= nil) then
        imgui.ProgressBar(pp, { GlamourUI.settings.PlayerStats.BarDim.l * GlamourUI.settings.PlayerStats.gui_scale, GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale }, '');
        imgui.PopStyleColor();
    else
        imgui.ProgressBar(p / 1000, {GlamourUI.settings.PlayerStats.BarDim.l * GlamourUI.settings.PlayerStats.gui_scale, GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale}, '');
        imgui.PopStyleColor();
        if(p > 1000) then
            imgui.SameLine();
            imgui.SetCursorPosX(o+5);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
            imgui.ProgressBar((p -1000) /1000, {GlamourUI.settings.PlayerStats.BarDim.l * GlamourUI.settings.PlayerStats.gui_scale, GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale}, '');
            imgui.PopStyleColor(1);
        end
        if(p > 2000) then
            imgui.SameLine();
            imgui.SetCursorPosX(o+5);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
            imgui.ProgressBar((p -2000) /1000, {GlamourUI.settings.PlayerStats.BarDim.l * GlamourUI.settings.PlayerStats.gui_scale, GlamourUI.settings.PlayerStats.BarDim.g * GlamourUI.settings.PlayerStats.gui_scale}, '');
            imgui.PopStyleColor(1);
        end
    end
    imgui.SameLine();
    imgui.SetCursorPosX(o+5);
    imgui.Text(tostring(p));
end

render.render_invite = function()
    if(gPacket.InviteActive == true)then
        if(imgui.Begin('PartyInvite##GlamPI', true, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            imgui.SetWindowFontScale(GlamourUI.settings.Party.pList.font_scale * GlamourUI.settings.Party.pList.gui_scale);
            imgui.Text('Party Invite From:  ' .. gPacket.inviter);

            imgui.End();
        end
    end
end

render.renderCastBar = function()
    local castbar = AshitaCore:GetMemoryManager():GetCastBar();
    local prog = castbar:GetPercent();
    local cbarTex = gResources.getTex(GlamourUI.settings, 'cBar', 'castBar.png');
    local cbarFill = gResources.getTex(GlamourUI.settings, 'cBar', 'castFill.png');

    if(prog == nil)then
        prog = .35;
    end

    if((GlamourUI.settings.cBar.enabled == true and gPacket.action.Casting == true) or gCBar.cBarDummy == true) then
        local actionName = gPacket.action.Resource.Name[1];
        local target = AshitaCore:GetMemoryManager():GetEntity():GetName(gPacket.action.Target);
        if(target == nil)then
            target = '';
        end
        local cbarstring = actionName .. ' >> ' .. target;




        imgui.SetNextWindowPos({GlamourUI.settings.cBar.x, GlamourUI.settings.cBar.y}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('CastBar##GlamCBar', gCBar.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            imgui.SetWindowFontScale(GlamourUI.settings.cBar.font_scale * 0.3);
            if(GlamourUI.settings.cBar.themed == true)then
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(50 * GlamourUI.settings.cBar.font_scale * 0.3);
                imgui.Image(cbarTex, {GlamourUI.settings.cBar.BarDim.l * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale});
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(50 * GlamourUI.settings.cBar.font_scale * 0.3);

                if(gPacket.action.Interrupt == true)then
                    local intOffset = imgui.CalcTextSize('Interrupted');
                    imgui.SetCursorPosX((imgui.GetWindowSize() - intOffset) * 0.5);
                    imgui.Text('Interrupted');
                else
                    imgui.Image(cbarFill, {GlamourUI.settings.cBar.BarDim.l * prog * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale}, {0, 0}, {prog, 1});
                end
            else
                imgui.ProgressBar(prog, { GlamourUI.settings.cBar.BarDim.l * GlamourUI.settings.cBar.gui_scale, GlamourUI.settings.cBar.BarDim.g * GlamourUI.settings.cBar.gui_scale }, '');
            end
            local wWidth = imgui.GetWindowWidth();
            local stringLen = imgui.CalcTextSize(cbarstring);
            local txtOffset = ((wWidth - stringLen) * 0.5);
            imgui.SetCursorPosX(txtOffset);
            imgui.SetCursorPosY(5);
            imgui.Text(cbarstring);
        end
        imgui.End();
    end
end

render.renderLot = function()
    local party = gParty.GetParty();
    imgui.SetNextWindowSize({200,1}, ImGuiCond_FirstUseEver);
    local index = gParty.GetTreasurePoolSelectedIndex();
    if(imgui.Begin('Lots##GlamParty', gParty.tpoolis_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
        imgui.SetWindowFontScale(0.5);
        imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize('Loot Table')) * 0.5);
        imgui.Text('Loot Table');
        imgui.SetWindowFontScale(0.3);
        for i=1,#party do
            if(party[i].Name == nil)then
                return;
            else
                if(party[i].TPool ~= nil)then
                    imgui.SetCursorPosX(10);
                    imgui.Text(tostring(party[i].Name) .. ":                  ");
                    imgui.SameLine();
                    imgui.SetCursorPosX(imgui.GetWindowWidth() - imgui.CalcTextSize(tostring(party[i].TPool[index])) - 10);
                    imgui.Text(tostring(party[i].TPool[index]));
                end
            end
        end
        imgui.End();
    end
end

render.renderEnvironment = function()
    local time = gEnv.GetTime();
    local weather, count = gEnv.GetWeather();
    local dTex = gResources.GetDayIcon(time.day);

    if(imgui.Begin('Environment##GlamEnv', gEnv.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
        imgui.SetWindowFontScale(0.6 * GlamourUI.settings.Env.font_scale);

        imgui.Image(dTex, {25 * GlamourUI.settings.Env.gui_scale,25 * GlamourUI.settings.Env.gui_scale});
        imgui.SameLine();
        imgui.Text('  ' .. tostring(time.hour) .. ':' .. tostring(time.minute));
        if(count == 0)then
            local txtOffset = imgui.CalcTextSize(weather);
            imgui.SetCursorPosX((imgui.GetWindowWidth() - txtOffset) * 0.5);
            imgui.Text(weather);
        elseif(count == 1)then
            local imgOffset = (imgui.GetWindowWidth() - 25) * 0.5;
            imgui.SetCursorPosX(imgOffset);
            imgui.Image(weather, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
        elseif(count == 2)then
            local imgOffset = (imgui.GetWindowWidth() - 50) * 0.5;
            imgui.SetCursorPosX(imgOffset);
            imgui.Image(weather, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
            imgui.SameLine();
            imgui.Image(weather, {25 * GlamourUI.settings.Env.gui_scale, 25 * GlamourUI.settings.Env.gui_scale});
        end
        imgui.End();
    end
end

--Focus Target Panel
render.renderFTarget = function()
    local ftTable = gTarget.ftTable;
    local hpbT = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
    local hpfT = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');

    if(ftTable ~= nil and #ftTable > 0)then
        if(imgui.Begin('FocusTarget##GlamFT', gTarget.ft_is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            imgui.SetWindowFontScale(0.5);
            imgui.Text('   Focus Targets');
            for i=1,#ftTable do
                imgui.SetWindowFontScale(0.5);
                imgui.Text(ftTable[i].Name);
                imgui.SetCursorPosX(10);
                imgui.Image(hpbT, {100, 20});
                imgui.SameLine();
                imgui.SetCursorPosX(10);
                imgui.Image(hpfT, {100 * (ftTable[i].HPPercent / 100), 20}, {0,0}, {ftTable[i].HPPercent / 100, 1});
                imgui.SameLine();
                imgui.Text('   ');
                imgui.SameLine();
                imgui.SetWindowFontScale(0.3);
                if(imgui.Button('-----##GlamFT', {30, 20}))then
                    gTarget.RemoveFocusTarget(i);
                end
            end
            imgui.End();
        end
    end
end

return render;