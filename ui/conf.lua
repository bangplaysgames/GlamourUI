local imgui = require('imgui')
local ffi = require('ffi')
local scaling = require('scaling')
local settings = require('settings')
local panelStyle = require('panelStyle')
local nativeStatusBlock = require('native_status_block')
local font_manager = require('font_manager')

local function glam_custom_chat_windows_active()
    if (GlamourUI ~= nil and GlamourUI.is_custom_chat_windows_enabled ~= nil) then
        return GlamourUI.is_custom_chat_windows_enabled() == true;
    end
    local chat = GlamourUI and GlamourUI.settings and GlamourUI.settings.Chat;
    if (chat == nil or chat.enabled ~= true) then
        return false;
    end
    return (chat.window1 ~= nil and chat.window1.enabled == true)
        or (chat.window2 ~= nil and chat.window2.enabled == true);
end

local function glam_notify_custom_chat_status_if_changed(beforeActive)
    if (GlamourUI == nil or GlamourUI.broadcast_custom_chat_status == nil) then
        return;
    end
    if (beforeActive ~= glam_custom_chat_windows_active()) then
        GlamourUI.broadcast_custom_chat_status();
    end
end

local function getThemeID(theme)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    if (dir == nil) then return; end
    for i = 1,#dir,1 do
        if(dir[i] == theme) then
            return i;
        end
    end
end

local function getLayoutID(layout)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\'):fmt(AshitaCore:GetInstallPath()));
    if (dir == nil) then return; end
    for i = 1,#dir,1 do
        if(dir[i] == layout) then
            return i;
        end
    end
end

local function getFontID(font, fontList)
    fontList = fontList or (configDirs ~= nil and configDirs.fonts) or T{};
    for i = 1, #fontList, 1 do
        if (fontList[i] == font) then
            return i;
        end
    end
end

local function font_combo_label(name, shiftJisOnly)
    if (not shiftJisOnly) then
        return name;
    end
    if (font_manager.supports_shift_jis(name)) then
        return name;
    end
    return ('%s (not Shift-JIS)'):fmt(name);
end

