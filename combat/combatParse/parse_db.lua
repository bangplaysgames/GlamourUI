--[[
    Combat parser accumulator engine (global gParseDB).

    Fed the *raw, pre-condense* decoded action packet (act) from
    packet_chat_emit.lua M.emit_0x28 -- see the full_act_cb hook there. Condensing
    merges/sums swings, which would destroy hit/miss/multi-attack counts, so the
    parser must see the un-condensed packet.

    Maintains scopes:
      battle -- selectable fight history + one live bucket; idle starts a new
              fight without discarding previous battles.
      total  -- cumulative; only cleared on command / Reset Total.

    No imgui here; ui/parse_window.lua reads the query API and draws.

    Scope tracking matches the user's choice: party + alliance players
    (player-side combatants), plus damage *taken* from mobs (credited to the
    player target, for the Defense view). Pet offense is rolled into the owner's
    parse as dmg.pet (via the owner id in the action packet). Mob offense tables
    are not tracked, so mob actors never become combatants.
]]--

require('common');

local actor_parse = require('actor_parse');
local parse_classify = require('parse_classify');
local combat_filters = require('combat_filters');
local trust_detect = require('trust_detect');
local parse_timeline_log = require('parse_timeline_log');
local packet_chat_emit = require('packet_chat_emit');

local M = {};

-- Keyed by actor_parse's `filter` field (NOT `type`, which is a raw slot id
-- like p0/p1/al0). trust resolves to filter 'party'.
local PLAYER_SIDES = {
    me = true, party = true, alliance = true,
    my_pet = true, other_pets = true,
};

-- serverId -> actor_parse result, cleared on zone. actor_parse.parse scans
-- entities 0..2303 per call, so the parser must not pay that per action.
local sideCache = {};
-- serverId -> bool trust flag (cached; see trust_detect).
local function sid_is_trust(sid)
    return trust_detect.sid_is_trust(sid);
end

local function classify_sid(sid)
    sid = tonumber(sid) or 0;
    if (sid == 0) then
        return nil;
    end
    local c = sideCache[sid];
    if (c ~= nil) then
        return c;
    end
    local ok, res = pcall(function()
        return actor_parse.parse(sid);
    end);
    if (not ok or res == nil) then
        return nil;
    end
    sideCache[sid] = res;
    return res;
end

-- Gaps between actions longer than this (seconds) are treated as downtime
-- (looting, travel, repositioning) and excluded from the active fight time used
-- for DPS -- otherwise DPS reads far too low when a "battle" spans several mobs.
local ACTIVE_GAP_CAP = 10.0;

local function new_scope()
    return {
        id = nil,
        start_clock = nil,
        last_clock = nil,
        last_engagement_clock = nil,
        end_clock = nil,
        active = 0,
        ended = false,
        endedReason = nil,
        combatants = {},
        events = {},
    };
end

local battleCounter = 0;

local state = {
    battles = {},
    current = new_scope(),
    total = new_scope(),
    viewBattleId = nil,
};

local function ensure_battle_id(scope)
    if (scope.id == nil) then
        battleCounter = battleCounter + 1;
        scope.id = battleCounter;
    end
end

