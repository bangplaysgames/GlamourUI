--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--


local imgui = require('imgui');
require('common');
local chat = require('chat');
local buffs = require('bufftable');


local party = {}
local bgsize = {
    x = 0,
    y = 0
}
local bgpos = {
    x = 0,
    y = 0
}
local abgsize = {
    x = 0,
    y = 0
}
local abgpos = {
    x = 0,
    y = 0
}
PartyMemberSize = T{
    x1 = 0,
    y1 = 0,
    x2 = 0,
    y2 = 0
}

party.Leader1 = '';
party.Leader2 = '';
party.Leader3 = '';
party.ALeader = '';

party.plistis_open = false;
party.apanelis_open = false;
party.pstatsis_open = false;
party.tpoolis_open = false;

party.settings = {}

party.layout = {
    Priority = {
        'name',
        'hp',
        'mp',
        'tp',
        'buffs',
        'jobIcon'
    },
    NamePosition = {
        x = 0,
        y = 0
    },
    HPBarPosition = {
        x = 0,
        y = 0,
        textX = 0,
        textY = 0
    },
    hpBarDim = {
        l = 200,
        g = 16
    },
    MPBarPosition = {
        x = 0,
        y = 0,
        textX = 0,
        textY = 0
    },
    mpBarDim = {
        l = 200,
        g = 16
    },
    TPBarPosition = {
        x = 0,
        y = 0,
        textX = 0,
        textY = 0
    },
    tpBarDim = {
        l = 200,
        g = 16
    },
    BuffPos = {
        x = 0,
        y = 0
    },
    jobIconPos = {
        x = 0,
        y = 0
    },
    padding = 0
}

--Treasure Pool Selected Item
local treasurePoolPointer = ashita.memory.find('FFXiMain.dll', 0, '8BD18B0D????????E8????????66394222', 4, 0);

local getZone = function(index)
    local id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(index);
    return AshitaCore:GetResourceManager():GetString('zones.names', id);
end



party.Party = {};

party.TreasurePool = {}

party.InviteActive = false;
party.InvitePlayer = nil;

party.EXPTable = {}
party.EXPTimeTable = {}
party.EXPSum = 0;
party.EXPTimeDelta = 0;
party.EXPperHour = 0;
party.EXPMode = 'EXP';
party.EXPReset = false;
party.CPperHour = 0;
party.CPTimeDelta = 0;
party.CPTable = {};
party.CPTimeTable = {};
party.CPSum = 0;
party.ExemPTable = {}
party.ExemPTimeTable = {}
party.ExemPperHour = 0;
party.ExemPSum = 0;
party.ExemPTimeDelta = 0;


party.GroupHeight1 = {}
party.GroupHeight1.x = 0;
party.GroupHeight1.y = 0;

party.GroupHeight2 = {}
party.GroupHeight2.x = 0;
party.GroupHeight2.y = 0;

party.tpoolis_open = false;

party.UpdatePos = function()
    GlamourUI.settings.Party.pList.x = GlamourUI.PartyList.x;
    GlamourUI.settings.Party.pList.y = GlamourUI.PartyList.y;
end

party.LevelSync = function(p)
    if(bit.band(AshitaCore:GetMemoryManager():GetParty():GetMemberFlagMask(p), 0x100) == 0x100)then
        return true;
    else
        return false;
    end
end

party.SetPartyLeads = function()
    local Party = AshitaCore:GetMemoryManager():GetParty();
    gParty.Leader1 = Party:GetAlliancePartyLeaderServerId1();
    gParty.Leader2 = Party:GetAlliancePartyLeaderServerId2();
    gParty.Leader3 = Party:GetAlliancePartyLeaderServerId3();
    if(AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount2() > 0 or AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount3() > 0)then
        gParty.ALeader = Party:GetAllianceLeaderServerId();
    end
end

party.IsLevelSync = function(p)
    return (bit.band(AshitaCore:GetMemoryManager():GetParty():GetMemberFlagMask(p), 0x100) == 0x100);
end

