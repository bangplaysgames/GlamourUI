--[[]
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--


addon.name = 'GlamourUI';
addon.author = 'Banggugyangu';
addon.desc = "A modular and customizable interface for FFXI";
addon.version = '0.4.5';

local imgui = require('imgui')


local settings = require('settings')
require('common')
local chat = require('chat')
require('helperfunctions')
local ffi = require('ffi')
local d3d8 = require('d3d8')

local dbug = false;

local default_settings = T{

    partylist = T{
        enabled = true,
        bgOpacity = 1,
        font_scale = 1.5,
        gui_scale = 1,
        layout = 'Default',
        theme = 'Default',
        themed = true,
        x = 12,
        y = 150,
        hpBarDim = T{
            l = 200,
            g = 16
        },
        mpBarDim = T{
            l = 200,
            g = 16
        },
        tpBarDim = T{
            l = 200,
            g = 16
        }
    },

    targetbar = T{
         enabled = true,
         font_scale = 1.5,
         gui_scale = 1,
         lockIndicator = true,
         theme = 'Default',
         themed = true,
         x = 1000,
         y = 150,
         hpBarDim = T{
             l = 660,
             g = 16
         }
    },

    alliancePanel = T{
        enabled = true,
        font_scale = 1.5,
        gui_scale = 1,
        theme = 'Default',
        themed = true,
        x = 12,
        y = 700,
        hpBarDim = T{
            l = 200,
            g = 16
        }
    },
    alliancePanel2 = T{
        enabled = true,
        font_scale = 1.5,
        gui_scale = 1,
        theme = 'Default',
        themed = true,
        x = 400,
        y = 700,
        hpBarDim = T{
            l = 200,
            g = 16
        }
    },
    playerStats = T{
        enabled = true,
        font_scale = 1.5,
        gui_scale = 1,
        theme = 'Default',
        themed = true,
        x = 600,
        y = 800,
        BarDim = T{
            l = 200,
            g = 16
        }
    },

    font = 'SpicyTaste'

};

glamourUI = T{
    is_open = true,
    settings = settings.load(default_settings),
    debug = '',
    layout = {
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
            y = 0
        },
        MPBarPosition = {
            x = 0,
            y = 0
        },
        TPBarPosition = {
            x = 0,
            y = 0
        },
        padding = 0
    },
    font = nil
}

local font = nil;


settings.register('settings', 'settings_update', function(s)
    if (s ~=nil) then
        glamourUI.settings = s;
    end

    settings.save();
end);

local party = AshitaCore:GetMemoryManager():GetParty();

local chatIsOpen = false;

