--[[
    Second, separate toast queue/window: alliance member weapon skills, spell casts,
    skillchains, and magic bursts. Restricted to alliance members only -- never
    random players or mobs. Mirrors ui/toasts.lua's API/timing model but
    keeps its own queue and settings (GlamourUI.settings.CombatToasts) so it renders as
    an independent window from the "you obtained X" toasts.

    Also tracks skillchain-opening actions PER TARGET (mob), not globally -- the
    skillchain helper panel (ui/render.lua render_skillchain_panel) only makes sense
    matched against whatever mob you're actually fighting; a global "last action"
    would show the wrong chain options the moment any party member hits a different
    target (split party, multiple mobs pulled, etc).
]]--

local skillchain_data = require('skillchain_data');
local combat_filters = require('combat_filters');

local M = {};

local active = {};
local nextId = 1;

-- targetId -> { targetId, targetName, name, skillchain, casterName, createdClock,
--   kind='ws'|'spell'|'pet', depth, windowOpen, windowClose }
local chainStateByTarget = {};

-- Skillchain window timing, mirrored from thotbar (state/skillchain.lua HandleActionPacket):
-- after a chain-opening action lands, the window to continue OPENS at +OPEN_DELAY and
-- CLOSES at +(CLOSE_BASE - depth). depth = how many links deep the chain already is
-- (0 for a fresh opener), which is why deeper chains have a tighter window.
local SC_WINDOW_OPEN_DELAY = 3.5;
local SC_WINDOW_CLOSE_BASE = 9.8;
local CHAIN_FADE_SEC = 1.5; -- after the window closes, how long the notification fades before removal

local function settings()
    return GlamourUI and GlamourUI.settings and GlamourUI.settings.CombatToasts or nil;
end

--- Returns the party/alliance slot index (0-17) for serverId, or nil if they're not in
--- the alliance and aren't the local player. FFXI layout: 0-5 party, 6-11 party 2,
--- 12-17 party 3.
local function find_party_slot(serverId)
    if (serverId == nil or serverId == 0) then
        return nil;
    end

    local party = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (party ~= nil) then
        for i = 0, 17 do
            local ok, id = pcall(function() return party:GetMemberServerId(i); end);
            if (ok and id ~= nil and id ~= 0 and id == serverId) then
                return i;
            end
        end
    end

    local selfEnt = GetPlayerEntity ~= nil and GetPlayerEntity() or nil;
    if (selfEnt ~= nil and selfEnt.ServerId == serverId) then
        return 0; -- self is always party slot 0 by FFXI convention, even when unpartied
    end
    return nil;
end

--- True only when actorServerId is the LOCAL player's own pet AND the player is
--- PUP or SMN -- the only pets whose TP moves drive the skillchain panel. Other
--- party members' pets (and DRG/BST pets) must never feed it.
local function is_local_skillchain_pet(actorServerId)
    local job = combat_filters.current_job();
    if (job ~= 'PUP' and job ~= 'SMN' and job ~= 'BST') then
        return false;
    end
    local p = (GetPlayerEntity ~= nil) and GetPlayerEntity() or nil;
    if (p == nil) then
        return false;
    end
    local petIdx = tonumber(p.PetTargetIndex) or 0;
    if (petIdx <= 0 or GetEntity == nil) then
        return false;
    end
    local petEnt = GetEntity(petIdx);
    return petEnt ~= nil and tonumber(petEnt.ServerId) == tonumber(actorServerId);
end

--- True if the entity in the given party slot currently has any of buffIds active.
--- Reuses GlamourUI's own existing buff tracking (core/resources.lua get_member_status,
--- self via GetBuffs(), other party members via the same packet/memory tracking the
--- party list UI already relies on) instead of rebuilding buff tracking from scratch.
local function actor_has_buff(serverId, partySlot, buffIds)
    if (gResources == nil or gResources.get_member_status == nil) then
        return false;
    end
    local ok, statusList = pcall(function() return gResources.get_member_status(serverId, partySlot); end);
    if (not ok or statusList == nil) then
        return false;
    end
    for i = 1, #statusList do
        for j = 1, #buffIds do
            if (statusList[i] == buffIds[j]) then
                return true;
            end
        end
    end
    return false;
end

local TOAST_ARROW = '→';

local HEADER_LABELS = {
    ws = 'Weaponskill',
    spell = 'Spell Cast',
    pet = 'Pet TP',
    skillchain = 'Skillchain',
};

local DEFAULT_COLORS = {
    ws = {1.0, 0.85, 0.3, 1.0},
    spell = {0.55, 0.8, 1.0, 1.0},
    pet = {0.6, 1.0, 0.6, 1.0},
    skillchain = {1.0, 0.95, 0.5, 1.0},
    magicBurst = {1.0, 0.45, 1.0, 1.0},
};