party.GetMember = function(i)
    local Party = AshitaCore:GetMemoryManager():GetParty();
    local Member = {}
    local active = Party:GetMemberIsActive(i) > 0;

    if(active == true)then
        Member.Id = Party:GetMemberServerId(i);
        Member.Name = Party:GetMemberName(i);
        Member.HP = Party:GetMemberHP(i);
        Member.HPP = Party:GetMemberHPPercent(i) / 100;
        Member.MP = Party:GetMemberMP(i);
        Member.MPP = Party:GetMemberMPPercent(i) / 100;
        Member.TP = Party:GetMemberTP(i);
        Member.Color = gParty.GetNameColor(Member.HPP);
        Member.Job = Party:GetMemberMainJob(i);
        Member.SJob = Party:GetMemberSubJob(i);
        Member.Level = Party:GetMemberMainJobLevel(i);
        Member.SJLevel = Party:GetMemberSubJobLevel(i);
        if(i < 6)then
            Member.Buffs = gResources.get_member_status(Member.Id, i);
        end
        Member.Zone = getZone(i);
        Member.TPool = party.getLot(i);
        if(i == 0)then
            Member.Mastered = AshitaCore:GetMemoryManager():GetPlayer():GetJobPointsSpent(Member.Job) >= 2100;
            Member.ML = AshitaCore:GetMemoryManager():GetPlayer():GetMasteryJobLevel(Member.Job);
            Member.ExemP = AshitaCore:GetMemoryManager():GetPlayer():GetMasteryExp();
            Member.MLTNL = AshitaCore:GetMemoryManager():GetPlayer():GetMasteryExpNeeded();
        end
    end
    return Member;
end

party.GetParty = function()
    local Party = AshitaCore:GetMemoryManager():GetParty();
    local PartyList = {}

    for i = 0,17,1 do
        table.insert(PartyList, party.GetMember(i));
    end
    gParty.SetPartyLeads();
    party.Party = PartyList;
    return PartyList;
end

party.getLot = function(p)
    local lotTable = {}
    for i = 0,9 do
        local lot = AshitaCore:GetMemoryManager():GetParty():GetMemberTreasureLot(p, i);
        if(lot == 0) then
            lotTable[i] = 'No Lot';
        elseif(lot == 65535) then
            lotTable[i] =  '---';
        else
            lotTable[i] = tostring(lot);
        end
    end

    return lotTable;
end

party.GetTreasurePoolSelectedIndex = function()
    local ptr = ashita.memory.read_uint32(treasurePoolPointer);
    ptr = ashita.memory.read_uint32(ptr);
    return ashita.memory.read_uint16(ptr + 0x15c), ashita.memory.read_uint16(ptr + 0x15E), ashita.memory.read_uint8(ptr + 0x160);
end

party.GetNameColor = function(h)
    if(h >= 0.75)then
        return GlamourUI.settings.Party.pList.hp1Color;
    elseif(h < 0.75 and h >= 0.55)then
        return GlamourUI.settings.Party.pList.hp2Color;
    elseif(h < 0.55 and h > 0)then
        return GlamourUI.settings.Party.pList.hp3Color;
    else
        return {0.5, 0.5, 0.5, 1.0};
    end
end