local function battle_has_data(scope)
    if (scope == nil) then
        return false;
    end
    if (scope.start_clock ~= nil) then
        return true;
    end
    if (scope.events ~= nil and #scope.events > 0) then
        return true;
    end
    return next(scope.combatants or {}) ~= nil;
end

local function finalize_battle(scope, reason, now)
    if (not battle_has_data(scope)) then
        return nil;
    end
    ensure_battle_id(scope);
    scope.ended = true;
    scope.endedReason = reason;
    scope.end_clock = now;
    return scope;
end

local function archive_current(reason, now)
    now = tonumber(now) or os.clock();
    local b = state.current;
    if (not battle_has_data(b)) then
        state.current = new_scope();
        return;
    end
    local archivedId = b.id;
    parse_timeline_log.end_battle(b, reason, now);
    local finalized = finalize_battle(b, reason, now);
    if (finalized ~= nil) then
        state.battles[#state.battles + 1] = finalized;
    end
    state.current = new_scope();
    if (archivedId ~= nil and state.viewBattleId == archivedId) then
        state.viewBattleId = nil;
    end
end

-- actor_parse exposes a pet's owner as a party SLOT KEY (p0/p1/al0/a20, where
-- 'p'=base 0, 'al'=base 6, 'a2'=base 12). Resolve it to the owner's name or sid.
local function party_slot_index(slotKey)
    if (type(slotKey) ~= 'string') then
        return nil;
    end
    local prefix, num = slotKey:match('^(%a+)(%d+)$');
    if (prefix == nil) then
        return nil;
    end
    local base = ({ p = 0, al = 6, a2 = 12 })[prefix];
    if (base == nil) then
        return nil;
    end
    return base + tonumber(num);
end

local function owner_name_from_slot(slotKey)
    local idx = party_slot_index(slotKey);
    if (idx == nil) then
        return nil;
    end
    local party = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (party == nil) then
        return nil;
    end
    local ok, nm = pcall(function()
        return party:GetMemberName(idx);
    end);
    if (ok and nm ~= nil and nm ~= '') then
        return nm;
    end
    return nil;
end

local function owner_sid_from_slot(slotKey)
    local idx = party_slot_index(slotKey);
    if (idx == nil) then
        return 0;
    end
    local party = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (party == nil) then
        return 0;
    end
    local ok, sid = pcall(function()
        return party:GetMemberServerId(idx);
    end);
    if (ok and sid ~= nil and sid > 0) then
        return sid;
    end
    return 0;
end

-- Pet action packets carry the owner's server id in act.info (retail layout) /
-- act.recast (legacy packet_codec field at the same bit offset).
local function pet_owner_sid_from_packet(act, actorOwner)
    local sid = tonumber(act.info) or tonumber(act.recast) or 0;
    if (sid > 0) then
        return sid;
    end
    return owner_sid_from_slot(actorOwner);
end

local function new_combatant(sid, name, side, ownerSid, now)
    return {
        sid = sid,
        name = name or ('?#' .. tostring(sid)),
        side = side or 'other',
        owner = ownerSid,
        ownerName = nil,
        isTrust = false,
        dmg = { total = 0, melee = 0, ranged = 0, ws = 0, magic = 0, ability = 0, pet = 0, add = 0 },
        acc = {
            melee  = { hit = 0, miss = 0, crit = 0, rounds = 0 },
            ranged = { hit = 0, miss = 0, crit = 0 },
        },
        ws = { count = 0, total = 0, max = 0 },
        magic = { count = 0, total = 0, bursts = 0, burstDmg = 0 },
        heal = { total = 0, count = 0 },
        taken = { total = 0, hits = 0, evaded = 0, parried = 0, shadows = 0, tpMoves = 0 },
        first_clock = now,
        last_clock = now,
    };
end

local function settings()
    return GlamourUI and GlamourUI.settings and GlamourUI.settings.Parse or nil;
end

local function idle_timeout()
    local s = settings();
    local t = s and tonumber(s.idleTimeout) or nil;
    if (t == nil or t < 1) then
        return 12.0;
    end
    return t;
end

--- Damage / taken activity (not heals) — used so trust regen between pulls does not block splits.
local function counts_as_engagement(r)
    if (r == nil or r.bucket == nil or r.bucket == 'none' or r.bucket == 'heal') then
        return false;
    end
    return true;
end

local function engagement_clock(scope)
    if (scope == nil) then
        return nil;
    end
    return scope.last_engagement_clock or scope.last_clock;
end

local function maybe_archive_idle(now)
    now = tonumber(now) or os.clock();
    local b = state.current;
    local last = engagement_clock(b);
    if (battle_has_data(b) and last ~= nil and (now - last) > idle_timeout()) then
        archive_current('idle', now);
        return true;
    end
    return false;
end

local function touch_scope(scope, now)
    ensure_battle_id(scope);
    if (scope.start_clock == nil) then
        scope.start_clock = now;
    elseif (scope.last_clock ~= nil) then
        -- Accumulate active fight time, skipping downtime gaps.
        local delta = now - scope.last_clock;
        if (delta > 0 and delta <= ACTIVE_GAP_CAP) then
            scope.active = (scope.active or 0) + delta;
        end
    end
    scope.last_clock = now;
    scope.ended = false;
end

local function get_combatant(scope, sid, name, side, ownerSid, now, isTrust)
    local c = scope.combatants[sid];
    if (c == nil) then
        c = new_combatant(sid, name, side, ownerSid, now);
        scope.combatants[sid] = c;
    else
        if (name ~= nil and name ~= '' and (c.name == nil or c.name:sub(1, 2) == '?#')) then
            c.name = name;
        end
        if (side ~= nil and side ~= 'other') then
            c.side = side;
        end
        if (ownerSid ~= nil and c.owner == nil) then
            c.owner = ownerSid;
        end
    end
    if (isTrust == true) then
        c.isTrust = true;
    end
    -- Resolve the owner's display name for pets (owner is a party slot key).
    if ((c.side == 'my_pet' or c.side == 'other_pets') and c.ownerName == nil and c.owner ~= nil) then
        c.ownerName = owner_name_from_slot(c.owner);
    end
    c.last_clock = now;
    return c;
end

local function apply_offense(c, r, action)
    if (r.isHit) then
        c.dmg.total = c.dmg.total + r.value;
        local b = r.bucket;
        if (c.dmg[b] ~= nil) then
            c.dmg[b] = c.dmg[b] + r.value;
        end
    end

    if (r.bucket == 'melee') then
        c.acc.melee.rounds = c.acc.melee.rounds + 1;
        if (r.isHit) then
            c.acc.melee.hit = c.acc.melee.hit + 1;
            if (r.isCrit) then c.acc.melee.crit = c.acc.melee.crit + 1; end
        elseif (r.isMiss) then
            c.acc.melee.miss = c.acc.melee.miss + 1;
        end
    elseif (r.bucket == 'ranged') then
        if (r.isHit) then
            c.acc.ranged.hit = c.acc.ranged.hit + 1;
            if (r.isCrit) then c.acc.ranged.crit = c.acc.ranged.crit + 1; end
        elseif (r.isMiss) then
            c.acc.ranged.miss = c.acc.ranged.miss + 1;
        end
    elseif (r.bucket == 'ws' and r.isHit) then
        c.ws.count = c.ws.count + 1;
        c.ws.total = c.ws.total + r.value;
        if (r.value > c.ws.max) then c.ws.max = r.value; end
    elseif (r.bucket == 'magic' and r.isHit) then
        c.magic.count = c.magic.count + 1;
        c.magic.total = c.magic.total + r.value;
        if (r.isBurst) then
            c.magic.bursts = c.magic.bursts + 1;
            c.magic.burstDmg = c.magic.burstDmg + r.value;
        end
    end

    -- Additional-effect / spike damage procs, credited to the actor.
    local add = parse_classify.add_effect_damage(action);
    if (add > 0) then
        c.dmg.add = c.dmg.add + add;
        c.dmg.total = c.dmg.total + add;
    end
end

local function apply_taken(c, r)
    c.taken.tpMoves = c.taken.tpMoves + (r.isTpMove and 1 or 0);
    if (r.isShadow) then
        c.taken.shadows = c.taken.shadows + 1;
    elseif (r.isParry) then
        c.taken.parried = c.taken.parried + 1;
    elseif (r.isEvade) then
        c.taken.evaded = c.taken.evaded + 1;
    elseif (r.isHit) then
        c.taken.hits = c.taken.hits + 1;
        c.taken.total = c.taken.total + r.value;
    end
end

local function timeline_actor(sid, name, side, isTrust)
    return {
        sid = tonumber(sid) or 0,
        name = name,
        side = side,
        trust = isTrust == true,
    };
end

local function timeline_action(action)
    if (action == nil) then
        return nil;
    end
    return {
        message = tonumber(action.message) or 0,
        param = tonumber(action.param) or 0,
        reaction = tonumber(action.reaction) or 0,
        animation = tonumber(action.animation) or 0,
        effect = tonumber(action.effect) or 0,
    };
end

local function timeline_result(r, addEffect)
    if (r == nil) then
        return nil;
    end
    local out = {
        bucket = r.bucket,
        value = r.value or 0,
        isHit = r.isHit == true,
        isMiss = r.isMiss == true,
        isCrit = r.isCrit == true,
        isBurst = r.isBurst == true,
        isParry = r.isParry == true,
        isEvade = r.isEvade == true,
        isShadow = r.isShadow == true,
        isTpMove = r.isTpMove == true,
    };
    if (addEffect ~= nil and addEffect > 0) then
        out.addEffect = addEffect;
    end
    return out;
end

local function shallow_copy_event(entry)
    local out = {};
    for k, v in pairs(entry) do
        out[k] = v;
    end
    return out;
end

local function log_timeline_event(scope, now, act, actor, target, action, r, petSource)
    local addEffect = parse_classify.add_effect_damage(action);
    if (not parse_classify.is_timeline_damage(r, addEffect)) then
        return;
    end
    local entry = {
        actor = actor,
        petSource = petSource,
        target = target,
        act = {
            category = tonumber(act.category) or 0,
            param = tonumber(act.param) or 0,
            info = tonumber(act.info) or tonumber(act.recast) or 0,
        },
        action = timeline_action(action),
        result = timeline_result(r, addEffect),
    };
    if (scope.start_clock == nil) then
        scope.start_clock = now;
    end
    entry.t = now - scope.start_clock;
    entry.abilityName = packet_chat_emit.resolve_timeline_ability_name(act, action, entry.result);
    scope.events[#scope.events + 1] = entry;
    parse_timeline_log.log_event(now, shallow_copy_event(entry));
end

local function ingest_into(scope, act, now)
    local actorSide = act.actor and act.actor.filter or nil;
    local actorSid = tonumber(act.actor_id) or 0;
    local actorName = act.actor and act.actor.name or nil;
    local actorOwner = act.actor and act.actor.owner or nil;
    local petSource = nil;
    -- Trust-ness is read from the entity (party trusts are matched by
    -- actor_parse's party loop and get type 'p1', so `type=='trust'` misses them).
    local actorIsTrust = sid_is_trust(actorSid);
    local actorIsPlayerSide = (actorSide ~= nil and PLAYER_SIDES[actorSide] == true);

    -- Credit pet offense/healing to the owner as dmg.pet, not a separate row.
    if (actorSide == 'my_pet' or actorSide == 'other_pets') then
        petSource = timeline_actor(actorSid, actorName, actorSide, actorIsTrust);
        local ownerSid = pet_owner_sid_from_packet(act, actorOwner);
        if (ownerSid <= 0) then
            actorIsPlayerSide = false;
        else
            local oinfo = classify_sid(ownerSid);
            if (oinfo == nil or PLAYER_SIDES[oinfo.filter] ~= true) then
                actorIsPlayerSide = false;
            else
                actorSid = ownerSid;
                actorSide = oinfo.filter;
                actorName = oinfo.name;
                actorOwner = nil;
                actorIsTrust = false;
            end
        end
    end

    if (actorIsPlayerSide and not combat_filters.parser_tracks_actor(actorSide, actorIsTrust)) then
        actorIsPlayerSide = false;
    end

    local touched = false;

    for _, tgt in ipairs(act.targets or {}) do
        local tinfo = classify_sid(tgt.server_id);
        local tside = tinfo and tinfo.filter or nil;
        local tname = tinfo and tinfo.name or nil;
        local tIsTrust = sid_is_trust(tgt.server_id);

        for _, action in ipairs(tgt.actions or {}) do
            local r = parse_classify.classify(act, action, tside);
            if (r.bucket ~= 'none') then
                if (r.bucket == 'taken') then
                    if (combat_filters.parser_tracks_actor(tside, tIsTrust)) then
                        local c = get_combatant(scope, tgt.server_id, tname, tside,
                            tinfo and tinfo.owner or nil, now, tIsTrust);
                        apply_taken(c, r);
                        if (scope == state.current) then
                            log_timeline_event(scope, now, act,
                                timeline_actor(actorSid, actorName, actorSide, actorIsTrust),
                                timeline_actor(tgt.server_id, tname, tside, tIsTrust),
                                action, r, nil);
                            scope.last_engagement_clock = now;
                        end
                        touched = true;
                    end
                elseif (actorIsPlayerSide) then
                    local c = get_combatant(scope, actorSid, actorName, actorSide, actorOwner, now, actorIsTrust);
                    local skipPet = (r.bucket == 'pet' and not combat_filters.parser_tracks_pet_damage_for(actorSide));
                    if (r.bucket == 'heal') then
                        c.heal.total = c.heal.total + r.value;
                        if (r.value > 0) then c.heal.count = c.heal.count + 1; end
                        touched = true;
                    elseif (not skipPet) then
                        apply_offense(c, r, action);
                        if (scope == state.current) then
                            log_timeline_event(scope, now, act,
                                timeline_actor(actorSid, actorName, actorSide, actorIsTrust),
                                timeline_actor(tgt.server_id, tname, tside, tIsTrust),
                                action, r, petSource);
                            if (counts_as_engagement(r)) then
                                scope.last_engagement_clock = now;
                            end
                        end
                        touched = true;
                    end
                end
            end
        end
    end

    if (touched) then
        touch_scope(scope, now);
    end
    return touched;
end

--- Feed a raw decoded action packet (act.actor already classified by caller).
function M.ingest(act)
    if (act == nil or act.targets == nil) then
        return;
    end
    local s = settings();
    if (s ~= nil and s.enabled == false) then
        return;
    end

    local now = os.clock();

    maybe_archive_idle(now);

    ingest_into(state.current, act, now);
    ingest_into(state.total, act, now);
end

--- Per-frame: archive the live battle once combat has been idle past the timeout.
function M.tick()
    maybe_archive_idle(os.clock());
end

-- ---- Query API (read by ui/parse_window.lua) ------------------------------

local function find_battle_by_id(id)
    id = tonumber(id);
    if (id == nil) then
        return nil;
    end
    if (state.current.id == id) then
        return state.current;
    end
    for i = 1, #state.battles do
        local b = state.battles[i];
        if (b.id == id) then
            return b;
        end
    end
    return nil;
end

local function resolve_battle_scope()
    if (state.viewBattleId ~= nil) then
        local b = find_battle_by_id(state.viewBattleId);
        if (b ~= nil) then
            return b;
        end
    end
    if (battle_has_data(state.current)) then
        return state.current;
    end
    local last = state.battles[#state.battles];
    if (last ~= nil) then
        return last;
    end
    return state.current;
end

function M.set_view_battle(id)
    state.viewBattleId = tonumber(id);
end

function M.get_view_battle_id()
    return resolve_battle_scope().id;
end

function M.battle_catalog()
    local list = {};
    for i = 1, #state.battles do
        local b = state.battles[i];
        list[#list + 1] = {
            id = b.id,
            index = i,
            duration = math.max(0, tonumber(b.active) or 0),
            ended = true,
            live = false,
            events = #(b.events or {}),
            reason = b.endedReason,
        };
    end
    if (battle_has_data(state.current)) then
        local c = state.current;
        list[#list + 1] = {
            id = c.id,
            index = #state.battles + 1,
            duration = math.max(0, tonumber(c.active) or 0),
            ended = false,
            live = true,
            events = #(c.events or {}),
            reason = nil,
        };
    end
    return list;
end

function M.battle_timeline_events(battleId)
    local b = find_battle_by_id(battleId);
    if (b == nil) then
        return {};
    end
    return b.events or {};
end

function M.battle_timeline_duration(battleId)
    local b = find_battle_by_id(battleId);
    if (b == nil) then
        return 0;
    end
    local dur = math.max(0, tonumber(b.active) or 0);
    local events = b.events or {};
    if (#events > 0) then
        local lastT = tonumber(events[#events].t) or 0;
        if (lastT > dur) then
            dur = lastT;
        end
    end
    if (dur <= 0 and b.start_clock ~= nil and b.end_clock ~= nil) then
        dur = math.max(0, b.end_clock - b.start_clock);
    end
    return dur;
end

--- Live timeline: current battle event log (always state.current, not view scope).
function M.live_timeline_events()
    return state.current.events or {};
end

--- Wall-clock seconds since the current battle started (battle start -> now).
function M.live_timeline_elapsed()
    local c = state.current;
    if (not battle_has_data(c) or c.start_clock == nil) then
        return 0;
    end
    return math.max(0, os.clock() - c.start_clock);
end

function M.live_timeline_battle_id()
    if (not battle_has_data(state.current)) then
        return nil;
    end
    return state.current.id;
end

function M.get_scope(name)
    if (name == 'total') then
        return state.total;
    end
    return resolve_battle_scope();
end

--- Seconds of ACTIVE combat in a scope (downtime gaps excluded), used as the
--- DPS denominator and shown as the duration.
function M.scope_duration(name)
    local s = M.get_scope(name);
    return math.max(0, tonumber(s.active) or 0);
end

--- Per-combatant DPS uses the SCOPE (encounter) duration as the denominator --
--- the same one raid DPS uses -- so individual DPS values sum to the raid total
--- and don't spike for someone with a short personal active window.
function M.dps(name, c)
    local secs = M.scope_duration(name);
    if (secs < 1) then secs = 1; end
    return (c.dmg.total or 0) / secs;
end

--- Player-side combatants sorted by a key ('damage'|'dps'|'healing'|'taken'|'name').
function M.combatant_list(name, sortKey)
    local scope = M.get_scope(name);
    local list = {};
    for _, c in pairs(scope.combatants) do
        if (PLAYER_SIDES[c.side] == true and combat_filters.parser_allows_combatant(c)) then
            list[#list + 1] = c;
        end
    end
    sortKey = sortKey or 'damage';
    table.sort(list, function(a, b)
        if (sortKey == 'name') then
            return tostring(a.name) < tostring(b.name);
        elseif (sortKey == 'healing') then
            return (a.heal.total or 0) > (b.heal.total or 0);
        elseif (sortKey == 'taken') then
            return (a.taken.total or 0) > (b.taken.total or 0);
        elseif (sortKey == 'dps') then
            return M.dps(name, a) > M.dps(name, b);
        end
        return (a.dmg.total or 0) > (b.dmg.total or 0);
    end);
    return list;
end

--- Sum of VISIBLE player-side damage in a scope (respects the player filter so
--- % bars / raid totals recompute over the shown groups only).
function M.total_damage(name)
    local scope = M.get_scope(name);
    local sum = 0;
    for _, c in pairs(scope.combatants) do
        if (PLAYER_SIDES[c.side] == true and combat_filters.parser_allows_combatant(c)) then
            sum = sum + (c.dmg.total or 0);
        end
    end
    return sum;
end

function M.raid_dps(name)
    local secs = M.scope_duration(name);
    if (secs < 1) then secs = 1; end
    return M.total_damage(name) / secs;
end

-- ---- Accuracy / rate helpers ----------------------------------------------

local function rate(hit, total)
    total = total or 0;
    if (total <= 0) then return 0; end
    return hit / total;
end

function M.melee_accuracy(c)
    return rate(c.acc.melee.hit, c.acc.melee.hit + c.acc.melee.miss);
end

function M.ranged_accuracy(c)
    return rate(c.acc.ranged.hit, c.acc.ranged.hit + c.acc.ranged.miss);
end

function M.melee_crit_rate(c)
    return rate(c.acc.melee.crit, c.acc.melee.hit);
end

--- Average hits per melee round (>1 indicates multi-attack).
function M.hits_per_round(c)
    if ((c.acc.melee.rounds or 0) <= 0) then return 0; end
    return c.acc.melee.hit / c.acc.melee.rounds;
end

function M.ws_average(c)
    if ((c.ws.count or 0) <= 0) then return 0; end
    return c.ws.total / c.ws.count;
end

-- ---- Lifecycle ------------------------------------------------------------

function M.reset_battle()
    archive_current('reset', os.clock());
end

function M.reset_total()
    state.total = new_scope();
end

function M.reset_all()
    if (battle_has_data(state.current)) then
        parse_timeline_log.end_battle(state.current, 'reset_all', os.clock());
    end
    state.battles = {};
    state.current = new_scope();
    state.total = new_scope();
    state.viewBattleId = nil;
    battleCounter = 0;
end

--- Called on zone change: drop the entity classification cache (server ids and
--- party layout change across zones).
function M.on_zone()
    sideCache = {};
    trust_detect.clear_cache();
end

return M;