local function render_font_combo(comboId, selectedFont, onSelect, opts)
    opts = opts or {};
    local shiftJisOnly = opts.shift_jis_only == true;
    if (#font_manager.get_all_font_names() == 0) then
        refresh_config_dirs();
    end
    if (gResources.update_shift_jis_font_list ~= nil) then
        gResources.update_shift_jis_font_list();
    end
    local fontList = shiftJisOnly and font_manager.get_shift_jis_font_names() or font_manager.get_all_font_names();
    if (fontList == nil) then
        fontList = T{};
    end
    if (shiftJisOnly and #fontList == 0 and configDirs.fonts ~= nil and #configDirs.fonts > 0) then
        fontList = configDirs.fonts;
    end

    local display = selectedFont;
    if (display == nil or display == '') then
        display = '(Default)';
    end

    if (not imgui.BeginCombo(comboId, display, combo_flags)) then
        return;
    end

    if (opts.allow_default ~= false) then
        if (imgui.Selectable(('(Default)##%sDef'):fmt(comboId), selectedFont == nil or selectedFont == '')) then
            onSelect('');
        end
    end

    local itemIndex = 0;
    for _, name in ipairs(fontList) do
        itemIndex = itemIndex + 1;
        local isSelected = (selectedFont == name);
        local label = font_combo_label(name, shiftJisOnly);
        if (imgui.Selectable(('%s##%s%d'):fmt(label, comboId, itemIndex), isSelected)) then
            onSelect(name);
        end
        if (isSelected) then
            imgui.SetItemDefaultFocus();
        end
    end

    imgui.EndCombo();

    if (shiftJisOnly) then
        imgui.TextDisabled('Lists fonts that support Japanese chat glyphs (CP932 / ImGui probe).');
    end
end

local function getBuffID(buff)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\%s\\icons\\'):fmt(AshitaCore:GetInstallPath(), addon.name));
    if (dir == nil) then return; end
    for i = 1,#dir,1 do
        if(dir[i] == buff)then
            return i;
        end
    end
end

local configDirs = {
    themes = T{},
    layouts = T{},
    buffs = T{},
    fonts = T{},
};

local themeID = T{ getThemeID('Default')};
local layoutID = T{ getLayoutID('Default')};
local fontID = T{ getFontID('Default') or 1 };
local buffID = T{ getBuffID('Default')};
local plLEditor = false;
local configWasOpen = false;

local confFooterHeight = 40;

local conf = {};

conf.is_open = false;
conf.selected_tab = 'General';

local CONFIG_CONTENT_MIN_W = 520;
local CONFIG_CONTENT_MIN_H = 520;
local CONFIG_TITLE = 'Glamour UI Configuration';

-- Approximate content body heights at 1080p before header/footer and scaleH.
local CONFIG_CONTENT_HEIGHTS = {
    General = 430,
    PartyList = 500,
    Alliance = 360,
    TargetBar = 360,
    PlayerStats = 540,
    Inventory = 260,
    Recast = 360,
    Chat = 940,
    CastBar = 340,
    Compass = 360,
    Environment = 360,
    Toasts = 480,
    CombatToasts = 480,
};

local function conf_calc_text_size(text)
    local tw, th = imgui.CalcTextSize(tostring(text or ''));
    if (type(tw) == 'table') then
        th = tonumber(tw[2]) or tonumber(tw.y) or 0;
        tw = tonumber(tw[1]) or tonumber(tw.x) or 0;
    end
    return tonumber(tw) or 0, tonumber(th) or 0;
end

local function conf_tab_button_width(label)
    local style = imgui.GetStyle();
    local framePadX = (tonumber(style.FramePadding.x) or 4) * 2;
    local tw = conf_calc_text_size(label);
    return math.ceil(tw + framePadX + 12);
end

local function tab_button(label, id, isSelected)
    if (isSelected) then
        imgui.PushStyleColor(ImGuiCol_Button, { 0.20, 0.55, 0.95, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.25, 0.60, 1.0, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.18, 0.50, 0.90, 1.0 });
    end
    local clicked = imgui.Button(('%s##Tab%s'):fmt(label, id));
    if (isSelected) then
        imgui.PopStyleColor(3);
    end
    return clicked;
end

local function conf_build_tabs()
    return T{
        { id = 'General', label = 'General', show = true },
        { id = 'PartyList', label = 'Party List', show = GlamourUI.settings.Party.pList.enabled == true },
        { id = 'Alliance', label = 'Alliance', show = GlamourUI.settings.Party.aPanel.enabled == true },
        { id = 'TargetBar', label = 'Target Bar', show = GlamourUI.settings.TargetBar.enabled == true },
        { id = 'PlayerStats', label = 'Player Stats', show = GlamourUI.settings.PlayerStats.enabled == true },
        { id = 'Inventory', label = 'Inventory', show = GlamourUI.settings.Inv.enabled == true },
        { id = 'Recast', label = 'Recast', show = GlamourUI.settings.rcPanel.enabled == true },
        { id = 'Chat', label = 'Chat', show = GlamourUI.settings.Chat.enabled == true },
        { id = 'CastBar', label = 'Cast Bar', show = GlamourUI.settings.cBar.enabled == true },
        { id = 'Compass', label = 'Compass', show = GlamourUI.settings.Compass ~= nil and GlamourUI.settings.Compass.enabled == true },
        { id = 'Environment', label = 'Environment', show = true },
        { id = 'Toasts', label = 'Toasts', show = GlamourUI.settings.Toasts ~= nil and GlamourUI.settings.Toasts.enabled == true },
        { id = 'CombatToasts', label = 'Combat Toasts', show = GlamourUI.settings.CombatToasts ~= nil and GlamourUI.settings.CombatToasts.enabled == true },
        { id = 'Parse', label = 'Combat Parser', show = true },
    };
end

local function conf_measure_tab_bar(tabs, rowWidth)
    rowWidth = math.max(200, tonumber(rowWidth) or 600);
    local style = imgui.GetStyle();
    local itemSpacingX = tonumber(style.ItemSpacing.x) or 8;
    local itemSpacingY = tonumber(style.ItemSpacing.y) or 4;
    local _, tabBtnH = conf_calc_text_size('Ay');
    tabBtnH = math.max(22, tabBtnH + (tonumber(style.FramePadding.y) or 4) * 2);

    local widths = {};
    local visible = 0;
    for i = 1, #tabs do
        if (tabs[i].show) then
            visible = visible + 1;
            widths[#widths + 1] = conf_tab_button_width(tabs[i].label);
        end
    end

    if (visible == 0) then
        return 0, 1, tabBtnH;
    end

    local rows = 1;
    local rowUsed = 0;
    local widestRow = 0;
    for i = 1, #widths do
        local w = widths[i];
        local gap = (rowUsed > 0) and itemSpacingX or 0;
        if (rowUsed > 0 and (rowUsed + gap + w) > rowWidth) then
            rows = rows + 1;
            widestRow = math.max(widestRow, rowUsed);
            rowUsed = w;
        else
            rowUsed = rowUsed + gap + w;
        end
    end
    widestRow = math.max(widestRow, rowUsed);

    local totalW = widestRow;
    if (rows == 1) then
        totalW = rowUsed;
    end
    return totalW, rows, tabBtnH + (rows - 1) * (tabBtnH + itemSpacingY);
end

local function conf_render_tab_bar(tabs, rowWidth)
    rowWidth = math.max(200, tonumber(rowWidth) or 600);
    local style = imgui.GetStyle();
    local itemSpacingX = tonumber(style.ItemSpacing.x) or 8;
    local itemSpacingY = tonumber(style.ItemSpacing.y) or 4;
    local _, lineH = conf_calc_text_size('Ay');
    local tabBtnH = math.max(22, lineH + (tonumber(style.FramePadding.y) or 4) * 2);
    local startX, startY = imgui.GetCursorPos();
    local rowY = startY;
    local rowUsed = 0;
    local firstInRow = true;

    for i = 1, #tabs do
        if (tabs[i].show) then
            local btnW = conf_tab_button_width(tabs[i].label);
            local gap = firstInRow and 0 or itemSpacingX;
            if (not firstInRow and (rowUsed + gap + btnW) > rowWidth) then
                rowY = rowY + tabBtnH + itemSpacingY;
                imgui.SetCursorPos({ startX, rowY });
                imgui.Dummy({ 1, 1 });
                rowUsed = 0;
                firstInRow = true;
                gap = 0;
            end

            if (not firstInRow) then
                imgui.SameLine(0, itemSpacingX);
            end
            firstInRow = false;
            rowUsed = rowUsed + gap + btnW;

            local isSel = conf.selected_tab == tabs[i].id;
            if (tab_button(tabs[i].label, tabs[i].id, isSel)) then
                conf.selected_tab = tabs[i].id;
            end
        end
    end

    imgui.SetCursorPos({ startX, rowY + tabBtnH + 4 });
    imgui.Dummy({ 1, 1 });
end

local function conf_calc_window_size(tabs, selectedTab, scaleW, scaleH, screenW, screenH)
    local titleW = conf_calc_text_size(CONFIG_TITLE) + 48;
    local probeRowW = math.floor(900 * scaleW);
    local tabBarW, tabRows, tabBarH = conf_measure_tab_bar(tabs, probeRowW);

    local contentH = CONFIG_CONTENT_HEIGHTS[selectedTab] or 520;
    local baseHeaderExtra = 42;
    local headerH = math.max(55, math.floor((baseHeaderExtra + tabBarH) * scaleH));
    local footerH = math.max(40, math.floor(55 * scaleH));

    local confW = math.max(CONFIG_CONTENT_MIN_W, math.floor(600 * scaleW), titleW, tabBarW + 40);
    local confH = headerH + footerH + math.floor(contentH * scaleH);

    local maxW = math.max(CONFIG_CONTENT_MIN_W, screenW - 48);
    local maxH = math.max(CONFIG_CONTENT_MIN_H, screenH - 48);
    confW = math.min(confW, maxW);
    confH = math.min(confH, maxH);

    if (tabBarW + 40 > confW) then
        tabBarW, tabRows, tabBarH = conf_measure_tab_bar(tabs, confW - 40);
        headerH = math.max(55, math.floor((baseHeaderExtra + tabBarH) * scaleH));
        confH = headerH + footerH + math.floor(contentH * scaleH);
        confH = math.min(confH, maxH);
    end

    confW = math.max(CONFIG_CONTENT_MIN_W, confW);
    confH = math.max(CONFIG_CONTENT_MIN_H, confH);
    return confW, confH, headerH, footerH;
end

local function conf_content_avail_x()
    local a = imgui.GetContentRegionAvail();
    if (type(a) == 'number') then
        return math.max(1, a);
    end
    if (type(a) == 'table') then
        local x = tonumber(a[1]) or tonumber(a.x);
        if (x ~= nil) then
            return math.max(1, x);
        end
    end
    return 400;
end

local conf_slider_arrow_pair_reserve = 78;

local function build_chat_input_panel_style_holder(chatSettings)
    return {
        panelBackgroundEnabled = chatSettings.inputPanelBackgroundEnabled,
        panelBackground = chatSettings.inputPanelBackground,
        panelRounding = chatSettings.inputPanelRounding,
        panelPaddingX = chatSettings.inputPanelPaddingX,
        panelPaddingY = chatSettings.inputPanelPaddingY,
        panelBorderSize = chatSettings.inputPanelBorderSize,
    };
end

local function save_chat_input_panel_style_holder(chatSettings, holder)
    chatSettings.inputPanelBackgroundEnabled = holder.panelBackgroundEnabled;
    chatSettings.inputPanelBackground = holder.panelBackground;
    chatSettings.inputPanelRounding = holder.panelRounding;
    chatSettings.inputPanelPaddingX = holder.panelPaddingX;
    chatSettings.inputPanelPaddingY = holder.panelPaddingY;
    chatSettings.inputPanelBorderSize = holder.panelBorderSize;
end

local render_toggle = nil;
local render_float_setting = nil;
local render_panel_background_controls = nil;
local render_selection_combo = nil;
local render_dimension_controls = nil;
local render_chat_color_swatch = nil;
local render_chat_code_color_swatch = nil;

local function ensure_chat_purpose_color(chatSettings, purpose)
    local colors = chatSettings.purposeColors;
    if (colors[purpose] == nil) then
        colors[purpose] = { 1.0, 1.0, 1.0, 1.0 };
    end
    return colors[purpose];
end

local function render_general_contents()
    imgui.Text('General');
    imgui.Separator();

    GlamourUI.settings.Party.pList.enabled = select(1, render_toggle('Enable Party List##GlamEnable', GlamourUI.settings.Party.pList.enabled == true));
    GlamourUI.settings.Party.aPanel.enabled = select(1, render_toggle('Enable Alliance Panel##GlamEnable', GlamourUI.settings.Party.aPanel.enabled == true));
    GlamourUI.settings.TargetBar.enabled = select(1, render_toggle('Enable Target Bar##GlamEnable', GlamourUI.settings.TargetBar.enabled == true));
    GlamourUI.settings.PlayerStats.enabled = select(1, render_toggle('Enable Player Stats##GlamEnable', GlamourUI.settings.PlayerStats.enabled == true));
    GlamourUI.settings.Inv.enabled = select(1, render_toggle('Enable Inventory Panel##GlamEnable', GlamourUI.settings.Inv.enabled == true));
    GlamourUI.settings.rcPanel.enabled = select(1, render_toggle('Enable Recast Panel##GlamEnable', GlamourUI.settings.rcPanel.enabled == true));
    local chatActivePrev = glam_custom_chat_windows_active();
    GlamourUI.settings.Chat.enabled = select(1, render_toggle('Enable Chat Logs##GlamEnable', GlamourUI.settings.Chat.enabled == true));
    glam_notify_custom_chat_status_if_changed(chatActivePrev);
    GlamourUI.settings.cBar.enabled = select(1, render_toggle('Enable Cast Bar##GlamEnable', GlamourUI.settings.cBar.enabled == true));
    GlamourUI.settings.Compass.enabled = select(1, render_toggle('Enable Heading Compass##GlamEnable', GlamourUI.settings.Compass.enabled == true));

    imgui.Separator();
    imgui.Text('Default Font');
    render_font_combo('DefaultFont##GlamConfGen', GlamourUI.settings.font, function(name)
        GlamourUI.settings.font = name;
        fontID = T{ getFontID(name) or 1 };
        gResources.loadFont(name);
        gResources.preload_configured_fonts(GlamourUI.settings);
    end, { allow_default = false });
    imgui.TextDisabled('Panels use their own font when set; otherwise this default is used.');

    imgui.Separator();
    imgui.Text('Packet Injection');
    local injOn = GlamourUI.settings.packet_injection_enabled == true;
    GlamourUI.settings.packet_injection_enabled = select(1, render_toggle('Enable Packet Injection Mode##GlamConfInject', injOn));
    imgui.PushTextWrapPos(imgui.GetCursorPosX() + math.max(200, conf_content_avail_x()));
    imgui.TextDisabled('Enables outgoing widescan requests to discover mob levels. Buff cancel and treasure lot/pass are always allowed. Confirm with your server staff before enabling.');
    imgui.PopTextWrapPos();
end

local function render_party_list_contents()
    imgui.Text('Party List');
    imgui.Separator();

    GlamourUI.settings.Party.pList.themed = select(1, render_toggle('Themed##Plist', GlamourUI.settings.Party.pList.themed));

    imgui.SameLine();
    imgui.SetCursorPosX(250);
    local dragEnabled, dragChanged = render_toggle('EnableDrag##Plist', GlamourUI.PartyList.Drag);
    if(dragChanged)then
        gParty.update_pos();
        GlamourUI.PartyList.Drag = dragEnabled;
    end

    render_selection_combo('Theme##PList', GlamourUI.settings.Party.pList.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.Party.pList.theme = themeName;
    end);

    local layoutEditorBtnW = 132;
    local layoutRowGap = 8;
    imgui.PushItemWidth(math.max(160, conf_content_avail_x() - layoutEditorBtnW - layoutRowGap));
    render_selection_combo('Layout##PList', GlamourUI.settings.Party.pList.layout, configDirs.layouts, layoutID, function(layoutName)
        GlamourUI.settings.Party.pList.layout = layoutName;
        gHelper.loadLayout(layoutName);
    end);
    imgui.PopItemWidth();
    imgui.SameLine(0, layoutRowGap);
    if (imgui.Button('Layout Editor##GlamPList', { layoutEditorBtnW, 0 })) then
        plLEditor = not plLEditor;
    end

    render_selection_combo('Buff Theme##PList', GlamourUI.settings.Party.pList.buffTheme, configDirs.buffs, buffID, function(buffTheme)
        GlamourUI.settings.Party.pList.buffTheme = buffTheme;
    end);

    GlamourUI.settings.Party.pList.gui_scale = render_float_setting('GuiScale##GlamPList', GlamourUI.settings.Party.pList.gui_scale, 0.1, 5.0, '%.1f');
    GlamourUI.settings.Party.pList.buff_gui_scale = render_float_setting(
        'Buff icon scale##GlamPList',
        GlamourUI.settings.Party.pList.buff_gui_scale or GlamourUI.settings.Party.pList.gui_scale or 1,
        0.1,
        5.0,
        '%.1f'
    );
    GlamourUI.settings.Party.pList.font_scale = render_float_setting('FontScale##GlamPList', GlamourUI.settings.Party.pList.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamPList', GlamourUI.settings.Party.pList.font or '', function(name)
        GlamourUI.settings.Party.pList.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);
    GlamourUI.settings.Party.pList.FillDown = select(1, render_toggle('Fill Down##Plist', GlamourUI.settings.Party.pList.FillDown));

    imgui.Separator();
    imgui.Text('Buff UI');
    GlamourUI.settings.Party.pList.hideDefault = select(1, render_toggle('Hide Default Party List##Plist', GlamourUI.settings.Party.pList.hideDefault));
    local hideNativeNew, hideNativeChanged = render_toggle('Hide Native Status Icons##Plist', GlamourUI.settings.Party.pList.hideNativeStatusIcons == true);
    GlamourUI.settings.Party.pList.hideNativeStatusIcons = hideNativeNew;
    if (hideNativeChanged) then
        if (hideNativeNew) then
            nativeStatusBlock.apply();
        else
            nativeStatusBlock.remove();
        end
    end
    GlamourUI.settings.Party.pList.highlightSelectedBuff = select(1, render_toggle('Highlight Selected Buff##Plist', GlamourUI.settings.Party.pList.highlightSelectedBuff ~= false));

    imgui.Separator();
    render_panel_background_controls('PartyListPB', GlamourUI.settings.Party.pList);
end

local function render_standard_themed_contents(childId, settingsTable, scaleLabels, dimensions, dimensionPrefix)
    settingsTable.themed = select(1, render_toggle(('Themed##%s'):fmt(childId), settingsTable.themed));
    render_selection_combo(('Theme##%s'):fmt(childId), settingsTable.theme, configDirs.themes, themeID, function(themeName)
        settingsTable.theme = themeName;
    end);

    settingsTable.gui_scale = render_float_setting(scaleLabels.gui, settingsTable.gui_scale, 0.1, 5.0, '%.1f');
    settingsTable.font_scale = render_float_setting(scaleLabels.font, settingsTable.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo(('Font##%s'):fmt(childId), settingsTable.font or '', function(name)
        settingsTable.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);

    if(dimensions ~= nil)then
        render_dimension_controls(dimensionPrefix, dimensions);
    end

    imgui.Separator();
    render_panel_background_controls(childId .. 'PB', settingsTable);
end

local function render_inventory_contents()
    render_selection_combo('Theme##GlamInvPanel', GlamourUI.settings.Inv.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.Inv.theme = themeName;
    end);
    GlamourUI.settings.Inv.font_scale = render_float_setting('FontScale##GlamInvPanel', GlamourUI.settings.Inv.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamInvPanel', GlamourUI.settings.Inv.font or '', function(name)
        GlamourUI.settings.Inv.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);
    imgui.Separator();
    render_panel_background_controls('InvPanelPB', GlamourUI.settings.Inv);
end

local function render_recast_contents()
    render_standard_themed_contents(
        'RecastPanel##GlamConf',
        GlamourUI.settings.rcPanel,
        {
            gui = 'GuiScale##GlamRecastPanel',
            font = 'FontScale##GlamRecastPanel',
        }
    );
end

local TOAST_TRIGGER_PURPOSES = T{ 'Spoils', 'Experience', 'Limit Points', 'Capacity Points', 'PartyInvite', 'TradeRequest' };

local function render_toasts_contents()
    local s = GlamourUI.settings.Toasts;
    s.enabled = select(1, render_toggle('Enable Toasts##GlamToasts', s.enabled == true));
    imgui.TextDisabled('Pops up when you obtain EXP, Limit Points, Capacity Points, items, or gil.');
    if (s.enabled ~= true) then
        return;
    end

    s.duration = render_float_setting('Duration (sec)##GlamToasts', tonumber(s.duration) or 10.0, 1.0, 30.0, '%.1f');
    s.slideInDuration = render_float_setting('Slide-in time (sec)##GlamToasts', tonumber(s.slideInDuration) or 0.25, 0.05, 2.0, '%.2f');
    s.fadeOutDuration = render_float_setting('Fade-out time (sec)##GlamToasts', tonumber(s.fadeOutDuration) or 1.5, 0.1, 5.0, '%.1f');
    s.width = math.floor(render_float_setting('Width (px)##GlamToasts', tonumber(s.width) or 320, 120, 800, '%.0f'));
    s.spacing = math.floor(render_float_setting('Spacing (px)##GlamToasts', tonumber(s.spacing) or 8, 0, 40, '%.0f'));
    s.maxStack = math.floor(render_float_setting('Max stacked##GlamToasts', tonumber(s.maxStack) or 5, 1, 10, '%.0f'));
    s.font_scale = render_float_setting('Font Scale##GlamToasts', tonumber(s.font_scale) or 1.0, 0.1, 3.0, '%.1f');
    s.x = render_float_setting('Position X##GlamToasts', tonumber(s.x) or 1550, 0, 3840, '%.0f');
    s.y = render_float_setting('Position Y##GlamToasts', tonumber(s.y) or 60, 0, 2160, '%.0f');
    imgui.TextDisabled('Tip: once a toast finishes sliding in, you can also just drag it -- that becomes the new spot for future toasts.');

    imgui.Separator();
    imgui.Text('Triggers');
    if (s.purposes == nil) then
        s.purposes = T{};
    end
    for i = 1, #TOAST_TRIGGER_PURPOSES do
        local purpose = TOAST_TRIGGER_PURPOSES[i];
        s.purposes[purpose] = select(1, render_toggle(purpose .. '##GlamToastsTrigger', s.purposes[purpose] == true));
    end

    imgui.Separator();
    if (imgui.Button('Test Toast##GlamToasts')) then
        gToasts.push('Spoils', 'Test: You obtain a Test Item from Test Mob.');
    end
    imgui.SameLine();
    if (imgui.Button('Test Item Toast (icon)##GlamToasts')) then
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local testItemId = 0;
        for slot = 0, inv:GetContainerCountMax(0) - 1 do
            local it = inv:GetContainerItem(0, slot);
            if (it ~= nil and it.Id ~= nil and it.Id > 0) then
                testItemId = it.Id;
                break;
            end
        end
        local info = gToasts.resolve_item_info(testItemId);
        gToasts.push('Spoils', ('%s dropped to the treasure pool.'):fmt(info.name), { icon = info.icon, tooltip = info.desc });
    end
    imgui.SameLine();
    if (imgui.Button('Test Trade Toast##GlamToasts')) then
        gToasts.push('TradeRequest', 'Trade request from Testplayer.', { duration = 60.0, key = 'TradeRequest' });
    end

    imgui.Separator();
    render_panel_background_controls('ToastsPB', s);
end

-- Job-specific filter checkboxes (combat_filters). target is the live boolean
-- table for the current job's filter set; edits persist on Save.
local function render_filter_toggles(label, target, keys, labels, idp)
    if (target == nil or keys == nil) then
        return;
    end
    imgui.Text(label);
    for i = 1, #keys do
        local k = keys[i];
        target[k] = select(1, render_toggle((labels[k] or k) .. '##' .. idp .. k, target[k] ~= false));
    end
end

local function render_combat_toasts_contents()
    local s = GlamourUI.settings.CombatToasts;
    s.enabled = select(1, render_toggle('Enable Combat Toasts##GlamCombatToasts', s.enabled == true));
    imgui.TextDisabled('Pops up on alliance member weapon skills, spells, skillchains, and magic bursts.');
    if (s.enabled ~= true) then
        return;
    end

    s.duration = render_float_setting('Duration (sec)##GlamCombatToasts', tonumber(s.duration) or 10.0, 1.0, 30.0, '%.1f');
    s.slideInDuration = render_float_setting('Slide-in time (sec)##GlamCombatToasts', tonumber(s.slideInDuration) or 0.25, 0.05, 2.0, '%.2f');
    s.fadeOutDuration = render_float_setting('Fade-out time (sec)##GlamCombatToasts', tonumber(s.fadeOutDuration) or 1.5, 0.1, 5.0, '%.1f');
    s.width = math.floor(render_float_setting('Width (px)##GlamCombatToasts', tonumber(s.width) or 320, 120, 800, '%.0f'));
    s.spacing = math.floor(render_float_setting('Spacing (px)##GlamCombatToasts', tonumber(s.spacing) or 8, 0, 40, '%.0f'));
    s.maxStack = math.floor(render_float_setting('Max stacked##GlamCombatToasts', tonumber(s.maxStack) or 5, 1, 10, '%.0f'));
    s.font_scale = render_float_setting('Font Scale##GlamCombatToasts', tonumber(s.font_scale) or 1.0, 0.1, 3.0, '%.1f');
    s.x = render_float_setting('Position X##GlamCombatToasts', tonumber(s.x) or 1550, 0, 3840, '%.0f');
    s.y = render_float_setting('Position Y##GlamCombatToasts', tonumber(s.y) or 420, 0, 2160, '%.0f');
    imgui.TextDisabled('Tip: once a toast finishes sliding in, you can also just drag it -- that becomes the new spot for future toasts.');

    imgui.Separator();
    s.showSkillchainPanel = select(1, render_toggle('Show skillchain panel##GlamCombatToasts', s.showSkillchainPanel ~= false));
    imgui.TextDisabled('Shows what YOU could weaponskill with to continue/close a chain off the most recent party weapon skill. Anchored to the right of this toast window.');

    imgui.Separator();
    if (gFilters ~= nil) then
        local set = gFilters.active_set();
        imgui.TextDisabled(('Filters (per job -- current: %s)'):fmt(gFilters.current_job() or '?'));
        render_filter_toggles('Show categories', set.toastCats, gFilters.TOAST_CATS, gFilters.TOAST_CAT_LABELS, 'GlamFCat');
        render_filter_toggles('Show players', set.toastPlayers, gFilters.TOAST_PLAYERS, gFilters.PLAYER_LABELS, 'GlamFTP');
    end

    imgui.Separator();
    imgui.TextDisabled('Test buttons use your current target -- target a mob first to see the skillchain panel populate.');
    if (imgui.Button('Test WS Toast##GlamCombatToasts')) then
        local selfEnt = GetPlayerEntity and GetPlayerEntity() or nil;
        local selfId = selfEnt and selfEnt.ServerId or 0;
        local selfName = (selfEnt and selfEnt.Name and tostring(selfEnt.Name):gsub('%z.*', '')) or 'You';
        local targetIndex = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        local targetEnt = (targetIndex ~= nil and targetIndex ~= 0) and GetEntity(targetIndex) or nil;
        local targetId = targetEnt and targetEnt.ServerId or nil;
        local targetName = (targetEnt and targetEnt.Name and tostring(targetEnt.Name):gsub('%z.*', '')) or 'Test Mob';
        gCombatToasts.handle_combat_event({ kind = 'ws', actorId = selfId, actorName = selfName, abilId = 30, name = 'Aeolian Edge', damage = 1234, targetId = targetId, targetName = targetName });
    end
    imgui.SameLine();
    if (imgui.Button('Test Spell Toast##GlamCombatToasts')) then
        local selfEnt = GetPlayerEntity and GetPlayerEntity() or nil;
        local selfId = selfEnt and selfEnt.ServerId or 0;
        local selfName = (selfEnt and selfEnt.Name and tostring(selfEnt.Name):gsub('%z.*', '')) or 'You';
        local targetIndex = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        local targetEnt = (targetIndex ~= nil and targetIndex ~= 0) and GetEntity(targetIndex) or nil;
        local targetId = targetEnt and targetEnt.ServerId or nil;
        local targetName = (targetEnt and targetEnt.Name and tostring(targetEnt.Name):gsub('%z.*', '')) or 'Test Mob';
        gCombatToasts.handle_combat_event({ kind = 'spell', actorId = selfId, actorName = selfName, abilId = 0, name = 'Thunder IV', damage = 987, damaging = true, targetId = targetId, targetName = targetName });
    end
    imgui.SameLine();
    if (imgui.Button('Test MB Toast##GlamCombatToasts')) then
        local selfEnt = GetPlayerEntity and GetPlayerEntity() or nil;
        local selfId = selfEnt and selfEnt.ServerId or 0;
        local selfName = (selfEnt and selfEnt.Name and tostring(selfEnt.Name):gsub('%z.*', '')) or 'You';
        local targetIndex = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        local targetEnt = (targetIndex ~= nil and targetIndex ~= 0) and GetEntity(targetIndex) or nil;
        local targetId = targetEnt and targetEnt.ServerId or nil;
        local targetName = (targetEnt and targetEnt.Name and tostring(targetEnt.Name):gsub('%z.*', '')) or 'Test Mob';
        gCombatToasts.handle_combat_event({ kind = 'spell', actorId = selfId, actorName = selfName, abilId = 0, name = 'Thunder IV', damage = 4321, damaging = true, magicBurst = true, targetId = targetId, targetName = targetName });
    end
    if (imgui.Button('Test SC Toast##GlamCombatToasts')) then
        local selfEnt = GetPlayerEntity and GetPlayerEntity() or nil;
        local selfId = selfEnt and selfEnt.ServerId or 0;
        local selfName = (selfEnt and selfEnt.Name and tostring(selfEnt.Name):gsub('%z.*', '')) or 'You';
        local targetIndex = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        local targetEnt = (targetIndex ~= nil and targetIndex ~= 0) and GetEntity(targetIndex) or nil;
        local targetId = targetEnt and targetEnt.ServerId or nil;
        local targetName = (targetEnt and targetEnt.Name and tostring(targetEnt.Name):gsub('%z.*', '')) or 'Test Mob';
        gCombatToasts.handle_combat_event({ kind = 'skillchain', actorId = selfId, actorName = selfName, abilId = 30, name = 'Aeolian Edge', skillchainName = 'Fragmentation', damage = 2100, targetId = targetId, targetName = targetName });
    end

    imgui.Separator();
    render_panel_background_controls('CombatToastsPB', s);
end

local function render_pstats_bar_dim_controls(title, dimTable, idSuffix)
    imgui.Text(title);
    local barLength = { dimTable.l };
    local barGirth = { dimTable.g };

    imgui.PushItemWidth(math.max(80, conf_content_avail_x() - conf_slider_arrow_pair_reserve));
    imgui.SliderInt(('Length##GlamPlayerStats%sLen'):fmt(idSuffix), barLength, 0, 700);
    imgui.PopItemWidth();
    dimTable.l = barLength[1];
    imgui.SameLine(0, 6);
    if(imgui.ArrowButton(('lleft##GlamPlayerStats%sLen'):fmt(idSuffix), ImGuiDir_Left))then
        dimTable.l = dimTable.l - 1;
    end
    imgui.SameLine(0, 2);
    if(imgui.ArrowButton(('lright##GlamPlayerStats%sLen'):fmt(idSuffix), ImGuiDir_Right))then
        dimTable.l = dimTable.l + 1;
    end

    imgui.PushItemWidth(math.max(80, conf_content_avail_x() - conf_slider_arrow_pair_reserve));
    imgui.SliderInt(('Girth##GlamPlayerStats%sGir'):fmt(idSuffix), barGirth, 0, 100);
    imgui.PopItemWidth();
    dimTable.g = barGirth[1];
    imgui.SameLine(0, 6);
    if(imgui.ArrowButton(('gleft##GlamPlayerStats%sGir'):fmt(idSuffix), ImGuiDir_Up))then
        dimTable.g = dimTable.g - 1;
    end
    imgui.SameLine(0, 2);
    if(imgui.ArrowButton(('gright##GlamPlayerStats%sGir'):fmt(idSuffix), ImGuiDir_Down))then
        dimTable.g = dimTable.g + 1;
    end
end

local function render_player_stats_contents()
    GlamourUI.settings.PlayerStats.themed = select(1, render_toggle('Themed##GlamPlayerStats', GlamourUI.settings.PlayerStats.themed));

    render_selection_combo('Theme##GlamPlayerStats', GlamourUI.settings.PlayerStats.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.PlayerStats.theme = themeName;
    end);

    GlamourUI.settings.PlayerStats.gui_scale = render_float_setting('GuiScale##GlamPlayerStats', GlamourUI.settings.PlayerStats.gui_scale, 0.1, 5.0, '%.1f');
    GlamourUI.settings.PlayerStats.font_scale = render_float_setting('FontScale##GlamPlayerStats', GlamourUI.settings.PlayerStats.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamPlayerStats', GlamourUI.settings.PlayerStats.font or '', function(name)
        GlamourUI.settings.PlayerStats.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);

    if(GlamourUI.settings.PlayerStats.expBarDim == nil)then
        GlamourUI.settings.PlayerStats.expBarDim = { l = 600, g = 14 };
    end
    if(type(GlamourUI.settings.PlayerStats.barPadding) ~= 'number')then
        GlamourUI.settings.PlayerStats.barPadding = 50;
    end

    render_pstats_bar_dim_controls('HP / MP / TP Bar Dimensions', GlamourUI.settings.PlayerStats.BarDim, 'Stat');
    GlamourUI.settings.PlayerStats.barPadding = render_float_setting('Bar Padding##GlamPlayerStatsPad', GlamourUI.settings.PlayerStats.barPadding, 0, 200, '%.0f');
    render_pstats_bar_dim_controls('EXP / CP Bar Dimensions', GlamourUI.settings.PlayerStats.expBarDim, 'Exp');

    imgui.Separator();
    render_panel_background_controls('PlayerStatsPB', GlamourUI.settings.PlayerStats);
end

local function render_chat_logs_contents()
    local chatSettings = GlamourUI.settings.Chat;

    chatSettings.forceNativeChatHidden = select(1, render_toggle('Keep Native Chat Hidden##GlamChatHidden', chatSettings.forceNativeChatHidden));
    chatSettings.persistChatLog = select(1, render_toggle('Persist Chatlog (save last 1000)##GlamChatPersist', chatSettings.persistChatLog == true));
    chatSettings.actionPacket28LegacyHeader = select(1, render_toggle('Force legacy 0x28 header (SimpleLog / DSP)##GlamChatAct28Legacy', chatSettings.actionPacket28LegacyHeader == true));

    chatSettings.condensedCombatLog = select(1, render_toggle('Condensed combat log (SimpleLog-style 0x28)##GlamCondCombat', chatSettings.condensedCombatLog == true));
    if (chatSettings.condensedCombatLog == true) then
        chatSettings.condenseDamage = select(1, render_toggle('  Merge hits per target##GlamCondDmg', chatSettings.condenseDamage ~= false));
        chatSettings.sumDamage = select(1, render_toggle('  Sum damage into one number##GlamSumDmg', chatSettings.sumDamage ~= false));
        chatSettings.condenseCrits = select(1, render_toggle('  Merge crit + normal hits##GlamCondCrit', chatSettings.condenseCrits == true));
        chatSettings.condenseTargets = select(1, render_toggle('  Merge identical targets##GlamCondTgt', chatSettings.condenseTargets ~= false));
    end

    imgui.Separator();
    imgui.Text('Stored messages');
    imgui.TextDisabled('Main ring buffer (memory / persist). Each chat window has its own max lines below; trimming one window no longer removes lines from the other.');
    local maxBufContents = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.maxEntries) or 1000))) };
    imgui.SliderInt('Max buffer size##GlamChatMaxEntriesContents', maxBufContents, 100, 20000);
    chatSettings.maxEntries = maxBufContents[1];

    chatSettings.inputFontScale = render_float_setting('Input Font Scale##GlamChatInput', chatSettings.inputFontScale or 1.0, 0.1, 5.0, '%.1f');
    render_font_combo('Input Font##GlamChatInput', chatSettings.font or '', function(name)
        chatSettings.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
        gResources.reload_font(chatSettings.font);
    end, { shift_jis_only = true });
    local inputBgHolder = build_chat_input_panel_style_holder(chatSettings);
    render_panel_background_controls('ChatInputPB', inputBgHolder);
    save_chat_input_panel_style_holder(chatSettings, inputBgHolder);

    imgui.Separator();
    imgui.Text('Purpose Colors');
    for i = 1, #GlamourUI.chatPurposeOrder do
        local purpose = GlamourUI.chatPurposeOrder[i];
        render_chat_color_swatch(purpose, ensure_chat_purpose_color(chatSettings, purpose));
    end

    imgui.Separator();
    imgui.Text('Message Component Colors');
    for i = 1, #GlamourUI.knownChatColorCodes do
        local entry = GlamourUI.knownChatColorCodes[i];
        local color = chatSettings.codeColors[entry.code] or entry.color;
        render_chat_code_color_swatch(entry.code, entry.label, color);
    end

    imgui.Separator();
    chatSettings.partyNameRoleColors = select(1, render_toggle('Color party member names by role##GlamPartyNameRole', chatSettings.partyNameRoleColors ~= false));
    imgui.TextDisabled('Trusts in your party use Trinity \"other\" (white). Players use tank / healer / damage / hybrid by main job.');
    imgui.Text('Trinity role colors');
    local trinityOrder = T{ 'tank', 'healer', 'damage', 'hybrid', 'other' };
    for ti = 1, #trinityOrder do
        local role = trinityOrder[ti];
        if (chatSettings.trinityColors[role] == nil) then
            chatSettings.trinityColors[role] = { 1.0, 1.0, 1.0, 1.0 };
        end
        render_chat_color_swatch(('Trinity ' .. role), chatSettings.trinityColors[role]);
    end

    imgui.Separator();
    local chatWinActivePrev = glam_custom_chat_windows_active();
    chatSettings.window1.enabled = select(1, render_toggle('Enable Chat Window 1##GlamChatWindow1Top', chatSettings.window1.enabled));
    chatSettings.window2.enabled = select(1, render_toggle('Enable Chat Window 2##GlamChatWindow2Top', chatSettings.window2.enabled));
    glam_notify_custom_chat_status_if_changed(chatWinActivePrev);

    imgui.Separator();
    if (imgui.BeginTabBar('ChatWindowTabs##GlamConf')) then
        if (chatSettings.window1.enabled and imgui.BeginTabItem('Chat Window 1##GlamChatWin1')) then
            chatSettings.window1.font_scale = render_float_setting('Font Scale##GlamChatWin1Font', chatSettings.window1.font_scale or 1.0, 0.1, 5.0, '%.1f');
            render_font_combo('Font##GlamChatWin1', chatSettings.window1.font or '', function(name)
                chatSettings.window1.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
                gResources.reload_font(chatSettings.window1.font);
            end, { shift_jis_only = true });
            local w1cap = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.window1.maxLines) or tonumber(chatSettings.maxEntries) or 1000))) };
            imgui.SliderInt('Max lines in this window##GlamChatWin1MaxLines', w1cap, 100, 20000);
            chatSettings.window1.maxLines = w1cap[1];
            imgui.TextDisabled('Oldest lines drop from the top of this window only. If unset, the main buffer size is used as the cap.');
            imgui.Separator();
            render_panel_background_controls('ChatWin1PB', chatSettings.window1);
            imgui.Separator();
            for i = 1, #GlamourUI.chatPurposeOrder do
                local purpose = GlamourUI.chatPurposeOrder[i];
                chatSettings.window1[purpose] = select(1, render_toggle((purpose .. '##GlamChatWindow1' .. i), chatSettings.window1[purpose] == true));
            end
            imgui.EndTabItem();
        end
        if (chatSettings.window2.enabled and imgui.BeginTabItem('Chat Window 2##GlamChatWin2')) then
            chatSettings.window2.font_scale = render_float_setting('Font Scale##GlamChatWin2Font', chatSettings.window2.font_scale or 1.0, 0.1, 5.0, '%.1f');
            render_font_combo('Font##GlamChatWin2', chatSettings.window2.font or '', function(name)
                chatSettings.window2.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
                gResources.reload_font(chatSettings.window2.font);
            end, { shift_jis_only = true });
            local w2cap = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.window2.maxLines) or tonumber(chatSettings.maxEntries) or 1000))) };
            imgui.SliderInt('Max lines in this window##GlamChatWin2MaxLines', w2cap, 100, 20000);
            chatSettings.window2.maxLines = w2cap[1];
            imgui.TextDisabled('Oldest lines drop from the top of this window only. If unset, the main buffer size is used as the cap.');
            imgui.Separator();
            render_panel_background_controls('ChatWin2PB', chatSettings.window2);
            imgui.Separator();
            for i = 1, #GlamourUI.chatPurposeOrder do
                local purpose = GlamourUI.chatPurposeOrder[i];
                chatSettings.window2[purpose] = select(1, render_toggle((purpose .. '##GlamChatWindow2' .. i), chatSettings.window2[purpose] == true));
            end
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end
end