function render_party_list()
    pokeCache(glamourUI.settings);
    local menu = getMenu();

    if(menu == 'fulllog')then
        chatIsOpen = true;
    elseif(menu == 'logwindo' or menu == nil)then
        chatIsOpen = false;
    end

    if (glamourUI.settings.partylist.enabled and chatIsOpen == false) then

        imgui.SetNextWindowBgAlpha(glamourUI.settings.partylist.bgOpacity);
        imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_FirstUseEver);


        if(glamourUI.settings.partylist.themed == true) then
            local hpbTex = getTex(glamourUI.settings, 'partylist', 'hpBar.png');
            local hpfTex = getTex(glamourUI.settings, 'partylist', 'hpFill.png');
            local mpbTex = getTex(glamourUI.settings, 'partylist', 'mpBar.png');
            local mpfTex = getTex(glamourUI.settings, 'partylist', 'mpFill.png');
            local tpbTex = getTex(glamourUI.settings, 'partylist', 'tpBar.png');
            local tpfTex = getTex(glamourUI.settings, 'partylist', 'tpFill.png');

            if (hpbTex == nil or hpfTex == nil or mpbTex == nil or mpfTex == nil or tpbTex == nil or tpfTex == nil) then
                -- we're missing textures - disable theming for this element and skip the frame
                glamourUI.settings.partylist.themed = false;
                return;
            end


            if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
                local party = AshitaCore:GetMemoryManager():GetParty()
                local partyCount = 0;
                for i = 1,6,1 do
                    if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
                        partyCount = partyCount +1;
                    end
                end

                local player = GetPlayerEntity();
                if(player == nil) then
                    player = 0;
                end
                local pet = GetEntity(player.PetTargetIndex);

                imgui.SetWindowFontScale((glamourUI.settings.partylist.font_scale));
                setHPColor(0);
                renderPlayerThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 0);
                renderPlayerThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 0);
                renderPlayerThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 0);
                renderPlayerThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 0);
                imgui.PopStyleColor();

                if(partyCount >= 2) then
                    if(getZone(1) == getZone(0))then
                        setHPColor(1);
                        renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 1);
                        renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 1);
                        renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 1);
                        renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 1);
                        imgui.PopStyleColor();
                    else
                        renderPartyZone(1);
                    end
                end
                if(partyCount >= 3) then
                    if(getZone(2) == getZone(0))then
                        setHPColor(2);
                        renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 2);
                        renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 2);
                        renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 2);
                        renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 2);
                        imgui.PopStyleColor();
                    else
                        renderPartyZone(2);
                    end
                end
                if(partyCount >= 4) then
                    if(getZone(3) == getZone(0))then
                        setHPColor(3);
                        renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 3);
                        renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 3);
                        renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 3);
                        renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 3);
                        imgui.PopStyleColor();
                    else
                        renderPartyZone(3);
                    end
                end
                if(partyCount >= 5) then
                    if(getZone(4) == getZone(0))then
                        setHPColor(4);
                        renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 4);
                        renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 4);
                        renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 4);
                        renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 4);
                        imgui.PopStyleColor();
                    else
                        renderPartyZone(4);
                    end
                end
                if(partyCount >= 6) then
                    if(getZone(5) == getZone(0))then
                        setHPColor(5);
                        renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 5);
                        renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 5);
                        renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 5);
                        renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, 5);
                        imgui.PopStyleColor();
                    else
                        renderPartyZone(5);
                    end
                end

                if(pet ~= nil) then
                    imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
                    renderPetThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, pet, partyCount);
                    renderPetThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, pet, partyCount);
                    renderPetThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, pet, partyCount);
                    renderPetThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, pet, partyCount);
                    imgui.PopStyleColor();
                end
            end
            imgui.End();
        else
            if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
                local party = AshitaCore:GetMemoryManager():GetParty()
                local partyCount = 0;

                for i = 1,6,1 do
                    if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
                        partyCount = partyCount +1;
                    end
                end

                local player = GetPlayerEntity();
                if(player == nil) then
                    player = 0;
                end
                local pet = GetEntity(player.PetTargetIndex);


                -- PLayer Rendering
                imgui.SetWindowFontScale((glamourUI.settings.partylist.font_scale));
                imgui.Text(tostring(getName(0)));
                imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(0) / 100, { 200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27 * glamourUI.settings.partylist.gui_scale);
                imgui.Text(tostring(getHP(0)));
                imgui.SameLine();
                imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(0) / 100, { 200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(242 * glamourUI.settings.partylist.gui_scale);
                imgui.Text(tostring(getMP(0)));
                imgui.SameLine();
                imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(0) / 1000, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale}, '');
                imgui.PopStyleColor(1);
                if(getTP(0) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(0) -1000) /1000, {200 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(0) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(0) -2000) /1000, {200 * glamourUI.settings.partylist.gui_scale, 4 * glamourUI.settings.partylist.gui_scale}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(457 * glamourUI.settings.partylist.gui_scale);
                imgui.Text(tostring(getTP(0)));

                --Party Member 1 Rendering
                if(partyCount >= 2) then
                    renderParty(1);
                end


                --Party Member 2 Rendering
                if(partyCount >= 3) then
                    renderParty(2);
                end

                --Party Member 3 Rendering
                if(partyCount >= 4) then
                    renderParty(3);
                end

                --Party Member 4 Rendering
                if(partyCount >= 5) then
                    renderParty(4);
                end

                --Party Member 5 Rendering
                if(partyCount >= 6) then
                    renderParty(5);
                end

                --Pet Rendering
                if(pet ~= nil) then
                    imgui.Text('');
                    imgui.Text(tostring(pet.Name));
                    imgui.SetCursorPosX(25);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                    imgui.ProgressBar(pet.HPPercent / 100, { 200, 14 }, '');
                    imgui.SameLine();
                    imgui.PopStyleColor(1);
                    imgui.SetCursorPosX(27);
                    imgui.Text(tostring(pet.HPPercent ) .. '%%');
                    imgui.SameLine();
                    imgui.SetCursorPosX(240);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                    imgui.ProgressBar(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100, { 200, 14}, '');
                    imgui.PopStyleColor(1);
                    imgui.SameLine();
                    imgui.SetCursorPosX(242);
                    imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()) .. '%%');
                    imgui.SameLine();
                    imgui.SetCursorPosX(455);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                    imgui.ProgressBar(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000, {200, 14}, '');
                    imgui.PopStyleColor(1);
                    if(getTP(5) > 1000) then
                        imgui.SameLine();
                        imgui.SetCursorPosX(455);
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                        imgui.ProgressBar((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() -1000) /1000, {200, 10}, '');
                        imgui.PopStyleColor(1);
                    end
                    if(getTP(5) > 2000) then
                        imgui.SameLine();
                        imgui.SetCursorPosX(455);
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                        imgui.ProgressBar((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() -2000) /1000, {200, 4}, '');
                        imgui.PopStyleColor(1);
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(457);
                    imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP()));
                end
            end

            imgui.End();

        end

    end

