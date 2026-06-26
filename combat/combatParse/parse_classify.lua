--[[
    Stateless classification helpers for the combat parser (parse_db.lua).

    Given a decoded action packet (act) and one (target, action) pair, decide:
      - which damage/stat bucket the action belongs to
      - whether it was a hit / miss / crit / magic burst
      - for damage taken: how it was mitigated (evade / parry / shadow / block)
      - the numeric damage or healing value

    Reuses the BtlMess action-message table (combat/combatParse/action_messages.lua)
    that packet_chat_emit.lua already relies on -- the `color` field there marks
    'D' (damage), 'M' (miss), 'H' (heal) which we lean on for bucketing, plus the
    same message-id sets simplify_combat.lua / packet_chat_emit.lua use.
]]--

require('common');

local M = {};

local res_actmsg = nil;
local res_failed = false;

local function actmsg()
    if (res_actmsg ~= nil or res_failed) then
        return res_actmsg;
    end
    local ok, data = pcall(function()
        return require('action_messages');
    end);
    if (not ok or type(data) ~= 'table') then
        res_failed = true;
        return nil;
    end
    res_actmsg = data;
    return res_actmsg;
end

-- Message id sets (mirrored from simplify_combat.lua english_simp_name and the
-- magic-burst detection in packet_chat_emit.lua).
local MELEE_HIT   = T{ 1, 67 };          -- 1 = hit, 67 = critical hit
local MELEE_CRIT  = T{ 67 };
local MELEE_MISS  = T{ 15, 30, 32, 282 };-- miss / anticipate / dodge / evaded
local MELEE_PARRY_REACTION = 11;
local RANGED_HIT  = T{ 352, 353, 576, 577 };
local RANGED_CRIT = T{ 353 };
local RANGED_MISS = T{ 354 };
local SHADOW_MSG  = T{ 14, 31 };         -- N of <target>'s shadows absorb...
local INTIMIDATE  = T{ 106 };            -- intimidated (no hit)
local BURST_MSG   = T{ 252, 265, 268, 269, 271, 272, 274, 275, 379, 650, 747 };

-- WS landing messages (same set thotbar/packet_chat_emit treat as a real WS).
local WS_MSG = T{ 103, 185, 187, 238 };

local function row_for(msg_id)
    local r = actmsg();
    if (r == nil) then
        return nil;
    end
    return r[tonumber(msg_id) or 0];
end

--- 'damage' | 'miss' | 'heal' | nil, derived from the action-message color.
local function color_kind(row)
    if (row == nil) then
        return nil;
    end
    local c = row.color;
    if (c == 'D') then
        return 'damage';
    elseif (c == 'M') then
        return 'miss';
    elseif (c == 'H') then
        return 'heal';
    end
    return nil;
end

local function category_bucket(cat, actorIsPet)
    if (actorIsPet) then
        return 'pet';
    end
    cat = tonumber(cat) or 0;
    if (cat == 1) then
        return 'melee';
    elseif (cat == 2) then
        return 'ranged';
    elseif (cat == 3) then
        return 'ws';
    elseif (cat == 4) then
        return 'magic';
    elseif (cat == 6) then
        return 'ability';
    elseif (cat == 11) then
        return 'mobskill'; -- mob TP move; only relevant for 'taken'
    end
    return 'other';
end

--- Primary numeric value carried by an action (the damage/heal number).
local function action_number(action)
    if (action == nil) then
        return 0;
    end
    return tonumber(action.param) or 0;
end

