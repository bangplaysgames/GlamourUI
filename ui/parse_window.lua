--[[
    Combat parser display (reads gParseDB; drawn from render.lua render_parse_window).

    Hybrid UI:
      compact  -- small meter: combatant list with damage bars + DPS (default).
      expanded -- Battle|Total toggle, sortable list, and Damage/Accuracy/Healing/
                  Defense detail tabs for the selected combatant.

    Visibility/expand/scope persist in GlamourUI.settings.Parse. Styled through
    panelStyle + gResources font scaling like the other GlamourUI panels.
]]--

require('common');

local imgui = require('imgui');
local panelStyle = require('panelStyle');
local chatPartyNames = require('chatPartyNames');

local M = {};

-- UI-only state (not persisted).
local selectedSid = nil;
local activeTab = 'Damage';

-- Approx content line count per detail tab (used to size the body so the window
-- isn't taller than the visible tab needs).
local TAB_LINES = { Damage = 12, Accuracy = 6, Healing = 3, Defense = 5 };

local SIDE_COLORS = {
    me         = { 1.00, 0.85, 0.30, 1.0 },
    party      = { 0.45, 0.75, 1.00, 1.0 },
    alliance   = { 0.55, 0.85, 0.65, 1.0 },
    trust      = { 0.70, 0.70, 0.95, 1.0 },
    my_pet     = { 0.60, 1.00, 0.60, 1.0 },
    other_pets = { 0.50, 0.80, 0.55, 1.0 },
};

local function settings()
    return GlamourUI and GlamourUI.settings and GlamourUI.settings.Parse or nil;
end

local function fmt_num(n)
    n = tonumber(n) or 0;
    if (n >= 1000000) then
        return ('%.2fM'):fmt(n / 1000000);
    elseif (n >= 10000) then
        return ('%.1fK'):fmt(n / 1000);
    end
    return ('%d'):fmt(math.floor(n + 0.5));
end

local function fmt_pct(x)
    return ('%.1f%%'):fmt((tonumber(x) or 0) * 100);
end

local function fmt_dur(secs)
    secs = math.floor(tonumber(secs) or 0);
    return ('%d:%02d'):fmt(math.floor(secs / 60), secs % 60);
end

local function side_color(side)
    return SIDE_COLORS[side] or { 1.0, 1.0, 1.0, 1.0 };
end

-- Color a combatant by its trinity ROLE (tank/healer/damage/...), reusing the
-- chat's job->role color mapping. Trusts are colored by their job too (same as
-- players). Pets and names not resolvable in the party roster use the side color.
local function name_color(c)
    if (c.side ~= 'my_pet' and c.side ~= 'other_pets') then
        local ok, col = pcall(chatPartyNames.get_role_color, c.name);
        if (ok and col ~= nil) then
            return col;
        end
    end
    return side_color(c.side);
end

-- Display label: pets show their owner's name in parentheses.
local function display_name(c)
    if ((c.side == 'my_pet' or c.side == 'other_pets') and c.ownerName ~= nil and c.ownerName ~= '') then
        return ('%s (%s)'):fmt(c.name, c.ownerName);
    end
    return c.name;
end

local function scope_name(s)
    if (s ~= nil and s.scope == 'total') then
        return 'total';
    end
    return 'battle';
end

-- ---- Compact meter --------------------------------------------------------

local function draw_meter_rows(s, scope, barW)
    local list = gParseDB.combatant_list(scope, s.sortBy or 'damage');
    if (#list == 0) then
        imgui.TextDisabled('No combat data yet.');
        return;
    end
    local top = list[1].dmg.total;
    if (top <= 0) then top = 1; end

    for i = 1, #list do
        local c = list[i];
        local frac = (c.dmg.total or 0) / top;
        local barCol = name_color(c);
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { barCol[1], barCol[2], barCol[3], 0.85 });
        -- Combined melee+ranged hit rate; shown only when the combatant has swung.
        local hits = c.acc.melee.hit + c.acc.ranged.hit;
        local swings = hits + c.acc.melee.miss + c.acc.ranged.miss;
        local overlay;
        if (swings > 0) then
            overlay = ('%s  %s dps  %s acc'):fmt(display_name(c), fmt_num(gParseDB.dps(scope, c)), fmt_pct(hits / swings));
        else
            overlay = ('%s  %s dps'):fmt(display_name(c), fmt_num(gParseDB.dps(scope, c)));
        end
        imgui.ProgressBar(frac, { barW, 0 }, overlay);
        imgui.PopStyleColor();
        if (imgui.IsItemClicked()) then
            selectedSid = c.sid;
            s.expanded = true;
        end
    end
end