end

function render_target_bar()
    pokeCache(glamourUI.settings);
    if (glamourUI.settings.targetbar.enabled) then
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
        local targetEntity = GetEntity(target);



        imgui.SetNextWindowBgAlpha(0);
        imgui.SetNextWindowSize({ -1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.targetbar.x, glamourUI.settings.targetbar.y}, ImGuiCond_FirstUseEver);

        if(targetEntity ~= nil) then
            if(imgui.Begin('Target Bar', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground))) then
                imgui.SetWindowFontScale(glamourUI.settings.targetbar.font_scale * glamourUI.settings.targetbar.gui_scale);
                imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                imgui.SetCursorPosY(10 * glamourUI.settings.targetbar.gui_scale);

                if(glamourUI.settings.targetbar.themed == true) then

                    local hpbTex = getTex(glamourUI.settings, 'targetbar', 'hpBar.png');
                    local hpfTex = getTex(glamourUI.settings, 'targetbar', 'hpFill.png');
                    local lockedTex = getTex(glamourUI.settings, 'targetbar', 'LockOn.png');

                    if(hpbTex == nil or hpfTex == nil or lockedTex == nil) then
                        -- missing textures, disable theming for this element and skipt the current frame
                        glamourUI.settings.targetbar.themed = false;
                        imgui.End();
                        return;
                    end

                    imgui.Text(targetEntity.Name);


                    imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.SetWindowFontScale(1 * glamourUI.settings.targetbar.font_scale);
                    imgui.Image(hpbTex, {glamourUI.settings.targetbar.hpBarDim.l * glamourUI.settings.targetbar.gui_scale, glamourUI.settings.targetbar.hpBarDim.g * glamourUI.settings.targetbar.gui_scale});
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Image(hpfTex, {(glamourUI.settings.targetbar.hpBarDim.l*(targetEntity.HPPercent /100) * glamourUI.settings.targetbar.gui_scale),(glamourUI.settings.targetbar.hpBarDim.g * glamourUI.settings.targetbar.gui_scale)});
                    imgui.SameLine();
                    imgui.SetCursorPosX(340 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Text(tostring(targetEntity.HPPercent) .. '%%');
                    if(IsTargetLocked() and glamourUI.settings.targetbar.lockIndicator == true) then
                        imgui.SetCursorPosX(0);
                        imgui.SetCursorPosY(0);
                        imgui.Image(lockedTex, {723 * glamourUI.settings.targetbar.gui_scale, 59 * glamourUI.settings.targetbar.gui_scale});
                    end

                else
                    local lockedTex = getTex(glamourUI.settings, 'targetbar', 'LockOn.png');
                    imgui.Text(targetEntity.Name);
                    if(IsTargetLocked() and glamourUI.settings.targetbar.lockIndicator == true) then
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0 });
                    else
                        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                    end
                    imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.SetWindowFontScale(1 * glamourUI.settings.targetbar.gui_scale);
                    imgui.ProgressBar(targetEntity.HPPercent / 100, {glamourUI.settings.targetbar.hpBarDim.l * glamourUI.settings.targetbar.gui_scale, glamourUI.settings.targetbar.hpBarDim.g * glamourUI.settings.targetbar.gui_scale}, tostring(targetEntity.HPPercent) .. '%');
                    imgui.PopStyleColor(1);

                    if(IsTargetLocked() and glamourUI.settings.targetbar.lockIndicator == true) then
                        imgui.SetCursorPosX(0);
                        imgui.SetCursorPosY(0);
                        imgui.Image(lockedTex, {(63 + glamourUI.settings.targetbar.hpBarDim.l) * glamourUI.settings.targetbar.gui_scale, 59 * glamourUI.settings.targetbar.gui_scale});
                    end

                end
                imgui.End();
            end
        end
    end