party.render_party_list = function()
    gResources.pokeCache(GlamourUI.settings);
    local menu = gHelper.getMenu();

    --Check if chatlog is expanded
    if( menu == 'fulllog') then
        gHelper.chatIsOpen = true;
    elseif(menu == 'logwindo' or menu == nil)then
        gHelper.chatIsOpen = false;
    end

    if(GlamourUI.settings.Party.pList.enabled == true and gHelper.chatIsOpen == false)then

        --Party List Rendering
        local hpbTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'hpBar.png');
        local hpfTex = gResources.getTex(GlamourUI.settings.Party, 'pList','hpFill.png');
        local mpbTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'mpBar.png');
        local mpfTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'mpFill.png');
        local tpbTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'tpBar.png');
        local tpfTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'tpFill.png');
        local targTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'partyTarget.png');
        local pleadTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'partyLead.png');
        local lsyncTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'levelSync.png');
        local stargTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'subTarget.png');
        local glowTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'glow.png');
        local Party = AshitaCore:GetMemoryManager():GetParty();
        local partyCount = 0;

        for i=0,5,1 do
            if (Party:GetMemberIsActive(i) > 0)then
                partyCount = partyCount + 1;
            end
        end

        if(not GlamourUI.settings.Party.pList.FillDown)then
            if(GlamourUI.PartyList.Drag)then
                imgui.SetNextWindowPos({GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y}, ImGuiCond_Once, {0.0, 1.0});
                GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y = imgui.GetWindowPos();
            end
        else
            if(GlamourUI.PartyList.Drag)then
                imgui.SetNextWindowPos({GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y}, ImGuiCond_Once, {0.0, 0.0});
                GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y = imgui.GetWindowPos();
            end
        end


        --Check for missing textures.  Disable themeing and skip frame if textures are missing
        if(hpbTex == nil or hpfTex == nil or mpbTex == nil or mpfTex == nil or tpbTex == nil or tpfTex == nil or targTex == nil or pleadTex == nil or lsyncTex == nil) then
            GlamourUI.settings.Party.pList.themed = false;
            return;
        end

        imgui.SetNextWindowSize({ -1, -1 }, ImGuiCond_Always);

        --Party List Rendering
        if(imgui.Begin('PartyList##GlamPList', gParty.plistis_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize)))then
            local pos = {imgui.GetCursorScreenPos()};

            if(not GlamourUI.settings.Party.pList.FillDown)then
                if(not GlamourUI.PartyList.Drag)then
                    imgui.SetWindowPos({GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y}, 0, {0.0, 1.0});
                end
            else
                if(not GlamourUI.PartyList.Drag)then
                    imgui.SetWindowPos({GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y}, 0, {0.0, 0.0});
                end
            end

            --Draw Party Members on Party List
            local player = GetPlayerEntity();
            local pet = '';
            if(player == nil) then
                player = 0;
            end
            if(Party:GetMemberServerId(0) ~= 0)then
                pet = GetEntity(player.PetTargetIndex);
            end

            if(GlamourUI.settings.Party.pList.FillDown)then
                for m = 1,partyCount,1 do
                    if(gParty.Party[m] ~= nil)then
                        local jobIconTex = gResources.getTex(GlamourUI.settings.Party, 'pList', ('%s.png'):fmt(AshitaCore:GetResourceManager():GetString("jobs.names_abbr", gParty.Party[m].Job)));

                        imgui.BeginGroup(('PartyMember %s##GlamPList'):fmt(gParty.Party[m].Name));

                        --Determine Render Priority and then render objects in order of lowest priority tobhighest
                        for i = 1,6,1 do
                            local p = i - 1;
                            p = 6 - p;
                            gUI.renderPlayerThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pleadTex, lsyncTex, m - 1, gParty.Party[m], jobIconTex);
                        end
                        imgui.EndGroup();
                        imgui.SameLine();
                        gParty.GroupHeight2.x, gParty.GroupHeight2.y =  imgui.GetCursorPos();
                        if(imgui.IsItemHovered())then
                            gParty.Hovered = true;
                        else
                            gParty.Hovered = false;
                        end
                        if(imgui.IsItemClicked())then
                            AshitaCore:GetChatManager():QueueCommand(-1, ("/ta %s"):fmt(gParty.Party[m].Name));
                        end
                        imgui.NewLine();
                    end
                end

                --Add Pet to Party List
                if(pet ~= nil) then
                    imgui.BeginGroup('Pet##GlamPList');
                    for i = 1,5,1 do
                        local p = i - 1;
                        p = 5 - p;
                        gUI.renderPetThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pet, partyCount);
                    end
                    imgui.EndGroup();
                    if(imgui.IsItemClicked())then
                        AshitaCore:GetChatManager():QueueCommand(-1, ("/ta <pet>"));
                    end
                end
            elseif(not GlamourUI.settings.Party.pList.FillDown)then
                for m = partyCount,1,-1 do
                    if(gParty.Party[m] ~= nil)then


                        imgui.BeginGroup(('PartyMember %s##GlamPList'):fmt(gParty.Party[m].Name));

                        --[[if(gParty.Hovered == true)then
                            local x = imgui.CalcItemWidth();
                            local y = gParty.GroupHeight2.y - gParty.GroupHeight1.y;
                            imgui.SetCursorPos({gParty.GroupHeight1.x, gParty.GroupHeight1.y});
                            imgui.Image(glowTex, {x, y});
                        end]]

                        --Determine Render Priority and then render objects in order of lowest priority tobhighest
                        for i = 1,5,1 do
                            local p = i - 1;
                            p = 5 - p;
                            gUI.renderPlayerThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pleadTex, lsyncTex, (m - partyCount) * -1, gParty.Party[m]);
                        end
                        imgui.EndGroup();
                        imgui.SameLine();
                        gParty.GroupHeight2.x, gParty.GroupHeight2.y =  imgui.GetCursorPos();
                        if(imgui.IsItemHovered())then
                            gParty.Hovered = true;
                        else
                            gParty.Hovered = false;
                        end
                        if(imgui.IsItemClicked())then
                            AshitaCore:GetChatManager():QueueCommand(-1, ("/ta %s"):fmt(gParty.Party[m].Name));
                        end
                        imgui.NewLine();
                    end
                end

                --Add Pet to Party List
                if(pet ~= nil) then
                    imgui.BeginGroup('Pet##GlamPList');
                    for i = 1,5,1 do
                        local p = i - 1;
                        p = 5 - p;
                        gUI.renderPetThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pet, partyCount);
                    end
                    imgui.EndGroup();
                    if(imgui.IsItemClicked())then
                        AshitaCore:GetChatManager():QueueCommand(-1, ("/ta <pet>"));
                    end
                end
                GlamourUI.PartyList.x, GlamourUI.PartyList.y = imgui.GetWindowPos();
                imgui.End();
            end
        end
    end
