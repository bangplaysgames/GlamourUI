require('common');

local imgui = require('imgui');
local bit = require('bit');

local effects = {};

effects.by_target = T{};

local SPELL_DURATION_SEC = {
    -- Sleep
    [253] = 60,   -- Sleep
    [259] = 90,   -- Sleep II
    -- Bind / Gravity
    [258] = 60,   -- Bind
    [216] = 120,  -- Gravity
    [217] = 120,  -- Gravity II (if present)
    -- Slow / Paralyze / Silence / Blind
    [56] = 180,   -- Slow
    [79] = 180,   -- Slow II
    [58] = 120,   -- Paralyze
    [80] = 120,   -- Paralyze II
    [59] = 120,   -- Silence
    [254] = 180,  -- Blind
    [276] = 180,  -- Blind II
    [23] = 60,    -- Dia
    [24] = 120,   -- Dia II
    [25] = 180,   -- Dia III
    [230] = 60,   -- Bio
    [231] = 120,  -- Bio II
    [232] = 180,  -- Bio III
    [112] = 12,   -- Flash; matches enemy_debuff_tracker (CatseyeXI base ~12s)
};

local function clamp(n, lo, hi)
    if (n < lo) then
        return lo;
    end
    if (n > hi) then
        return hi;
    end
    return n;
end

local function decode_resist_tier(action)
    if (action == nil) then
        return 0;
    end
    local rt = tonumber(action.resist_tier);
    if (rt ~= nil and rt >= 0) then
        return rt;
    end
    local r = tonumber(action.reaction);
    if (r == nil) then
        return 0;
    end
    local upper = bit.rshift(bit.band(r, 0xF0), 4);
    if (upper ~= nil and upper >= 0 and upper <= 5) then
        return upper;
    end
    return 0;
end

local function resist_multiplier_from_tier(tier)
    tier = clamp(tonumber(tier) or 0, 0, 5);
    return 1.0 / (2 ^ tier);
end

local function is_valid_status_id(id)
    id = tonumber(id);
    return id ~= nil and id >= 1 and id <= 0x3FF and id ~= 255;
end

local function ensure_target(serverId)
    if (serverId == nil or serverId == 0) then
        return nil;
    end
    if (effects.by_target[serverId] == nil) then
        effects.by_target[serverId] = T{};
    end
    return effects.by_target[serverId];
end

effects.purge_target = function(serverId)
    if (serverId == nil or serverId == 0) then
        return;
    end
    effects.by_target[serverId] = nil;
end

effects.add = function(serverId, statusId, kind, meta)
    if (serverId == nil or serverId == 0) then
        return;
    end
    if (not is_valid_status_id(statusId)) then
        return;
    end

    local now = os.clock();
    local t = ensure_target(serverId);
    if (t == nil) then
        return;
    end

    meta = meta or {};
    local spellId = tonumber(meta.spellId) or 0;
    local baseDur = tonumber(meta.durationSec);
    if (baseDur == nil and spellId ~= 0) then
        baseDur = SPELL_DURATION_SEC[spellId];
    end

    local resistTier = decode_resist_tier(meta.action);
    local resistMult = resist_multiplier_from_tier(resistTier);
    local dur = baseDur ~= nil and math.floor(baseDur * resistMult) or nil;
    local expires = dur ~= nil and (now + dur) or nil;

    t[statusId] = {
        id = statusId,
        kind = kind or 'effect', -- 'buff' | 'debuff' | 'effect'
        appliedClock = now,
        lastSeenClock = now,
        spellId = spellId ~= 0 and spellId or nil,
        durationSec = dur,
        expiresClock = expires,
        resistTier = resistTier,
        resistMult = resistMult,
    };
end

effects.remove = function(serverId, statusId)
    if (serverId == nil or serverId == 0) then
        return;
    end
    if (not is_valid_status_id(statusId)) then
        return;
    end
    local t = effects.by_target[serverId];
    if (t ~= nil) then
        t[statusId] = nil;
        if (next(t) == nil) then
            effects.by_target[serverId] = nil;
        end
    end
