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
addon.version = '0.0.1';

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
local p1 = T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}
local p2 = T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}
local p3 =T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}
local p4 = T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}
local p5 = T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}
local p6 = T{
    Name = '',
    HP = 0,
    HPP = 0,
    MP = 0,
    MPP = 0,
    TP = 0
}



function render_test_panel()
    if (glamourUI.settings.partylist.enabled) then
        imgui.SetNextWindowBgAlpha(.3);
        imgui.SetNextWindowSize({ 750, -1, }, ImGuiCond_Always);
        imgui.SetNextWindowPos({glamourUI.settings.partylist.x, glamourUI.settings.partylist.y}, ImGuiCond_Always);


        if (imgui.Begin('PartyList', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav))) then
            local party = AshitaCore:GetMemoryManager():GetParty()
            local partyCount = 0;
            for i = 1,6,1 do
                if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
                    partyCount = partyCount +1;
                end
            end

            p1.Name = party:GetMemberName(0);
            p1.HP = party:GetMemberHP(0);
            p1.HPP = party:GetMemberHPPercent(0);
            p1.MP = party:GetMemberMP(0);
            p1.MPP = party:GetMemberMPPercent(0);
            p1.TP = party:GetMemberTP(0);
            
            
            p2.Name = party:GetMemberName(1);
            p2.HP = party:GetMemberHP(1);
            p2.HPP = party:GetMemberHPPercent(1);
            p2.MP = party:GetMemberMP(1);
            p2.MPP = party:GetMemberMPPercent(1);
            p2.TP = party:GetMemberTP(1);


            p3.Name = party:GetMemberName(2);
            p3.HP = party:GetMemberHP(2);
            p3.HPP = party:GetMemberHPPercent(2);
            p3.MP = party:GetMemberMP(2);
            p3.MPP = party:GetMemberMPPercent(2);
            p3.TP = party:GetMemberTP(2);


            p4.Name = party:GetMemberName(3);
            p4.HP = party:GetMemberHP(3);
            p4.HPP = party:GetMemberHPPercent(3);
            p4.MP = party:GetMemberMP(3);
            p4.MPP = party:GetMemberMPPercent(3);
            p4.TP = party:GetMemberTP(3);

            
            p5.Name = party:GetMemberName(4);
            p5.HP = party:GetMemberHP(4);
            p5.HPP = party:GetMemberHPPercent(4);
            p5.MP = party:GetMemberMP(4);
            p5.MPP = party:GetMemberMPPercent(4);
            p5.TP = party:GetMemberTP(4);


            p6.Name = party:GetMemberName(5);
            p6.HP = party:GetMemberHP(5);
            p6.HPP = party:GetMemberHPPercent(5);
            p6.MP = party:GetMemberMP(5);
            p6.MPP = party:GetMemberMPPercent(5);
            p6.TP = party:GetMemberTP(5);
            
            
            -- PLayer Rendering
            imgui.Text(tostring(p1.Name));
            imgui.SetCursorPosX(25);
            imgui.ProgressBar(p1.HPP / 100, { 200, 16 });
            imgui.SameLine();
            imgui.SetCursorPosX(27);
            imgui.Text(tostring(p1.HP));
            imgui.SameLine();
            imgui.SetCursorPosX(275);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
            imgui.ProgressBar(p1.MPP / 100, { 200, 16});
            imgui.SameLine();
            imgui.SetCursorPosX(277);
            imgui.Text(tostring(p1.MP));
            imgui.SameLine();
            imgui.SetCursorPosX(525);
            imgui.ProgressBar(p1.TP / 1000, {200, 16});
            imgui.SameLine();
            imgui.SetCursorPosX(527);
            imgui.Text(tostring(p1.TP));
            
            --Party Member 1 Rendering
            if(partyCount >= 2) then
                imgui.Text('');
                imgui.Text(tostring(p2.Name));
                imgui.SetCursorPosX(25);
                imgui.ProgressBar(p2.HPP / 100, { 200, 16 });
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(p2.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(275);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
                imgui.ProgressBar(p2.MPP / 100, { 200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(277);
                imgui.Text(tostring(p2.MP));
                imgui.SameLine();
                imgui.SetCursorPosX(525);
                imgui.ProgressBar(p2.TP / 1000, {200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(527);
                imgui.Text(tostring(p2.TP));
            end
            
            --Party Member 2 Rendering
            if(partyCount >= 3) then
                imgui.Text('');
                imgui.Text(tostring(p3.Name));
                imgui.SetCursorPosX(25);
                imgui.ProgressBar(p3.HPP / 100, { 200, 16 });
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(p3.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(275);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
                imgui.ProgressBar(p3.MPP / 100, { 200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(277);
                imgui.Text(tostring(p3.MP));
                imgui.SameLine();
                imgui.SetCursorPosX(525);
                imgui.ProgressBar(p3.TP / 1000, {200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(527);
                imgui.Text(tostring(p3.TP));
            end
            
            --Party Member 3 Rendering
            if(partyCount >= 4) then
                imgui.Text('');
                imgui.Text(tostring(p4.Name));
                imgui.SetCursorPosX(25);
                imgui.ProgressBar(p4.HPP / 100, { 200, 16 });
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(p4.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(275);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
                imgui.ProgressBar(p4.MPP / 100, { 200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(277);
                imgui.Text(tostring(p4.MP));
                imgui.SameLine();
                imgui.SetCursorPosX(525);
                imgui.ProgressBar(p4.TP / 1000, {200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(527);
                imgui.Text(tostring(p4.TP));
            end
            
            --Party Member 4 Rendering
            if(partyCount >= 5) then
                imgui.Text('');
                imgui.Text(tostring(p5.Name));
                imgui.SetCursorPosX(25);
                imgui.ProgressBar(p5.HPP / 100, { 200, 16 });
                imgui.SameLine();
                imgui.SetCursorPosX(27);
                imgui.Text(tostring(p5.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(275);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
                imgui.ProgressBar(p5.MPP / 100, { 200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(277);
                imgui.Text(tostring(p5.MP));
                imgui.SameLine();
                imgui.SetCursorPosX(525);
                imgui.ProgressBar(p5.TP / 1000, {200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(527);
                imgui.Text(tostring(p5.TP));
            end
            
            --Party Member 5 Rendering
            if(partyCount >= 6) then
                imgui.Text('');
                imgui.Text(tostring(p6.Name));
                imgui.SetCursorPosX(25);
                imgui.ProgressBar(p6.HPP / 100, { 200, 16 });
                imgui.SameLine();
                imgui.SetCursorPosX(30);
                imgui.Text(tostring(p6.HP));
                imgui.SameLine();
                imgui.SetCursorPosX(275);
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.49, 1.0, 1.0 });
                imgui.ProgressBar(p6.MPP / 100, { 200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(280);
                imgui.Text(tostring(p6.MP));
                imgui.SameLine();
                imgui.SetCursorPosX(525);
                imgui.ProgressBar(p6.TP / 1000, {200, 16});
                imgui.SameLine();
                imgui.SetCursorPosX(530);
                imgui.Text(tostring(p6.TP));
            end

        end

    end
    imgui.End();
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
    render_test_panel();
end)

