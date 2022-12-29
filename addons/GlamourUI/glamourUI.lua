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
addon.version = '0.0.3';

local imgui = require('imgui')


local settings = require('settings')
require('common')
local chat = require('chat')



local default_settings = T{

    partylist = T{
        x = 12,
        y = 150,
        enabled = true,
        theme = 'Default'
    },

    targetbar = T{
         x = 1000,
         y = 150,
         enabled = true
    }
};

local glamourUI = T{
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

local getName = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberName(index);
end

local getHP = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberHP(index);
end

local getHPP = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(index);
end

local getMP = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberMP(index);
end

local getMPP = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberMPPercent(index);
end

local getTP = function(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberTP(index);
end

function render_party_list()
    if (glamourUI.settings.partylist.enabled) then
        imgui.SetNextWindowBgAlpha(.3);
        imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_Always);


        if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav))) then
            local party = AshitaCore:GetMemoryManager():GetParty()
            local partyCount = 0;
            for i = 1,6,1 do
                if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
                    partyCount = partyCount +1;
                end
            end

            -- PLayer Rendering
            imgui.Text(tostring(getName(0)));
            imgui.SetCursorPosX(25);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
            imgui.ProgressBar(getHPP(0) / 100, { 200, 16 }, '');
            imgui.PopStyleColor(1);
            imgui.SameLine();
            imgui.SetCursorPosX(27);
            imgui.Text(tostring(getHP(0)));
            imgui.SameLine();
            imgui.SetCursorPosX(255);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
            imgui.ProgressBar(getMPP(0) / 100, { 200, 16}, '');
            imgui.PopStyleColor(1);
            imgui.SameLine();
            imgui.SetCursorPosX(257);
            imgui.Text(tostring(getMP(0)));
            imgui.SameLine();
            imgui.SetCursorPosX(490);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
            imgui.ProgressBar(getTP(0) / 1000, {200, 16}, '');
            imgui.PopStyleColor(1);
            if(getTP(0) > 1000) then
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                imgui.ProgressBar((getTP(0) -1000) /1000, {200, 10}, '');
                imgui.PopStyleColor(1);
            end
            if(getTP(0) > 2000) then
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                imgui.ProgressBar((getTP(0) -2000) /1000, {200, 4}, '');
                imgui.PopStyleColor(1);
            end
            imgui.SameLine();
            imgui.SetCursorPosX(492);
            imgui.Text(tostring(getTP(0)));

            --Party Member 1 Rendering
            if(partyCount >= 2) then
                imgui.Text('');
                imgui.Text(tostring(getName(1)));
                imgui.SetCursorPosX(25);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(1) / 100, { 200, 16 }, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(getHP(1)));
                imgui.SameLine();
                imgui.SetCursorPosX(255);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(1) / 100, { 200, 16}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(257);
                imgui.Text(tostring(getMP(1)));
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(1) / 1000, {200, 16}, '');
                imgui.PopStyleColor(1);
                if(getTP(1) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(1) -1000) /1000, {200, 10}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(1) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(1) -2000) /1000, {200, 4}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(492);
                imgui.Text(tostring(getTP(1)));
            end

            --Party Member 2 Rendering
            if(partyCount >= 3) then
                imgui.Text('');
                imgui.Text(tostring(getName(2)));
                imgui.SetCursorPosX(25);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(2) / 100, { 200, 16 }, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(getHP(2)));
                imgui.SameLine();
                imgui.SetCursorPosX(255);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(2) / 100, { 200, 16}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(257);
                imgui.Text(tostring(getMP(2)));
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(2) / 1000, {200, 16}, '');
                imgui.PopStyleColor(1);
                if(getTP(2) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(2) -1000) /1000, {200, 10}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(2) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(2) -2000) /1000, {200, 4}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(492);
                imgui.Text(tostring(getTP(2)));
            end

            --Party Member 3 Rendering
            if(partyCount >= 4) then
                imgui.Text('');
                imgui.Text(tostring(getName(3)));
                imgui.SetCursorPosX(25);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(3) / 100, { 200, 16 }, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(getHP(3)));
                imgui.SameLine();
                imgui.SetCursorPosX(255);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(3) / 100, { 200, 16}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(257);
                imgui.Text(tostring(getMP(3)));
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(3) / 1000, {200, 16}, '');
                imgui.PopStyleColor(1);
                if(getTP(3) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(3) -1000) /1000, {200, 10}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(3) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(3) -2000) /1000, {200, 4}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(492);
                imgui.Text(tostring(getTP(3)));
            end

            --Party Member 4 Rendering
            if(partyCount >= 5) then
                imgui.Text('');
                imgui.Text(tostring(getName(4)));
                imgui.SetCursorPosX(25);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(4) / 100, { 200, 16 }, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(getHP(4)));
                imgui.SameLine();
                imgui.SetCursorPosX(255);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(4) / 100, { 200, 16}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(257);
                imgui.Text(tostring(getMP(4)));
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(4) / 1000, {200, 16}, '');
                imgui.PopStyleColor(1);
                if(getTP(4) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(4) -1000) /1000, {200, 10}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(4) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(4) -2000) /1000, {200, 4}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(492);
                imgui.Text(tostring(getTP(4)));
            end

            --Party Member 5 Rendering
            if(partyCount >= 6) then
                imgui.Text('');
                imgui.Text(tostring(getName(5)));
                imgui.SetCursorPosX(25);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(getHPP(5) / 100, { 200, 16 }, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(getHP(5)));
                imgui.SameLine();
                imgui.SetCursorPosX(255);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
                imgui.ProgressBar(getMPP(5) / 100, { 200, 16}, '');
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.SetCursorPosX(257);
                imgui.Text(tostring(getMP(5)));
                imgui.SameLine();
                imgui.SetCursorPosX(490);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
                imgui.ProgressBar(getTP(5) / 1000, {200, 16}, '');
                imgui.PopStyleColor(1);
                if(getTP(5) > 1000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
                    imgui.ProgressBar((getTP(5) -1000) /1000, {200, 10}, '');
                    imgui.PopStyleColor(1);
                end
                if(getTP(5) > 2000) then
                    imgui.SameLine();
                    imgui.SetCursorPosX(490);
                    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
                    imgui.ProgressBar((getTP(5) -2000) /1000, {200, 4}, '');
                    imgui.PopStyleColor(1);
                end
                imgui.SameLine();
                imgui.SetCursorPosX(492);
                imgui.Text(tostring(getTP(5)));
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

        imgui.SetNextWindowBgAlpha(.3);
        imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.targetbar.x, glamourUI.settings.targetbar.y}, ImGuiCond_Always);

        if(targetEntity ~= nil) then
            if(imgui.Begin('Target Bar', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav))) then

                imgui.Text(targetEntity.Name);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
                imgui.ProgressBar(targetEntity.HPPercent / 100, {700, 16}, tostring(targetEntity.HPPercent) .. '%');
                imgui.PopStyleColor(1);
            end
            imgui.End();

        end
    end
end


ashita.events.register('command', 'command_cb', function (e)
    --Parse Arguments
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/gui')) then
        return;
    end

    --Block all related commands
    e.blocked = true;

    --Handle Command
    if(#args == 1) then
        glamourUI.settings.partylist.enabled = not glamourUI.settings.partylist.enabled;
    end

end)

ashita.events.register('d3d_present', 'present_cb', function ()
    render_party_list();
    render_target_bar();
end)

