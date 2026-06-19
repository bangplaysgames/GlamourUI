require('common');

local compat = require('compat');
local actor_parse = require('actor_parse');
local action_packet28 = require('action_packet28');
local packet_codec = require('packet_codec');
local skill_tables = require('skill_tables');
local condense_action_packet = require('condense_action_packet');
local mode_options = require('mode_options');
local simplify_combat = require('simplify_combat');
local roe_regime = require('roe_regime');

local M = {};

local res_actmsg;
local res_load_err;

-- Action messages that mark a real player weapon skill landing (damage / HP-or-MP drain /
-- HP recover), same set thotbar uses to detect a WS. A category-3 action whose message is
-- NOT one of these isn't a damaging WS -- e.g. a trust ability mis-slotted into the WS
-- category like NanaaMihgo's Despoil (a steal: message carries the stolen ITEM id, not
-- damage), which would otherwise mis-toast as "Final Paradise for <itemId> damage".
local WS_MESSAGE_IDS = { [103] = true, [185] = true, [187] = true, [238] = true };

local function is_magic_burst_message(msg_id)
    msg_id = tonumber(msg_id) or 0;
    if (msg_id == 0) then
        return false;
    end
    local row = res_actmsg and res_actmsg[msg_id] or nil;
    if (row == nil or row.en == nil) then
        return false;
    end
    return row.en:find('Magic Burst', 1, true) ~= nil;
end

local function skillchain_name_from_message(msg_id)
    msg_id = tonumber(msg_id) or 0;
    if (msg_id == 0) then
        return nil;
    end
    local row = res_actmsg and res_actmsg[msg_id] or nil;
    if (row == nil or row.en == nil) then
        return nil;
    end
    local en = row.en;
    if (en:find('Skillchain', 1, true) == nil) then
        return nil;
    end
    local name = en:match('Skillchain:?%s*([^%.!${]+)');
    if (name ~= nil) then
        name = name:gsub('^%s+', ''):gsub('%s+$', '');
        if (name ~= '' and name ~= 'Skillchain') then
            return name;
        end
    end
    return 'Skillchain';
end

local function add_effect_numeric(m)
    if (m == nil) then
        return nil;
    end
    local raw = (m.cadd_effect_param ~= nil and tostring(m.cadd_effect_param) ~= '')
        and m.cadd_effect_param or m.add_effect_param;
    local n = tonumber(raw);
    if (n ~= nil and n > 0) then
        return n;
    end
    return nil;
end

local function classify_combat_action(act, m)
    local cat = tonumber(act.category) or 0;
    local actorType = act.actor and act.actor.type or nil;
    local isOwnedPet = (actorType == 'my_pet' or actorType == 'other_pets');
    local msg = m and (tonumber(m.message) or 0) or 0;
    -- Pet TP moves arrive as cat 11 (or msg 110/317), but automaton/pet ranged
    -- weaponskills come as cat 2 and other pet weaponskills as cat 3, so treat
    -- those as pet events too (otherwise they emit no toast / no damage number).
    local isPetMove = isOwnedPet and (msg == 110 or msg == 317 or cat == 11 or cat == 2 or cat == 3);
    local abilId = math.floor(tonumber(act.param) or 0);
    if (cat == 3 and WS_MESSAGE_IDS[msg]) then
        return 'ws', abilId;
    elseif (cat == 4) then
        return 'spell', abilId;
    elseif (isPetMove) then
        return 'pet', abilId % 0x10000;
    end
    return nil, abilId;
end

local function templ_has(templ, token)
    return templ ~= nil and templ ~= '' and templ:find(token, 1, true) ~= nil;
end