local function render_cast_bar_contents(cbar_gui_scale, cbar_font_scale)
    imgui.Text('Cast Bar');
    imgui.SameLine();
    imgui.SetCursorPosX(200);
    if(imgui.Checkbox('Themed##GlamCBar', {GlamourUI.settings.cBar.themed}))then
        GlamourUI.settings.cBar.themed = not GlamourUI.settings.cBar.themed;
    end
    imgui.SetCursorPosX(200);
    if(imgui.Checkbox('Dummy Castbar##GlamCBar', {gCBar.cBarDummy}))then
        local pe = GetPlayerEntity();
        if(pe ~= nil)then
            gCBar.dummyTargetIndex = pe.TargetIndex;
        end
        gCBar.dummySpellName = 'Awesome Spell';
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
    if(imgui.BeginCombo('Theme##GlamCBar', GlamourUI.settings.cBar.theme, combo_flags))then
        for i = 1,#configDirs.themes,1 do
            local is_selected = i == themeID;

            if (GlamourUI.settings.cBar.theme ~= configDirs.themes[i] and imgui.Selectable(configDirs.themes[i], is_selected))then
                themeID = i;
                GlamourUI.settings.cBar.theme = configDirs.themes[i];
            end
            if(is_selected) then
                imgui.SetItemDefaultFocus();
            end
        end
        imgui.EndCombo();
    end
    imgui.Separator();
    render_panel_background_controls('CastBarPB', GlamourUI.settings.cBar);
