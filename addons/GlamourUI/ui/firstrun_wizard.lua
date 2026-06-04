--[[ First-run setup wizard for GlamourUI. ]]

local imgui = require('imgui');
local settings = require('settings');
local scaling = require('scaling');
local font_manager = require('font_manager');

local wizard = {
    is_open = false,
    page_index = 1,
    dirs_ready = false,
};

local WIZARD_TITLE = 'GlamourUI Setup';
local PACKET_INJECTION_DISCLAIMER = [[Packet Injection Mode enables the injection of certain outgoing packets to enrich some of the functions of GlamourUI.  This IS DETECTABLE by the server and may be against the server rules for whatever server you are playing on.  If you have questions regarding whether this functionality is allowed or not, please reach out to the staff for your server.  Banggugyangu and anyone else involved in the development of GlamourUI or Ashita are not responsible in any way for consequences of breaking a server's rules.  Please follow the rules set by your server's staff.]];

local function wiz_toggle(label, value)
    if (render_toggle ~= nil) then
        return render_toggle(label, value);
    end
    local changed = imgui.Checkbox(label, { value == true });
    if (changed) then
        return not value, true;
    end
    return value, false;
end

local function wiz_text_wrapped(text)
    imgui.PushTextWrapPos(imgui.GetCursorPosX() + math.max(200, imgui.GetContentRegionAvail()));
    imgui.TextWrapped(tostring(text or ''));
    imgui.PopTextWrapPos();
end

local function wiz_theme_combo(label, selected, entries, onSelect)
    entries = entries or T{};
    local display = selected;
    if (display == nil or display == '') then
        display = '(none)';
    end
    if (not imgui.BeginCombo(label, display)) then
        return;
    end
    for i = 1, #entries do
        local name = entries[i];
        if (imgui.Selectable(('%s##%s%d'):fmt(name, label, i), selected == name)) then
            onSelect(name);
        end
    end
    imgui.EndCombo();
end

local function wiz_ensure_dirs()
    if (wizard.dirs_ready) then
        return;
    end
    if (gConf ~= nil and gConf.refresh_config_dirs ~= nil) then
        gConf.refresh_config_dirs();
    end
    wizard.dirs_ready = true;
end

local function wiz_dirs()
    wiz_ensure_dirs();
    if (gConf ~= nil and gConf.get_config_dirs ~= nil) then
        return gConf.get_config_dirs();
    end
    return { themes = T{}, buffs = T{}, fonts = T{} };
end

local function page_packet_injection()
    imgui.Text('Packet Injection');
    imgui.Separator();
    wiz_text_wrapped(PACKET_INJECTION_DISCLAIMER);
    imgui.Spacing();
    local enabled = GlamourUI.settings.packet_injection_enabled == true;
    GlamourUI.settings.packet_injection_enabled = select(1, wiz_toggle('Enable Packet Injection Mode##FirstrunInject', enabled));
    if (GlamourUI.settings.packet_injection_enabled ~= true) then
        imgui.TextDisabled('Off (recommended until you confirm server rules).');
    else
        imgui.TextDisabled('On — GlamourUI may send outgoing widescan requests to discover mob levels on target.');
    end
end

