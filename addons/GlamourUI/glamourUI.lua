--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--


addon.name = 'GlamourUI';
addon.author = 'Banggugyangu';
addon.desc = "A modular and customizable interface for FFXI";
addon.version = '0.7.2';

local imgui = require('imgui')


local settings = require('settings')
require('common')
local chat = require('chat')
require('helperfunctions')
local ffi = require('ffi')
local d3d8 = require('d3d8')
local primlib = require('primitives')
local env = require('scaling')
local dbug = false;

local default_settings = T{

    partylist = T{
        enabled = true,
        bgOpacity = 1,
        font_size = 16,
        font = 'SpicyTaste',
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
         font_size = 16,
         font = 'SpicyTaste',
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
        font_size = 16,
        font = 'SpicyTaste',
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
        font_size = 16,
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
        font_size = 16,
        font = 'SpicyTaste',
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
    invPanel  = T{
        theme = 'Default',
        font = 'SpicyTaste',
        font_size = 20,
        enabled = true
    }


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
    pListFont = nil,
    tBarFont = nil,
    aPanelFont = nil,
    pStatsFont = nil,
    iPanelFont = nil,
    bgSize = T{
        x = 0,
        y = 0
    },
    bgPos = T{
        x = 0,
        y = 0
    }
}

partylistW = 0;

local font = nil;
local firstLoad = true;


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


        local bgTex = getTex(glamourUI.settings, 'partylist', 'background.png');

        imgui.SetNextWindowSize({glamourUI.bgSize.x + 15, glamourUI.bgSize.y + 15}, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.bgPos.x, glamourUI.bgPos.y}, ImGuiCond_Always);

        if(imgui.Begin('pListBG', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground)))then
            imgui.Image(bgTex, {glamourUI.bgSize.x, glamourUI.bgSize.y});
            imgui.End();
        end

            imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
            imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_FirstUseEver);



            if(glamourUI.settings.partylist.themed == true) then
                local hpbTex = getTex(glamourUI.settings, 'partylist', 'hpBar.png');
                local hpfTex = getTex(glamourUI.settings, 'partylist', 'hpFill.png');
                local mpbTex = getTex(glamourUI.settings, 'partylist', 'mpBar.png');
                local mpfTex = getTex(glamourUI.settings, 'partylist', 'mpFill.png');
                local tpbTex = getTex(glamourUI.settings, 'partylist', 'tpBar.png');
                local tpfTex = getTex(glamourUI.settings, 'partylist', 'tpFill.png');
                local targTex = getTex(glamourUI.settings, 'partylist', 'partyTarget.png');
                local pleadTex = getTex(glamourUI.settings, 'partylist', 'partyLead.png');
                local lsyncTex = getTex(glamourUI.settings, 'partylist', 'levelSync.png');

                if (hpbTex == nil or hpfTex == nil or mpbTex == nil or mpfTex == nil or tpbTex == nil or tpfTex == nil) then
                    -- we're missing textures - disable theming for this element and skip the frame
                    glamourUI.settings.partylist.themed = false;
                    return;
                end


                if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
                    local pos = {imgui.GetCursorScreenPos()};
                    local party = AshitaCore:GetMemoryManager():GetParty()
                    local partyCount = 0;
                    for i = 1,6,1 do
                        if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
                            partyCount = partyCount +1;
                        end
                    end

                    imgui.PushFont(glamourUI.pListFont);
                    local player = GetPlayerEntity();
                    if(player == nil) then
                        player = 0;
                    end
                    local pet = GetEntity(player.PetTargetIndex);

                    setHPColor(0);
                    renderPlayerThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 0);
                    renderPlayerThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 0);
                    renderPlayerThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 0);
                    renderPlayerThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 0);
                    imgui.PopStyleColor();

                    if(partyCount >= 2) then
                        if(getZone(1) == getZone(0))then
                            setHPColor(1);
                            renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 1);
                            renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 1);
                            renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 1);
                            renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 1);
                            imgui.PopStyleColor();
                        else
                            renderPartyZone(1);
                        end
                    end
                    if(partyCount >= 3) then
                        if(getZone(2) == getZone(0))then
                            setHPColor(2);
                            renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 2);
                            renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 2);
                            renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 2);
                            renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 2);
                            imgui.PopStyleColor();
                        else
                            renderPartyZone(2);
                        end
                    end
                    if(partyCount >= 4) then
                        if(getZone(3) == getZone(0))then
                            setHPColor(3);
                            renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 3);
                            renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 3);
                            renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 3);
                            renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 3);
                            imgui.PopStyleColor();
                        else
                            renderPartyZone(3);
                        end
                    end
                    if(partyCount >= 5) then
                        if(getZone(4) == getZone(0))then
                            setHPColor(4);
                            renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 4);
                            renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 4);
                            renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 4);
                            renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 4);
                            imgui.PopStyleColor();
                        else
                            renderPartyZone(4);
                        end
                    end
                    if(partyCount >= 6) then
                        if(getZone(5) == getZone(0))then
                            setHPColor(5);
                            renderPartyThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 5);
                            renderPartyThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 5);
                            renderPartyThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 5);
                            renderPartyThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pleadTex, lsyncTex, 5);
                            imgui.PopStyleColor();
                        else
                            renderPartyZone(5);
                        end
                    end

                    if(pet ~= nil) then
                        imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
                        renderPetThemed(4, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pet, partyCount);
                        renderPetThemed(3, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pet, partyCount);
                        renderPetThemed(2, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pet, partyCount);
                        renderPetThemed(1, hpbTex, hpfTex, mpbTex, mpfTex, tpbTex, tpfTex, targTex, pet, partyCount);
                        imgui.PopStyleColor();
                    end
                end
                glamourUI.bgSize.x = imgui.GetWindowWidth() + 50;
                glamourUI.bgSize.y = imgui.GetWindowHeight() + 50;
                local pos = {imgui.GetWindowPos()};
                glamourUI.bgPos.x = pos[1] - 25;
                glamourUI.bgPos.y = pos[2] - 25;
                imgui.PopFont();
                imgui.End();
                --renderPlayerBuffs();
            else
                if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
                    local party = AshitaCore:GetMemoryManager():GetParty()
                    local partyCount = 0;

                    imgui.PushFont(glamourUI.pListFont);

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
                    imgui.PopStyleVar();
                end
                imgui.PopFont();
                partylistW = imgui.GetWindowWidth();
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
        local subtarg = getSubTargetEntity();


        imgui.SetNextWindowBgAlpha(0);
        imgui.SetNextWindowSize({ -1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.targetbar.x, glamourUI.settings.targetbar.y}, ImGuiCond_FirstUseEver);

        if(targetEntity ~= nil) then
            if(imgui.Begin('Target Bar', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground))) then
                local hpbTex = getTex(glamourUI.settings, 'targetbar', 'hpBar.png');
                local hpfTex = getTex(glamourUI.settings, 'targetbar', 'hpFill.png');

                imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                imgui.SetCursorPosY(10 * glamourUI.settings.targetbar.gui_scale);
                imgui.PushFont(glamourUI.tBarFont);

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
                    imgui.Image(hpbTex, {glamourUI.settings.targetbar.hpBarDim.l * glamourUI.settings.targetbar.gui_scale, glamourUI.settings.targetbar.hpBarDim.g * glamourUI.settings.targetbar.gui_scale});
                    imgui.SameLine();
                    imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Image(hpfTex, {(glamourUI.settings.targetbar.hpBarDim.l*(targetEntity.HPPercent /100) * glamourUI.settings.targetbar.gui_scale),(glamourUI.settings.targetbar.hpBarDim.g * glamourUI.settings.targetbar.gui_scale)});
                    imgui.SetCursorPosY(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.SetCursorPosY(30 * glamourUI.settings.targetbar.gui_scale);
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
                if(subtarg ~= nil)then
                    imgui.SetWindowFontScale(glamourUI.settings.targetbar.gui_scale + 0.5);
                    imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Text('Sub Target:   ');
                    imgui.SameLine();
                    imgui.Text(subtarg.Name);
                    imgui.SetCursorPosY(77);
                    imgui.SetCursorPosX(350 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Image(hpbTex, {(glamourUI.settings.targetbar.hpBarDim.l * 0.5),(glamourUI.settings.targetbar.hpBarDim.g * 0.5)});
                    imgui.SameLine();
                    imgui.SetCursorPosX(350 * glamourUI.settings.targetbar.gui_scale);
                    imgui.Image(hpfTex, {(glamourUI.settings.targetbar.hpBarDim.l * 0.5 * (subtarg.HPPercent / 100)), (glamourUI.settings.targetbar.hpBarDim.g * 0.5)});
                end
                imgui.PopFont();
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
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local pEntity = AshitaCore:GetMemoryManager():GetEntity(player);
        local party = AshitaCore:GetMemoryManager():GetParty();

        imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({12, 12}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('Debug'))then

            imgui.Text('Font');

            imgui.Text(tostring(party:GetStatusIcons(0)));
            imgui.PushFont(glamourUI.pListFont);
            imgui.PopFont();
        end
        imgui.End();
    end
end

function render_player_stats()
    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
    imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_FirstUseEver);
    local hp = getHP(0);
    local hpp = getHPP(0);
    local mp = getMP(0);
    local mpp = getMPP(0);
    local tp = getTP(0);

    if(glamourUI.settings.playerStats.enabled == true)then
        if (imgui.Begin('Player Stats', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground))) then
            imgui.PushFont(glamourUI.pStatsFont);
            if(glamourUI.settings.playerStats.themed == true) then

                local hpbTex = getTex(glamourUI.settings, 'playerStats', 'hpBar.png');
                local hpfTex = getTex(glamourUI.settings, 'playerStats', 'hpFill.png');
                local mpbTex = getTex(glamourUI.settings, 'playerStats', 'mpBar.png');
                local mpfTex = getTex(glamourUI.settings, 'playerStats', 'mpFill.png');
                local tpbTex = getTex(glamourUI.settings, 'playerStats', 'tpBar.png');
                local tpfTex = getTex(glamourUI.settings, 'playerStats', 'tpFill.png');


                renderPlayerStats(hpbTex, hpfTex, hp, hpp, 0);
                imgui.SameLine();
                renderPlayerStats(mpbTex, mpfTex, mp, mpp, 250);
                imgui.SameLine();
                renderPlayerStats(tpbTex, tpfTex, tp, nil, 500);

            else

                renderPlayerNoTheme(0, { 1.0, 0.25, 0.25, 1.0 }, hp, hpp);
                imgui.SameLine();
                renderPlayerNoTheme(250, { 0.0, 0.5, 0.0, 1.0 }, mp, mpp);
                imgui.SameLine();
                renderPlayerNoTheme(500, { 0.0, 0.45, 1.0, 1.0}, tp, nil);

            end
            imgui.PopFont();
        end
        imgui.End();
    end

