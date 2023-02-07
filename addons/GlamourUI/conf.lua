--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--
require('common')
local imgui = require('imgui')


confGUI = T{
    is_open = false,
    themeID = T{ getThemeID('Default')},
    layoutID = T{ getLayoutID('Default')},
    fontID = T{ getFontID('Default')}
};

layoutGUI = T{
    is_open = false
};

plistBarDim = T{
    is_open = false
};

tBarDim = T{
    is_open = false
};

aPanelBarDim = T{
    is_open = false
};

pStatsBarDim = T{
    is_open = false
};

local confFont = loadFont('MysticGate', 16, 'partylist');

function render_config()
    local party_gui_scale = {glamourUI.settings.partylist.gui_scale};
    local target_gui_scale = {glamourUI.settings.targetbar.gui_scale};
    local alliance_gui_scale = {glamourUI.settings.alliancePanel.gui_scale};
    local alliance2_gui_scale = {glamourUI.settings.alliancePanel2.gui_scale};
    local player_gui_scale = {glamourUI.settings.playerStats.gui_scale};
    local cbar_gui_scale = {glamourUI.settings.cBar.gui_scale};
    local party_font_scale = {glamourUI.settings.partylist.font_size};
    local target_font_scale = {glamourUI.settings.targetbar.font_size};
    local alliance_font_scale = {glamourUI.settings.alliancePanel.font_size};
    local alliance2_font_scale = {glamourUI.settings.alliancePanel2.font_size};
    local player_font_scale = {glamourUI.settings.playerStats.font_size};
    local inv_font_scale = {glamourUI.settings.invPanel.font_size};
    local themedir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    local layoutdir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\'):fmt(AshitaCore:GetInstallPath()));
    local fontdir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Fonts\\'):fmt(AshitaCore:GetInstallPath()));

    if(confGUI.is_open == true)then
        imgui.SetNextWindowSize({-1,-1}, ImGuiCond_Always);
        if(imgui.Begin('GlamourUI Configuration', confGUI.is_open, ImGuiWindowFlags_NoDecoration,ImGuiWindowFlags_AlwaysAutoResize)) then
            imgui.PushFont(confFont);
            imgui.Text('GlamourUI Configuration');
            imgui.BeginChild('conf_partylist', {500,180}, true);
            imgui.Text('PartyList');
            imgui.SameLine();
            imgui.SetCursorPosX(200);
            if(imgui.Checkbox('Enabled', {glamourUI.settings.partylist.enabled}))then
                glamourUI.settings.partylist.enabled = not glamourUI.settings.partylist.enabled;
            end
            imgui.SameLine();
            imgui.SetCursorPosX(400);
            if(imgui.Checkbox('Themed', {glamourUI.settings.partylist.themed}))then
                glamourUI.settings.partylist.themed = not glamourUI.settings.partylist.themed;
            end
            imgui.SliderFloat('Party List Scale  ', party_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.partylist.gui_scale ~= party_gui_scale[1]) then
                glamourUI.settings.partylist.gui_scale = party_gui_scale[1];
            end
            imgui.SliderInt('Font Size', party_font_scale, 1, 50);
            if(glamourUI.settings.partylist.font_size ~= party_font_scale[1])then
                glamourUI.settings.partylist.font_size = party_font_scale[1];
                loadFont(glamourUI.settings.partylist.font, glamourUI.settings.partylist.font_size, 'partylist');
            end
            if(imgui.BeginCombo('Theme  ', glamourUI.settings.partylist.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.partylist.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.partylist.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Layout  ', glamourUI.settings.partylist.layout, combo_flags))then
                for i = 1,#layoutdir,1 do
                    local is_selected = i == confGUI.layoutID;

                    if (glamourUI.settings.partylist.layout ~= layoutdir[i] and imgui.Selectable(layoutdir[i], is_selected))then
                        confGUI.layoutID = i;
                        glamourUI.settings.partylist.layout = layoutdir[i];
                        loadLayout(layoutdir[i]);
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Font  ', glamourUI.settings.partylist.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == confGUI.fontID;

                    if (glamourUI.settings.partylist.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        confGUI.fontID = i;
                        glamourUI.settings.partylist.font = fontdir[i];
                        loadFont(fontdir[i], glamourUI.settings.partylist.font_size, 'partylist');
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.Button('Bar Dimensions'))then
                plistBarDim.is_open = not plistBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_targetbar', {500,165}, true);
            imgui.Text('Target Bar');
            imgui.SameLine();
            imgui.SetCursorPosX(200);
            if(imgui.Checkbox('Enabled', {glamourUI.settings.targetbar.enabled}))then
                glamourUI.settings.targetbar.enabled = not glamourUI.settings.targetbar.enabled;
            end
            imgui.SameLine();
            imgui.SetCursorPosX(400);
            if(imgui.Checkbox('Themed', {glamourUI.settings.targetbar.themed}))then
                glamourUI.settings.targetbar.themed = not glamourUI.settings.targetbar.themed;
            end
            imgui.SliderFloat('Target Bar Scale  ', target_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.targetbar.gui_scale ~= target_gui_scale[1]) then
                glamourUI.settings.targetbar.gui_scale = target_gui_scale[1];
            end
            imgui.SliderInt('Font Size', target_font_scale, 1, 50);
            if(glamourUI.settings.targetbar.font_size ~= target_font_scale[1])then
                glamourUI.settings.targetbar.font_size = target_font_scale[1];
                loadFont(glamourUI.settings.targetbar.font, glamourUI.settings.targetbar.font_size, 'targetbar');
            end
            if(imgui.BeginCombo('Theme  ', glamourUI.settings.targetbar.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.targetbar.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.targetbar.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Font  ', glamourUI.settings.targetbar.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == confGUI.fontID;

                    if (glamourUI.settings.targetbar.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        confGUI.fontID = i;
                        glamourUI.settings.targetbar.font = fontdir[i];
                        loadFont(fontdir[i], glamourUI.settings.targetbar.font_size, 'targetbar');
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.Button('Bar Dimensions'))then
                tBarDim.is_open = not tBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_alliancePanel', {500,165}, true);
            imgui.Text('Alliance Panels');
            imgui.SameLine();
            imgui.SetCursorPosX(200);
            if(imgui.Checkbox('Enabled', {glamourUI.settings.alliancePanel.enabled}))then
                glamourUI.settings.alliancePanel.enabled = not glamourUI.settings.alliancePanel.enabled;
                glamourUI.settings.alliancePanel2.enabled = not glamourUI.settings.alliancePanel2.enabled;
            end
            imgui.SameLine();
            imgui.SetCursorPosX(400);
            if(imgui.Checkbox('Themed', {glamourUI.settings.alliancePanel.themed}))then
                glamourUI.settings.alliancePanel.themed = not glamourUI.settings.alliancePanel.themed;
                glamourUI.settings.alliancePanel2.themed = not glamourUI.settings.alliancePanel2.themed;
            end
            imgui.SliderFloat('Alliance Panels Scale  ', alliance_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.alliancePanel.gui_scale ~= alliance_gui_scale[1]) then
                glamourUI.settings.alliancePanel.gui_scale = alliance_gui_scale[1];
                glamourUI.settings.alliancePanel.gui_scale = alliance2_gui_scale[1];
            end
            imgui.SliderInt('Font Scale', alliance_font_scale, 1, 50);
            if(glamourUI.settings.alliancePanel.font_size ~= alliance_font_scale[1])then
                glamourUI.settings.alliancePanel.font_size = alliance_font_scale[1];
                glamourUI.settings.alliancePanel2.font_size = alliance_font_scale[1];
                loadFont(glamourUI.settings.alliancePanel.font, glamourUI.settings.alliancePanel.font_size, 'alliancePanel');
            end
            if(imgui.BeginCombo('Theme  ', glamourUI.settings.alliancePanel.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.alliancePanel.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.alliancePanel.theme = themedir[i];
                        glamourUI.settings.alliancePanel2.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Font  ', glamourUI.settings.alliancePanel.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == confGUI.fontID;

                    if (glamourUI.settings.alliancePanel.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        confGUI.fontID = i;
                        glamourUI.settings.alliancePanel.font = fontdir[i];
                        loadFont(fontdir[i], glamourUI.settings.alliancePanel.font_size, 'alliancePanel');
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.Button('BarDimensions'))then
                aPanelBarDim.is_open = not aPanelBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_CastBar', {500, 165}, true);
            imgui.Text('Cast Bar');
            imgui.SameLine();
            imgui.SetCursorPosX(200);
            if(imgui.Checkbox('Enabled', {glamourUI.settings.cBar.enabled}))then
                glamourUI.settings.cBar.enabled = not glamourUI.settings.cBar.enabled;
            end
            imgui.SameLine();
            imgui.SetCursorPosX(400);
            if(imgui.Checkbox('Themed', {glamourUI.settings.cBar.themed}))then
                glamourUI.settings.cBar.themed = not glamourUI.settings.cBar.themed;
            end
            imgui.SliderFloat('Cast Bar Scale  ', cbar_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.cBar.gui_scale ~= cbar_gui_scale[1])then
                glamourUI.settings.cBar.gui_scale = cbar_gui_scale[1];
            end
            if(imgui.BeginCombo('Theme  ', glamourUI.settings.cBar.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.cBar.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.cBar.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            imgui.EndChild();
            imgui.BeginChild('conf_playerStats', {500,165}, true);
            imgui.Text('Player Stats');
            imgui.SameLine();
            imgui.SetCursorPosX(200);
            if(imgui.Checkbox('Enabled', {glamourUI.settings.playerStats.enabled}))then
                glamourUI.settings.playerStats.enabled = not glamourUI.settings.playerStats.enabled;
            end
            imgui.SameLine();
            imgui.SetCursorPosX(400);
            if(imgui.Checkbox('Themed', {glamourUI.settings.playerStats.themed}))then
                glamourUI.settings.playerStats.themed = not glamourUI.settings.playerStats.themed;
            end
            imgui.SliderFloat('Player Stats Scale  ', player_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.playerStats.gui_scale ~= player_gui_scale[1]) then
                glamourUI.settings.playerStats.gui_scale = player_gui_scale[1];
            end
            imgui.SliderInt('Font Size', player_font_scale, 1, 50);
            if(glamourUI.settings.playerStats.font_size ~= player_font_scale[1])then
                glamourUI.settings.playerStats.font_size = player_font_scale[1];
                loadFont(glamourUI.settings.playerStats.font, glamourUI.settings.playerStats.font_size, 'playerStats');
            end
            if(imgui.BeginCombo('Theme  ', glamourUI.settings.playerStats.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.playerStats.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.playerStats.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Font  ', glamourUI.settings.playerStats.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == confGUI.fontID;

                    if (glamourUI.settings.playerStats.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        confGUI.fontID = i;
                        glamourUI.settings.playerStats.font = fontdir[i];
                        loadFont(fontdir[i], glamourUI.settings.playerStats.font_size, 'playerStats');
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.Button('Bar Dimensions'))then
                pStatsBarDim.is_open = not pStatsBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('invPanel', {500,165});
            if(imgui.Checkbox('Enabled##inv', {glamourUI.settings.invPanel.enabled}))then
                glamourUI.settings.invPanel.enabled = not glamourUI.settings.invPanel.enabled;
            end
            imgui.SliderInt('Font Size##inv', inv_font_scale, 1, 50);
            if(glamourUI.settings.invPanel.font_size ~= inv_font_scale[1])then
                glamourUI.settings.invPanel.font_size = inv_font_scale[1];
            end
            if(imgui.BeginCombo('Theme  ##inv', glamourUI.settings.invPanel.theme, combo_flags))then
                for i = 1,#themedir,1 do
                    local is_selected = i == confGUI.themeID;

                    if (glamourUI.settings.invPanel.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                        confGUI.themeID = i;
                        glamourUI.settings.invPanel.theme = themedir[i];
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.BeginCombo('Font  ##inv', glamourUI.settings.invPanel.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == confGUI.fontID;

                    if (glamourUI.settings.invPanel.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        confGUI.fontID = i;
                        glamourUI.settings.invPanel.font = fontdir[i];
                        reloadGUI();
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            if(imgui.Button('Reload Inventory Panel Font'))then
                reloadGUI();
            end
            imgui.EndChild();
            imgui.Text('Recast Panel');
            imgui.BeginChild('Recast Panel', {500, 50}, true);
                if(imgui.Checkbox('Enabled##recast', {glamourUI.settings.rcPanel.enabled}))then
                    glamourUI.settings.rcPanel.enabled = not glamourUI.settings.rcPanel.enabled;
                end
            imgui.EndChild();
            if(imgui.Button('Close Config'))then
                confGUI.is_open = false;
            end
        end
        imgui.PopFont();
        imgui.End();
    end
end

function render_layout_editor()
    local priority = glamourUI.layout.Priority;
    local nPos = T{
        x = {glamourUI.layout.NamePosition.x},
        y = {glamourUI.layout.NamePosition.y}
    };
    local hpB = T{
        x = {glamourUI.layout.HPBarPosition.x},
        y = {glamourUI.layout.HPBarPosition.y},
        textx = {glamourUI.layout.HPBarPosition.textX},
        texty = {glamourUI.layout.HPBarPosition.textY}
    };
    local mpB = T{
        x = {glamourUI.layout.MPBarPosition.x},
        y = {glamourUI.layout.MPBarPosition.y},
        textx = {glamourUI.layout.MPBarPosition.textX},
        texty = {glamourUI.layout.MPBarPosition.textY}
    };
    local tpB = T{
        x = {glamourUI.layout.TPBarPosition.x},
        y = {glamourUI.layout.TPBarPosition.y},
        textx = {glamourUI.layout.TPBarPosition.textX},
        texty = {glamourUI.layout.TPBarPosition.textY}
    };
    local pad = {glamourUI.layout.padding};

    if(layoutGUI.is_open == true)then
        imgui.SetNextWindowSize({465,665});
        if(imgui.Begin('Layout Editor', layoutGUI.is_open, ImGuiWindowFlags_NoDecoration))then
            imgui.PushFont(confFont);
            imgui.Text('Layout Editor');
            imgui.BeginChild('layoutName', {450, 100}, true);
            imgui.Text('Name')
            imgui.SliderInt("X          ##N", nPos.x, 0, 700);
            if(glamourUI.layout.NamePosition.x ~= nPos.x[1])then
                glamourUI.layout.NamePosition.x = nPos.x[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('nXleft', ImGuiDir_Left))then
                glamourUI.layout.NamePosition.x = glamourUI.layout.NamePosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('nXright', ImGuiDir_Right))then
                glamourUI.layout.NamePosition.x = glamourUI.layout.NamePosition.x + 1;
            end
            imgui.SliderInt("Y          ##N", nPos.y, 0, 100);
            if(glamourUI.layout.NamePosition.y ~= nPos.y[1])then
                glamourUI.layout.NamePosition.y = nPos.y[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('nYleft', ImGuiDir_Up))then
                glamourUI.layout.NamePosition.y = glamourUI.layout.NamePosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('nYright', ImGuiDir_Down))then
                glamourUI.layout.NamePosition.y = glamourUI.layout.NamePosition.y + 1;
            end
            
            imgui.EndChild()
            imgui.BeginChild('layoutHP', {450, 150}, true);
            imgui.Text('HP Bar');
            imgui.SliderInt("X          ##HP", hpB.x, 0, 700);
            if(glamourUI.layout.HPBarPosition.x ~= hpB.x[1])then
                glamourUI.layout.HPBarPosition.x = hpB.x[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hXleft', ImGuiDir_Left))then
                glamourUI.layout.HPBarPosition.x = glamourUI.layout.HPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hXright', ImGuiDir_Right))then
                glamourUI.layout.HPBarPosition.x = glamourUI.layout.HPBarPosition.x + 1;
            end
            imgui.SliderInt("Y          ##HP", hpB.y, 0, 100);
            if(glamourUI.layout.HPBarPosition.y ~= hpB.y[1])then
                glamourUI.layout.HPBarPosition.y = hpB.y[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hyleft', ImGuiDir_Up))then
                glamourUI.layout.HPBarPosition.y = glamourUI.layout.HPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hyright', ImGuiDir_Down))then
                glamourUI.layout.HPBarPosition.y = glamourUI.layout.HPBarPosition.y + 1;
            end
            imgui.SliderInt('HP Text X  ##HP', hpB.textx, 0, 700);
            if(glamourUI.layout.HPBarPosition.textX ~= hpB.textx[1])then
                glamourUI.layout.HPBarPosition.textX = hpB.textx[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htxleft', ImGuiDir_Left))then
                glamourUI.layout.HPBarPosition.textX = glamourUI.layout.HPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htxright', ImGuiDir_Right))then
                glamourUI.layout.HPBarPosition.textX = glamourUI.layout.HPBarPosition.textX + 1
            end
            imgui.SliderInt('HP Text Y  ##HP', hpB.texty, 0, 100);
            if(glamourUI.layout.HPBarPosition.textY ~= hpB.texty[1])then
                glamourUI.layout.HPBarPosition.textY = hpB.texty[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htyUp', ImGuiDir_Up))then
                glamourUI.layout.HPBarPosition.textY = glamourUI.layout.HPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htyDown', ImGuiDir_Down))then
                glamourUI.layout.HPBarPosition.textY = glamourUI.layout.HPBarPosition.textY + 1
            end
            imgui.EndChild();
            imgui.BeginChild('layoutMP', {450,150}, true);
            imgui.Text('MP Bar');
            imgui.SliderInt("X          ##MP", mpB.x, 0, 700);
            if(glamourUI.layout.MPBarPosition.x ~= mpB.x[1])then
                glamourUI.layout.MPBarPosition.x = mpB.x[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hXleft', ImGuiDir_Left))then
                glamourUI.layout.MPBarPosition.x = glamourUI.layout.MPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hXright', ImGuiDir_Right))then
                glamourUI.layout.MPBarPosition.x = glamourUI.layout.MPBarPosition.x + 1;
            end
            imgui.SliderInt("Y          ##MP", mpB.y, 0, 100);
            if(glamourUI.layout.MPBarPosition.y ~= mpB.y[1])then
                glamourUI.layout.MPBarPosition.y = mpB.y[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hyleft', ImGuiDir_Up))then
                glamourUI.layout.MPBarPosition.y = glamourUI.layout.MPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('hyright', ImGuiDir_Down))then
                glamourUI.layout.MPBarPosition.y = glamourUI.layout.MPBarPosition.y + 1;
            end
            imgui.SliderInt('MP Text X  ##MP', mpB.textx, 0, 700);
            if(glamourUI.layout.MPBarPosition.textX ~= mpB.textx[1])then
                glamourUI.layout.MPBarPosition.textX = mpB.textx[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('mtxleft', ImGuiDir_Left))then
                glamourUI.layout.MPBarPosition.textX = glamourUI.layout.MPBarPosition.textX - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('mtxright', ImGuiDir_Right))then
                glamourUI.layout.MPBarPosition.textX = glamourUI.layout.MPBarPosition.textX + 1
            end
            imgui.SliderInt('MP Text Y  ##MP', mpB.texty, 0, 100);
            if(glamourUI.layout.MPBarPosition.textY ~= mpB.texty[1])then
                glamourUI.layout.MPBarPosition.textY = mpB.texty[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('mtyUp', ImGuiDir_Up))then
                glamourUI.layout.MPBarPosition.textY = glamourUI.layout.MPBarPosition.textX - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('mtyDown', ImGuiDir_Down))then
                glamourUI.layout.MPBarPosition.textY = glamourUI.layout.MPBarPosition.textY + 1
            end
            imgui.EndChild();
            imgui.BeginChild('layoutTP', {450,150}, true);
            imgui.Text('TP Bar');
            imgui.SliderInt("X          ##TP", tpB.x, 0, 700);
            if(glamourUI.layout.TPBarPosition.x ~= tpB.x[1])then
                glamourUI.layout.TPBarPosition.x = tpB.x[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tXleft', ImGuiDir_Left))then
                glamourUI.layout.TPBarPosition.x = glamourUI.layout.TPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tXright', ImGuiDir_Right))then
                glamourUI.layout.TPBarPosition.x = glamourUI.layout.TPBarPosition.x + 1;
            end
            imgui.SliderInt("Y          ##TP", tpB.y, 0, 100);
            if(glamourUI.layout.TPBarPosition.y ~= tpB.y[1])then
                glamourUI.layout.TPBarPosition.y = tpB.y[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tyleft', ImGuiDir_Up))then
                glamourUI.layout.TPBarPosition.y = glamourUI.layout.TPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tyright', ImGuiDir_Down))then
                glamourUI.layout.TPBarPosition.y = glamourUI.layout.TPBarPosition.y + 1;
            end
            imgui.SliderInt('TP Text X  ##TP', tpB.textx, 0, 700);
            if(glamourUI.layout.TPBarPosition.textX ~= tpB.textx[1])then
                glamourUI.layout.TPBarPosition.textX = tpB.textx[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('ttxleft', ImGuiDir_Left))then
                glamourUI.layout.TPBarPosition.textX = glamourUI.layout.TPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('ttxright', ImGuiDir_Right))then
                glamourUI.layout.TPBarPosition.textX = glamourUI.layout.TPBarPosition.textX + 1
            end
            imgui.SliderInt('TP Text Y  ##TP', tpB.texty, 0, 100);
            if(glamourUI.layout.TPBarPosition.textY ~= tpB.texty[1])then
                glamourUI.layout.TPBarPosition.textY = tpB.texty[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htyUp', ImGuiDir_Up))then
                glamourUI.layout.TPBarPosition.textY = glamourUI.layout.TPBarPosition.textY -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('htyDown', ImGuiDir_Down))then
                glamourUI.layout.TPBarPosition.textY = glamourUI.layout.TPBarPosition.textY + 1
            end
            imgui.EndChild();
            imgui.BeginChild('layoutPadding', {450, 60}, true);
            imgui.Text('Padding');
            imgui.SliderInt("          ", pad, 0, 100);
            if(glamourUI.layout.padding ~= pad[1])then
                glamourUI.layout.padding = pad[1];
            end
            imgui.SameLine();
            if(imgui.ArrowButton('pleft', ImGuiDir_Up))then
                glamourUI.layout.padding = glamourUI.layout.padding - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('pright', ImGuiDir_Down))then
                glamourUI.layout.padding = glamourUI.layout.padding + 1;
            end
            imgui.EndChild();
            if(imgui.Button('Close Editor'))then
                layoutGUI.is_open = false;
                updateLayoutFile(glamourUI.settings.partylist.layout);
            end
            imgui.PopFont();
        end
        imgui.End();
    end
end

function render_plistBarDim()
    local hpBl = {glamourUI.settings.partylist.hpBarDim.l};
    local hpBg = {glamourUI.settings.partylist.hpBarDim.g};
    local mpBl = {glamourUI.settings.partylist.mpBarDim.l};
    local mpBg = {glamourUI.settings.partylist.mpBarDim.g};
    local tpBl = {glamourUI.settings.partylist.tpBarDim.l};
    local tpBg = {glamourUI.settings.partylist.tpBarDim.g};
    if(plistBarDim.is_open == true)then
        imgui.SetNextWindowSize({300, 100}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('plistBarDim', {300, 100}, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            imgui.PushFont(confFont);
            imgui.Text('Party List Bar Dimensions');
            imgui.BeginChild('hpBar', {300, 100});
            imgui.Text('HP Bar');
            imgui.SliderInt('Length', hpBl, 1, 500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                hpBl[1] = hpBl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                hpBl[1] = hpBl[1] + 1;
            end
            imgui.SliderInt('Girth', hpBg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                hpBg[1] = hpBg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                hpBg[1] = hpBg[1] + 1;
            end
            imgui.EndChild();
            imgui.BeginChild('mpBar', {300, 100});
            imgui.Text('MP Bar');
            imgui.SliderInt('Length', mpBl, 1, 500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                mpBl[1] = mpBl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                mpBl[1] = mpBl[1] + 1;
            end
            imgui.SliderInt('Girth', mpBg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                mpBg[1] = mpBg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                mpBg[1] = mpBg[1] + 1;
            end
            imgui.EndChild();
            imgui.BeginChild('tpBar', {300, 100});
            imgui.Text('TP Bar');
            imgui.SliderInt('Length', tpBl, 1, 500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                tpBl[1] = tpBl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                tpBl[1] = tpBl[1] + 1;
            end
            imgui.SliderInt('Girth', tpBg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                tpBg[1] = tpBg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                tpBg[1] = tpBg[1] + 1;
            end
            imgui.EndChild();
            if(imgui.Button('Close Editor'))then
                plistBarDim.is_open = false;
            end
            imgui.PopFont();
        end
        glamourUI.settings.partylist.hpBarDim.l = hpBl[1];
        glamourUI.settings.partylist.hpBarDim.g = hpBg[1];
        glamourUI.settings.partylist.mpBarDim.l = mpBl[1];
        glamourUI.settings.partylist.mpBarDim.g = mpBg[1];
        glamourUI.settings.partylist.tpBarDim.l = tpBl[1];
        glamourUI.settings.partylist.tpBarDim.g = tpBg[1];
        imgui.End();
    end
end

function render_tbarDim()
    local hpBl = {glamourUI.settings.targetbar.hpBarDim.l};
    local hpBg = {glamourUI.settings.targetbar.hpBarDim.g};

    if(tBarDim.is_open == true)then
        imgui.SetNextWindowSize({300, 100}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('tBarDim', {300, 100}, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            imgui.PushFont(confFont);
            imgui.Text('Target Bar Dimensions');
            imgui.BeginChild('hpBar', {300, 100});
            imgui.Text('HP Bar');
            imgui.SliderInt('Length', hpBl, 1, 1500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                hpBl[1] = hpBl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                hpBl[1] = hpBl[1] + 1;
            end
            imgui.SliderInt('Girth', hpBg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                hpBg[1] = hpBg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                hpBg[1] = hpBg[1] + 1;
            end
            imgui.EndChild();
            if(imgui.Button('Close Editor'))then
                tBarDim.is_open = false;
            end
            imgui.PopFont();
        end
        glamourUI.settings.targetbar.hpBarDim.l = hpBl[1];
        glamourUI.settings.targetbar.hpBarDim.g = hpBg[1];
        imgui.End();
    end
end

function render_aPanelDim()
    local hpBl = {glamourUI.settings.alliancePanel.hpBarDim.l};
    local hpBg = {glamourUI.settings.alliancePanel.hpBarDim.g};

    if(aPanelBarDim.is_open == true)then
        imgui.SetNextWindowSize({300, 100}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('aPanelBarDim', {300, 100}, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            imgui.PushFont(confFont);
            imgui.Text('Alliance Panel Bar Dimensions');
            imgui.BeginChild('hpBar', {300, 100});
            imgui.Text('HP Bar');
            imgui.SliderInt('Length', hpBl, 1, 500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                hpBl[1] = hpBl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                hpBl[1] = hpBl[1] + 1;
            end
            imgui.SliderInt('Girth', hpBg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                hpBg[1] = hpBg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                hpBg[1] = hpBg[1] + 1;
            end
            imgui.EndChild();
            if(imgui.Button('Close Editor'))then
                aPanelBarDim.is_open = false;
            end
            imgui.PopFont();
        end
        glamourUI.settings.alliancePanel.hpBarDim.l = hpBl[1];
        glamourUI.settings.alliancePanel.hpBarDim.g = hpBg[1];
        glamourUI.settings.alliancePanel2.hpBarDim.l = hpBl[1];
        glamourUI.settings.alliancePanel2.hpBarDim.g = hpBg[1];
        imgui.End();
    end
end

function render_pStatsPanelDim()
    local Bl = {glamourUI.settings.playerStats.BarDim.l};
    local Bg = {glamourUI.settings.playerStats.BarDim.g};

    if(pStatsBarDim.is_open == true)then
        imgui.SetNextWindowSize({300, 100}, ImGuiCond_FirstUseEver);
        if(imgui.Begin('pStatsBarDim', {300, 100}, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoDecoration)))then
            imgui.PushFont(confFont);
            imgui.Text('Player Stats Bar Dimensions');
            imgui.BeginChild('hpBar', {300, 100});
            imgui.Text('HP Bar');
            imgui.BeginGroup('Length');
            imgui.SliderInt('Length', Bl, 1, 500);
            imgui.SameLine();
            if(imgui.Button('-##l'))then
                Bl[1] = Bl[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##l'))then
                Bl[1] = Bl[1] + 1;
            end
            imgui.SliderInt('Girth', Bg, 1, 100);
            imgui.SameLine();
            if(imgui.Button('-##g'))then
                Bg[1] = Bg[1] - 1;
            end
            imgui.SameLine();
            if(imgui.Button('+##g'))then
                Bg[1] = Bg[1] + 1;
            end
            imgui.EndChild();
            if(imgui.Button('Close Editor'))then
                pStatsBarDim.is_open = false;
            end
        end
        glamourUI.settings.playerStats.BarDim.l = Bl[1];
        glamourUI.settings.playerStats.BarDim.g = Bg[1];
        imgui.PopFont();
        imgui.End();
    end
end