local function page_general()
    imgui.Text('Choose which UI modules to enable.');
    imgui.Separator();
    local s = GlamourUI.settings;
    s.Party.pList.enabled = select(1, wiz_toggle('Party List##FirstrunGen', s.Party.pList.enabled == true));
    s.Party.aPanel.enabled = select(1, wiz_toggle('Alliance Panel##FirstrunGen', s.Party.aPanel.enabled == true));
    s.TargetBar.enabled = select(1, wiz_toggle('Target Bar##FirstrunGen', s.TargetBar.enabled == true));
    s.PlayerStats.enabled = select(1, wiz_toggle('Player Stats##FirstrunGen', s.PlayerStats.enabled == true));
    s.Inv.enabled = select(1, wiz_toggle('Inventory Panel##FirstrunGen', s.Inv.enabled == true));
    s.rcPanel.enabled = select(1, wiz_toggle('Recast Panel##FirstrunGen', s.rcPanel.enabled == true));
    s.Chat.enabled = select(1, wiz_toggle('Chat Logs##FirstrunGen', s.Chat.enabled == true));
    s.cBar.enabled = select(1, wiz_toggle('Cast Bar##FirstrunGen', s.cBar.enabled == true));
    s.Compass.enabled = select(1, wiz_toggle('Heading Compass##FirstrunGen', s.Compass.enabled == true));
    imgui.Separator();
    imgui.Text('Default Font');
    if (gConf ~= nil and gConf.render_font_combo ~= nil) then
        gConf.render_font_combo('DefaultFont##Firstrun', s.font, function(name)
            s.font = name;
            gResources.loadFont(name);
            if (gResources.preload_configured_fonts ~= nil) then
                gResources.preload_configured_fonts(s);
            end
        end, { allow_default = false });
    else
        imgui.TextDisabled(s.font or '(default)');
    end
end

local function page_themed_panel(title, settingsTable, opts)
    opts = opts or {};
    imgui.Text(title);
    imgui.Separator();
    local dirs = wiz_dirs();
    settingsTable.enabled = select(1, wiz_toggle(('Enabled##Firstrun%s'):fmt(title), settingsTable.enabled == true));
    if (opts.themed_toggle ~= false) then
        settingsTable.themed = select(1, wiz_toggle(('Themed##Firstrun%s'):fmt(title), settingsTable.themed == true));
    end
    if (settingsTable.theme ~= nil) then
        wiz_theme_combo(('Theme##Firstrun%s'):fmt(title), settingsTable.theme, dirs.themes, function(name)
            settingsTable.theme = name;
        end);
    end
    if (opts.buff_theme and settingsTable.buffTheme ~= nil) then
        wiz_theme_combo(('Buff Theme##Firstrun%s'):fmt(title), settingsTable.buffTheme, dirs.buffs, function(name)
            settingsTable.buffTheme = name;
        end);
    end
    if (opts.gui_scale and settingsTable.gui_scale ~= nil) then
        local gv = { tonumber(settingsTable.gui_scale) or 1 };
        imgui.SliderFloat(('UI Scale##Firstrun%s'):fmt(title), gv, 0.5, 2.5, '%.1f');
        settingsTable.gui_scale = gv[1];
    end
    if (opts.font_scale and settingsTable.font_scale ~= nil) then
        local fv = { tonumber(settingsTable.font_scale) or 1 };
        imgui.SliderFloat(('Font Scale##Firstrun%s'):fmt(title), fv, 0.5, 2.5, '%.1f');
        settingsTable.font_scale = fv[1];
    end
end

local function page_party_list()
    page_themed_panel('Party List', GlamourUI.settings.Party.pList, {
        buff_theme = true,
        gui_scale = true,
        font_scale = true,
    });
    local p = GlamourUI.settings.Party.pList;
    p.hideDefault = select(1, wiz_toggle('Hide Default Party List##FirstrunPL', p.hideDefault == true));
    p.FillDown = select(1, wiz_toggle('Fill Down##FirstrunPL', p.FillDown == true));
end