end

local function ensure_rgba4_inplace(tbl, fallback)
    if (type(tbl) ~= 'table') then
        return fallback;
    end
    tbl[1] = tonumber(tbl[1]) or fallback[1];
    tbl[2] = tonumber(tbl[2]) or fallback[2];
    tbl[3] = tonumber(tbl[3]) or fallback[3];
    tbl[4] = tonumber(tbl[4]) or fallback[4];
    return tbl;
end

local function render_compass_contents()
    local s = GlamourUI.settings.Compass;
    if (s == nil) then
        return;
    end

    local geo_cardinal_default_colors = {
        Water = { 0.0, 0.42307734489440918, 1.0, 1.0 },
        Fire = { 1.0, 0.23529410362243652, 0.0, 1.0 },
        Dark = { 0.0, 0.0, 0.0, 1.0 },
        Light = { 1.0, 1.0, 1.0, 1.0 },
        Ice = { 0.55, 0.90, 1.0, 1.0 },
        Wind = { 0.0, 0.93013101816177368, 0.18602624535560608, 1.0 },
        Earth = { 0.98689955472946167, 0.64557880163192749, 0.13359779119491577, 1.0 },
        Lightning = { 0.78388655185699463, 0.095230832695960999, 0.99126636981964111, 1.0 },
    };
    local geo_cardinal_elements = {
        'Water', 'Fire', 'Dark', 'Light', 'Ice', 'Wind', 'Earth', 'Lightning',
    };

    local function ensure_geo_cardinal_colors(settingsTable)
        if (settingsTable.geoCardinalColors == nil) then
            settingsTable.geoCardinalColors = {};
        end
        for i = 1, #geo_cardinal_elements do
            local element = geo_cardinal_elements[i];
            local fallback = geo_cardinal_default_colors[element];
            if (settingsTable.geoCardinalColors[element] == nil) then
                settingsTable.geoCardinalColors[element] = {
                    fallback[1], fallback[2], fallback[3], fallback[4],
                };
            end
            ensure_rgba4_inplace(settingsTable.geoCardinalColors[element], fallback);
        end
    end

    local function render_geo_cardinal_color_swatch(element, color)
        imgui.PushStyleColor(ImGuiCol_Button, color);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, color);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, color);
        if (imgui.Button(('##GlamGeoCardinal' .. element), { 20, 20 })) then
            imgui.OpenPopup(('GlamGeoCardinalPicker##' .. element));
        end
        imgui.PopStyleColor(3);
        imgui.SameLine();
        imgui.Text(element);

        if (imgui.BeginPopup(('GlamGeoCardinalPicker##' .. element))) then
            imgui.ColorPicker3(('##GlamGeoCardinalPick' .. element), color);
            imgui.EndPopup();
        end
    end

    imgui.Text('Heading Compass');
    imgui.Separator();

    render_standard_themed_contents(
        'Compass##GlamConf',
        s,
        { gui = 'GuiScale##GlamCompass', font = 'FontScale##GlamCompass', }
    );

    imgui.Separator();
    imgui.Text('Layout');
    s.width = render_float_setting('Compass Length (px)##GlamCompass', tonumber(s.width) or 540, 160.0, 1200.0, '%.0f');

    imgui.Separator();
    imgui.Text('Behavior');
    s.show_degrees = select(1, render_toggle('Show Degrees (non-cardinal ticks)##GlamCompass', s.show_degrees == true));
    s.show_heading_value = select(1, render_toggle('Show Heading Value (deg)##GlamCompass', s.show_heading_value == true));
    s.fov_deg = render_float_setting('Field of View (deg)##GlamCompass', tonumber(s.fov_deg) or 120, 30.0, 240.0, '%.0f');
    s.tick_deg = render_float_setting('Tick Step (deg)##GlamCompass', tonumber(s.tick_deg) or 5, 1.0, 45.0, '%.0f');
    s.major_tick_deg = render_float_setting('Major Tick (deg)##GlamCompass', tonumber(s.major_tick_deg) or 15, 5.0, 90.0, '%.0f');
    s.label_deg = render_float_setting('Label Step (deg)##GlamCompass', tonumber(s.label_deg) or 45, 15.0, 90.0, '%.0f');
    if (s.geoCardinalGlow == nil) then
        s.geoCardinalGlow = true;
    end
    s.geoCardinalGlow = select(1, render_toggle('Cardinal Chant glow (GEO)##GlamCompass', s.geoCardinalGlow == true));
    if (s.geoCardinalGlow == true) then
        local glowOpacityPct = { (tonumber(s.geoCardinalGlowOpacity) or 1.0) * 100.0 };
        imgui.SliderFloat('Cardinal Chant Glow Opacity##GlamCompass', glowOpacityPct, 0.0, 100.0, '%.0f%%');
        s.geoCardinalGlowOpacity = glowOpacityPct[1] / 100.0;
        imgui.Separator();
        imgui.Text('Cardinal Chant Element Colors');
        ensure_geo_cardinal_colors(s);
        for i = 1, #geo_cardinal_elements do
            local element = geo_cardinal_elements[i];
            render_geo_cardinal_color_swatch(element, s.geoCardinalColors[element]);
        end
    end