--- Classify a single (target, action) for the given actor type and target side.
--- act        : decoded action packet (act.category, act.actor.type)
--- action     : one entry of target.actions
--- targetSide : actor_parse filter of the target ('me'/'party'/...) or nil
--- Returns a flat result table; bucket == 'none' means "ignore".
function M.classify(act, action, targetSide)
    local out = {
        bucket = 'none',
        value = 0,
        isHit = false,
        isMiss = false,
        isCrit = false,
        isBurst = false,
        isParry = false,
        isEvade = false,
        isShadow = false,
        isTpMove = false,
    };
    if (act == nil or action == nil) then
        return out;
    end

    local cat = tonumber(act.category) or 0;
    local msg = tonumber(action.message) or 0;
    -- actor_parse exposes the clean side in `filter` (me/party/alliance/my_pet/
    -- other_pets/monsters/enemies/others); `type` is a raw slot id (p0,p1,al0,...).
    local actorSide = act.actor and act.actor.filter or nil;
    local actorIsPet = (actorSide == 'my_pet' or actorSide == 'other_pets');
    local actorIsMob = (actorSide == 'monsters' or actorSide == 'enemies');
    local reaction = tonumber(action.reaction) or 0;
    local row = row_for(msg);
    local kind = color_kind(row);

    local targetIsPlayerSide = (targetSide == 'me' or targetSide == 'party'
        or targetSide == 'alliance' or targetSide == 'my_pet' or targetSide == 'other_pets');

    -- Damage TAKEN: a mob acting on a player-side target. Mitigation flags let the
    -- Defense view show evade/parry/shadow rates without a damage number.
    if (actorIsMob and targetIsPlayerSide) then
        out.bucket = 'taken';
        out.isTpMove = (cat == 11);
        if (SHADOW_MSG:contains(msg)) then
            out.isShadow = true;
        elseif (reaction == MELEE_PARRY_REACTION) then
            out.isParry = true;
        elseif (MELEE_MISS:contains(msg) or kind == 'miss') then
            out.isEvade = true;
        elseif (kind == 'damage') then
            out.value = action_number(action);
            out.isHit = true;
            if (MELEE_CRIT:contains(msg)) then
                out.isCrit = true;
            end
        end
        return out;
    end

    -- Offense / healing: only when the actor is player-side. (trust resolves to
    -- filter 'party', so it is covered by the 'party' check.)
    local actorIsPlayerSide = (actorSide == 'me' or actorSide == 'party'
        or actorSide == 'alliance' or actorIsPet);
    if (not actorIsPlayerSide) then
        return out;
    end

    -- Healing (cures, regen, drain HP recover) regardless of category.
    if (kind == 'heal') then
        out.bucket = 'heal';
        out.value = action_number(action);
        return out;
    end

    out.bucket = category_bucket(cat, actorIsPet);
    out.isBurst = BURST_MSG:contains(msg);

    -- Melee / ranged accuracy + crit.
    if (out.bucket == 'melee') then
        if (SHADOW_MSG:contains(msg)) then
            out.isShadow = true;
        elseif (reaction == MELEE_PARRY_REACTION or INTIMIDATE:contains(msg) or MELEE_MISS:contains(msg)) then
            out.isMiss = true;
        elseif (MELEE_HIT:contains(msg) or kind == 'damage') then
            out.isHit = true;
            out.value = action_number(action);
            out.isCrit = MELEE_CRIT:contains(msg);
        end
    elseif (out.bucket == 'ranged') then
        if (RANGED_MISS:contains(msg)) then
            out.isMiss = true;
        elseif (RANGED_HIT:contains(msg) or kind == 'damage') then
            out.isHit = true;
            out.value = action_number(action);
            out.isCrit = RANGED_CRIT:contains(msg);
        end
    elseif (kind == 'damage') then
        -- ws / magic / ability / pet damage.
        out.value = action_number(action);
        out.isHit = true;
    elseif (kind == 'miss') then
        out.isMiss = true;
    end

    -- A category-3 action that is NOT a real WS landing message (e.g. a steal
    -- mis-slotted into the WS category) carries no damage -- drop the value.
    if (cat == 3 and not WS_MSG:contains(msg) and kind ~= 'damage') then
        out.value = 0;
        out.isHit = false;
    end

    return out;
end

--- Additional-effect / spike damage attached to an action (added physical/magical
--- damage procs). Returns value or 0.
function M.add_effect_damage(action)
    if (action == nil) then
        return 0;
    end
    local total = 0;
    if (action.has_add_effect and tonumber(action.add_effect_message or 0) ~= 0) then
        local row = row_for(action.add_effect_message);
        if (color_kind(row) == 'damage') then
            total = total + (tonumber(action.add_effect_param) or 0);
        end
    end
    if (action.has_spike_effect and tonumber(action.spike_effect_message or 0) ~= 0) then
        local row = row_for(action.spike_effect_message);
        if (color_kind(row) == 'damage') then
            total = total + (tonumber(action.spike_effect_param) or 0);
        end
    end
    return total;
end

return M;