local function page_chat()
    imgui.Text('Chat Logs');
    imgui.Separator();
    local chatSettings = GlamourUI.settings.Chat;
    chatSettings.enabled = select(1, wiz_toggle('Enabled##FirstrunChat', chatSettings.enabled == true));
    if (chatSettings.window1 ~= nil) then
        chatSettings.window1.enabled = select(1, wiz_toggle('Chat Window 1##FirstrunChat', chatSettings.window1.enabled == true));
    end
    if (chatSettings.window2 ~= nil) then
        chatSettings.window2.enabled = select(1, wiz_toggle('Chat Window 2##FirstrunChat', chatSettings.window2.enabled == true));
    end
    chatSettings.forceNativeChatHidden = select(1, wiz_toggle('Keep Native Chat Hidden##FirstrunChat', chatSettings.forceNativeChatHidden == true));
    chatSettings.persistChatLog = select(1, wiz_toggle('Persist Chat Log##FirstrunChat', chatSettings.persistChatLog == true));
    if (gConf ~= nil and gConf.render_font_combo ~= nil) then
        imgui.Text('Chat Input Font');
        gConf.render_font_combo('ChatInputFont##Firstrun', chatSettings.font or '', function(name)
            chatSettings.font = font_manager.pick_shift_jis_fallback(name, GlamourUI.settings.font);
            gResources.reload_font(chatSettings.font);
        end, { shift_jis_only = true });
    end
end

local function page_compass()
    local s = GlamourUI.settings.Compass;
    page_themed_panel('Heading Compass', s, { gui_scale = true, font_scale = true });
    s.show_degrees = select(1, wiz_toggle('Show Degree Ticks##FirstrunCompass', s.show_degrees == true));
    s.show_heading_value = select(1, wiz_toggle('Show Heading Value##FirstrunCompass', s.show_heading_value == true));
end

local function page_environment()
    local s = GlamourUI.settings.Env;
    page_themed_panel('Environment Panel', s, { gui_scale = true, font_scale = true });
    imgui.Separator();
    imgui.Text('Minimap');
    s.minimap_enabled = select(1, wiz_toggle('Enable Minimap##FirstrunEnv', s.minimap_enabled == true));
    if (s.minimap_enabled == true) then
        local wv = { tonumber(s.minimap_width) or 180 };
        local hv = { tonumber(s.minimap_height) or 180 };
        imgui.SliderFloat('Minimap Width##FirstrunEnv', wv, 80, 400, '%.0f');
        imgui.SliderFloat('Minimap Height##FirstrunEnv', hv, 80, 400, '%.0f');
        s.minimap_width = wv[1];
        s.minimap_height = hv[1];
        s.minimap_show_mobs = select(1, wiz_toggle('Show Mobs##FirstrunEnv', s.minimap_show_mobs == true));
        s.minimap_show_party = select(1, wiz_toggle('Show Party##FirstrunEnv', s.minimap_show_party == true));
        s.minimap_label_hover_only = select(1, wiz_toggle('Names on Hover Only##FirstrunEnv', s.minimap_label_hover_only == true));
    end
end

local function page_cast_bar()
    local s = GlamourUI.settings.cBar;
    page_themed_panel('Cast Bar', s, { gui_scale = true, font_scale = true });
end

local WIZARD_PAGES = {
    { title = 'Welcome', render = function()
        imgui.Text('Welcome to GlamourUI');
        imgui.Separator();
        wiz_text_wrapped('This wizard walks through the main options for each UI element. Layout and position editing stay in /glam config — here you only pick features and styles.');
        imgui.Spacing();
        page_packet_injection();
    end },
    { title = 'Modules', render = page_general },
    { title = 'Party List', render = page_party_list },
    { title = 'Alliance', render = function()
        page_themed_panel('Alliance Panel', GlamourUI.settings.Party.aPanel, { gui_scale = true, font_scale = true });
    end },
    { title = 'Target Bar', render = function()
        page_themed_panel('Target Bar', GlamourUI.settings.TargetBar, { gui_scale = true, font_scale = true });
    end },
    { title = 'Player Stats', render = function()
        page_themed_panel('Player Stats', GlamourUI.settings.PlayerStats, { gui_scale = true, font_scale = true });
    end },
    { title = 'Inventory', render = function()
        page_themed_panel('Inventory Panel', GlamourUI.settings.Inv, { themed_toggle = false, gui_scale = true, font_scale = true });
    end },
    { title = 'Recast', render = function()
        page_themed_panel('Recast Panel', GlamourUI.settings.rcPanel, { gui_scale = true, font_scale = true });
    end },
    { title = 'Chat', render = page_chat },
    { title = 'Cast Bar', render = page_cast_bar },
    { title = 'Compass', render = page_compass },
    { title = 'Environment', render = page_environment },
};