end

party.render_alliance_panel = function()
    local a1Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount2();
    local a2Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount3();

    if((a1Count >= 1 or a2Count >= 1) and GlamourUI.settings.Party.aPanel.enabled)then
        local hpbTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'hpBar.png');
        local hpfTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'hpFill.png');
        local targTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'partyTarget.png');
        local stargTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'subTarget.png');
        local pLeadTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'partyLead.png');
        local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
        local evenOffset = (GlamourUI.settings.Party.aPanel.hpBarDim.l * 2) + 100;


        if(imgui.Begin('APanel##GlamAP', gParty.apanelis_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
            imgui.SetWindowFontScale(0.3 * GlamourUI.settings.Party.aPanel.font_scale);
            if(a1Count > 0)then
                local strLen = imgui.CalcTextSize('Party 2');
                imgui.SetCursorPosX((imgui.GetWindowWidth() - strLen) * 0.5);
                imgui.Text('Party 2');
                for i = 6,11,1 do
                    local mult = i-6;
                    if (mult % 2 ~= 0) then
                        mult = mult - 1;
                    end
                    local yOff = (mult * GlamourUI.settings.Party.aPanel.hpBarDim.g + 16);
                    imgui.BeginGroup(('APanel %s##'):fmt(gParty.Party[i+1].Name));
                    if(i % 2 == 0)then
                        imgui.SetWindowFontScale(0.3 * GlamourUI.settings.Party.aPanel.font_scale);
                        local o = 50;
                        imgui.SetCursorPosY(yOff + 1);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    else
                        local o = 100  + GlamourUI.settings.Party.aPanel.hpBarDim.l
                        imgui.SetWindowFontScale(0.3 * GlamourUI.settings.Party.aPanel.font_scale);
                        imgui.SetCursorPosY(yOff + 1);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    end
                    imgui.EndGroup();
                    if(imgui.IsItemClicked())then
                        AshitaCore:GetChatManager():QueueCommand(-1, ('/ta %s'):fmt(gParty.Party[i].Name));
                    end
                end
            end
            if(a2Count > 0)then
                local strLen = imgui.CalcTextSize('Party 3');
                imgui.SetCursorPosX((imgui.GetWindowWidth() - strLen) * 0.5);
                imgui.Text('Party 3');
                for i = 12,17,1 do
                    imgui.BeginGroup(('APanel %s##'):fmt(gParty.Party[i+1].Name));
                    local mult = i-6;
                    if (mult % 2 ~= 0) then
                        mult = mult - 1;
                    end
                    local yOff = (mult * GlamourUI.settings.Party.aPanel.hpBarDim.g + 40);
                    if(i % 2 == 0)then
                        imgui.SetWindowFontScale(0.3 * GlamourUI.settings.Party.aPanel.font_scale);
                        local o = 50 * GlamourUI.settings.Party.aPanel.gui_scale;
                        imgui.SetCursorPosY(yOff);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    else
                        imgui.SetWindowFontScale(0.3 * GlamourUI.settings.Party.aPanel.font_scale);
                        local o = (100  + GlamourUI.settings.Party.aPanel.hpBarDim.l) * GlamourUI.settings.Party.aPanel.gui_scale;
                        imgui.SetCursorPosY(yOff);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    end
                    imgui.EndGroup();
                    if(imgui.IsItemClicked())then
                        AshitaCore:GetChatManager():QueueCommand(-1, ('/ta %s'):fmt(gParty.Party[i].Name));
                    end
                end
            end
            --Set Background Size and Position for Next Frame
            abgsize.x = imgui.GetWindowWidth() + 50;
            abgsize.y = imgui.GetWindowHeight() + 50;
            local pos = {imgui.GetWindowPos()};
            abgpos.x = pos[1] - 25;
            abgpos.y = pos[2] - 25;
            imgui.End();
        end
    end
end

party.render_player_stats = function()
    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
    imgui.SetNextWindowPos({GlamourUI.settings.PlayerStats.x, GlamourUI.settings.PlayerStats.y}, ImGuiCond_FirstUseEver);
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local curEXP = player:GetExpCurrent();
    local maxEXP = player:GetExpNeeded();
    local curLP = player:GetLimitPoints();
    local job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", party.Party[1].Job) .. tostring(party.Party[1].Level) .. '/' .. AshitaCore:GetResourceManager():GetString("jobs.names_abbr", party.Party[1].SJob) .. tostring(party.Party[1].SJLevel);
    local expModeStr = gParty.EXPMode .. ' / hr';

    if(maxEXP ~= nil)then
        local tnl = maxEXP - curEXP;
    end

    if(GlamourUI.settings.PlayerStats.enabled == true)then
        if (imgui.Begin('PlayerStats##GlamPStats', gParty.pstatsis_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
            imgui.SetWindowFontScale(GlamourUI.settings.PlayerStats.font_scale * 0.5);
            if(GlamourUI.settings.PlayerStats.themed == true) then

                local hpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
                local hpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');
                local mpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpBar.png');
                local mpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpFill.png');
                local tpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpBar.png');
                local tpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpFill.png');
                local ebTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'expBar.png');
                local efTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'expFill.png');


                gUI.RenderPlayerStats(hpbTex, hpfTex, gParty.Party[1].HP, gParty.Party[1].HPP, 0);
                imgui.SameLine();
                gUI.RenderPlayerStats(mpbTex, mpfTex, gParty.Party[1].MP, gParty.Party[1].MPP, 250);
                imgui.SameLine();
                gUI.RenderPlayerStats(tpbTex, tpfTex, gParty.Party[1].TP, nil, 500);

                imgui.SetWindowFontScale(GlamourUI.settings.PlayerStats.font_scale * 0.3);
                --EXP Bar
                imgui.SetCursorPosX(50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                if(party.EXPMode == 'EXP')then
                    imgui.Text(tostring(curEXP) .. '/' .. tostring(maxEXP));
                else
                    imgui.Text(tostring(curLP) .. '/10000');
                end
                imgui.SetCursorPosX(50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 15);
                local expBarLen = imgui.GetWindowWidth() - 100
                imgui.Image(ebTex, {expBarLen, 14});
                imgui.SetCursorPosX(50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 15);
                if(party.EXPMode == 'EXP')then
                    imgui.Image(efTex, {expBarLen * (curEXP / maxEXP), 14}, {0,0}, {curEXP / maxEXP, 1});
                else
                    imgui.Image(efTex, {expBarLen * (curLP / 10000), 14}, {0,0}, {curLP / 10000, 1});
                end
                local EXPperHourStr = tostring(gParty.EXPperHour);
                if(gParty.EXPperHour >= 1000000)then
                    EXPperHourStr = tostring(math.floor((gParty.EXPperHour / 1000000) * 100) / 100) .. 'M';
                end
                local phOffset = imgui.CalcTextSize(tostring(EXPperHourStr .. ' ' .. expModeStr));
                imgui.SetCursorPosX(imgui.GetWindowWidth() - phOffset - 50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                imgui.Text('     ');
                if(imgui.IsItemHovered())then
                    imgui.SetCursorPosX(imgui.GetWindowWidth() - phOffset - 50);
                    imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                    imgui.Text('Reset?');
                    if(imgui.IsItemClicked())then
                        gParty.EXPReset = true;
                    end
                else
                    imgui.SetCursorPosX(imgui.GetWindowWidth() - phOffset - 50);
                    imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                    imgui.Text(tostring(EXPperHourStr .. ' ' .. expModeStr));
                end
                local stroffset = (imgui.GetWindowWidth() - imgui.CalcTextSize(job)) * 0.5;
                imgui.SetCursorPosX(stroffset);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                imgui.Text(job);
                if(party.EXPMode == 'LP')then
                    local merits = tostring(player:GetMeritPoints()) .. '/' .. tostring(player:GetMeritPointsMax());
                    local cp = player:GetCapacityPoints(gParty.Party[1].Job);
                    local jp = player:GetJobPoints(gParty.Party[1].Job);
                    imgui.SameLine();
                    imgui.SetCursorPosX(imgui.GetWindowWidth() * 0.66);
                    imgui.Text('Merits:  ' .. merits);
                    if(gParty.Party[1].Level == 99 or cp > 0 or jp > 0)then
                        if(not gParty.Party[1].Mastered)then
                            imgui.SetCursorPosX(50);
                            imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 50);
                            imgui.Image(ebTex, {expBarLen, 5});
                            imgui.SetCursorPosX(50);
                            imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 50);
                            imgui.Image(efTex, {expBarLen * (cp / 30000), 5}, {0,0}, {cp / 30000, 1});
                            local JPStr = ('CP:  ' .. tostring(cp) .. ' / 30000 : (' .. tostring(jp) .. ' JP)');
                            local JPStrOffset = (imgui.GetWindowWidth() - imgui.CalcTextSize(JPStr)) * 0.5;
                            imgui.SetCursorPosX(JPStrOffset);
                            imgui.Text(JPStr);
                            imgui.SameLine();
                            local CPperHourStr = tostring(gParty.CPperHour);
                            if(gParty.CPperHour >= 1000000)then
                                CPperHourStr = tostring(math.floor((gParty.CPperHour / 1000000) * 100) / 100) .. 'M';
                            end
                            local CPphOffset = (imgui.CalcTextSize(CPperHourStr));
                            imgui.SetCursorPosX(imgui.GetWindowWidth() - CPphOffset - 50);
                            imgui.Text(tostring(CPperHourStr) .. ' CP/Hr');
                        else
                            local ExemP = gParty.Party[1].ExemP;
                            local MLTNL = gParty.Party[1].MLTNL;
                            imgui.SetCursorPosX(50);
                            imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 50);
                            imgui.Image(ebTex, {expBarLen, 5});
                            imgui.SetCursorPosX(50);
                            imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 50);
                            imgui.Image(efTex, {expBarLen * (ExemP / MLTNL), 5}, {0,0}, {ExemP / MLTNL, 1});
                            local JPStr = ('ExemP:  ' .. tostring(ExemP) .. ' / ' .. tostring(MLTNL) .. ' | Master Level:  ' .. tostring(gParty.Party[1].ML));
                            local JPStrOffset = (imgui.GetWindowWidth() - imgui.CalcTextSize(JPStr)) * 0.5;
                            imgui.SetCursorPosX(JPStrOffset);
                            imgui.Text(JPStr);
                            imgui.SameLine();
                            local ExemPperHourStr = tostring(gParty.ExemPperHour);
                            if(gParty.ExemPperHour >= 1000000)then
                                ExemPperHourStr = tostring(math.floor((gParty.ExemPperHour / 1000000) * 100) / 100) .. 'M';
                            end
                            local ExemPphOffset = (imgui.CalcTextSize(ExemPperHourStr));
                            imgui.SetCursorPosX(imgui.GetWindowWidth() - ExemPphOffset - 150);
                            imgui.Text(tostring(ExemPperHourStr) .. ' ExemP/Hr');
                        end
                    end
                end

            else

                gUI.renderPlayerNoTheme(0, { 1.0, 0.25, 0.25, 1.0 }, gParty.Party[1].HP, gParty.Party[1].HPP);
                imgui.SameLine();
                gUI.renderPlayerNoTheme(250, { 0.0, 0.5, 0.0, 1.0 }, gParty.Party[1].MP, gParty.Party[1].MPP);
                imgui.SameLine();
                gUI.renderPlayerNoTheme(500, { 0.0, 0.45, 1.0, 1.0}, gParty.Party[1].TP, nil);

                --EXP Bar
                imgui.SetCursorPosX(50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                imgui.Text(tostring(curEXP) .. '/' .. tostring(maxEXP));
                imgui.SetCursorPosX(50);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 15);
                local expBarLen = imgui.GetWindowWidth() - 100;
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, {1.0, 1.0, 0.25, 1.0});
                imgui.ProgressBar((curEXP / maxEXP), {expBarLen, 14}, '');
                imgui.PopStyleColor();
                local stroffset = (imgui.GetWindowWidth() - imgui.CalcTextSize(job)) * 0.5;
                imgui.SetCursorPosX(stroffset);
                imgui.SetCursorPosY(GlamourUI.settings.PlayerStats.BarDim.g + 30);
                imgui.Text(job);
            end
            imgui.End();
        end
    end