local function lit_replace(str, from, to_)
    if (str == nil or from == nil or from == '') then
        return str;
    end
    local out = str;
    local idx = out:find(from, 1, true);
    while (idx ~= nil) do
        out = out:sub(1, idx - 1) .. tostring(to_ or '') .. out:sub(idx + #from);
        idx = out:find(from, idx + #(tostring(to_ or '')), true);
    end
    return out;
end

--- Treat empty string like nil so `x or ('#'..id)` still replaces bogus \"\" from resource lookups.
local function skill_nonempty(s)
    if (s == nil) then
        return nil;
    end
    s = tostring(s);
    if (s == '') then
        return nil;
    end
    return s;
end

local function load_res_actmsg()
    if (res_actmsg ~= nil or res_load_err ~= nil) then
        return res_actmsg;
    end
    local ok, data = pcall(function()
        return require('action_messages');
    end);
    if (not ok or type(data) ~= 'table') then
        res_load_err = tostring(data);
        return nil;
    end
    res_actmsg = data;
    return res_actmsg;
end

local function rm()
    return AshitaCore:GetResourceManager();
end

local function rm_string(tbl, id)
    if (id == nil) then
        return nil;
    end
    id = math.floor(tonumber(id) or 0);
    if (id < 0 or id > 65535) then
        return nil;
    end
    local r = rm();
    if (r == nil or r.GetString == nil) then
        return nil;
    end
    local ok, s = pcall(function()
        local s1 = r:GetString(tbl, id, 2);
        if (s1 ~= nil and s1 ~= '') then
            return s1;
        end
        return r:GetString(tbl, id, 1);
    end);
    if (not ok or s == nil or s == '') then
        return nil;
    end
    return s;
end

local function ability_object_first_name(ab)
    if (ab == nil or ab.Name == nil) then
        return nil;
    end
    local nm = ab.Name;
    local ok2, a, b = pcall(function()
        return nm[1], nm[2];
    end);
    if (not ok2) then
        return nil;
    end
    for ii = 1, 2 do
        local v = (ii == 1) and a or b;
        if (v ~= nil) then
            local s = tostring(v);
            if (s ~= '' and s ~= 'nil') then
                return s;
            end
        end
    end
    return nil;
end

local function weapon_skill_display_name_by_packet_id(id)
    local r = rm();
    if (r == nil or r.GetAbilityById == nil) then
        return nil;
    end
    local n = math.floor(tonumber(id) or 0);
    if (n <= 0 or n > 0x200) then
        return nil;
    end
    local ok, ab = pcall(function()
        return r:GetAbilityById(n);
    end);
    if (not ok or ab == nil) then
        return nil;
    end
    return ability_object_first_name(ab);
end

local function job_ability_display_name_by_packet_id(id)
    local r = rm();
    if (r == nil or r.GetAbilityById == nil) then
        return nil;
    end
    local n = math.floor(tonumber(id) or 0);
    if (n <= 0) then
        return nil;
    end
    local tries = {};
    if (n < 0x200) then
        tries[1] = n + 0x200;
    else
        tries[1] = n;
    end
    local seen = {};
    for ti = 1, #tries do
        local tid = tries[ti];
        if (not seen[tid]) then
            seen[tid] = true;
            local ok, ab = pcall(function()
                return r:GetAbilityById(tid);
            end);
            if (ok and ab ~= nil) then
                local s = ability_object_first_name(ab);
                if (s ~= nil and s ~= '') then
                    return s;
                end
            end
        end
    end
    return nil;
end

local function lookup_spell(id)
    for _, t in ipairs(T{ 'spells.names', 'spells.names_short', 'spells' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_player_ws(id)
    local n = math.floor(tonumber(id) or 0);
    if (n <= 0) then
        return nil;
    end
    for _, t in ipairs(T{ 'weapon_skills.names', 'weapon_skills' }) do
        local s = rm_string(t, n);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return weapon_skill_display_name_by_packet_id(n);
end

local function lookup_ws(id)
    local n = math.floor(tonumber(id) or 0);
    if (n <= 0) then
        return nil;
    end
    local s = lookup_player_ws(n);
    if (s ~= nil and s ~= '') then
        return s;
    end
    for _, t in ipairs(T{ 'monsters.weapon_skills' }) do
        s = rm_string(t, n);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_job_ability(id)
    local abil_name = job_ability_display_name_by_packet_id(id);
    if (abil_name ~= nil and abil_name ~= '') then
        return abil_name;
    end
    for _, t in ipairs(T{ 'job_abilities.names', 'abilities.jobs', 'job_abilities' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_mon_ability(id, _actorName, opts)
    opts = opts or {};
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil;
    end
    if (id >= 0x101) then
        local row = id - 256;
        if (row >= 1) then
            for _, t in ipairs(T{ 'monsters.abilities', 'monsters.abilities.names', 'monster.abilities' }) do
                local s = rm_string(t, row);
                if (s ~= nil and s ~= '') then
                    return s;
                end
            end
        end
    end
    for _, t in ipairs(T{ 'monsters.weapon_skills', 'monsters.weapon_skills.names', 'monster.weapon_skills' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    if (id > 256) then
        local s = rm_string('monsters.weapon_skills', id - 256);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    if (opts.allow_player_ws == false) then
        return nil;
    end
    return lookup_player_ws(id);
end

local function skill_table_entry_name(entry)
    if (entry == nil or entry.Name == nil) then
        return nil;
    end
    return ability_object_first_name(entry);
end

local function spellparse_weapon_skill_name(abil_ID)
    local id = math.floor(tonumber(abil_ID) or 0);
    if (id <= 0) then
        return nil;
    end
    if (id > 256) then
        local name = skill_table_entry_name(skill_tables.mon_ability_entry(id));
        if (name ~= nil and name ~= '') then
            return name;
        end
        return 'Special Attack';
    end
    return skill_table_entry_name(skill_tables.weapon_skill_entry(id));
end

local function spellparse_ability_name(abil_ID)
    return skill_table_entry_name(skill_tables.job_ability_entry(abil_ID));
end

local function lookup_item(id)
    local n = math.floor(tonumber(id) or 0);
    if (n > 0 and n <= 65535) then
        local r = rm();
        if (r ~= nil and r.GetItemById ~= nil) then
            local ok, item = pcall(function()
                return r:GetItemById(n);
            end);
            if (ok and item ~= nil) then
                local s = ability_object_first_name(item);
                if (s ~= nil and s ~= '') then
                    return s;
                end
            end
        end
    end
    for _, t in ipairs(T{ 'items.names_log', 'items.names', 'items' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_skill(id)
    for _, t in ipairs(T{ 'skills.names', 'skills' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_buff(id)
    local n = math.floor(tonumber(id) or 0);
    if (n < 0 or n > 65535) then
        return nil;
    end
    local a = rm_string(compat.buffs_table(), n);
    if (a ~= nil and a ~= '') then
        return a;
    end
    return rm_string('buffs.names_log', n);
end

local function purpose_from_row(row, msg_id)
    msg_id = tonumber(msg_id) or 0;
    local c = row and row.color;
    if (c == 'D') then
        return 'Damage Dealt';
    elseif (c == 'M') then
        return 'Miss';
    elseif (c == 'H') then
        return 'HP Recovered';
    elseif (c == 'R') then
        return 'Spell Complete';
    end
    if (msg_id == 3 or msg_id == 42 or msg_id == 327) then
        return 'Spell Cast';
    elseif (msg_id == 6 or msg_id == 20) then
        return 'Kill';
    elseif (msg_id == 16) then
        return 'Interrupted';
    elseif (msg_id == 64 or msg_id == 204 or msg_id == 206) then
        return 'Lose Effect';
    elseif (msg_id == 78 or msg_id == 328) then
        return 'Ability Not Ready';
    elseif (msg_id == 98 or msg_id == 565 or msg_id == 566 or msg_id == 582
        or msg_id == 673 or msg_id == 706 or msg_id == 765 or msg_id == 766) then
        return 'Spoils'; -- item/gil/tab obtained from treasure pool, reives, etc.
    elseif (msg_id == 8 or msg_id == 105 or msg_id == 253) then
        return 'Experience';
    elseif (msg_id == 371 or msg_id == 372) then
        return 'Limit Points';
    elseif (msg_id == 718 or msg_id == 735) then
        return 'Capacity Points';
    end
    if (roe_regime.is_roe_message(msg_id)) then
        return roe_regime.purpose();
    end
    return 'None';
end

local function cat_contains(cat, ...)
    for i = 1, select('#', ...) do
        if (cat == select(i, ...)) then
            return true;
        end
    end
    return false;
end

local function resolve_action_resources(act, msg_id, m)
    local spell = '';
    local ability = '';
    local weapon_skill = '';
    local item = '';
    local cat = tonumber(act.category) or 0;
    local param = tonumber(act.param) or 0;
    local tp = tonumber(m and m.param) or 0;

    local abil_ID = param;
    if (cat_contains(cat, 7, 8, 9)) then
        abil_ID = tonumber(m and m.param) or param;
    end

    local row = res_actmsg[msg_id];
    local templ = (row and row.en) or '';
    if (templ:find('${spell}', 1, true)) then
        spell = skill_nonempty(lookup_spell(abil_ID)) or ('#' .. tostring(abil_ID));
    end
    if (templ:find('${ability}', 1, true)) then
        ability = skill_nonempty(spellparse_ability_name(abil_ID)) or ('#' .. tostring(abil_ID));
    end
    if (templ:find('${weapon_skill}', 1, true)) then
        weapon_skill = skill_nonempty(spellparse_weapon_skill_name(abil_ID)) or ('#' .. tostring(abil_ID));
    end
    if (templ:find('${item}', 1, true) or templ:find('${item2}', 1, true)) then
        item = skill_nonempty(lookup_item(abil_ID)) or ('#' .. tostring(abil_ID));
    end

    return spell, ability, weapon_skill, item, tp;
end

local function plain_action_label(act, msg_id, m)
    local spell, ability, ws, item = resolve_action_resources(act, msg_id, m);
    local row = res_actmsg[msg_id];
    local templ = (row and row.en) or '';
    if (templ:find('${spell}', 1, true) and spell ~= '') then
        return spell;
    end
    if (templ:find('${ability}', 1, true) and ability ~= '') then
        return ability;
    end
    if (templ:find('${weapon_skill}', 1, true) and ws ~= '') then
        return ws;
    end
    if (templ:find('${item}', 1, true) and item ~= '') then
        return item;
    end
    if (templ:find('${item2}', 1, true) and item ~= '') then
        return item;
    end
    return '';
end

local function primary_numeric_display(m)
    if (m.cparam ~= nil and tostring(m.cparam) ~= '') then
        return tostring(m.cparam);
    end
    return tostring(m.param or '');
end

local function resolve_combat_ability_name(act, kind, abilId)
    if (kind == 'ws') then
        return lookup_player_ws(abilId);
    elseif (kind == 'spell') then
        return lookup_spell(abilId);
    elseif (kind == 'pet') then
        return lookup_mon_ability(abilId, nil, { allow_player_ws = false });
    end
    local cat = tonumber(act.category) or 0;
    abilId = math.floor(tonumber(abilId) or 0);
    if (cat == 3) then
        return lookup_player_ws(abilId);
    elseif (cat == 4) then
        return lookup_spell(abilId);
    end
    return nil;
end

local function emit_combat_events(act, combat_event_cb)
    if (combat_event_cb == nil or act == nil) then
        return;
    end

    local firstTgt = act.targets and act.targets[1];
    local firstAction = firstTgt and firstTgt.actions and firstTgt.actions[1];
    local kind, abilId = classify_combat_action(act, firstAction);

    -- Resolve the ability name the SAME way the chat log does (template-driven
    -- plain_action_label / resolve_action_resources). The category-based
    -- lookup_mon_ability path mis-resolves pet TP moves like wyvern breaths
    -- ("Gust Breath" -> "Petro Eyes"); the chat path gets them right.
    local resolvedName = '';
    if (firstAction ~= nil) then
        resolvedName = plain_action_label(act, tonumber(firstAction.message) or 0, firstAction) or '';
    end
    if (resolvedName == '') then
        -- The labelling sub-action may not be the first one (a breath's "uses"
        -- line vs its damage line); scan for the first action that yields a label.
        for _, tgt in ipairs(act.targets or {}) do
            for _, m in ipairs(tgt.actions or {}) do
                local lbl = plain_action_label(act, tonumber(m.message) or 0, m);
                if (lbl ~= nil and lbl ~= '') then
                    resolvedName = lbl;
                    break;
                end
            end
            if (resolvedName ~= '') then break; end
        end
    end
    if (resolvedName == '') then
        resolvedName = resolve_combat_ability_name(act, kind, abilId) or '';
    end

    if (kind ~= nil and resolvedName ~= '') then
        local name = resolvedName;
        local damage = nil;
        local dmgMsg = firstAction and (tonumber(firstAction.message) or 0) or 0;
        local primaryMsg = dmgMsg;
        local targetId = nil;
        local targetName = nil;

        -- Damage: take the first damage-colored ('D') action across targets, the
        -- same number the chat log's damage line prints. A pet move's "uses ..."
        -- sub-action often carries no number, so reading only actions[1] missed it.
        for _, tgt in ipairs(act.targets or {}) do
            for _, m in ipairs(tgt.actions or {}) do
                local mid = tonumber(m.message) or 0;
                local row = res_actmsg and res_actmsg[mid] or nil;
                if (row ~= nil and (row.color == 'D' or (row.color == 'H' and (mid == 227 or mid == 274)))) then
                    local n = tonumber(primary_numeric_display(m));
                    if (n ~= nil and n > 0) then
                        damage = n;
                        dmgMsg = mid;
                        break;
                    end
                end
            end
            if (damage ~= nil) then break; end
        end
        if (damage == nil and firstAction ~= nil) then
            local n = tonumber(primary_numeric_display(firstAction));
            if (n ~= nil and n > 0) then
                damage = n;
            end
        end

        local damaging = (damage ~= nil);

        if (firstTgt ~= nil) then
            targetId = firstTgt.server_id;
            local targTbl = actor_parse.parse(firstTgt.server_id);
            targetName = targTbl and targTbl.name or nil;
        end
        pcall(function()
            combat_event_cb({
                kind = kind,
                actorId = act.actor_id,
                actorName = (act.actor and act.actor.name) or nil,
                abilId = abilId,
                name = name,
                damage = damage,
                damaging = damaging,
                magicBurst = is_magic_burst_message(primaryMsg) or is_magic_burst_message(dmgMsg),
                message = primaryMsg,
                targetId = targetId,
                targetName = targetName,
            });
        end);
    end

    local closingName = (resolvedName ~= '' and resolvedName) or resolve_combat_ability_name(act, kind, abilId) or '?';
    local seenSkillchain = {};

    for _, tgt in ipairs(act.targets or {}) do
        local sid = tgt.server_id;
        local targTbl = actor_parse.parse(sid);
        local targetName = targTbl and targTbl.name or nil;
        for __, m in ipairs(tgt.actions or {}) do
            local scMsgId = 0;
            local scDamage = nil;
            if (m.has_add_effect) then
                scMsgId = tonumber(m.add_effect_message) or 0;
                scDamage = add_effect_numeric(m);
            end
            if (scMsgId == 0 or skillchain_name_from_message(scMsgId) == nil) then
                scMsgId = tonumber(m.message) or 0;
                if (skillchain_name_from_message(scMsgId) ~= nil) then
                    local n = tonumber(primary_numeric_display(m));
                    if (n ~= nil and n > 0) then
                        scDamage = n;
                    end
                else
                    scMsgId = 0;
                end
            end
            local scName = skillchain_name_from_message(scMsgId);
            if (scName ~= nil) then
                local dedupeKey = ('%u:%u:%s'):fmt(sid, scMsgId, tostring(scDamage or 0));
                if (not seenSkillchain[dedupeKey]) then
                    seenSkillchain[dedupeKey] = true;
                    pcall(function()
                        combat_event_cb({
                            kind = 'skillchain',
                            actorId = act.actor_id,
                            actorName = (act.actor and act.actor.name) or nil,
                            abilId = abilId,
                            name = closingName,
                            skillchainName = scName,
                            damage = scDamage,
                            targetId = sid,
                            targetName = targetName,
                        });
                    end);
                end
            end
        end
    end
end

local function condensed_swing_prefix(mode, m)
    if (mode == nil or mode.condensedamage ~= true) then
        return '';
    end
    local n = tonumber(m.number) or 1;
    if (n <= 1) then
        return '';
    end
    return ('[%u] '):fmt(n);
end

local function format_action_line(act, target_sid, m, mode)
    local msg_id = tonumber(m.message) or 0;
    if (msg_id == 0 or res_actmsg[msg_id] == nil) then
        return nil, nil;
    end

    if (roe_regime.is_progress_message(msg_id)) then
        local p1 = tonumber(m.param) or 0;
        local p2 = tonumber(m.param_2) or tonumber(act.param) or 0;
        local line = roe_regime.format_progress_line(msg_id, p1, p2);
        if (line ~= nil and line ~= '') then
            return roe_regime.purpose(), line;
        end
    end

    local row = res_actmsg[msg_id];
    local retail_en = row.en;
    local templ = retail_en;
    if (templ == nil or templ == '') then
        return nil, nil;
    end

    local fields_tab = simplify_combat.search_fields(retail_en);
    if (mode ~= nil and mode.simplify == true) then
        simplify_combat.apply_field_overrides(msg_id, fields_tab);
        local pt = simplify_combat.pick_template(msg_id, fields_tab);
        if (pt ~= nil) then
            templ = pt;
        end
    end

    local actor_n = (act.actor and act.actor.name) or '?';
    local targ_tbl = actor_parse.parse(target_sid);
    local target_n = (targ_tbl and targ_tbl.name) or '?';

    local spell, ability, ws, item, _tp = resolve_action_resources(act, msg_id, m);
    local retail_status = templ_has(row.en, '${status}');
    local status = '';
    if (templ_has(templ, '${status}') and retail_status) then
        status = lookup_buff(m.param) or '';
    end

    local numb = primary_numeric_display(m);
    if (row.prefix) then
        numb = row.prefix .. ' ' .. numb;
    end
    if (row.suffix == 'shadow' and tonumber(m.param) ~= 1) then
        numb = numb .. ' shadows';
    end

    local add_status = '';
    if (templ_has(templ, '${status}') and m.has_add_effect and tonumber(m.add_effect_message or 0) ~= 0 and res_actmsg[m.add_effect_message]) then
        add_status = lookup_buff(m.add_effect_param) or '';
    end

    local abil = '';
    if (mode ~= nil and mode.simplify == true) then
        abil = simplify_combat.english_simp_name(act, msg_id, m, function()
            return plain_action_label(act, msg_id, m);
        end);
    end

    local out = templ;
    out = lit_replace(out, '${abil}', abil);
    out = lit_replace(out, "${actor}'s", actor_n .. "'s");
    out = lit_replace(out, "${target}'s", target_n .. "'s");
    out = lit_replace(out, '${spell}', spell);
    out = lit_replace(out, '${ability}', ability);
    out = lit_replace(out, '${weapon_skill}', ws);
    out = lit_replace(out, '${item}', item);
    out = lit_replace(out, '${item2}', item);
    out = lit_replace(out, '${actor}', actor_n);
    out = lit_replace(out, '${target}', target_n);
    if (templ_has(templ, '${regime}')) then
        local regime_id = tonumber(act.param) or tonumber(m.param) or 0;
        local regime = roe_regime.lookup_regime_name(regime_id) or ('#' .. tostring(regime_id));
        out = lit_replace(out, '${regime}', regime);
    end
    if (roe_regime.is_progress_message(msg_id)) then
        local p1 = tonumber(m.param) or 0;
        local p2 = tonumber(m.param_2) or tonumber(act.param) or 0;
        out = lit_replace(out, '${number}', tostring(p1));
        out = lit_replace(out, '${number2}', tostring(p2));
        out = lit_replace(out, '${numb}', tostring(p1));
    else
        out = lit_replace(out, '${number}', numb);
        out = lit_replace(out, '${number2}', tostring(m.param_2 or m.param or ''));
        out = lit_replace(out, '${numb}', numb);
    end
    out = lit_replace(out, '${status}', status ~= '' and status or (add_status ~= '' and add_status or ''));
    if (templ_has(templ, '${skill}')) then
        out = lit_replace(out, '${skill}', lookup_skill(m.param) or '');
    else
        out = lit_replace(out, '${skill}', '');
    end
    if (templ_has(templ, '${gil}')) then
        local g = tonumber(m.param) or 0;
        out = lit_replace(out, '${gil}', tostring(g) .. ' gil');
    end
    out = lit_replace(out, '${lb}', '\n');

    out = out:gsub('\7', '\n');
    out = condensed_swing_prefix(mode, m) .. out;
    local purpose = purpose_from_row(row, msg_id);
    return purpose, out;
end

local function emit_add_effect_line(act, target_sid, m, mode)
    if (not m.has_add_effect or tonumber(m.add_effect_message or 0) == 0) then
        return nil, nil;
    end
    local msg_id = tonumber(m.add_effect_message) or 0;
    if (msg_id == 0 or res_actmsg[msg_id] == nil) then
        return nil, nil;
    end
    local row = res_actmsg[msg_id];
    local templ = row.en;
    if (templ == nil) then
        return nil, nil;
    end
    local actor_n = (act.actor and act.actor.name) or '?';
    local targ_tbl = actor_parse.parse(target_sid);
    local target_n = (targ_tbl and targ_tbl.name) or '?';
    local status = '';
    if (templ_has(templ, '${status}')) then
        status = lookup_buff(m.add_effect_param) or '';
    end

    local addNum = (m.cadd_effect_param ~= nil and tostring(m.cadd_effect_param) ~= '') and tostring(m.cadd_effect_param) or tostring(m.add_effect_param or '');

    local out = templ;
    out = lit_replace(out, '${spell}', '');
    out = lit_replace(out, '${ability}', '');
    out = lit_replace(out, '${weapon_skill}', '');
    out = lit_replace(out, '${item}', '');
    out = lit_replace(out, "${actor}'s", actor_n .. "'s");
    out = lit_replace(out, "${target}'s", target_n .. "'s");
    out = lit_replace(out, '${actor}', actor_n);
    out = lit_replace(out, '${target}', target_n);
    out = lit_replace(out, '${number}', addNum);
    out = lit_replace(out, '${status}', status);
    out = lit_replace(out, '${lb}', '\n');
    out = out:gsub('\7', '\n');
    if (mode ~= nil and mode.condensedamage == true and (tonumber(m.add_effect_number) or 1) > 1) then
        out = ('[%u] '):fmt(m.add_effect_number) .. out;
    end
    local purpose = purpose_from_row(row, msg_id);
    return purpose, out;
end

local function emit_spike_line(act, target_sid, m, mode)
    if (not m.has_spike_effect or tonumber(m.spike_effect_message or 0) == 0) then
        return nil, nil;
    end
    local msg_id = tonumber(m.spike_effect_message) or 0;
    if (msg_id == 0 or res_actmsg[msg_id] == nil) then
        return nil, nil;
    end
    local row = res_actmsg[msg_id];
    local templ = row.en;
    if (templ == nil) then
        return nil, nil;
    end
    local actor_n = (act.actor and act.actor.name) or '?';
    local targ_tbl = actor_parse.parse(target_sid);
    local target_n = (targ_tbl and targ_tbl.name) or '?';

    local spikeNum = (m.cspike_effect_param ~= nil and tostring(m.cspike_effect_param) ~= '') and tostring(m.cspike_effect_param) or tostring(m.spike_effect_param or '');

    local out = templ;
    out = lit_replace(out, "${actor}'s", actor_n .. "'s");
    out = lit_replace(out, "${target}'s", target_n .. "'s");
    out = lit_replace(out, '${spell}', '');
    out = lit_replace(out, '${ability}', '');
    out = lit_replace(out, '${weapon_skill}', '');
    out = lit_replace(out, '${item}', '');
    out = lit_replace(out, '${actor}', actor_n);
    out = lit_replace(out, '${target}', target_n);
    out = lit_replace(out, '${number}', spikeNum);
    if (templ_has(templ, '${status}')) then
        out = lit_replace(out, '${status}', lookup_buff(m.spike_effect_param) or '');
    else
        out = lit_replace(out, '${status}', '');
    end
    out = lit_replace(out, '${lb}', '\n');
    out = out:gsub('\7', '\n');
    if (mode ~= nil and mode.condensedamage == true and (tonumber(m.spike_effect_number) or 1) > 1) then
        out = ('[%u] '):fmt(m.spike_effect_number) .. out;
    end
    local purpose = purpose_from_row(row, msg_id);
    return purpose, out;
end

function M.emit_0x28(e, append_cb, combat_event_cb, full_act_cb)
    if (append_cb == nil or e == nil or e.data == nil) then
        return;
    end
    if (load_res_actmsg() == nil) then
        return;
    end

    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;

    local raw = e.data;
    if (raw == nil or #raw < 4) then
        return;
    end

    skill_tables.ensure();

    local act = packet_codec.string_to_act(raw);
    if (act == nil or act.targets == nil or #act.targets == 0) then
        local legacyHeader = (chat ~= nil and chat.actionPacket28LegacyHeader == true);
        act = action_packet28.parse_action_packet(raw, legacyHeader);
        if (act == nil or act.targets == nil or #act.targets == 0) then
            act = action_packet28.parse_action_packet(raw, not legacyHeader);
        end
    end
    if (act == nil or act.targets == nil or #act.targets == 0) then
        return;
    end

    act.size = raw:byte(5);
    if (act.target_count == nil) then
        act.target_count = #act.targets;
    end

    -- Feed the combat parser the RAW, pre-condense packet -- condensing below
    -- merges/sums swings, which would destroy hit/miss/multi-attack counts.
    if (full_act_cb ~= nil) then
        if (act.actor == nil) then
            act.actor = actor_parse.parse(act.actor_id);
        end
        pcall(full_act_cb, act);
    end

    local mode = mode_options.get_mode(chat);
    act = condense_action_packet.run(act, mode, function()
        return true;
    end);

    if (act.actor == nil) then
        act.actor = actor_parse.parse(act.actor_id);
    end

    emit_combat_events(act, combat_event_cb);

    for _, tgt in ipairs(act.targets or {}) do
        local sid = tgt.server_id;
        for __, m in ipairs(tgt.actions or {}) do
            local p, line = format_action_line(act, sid, m, mode);
            if (p ~= nil and line ~= nil and line ~= '') then
                append_cb(p, line);
            end
            local ap, al = emit_add_effect_line(act, sid, m, mode);
            if (ap ~= nil and al ~= nil and al ~= '') then
                append_cb(ap, al);
            end
            local sp, sl = emit_spike_line(act, sid, m, mode);
            if (sp ~= nil and sl ~= nil and sl ~= '') then
                append_cb(sp, sl);
            end
        end
    end
end

function M.emit_0x29(e, append_cb)
    if (append_cb == nil or e == nil or e.data == nil or #e.data < 0x1A) then
        return;
    end
    if (load_res_actmsg() == nil) then
        return;
    end

    local d = e.data;
    local actor_id = struct.unpack('I', d, 0x05);
    local target_id = struct.unpack('I', d, 0x09);
    local param_1 = struct.unpack('I', d, 0x0D);
    local param_2 = struct.unpack('I', d, 0x11);
    local message_id = struct.unpack('H', d, 0x19) % 32768;

    if (message_id == 0 or res_actmsg[message_id] == nil) then
        return;
    end

    if (roe_regime.is_progress_message(message_id)) then
        local roe_line = roe_regime.format_progress_line(message_id, param_1, param_2);
        if (roe_line ~= nil and roe_line ~= '') then
            append_cb(roe_regime.purpose(), roe_line);
            return;
        end
    end

    local actor_tbl = actor_parse.parse(actor_id);
    local target_tbl = actor_parse.parse(target_id);
    local actor_n = (actor_tbl and actor_tbl.name) or '?';
    local target_n = (target_tbl and target_tbl.name) or '?';

    local row = res_actmsg[message_id];
    local retail_en = row.en;
    local templ = retail_en;
    if (templ == nil or templ == '') then
        return;
    end

    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    local mode = mode_options.get_mode(chat);

    local fields_tab = simplify_combat.search_fields(retail_en);
    if (mode.simplify == true) then
        simplify_combat.apply_field_overrides(message_id, fields_tab);
        local pt = simplify_combat.pick_template(message_id, fields_tab);
        if (pt ~= nil) then
            templ = pt;
        end
    end

    local spell = '';
    local ability = '';
    local ws = '';
    local item = '';

    if (templ_has(templ, '${spell}')) then
        spell = skill_nonempty(lookup_spell(param_1)) or ('#' .. tostring(param_1));
    end
    if (templ_has(templ, '${ability}')) then
        ability = skill_nonempty(spellparse_ability_name(param_1)) or ('#' .. tostring(param_1));
    end
    if (templ_has(templ, '${weapon_skill}')) then
        ws = skill_nonempty(spellparse_weapon_skill_name(param_1)) or ('#' .. tostring(param_1));
    end
    if (templ_has(templ, '${item}')) then
        item = skill_nonempty(lookup_item(param_1)) or ('#' .. tostring(param_1));
    end

    local item2 = '';
    if (templ_has(templ, '${item2}')) then
        item2 = skill_nonempty(lookup_item(param_2)) or ('#' .. tostring(param_2));
    end

    local abil = '';
    if (mode.simplify == true) then
        if (spell ~= '') then
            abil = spell;
        elseif (ability ~= '') then
            abil = ability;
        elseif (ws ~= '') then
            abil = ws;
        elseif (item ~= '') then
            abil = item;
        end
    end

    local status = '';
    if (templ_has(templ, '${status}')) then
        status = lookup_buff(param_1) or '';
    end

    local out = templ;
    out = lit_replace(out, '${abil}', abil);
    out = lit_replace(out, "${actor}'s", actor_n .. "'s");
    out = lit_replace(out, "${target}'s", target_n .. "'s");
    out = lit_replace(out, '${spell}', spell);
    out = lit_replace(out, '${ability}', ability);
    out = lit_replace(out, '${weapon_skill}', ws);
    out = lit_replace(out, '${item}', item);
    out = lit_replace(out, '${item2}', item2);
    out = lit_replace(out, '${actor}', actor_n);
    out = lit_replace(out, '${target}', target_n);
    if (templ_has(templ, '${regime}')) then
        local regime = roe_regime.lookup_regime_name(param_1) or ('#' .. tostring(param_1));
        out = lit_replace(out, '${regime}', regime);
    end
    out = lit_replace(out, '${number}', tostring(param_1));
    out = lit_replace(out, '${numb}', tostring(param_1));
    out = lit_replace(out, '${number2}', tostring(param_2));
    out = lit_replace(out, '${status}', status);
    if (templ_has(templ, '${skill}')) then
        out = lit_replace(out, '${skill}', lookup_skill(param_1) or '');
    else
        out = lit_replace(out, '${skill}', '');
    end
    if (templ_has(templ, '${gil}')) then
        local g = tonumber(param_1) or 0;
        out = lit_replace(out, '${gil}', tostring(g) .. ' gil');
    end
    out = lit_replace(out, '${lb}', '\n');

    out = out:gsub('\7', '\n');
    local purpose = purpose_from_row(row, message_id);
    append_cb(purpose, out);
end

function M.emit_packet(e, append_cb, combat_event_cb, full_act_cb)
    if (e == nil or append_cb == nil) then
        return;
    end
    if (e.id == 0x28) then
        M.emit_0x28(e, append_cb, combat_event_cb, full_act_cb);
    elseif (e.id == 0x29) then
        M.emit_0x29(e, append_cb);
    end
end

return M;
