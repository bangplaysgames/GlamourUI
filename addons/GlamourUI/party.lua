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

party.Leader1 = '';
party.Leader2 = '';
party.Leader3 = '';
party.ALeader = '';

party.settings = {}

party.layout = {
    Priority = {
        'name',
        'hp',
        'mp',
        'tp'
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
    padding = 0
}

--Treasure Pool Selected Item
local treasurePoolPointer = ashita.memory.find('FFXiMain.dll', 0, '8BD18B0D????????E8????????66394222', 4, 0);

local getZone = function(index)
    local id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(index);
    return AshitaCore:GetResourceManager():GetString('zones.names', id);
end

local function GetTreasurePoolSelectedIndex()
    local ptr = ashita.memory.read_uint32(treasurePoolPointer);
    ptr = ashita.memory.read_uint32(ptr);
    return ashita.memory.read_uint16(ptr + 0x15E);
end

party.Party = {};

party.InviteActive = false;
party.InvitePlayer = nil;

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
        Member.Level = Party:GetMemberMainJobLevel(i);
        if(i < 6)then
            Member.Buffs = gResources.get_member_status(Member.Id, i);
        end
        Member.Zone = getZone(i);
    end
    return Member;
end

party.GetParty = function()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local PartyList = {}

    for i = 0,17,1 do
        table.insert(PartyList, gParty.GetMember(i));
    end
    gParty.SetPartyLeads();
    return PartyList;
end

party.getLot = function(p)
    local i = GetTreasurePoolSelectedIndex();
    local lot = AshitaCore:GetMemoryManager():GetParty():GetMemberTreasureLot(p, i);
    if(lot == 0) then
        return 'No Lot';
    elseif(lot == 65535) then
        return '---';
    else
        return lot;
    end
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
        local bgTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'background.png');

        --Party List Background Rendering
        imgui.SetNextWindowSize({bgsize.x, bgsize.y}, ImGuiCond_Always);
        imgui.SetNextWindowPos({bgpos.x, bgpos.y}, ImGuiCond_Always);
        if(imgui.Begin('Background##GlamPList', GlamourUI.settings.Party.pList.enabled, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoInputs)))then
            imgui.Image(bgTex, {bgsize.x, bgsize.y});
            imgui.End();
        end

        --Party List Rendering
        imgui.SetNextWindowSize({ -1, -1 }, ImGuiCond_Always);
        imgui.SetNextWindowPos({GlamourUI.settings.Party.pList.x, GlamourUI.settings.Party.pList.y}, ImGuiCond_FirstUseEver);
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

        --Check for missing textures.  Disable themeing and skip fram if textures are missing
        if(hpbTex == nil or hpfTex == nil or mpbTex == nil or mpfTex == nil or tpbTex == nil or tpfTex == nil or targTex == nil or pleadTex == nil or lsyncTex == nil) then
            GlamourUI.settings.Party.pList.themed = false;
            return;
        end

        --Party List Rendering
        if(imgui.Begin('PartyList##GlamPList', GlamourUI.settings.Party.pList.enabled, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground)))then
            local pos = {imgui.GetCursorScreenPos()};
            local party = AshitaCore:GetMemoryManager():GetParty();
            local partyCount = 0;

            for i=0,5,1 do
                if (party:GetMemberIsActive(i) > 0)then
                    partyCount = partyCount + 1;
                end
            end

            --Draw Party Members on Party List
            local player = GetPlayerEntity();
            local pet = '';
            if(player == nil) then
                player = 0;
            end
            if(party:GetMemberServerId(0) ~= 0)then
                pet = GetEntity(player.PetTargetIndex);
            end
            for m = 1,partyCount,1 do
                if(gParty.Party[m] ~= nil)then

                    --Determine Render Priority and then render objects in order of lowest priority tobhighest
                    for i = 1,5,1 do
                        local p = i - 1;
                        p = 5 - p;
                        gUI.renderPlayerThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pleadTex, lsyncTex, m - 1, gParty.Party[m]);
                    end
                end
            end

            --Add Pet to Party List
            if(pet ~= nil) then
                for i = 1,5,1 do
                    local p = i - 1;
                    p = 5 - p;
                    gUI.renderPetThemed(p, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, stargTex, pet, partyCount);
                end
            end

            --Set Background Size and Position for Next Frame
            bgsize.x = imgui.GetWindowWidth() + 50;
            bgsize.y = imgui.GetWindowHeight() + 50;
            local pos = {imgui.GetWindowPos()};
            bgpos.x = pos[1] - 25;
            bgpos.y = pos[2] - 25;
            imgui.End();
        end
    end