end

local function render_minimap_label_color_picker(popupId, label, color)
    imgui.PushStyleColor(ImGuiCol_Button, color);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, color);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, color);
    if (imgui.Button(('##GlamMMLabelColor' .. popupId), { 20, 20 })) then
        imgui.OpenPopup(('GlamMMLabelColorPicker##' .. popupId));
    end
    imgui.PopStyleColor(3);
    imgui.SameLine();
    imgui.Text(label);

    if (imgui.BeginPopup(('GlamMMLabelColorPicker##' .. popupId))) then
        imgui.ColorPicker3(('##GlamMMPick' .. popupId), color);
        imgui.EndPopup();
    end
end

local function render_environment_contents()
    local s = GlamourUI.settings.Env;
    render_standard_themed_contents(
        'Environment##GlamConf',
        s,
        { gui = 'GuiScale##GlamEnv', font = 'FontScale##GlamEnv', },
        nil,
        nil
    );

    imgui.Separator();
    imgui.Text('Zone Timer');
    if (s.zone_timer_enabled == nil) then
        s.zone_timer_enabled = true;
    end
    s.zone_timer_enabled = select(1, render_toggle('Show Zone Timer##GlamEnvZT', s.zone_timer_enabled == true));
    if (s.dynamis_tracker_enabled == nil) then
        s.dynamis_tracker_enabled = true;
    end
    s.dynamis_tracker_enabled = select(1, render_toggle('Show Dynamis Timer and KI##GlamEnvDyn', s.dynamis_tracker_enabled == true));

    imgui.Separator();
    imgui.Text('Minimap');
    s.minimap_enabled = select(1, render_toggle('Enable Minimap##GlamEnvMM', s.minimap_enabled == true));
    if (s.minimap_enabled == true) then
        s.minimap_width = render_float_setting('Width (px)##GlamEnvMM', tonumber(s.minimap_width) or 180, 80, 400, '%.0f');
        s.minimap_height = render_float_setting('Height (px)##GlamEnvMM', tonumber(s.minimap_height) or 180, 80, 400, '%.0f');
        s.minimap_zoom_step = render_float_setting('Zoom Step##GlamEnvMM', tonumber(s.minimap_zoom_step) or 0.1, 0.01, 1.0, '%.2f');
        s.minimap_default_zoom = render_float_setting('Default Zoom Multiplier##GlamEnvMM', tonumber(s.minimap_default_zoom) or 1.0, 1.0, 10.0, '%.2f');
        s.fullscreen_map_default_zoom = render_float_setting('Fullscreen Default Zoom Multiplier##GlamEnvMM', tonumber(s.fullscreen_map_default_zoom) or tonumber(s.minimap_default_zoom) or 1.0, 1.0, 10.0, '%.2f');
        s.minimap_opacity = render_float_setting('Map Opacity##GlamEnvMM', tonumber(s.minimap_opacity) or 1.0, 0.1, 1.0, '%.2f');
        s.minimap_transit_opacity = render_float_setting('In-Transit Opacity (full map)##GlamEnvMM', tonumber(s.minimap_transit_opacity) or 0.45, 0.05, 1.0, '%.2f');
        do
            local map_render = require('map_render');
            local maptexture = require('maptexture');
            s.minimap_render_mode = map_render.normalize_mode(s.minimap_render_mode);
            local modeIndex = T{ map_render.mode_index(s.minimap_render_mode) };
            render_selection_combo('Map Render Mode##GlamEnvMM', map_render.label_for_mode(s.minimap_render_mode), map_render.MODE_LABELS, modeIndex, function(label)
                for i = 1, #map_render.MODE_LABELS do
                    if (map_render.MODE_LABELS[i] == label) then
                        local newMode = map_render.MODE_IDS[i];
                        if (newMode ~= s.minimap_render_mode) then
                            s.minimap_render_mode = newMode;
                            maptexture.clear_all();
                            ashita.tasks.once(1, function()
                                local minimap = require('minimap');
                                if (minimap.reload_map ~= nil) then
                                    minimap.reload_map();
                                end
                            end);
                        end
                        break;
                    end
                end
            end);
            imgui.TextDisabled('Color modes decompress DXT/bitmap maps (slower than Normal).');
        end
        s.minimap_cache_max = render_float_setting('Map Cache Max (textures)##GlamEnvMM', tonumber(s.minimap_cache_max) or 64, 8, 256, '%.0f');
        s.minimap_overlay_opacity = render_float_setting('Marker Opacity##GlamEnvMM', tonumber(s.minimap_overlay_opacity) or 1.0, 0.1, 1.0, '%.2f');
        s.minimap_scan_distance = render_float_setting('Scan Distance (yalms)##GlamEnvMM', tonumber(s.minimap_scan_distance) or 50, 10, 100, '%.0f');
        s.minimap_scan_interval = render_float_setting('Scan Interval (sec)##GlamEnvMM', tonumber(s.minimap_scan_interval) or 2, 0.5, 30, '%.1f');
        imgui.Separator();
        imgui.Text('Markers (zone defaults — per-zone overrides on Environment panel hover)');
        s.minimap_show_npcs = select(1, render_toggle('Default: Show NPCs##GlamEnvMM', s.minimap_show_npcs == true));
        s.minimap_show_mobs = select(1, render_toggle('Default: Show Mobs##GlamEnvMM', s.minimap_show_mobs == true));
        s.minimap_show_party = select(1, render_toggle('Default: Show Party##GlamEnvMM', s.minimap_show_party == true));
        s.minimap_show_alliance = select(1, render_toggle('Default: Show Alliance##GlamEnvMM', s.minimap_show_alliance == true));
        s.minimap_show_other_players = select(1, render_toggle('Default: Show Other Players##GlamEnvMM', s.minimap_show_other_players == true));
        s.minimap_show_target = select(1, render_toggle('Default: Show Target Marker##GlamEnvMM', s.minimap_show_target == true));
        imgui.Text('Name labels (each entity once)');
        s.minimap_label_hover_only = select(1, render_toggle('Names on Hover Only##GlamEnvMM', s.minimap_label_hover_only == true));
        s.minimap_label_mobs = select(1, render_toggle('Label: Mobs##GlamEnvMM', s.minimap_label_mobs == true));
        s.minimap_label_players = select(1, render_toggle('Label: Players##GlamEnvMM', s.minimap_label_players == true));
        s.minimap_label_npcs = select(1, render_toggle('Label: NPCs##GlamEnvMM', s.minimap_label_npcs == true));
        s.minimap_label_target = select(1, render_toggle('Label: Target##GlamEnvMM', s.minimap_label_target == true));
        s.minimap_label_hostile = select(1, render_toggle('Label: Hostile##GlamEnvMM', s.minimap_label_hostile == true));
        s.minimap_label_font_scale = render_float_setting('Label Font Scale##GlamEnvMM', tonumber(s.minimap_label_font_scale) or 0.85, 0.4, 2.0, '%.2f');
        if (type(s.minimap_label_color_mobs) ~= 'table') then s.minimap_label_color_mobs = { 1.0, 0.55, 0.50, 1.0 }; end
        if (type(s.minimap_label_color_players) ~= 'table') then s.minimap_label_color_players = { 0.65, 0.82, 1.0, 1.0 }; end
        if (type(s.minimap_label_color_npcs) ~= 'table') then s.minimap_label_color_npcs = { 0.98, 0.94, 0.55, 1.0 }; end
        if (type(s.minimap_label_color_target) ~= 'table') then s.minimap_label_color_target = { 1.0, 0.92, 0.2, 1.0 }; end
        if (type(s.minimap_label_color_hostile) ~= 'table') then s.minimap_label_color_hostile = { 1.0, 0.45, 0.35, 1.0 }; end
        ensure_rgba4_inplace(s.minimap_label_color_mobs, { 1.0, 0.55, 0.50, 1.0 });
        ensure_rgba4_inplace(s.minimap_label_color_players, { 0.65, 0.82, 1.0, 1.0 });
        ensure_rgba4_inplace(s.minimap_label_color_npcs, { 0.98, 0.94, 0.55, 1.0 });
        ensure_rgba4_inplace(s.minimap_label_color_target, { 1.0, 0.92, 0.2, 1.0 });
        ensure_rgba4_inplace(s.minimap_label_color_hostile, { 1.0, 0.45, 0.35, 1.0 });
        imgui.Text('Label text colors');
        render_minimap_label_color_picker('Mobs', 'Mobs', s.minimap_label_color_mobs);
        render_minimap_label_color_picker('Players', 'Players', s.minimap_label_color_players);
        render_minimap_label_color_picker('NPCs', 'NPCs', s.minimap_label_color_npcs);
        render_minimap_label_color_picker('Target', 'Target', s.minimap_label_color_target);
        render_minimap_label_color_picker('Hostile', 'Hostile', s.minimap_label_color_hostile);
        s.minimap_icon_npc = render_float_setting('NPC Icon Size##GlamEnvMM', tonumber(s.minimap_icon_npc) or 4, 2, 16, '%.0f');
        s.minimap_icon_mob = render_float_setting('Mob Icon Size##GlamEnvMM', tonumber(s.minimap_icon_mob) or 4, 2, 16, '%.0f');
        s.minimap_icon_party = render_float_setting('Party Icon Size##GlamEnvMM', tonumber(s.minimap_icon_party) or 6, 3, 20, '%.0f');
        s.minimap_icon_alliance = render_float_setting('Alliance Icon Size##GlamEnvMM', tonumber(s.minimap_icon_alliance) or 5, 3, 20, '%.0f');
        s.minimap_icon_player = render_float_setting('Other Player Icon Size##GlamEnvMM', tonumber(s.minimap_icon_player) or 5, 3, 20, '%.0f');
        s.minimap_icon_target = render_float_setting('Target Icon Size##GlamEnvMM', tonumber(s.minimap_icon_target) or 8, 4, 24, '%.0f');
    end
end