local function toast_header(event)
    if (event.magicBurst == true) then
        return 'Magic Burst';
    end
    if (event.kind == 'skillchain') then
        local sc = event.skillchainName;
        if (sc ~= nil and sc ~= '' and sc ~= 'Skillchain') then
            return ('Skillchain: %s'):fmt(sc);
        end
        return 'Skillchain';
    end
    return HEADER_LABELS[event.kind] or 'Combat';
end

local function format_toast_lines(event)
    local actor = event.actorName or '?';
    local ability = event.name or '?';
    local target = event.targetName;
    local detail;

    if (target ~= nil and target ~= '' and target ~= '?') then
        detail = ('%s: %s %s %s'):fmt(actor, ability, TOAST_ARROW, target);
    else
        detail = ('%s: %s'):fmt(actor, ability);
    end

    if (event.damage ~= nil and event.damage > 0) then
        detail = detail .. (' : %u'):fmt(event.damage);
    end

    return toast_header(event), detail;
end

local function toast_color(event)
    if (event.magicBurst == true) then
        return DEFAULT_COLORS.magicBurst;
    end
    if (event.kind == 'skillchain') then
        local sc = event.skillchainName;
        if (sc ~= nil and skillchain_data.colors[sc] ~= nil) then
            local c = skillchain_data.colors[sc];
            return { c[1], c[2], c[3], 1.0 };
        end
        return DEFAULT_COLORS.skillchain;
    end
    return DEFAULT_COLORS[event.kind] or {1.0, 1.0, 1.0, 1.0};
end

