--[[
    Combat parser accumulator engine (global gParseDB).

    Fed the *raw, pre-condense* decoded action packet (act) from
    packet_chat_emit.lua M.emit_0x28 -- see the full_act_cb hook there. Condensing
    merges/sums swings, which would destroy hit/miss/multi-attack counts, so the
    parser must see the un-condensed packet.

    Maintains two scopes:
      battle -- the current fight; auto-resets after a combat-idle timeout.
      total  -- cumulative; only cleared on command / Reset Total.

    No imgui here; ui/parse_window.lua reads the query API and draws.

    Scope tracking matches the user's choice: party + alliance + their pets
    (player-side combatants), plus damage *taken* from mobs (credited to the
    player target, for the Defense view). Mob offense tables are not tracked, so
    mob actors never become combatants.
]]--

require('common');

local actor_parse = require('actor_parse');
local parse_classify = require('parse_classify');
local combat_filters = require('combat_filters');

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
-- serverId -> bool trust flag (cached; the entity scan is expensive). A party
-- trust is matched by actor_parse's party loop and gets type 'p1', NOT 'trust',
-- so trust-ness must be read from the entity (same test chatPartyNames uses).
local trustCache = {};

local function sid_is_trust(sid)
    sid = tonumber(sid) or 0;
    if (sid == 0) then
        return false;
    end
    local cached = trustCache[sid];
    if (cached ~= nil) then
        return cached;
    end
    local res = false;
    if (GetEntity ~= nil) then
        for x = 0, 2303 do
            local e = GetEntity(x);
            if (e ~= nil and e.ServerId == sid) then
                local sf = tonumber(e.SpawnFlags) or 0;
                res = (bit.band(sf, 0x1000) == 0x1000) or ((tonumber(e.TrustOwnerTargetIndex) or 0) > 0);
                break;
            end
        end
    end
    trustCache[sid] = res;
    return res;
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
    return { start_clock = nil, last_clock = nil, active = 0, ended = false, combatants = {} };
end

-- actor_parse exposes a pet's owner as a party SLOT KEY (p0/p1/al0/a20, where
-- 'p'=base 0, 'al'=base 6, 'a2'=base 12). Resolve it to the owner's name.
local function owner_name_from_slot(slotKey)
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
    local idx = base + tonumber(num);
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

local state = {
    battle = new_scope(),
    total = new_scope(),
};

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

local function touch_scope(scope, now)
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

-- Pets get a NEW server id every time they are released and resummoned, so
-- keying combatants by sid would list the same pet multiple times for one owner.
-- Key pets by owner-slot + pet name instead so a resummon compiles into the
-- existing entry. Non-pets stay keyed by sid.
local function combatant_key(side, sid, ownerSid, name)
    if ((side == 'my_pet' or side == 'other_pets') and name ~= nil and name ~= '') then
        return 'pet:' .. tostring(ownerSid or '?') .. ':' .. tostring(name);
    end
    return sid;
end

local function get_combatant(scope, sid, name, side, ownerSid, now, isTrust)
    local key = combatant_key(side, sid, ownerSid, name);
    local c = scope.combatants[key];
    if (c == nil) then
        c = new_combatant(sid, name, side, ownerSid, now);
        scope.combatants[key] = c;
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

local function ingest_into(scope, act, now)
    local actorSide = act.actor and act.actor.filter or nil;
    local actorSid = tonumber(act.actor_id) or 0;
    local actorName = act.actor and act.actor.name or nil;
    local actorOwner = act.actor and act.actor.owner or nil;
    -- Trust-ness is read from the entity (party trusts are matched by
    -- actor_parse's party loop and get type 'p1', so `type=='trust'` misses them).
    local actorIsTrust = sid_is_trust(actorSid);
    local actorIsPlayerSide = (actorSide ~= nil and PLAYER_SIDES[actorSide] == true);

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
                    -- Credit the player-side target taking the hit.
                    local c = get_combatant(scope, tgt.server_id, tname, tside,
                        tinfo and tinfo.owner or nil, now, tIsTrust);
                    apply_taken(c, r);
                    touched = true;
                elseif (actorIsPlayerSide) then
                    local c = get_combatant(scope, actorSid, actorName, actorSide, actorOwner, now, actorIsTrust);
                    if (r.bucket == 'heal') then
                        c.heal.total = c.heal.total + r.value;
                        if (r.value > 0) then c.heal.count = c.heal.count + 1; end
                    else
                        apply_offense(c, r, action);
                    end
                    touched = true;
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

    -- A fresh action after the current battle went idle starts a new battle
    -- (total already holds the cumulative numbers).
    if (state.battle.ended == true) then
        state.battle = new_scope();
    end

    ingest_into(state.battle, act, now);
    ingest_into(state.total, act, now);
end

--- Per-frame: freeze the current battle once combat has been idle past the timeout.
function M.tick()
    local b = state.battle;
    if (b.ended ~= true and b.last_clock ~= nil) then
        if ((os.clock() - b.last_clock) > idle_timeout()) then
            b.ended = true;
        end
    end
end

-- ---- Query API (read by ui/parse_window.lua) ------------------------------

function M.get_scope(name)
    if (name == 'total') then
        return state.total;
    end
    return state.battle;
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
        if (PLAYER_SIDES[c.side] == true and combat_filters.parser_allows_side(c.side)) then
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
        if (PLAYER_SIDES[c.side] == true and combat_filters.parser_allows_side(c.side)) then
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
    state.battle = new_scope();
end

function M.reset_total()
    state.total = new_scope();
end

function M.reset_all()
    state.battle = new_scope();
    state.total = new_scope();
end

--- Called on zone change: drop the entity classification cache (server ids and
--- party layout change across zones).
function M.on_zone()
    sideCache = {};
    trustCache = {};
end

return M;