local refresh_config_dirs = function()
    local installPath = AshitaCore:GetInstallPath();
    local fontPath = ('%s\\config\\addons\\%s\\Fonts\\'):fmt(installPath, addon.name);

    configDirs.themes = ashita.fs.get_directory(('%s\\config\\addons\\%s\\Themes\\'):fmt(installPath, addon.name));
    configDirs.layouts = ashita.fs.get_directory(('%s\\config\\addons\\%s\\Layouts\\'):fmt(installPath, addon.name));
    configDirs.buffs = ashita.fs.get_directory(('%s\\config\\addons\\%s\\icons'):fmt(installPath, addon.name));
    font_manager.scan_directory(fontPath);
    if (gResources.update_shift_jis_font_list ~= nil) then
        gResources.update_shift_jis_font_list();
    end
    local scanned = font_manager.get_all_font_names();
    configDirs.fonts = (#scanned > 0) and scanned or ashita.fs.get_dir(fontPath, '.*');
end

local sync_config_ids = function()
    themeID = T{ getThemeID(GlamourUI.settings.Party.pList.theme) or 1 };
    layoutID = T{ getLayoutID(GlamourUI.settings.Party.pList.layout) or 1 };
    fontID = T{ getFontID(GlamourUI.settings.font) or 1 };
    buffID = T{ getBuffID(GlamourUI.settings.Party.pList.buffTheme) or 1 };
end

render_toggle = function(label, value)
    local changed = imgui.Checkbox(label, {value});
    if(changed)then
        return not value, true;
    end

    return value, false;
end

render_float_setting = function(label, value, minimum, maximum, format)
    local sliderValue = {value};
    imgui.SliderFloat(label, sliderValue, minimum, maximum, format);
    return sliderValue[1];
end

render_panel_background_controls = function(popupSuffix, settingsTable)
    panelStyle.normalize_settings(settingsTable);

    local en = { settingsTable.panelBackgroundEnabled == true };
    imgui.Checkbox(('Custom fill color##PanelBgEn' .. popupSuffix), en);
    settingsTable.panelBackgroundEnabled = en[1];
    imgui.SameLine();
    imgui.TextDisabled('(border / rounding / padding are separate)');

    local fillOff = settingsTable.panelBackgroundEnabled == false;
    if (not fillOff) then
        imgui.Text('Fill color');
        imgui.SameLine();
        local c = settingsTable.panelBackground;
        local preview = c;
        if (preview == nil) then
            preview = { 0.45, 0.45, 0.45, 1.0 };
        end
        imgui.PushStyleColor(ImGuiCol_Button, preview);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, preview);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, preview);
        if (imgui.Button(('##PanelBgBtn' .. popupSuffix), { 20, 20 })) then
            imgui.OpenPopup(('PanelBgPick##' .. popupSuffix));
        end
        imgui.PopStyleColor(3);
        imgui.SameLine();
        if (c == nil) then
            imgui.TextDisabled('(theme default / clear)');
        else
            imgui.Text(('A=%.2f'):fmt(c[4] or 1.0));
        end

        if (imgui.BeginPopup(('PanelBgPick##' .. popupSuffix))) then
            if (settingsTable.panelBackground == nil) then
                settingsTable.panelBackground = { 0.09, 0.09, 0.09, 0.94 };
            end
            local col = settingsTable.panelBackground;
            imgui.ColorPicker3(('RGB##PB' .. popupSuffix), col);
            local alpha = { col[4] or 1.0 };
            imgui.SliderFloat(('Alpha##PB' .. popupSuffix), alpha, 0.0, 1.0, '%.2f');
            col[4] = alpha[1];
            if (imgui.Button(('Use theme default##PB' .. popupSuffix))) then
                settingsTable.panelBackground = nil;
                imgui.CloseCurrentPopup();
            end
            imgui.EndPopup();
        end
    else
        imgui.TextDisabled('Uses the theme default window background. Border and shape settings still apply below.');
    end

    imgui.Separator();
    imgui.TextDisabled('Frame: 0 = stock ImGui for that dimension. Border 0 removes window and child borders.');
    local rnd = { tonumber(settingsTable.panelRounding) or 0 };
    imgui.SliderFloat(('Corner rounding##PB' .. popupSuffix), rnd, 0.0, 20.0, '%.0f px');
    settingsTable.panelRounding = rnd[1];

    local usePad = { settingsTable.panelPaddingX ~= nil and settingsTable.panelPaddingY ~= nil };
    imgui.Checkbox(('Custom padding##PB' .. popupSuffix), usePad);
    if (usePad[1] == true) then
        if (settingsTable.panelPaddingX == nil or settingsTable.panelPaddingY == nil) then
            settingsTable.panelPaddingX = 8;
            settingsTable.panelPaddingY = 8;
        end
    else
        settingsTable.panelPaddingX = nil;
        settingsTable.panelPaddingY = nil;
    end
    if (settingsTable.panelPaddingX ~= nil and settingsTable.panelPaddingY ~= nil) then
        local px = { tonumber(settingsTable.panelPaddingX) or 8 };
        local py = { tonumber(settingsTable.panelPaddingY) or 8 };
        imgui.SliderFloat(('Padding X##PB' .. popupSuffix), px, 0.0, 32.0, '%.0f');
        imgui.SliderFloat(('Padding Y##PB' .. popupSuffix), py, 0.0, 32.0, '%.0f');
        settingsTable.panelPaddingX = px[1];
        settingsTable.panelPaddingY = py[1];
    end

    local bsz = { tonumber(settingsTable.panelBorderSize) or 0 };
    imgui.SliderFloat(('Border##PB' .. popupSuffix), bsz, 0.0, 4.0, '%.0f px');
    settingsTable.panelBorderSize = bsz[1];
end

render_selection_combo = function(label, selectedValue, entries, selectedIndex, onSelect)
    if(imgui.BeginCombo(label, selectedValue, combo_flags))then
        local fontPushed = gResources.push_font_scale(0.3);
        for i = 1,#entries,1 do
            local isSelected = i == selectedIndex[1];

            if(selectedValue ~= entries[i] and imgui.Selectable(entries[i], isSelected))then
                selectedIndex[1] = i;
                onSelect(entries[i]);
                selectedValue = entries[i];
            end
            if(isSelected)then
                imgui.SetItemDefaultFocus();
            end
        end
        gResources.pop_font(fontPushed);
        imgui.EndCombo();
    end
end

local render_party_list_tab = function()
    if(not imgui.BeginTabItem('Party List'))then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild('PartyListTabContents##GlamConf', {-1, childHeight}, 0);

    GlamourUI.settings.Party.pList.enabled = select(1, render_toggle('Enabled##Plist', GlamourUI.settings.Party.pList.enabled));
    imgui.SameLine();
    imgui.SetCursorPosX(200);

    GlamourUI.settings.Party.pList.themed = select(1, render_toggle('Themed##Plist', GlamourUI.settings.Party.pList.themed));

    imgui.SameLine();
    imgui.SetCursorPosX(400);
    local dragEnabled, dragChanged = render_toggle('EnableDrag##Plist', GlamourUI.PartyList.Drag);
    if(dragChanged)then
        gParty.update_pos();
        GlamourUI.PartyList.Drag = dragEnabled;
    end

    render_selection_combo('Theme##PList', GlamourUI.settings.Party.pList.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.Party.pList.theme = themeName;
    end);

    local layoutEditorBtnWTab = 132;
    local layoutRowGapTab = 8;
    imgui.PushItemWidth(math.max(160, conf_content_avail_x() - layoutEditorBtnWTab - layoutRowGapTab));
    render_selection_combo('Layout##PList', GlamourUI.settings.Party.pList.layout, configDirs.layouts, layoutID, function(layoutName)
        GlamourUI.settings.Party.pList.layout = layoutName;
        gHelper.loadLayout(layoutName);
    end);
    imgui.PopItemWidth();
    imgui.SameLine(0, layoutRowGapTab);
    if (imgui.Button('Layout Editor##GlamPList', { layoutEditorBtnWTab, 0 })) then
        plLEditor = not plLEditor;
    end

    render_selection_combo('Buff Theme##PList', GlamourUI.settings.Party.pList.buffTheme, configDirs.buffs, buffID, function(buffTheme)
        GlamourUI.settings.Party.pList.buffTheme = buffTheme;
    end);

    GlamourUI.settings.Party.pList.gui_scale = render_float_setting('GuiScale##GlamPList', GlamourUI.settings.Party.pList.gui_scale, 0.1, 5.0, '%.1f');
    GlamourUI.settings.Party.pList.buff_gui_scale = render_float_setting(
        'Buff icon scale##GlamPList',
        GlamourUI.settings.Party.pList.buff_gui_scale or GlamourUI.settings.Party.pList.gui_scale or 1,
        0.1,
        5.0,
        '%.1f'
    );
    GlamourUI.settings.Party.pList.font_scale = render_float_setting('FontScale##GlamPList', GlamourUI.settings.Party.pList.font_scale, 0.1, 5.0, '%.1f');
    GlamourUI.settings.Party.pList.hideDefault = select(1, render_toggle('Hide Default Party List##Plist', GlamourUI.settings.Party.pList.hideDefault));
    GlamourUI.settings.Party.pList.FillDown = select(1, render_toggle('Fill Down##Plist', GlamourUI.settings.Party.pList.FillDown));
    local hideNativeNew, hideNativeChanged = render_toggle('Hide Native Status Icons##Plist', GlamourUI.settings.Party.pList.hideNativeStatusIcons == true);
    GlamourUI.settings.Party.pList.hideNativeStatusIcons = hideNativeNew;
    if (hideNativeChanged) then
        if (hideNativeNew) then
            nativeStatusBlock.apply();
        else
            nativeStatusBlock.remove();
        end
    end
    GlamourUI.settings.Party.pList.highlightSelectedBuff = select(1, render_toggle('Highlight Selected Buff##Plist', GlamourUI.settings.Party.pList.highlightSelectedBuff ~= false));

    imgui.Separator();
    render_panel_background_controls('PartyListPB', GlamourUI.settings.Party.pList);

    imgui.EndChild();
    imgui.EndTabItem();
end

render_dimension_controls = function(prefix, dimensions)
    local lengthValue = {dimensions.l};
    local girthValue = {dimensions.g};

    imgui.Text('HP Bar Dimensions');
    imgui.PushItemWidth(math.max(80, conf_content_avail_x() - conf_slider_arrow_pair_reserve));
    imgui.SliderInt(('Length##%s'):fmt(prefix), lengthValue, 0, 700);
    imgui.PopItemWidth();
    dimensions.l = lengthValue[1];
    imgui.SameLine(0, 6);
    if(imgui.ArrowButton(('lleft##%s'):fmt(prefix), ImGuiDir_Left))then
        dimensions.l = dimensions.l - 1;
    end
    imgui.SameLine(0, 2);
    if(imgui.ArrowButton(('lright##%s'):fmt(prefix), ImGuiDir_Right))then
        dimensions.l = dimensions.l + 1;
    end

    imgui.PushItemWidth(math.max(80, conf_content_avail_x() - conf_slider_arrow_pair_reserve));
    imgui.SliderInt(('Girth##%s'):fmt(prefix), girthValue, 0, 100);
    imgui.PopItemWidth();
    dimensions.g = girthValue[1];
    imgui.SameLine(0, 6);
    if(imgui.ArrowButton(('gleft##%s'):fmt(prefix), ImGuiDir_Up))then
        dimensions.g = dimensions.g - 1;
    end
    imgui.SameLine(0, 2);
    if(imgui.ArrowButton(('gright##%s'):fmt(prefix), ImGuiDir_Down))then
        dimensions.g = dimensions.g + 1;
    end
end

local render_standard_themed_tab = function(tabLabel, childId, settingsTable, scaleLabels, dimensions, dimensionPrefix)
    if(not imgui.BeginTabItem(tabLabel))then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild(('StdTabContents##' .. childId), {-1, childHeight}, 0);

    settingsTable.enabled = select(1, render_toggle(('Enabled##%s'):fmt(childId), settingsTable.enabled));
    imgui.SameLine();
    imgui.SetCursorPosX(200);
    settingsTable.themed = select(1, render_toggle(('Themed##%s'):fmt(childId), settingsTable.themed));

    render_selection_combo(('Theme##%s'):fmt(childId), settingsTable.theme, configDirs.themes, themeID, function(themeName)
        settingsTable.theme = themeName;
    end);

    settingsTable.gui_scale = render_float_setting(scaleLabels.gui, settingsTable.gui_scale, 0.1, 5.0, '%.1f');
    settingsTable.font_scale = render_float_setting(scaleLabels.font, settingsTable.font_scale, 0.1, 5.0, '%.1f');

    if(dimensions ~= nil)then
        render_dimension_controls(dimensionPrefix, dimensions);
    end

    imgui.Separator();
    render_panel_background_controls(childId .. 'PB', settingsTable);

    imgui.EndChild();
    imgui.EndTabItem();
end

local render_inventory_tab = function()
    if(not imgui.BeginTabItem('Inventory Panel##GlamConf'))then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild('InvTabContents##GlamConf', {-1, childHeight}, 0);

    GlamourUI.settings.Inv.enabled = select(1, render_toggle('Enabled##GlamInvPanel', GlamourUI.settings.Inv.enabled));
    render_selection_combo('Theme##GlamInvPanel', GlamourUI.settings.Inv.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.Inv.theme = themeName;
    end);
    GlamourUI.settings.Inv.font_scale = render_float_setting('FontScale##GlamInvPanel', GlamourUI.settings.Inv.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamInvTab', GlamourUI.settings.Inv.font or '', function(name)
        GlamourUI.settings.Inv.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);

    imgui.Separator();
    render_panel_background_controls('InvPanelPB', GlamourUI.settings.Inv);

    imgui.EndChild();
    imgui.EndTabItem();
