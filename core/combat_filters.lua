--[[
    Combat filter settings shared by the combat toasts and the parser.

    Stored per CHARACTER automatically (GlamourUI settings are character-scoped),
    and per JOB inside that: every job gets its own auto-created filter set
    (seeded from the defaults below), looked up live by the current main job so a
    job change instantly swaps the active filters.

    A filter set has:
      toastCats     -- which combat-toast categories show (ws/spell/pet/sc/burst)
      toastPlayers  -- which actor groups toast (self/party/pets/alliance/others)
      parserPlayers -- which groups appear in the parser (self/party/pets/alliance)
]]--

require('common');

local M = {};

local function default_set()
    return {
        toastCats = { ws = true, spell = true, pet = true, skillchain = true, magicBurst = true },
        toastPlayers = { self = true, party = true, pets = true, alliance = true, others = false },
        parserPlayers = { self = true, party = true, pets = true, alliance = true },
    };
end

M.TOAST_CATS = { 'ws', 'spell', 'pet', 'skillchain', 'magicBurst' };
M.TOAST_CAT_LABELS = {
    ws = 'Weaponskills', spell = 'Spells', pet = 'Pet TP', skillchain = 'Skillchains', magicBurst = 'Magic Bursts',
};
M.TOAST_PLAYERS = { 'self', 'party', 'pets', 'alliance', 'others' };
M.PARSER_PLAYERS = { 'self', 'party', 'pets', 'alliance' };
M.PLAYER_LABELS = {
    self = 'Self', party = 'Party', pets = 'Pets', alliance = 'Alliance', others = 'Others',
};

local function fill_bool_defaults(dst, src)
    if (type(dst) ~= 'table') then
        return;
    end
    for k, v in pairs(src) do
        if (dst[k] == nil) then
            dst[k] = v;
        end
    end
end

local function normalize_set(set)
    if (type(set) ~= 'table') then
        return default_set();
    end
    local d = default_set();
    if (type(set.toastCats) ~= 'table') then set.toastCats = d.toastCats; else fill_bool_defaults(set.toastCats, d.toastCats); end
    if (type(set.toastPlayers) ~= 'table') then set.toastPlayers = d.toastPlayers; else fill_bool_defaults(set.toastPlayers, d.toastPlayers); end
    if (type(set.parserPlayers) ~= 'table') then set.parserPlayers = d.parserPlayers; else fill_bool_defaults(set.parserPlayers, d.parserPlayers); end
    return set;
end

local function filters_root()
    if (GlamourUI == nil or GlamourUI.settings == nil) then
        return nil;
    end
    if (GlamourUI.settings.Filters == nil) then
        GlamourUI.settings.Filters = { byJob = {} };
    end
    if (type(GlamourUI.settings.Filters.byJob) ~= 'table') then
        GlamourUI.settings.Filters.byJob = {};
    end
    return GlamourUI.settings.Filters;
end

--- Current main job abbreviation (e.g. 'WAR'), or nil if not resolvable.
function M.current_job()
    local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
    local p = mm and mm:GetPlayer() or nil;
    if (p == nil) then
        return nil;
    end
    local ok, id = pcall(function() return p:GetMainJob(); end);
    if (not ok or id == nil or tonumber(id) == nil or tonumber(id) <= 0) then
        return nil;
    end
    local rm = AshitaCore:GetResourceManager();
    if (rm ~= nil) then
        local okS, abbr = pcall(function() return rm:GetString('jobs.names_abbr', id); end);
        if (okS and abbr ~= nil and abbr ~= '') then
            return abbr;
        end
    end
    return ('JOB%d'):fmt(tonumber(id));
end

-- Cache the active set reference keyed by job so the per-frame hot path
-- (combatant list / toasts) doesn't rebuild it. The cached value is the live
-- byJob[job] table, so config edits are reflected without invalidation.
local cachedJob = nil;
local cachedSet = nil;
local transientSet = default_set(); -- used when no job / no settings yet (not persisted)

--- The filter set for the current job, auto-created (seeded from defaults) the
--- first time that job is seen. Returns a transient all-on-ish set if the job or
--- settings aren't available yet (e.g. zoning) so nothing is wrongly hidden.
function M.active_set()
    local root = filters_root();
    if (root == nil) then
        return transientSet;
    end
    local job = M.current_job();
    if (job == nil) then
        return transientSet;
    end
    if (job == cachedJob and cachedSet ~= nil and root.byJob[job] == cachedSet) then
        return cachedSet;
    end
    if (root.byJob[job] == nil) then
        root.byJob[job] = default_set();
    else
        normalize_set(root.byJob[job]);
    end
    cachedJob = job;
    cachedSet = root.byJob[job];
    return cachedSet;
end

function M.invalidate()
    cachedJob = nil;
    cachedSet = nil;
end

-- ---- Group classification --------------------------------------------------

local function group_for_server_id(sid)
    sid = tonumber(sid) or 0;
    if (sid == 0) then
        return 'others';
    end
    local party = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (party ~= nil) then
        for i = 0, 17 do
            local ok, id = pcall(function() return party:GetMemberServerId(i); end);
            if (ok and id ~= nil and id ~= 0 and id == sid) then
                if (i == 0) then return 'self'; end
                if (i <= 5) then return 'party'; end
                return 'alliance';
            end
        end
    end
    local selfEnt = (GetPlayerEntity ~= nil) and GetPlayerEntity() or nil;
    if (selfEnt ~= nil and selfEnt.ServerId == sid) then
        return 'self';
    end
    return 'others';
end

--- True if a combat-toast event passes the active category + player filters.
function M.toast_allows(event)
    if (event == nil) then
        return false;
    end
    local set = M.active_set();

    local cat;
    if (event.kind == 'skillchain') then
        cat = 'skillchain';
    elseif (event.magicBurst == true) then
        cat = 'magicBurst';
    else
        cat = event.kind;
    end
    if (cat ~= nil and set.toastCats[cat] == false) then
        return false;
    end

    local grp;
    if (event.kind == 'pet') then
        grp = 'pets';
    else
        grp = group_for_server_id(event.actorId);
    end
    if (set.toastPlayers[grp] == false) then
        return false;
    end
    return true;
end

--- Map a parser combatant `side` to a player group.
function M.side_group(side)
    if (side == 'me') then return 'self'; end
    if (side == 'party') then return 'party'; end
    if (side == 'alliance') then return 'alliance'; end
    if (side == 'my_pet' or side == 'other_pets') then return 'pets'; end
    return 'others';
end

--- True if a parser combatant of the given `side` should be shown.
function M.parser_allows_side(side)
    local set = M.active_set();
    local grp = M.side_group(side);
    if (set.parserPlayers[grp] == false) then
        return false;
    end
    return true;
end

return M;