local function wiz_page_count()
    return #WIZARD_PAGES;
end

function wizard.open()
    wizard.page_index = 1;
    wizard.is_open = true;
    wizard.dirs_ready = false;
    wiz_ensure_dirs();
end

function wizard.close()
    wizard.is_open = false;
end

function wizard.toggle()
    if (wizard.is_open) then
        wizard.close();
    else
        wizard.open();
    end
end

function wizard.finish()
    GlamourUI.settings.firstrun_completed = true;
    wizard.close();
    settings.save();
end

function wizard.should_auto_open()
    if (GlamourUI.settings.firstrun_completed == true) then
        return false;
    end
    return true;
end

function wizard.render()
    if (wizard.is_open ~= true) then
        return;
    end

    wiz_ensure_dirs();

    local winW = scaling.window.w or 1920;
    local winH = scaling.window.h or 1080;
    local scaleW = winW / 1920;
    local scaleH = winH / 1080;
    local w = math.min(winW - 48, math.max(520, math.floor(720 * scaleW)));
    local h = math.min(winH - 48, math.max(420, math.floor(560 * scaleH)));

    imgui.SetNextWindowPos({ winW * 0.5, winH * 0.5 }, ImGuiCond_Always, { 0.5, 0.5 });
    imgui.SetNextWindowSize({ w, h }, ImGuiCond_Always);

    local fontPushed = nil;
    if (gResources ~= nil and gResources.push_font_scale ~= nil) then
        fontPushed = gResources.push_font_scale(0.35);
    end

    if (not imgui.Begin('GlamourUI Setup##GlamFirstRun', wizard.is_open, bit.bor(
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoSavedSettings
    ))) then
        if (fontPushed ~= nil) then
            gResources.pop_font(fontPushed);
        end
        return;
    end

    imgui.Text(WIZARD_TITLE);
    imgui.Separator();

    local page = WIZARD_PAGES[wizard.page_index] or WIZARD_PAGES[1];
    local stepLabel = ('Step %d of %d — %s'):fmt(wizard.page_index, wiz_page_count(), page.title);
    imgui.TextDisabled(stepLabel);
    imgui.Spacing();

    local footerH = math.max(44, math.floor(52 * scaleH));
    imgui.BeginChild('FirstrunBody##Glam', { -1, -footerH }, 0);
    page.render();
    imgui.EndChild();

    imgui.Separator();
    local btnW = math.max(100, math.floor(110 * scaleW));
    local totalBtnW = btnW * 3 + 16;
    imgui.SetCursorPosX(math.max(0, (imgui.GetWindowWidth() - totalBtnW) * 0.5));

    if (wizard.page_index > 1) then
        if (imgui.Button('Back##Firstrun', { btnW, 0 })) then
            wizard.page_index = wizard.page_index - 1;
        end
    else
        imgui.InvisibleButton('BackSpacer##Firstrun', { btnW, imgui.GetFrameHeight() });
    end

    imgui.SameLine(0, 8);
    if (imgui.Button('Close##Firstrun', { btnW, 0 })) then
        wizard.close();
        settings.save();
    end

    imgui.SameLine(0, 8);
    local onLast = wizard.page_index >= wiz_page_count();
    if (imgui.Button(onLast and 'Finish##Firstrun' or 'Next##Firstrun', { btnW, 0 })) then
        if (onLast) then
            wizard.finish();
        else
            wizard.page_index = wizard.page_index + 1;
            settings.save();
        end
    end

    if (fontPushed ~= nil) then
        gResources.pop_font(fontPushed);
    end
    imgui.End();
end

return wizard;
