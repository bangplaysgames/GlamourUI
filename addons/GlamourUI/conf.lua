require('common')
local imgui = require('imgui')


confGUI = T{
    is_open = false,
    themeID = T{ getThemeID('Default')}
}

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

    if(confGUI.is_open == true)then
        imgui.SetNextWindowSize({-1,-1}, ImGuiCond_Always);
        if(imgui.Begin('GlamourUI Configuration', confGUI.is_open, ImGuiWindowFlags_NoDecoration,ImGuiWindowFlags_AlwaysAutoResize)) then
            imgui.BeginGroup();
            imgui.BeginChild('conf_partylist', {500,125}, true);
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
            imgui.EndChild();
            imgui.BeginChild('conf_targetbar', {500,125}, true);
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
            imgui.SliderFloat('Target Bar Scale  ', party_gui_scale, 0.1, 5.0, '%.1f');
            if(glamourUI.settings.targetbar.gui_scale ~= target_gui_scale[1]) then
                glamourUI.settings.targetbar.gui_scale = target_gui_scale[1];
            end
            imgui.SliderFloat('Font Scale', party_font_scale, 0.1, 5.0, '%.1f');
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
            imgui.EndChild();
            imgui.BeginChild('conf_alliancePanel', {500,125}, true);
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
                glamourUI.settings.alliancePanel.themed = not glamourUI.settings.AlliancePanel.themed;
                glamourUI.settings.alliancePanel2.themed = not glamourUI.settings.AlliancePanel2.themed;
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
            imgui.EndChild();
            imgui.BeginChild('conf_playerStats', {500,125}, true);
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
            imgui.EndChild();
            if(imgui.Button('Close Config'))then
                confGUI.is_open = false;
            end
            imgui.EndGroup();
        end
        imgui.End();
    end
end