local function push_event(event, color)
    local s = settings();
    if (s == nil or s.enabled ~= true) then
        return;
    end

    local header, detail = format_toast_lines(event);
    if (detail == '') then
        return;
    end

    local maxStack = math.max(1, tonumber(s.maxStack) or 5);
    while (#active >= maxStack) do
        table.remove(active, 1);
    end

    active[#active + 1] = {
        id = nextId,
        header = header,
        detail = detail,
        text = header .. '\n' .. detail,
        color = color or {1.0, 1.0, 1.0, 1.0},
        createdClock = os.clock(),
        duration = tonumber(s.duration) or 10.0,
    };
    nextId = nextId + 1;
end

local function record_chain_state(event, skillchain, kind)
    if (event.targetId == nil or event.targetId == 0 or skillchain == nil) then
        return;
    end

    local now = os.clock();

    -- Depth tracking: if a chain-opening action lands on a target whose window is still
    -- open AND its properties actually continue the existing chain, it's a deeper link --
    -- bump depth (which tightens the next window, matching thotbar). Otherwise this starts
    -- a fresh chain at depth 0.
    local depth = 0;
    local prev = chainStateByTarget[event.targetId];
    if (prev ~= nil and prev.windowClose ~= nil and now < prev.windowClose) then
        if (skillchain_data.resolve_chain(prev.skillchain, skillchain) ~= nil) then
            depth = (prev.depth or 0) + 1;
        end
    end

    chainStateByTarget[event.targetId] = {
        targetId = event.targetId,
        targetName = event.targetName,
        id = event.abilId,
        name = event.name,
        skillchain = skillchain,
        casterName = event.actorName,
        createdClock = now,
        kind = kind,
        depth = depth,
        windowOpen = now + SC_WINDOW_OPEN_DELAY,
        windowClose = now + (SC_WINDOW_CLOSE_BASE - depth),
    };
end

--- Feed a combat_event_cb-shaped event (see packet_chat_emit.lua M.emit_0x28) in. Filters
--- to party members (incl. yourself). For spells: damaging elemental nukes always toast;
--- BLU physical spells under Chain Affinity/Azure Lore and SCH elemental spells under
--- Immanence also toast AND update the skillchain panel's per-target chain state, same
--- as a weapon skill would, since they carry real skillchain properties while buffed.
--- @param event table { kind='ws'|'spell', actorId, actorName, abilId, name, damage, targetId, targetName }
function M.handle_combat_event(event)
    if (event == nil) then
        return;
    end
    -- Category + player-group filtering (job-specific). Replaces the old
    -- party-only gate; 'others' is opt-in per job via the filter settings.
    if (not combat_filters.toast_allows(event)) then
        return;
    end

    if (event.kind == 'skillchain') then
        push_event(event, toast_color(event));
        return;
    end

    -- Pet TP moves: actor is the pet entity (never a party slot). Both the local
    -- player's pet and other party members' pets arrive here as kind='pet'.
    -- The skillchain panel must ONLY ever reflect the local player's OWN pet, and
    -- only when that pet is a PUP automaton / SMN avatar (is_local_skillchain_pet).
    if (event.kind == 'pet') then
        push_event(event, toast_color(event));
        if (is_local_skillchain_pet(event.actorId)) then
            -- Learn this pet's actual moveset so the chain-options panel offers only
            -- moves THIS pet can do, not every pet ability in the game.
            skillchain_data.note_pet_ability_used(event.abilId);
            local entry = skillchain_data.pet_skills[event.abilId];
            record_chain_state(event, entry and entry.skillchain or nil, 'pet');
        end
        return;
    end

    if (event.kind == 'ws') then
        push_event(event, toast_color(event));

        local entry = skillchain_data.weapon_skills[event.abilId];
        record_chain_state(event, entry and entry.skillchain or nil, 'ws');
    elseif (event.kind == 'spell') then
        local slot = find_party_slot(event.actorId);
        local chainProps = nil;
        if (skillchain_data.sch_spells[event.abilId] ~= nil
            and actor_has_buff(event.actorId, slot, { skillchain_data.IMMANENCE_BUFF_ID })) then
            chainProps = skillchain_data.sch_spells[event.abilId];
        elseif (skillchain_data.blu_spells[event.abilId] ~= nil
            and actor_has_buff(event.actorId, slot, { skillchain_data.AZURE_LORE_BUFF_ID, skillchain_data.CHAIN_AFFINITY_BUFF_ID })) then
            chainProps = skillchain_data.blu_spells[event.abilId];
        end

        if (event.damaging ~= true and chainProps == nil) then
            return;
        end
        push_event(event, toast_color(event));

        if (chainProps ~= nil) then
            record_chain_state(event, chainProps, 'spell');
        end
    end
end

function M.tick()
    local now = os.clock();

    local i = 1;
    while (i <= #active) do
        local t = active[i];
        if ((now - t.createdClock) >= t.duration) then
            table.remove(active, i);
        else
            i = i + 1;
        end
    end

    for targetId, state in pairs(chainStateByTarget) do
        local close = state.windowClose or (state.createdClock + SC_WINDOW_CLOSE_BASE);
        if ((now - close) >= CHAIN_FADE_SEC) then
            chainStateByTarget[targetId] = nil;
        end
    end
end

--- Phase of a chain state's skillchain window at `now`:
---   'pending' -> window hasn't opened yet (still in the post-action delay)
---   'open'    -> window is open; chain can be continued
---   'closing' -> window has closed; notification is fading out
---   'closed'  -> fully faded; caller should treat as gone
--- Returns (phase, secondsRemaining, alpha). secondsRemaining counts down to whichever
--- boundary is next (open during 'pending', close during 'open'); alpha is the fade factor.
function M.get_chain_window(state, now)
    now = now or os.clock();
    local open = state.windowOpen or state.createdClock;
    local close = state.windowClose or (state.createdClock + SC_WINDOW_CLOSE_BASE);
    if (now < open) then
        return 'pending', (open - now), 1.0;
    elseif (now < close) then
        return 'open', (close - now), 1.0;
    end
    local over = now - close;
    if (over >= CHAIN_FADE_SEC) then
        return 'closed', 0.0, 0.0;
    end
    return 'closing', 0.0, math.max(0.0, 1.0 - (over / CHAIN_FADE_SEC));
end

--- Server id of the player's current target, or nil if no target / not resolvable.
local function current_target_id()
    local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
    if (mm == nil or GetEntity == nil) then
        return nil;
    end
    local ok, targetIndex = pcall(function() return mm:GetTarget():GetTargetIndex(0); end);
    if (not ok or targetIndex == nil or targetIndex == 0) then
        return nil;
    end
    local ent = GetEntity(targetIndex);
    return ent and ent.ServerId or nil;
end

function M.get_active()
    return active;
end

--- Same timing model as ui/toasts.lua -- see that file for details.
function M.get_visual_state(toast, now)
    local s = settings();
    now = now or os.clock();
    local age = now - toast.createdClock;
    local duration = tonumber(toast.duration) or 10.0;
    local slideInDuration = math.max(0.01, tonumber(s and s.slideInDuration) or 0.25);
    local fadeOutDuration = math.max(0.01, tonumber(s and s.fadeOutDuration) or 1.5);

    local slideT = math.min(1.0, age / slideInDuration);
    slideT = 1.0 - (1.0 - slideT) ^ 3;

    local remaining = math.max(0, duration - age);
    local remainingRatio = math.min(1.0, remaining / duration);

    local alpha = 1.0;
    if (remaining < fadeOutDuration) then
        alpha = math.max(0.0, remaining / fadeOutDuration);
    end

    return slideT, alpha, remainingRatio;
end

--- The skillchain-opening action (weapon skill, or a buffed BLU/SCH spell that carries
--- real skillchain properties) most recently landed on whatever you currently have
--- targeted -- not just "the last one anywhere", since that could be a different mob
--- entirely if the party's split. Returns nil if you have no target, or no chain-opening
--- action has landed on your current target recently (until its window closes + fades).
--- { targetId, targetName, id, name, skillchain, casterName, createdClock, kind='ws'|'spell' }
function M.get_last_weaponskill()
    local targetId = current_target_id();
    if (targetId == nil) then
        return nil;
    end
    return chainStateByTarget[targetId];
end

function M.clear()
    active = {};
end

return M;