local function render_compact(s)
    local scope = scope_name(s);
    local barW = math.max(160, tonumber(s.width) or 280);

    imgui.Text(('Battle %s'):fmt(fmt_dur(gParseDB.scope_duration(scope))));
    imgui.SameLine();
    imgui.TextDisabled(('| %s dps'):fmt(fmt_num(gParseDB.raid_dps(scope))));
    imgui.SameLine(barW - 24);
    if (imgui.SmallButton('+##GlamParseExpand')) then
        s.expanded = true;
    end
    imgui.Separator();

    draw_meter_rows(s, scope, barW);
end

-- ---- Expanded views -------------------------------------------------------

local function selected_combatant(scope)
    local list = gParseDB.combatant_list(scope, 'damage');
    if (#list == 0) then
        return nil;
    end
    for i = 1, #list do
        if (list[i].sid == selectedSid) then
            return list[i];
        end
    end
    return list[1];
end

local function detail_damage(c)
    imgui.Text(('Total Damage: %s'):fmt(fmt_num(c.dmg.total)));
    imgui.Separator();
    local rows = {
        { 'Melee', c.dmg.melee }, { 'Ranged', c.dmg.ranged }, { 'Weaponskill', c.dmg.ws },
        { 'Magic', c.dmg.magic }, { 'Ability', c.dmg.ability }, { 'Pet', c.dmg.pet },
        { 'Add. Effect', c.dmg.add },
    };
    for _, r in ipairs(rows) do
        local pct = (c.dmg.total > 0) and (r[2] / c.dmg.total) or 0;
        imgui.Text(('%-12s %10s  %6s'):fmt(r[1], fmt_num(r[2]), fmt_pct(pct)));
    end
    imgui.Separator();
    imgui.Text(('Weaponskills: %d   avg %s   max %s'):fmt(
        c.ws.count, fmt_num(gParseDB.ws_average(c)), fmt_num(c.ws.max)));
    imgui.Text(('Magic casts: %d   bursts %d (%s)'):fmt(
        c.magic.count, c.magic.bursts, fmt_num(c.magic.burstDmg)));
end

local function detail_accuracy(c)
    imgui.Text(('Melee   Acc %s   Crit %s'):fmt(
        fmt_pct(gParseDB.melee_accuracy(c)), fmt_pct(gParseDB.melee_crit_rate(c))));
    imgui.TextDisabled(('  %d hit / %d miss / %d crit'):fmt(
        c.acc.melee.hit, c.acc.melee.miss, c.acc.melee.crit));
    imgui.Text(('Multi-attack: %.2f hits/round'):fmt(gParseDB.hits_per_round(c)));
    imgui.Separator();
    imgui.Text(('Ranged  Acc %s'):fmt(fmt_pct(gParseDB.ranged_accuracy(c))));
    imgui.TextDisabled(('  %d hit / %d miss / %d crit'):fmt(
        c.acc.ranged.hit, c.acc.ranged.miss, c.acc.ranged.crit));
end

local function detail_healing(c)
    imgui.Text(('Total Healing: %s'):fmt(fmt_num(c.heal.total)));
    imgui.Text(('Heal actions: %d'):fmt(c.heal.count));
    if (c.heal.count > 0) then
        imgui.Text(('Average: %s'):fmt(fmt_num(c.heal.total / c.heal.count)));
    end
end

local function detail_defense(c)
    local t = c.taken;
    imgui.Text(('Damage Taken: %s'):fmt(fmt_num(t.total)));
    imgui.Text(('Hits taken: %d   TP moves: %d'):fmt(t.hits, t.tpMoves));
    imgui.Separator();
    local defended = t.evaded + t.parried + t.shadows;
    local incoming = t.hits + defended;
    imgui.Text(('Evaded: %d   Parried: %d   Shadows: %d'):fmt(t.evaded, t.parried, t.shadows));
    if (incoming > 0) then
        imgui.Text(('Mitigated: %s'):fmt(fmt_pct(defended / incoming)));
    end
end

local function render_expanded(s)
    local scope = scope_name(s);

    -- Scope + controls row.
    if (imgui.RadioButton('Battle##GlamParseScope', scope == 'battle')) then
        s.scope = 'battle';
    end
    imgui.SameLine();
    if (imgui.RadioButton('Total##GlamParseScope', scope == 'total')) then
        s.scope = 'total';
    end
    imgui.SameLine();
    if (imgui.SmallButton('Reset Total##GlamParse')) then
        gParseDB.reset_total();
    end
    imgui.SameLine();
    if (imgui.SmallButton('Compact##GlamParse')) then
        s.expanded = false;
    end
    scope = scope_name(s);

    imgui.Text(('Duration %s   Raid DPS %s'):fmt(
        fmt_dur(gParseDB.scope_duration(scope)), fmt_num(gParseDB.raid_dps(scope))));
    imgui.Separator();

    local list = gParseDB.combatant_list(scope, s.sortBy or 'damage');
    local totalDmg = gParseDB.total_damage(scope);
    if (totalDmg <= 0) then totalDmg = 1; end

    -- Side-by-side layout via two child regions with EXPLICIT sizes. Columns
    -- break AlwaysAutoResize (the window can't measure them and clips); a sized
    -- BeginChild is a normal measured item, so the window resizes to fit both.
    local lineH = imgui.GetTextLineHeightWithSpacing();
    local leftW = math.max(160, tonumber(s.width) or 220);
    local rightW = 300;
    -- Size the body to whichever needs more height: the full combatant list, or
    -- the CURRENTLY VISIBLE detail tab (+2 rows for the name header + tab bar).
    -- Using the active tab (from last frame) keeps the window from staying as
    -- tall as the largest tab when a short tab is shown.
    local detailRows = (TAB_LINES[activeTab] or 12) + 2;
    local bodyRows = math.max(#list + 1, detailRows);
    local bodyH = bodyRows * lineH;

    -- Left: combatant list.
    if (imgui.BeginChild('GlamParseList', { leftW, bodyH }, ImGuiChildFlags_Borders)) then
        if (#list == 0) then
            imgui.TextDisabled('No combat data yet.');
        end
        for i = 1, #list do
            local c = list[i];
            local col = name_color(c);
            imgui.PushStyleColor(ImGuiCol_Text, col);
            local label = ('%s  %s (%s)'):fmt(display_name(c), fmt_num(c.dmg.total),
                fmt_pct((c.dmg.total or 0) / totalDmg));
            if (imgui.Selectable(label .. '##GlamParseSel' .. tostring(c.sid), selectedSid == c.sid)) then
                selectedSid = c.sid;
            end
            imgui.PopStyleColor();
        end
    end
    imgui.EndChild();

    imgui.SameLine();

    -- Right: detail tabs for the selected combatant.
    if (imgui.BeginChild('GlamParseDetail', { rightW, bodyH }, 0)) then
        local c = selected_combatant(scope);
        if (c == nil) then
            imgui.TextDisabled('Select a combatant.');
        else
            local col = name_color(c);
            imgui.TextColored(col, display_name(c));
            -- Ashita's imgui binding doesn't expose these flag globals; fall back
            -- to upstream numeric values (ResizeDown = 1<<6, NoScrollBtns = 1<<4).
            local tabFlags = bit.bor(
                rawget(_G, 'ImGuiTabBarFlags_FittingPolicyResizeDown') or 64,
                rawget(_G, 'ImGuiTabBarFlags_NoTabListScrollingButtons') or 16
            );
            if (imgui.BeginTabBar('GlamParseTabs', tabFlags)) then
                if (imgui.BeginTabItem('Damage##GlamParse')) then
                    activeTab = 'Damage';
                    detail_damage(c);
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Accuracy##GlamParse')) then
                    activeTab = 'Accuracy';
                    detail_accuracy(c);
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Healing##GlamParse')) then
                    activeTab = 'Healing';
                    detail_healing(c);
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Defense##GlamParse')) then
                    activeTab = 'Defense';
                    detail_defense(c);
                    imgui.EndTabItem();
                end
                imgui.EndTabBar();
            end
        end
    end
    imgui.EndChild();
end

-- ---- Entry point ----------------------------------------------------------

function M.render()
    local s = settings();
    if (s == nil or s.enabled ~= true) then
        return;
    end
    if (gParseDB == nil) then
        return;
    end

    local expanded = (s.expanded == true);
    imgui.SetNextWindowPos({ tonumber(s.x) or 100, tonumber(s.y) or 200 }, ImGuiCond_FirstUseEver);

    local flags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_AlwaysAutoResize
    );

    local bgPops = panelStyle.push_panel_background(s);
    local fontPushed = gResources.push_font_scale((tonumber(s.font_scale) or 1) * 0.5, s);

    if (imgui.Begin('Combat Parser##GlamParse', true, flags)) then
        local ok, err = pcall(function()
            if (expanded) then
                render_expanded(s);
            else
                render_compact(s);
            end
            local wp = { imgui.GetWindowPos() };
            s.x = wp[1];
            s.y = wp[2];
        end);
        if (not ok) then
            imgui.TextColored({ 1.0, 0.4, 0.4, 1.0 }, tostring(err));
        end
    end
    imgui.End();

    gResources.pop_font(fontPushed);
    panelStyle.pop_panel_background(bgPops);
end

return M;