end

function render_alliance_panel()
    if(glamourUI.settings.alliancePanel.enabled == true) then
        local a1Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount2();
        local a2Count = AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount3();
        if(a1Count >= 1 or a2Count >=1)then
            imgui.SetNextWindowBgAlpha(.3);
            imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
            imgui.SetNextWindowPos({glamourUI.settings.alliancePanel.x, glamourUI.settings.alliancePanel.y}, ImGuiCond_FirstUseEver);


            local hpbTex1 = getTex(glamourUI.settings, 'alliancePanel', 'hpBar.png');
            local hpfTex1 = getTex(glamourUI.settings, 'alliancePanel', 'hpFill.png');
            local hpbTex2 = getTex(glamourUI.settings, 'alliancePanel2', 'hpBar.png');
            local hpfTex2 = getTex(glamourUI.settings, 'alliancePanel2', 'hpFill.png');

            if(hpbTex1 == nil or hpfTex1 == nil) then
                glamourUI.settings.alliancePanel.themed = false;
            end
            if(hpbTex2 == nil or hpfTex2 == nil) then
                glamourUI.settings.alliancePanel2.themed = false;
            end


            if (imgui.Begin('Alliance List', glamourUI.alliancePanel.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then

                if(a1Count >= 1) then
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 6, 0);
                    else
                        renderAllianceMember(6);

                    end
                end
                if(a1Count >= 2) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 7, 100);
                    else
                        renderAllianceMember(7);

                    end
                end
                if(a1Count >= 3) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 8, 200);
                    else
                        renderAllianceMember(8);

                    end
                end
                if(a1Count >= 4) then
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 9, 0);
                    else
                        renderAllianceMember(9);

                    end
                end
                if(a1Count >= 5) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 10, 0);
                    else
                        renderAllianceMember(10);

                    end
                end
                if(a1Count >= 6) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex1, hpfTex1, 11, 0);
                    else
                        renderAllianceMember(11);

                    end
                end
            end
            imgui.End()


            imgui.SetNextWindowBgAlpha(.3);
            imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
            imgui.SetNextWindowPos({glamourUI.settings.alliancePanel2.x, glamourUI.settings.alliancePanel2.y}, ImGuiCond_FirstUseEver);
            if (imgui.Begin('Alliance List', glamourUI.alliancePanel.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then

                if(a2Count >= 1) then
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 12, 0);
                    else
                        renderAllianceMember(12);

                    end
                end
                if(a2Count >= 2) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 13, 100);
                    else
                        renderAllianceMember(13);

                    end
                end
                if(a2Count >= 3) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 14, 200);
                    else
                        renderAllianceMember(14);

                    end
                end
                if(a2Count >= 4) then
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 15, 0);
                    else
                        renderAllianceMember(15);

                    end
                end
                if(a2Count >= 5) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 16, 0);
                    else
                        renderAllianceMember(16);

                    end
                end
                if(a2Count >= 6) then
                    imgui.SameLine();
                    if(glamourUI.settings.alliancePanel.themed == true)then
                        renderAllianceThemed(hpbTex2, hpfTex2, 17, 0);
                    else
                        renderAllianceMember(17);

                    end
                end
            end
            imgui.End()


        end
    end

end

function render_debug_panel()
    if(dbug == true) then
        local rect = AshitaCore:GetProperties():GetFinalFantasyHwnd();
        imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({12, 12}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('Debug'))then
            --imgui.PushFont(glamourUI.font);
            imgui.Text(tostring(getMenu()));
            --imgui.PopFont();
        end
        imgui.End();
    end
end

