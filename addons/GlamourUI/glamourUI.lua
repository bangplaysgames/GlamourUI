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
addon.version = '0.0.4';

local imgui = require('imgui')


local settings = require('settings')
require('common')
local chat = require('chat')
require('helperfunctions')
local ffi = require('ffi')
local d3d8 = require('d3d8')

local dbug = false;

local d3d8_device = d3d8.get_device();

local default_settings = T{

    partylist = T{
        x = 12,
        y = 150,
        enabled = true,
        theme = 'Default',
        font_scale = 1.5,
        gui_scale = 1
    },

    targetbar = T{
         x = 1000,
         y = 150,
         enabled = true,
         font_scale = 1.5,
         gui_scale = 1,
         lockIndicator = true
    }
};

glamourUI = T{
    is_open = true,
    settings = settings.load(default_settings)
}

settings.register('settings', 'settings_update', function(s)
    if (s ~=nil) then
        glamourUI.settings = s;
    end

    settings.save();
end);

local party = AshitaCore:GetMemoryManager():GetParty();

function render_party_list()
    if (glamourUI.settings.partylist.enabled) then
        imgui.SetNextWindowBgAlpha(.3);
        imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_FirstUseEver);


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

            -- PLayer Rendering
            imgui.SetWindowFontScale((glamourUI.settings.partylist.font_scale * glamourUI.settings.partylist.gui_scale));
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
                imgui.Text(tostring(pet.HPPercent));
                imgui.SameLine();
                imgui.SetCursorPosX(240);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100, { 200, 14}, '');
                imgui.PopStyleColor(1);
                imgui.SetCursorPosX(242);
                imgui.Text(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent());
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
    end
    imgui.End();
end

function render_target_bar()
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
                imgui.Text(targetEntity.Name);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.SetCursorPosX(30 * glamourUI.settings.targetbar.gui_scale);
                imgui.ProgressBar(targetEntity.HPPercent / 100, {660 * glamourUI.settings.targetbar.gui_scale, 16 * glamourUI.settings.targetbar.gui_scale}, tostring(targetEntity.HPPercent) .. '%');
                imgui.PopStyleColor(1);
                if(IsTargetLocked() and glamourUI.settings.targetbar.lockIndicator == true) then
                    local lockTexPath = ('%s\\addons\\GlamourUI\\resources\\LockOn.png'):fmt(AshitaCore:GetInstallPath());
                    local lockTexPtr = ffi.new('IDirect3DTexture8*[1]');
                    local lockedTex = getTex(d3d8_device, lockTexPath, lockTexPtr);

                    imgui.SetCursorPosX(0);
                    imgui.SetCursorPosY(0);
                    imgui.Image(lockedTex, {723 * glamourUI.settings.targetbar.gui_scale, 59 * glamourUI.settings.targetbar.gui_scale});
                end
            end
            imgui.End();



        end
    end
end

function render_debug_panel()
    if(dbug == true) then
        imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Always);
        imgui.SetNextWindowPos({12, 12}, ImGuiCond_Always);
        if(imgui.Begin('Debug'))then
            imgui.Text(tostring(IsTargetLocked()));
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
    end
end)

ashita.events.register('d3d_present', 'present_cb', function ()
    local player = GetPlayerEntity();
    if (player ~= nil) then
        render_party_list();
        render_target_bar();
        render_debug_panel();
    end
end)

ashita.events.register('unload', 'unload_cb', function()
    settings.save();
end)