end

local render_recast_tab = function()
    render_standard_themed_tab(
        'Recast Panel##GlamConf',
        'RecastPanel##GlamConf',
        GlamourUI.settings.rcPanel,
        {
            gui = 'GuiScale##GlamRecastPanel',
            font = 'FontScale##GlamRecastPanel',
        }
    );
end

render_chat_color_swatch = function(purpose, color)
    imgui.PushStyleColor(ImGuiCol_Button, color);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, color);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, color);
    if (imgui.Button(('##ChatPurpose' .. purpose), { 20, 20 })) then
        imgui.OpenPopup(('ColorPicker##' .. purpose));
    end
    imgui.PopStyleColor(3);
    imgui.SameLine();
    imgui.Text(purpose);

    if (imgui.BeginPopup(('ColorPicker##' .. purpose))) then
        imgui.ColorPicker3(('##CP' .. purpose), color);
        if (gChat ~= nil and gChat.invalidate_draw_cache ~= nil) then
            gChat.invalidate_draw_cache();
        end
        imgui.EndPopup();
    end
end

render_chat_code_color_swatch = function(code, label, color)
    imgui.PushStyleColor(ImGuiCol_Button, color);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, color);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, color);
    if (imgui.Button(('##ChatCodeColor' .. code), { 20, 20 })) then
        imgui.OpenPopup(('CodeColorPicker##' .. code));
    end
    imgui.PopStyleColor(3);
    imgui.SameLine();
    imgui.Text(('%s - %s'):fmt(code, label));

    if (imgui.BeginPopup(('CodeColorPicker##' .. code))) then
        imgui.ColorPicker3(('##CCP' .. code), color);
        imgui.EndPopup();
    end
end

local render_chat_logs_tab = function()
    if (not imgui.BeginTabItem('Chat Logs##GlamConf')) then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild('ChatLogsTabContents##GlamConf', {-1, childHeight}, 0);

    local chatSettings = GlamourUI.settings.Chat;

    chatSettings.enabled = select(1, render_toggle('Enabled##GlamChatEnabled', chatSettings.enabled));
    chatSettings.forceNativeChatHidden = select(1, render_toggle('Keep Native Chat Hidden##GlamChatHidden', chatSettings.forceNativeChatHidden));
    chatSettings.persistChatLog = select(1, render_toggle('Persist Chatlog (save last 1000)##GlamChatPersistTab', chatSettings.persistChatLog == true));
    chatSettings.actionPacket28LegacyHeader = select(1, render_toggle('Force legacy 0x28 header (SimpleLog / DSP)##GlamChatAct28Legacy', chatSettings.actionPacket28LegacyHeader == true));
    if (chatSettings.actionPacket28LegacyHeader == true) then
        imgui.TextDisabled('Skips XiPackets retail parse; use if the server only matches SimpleLog bit layout.');
    else
        imgui.TextDisabled('Default: XiPackets retail; if trg_sum decodes as 0 but the packet still has targets, SimpleLog layout is used automatically.');
    end

    chatSettings.condensedCombatLog = select(1, render_toggle('Condensed combat log (SimpleLog-style 0x28)##GlamCondCombatTab', chatSettings.condensedCombatLog == true));
    if (chatSettings.condensedCombatLog == true) then
        chatSettings.condenseDamage = select(1, render_toggle('  Merge hits per target##GlamCondDmgTab', chatSettings.condenseDamage ~= false));
        chatSettings.sumDamage = select(1, render_toggle('  Sum damage into one number##GlamSumDmgTab', chatSettings.sumDamage ~= false));
        chatSettings.condenseCrits = select(1, render_toggle('  Merge crit + normal hits##GlamCondCritTab', chatSettings.condenseCrits == true));
        chatSettings.condenseTargets = select(1, render_toggle('  Merge identical targets##GlamCondTgtTab', chatSettings.condenseTargets ~= false));
        imgui.TextDisabled('Rewrites incoming 0x28 like SimpleLog (data_modified); does not import SimpleLog profiles.');
    end

    imgui.Text('Stored messages');
    imgui.TextDisabled('Main ring buffer (memory / persist). Each chat window has its own max lines; trimming one window no longer removes lines from the other.');
    local maxBufTab = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.maxEntries) or 1000))) };
    imgui.SliderInt('Max buffer size##GlamChatMaxEntriesTab', maxBufTab, 100, 20000);
    chatSettings.maxEntries = maxBufTab[1];

    chatSettings.inputFontScale = render_float_setting('Input Font Scale##GlamChatInput', chatSettings.inputFontScale or 1.0, 0.1, 5.0, '%.1f');
    render_font_combo('Input Font##GlamChatInput', chatSettings.font or '', function(name)
        chatSettings.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
        gResources.reload_font(chatSettings.font);
    end, { shift_jis_only = true });
    local inputBgHolder = build_chat_input_panel_style_holder(chatSettings);
    render_panel_background_controls('ChatInputPB', inputBgHolder);
    save_chat_input_panel_style_holder(chatSettings, inputBgHolder);

    imgui.Separator();
    imgui.Text('Purpose Colors');
    for i = 1, #GlamourUI.chatPurposeOrder do
        local purpose = GlamourUI.chatPurposeOrder[i];
        render_chat_color_swatch(purpose, ensure_chat_purpose_color(chatSettings, purpose));
    end

    imgui.Separator();
    imgui.Text('Message Component Colors');
    for i = 1, #GlamourUI.knownChatColorCodes do
        local entry = GlamourUI.knownChatColorCodes[i];
        local color = chatSettings.codeColors[entry.code] or entry.color;
        render_chat_code_color_swatch(entry.code, entry.label, color);
    end

    imgui.Separator();
    chatSettings.partyNameRoleColors = select(1, render_toggle('Color party member names by role##GlamPartyNameRoleTab', chatSettings.partyNameRoleColors ~= false));
    imgui.TextDisabled('Trusts in your party use Trinity \"other\" (white). Players use tank / healer / damage / hybrid by main job.');
    imgui.Text('Trinity role colors');
    local trinityOrderTab = T{ 'tank', 'healer', 'damage', 'hybrid', 'other' };
    for ti = 1, #trinityOrderTab do
        local role = trinityOrderTab[ti];
        if (chatSettings.trinityColors[role] == nil) then
            chatSettings.trinityColors[role] = { 1.0, 1.0, 1.0, 1.0 };
        end
        render_chat_color_swatch(('Trinity ' .. role), chatSettings.trinityColors[role]);
    end

    imgui.Separator();
    local chatWinActivePrevTab = glam_custom_chat_windows_active();
    chatSettings.window1.enabled = select(1, render_toggle('Enable Chat Window 1##GlamChatWindow1Top', chatSettings.window1.enabled));
    chatSettings.window2.enabled = select(1, render_toggle('Enable Chat Window 2##GlamChatWindow2Top', chatSettings.window2.enabled));
    glam_notify_custom_chat_status_if_changed(chatWinActivePrevTab);

    imgui.Separator();
    if (imgui.BeginTabBar('ChatWindowTabs##GlamConf')) then
        if (chatSettings.window1.enabled and imgui.BeginTabItem('Chat Window 1##GlamChatWin1')) then
            chatSettings.window1.font_scale = render_float_setting('Font Scale##GlamChatWin1Font', chatSettings.window1.font_scale or 1.0, 0.1, 5.0, '%.1f');
            render_font_combo('Font##GlamChatWin1', chatSettings.window1.font or '', function(name)
                chatSettings.window1.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
                gResources.reload_font(chatSettings.window1.font);
            end, { shift_jis_only = true });
            local w1capTab = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.window1.maxLines) or tonumber(chatSettings.maxEntries) or 1000))) };
            imgui.SliderInt('Max lines in this window##GlamChatWin1MaxLinesTab', w1capTab, 100, 20000);
            chatSettings.window1.maxLines = w1capTab[1];
            imgui.TextDisabled('Oldest lines drop from the top of this window only. If unset, the main buffer size is used as the cap.');
            imgui.Separator();
            render_panel_background_controls('ChatWin1PB', chatSettings.window1);
            imgui.Separator();
            for i = 1, #GlamourUI.chatPurposeOrder do
                local purpose = GlamourUI.chatPurposeOrder[i];
                chatSettings.window1[purpose] = select(1, render_toggle((purpose .. '##GlamChatWindow1' .. i), chatSettings.window1[purpose] == true));
            end
            imgui.EndTabItem();
        end
        if (chatSettings.window2.enabled and imgui.BeginTabItem('Chat Window 2##GlamChatWin2')) then
            chatSettings.window2.font_scale = render_float_setting('Font Scale##GlamChatWin2Font', chatSettings.window2.font_scale or 1.0, 0.1, 5.0, '%.1f');
            render_font_combo('Font##GlamChatWin2', chatSettings.window2.font or '', function(name)
                chatSettings.window2.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
                gResources.reload_font(chatSettings.window2.font);
            end, { shift_jis_only = true });
            local w2capTab = { math.floor(math.min(20000, math.max(100, tonumber(chatSettings.window2.maxLines) or tonumber(chatSettings.maxEntries) or 1000))) };
            imgui.SliderInt('Max lines in this window##GlamChatWin2MaxLinesTab', w2capTab, 100, 20000);
            chatSettings.window2.maxLines = w2capTab[1];
            imgui.TextDisabled('Oldest lines drop from the top of this window only. If unset, the main buffer size is used as the cap.');
            imgui.Separator();
            render_panel_background_controls('ChatWin2PB', chatSettings.window2);
            imgui.Separator();
            for i = 1, #GlamourUI.chatPurposeOrder do
                local purpose = GlamourUI.chatPurposeOrder[i];
                chatSettings.window2[purpose] = select(1, render_toggle((purpose .. '##GlamChatWindow2' .. i), chatSettings.window2[purpose] == true));
            end
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end

    imgui.EndChild();
    imgui.EndTabItem();
end

local render_player_stats_tab = function()
    if(not imgui.BeginTabItem('Player Stats##GlamConf'))then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild('PlayerStatsTabContents##GlamConf', {-1, childHeight}, 0);

    GlamourUI.settings.PlayerStats.enabled = select(1, render_toggle('Enabled##GlamPlayerStats', GlamourUI.settings.PlayerStats.enabled));
    imgui.SameLine();
    imgui.SetCursorPosX(200);
    GlamourUI.settings.PlayerStats.themed = select(1, render_toggle('Themed##GlamPlayerStats', GlamourUI.settings.PlayerStats.themed));

    render_selection_combo('Theme##GlamPlayerStats', GlamourUI.settings.PlayerStats.theme, configDirs.themes, themeID, function(themeName)
        GlamourUI.settings.PlayerStats.theme = themeName;
    end);

    GlamourUI.settings.PlayerStats.gui_scale = render_float_setting('GuiScale##GlamPlayerStats', GlamourUI.settings.PlayerStats.gui_scale, 0.1, 5.0, '%.1f');
    GlamourUI.settings.PlayerStats.font_scale = render_float_setting('FontScale##GlamPlayerStats', GlamourUI.settings.PlayerStats.font_scale, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamPlayerStats', GlamourUI.settings.PlayerStats.font or '', function(name)
        GlamourUI.settings.PlayerStats.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);

    if(GlamourUI.settings.PlayerStats.expBarDim == nil)then
        GlamourUI.settings.PlayerStats.expBarDim = { l = 600, g = 14 };
    end
    if(type(GlamourUI.settings.PlayerStats.barPadding) ~= 'number')then
        GlamourUI.settings.PlayerStats.barPadding = 50;
    end

    render_pstats_bar_dim_controls('HP / MP / TP Bar Dimensions', GlamourUI.settings.PlayerStats.BarDim, 'StatTab');
    GlamourUI.settings.PlayerStats.barPadding = render_float_setting('Bar Padding##GlamPlayerStatsPadTab', GlamourUI.settings.PlayerStats.barPadding, 0, 200, '%.0f');
    render_pstats_bar_dim_controls('EXP / CP Bar Dimensions', GlamourUI.settings.PlayerStats.expBarDim, 'ExpTab');

    imgui.Separator();
    render_panel_background_controls('PlayerStatsPB', GlamourUI.settings.PlayerStats);

    imgui.EndChild();
    imgui.EndTabItem();
