require('common')
local imgui = require('imgui')


confGUI = T{
    is_open = false,
    themeID = T{ getThemeID('Default')},
    layoutID = T{ getLayoutID('Default')},
    --fontID = T{ getFontID('Default')}
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

function render_config()
    local party_gui_scale = {glamourUI.settings.partylist.gui_scale};
    local target_gui_scale = {glamourUI.settings.targetbar.gui_scale};
    local alliance_gui_scale = {glamourUI.settings.alliancePanel.gui_scale};
    local alliance2_gui_scale = {glamourUI.settings.alliancePanel2.gui_scale};
    local player_gui_scale = {glamourUI.settings.playerStats.gui_scale};
    local party_font_scale = {glamourUI.settings.partylist.font_scale};
    local target_font_scale = {glamourUI.settings.targetbar.font_scale};
    local alliance_font_scale = {glamourUI.settings.alliancePanel.font_scale};
    local alliance2_font_scale = {glamourUI.settings.alliancePanel2.font_scale};
    local player_font_scale = {glamourUI.settings.playerStats.font_scale};
    local themedir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    local layoutdir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\'):fmt(AshitaCore:GetInstallPath()));
    --local fontdir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Fonts\\')):fmt(AshitaCore:GetInstallPath());


    if(confGUI.is_open == true)then
        imgui.SetNextWindowSize({-1,-1}, ImGuiCond_Always);
        if(imgui.Begin('GlamourUI Configuration', confGUI.is_open, ImGuiWindowFlags_NoDecoration,ImGuiWindowFlags_AlwaysAutoResize)) then
            imgui.Text('GlamourUI Configuration');
            imgui.BeginGroup();
            imgui.BeginChild('conf_partylist', {500,160}, true);
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
            imgui.SliderFloat('Font Scale', party_font_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.partylist.font_scale ~= party_font_scale[1])then
                glamourUI.settings.partylist.font_scale = party_font_scale[1];
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
            if(imgui.Button('Bar Dimensions'))then
                plistBarDim.is_open = not plistBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_targetbar', {500,145}, true);
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
            imgui.SliderFloat('Font Scale', target_font_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.targetbar.font_scale ~= target_font_scale[1])then
                glamourUI.settings.targetbar.font_scale = target_font_scale[1];
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
            if(imgui.Button('Bar Dimensions'))then
                tBarDim.is_open = not tBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_alliancePanel', {500,145}, true);
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
            imgui.SliderFloat('Font Scale', alliance_font_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.alliancePanel.font_scale ~= alliance_font_scale[1])then
                glamourUI.settings.alliancePanel.font_scale = alliance_font_scale[1];
                glamourUI.settings.alliancePanel.font_scale = alliance_font_scale[1];
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
            if(imgui.Button('BarDimensions'))then
                aPanelBarDim.is_open = not aPanelBarDim.is_open;
            end
            imgui.EndChild();
            imgui.BeginChild('conf_playerStats', {500,145}, true);
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
            imgui.SliderFloat('Font Scale', player_font_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.playerStats.font_scale ~= player_font_scale[1])then
                glamourUI.settings.playerStats.font_scale = player_font_scale[1];
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
            if(imgui.Button('Bar Dimensions'))then
                pStatsBarDim.is_open = not pStatsBarDim.is_open;
            end
            imgui.EndChild();
            if(imgui.Button('Close Config'))then
                confGUI.is_open = false;
            end
            imgui.EndGroup();
        end
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
        y = {glamourUI.layout.HPBarPosition.y}
    };
    local mpB = T{
        x = {glamourUI.layout.MPBarPosition.x},
        y = {glamourUI.layout.MPBarPosition.y}
    };
    local tpB = T{
        x = {glamourUI.layout.TPBarPosition.x},
        y = {glamourUI.layout.TPBarPosition.y}
    };
    local pad = {glamourUI.layout.padding};

    if(layoutGUI.is_open == true)then
        imgui.SetNextWindowSize({400,515});
        if(imgui.Begin('Layout Editor', layoutGUI.is_open, ImGuiWindowFlags_NoDecoration))then
            imgui.Text('Layout Editor');
            imgui.BeginChild('layoutName', {400, 100}, true);
            imgui.Text('Name')
            imgui.InputInt("X  ", nPos.x, 0, 700);
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
            imgui.InputInt("Y  ", nPos.y, 0, 100);
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
            imgui.BeginChild('layoutHP', {400, 100}, true);
            imgui.Text('HP Bar');
            imgui.InputInt("X  ", hpB.x, 0, 700);
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
            imgui.InputInt("Y  ", hpB.y, 0, 100);
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
            imgui.EndChild();
            imgui.BeginChild('layoutMP', {400,100}, true);
            imgui.Text('MP Bar');
            imgui.InputInt("X  ", mpB.x, 0, 700);
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
            imgui.InputInt("Y  ", mpB.y, 0, 100);
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
            imgui.EndChild();
            imgui.BeginChild('layoutTP', {400,100}, true);
            imgui.Text('TP Bar');
            imgui.InputInt("X  ", tpB.x, 0, 700);
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
            imgui.InputInt("Y  ", tpB.y, 0, 100);
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
            imgui.EndChild();
            imgui.BeginChild('layoutPadding', {400, 50}, true);
            imgui.Text('Padding');
            imgui.InputInt("", pad, 0, 100);
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
        imgui.End();
    end
end