end

function render_inventory_panel()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local zoning = player:GetIsZoning();

    if (zoning == 0) then
        if(glamourUI.settings.invPanel.enabled == true)then
            local invTex = getTex(glamourUI.settings, 'invPanel', 'lootbag.png');
            local wardTex = getTex(glamourUI.settings, 'invPanel', 'wardrobe.png');
            local safeTex = getTex(glamourUI.settings, 'invPanel', 'safe.png');
            local tPoolTex = getTex(glamourUI.settings, 'invPanel', 'treasure.png');
            local gilTex = getTex(glamourUI.settings, 'invPanel', 'gil.png');
            local mX = env.menu.w;
            local mY = env.menu.h;
            local wX = env.window.w;
            local wY = env.window.h;
            local scaleX = wX / mX;
            local scaleY = wY / mY;
            local size = {(115 * scaleX), (185 * scaleY)};
            local menu = {wX - (128 * scaleX), wY - (200 * scaleY)};
            local gil = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0);
            local wardCount = getInventory(8) + getInventory(10) + getInventory(11) + getInventory(12) + getInventory(13) + getInventory(14) + getInventory(15) + getInventory(16);
            local wardMax = getInventoryMax(8) + getInventoryMax(10) + getInventoryMax(11) + getInventoryMax(12) + getInventoryMax(13)+ getInventoryMax(14) + getInventoryMax(15) + getInventoryMax(16);
            local tPoolCount = AshitaCore:GetMemoryManager():GetInventory():GetTreasurePoolItemCount();

            imgui.SetNextWindowBgAlpha(1);
            imgui.SetNextWindowSize(size, ImGuiCond_Always);
            imgui.SetNextWindowPos(menu);
            if(imgui.Begin("InventoryPanel", glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration)))then
                imgui.PushFont(glamourUI.iPanelFont);

                --Inventory Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(20 * scaleY);
                imgui.Text(tostring(getInventory(0)) .. '/' .. tostring(getInventoryMax(0)));
                imgui.SameLine();
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(16 * scaleY);
                imgui.Image(invTex, {15 * scaleX, 20 * scaleY})

                --Wardrobe Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(50 * scaleY);
                imgui.Text(tostring(wardCount).. '/' .. tostring(wardMax));
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(51 * scaleY);
                imgui.Image(wardTex, {15 * scaleX, 20 * scaleY});

                --MogSafe Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(80 * scaleY);
                imgui.Text(tostring(getInventory(1) .. '/' .. tostring(getInventoryMax(1))));
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(81 * scaleY);
                imgui.Image(safeTex, {15 * scaleX, 20 * scaleY});

                --Treasure Pool
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(110 * scaleY);
                imgui.Text(tostring(tPoolCount));
                imgui.SetCursorPosX(80 * scaleX);
                imgui.SetCursorPosY(114 * scaleY);
                imgui.Image(tPoolTex, {25 * scaleX, 20 * scaleY});

                --Gil Count
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(145 * scaleY);
                if gil ~= nil then
                    imgui.Text(tostring(gil.Count));
                end
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(147 * scaleY);
                imgui.Image(gilTex, {15 * scaleX, 15 * scaleY});
                imgui.PopFont();
                imgui.End();
            end
        end

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
    local playerSID = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    if (player ~= nil and playerSID ~= 0) then
        if(firstLoad == true)then
            loadLayout(glamourUI.settings.partylist.layout);
            firstLoad = false;
        end
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
        render_inventory_panel();
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

    local scaleY = env.window.h / env.menu.h;
    loadFont(glamourUI.settings.partylist.font, glamourUI.settings.partylist.font_size, 'partylist');
    loadFont(glamourUI.settings.targetbar.font, glamourUI.settings.targetbar.font_size, 'targetbar');
    loadFont(glamourUI.settings.alliancePanel.font, glamourUI.settings.alliancePanel.font_size, 'alliancePanel');
    loadFont(glamourUI.settings.playerStats.font, glamourUI.settings.playerStats.font_size, 'playerStats');
    loadFont(glamourUI.settings.invPanel.font, glamourUI.settings.invPanel.font_size * scaleY, 'invPanel')
end)

ashita.events.register('unload', 'unload_cb', function()
    settings.save();
end)