function render_player_stats()
    imgui.SetNextWindowBgAlpha(.3);
    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
    imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_FirstUseEver);
    local hp = getHP(0);
    local hpp = getHPP(0);
    local mp = getMP(0);
    local mpp = getMPP(0);
    local tp = getTP(0);

    if(glamourUI.settings.playerStats.enabled == true)then
        if (imgui.Begin('Player Stats', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
            if(glamourUI.settings.playerStats.themed == true) then

                local hpbTex = getTex(glamourUI.settings, 'playerStats', 'hpBar.png');
                local hpfTex = getTex(glamourUI.settings, 'playerStats', 'hpFill.png');
                local mpbTex = getTex(glamourUI.settings, 'playerStats', 'mpBar.png');
                local mpfTex = getTex(glamourUI.settings, 'playerStats', 'mpFill.png');
                local tpbTex = getTex(glamourUI.settings, 'playerStats', 'tpBar.png');
                local tpfTex = getTex(glamourUI.settings, 'playerStats', 'tpFill.png');


                imgui.SetWindowFontScale(glamourUI.settings.playerStats.font_scale);
                renderPlayerStats(hpbTex, hpfTex, hp, hpp, 0);
                imgui.SameLine();
                renderPlayerStats(mpbTex, mpfTex, mp, mpp, 250);
                imgui.SameLine();
                renderPlayerStats(tpbTex, tpfTex, tp, nil, 500);

            else

                imgui.SetWindowFontScale(glamourUI.settings.playerStats.font_scale);
                renderPlayerNoTheme(0, { 1.0, 0.25, 0.25, 1.0 }, hp, hpp);
                imgui.SameLine();
                renderPlayerNoTheme(250, { 0.0, 0.5, 0.0, 1.0 }, mp, mpp);
                imgui.SameLine();
                renderPlayerNoTheme(500, { 0.0, 0.45, 1.0, 1.0}, tp, nil);

            end

        end
        imgui.End();
    end

end

ashita.events.register('command', 'command_cb', function (e)
    --Parse Arguments
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/glam')) then
        return;
    end

    --Block all related commands
    e.blocked = true;

    --Show Help
    if(args[1]:any('/glam') and (#args ==1 or args[2]:any('help'))) then
        print(chat.header('Glamour UI Commands:'));
        print(chat.message('/glam - Show this help text'))
        print(chat.message('/glam config - Opens the Configuration window'));
        print(chat.message('/glam layout - Opens the Layout Editor'));
        print(chat.message('/glam newlayout layoutname - Creates a new layout with name: layoutname'))
        print(chat.message('/glam partylist - Toggle Partylist'));
        print(chat.message('/glam partylist setscale # - Set PartyList Scale'));
        print(chat.message('/glam targetbar - Toggle Target Bar'));
        print(chat.message('/glam targetbar setscale # - Set Target Bar Scale'));
    end
    --Handle Command
    if(#args > 1) then
        if (#args == 2 and args[2] == 'partylist') then
            glamourUI.settings.partylist.enabled = not glamourUI.settings.partylist.enabled;
            settings.save();
        end
        if (#args == 2 and args[2] == 'targetbar') then
            glamourUI.settings.targetbar.enabled = not glamourUI.settings.targetbar.enabled;
            settings.save();
        end
        if (args[2] == 'lockindicator') then
            glamourUI.settings.targetbar.lockIndicator = not glamourUI.settings.targetbar.lockIndicator;
            settings.save();
        end
        if (args[2] == 'debug') then
            dbug = not dbug;
        end
        if (args[3] == 'setscale')then
            setscale(args[2], args[4]);
        end
        if (args[2] == 'config') then
            confGUI.is_open = true;
        end
        if (args[2] == 'layout') then
            layoutGUI.is_open = true;
        end
        if (args[2] == 'newlayout') then
            if(args[3] ~= nil)then
                createLayout(args[3]);
            end
        end
    end
end)

ashita.events.register('d3d_present', 'present_cb', function ()
    local player = GetPlayerEntity();
    if (player ~= nil) then
        render_party_list();
        render_target_bar();
        render_alliance_panel();
        render_player_stats();
        render_config(glamourUI.settings);
        render_layout_editor(glamourUI.layout);
        render_plistBarDim();
        render_tbarDim();
        render_aPanelDim();
        render_pStatsPanelDim();
        render_debug_panel();
    end
end)

ashita.events.register('load', 'load_cb', function()
    if(not ashita.fs.exists(('%s\\config\\addons\\GlamourUI\\Layouts'):fmt(AshitaCore:GetInstallPath())))then
        ashita.fs.create_directory(('%s\\config\\addons\\GlamourUI\\Layouts'):fmt(AshitaCore:GetInstallPath()));
        print(chat.header('Creating Layout Directory'));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\GlamourUI\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath())))then
        ashita.fs.create_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath()));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\GlamourUI\\Layouts\\Default\\layout.lua'):fmt(AshitaCore:GetInstallPath()))) then
        createLayout('Default');
        print(chat.header('Creating Default Layout'));
    end
    require('conf')
    loadLayout(glamourUI.settings.partylist.layout);
    loadFont(glamourUI.settings.font);
end)

ashita.events.register('unload', 'unload_cb', function()
    settings.save();
end)