end

local render_general_tab = function()
    if (not imgui.BeginTabItem('General##GlamConf')) then
        return;
    end

    local tabAvailY = imgui.GetContentRegionAvail();
    local childHeight = math.max(1, tabAvailY - confFooterHeight);
    imgui.BeginChild('GeneralTabContents##GlamConf', {-1, childHeight}, 0);

    imgui.Text('General');
    imgui.Separator();
    if(imgui.BeginCombo('Font##GlamConf', GlamourUI.settings.font, combo_flags))then
        for i = 1,#configDirs.fonts,1 do
            local is_selected = i == fontID;

            if (GlamourUI.settings.font ~= configDirs.fonts[i] and imgui.Selectable(configDirs.fonts[i], is_selected))then
                fontID = i;
                GlamourUI.settings.font = configDirs.fonts[i];
                gResources.loadFont(GlamourUI.settings.font);
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

local PARSE_SORTS = { 'damage', 'dps', 'healing', 'taken', 'name' };

local function render_parse_contents()
    local p = GlamourUI.settings.Parse;
    if (p == nil) then
        return;
    end
    p.enabled = select(1, render_toggle('Enable Combat Parser##GlamParse', p.enabled == true));
    imgui.TextDisabled('DPS / damage / accuracy / healing / defense meter. Toggle: /glam parse');
    if (p.enabled ~= true) then
        return;
    end

    p.expanded = select(1, render_toggle('Start expanded (full window)##GlamParse', p.expanded == true));

    imgui.Text('Sort by:');
    for i = 1, #PARSE_SORTS do
        imgui.SameLine();
        if (imgui.RadioButton(PARSE_SORTS[i] .. '##GlamParseSort', p.sortBy == PARSE_SORTS[i])) then
            p.sortBy = PARSE_SORTS[i];
        end
    end

    p.idleTimeout = render_float_setting('Battle idle reset (sec)##GlamParse', tonumber(p.idleTimeout) or 12.0, 3.0, 60.0, '%.0f');
    p.width = math.floor(render_float_setting('Meter width (px)##GlamParse', tonumber(p.width) or 280, 160, 800, '%.0f'));
    p.font_scale = render_float_setting('FontScale##GlamParse', tonumber(p.font_scale) or 1, 0.1, 5.0, '%.1f');
    render_font_combo('Font##GlamParse', p.font or '', function(name)
        p.font = name;
        gResources.reload_font(name ~= '' and name or GlamourUI.settings.font);
    end);

    imgui.Separator();
    if (gFilters ~= nil) then
        local set = gFilters.active_set();
        imgui.TextDisabled(('Player filter (per job -- current: %s)'):fmt(gFilters.current_job() or '?'));
        render_filter_toggles('Show players', set.parserPlayers, gFilters.PARSER_PLAYERS, gFilters.PLAYER_LABELS, 'GlamFPP');
    end

    imgui.Separator();
    if (imgui.Button('Reset Battle##GlamParse') and gParseDB ~= nil) then
        gParseDB.reset_battle();
    end
    imgui.SameLine();
    if (imgui.Button('Reset Total##GlamParse') and gParseDB ~= nil) then
        gParseDB.reset_total();
    end

    imgui.Separator();
    render_panel_background_controls('ParsePB', p);
end

conf.render_config = function()
    local cbar_gui_scale = {GlamourUI.settings.cBar.gui_scale};
    local cbar_font_scale = {GlamourUI.settings.cBar.font_scale};
    if(conf.is_open == true)then
        if(not configWasOpen)then
            refresh_config_dirs();
            sync_config_ids();
            configWasOpen = true;
        end

        local winW = scaling.window.w or 1920;
        local winH = scaling.window.h or 1080;
        local scaleW = (winW / 1920);
        local scaleH = (winH / 1080);

        local configFontPushed = gResources.push_font_scale(0.35);
        local tabs = conf_build_tabs();

        local selectedValid = false;
        for i = 1, #tabs do
            if (tabs[i].show and tabs[i].id == conf.selected_tab) then
                selectedValid = true;
                break;
            end
        end
        if (not selectedValid) then
            conf.selected_tab = 'General';
        end

        local confW, confH, headerH, footerH = conf_calc_window_size(tabs, conf.selected_tab, scaleW, scaleH, winW, winH);
        imgui.SetNextWindowSize({ confW, confH }, ImGuiCond_Always);

        if(imgui.Begin('ConfMain##GlamConf', conf.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse)))then

            imgui.BeginChild('ConfHeader##GlamConf', {-1, headerH}, 0);
            local titleW = conf_calc_text_size(CONFIG_TITLE);
            local txtOffset = ((imgui.GetWindowWidth() - titleW) * 0.5);
            imgui.SetCursorPosX(math.max(0, txtOffset));
            imgui.Text(CONFIG_TITLE);
            imgui.Separator();

            conf_render_tab_bar(tabs, imgui.GetWindowWidth() - 16);
            imgui.EndChild();

            imgui.BeginChild('ConfContents##GlamConf', {-1, -footerH}, 0);
            if (conf.selected_tab == 'General') then
                render_general_contents();
            elseif (conf.selected_tab == 'PartyList') then
                render_party_list_contents();
            elseif (conf.selected_tab == 'Alliance') then
                render_standard_themed_contents(
                    'AlliancePanel##GlamConf',
                    GlamourUI.settings.Party.aPanel,
                    { gui = 'GuiScale##GlamAPanel', font = 'FontScale##GlamAPanel', },
                    GlamourUI.settings.Party.aPanel.hpBarDim,
                    'GlamAPanelHPPos'
                );
            elseif (conf.selected_tab == 'TargetBar') then
                render_standard_themed_contents(
                    'TargetBar##GlamConf',
                    GlamourUI.settings.TargetBar,
                    { gui = 'GuiScale##GlamTargetBar', font = 'FontScale##GlamTargetBar', },
                    GlamourUI.settings.TargetBar.hpBarDim,
                    'GlamTargetBarHPPos'
                );
                imgui.Separator();
                if (GlamourUI.settings.TargetBar.mobdbIcons == nil) then
                    GlamourUI.settings.TargetBar.mobdbIcons = true;
                end
                GlamourUI.settings.TargetBar.mobdbIcons = select(
                    1,
                    render_toggle('MobDB icons (mobs)##GlamTargetBar', GlamourUI.settings.TargetBar.mobdbIcons == true)
                );
                if (GlamourUI.settings.TargetBar.mobdbIcons == true) then
                    local tb = GlamourUI.settings.TargetBar;
                    if (tb.mobdbIconScale == nil) then
                        tb.mobdbIconScale = 1.0;
                    end
                    if (tb.mobdbTextScale == nil) then
                        tb.mobdbTextScale = 0.4;
                    end
                    tb.mobdbIconScale = render_float_setting(
                        'MobDB Icon Scale##GlamTargetBar',
                        tonumber(tb.mobdbIconScale) or 1.0,
                        0.25,
                        3.0,
                        '%.2f'
                    );
                    tb.mobdbTextScale = render_float_setting(
                        'MobDB Text Scale##GlamTargetBar',
                        tonumber(tb.mobdbTextScale) or 0.4,
                        0.1,
                        2.0,
                        '%.2f'
                    );
                end
            elseif (conf.selected_tab == 'PlayerStats') then
                render_player_stats_contents();
            elseif (conf.selected_tab == 'Inventory') then
                render_inventory_contents();
            elseif (conf.selected_tab == 'Recast') then
                render_recast_contents();
            elseif (conf.selected_tab == 'Chat') then
                render_chat_logs_contents();
            elseif (conf.selected_tab == 'CastBar') then
                render_cast_bar_contents(cbar_gui_scale, cbar_font_scale);
            elseif (conf.selected_tab == 'Compass') then
                render_compass_contents();
            elseif (conf.selected_tab == 'Environment') then
                render_environment_contents();
            elseif (conf.selected_tab == 'Toasts') then
                render_toasts_contents();
            elseif (conf.selected_tab == 'CombatToasts') then
                render_combat_toasts_contents();
            elseif (conf.selected_tab == 'Parse') then
                render_parse_contents();
            end
            imgui.EndChild();

            imgui.BeginChild('ConfFooter##GlamConf', {-1, footerH}, 0);
            imgui.Separator();
            local saveWidth = math.max(120, math.floor(120 * scaleW));
            imgui.SetCursorPosX((imgui.GetWindowWidth() - (saveWidth * 2 + 10)) * 0.5);
            if(imgui.Button('Save##GlamConf', { saveWidth, 0 }))then
                settings.save();
            end
            imgui.SameLine();
            if(imgui.Button('Close##GlamConf', { saveWidth, 0 }))then
                settings.save();
                conf.is_open = false;
            end
            imgui.EndChild();

            gResources.pop_font(configFontPushed);
            imgui.End();
        end
    else
        configWasOpen = false;
    end

    if(plLEditor == true)then
        imgui.SetNextWindowSize({465, 845});
        if(imgui.Begin('LayoutEditor##Glam', plLEditor, bit.bor(ImGuiWindowFlags_NoDecoration)))then
            local layoutFontPushed = gResources.push_font_scale(0.3);
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
            local jIPos = T{
                x = {gParty.layout.jobIconPos.x},
                y = {gParty.layout.jobIconPos.y}
            }

            imgui.Text('Layout Editor');
            imgui.BeginChild('Name##GlamPList', {450, 75}, ImGuiChildFlags_Borders);

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

            imgui.BeginChild('layoutHP##GlamPList', {450, 175}, ImGuiChildFlags_Borders);
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
                gParty.layout.HPBarPosition.textY = gParty.layout.HPBarPosition.textY - 1;
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

            imgui.BeginChild('layoutMP##GlamPList', {450, 175}, ImGuiChildFlags_Borders);
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
                gParty.layout.MPBarPosition.textY = gParty.layout.MPBarPosition.textY - 1;
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

            imgui.BeginChild('layoutTP##GlamPList', {450, 175}, ImGuiChildFlags_Borders);
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
                gParty.layout.TPBarPosition.textY = gParty.layout.TPBarPosition.textY - 1;
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
            
            imgui.BeginChild('BuffPosition##GlamBPos', { 450, 75 }, ImGuiChildFlags_Borders);
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

            imgui.BeginChild('jIcon##GlamPList', {450, 75}, ImGuiChildFlags_Borders);

            imgui.Text('Job Icon');
            imgui.SliderInt("X##GlamjIconPos", jIPos.x, 0, 700);
            if(gParty.layout.jobIconPos.x ~= jIPos.x[1])then
                gParty.layout.jobIconPos.x = jIPos.x[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('Xleft##GlamjIconPos', ImGuiDir_Left))then
                gParty.layout.jobIconPos.x = gParty.layout.jobIconPos.x - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('Xright##GlamjIconPos', ImGuiDir_Right))then
                gParty.layout.jobIconPos.x = gParty.layout.jobIconPos.x + 1;
            end
            imgui.SliderInt("Y##GlamjIconPos", jIPos.y, 0, 100);
            if(gParty.layout.jobIconPos.y ~= jIPos.y[1])then
                gParty.layout.jobIconPos.y = jIPos.y[1];
            end
            imgui.SameLine();
            imgui.SetCursorPosX(385);
            if(imgui.ArrowButton('jYleft', ImGuiDir_Up))then
                gParty.layout.jobIconPos.y = gParty.layout.jobIconPos.y - 1;
            end
            imgui.SameLine();
            if(imgui.ArrowButton('jYright', ImGuiDir_Down))then
                gParty.layout.jobIconPos.y = gParty.layout.jobIconPos.y + 1;
            end
            imgui.EndChild();

            imgui.SliderInt("Padding##GlamBuffPos", {gParty.layout.padding}, 0, 100);
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
            gResources.pop_font(layoutFontPushed);
            imgui.End();
        end
    end
end

conf.refresh_config_dirs = refresh_config_dirs;
conf.get_config_dirs = function()
    return configDirs;
end;
conf.render_font_combo = render_font_combo;

return conf;