end

party.render_alliance_panel = function()
    local a1Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount2();
    local a2Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount3();

    local bgTex = gResources.getTex(GlamourUI.settings.Party, 'pList', 'background.png');

    if(a1Count > 0 or a2Count > 0)then
        --Party List Background Rendering
        imgui.SetNextWindowSize({abgsize.x, abgsize.y}, ImGuiCond_Always);
        imgui.SetNextWindowPos({abgpos.x, abgpos.y}, ImGuiCond_Always);
        if(imgui.Begin('Background##GlamAPanel', GlamourUI.settings.Party.pList.enabled, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoInputs)))then
            imgui.Image(bgTex, {abgsize.x, abgsize.y});
            imgui.End();
        end
    end

    if(a1Count >= 1 or a2Count >= 1)then
        local hpbTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'hpBar.png');
        local hpfTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'hpFill.png');
        local targTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'partyTarget.png');
        local stargTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'subTarget.png');
        local pLeadTex = gResources.getTex(GlamourUI.settings.Party, 'aPanel', 'partyLead.png');
        local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
        local evenOffset = (GlamourUI.settings.Party.aPanel.hpBarDim.l * 2) + 100;


        if(imgui.Begin('APanel##GlamAP', GlamourUI.settings.Party.aPanel.enabled, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_AlwaysAutoResize))) then
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
                    if(i % 2 == 0)then
                        local o = 50;
                        imgui.SetCursorPosY(yOff + 1);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    else
                        local o = 100  + GlamourUI.settings.Party.aPanel.hpBarDim.l

                        imgui.SetCursorPosY(yOff + 1);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    end
                end
            end
            if(a2Count > 0)then
                local strLen = imgui.CalcTextSize('Party 3');
                imgui.SetCursorPosY(120);
                imgui.SetCursorPosX((imgui.GetWindowWidth() - strLen) * 0.5);
                imgui.Text('Party 3');
                for i = 12,17,1 do
                    local mult = i-6;
                    if (mult % 2 ~= 0) then
                        mult = mult - 1;
                    end
                    local yOff = (mult * GlamourUI.settings.Party.aPanel.hpBarDim.g + 40);
                    if(i % 2 == 0)then
                        local o = 50;
                        imgui.SetCursorPosY(yOff);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
                    else
                        local o = 100  + GlamourUI.settings.Party.aPanel.hpBarDim.l
                        imgui.SetCursorPosY(yOff);
                        gUI.RenderAllianceMember(hpbTex, hpfTex, targTex, stargTex, pLeadTex, target, mult, o, gParty.Party[i + 1], i);
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

    if(GlamourUI.settings.PlayerStats.enabled == true)then
        if (imgui.Begin('Player Stats##Glam', GlamourUI.settings.PlayerStats.enabled, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
            imgui.SetWindowFontScale(GlamourUI.settings.PlayerStats.font_scale * 0.5);
            if(GlamourUI.settings.PlayerStats.themed == true) then

                local hpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpBar.png');
                local hpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'hpFill.png');
                local mpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpBar.png');
                local mpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'mpFill.png');
                local tpbTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpBar.png');
                local tpfTex = gResources.getTex(GlamourUI.settings, 'PlayerStats', 'tpFill.png');


                gUI.RenderPlayerStats(hpbTex, hpfTex, gParty.Party[1].HP, gParty.Party[1].HPP, 0);
                imgui.SameLine();
                gUI.RenderPlayerStats(mpbTex, mpfTex, gParty.Party[1].MP, gParty.Party[1].MPP, 250);
                imgui.SameLine();
                gUI.RenderPlayerStats(tpbTex, tpfTex, gParty.Party[1].TP, nil, 500);

            else

                gUI.renderPlayerNoTheme(0, { 1.0, 0.25, 0.25, 1.0 }, gParty.Party[1].HP, gParty.Party[1].HPP);
                imgui.SameLine();
                gUI.renderPlayerNoTheme(250, { 0.0, 0.5, 0.0, 1.0 }, gParty.Party[1].MP, gParty.Party[1].MPP);
                imgui.SameLine();
                gUI.renderPlayerNoTheme(500, { 0.0, 0.45, 1.0, 1.0}, gParty.Party[1].TP, nil);

            end
        end
        imgui.End();
    end
end

return party;