end

effects.apply_mode = function(serverId, statusId, mode)
    if (mode == 'Add Buff') then
        effects.add(serverId, statusId, 'buff');
        return;
    end
    if (mode == 'Add Debuff') then
        effects.add(serverId, statusId, 'debuff');
        return;
    end
    if (mode == 'Add Effect') then
        effects.add(serverId, statusId, 'effect');
        return;
    end
    if (mode == 'Lose Debuff' or mode == 'Lose Effect') then
        effects.remove(serverId, statusId);
        return;
    end
end

effects.apply_mode_with_action = function(serverId, statusId, mode, meta)
    if (mode == 'Add Buff') then
        effects.add(serverId, statusId, 'buff', meta);
        return;
    end
    if (mode == 'Add Debuff') then
        effects.add(serverId, statusId, 'debuff', meta);
        return;
    end
    if (mode == 'Add Effect') then
        effects.add(serverId, statusId, 'effect', meta);
        return;
    end
    if (mode == 'Lose Debuff' or mode == 'Lose Effect') then
        effects.remove(serverId, statusId);
        return;
    end
end

effects.get_status_ids_by_kind = function(serverId, kind)
    local t = effects.by_target[serverId];
    if (t == nil) then
        return T{};
    end
    local ids = T{};
    for statusId, data in pairs(t) do
        if (data ~= nil and data.kind == kind) then
            ids[#ids + 1] = statusId;
        end
    end
    table.sort(ids, function(a, b) return a < b; end);
    return ids;
end

effects.get_remaining_seconds_for_status_id = function(serverId, statusId)
    local t = effects.by_target[serverId];
    if (t == nil) then
        return nil;
    end
    local data = t[statusId];
    if (data == nil or data.expiresClock == nil) then
        return nil;
    end
    return math.max(0, data.expiresClock - os.clock());
end

local function icon_tex_for_status(statusId)
    if (gResources == nil) then
        return nil;
    end

    local theme = nil;
    if (GlamourUI ~= nil and GlamourUI.settings ~= nil and GlamourUI.settings.Party ~= nil
            and GlamourUI.settings.Party.pList ~= nil) then
        theme = GlamourUI.settings.Party.pList.buffTheme;
    end

    if (gResources.get_icon_from_theme ~= nil) then
        local ok, tex = pcall(function()
            return gResources.get_icon_from_theme(theme, statusId);
        end);
        if (ok and tex ~= nil) then
            return tex;
        end
    end

    if (gResources.get_icon_image ~= nil) then
        local ok, tex = pcall(function()
            return gResources.get_icon_image(statusId);
        end);
        if (ok) then
            return tex;
        end
    end

    return nil;
end

local function format_remaining_seconds(sec)
    if (sec == nil) then
        return '';
    end
    if (sec < 0) then
        return '--';
    end
    if (sec >= 3600) then
        return string.format('%dh', math.floor(sec / 3600));
    end
    local m = math.floor(sec / 60);
    local s = math.floor(sec - m * 60);
    if (m > 0) then
        return string.format('%d:%02d', m, s);
    end
    return string.format('%d', s);
end

local function imgui_calc_text_width(str)
    if (str == nil or str == '') then
        return 0;
    end
    local w = imgui.CalcTextSize(str);
    if (type(w) == 'number') then
        return w;
    end
    if (type(w) == 'table') then
        return tonumber(w[1]) or tonumber(w.x) or 0;
    end
    return tonumber(w) or 0;
end

local function collect_ids_by_kind(t, wantKind)
    local ids = T{};
    for statusId, data in pairs(t) do
        if (data ~= nil and data.kind == wantKind) then
            ids[#ids + 1] = statusId;
        end
    end
    table.sort(ids, function(a, b) return a < b; end);
    return ids;
end

local function render_id_row(t, ids, opts)
    local iconSize = tonumber(opts.iconSize) or 14;
    local maxIcons = tonumber(opts.maxIcons) or 16;
    local spacing = tonumber(opts.spacing) or 2;
    local showTimerTooltip = (opts.showTimerTooltip ~= false);
    local showTimerOverlay = (opts.showTimerOverlay == true);
    local fontScale = tonumber(opts.timerFontScale) or 0.55;

    local shown = 0;
    for i = 1, #ids do
        if (shown >= maxIcons) then
            break;
        end
        local statusId = ids[i];
        local data = t[statusId];
        local pos = { imgui.GetCursorPos() };
        local tex = icon_tex_for_status(statusId);
        if (tex ~= nil) then
            imgui.Image(tex, { iconSize, iconSize });
        else
            imgui.Text(string.format('#%d', statusId));
        end

        if (showTimerTooltip and imgui.IsItemHovered ~= nil and imgui.IsItemHovered() and data ~= nil) then
            imgui.BeginTooltip();
            local now = os.clock();
            local rem = nil;
            if (data.expiresClock ~= nil) then
                rem = math.max(0, data.expiresClock - now);
            end
            if (data.spellId ~= nil) then
                imgui.Text(string.format('SpellId: %d', data.spellId));
            end
            if (data.durationSec ~= nil) then
                imgui.Text(string.format('Duration: %ds', data.durationSec));
            end
            if (rem ~= nil) then
                imgui.Text(string.format('Remaining: %.0fs', rem));
            end
            if (data.resistTier ~= nil and data.resistTier > 0) then
                imgui.Text(string.format('Resist: 1/%d', 2 ^ data.resistTier));
            end
            imgui.EndTooltip();
        end

        if (showTimerOverlay and data ~= nil and data.expiresClock ~= nil and gResources ~= nil and gResources.push_font_scale ~= nil) then
            local now = os.clock();
            local rem = math.max(0, data.expiresClock - now);
            local txt = format_remaining_seconds(rem);
            if (txt ~= nil and txt ~= '') then
                local pushed = gResources.push_font_scale(fontScale);
                local tw = imgui_calc_text_width(txt);
                local tx = pos[1] + (iconSize - tw) * 0.5;
                local ty = pos[2] + iconSize - 10;

                imgui.SetCursorPos({ tx + 1, ty + 1 });
                imgui.PushStyleColor(ImGuiCol_Text, { 0.02, 0.02, 0.02, 1.0 });
                imgui.Text(txt);
                imgui.PopStyleColor();

                imgui.SetCursorPos({ tx, ty });
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 0.72, 1.0 });
                imgui.Text(txt);
                imgui.PopStyleColor();

                gResources.pop_font(pushed);
                imgui.SetCursorPos(pos);
            end
        end

        shown = shown + 1;
        if (shown < maxIcons and i < #ids) then
            imgui.SameLine();
            imgui.SetCursorPosX(imgui.GetCursorPosX() + spacing);
        end
    end
end

effects.render_rows_under_cursor = function(serverId, opts)
    opts = opts or {};
    local t = effects.by_target[serverId];
    if (t == nil) then
        return;
    end

    local debuffIds = collect_ids_by_kind(t, 'debuff');
    local buffIds = collect_ids_by_kind(t, 'buff');

    if (#debuffIds > 0) then
        render_id_row(t, debuffIds, opts);
    end

    if (#buffIds > 0) then
        if (#debuffIds > 0) then
            imgui.NewLine();
        end
        render_id_row(t, buffIds, opts);
    end
end

effects.render_row_under_cursor = function(serverId, opts)
    opts = opts or {};
    opts.maxIcons = tonumber(opts.maxIcons) or 16;
    local t = effects.by_target[serverId];
    if (t == nil) then
        return;
    end
    local ids = T{};
    for statusId, _ in pairs(t) do
        ids[#ids + 1] = statusId;
    end
    table.sort(ids, function(a, b) return a < b; end);
    render_id_row(t, ids, opts);
end

return effects;

