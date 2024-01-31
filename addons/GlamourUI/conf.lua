local imgui = require('imgui')
local ffi = require('ffi')
local chat = require('chat')

local function getThemeID(theme)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    for i = 1,#dir,1 do
        if(dir[i] == theme) then
            return i;
        end
    end
end

local function getLayoutID(layout)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\'):fmt(AshitaCore:GetInstallPath()));

    for i = 1,#dir,1 do
        if(dir[i] == layout) then
            return i;
        end
    end
end

local function getFontID(font)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Fonts\\'):fmt(AshitaCore:GetInstallPath()), '.ttf');

    for i = 1,#dir,1 do
        if(dir[i] == font) then
            return i;
        end
    end
end

local function getBuffID(buff)
    local dir = ashita.fs.get_directory(('%s\\resources\\%s\\'):fmt(AshitaCore:GetInstallPath(), addon.name));

    for i = 1,#dir,1 do
        if(dir[i] == buff)then
            return i;
        end
    end
end

local themeID = T{ getThemeID('Default')};
local layoutID = T{ getLayoutID('Default')};
local fontID = T{ getFontID('Default')};
local buffID = T{ getBuffID('Default')};
local plLEditor = false;


local conf = {}

conf.is_open = false;

conf.render_config = function()
    local party_gui_scale = {GlamourUI.settings.Party.pList.gui_scale};
    local target_gui_scale = {GlamourUI.settings.TargetBar.gui_scale};
    local alliance_gui_scale = {GlamourUI.settings.Party.aPanel.gui_scale};
    local player_gui_scale = {GlamourUI.settings.PlayerStats.gui_scale};
    local cbar_gui_scale = {GlamourUI.settings.cBar.gui_scale};
    local rc_gui_scale = {GlamourUI.settings.rcPanel.gui_scale};
    local party_font_scale = {GlamourUI.settings.Party.pList.font_scale};
    local target_font_scale = {GlamourUI.settings.TargetBar.font_scale};
    local alliance_font_scale = {GlamourUI.settings.Party.aPanel.font_scale};
    local player_font_scale = {GlamourUI.settings.PlayerStats.font_scale};
    local inventory_font_scale = {GlamourUI.settings.Inv.font_scale};
    local cbar_font_scale = {GlamourUI.settings.cBar.font_scale};
    local rc_font_scale = {GlamourUI.settings.rcPanel.font_scale};
    local fontPath = ('%s\\config\\addons\\%s\\Fonts\\'):fmt(AshitaCore:GetInstallPath(), addon.name)
    local themedir = ashita.fs.get_directory(('%s\\config\\addons\\%s\\Themes\\'):fmt(AshitaCore:GetInstallPath(), addon.name));
    local layoutdir = ashita.fs.get_directory(('%s\\config\\addons\\%s\\Layouts\\'):fmt(AshitaCore:GetInstallPath(), addon.name));
    local buffdir = ashita.fs.get_directory(('%s\\resources\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name));
    local fontdir = ashita.fs.get_dir(fontPath, '.*');


    if(conf.is_open == true)then
        imgui.SetNextWindowSize({500, 325});
        if(imgui.Begin('ConfMain##GlamConf', conf.is_open, bit.bor(ImGuiWindowFlags_NoDecoration)))then
            local txtOffset = ((500 - imgui.CalcTextSize('Glamour UI Configuration')) * 0.5);
            imgui.SetCursorPosX(txtOffset);
            imgui.Text('Glamour UI Configuration');

            imgui.SetWindowFontScale(0.35);
            if(imgui.BeginTabBar('ConfTabBar##Glam'))then
                if(imgui.BeginTabItem('Party List'))then
                    imgui.BeginChild('PartyList##GlamPList', {485, 210}, false);

                    --Enable Toggle
                    if(imgui.Checkbox('Enabled##Plist', {GlamourUI.settings.Party.pList.enabled}))then
                        GlamourUI.settings.Party.pList.enabled = not GlamourUI.settings.Party.pList.enabled;
                    end;imgui.SameLine();
                    imgui.SetCursorPosX(200);
                    
                    --Theme Toggle
                    if(imgui.Checkbox('Themed##Plist', {GlamourUI.settings.Party.pList.themed}))then
                        GlamourUI.settings.Party.pList.themed = not GlamourUI.settings.Party.pList.themed;
                    end
                    
                    --Theme Selector
                    if(imgui.BeginCombo('Theme##PList', GlamourUI.settings.Party.pList.theme, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.Party.pList.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.Party.pList.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Layout Selector
                    if(imgui.BeginCombo('Layout##PList', GlamourUI.settings.Party.pList.layout, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#layoutdir,1 do
                            local is_selected = i == layoutID;

                            if(GlamourUI.settings.Party.pList.layout ~= layoutdir[i] and imgui.Selectable(layoutdir[i], is_selected))then
                                layoutID = i;
                                GlamourUI.settings.Party.pList.layout = layoutdir[i];
                                gHelper.loadLayout(GlamourUI.settings.Party.pList.layout);
                            end
                            if(is_selected)then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Layout Editor
                    imgui.SameLine();
                    imgui.SetCursorPosX(400);
                    if(imgui.Button('Layout Editor##GlamPList'))then
                        plLEditor = not plLEditor;
                    end


                    --Buff Icon Theme Selector
                    if(imgui.BeginCombo('Buff Theme##PList', GlamourUI.settings.Party.pList.buffTheme, combo_flags))then
                        for i = 1,#buffdir,1 do
                            local is_selected = i == buffID;

                            if(GlamourUI.settings.Party.pList.buffTheme ~= buffdir[i] and imgui.Selectable(buffdir[i], is_selected))then
                                buffID = i;
                                GlamourUI.settings.Party.pList.buffTheme = buffdir[i];
                            end
                            if(is_selected)then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                    end

                    --Gui Scale
                    imgui.SliderFloat('GuiScale##GlamPList', party_gui_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.Party.pList.gui_scale ~= party_gui_scale[1])then
                        GlamourUI.settings.Party.pList.gui_scale = party_gui_scale[1];
                    end

                    --Font Scale
                    imgui.SliderFloat('FontScale##GlamPList', party_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.Party.pList.font_scale ~= party_font_scale[1])then
                        GlamourUI.settings.Party.pList.font_scale = party_font_scale[1];
                    end

                    --Hide Default Party List
                    --Theme Toggle
                    if(imgui.Checkbox('Hide Default Party List##Plist', {GlamourUI.settings.Party.pList.hideDefault}))then
                        GlamourUI.settings.Party.pList.hideDefault = not GlamourUI.settings.Party.pList.hideDefault;
                    end

                    --FillDown
                    if(imgui.Checkbox('Fill Down##Plist', {GlamourUI.settings.Party.pList.FillDown}))then
                        GlamourUI.settings.Party.pList.FillDown = not GlamourUI.settings.Party.pList.FillDown;
                    end;

                    imgui.EndChild();
                    imgui.EndTabItem();
                end

                --Alliance Panel
                if(imgui.BeginTabItem('Alliance Panel##GlamConf'))then
                    local APhpB = {
                        l = { GlamourUI.settings.Party.aPanel.hpBarDim.l },
                        g = { GlamourUI.settings.Party.aPanel.hpBarDim.g }
                    }
                    imgui.BeginChild('AlliancePanel##GlamConf', {485, 210}, false);

                    --Enable Toggle
                    if(imgui.Checkbox('Enabled##GlamAPanel', {GlamourUI.settings.Party.aPanel.enabled}))then
                        GlamourUI.settings.Party.aPanel.enabled = not GlamourUI.settings.Party.aPanel.enabled;
                    end;imgui.SameLine();
                    imgui.SetCursorPosX(200);

                    --Theme Toggle
                    if(imgui.Checkbox('Themed##GlamAPanel', {GlamourUI.settings.Party.aPanel.themed}))then
                        GlamourUI.settings.Party.aPanel.themed = not GlamourUI.settings.Party.aPanel.themed;
                    end

                    --Theme Selector
                    if(imgui.BeginCombo('Theme##GlamAPanel', GlamourUI.settings.Party.aPanel.theme, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.Party.aPanel.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.Party.aPanel.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Gui Scale
                    imgui.SliderFloat('GuiScale##GlamAPanel', alliance_gui_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.Party.aPanel.gui_scale ~= alliance_gui_scale[1])then
                        GlamourUI.settings.Party.aPanel.gui_scale = alliance_gui_scale[1];
                    end

                    --Font Scale
                    imgui.SliderFloat('FontScale##GlamAPanel', alliance_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.Party.aPanel.font_scale ~= alliance_font_scale[1])then
                        GlamourUI.settings.Party.aPanel.font_scale = alliance_font_scale[1];
                    end

                    --HP Bar Dimensions
                    imgui.Text('HP Bar Dimensions');
                    imgui.SliderInt("Length##GlamAPanelHPPos", APhpB.l, 0, 700);
                    if(GlamourUI.settings.Party.aPanel.hpBarDim.l ~= APhpB.l[1])then
                        GlamourUI.settings.Party.aPanel.hpBarDim.l = APhpB.l[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('lleft##GlamAPanelHPPos', ImGuiDir_Left))then
                        GlamourUI.settings.Party.aPanel.hpBarDim.l = GlamourUI.settings.Party.aPanel.hpBarDim.l - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('lright##GlamAPanelHPPos', ImGuiDir_Right))then
                        GlamourUI.settings.Party.aPanel.hpBarDim.l = GlamourUI.settings.Party.aPanel.hpBarDim.l + 1;
                    end
                    imgui.SliderInt("Girth##GlamHPPos", APhpB.g, 0, 100);
                    if(GlamourUI.settings.Party.aPanel.hpBarDim.g ~= APhpB.g[1])then
                        GlamourUI.settings.Party.aPanel.hpBarDim.g = APhpB.g[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('gleft##GlamHPPos', ImGuiDir_Up))then
                        GlamourUI.settings.Party.aPanel.hpBarDim.g = GlamourUI.settings.Party.aPanel.hpBarDim.g - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('gright##GlamHPPos', ImGuiDir_Down))then
                        GlamourUI.settings.Party.aPanel.hpBarDim.g = GlamourUI.settings.Party.aPanel.hpBarDim.g + 1;
                    end

                    imgui.EndChild();
                    imgui.EndTabItem();
                end
                
                --Target Bar
                if(imgui.BeginTabItem('Target Bar##GlamConf'))then
                    local TBhpB = {
                        l = {GlamourUI.settings.TargetBar.hpBarDim.l},
                        g = {GlamourUI.settings.TargetBar.hpBarDim.g}
                    }
                    imgui.BeginChild('TargetBar##GlamConf', {485, 210}, false);

                    --Enable Toggle
                    if(imgui.Checkbox('Enabled##GlamAPanel', {GlamourUI.settings.TargetBar.enabled}))then
                        GlamourUI.settings.TargetBar.enabled = not GlamourUI.settings.TargetBar.enabled;
                    end;imgui.SameLine();
                    imgui.SetCursorPosX(200);

                    --Theme Toggle
                    if(imgui.Checkbox('Themed##GlamAPanel', {GlamourUI.settings.TargetBar.themed}))then
                        GlamourUI.settings.TargetBar.themed = not GlamourUI.settings.TargetBar.themed;
                    end

                    --Theme Selector
                    if(imgui.BeginCombo('Theme##GlamAPanel', GlamourUI.settings.TargetBar.theme, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.TargetBar.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.TargetBar.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Gui Scale
                    imgui.SliderFloat('GuiScale##GlamAPanel', target_gui_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.TargetBar.gui_scale ~= target_gui_scale[1])then
                        GlamourUI.settings.TargetBar.gui_scale = target_gui_scale[1];
                    end

                    --Font Scale
                    imgui.SliderFloat('FontScale##GlamAPanel', target_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.TargetBar.font_scale ~= target_font_scale[1])then
                        GlamourUI.settings.TargetBar.font_scale = target_font_scale[1];
                    end

                    --HP Bar Dimensions
                    imgui.Text('HP Bar Dimensions');
                    imgui.SliderInt("Length##GlamAPanelHPPos", TBhpB.l, 0, 700);
                    if(GlamourUI.settings.TargetBar.hpBarDim.l ~= TBhpB.l[1])then
                        GlamourUI.settings.TargetBar.hpBarDim.l = TBhpB.l[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('lleft##GlamAPanelHPPos', ImGuiDir_Left))then
                        GlamourUI.settings.TargetBar.hpBarDim.l = GlamourUI.settings.TargetBar.hpBarDim.l - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('lright##GlamAPanelHPPos', ImGuiDir_Right))then
                        GlamourUI.settings.TargetBar.hpBarDim.l = GlamourUI.settings.TargetBar.hpBarDim.l + 1;
                    end
                    imgui.SliderInt("Girth##GlamHPPos", TBhpB.g, 0, 100);
                    if(GlamourUI.settings.TargetBar.hpBarDim.g ~= TBhpB.g[1])then
                        GlamourUI.settings.TargetBar.hpBarDim.g = TBhpB.g[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('gleft##GlamHPPos', ImGuiDir_Up))then
                        GlamourUI.settings.TargetBar.hpBarDim.g = GlamourUI.settings.TargetBar.hpBarDim.g - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('gright##GlamHPPos', ImGuiDir_Down))then
                        GlamourUI.settings.TargetBar.hpBarDim.g = GlamourUI.settings.TargetBar.hpBarDim.g + 1;
                    end
                    
                    imgui.EndChild();
                    imgui.EndTabItem();
                end
                
                --Player Stats
                if(imgui.BeginTabItem('Player Stats##GlamConf'))then
                    local PSB = {
                        l = {GlamourUI.settings.PlayerStats.BarDim.l},
                        g = {GlamourUI.settings.PlayerStats.BarDim.g}
                    }
                    imgui.BeginChild('PlayerStats##GlamConf', {485, 210}, false)

                    --Enable Toggle
                    if(imgui.Checkbox('Enabled##GlamAPanel', {GlamourUI.settings.PlayerStats.enabled}))then
                        GlamourUI.settings.PlayerStats.enabled = not GlamourUI.settings.PlayerStats.enabled;
                    end;imgui.SameLine();
                    imgui.SetCursorPosX(200);

                    --Theme Toggle
                    if(imgui.Checkbox('Themed##GlamAPanel', {GlamourUI.settings.PlayerStats.themed}))then
                        GlamourUI.settings.PlayerStats.themed = not GlamourUI.settings.PlayerStats.themed;
                    end

                    --Theme Selector
                    if(imgui.BeginCombo('Theme##GlamAPanel', GlamourUI.settings.PlayerStats.theme, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.PlayerStats.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.PlayerStats.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Gui Scale
                    imgui.SliderFloat('GuiScale##GlamAPanel', player_gui_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.PlayerStats.gui_scale ~= player_gui_scale[1])then
                        GlamourUI.settings.PlayerStats.gui_scale = player_gui_scale[1];
                    end

                    --Font Scale
                    imgui.SliderFloat('FontScale##GlamAPanel', player_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.PlayerStats.font_scale ~= player_font_scale[1])then
                        GlamourUI.settings.PlayerStats.font_scale = player_font_scale[1];
                    end

                    --HP Bar Dimensions
                    imgui.Text('HP Bar Dimensions');
                    imgui.SliderInt("Length##GlamAPanelHPPos", PSB.l, 0, 700);
                    if(GlamourUI.settings.PlayerStats.BarDim.l ~= PSB.l[1])then
                        GlamourUI.settings.PlayerStats.BarDim.l = PSB.l[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('lleft##GlamAPanelHPPos', ImGuiDir_Left))then
                        GlamourUI.settings.PlayerStats.BarDim.l = GlamourUI.settings.PlayerStats.BarDim.l - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('lright##GlamAPanelHPPos', ImGuiDir_Right))then
                        GlamourUI.settings.PlayerStats.BarDim.l = GlamourUI.settings.PlayerStats.BarDim.l + 1;
                    end
                    imgui.SliderInt("Girth##GlamHPPos", PSB.g, 0, 100);
                    if(GlamourUI.settings.PlayerStats.BarDim.g ~= PSB.g[1])then
                        GlamourUI.settings.PlayerStats.BarDim.g = PSB.g[1];
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(385);
                    if(imgui.ArrowButton('gleft##GlamHPPos', ImGuiDir_Up))then
                        GlamourUI.settings.PlayerStats.BarDim.g = GlamourUI.settings.PlayerStats.BarDim.g - 1;
                    end
                    imgui.SameLine();
                    if(imgui.ArrowButton('gright##GlamHPPos', ImGuiDir_Down))then
                        GlamourUI.settings.PlayerStats.BarDim.g = GlamourUI.settings.PlayerStats.BarDim.g + 1;
                    end
                    
                    imgui.EndChild();
                    imgui.EndTabItem();                    
                end
                
                --Inventory Panel
                if(imgui.BeginTabItem('Inventory Panel##GlamConf'))then
                    imgui.BeginChild('InventoryPanel##GlamConf', {485, 210}, false);

                    --Enable Toggle
                    if(imgui.Checkbox('Enabled##GlamInvPanel', {GlamourUI.settings.Inv.enabled}))then
                        GlamourUI.settings.Inv.enabled = not GlamourUI.settings.Inv.enabled;
                    end

                    --Theme Selector
                    if(imgui.BeginCombo('Theme##GlamInvPanel', GlamourUI.settings.Inv.theme, combo_flags))then
                        imgui.SetWindowFontScale(0.3);
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.Inv.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.Inv.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end

                    --Font Scale
                    imgui.SliderFloat('FontScale##GlamInvPanel', inventory_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.Inv.font_scale ~= inventory_font_scale[1])then
                        GlamourUI.settings.Inv.font_scale = inventory_font_scale[1];
                    end

                    imgui.EndChild();
                    imgui.EndTabItem();
                end

                --Recast Panel
                if(imgui.BeginTabItem('Recast Panel##GlamConf'))then
                    if(imgui.BeginChild('RecastPanel##GlamConf', {485, 210}, false))then

                        --Enable Toggle
                        if(imgui.Checkbox('Enabled##GlamAPanel', {GlamourUI.settings.rcPanel.enabled}))then
                            GlamourUI.settings.rcPanel.enabled = not GlamourUI.settings.rcPanel.enabled;
                        end;imgui.SameLine();
                        imgui.SetCursorPosX(200);

                        --Theme Toggle
                        if(imgui.Checkbox('Themed##GlamAPanel', {GlamourUI.settings.rcPanel.themed}))then
                            GlamourUI.settings.rcPanel.themed = not GlamourUI.settings.rcPanel.themed;
                        end

                        --Theme Selector
                        if(imgui.BeginCombo('Theme##GlamAPanel', GlamourUI.settings.rcPanel.theme, combo_flags))then
                            imgui.SetWindowFontScale(0.3);
                            for i = 1,#themedir,1 do
                                local is_selected = i == themeID;

                                if (GlamourUI.settings.rcPanel.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                    themeID = i;
                                    GlamourUI.settings.rcPanel.theme = themedir[i];
                                end
                                if(is_selected) then
                                    imgui.SetItemDefaultFocus();
                                end
                            end
                            imgui.EndCombo();
                        end

                        --Gui Scale
                        imgui.SliderFloat('GuiScale##GlamAPanel', rc_gui_scale, 0.1, 5.0, '%.1f');
                        if(GlamourUI.settings.rcPanel.gui_scale ~= rc_gui_scale[1])then
                            GlamourUI.settings.rcPanel.gui_scale = rc_gui_scale[1];
                        end

                        --Font Scale
                        imgui.SliderFloat('FontScale##GlamAPanel', rc_font_scale, 0.1, 5.0, '%.1f');
                        if(GlamourUI.settings.rcPanel.font_scale ~= rc_font_scale[1])then
                            GlamourUI.settings.rcPanel.font_scale = rc_font_scale[1];
                        end
                        
                        imgui.EndChild();
                    end
                    imgui.EndTabItem();
                end
                
                --Cast Bar
                if(imgui.BeginTabItem('Cast Bar##GlamConf'))then
                    imgui.BeginChild('CBar##GlamConf', {485, 210}, false);

                    imgui.Text('Cast Bar');
                    imgui.SameLine();
                    imgui.SetCursorPosX(200);
                    if(imgui.Checkbox('Enabled', {GlamourUI.settings.cBar.enabled}))then
                        GlamourUI.settings.cBar.enabled = not GlamourUI.settings.cBar.enabled;
                    end
                    imgui.SameLine();
                    imgui.SetCursorPosX(400);
                    if(imgui.Checkbox('Themed', {GlamourUI.settings.cBar.themed}))then
                        GlamourUI.settings.cBar.themed = not GlamourUI.settings.cBar.themed;
                    end
                    imgui.SetCursorPosX(200);
                    if(imgui.Checkbox('Dummy Castbar', {gCBar.cBarDummy}))then
                        gPacket.action.Target = GetPlayerEntity().TargetIndex;
                        gPacket.action.Resource.Name = {}
                        gPacket.action.Resource.Name[1] = "Awesome Spell"
                        gCBar.cBarDummy = not gCBar.cBarDummy;
                    end
                    imgui.SliderFloat('Cast Bar Scale##GlamConf', cbar_gui_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.cBar.gui_scale ~= cbar_gui_scale[1])then
                        GlamourUI.settings.cBar.gui_scale = cbar_gui_scale[1];
                    end
                    imgui.SliderFloat('Cast Bar Font Scale##GlamConf', cbar_font_scale, 0.1, 5.0, '%.1f');
                    if(GlamourUI.settings.cBar.font_scale ~= cbar_font_scale[1])then
                        GlamourUI.settings.cBar.font_scale = cbar_font_scale[1];
                    end
                    if(imgui.BeginCombo('Theme', GlamourUI.settings.cBar.theme, combo_flags))then
                        for i = 1,#themedir,1 do
                            local is_selected = i == themeID;

                            if (GlamourUI.settings.cBar.theme ~= themedir[i] and imgui.Selectable(themedir[i], is_selected))then
                                themeID = i;
                                GlamourUI.settings.cBar.theme = themedir[i];
                            end
                            if(is_selected) then
                                imgui.SetItemDefaultFocus();
                            end
                        end
                        imgui.EndCombo();
                    end
                    imgui.EndChild();
                    imgui.EndTabItem();
                end
            imgui.EndTabBar();
            end

            --Font Selector
            if(imgui.BeginCombo('Font##GlamConf', GlamourUI.settings.font, combo_flags))then
                for i = 1,#fontdir,1 do
                    local is_selected = i == fontID;

                    if (GlamourUI.settings.font ~= fontdir[i] and imgui.Selectable(fontdir[i], is_selected))then
                        fontID = i;
                        GlamourUI.settings.font = fontdir[i];
                        gResources.loadFont(GlamourUI.settings.font);
                    end
                    if(is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end

            imgui.Text('');
            imgui.SetCursorPosX(225);
            if(imgui.Button('Close##GlamConf'))then
                conf.is_open = false;
            end
            imgui.End();
        end
    end

    if(plLEditor == true)then
        imgui.SetNextWindowSize({465, 765});
        if(imgui.Begin('LayoutEditor##Glam', plLEditor, bit.bor(ImGuiWindowFlags_NoDecoration)))then
            imgui.SetWindowFontScale(0.3);
            local priority = gParty.layout.Priority;
            local nPos = T{
                x = {gParty.layout.NamePosition.x},
                y = {gParty.layout.NamePosition.y}
            };
            local hpB = T{
                x = {gParty.layout.HPBarPosition.x},
                y = {gParty.layout.HPBarPosition.y},
                textx = {gParty.layout.HPBarPosition.textX},
                texty = {gParty.layout.HPBarPosition.textY},
                l = {gParty.layout.hpBarDim.l},
                g = {gParty.layout.hpBarDim.g},
            };
            local mpB = T{
                x = {gParty.layout.MPBarPosition.x},
                y = {gParty.layout.MPBarPosition.y},
                textx = {gParty.layout.MPBarPosition.textX},
                texty = {gParty.layout.MPBarPosition.textY},
                l = {gParty.layout.mpBarDim.l},
                g = {gParty.layout.mpBarDim.g},
            };
            local tpB = T{
                x = {gParty.layout.TPBarPosition.x},
                y = {gParty.layout.TPBarPosition.y},
                textx = {gParty.layout.TPBarPosition.textX},
                texty = {gParty.layout.TPBarPosition.textY},
                l = {gParty.layout.tpBarDim.l},
                g = {gParty.layout.tpBarDim.g},
            };
            local buffPos = T{
                x = {gParty.layout.BuffPos.x},
                y = {gParty.layout.BuffPos.y}
            }

            imgui.Text('Layout Editor');
            imgui.BeginChild('Name##GlamPList', {450, 75}, true);

            --Name Layout and Dimensions
            imgui.Text('Name');
            imgui.SliderInt("X##GlamNamePos", nPos.x, 0, 700);
            if(gParty.layout.NamePosition.x ~= nPos.x[1])then
                gParty.layout.NamePosition.x = nPos.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamNamePos', ImGuiDir_Left))then
                gParty.layout.NamePosition.x = gParty.layout.NamePosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamNamePos', ImGuiDir_Right))then
                gParty.layout.NamePosition.x = gParty.layout.NamePosition.x + 1;
            end
            imgui.SliderInt("Y##GlamNamePos", nPos.y, 0, 100);
            if(gParty.layout.NamePosition.y ~= nPos.y[1])then
                gParty.layout.NamePosition.y = nPos.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('nYleft', ImGuiDir_Up))then
                gParty.layout.NamePosition.y = gParty.layout.NamePosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('nYright', ImGuiDir_Down))then
                gParty.layout.NamePosition.y = gParty.layout.NamePosition.y + 1;
            end
            imgui.EndChild();

            --HP Bar Layout and Dimensions
            imgui.BeginChild('layoutHP##GlamPList', {450, 175}, true);
            imgui.Text('HP Bar');
            imgui.SliderInt("X##GlamHPPos", hpB.x, 0, 700);
            if(gParty.layout.HPBarPosition.x ~= hpB.x[1])then
                gParty.layout.HPBarPosition.x = hpB.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamHPPos', ImGuiDir_Left))then
                gParty.layout.HPBarPosition.x = gParty.layout.HPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamHPPos', ImGuiDir_Right))then
                gParty.layout.HPBarPosition.x = gParty.layout.HPBarPosition.x + 1;
            end
            imgui.SliderInt("Y##GlamHPPos", hpB.y, 0, 100);
            if(gParty.layout.HPBarPosition.y ~= hpB.y[1])then
                gParty.layout.HPBarPosition.y = hpB.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Yleft##GlamHPPos', ImGuiDir_Up))then
                gParty.layout.HPBarPosition.y = gParty.layout.HPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Yright##GlamHPPos', ImGuiDir_Down))then
                gParty.layout.HPBarPosition.y = gParty.layout.HPBarPosition.y + 1;
            end
            imgui.SliderInt('HP Text X##GlamHPPos', hpB.textx, 0, 700);
            if(gParty.layout.HPBarPosition.textX ~= hpB.textx[1])then
                gParty.layout.HPBarPosition.textX = hpB.textx[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('txleft##GlamHPPos', ImGuiDir_Left))then
                gParty.layout.HPBarPosition.textX = gParty.layout.HPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('txright##GlamHPPos', ImGuiDir_Right))then
                gParty.layout.HPBarPosition.textX = gParty.layout.HPBarPosition.textX + 1
            end
            imgui.SliderInt('HP Text Y##GlamHPPos', hpB.texty, 0, 100);
            if(gParty.layout.HPBarPosition.textY ~= hpB.texty[1])then
                gParty.layout.HPBarPosition.textY = hpB.texty[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('tyUp##GlamHPPos', ImGuiDir_Up))then
                gParty.layout.HPBarPosition.textY = gParty.layout.HPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tyDown##GlamHPPos', ImGuiDir_Down))then
                gParty.layout.HPBarPosition.textY = gParty.layout.HPBarPosition.textY + 1
            end
            imgui.SliderInt("Length##GlamHPPos", hpB.l, 0, 700);
            if(gParty.layout.hpBarDim.l ~= hpB.l[1])then
                gParty.layout.hpBarDim.l = hpB.l[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('lleft##GlamHPPos', ImGuiDir_Left))then
                gParty.layout.hpBarDim.l = gParty.layout.hpBarDim.l - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('lright##GlamHPPos', ImGuiDir_Right))then
                gParty.layout.hpBarDim.l = gParty.layout.hpBarDim.l + 1;
            end
            imgui.SliderInt("Girth##GlamHPPos", hpB.g, 0, 100);
            if(gParty.layout.hpBarDim.g ~= hpB.g[1])then
                gParty.layout.hpBarDim.g = hpB.g[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('gleft##GlamHPPos', ImGuiDir_Up))then
                gParty.layout.hpBarDim.g = gParty.layout.hpBarDim.g - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('gright##GlamHPPos', ImGuiDir_Down))then
                gParty.layout.hpBarDim.g = gParty.layout.hpBarDim.g + 1;
            end
            imgui.EndChild();

            --MP Bar Layout and Dimensions
            imgui.BeginChild('layoutMP##GlamPList', {450, 175}, true);
            imgui.Text('MP Bar');
            imgui.SliderInt("X##GlamMPPos", mpB.x, 0, 700);
            if(gParty.layout.MPBarPosition.x ~= mpB.x[1])then
                gParty.layout.MPBarPosition.x = mpB.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamMPPos', ImGuiDir_Left))then
                gParty.layout.MPBarPosition.x = gParty.layout.MPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamMPPos', ImGuiDir_Right))then
                gParty.layout.MPBarPosition.x = gParty.layout.MPBarPosition.x + 1;
            end
            imgui.SliderInt("Y##GlamMPPos", mpB.y, 0, 100);
            if(gParty.layout.MPBarPosition.y ~= mpB.y[1])then
                gParty.layout.MPBarPosition.y = mpB.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Yleft##GlamMPPos', ImGuiDir_Up))then
                gParty.layout.MPBarPosition.y = gParty.layout.MPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Yright##GlamMPPos', ImGuiDir_Down))then
                gParty.layout.MPBarPosition.y = gParty.layout.MPBarPosition.y + 1;
            end
            imgui.SliderInt('MP Text X##GlamMPPos', mpB.textx, 0, 700);
            if(gParty.layout.MPBarPosition.textX ~= mpB.textx[1])then
                gParty.layout.MPBarPosition.textX = mpB.textx[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('txleft##GlamMPPos', ImGuiDir_Left))then
                gParty.layout.MPBarPosition.textX = gParty.layout.MPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('txright##GlamMPPos', ImGuiDir_Right))then
                gParty.layout.MPBarPosition.textX = gParty.layout.MPBarPosition.textX + 1
            end
            imgui.SliderInt('MP Text Y##GlamMPPos', mpB.texty, 0, 100);
            if(gParty.layout.MPBarPosition.textY ~= mpB.texty[1])then
                gParty.layout.MPBarPosition.textY = mpB.texty[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('tyUp##GlamMPPos', ImGuiDir_Up))then
                gParty.layout.MPBarPosition.textY = gParty.layout.MPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tyDown##GlamMPPos', ImGuiDir_Down))then
                gParty.layout.MPBarPosition.textY = gParty.layout.MPBarPosition.textY + 1
            end
            imgui.SliderInt("Length##GlamMPPos", mpB.l, 0, 700);
            if(gParty.layout.mpBarDim.l ~= mpB.l[1])then
                gParty.layout.mpBarDim.l = mpB.l[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('lleft##GlamMPPos', ImGuiDir_Left))then
                gParty.layout.mpBarDim.l = gParty.layout.mpBarDim.l - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('lright##GlamMPPos', ImGuiDir_Right))then
                gParty.layout.mpBarDim.l = gParty.layout.mpBarDim.l + 1;
            end
            imgui.SliderInt("Girth##GlamMPPos", mpB.g, 0, 100);
            if(gParty.layout.mpBarDim.g ~= mpB.g[1])then
                gParty.layout.mpBarDim.g = mpB.g[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('gleft##GlamMPPos', ImGuiDir_Up))then
                gParty.layout.mpBarDim.g = gParty.layout.mpBarDim.g - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('gright##GlamMPPos', ImGuiDir_Down))then
                gParty.layout.mpBarDim.g = gParty.layout.mpBarDim.g + 1;
            end
            imgui.EndChild();

            --TP Bar Layout and Dimensions
            imgui.BeginChild('layoutTP##GlamPList', {450, 175}, true);
            imgui.Text('TP Bar');
            imgui.SliderInt("X##GlamTPPos", tpB.x, 0, 700);
            if(gParty.layout.TPBarPosition.x ~= tpB.x[1])then
                gParty.layout.TPBarPosition.x = tpB.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamTPPos', ImGuiDir_Left))then
                gParty.layout.TPBarPosition.x = gParty.layout.TPBarPosition.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamTPPos', ImGuiDir_Right))then
                gParty.layout.TPBarPosition.x = gParty.layout.TPBarPosition.x + 1;
            end
            imgui.SliderInt("Y##GlamTPPos", tpB.y, 0, 100);
            if(gParty.layout.TPBarPosition.y ~= tpB.y[1])then
                gParty.layout.TPBarPosition.y = tpB.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Yleft##GlamTPPos', ImGuiDir_Up))then
                gParty.layout.TPBarPosition.y = gParty.layout.TPBarPosition.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Yright##GlamTPPos', ImGuiDir_Down))then
                gParty.layout.TPBarPosition.y = gParty.layout.TPBarPosition.y + 1;
            end
            imgui.SliderInt('TP Text X##GlamTPPos', tpB.textx, 0, 700);
            if(gParty.layout.TPBarPosition.textX ~= tpB.textx[1])then
                gParty.layout.TPBarPosition.textX = tpB.textx[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('txleft##GlamTPPos', ImGuiDir_Left))then
                gParty.layout.TPBarPosition.textX = gParty.layout.TPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('txright##GlamTPPos', ImGuiDir_Right))then
                gParty.layout.TPBarPosition.textX = gParty.layout.TPBarPosition.textX + 1
            end
            imgui.SliderInt('TP Text Y##GlamTPPos', tpB.texty, 0, 100);
            if(gParty.layout.TPBarPosition.textY ~= tpB.texty[1])then
                gParty.layout.TPBarPosition.textY = tpB.texty[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('tyUp##GlamTPPos', ImGuiDir_Up))then
                gParty.layout.TPBarPosition.textY = gParty.layout.TPBarPosition.textX -1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('tyDown##GlamTPPos', ImGuiDir_Down))then
                gParty.layout.TPBarPosition.textY = gParty.layout.TPBarPosition.textY + 1
            end
            imgui.SliderInt("Length##GlamTPPos", tpB.l, 0, 700);
            if(gParty.layout.tpBarDim.l ~= tpB.l[1])then
                gParty.layout.tpBarDim.l = tpB.l[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('lleft##GlamTPPos', ImGuiDir_Left))then
                gParty.layout.tpBarDim.l = gParty.layout.tpBarDim.l - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('lright##GlamTPPos', ImGuiDir_Right))then
                gParty.layout.tpBarDim.l = gParty.layout.tpBarDim.l + 1;
            end
            imgui.SliderInt("Girth##GlamTPPos", tpB.g, 0, 100);
            if(gParty.layout.tpBarDim.g ~= tpB.g[1])then
                gParty.layout.tpBarDim.g = tpB.g[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('gleft##GlamTPPos', ImGuiDir_Up))then
                gParty.layout.tpBarDim.g = gParty.layout.tpBarDim.g - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('gright##GlamTPPos', ImGuiDir_Down))then
                gParty.layout.tpBarDim.g = gParty.layout.tpBarDim.g + 1;
            end
            imgui.EndChild();
            
            --BuffPosition
            imgui.BeginChild('BuffPosition##GlamBPos', { 450, 75 }, true);
            imgui.Text('Buff Position');
            imgui.SliderInt("X##GlamBuffPos", buffPos.x, 0, 700);
            if(gParty.layout.BuffPos.x ~= buffPos.x[1])then
                gParty.layout.BuffPos.x = buffPos.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamBuffPos', ImGuiDir_Left))then
                gParty.layout.BuffPos.x = gParty.layout.BuffPos.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamBuffPos', ImGuiDir_Right))then
                gParty.layout.BuffPos.x = gParty.layout.BuffPos.x + 1;
            end
            imgui.SliderInt("Y##GlamBuffPos", buffPos.y, 0, 100);
            if(gParty.layout.BuffPos.y ~= buffPos.y[1])then
                gParty.layout.BuffPos.y = buffPos.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Yleft##GlamBuffPos', ImGuiDir_Up))then
                gParty.layout.BuffPos.y = gParty.layout.BuffPos.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Yright##GlamBuffPos', ImGuiDir_Down))then
                gParty.layout.BuffPos.y = gParty.layout.BuffPos.y + 1;
            end
            imgui.EndChild();

            --Padding
            imgui.SliderInt("Padding##GlamBuffPos", {gParty.layout.padding}, 0, 100);
            --[[if(gParty.layout.Padding ~= buffPos.y[1])then
                gParty.layout.Padding = buffPos.y[1];
            end]]
            imgui.SameLine();
            imgui.SetCursorPosX(394);
            if(imgui.ArrowButton('Padleft##GlamBuffPos', ImGuiDir_Up))then
                gParty.layout.padding = gParty.layout.padding - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Padright##GlamBuffPos', ImGuiDir_Down))then
                gParty.layout.padding = gParty.layout.padding + 1;
            end

            imgui.SetCursorPosX(225);
            if(imgui.Button('Close##GlamLayout'))then
                plLEditor = false;
                gHelper.updateLayoutFile(GlamourUI.settings.Party.pList.layout);
            end
            imgui.End();
        end
    end
end

return conf;