end

party.PlayerSkills = function()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local combat = {}
    local craft = {}
    combat.Melee = {}
    combat.Defensive = {}
    combat.Ranged = {}
    combat.Magic = {}

    local skillTable = {
        --Melee
        [1] = 'Hand to Hand',
        [2] = 'Dagger',
        [3] = 'Sword',
        [4] = 'Great Sword',
        [5] = 'Axe',
        [6] = 'Great Axe',
        [7] = 'Scythe',
        [8] = 'Polearm',
        [9] = 'Katana',
        [10] = 'Great Katana',
        [11] = 'Club',
        [12] = 'Staff',

        --Ranged
        [25] = 'Archery',
        [26] = 'Marksmanship',
        [27] = 'Throwing',

        --Defensive
        [28] = 'Guard',
        [29] = 'Evasion',
        [30] = 'Shield',
        [31] = 'Parry',

        --Magic
        [32] = 'Divine',
        [33] = 'Healing',
        [34] = 'Enhancing',
        [35] = 'Enfeebling',
        [36] = 'Elemental',
        [37] = 'Dark',
        [38] = 'Summoning',
        [39] = 'Ninjutsu',
        [40] = 'Singing',
        [41] = 'String',
        [42] = 'Wind',
        [43] = 'Blue Magic',

        --Crafts
        [48] = 'Fishing',
        [49] = 'Woodworking',
        [50] = 'Smithing',
        [51] = 'Goldsmithing',
        [52] = 'Clothcraft',
        [53] = 'Leathercraft',
        [54] = 'Bonecraft',
        [55] = 'Alchemy',
        [56] = 'Cooking',
        [57] = 'Synergy',
        [58] = 'Chocobo Digging'
    }

    for i = 1,12 do
        local pCS = player:GetCombatSkill(i);
        combat.Melee[skillTable[i]] = pCS;
    end

    for i = 25,27 do
        local pCS = player:GetCombatSkill(i);
        combat.Ranged[skillTable[i]] = pCS;
    end

    for i = 28,31 do
        local pCS = player:GetCombatSkill(i);
        combat.Defensive[skillTable[i]] = pCS;
    end

    for i = 32,43 do
        local pCS = player:GetCombatSkill(i);
        combat.Magic[skillTable[i]] = pCS;
    end

    for i = 0,10 do
        local pCrS = player:GetCraftSkill(i);
        craft[skillTable[i + 48]] = pCrS;
    end

    return combat, craft;
end

party.GetCraftRank = function(skill)
    local ranks = {
        'Amateur', 'Recruit', 'Initiate', 'Novice', 'Apprentice', 'Journeyman', 'Craftsman', 'Artisan', 'Adept', 'Veteran', 'Expert'
    }
    return ranks[skill];
end

party.Skill_Is_Open = false;
party.ShowCrafts = false;

return party;