--[[
    Current-target mob spell / ability readout from incoming 0x28 / 0x29 packets.
    Matches the targeted entity by server id (packet actor_id).
]]
require('common');

local bit = require('bit');
local struct = require('struct');
local action_packet28 = require('action_packet28');
local actor_parse = require('actor_parse');

local info = debug.getinfo(1, 'S');
local src = info.source or '';
if (src:sub(1, 1) == '@') then
    local dir = src:sub(2):match('^(.*[/\\])') or '';
    package.path = dir .. 'combatParse/?.lua;' .. package.path;
end

local M = {};

local DISPLAY_SEC = 12.0;

local END_CATEGORIES = {
    [4] = true,
};

local state = {
    serverId = 0,
    label = '',
    expiresAt = 0,
};

local res_actmsg;
local res_actmsg_err;

local function rm()
    return AshitaCore:GetResourceManager();
end

local function rm_string(tbl, id)
    id = math.floor(tonumber(id) or 0);
    if (id < 1 or id > 65535) then
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
    local ok, a, b = pcall(function()
        return nm[1], nm[2];
    end);
    if (not ok) then
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

local function lookup_spell(id)
    for _, t in ipairs(T{ 'spells.names', 'spells.names_short', 'spells' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    local r = rm();
    if (r ~= nil and r.GetSpellById ~= nil) then
        local ok, spell = pcall(function()
            return r:GetSpellById(id);
        end);
        if (ok and spell ~= nil) then
            local nm = ability_object_first_name(spell);
            if (nm ~= nil) then
                return nm;
            end
        end
    end
    return nil;
end

local function lookup_player_ws(id)
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil;
    end
    for _, t in ipairs(T{ 'weapon_skills.names', 'weapon_skills' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    local r = rm();
    if (r ~= nil and r.GetAbilityById ~= nil and id > 0 and id <= 0x200) then
        local ok, ab = pcall(function()
            return r:GetAbilityById(id);
        end);
        if (ok and ab ~= nil) then
            return ability_object_first_name(ab);
        end
    end
    return nil;
end

local function lookup_ws(id)
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil;
    end
    for _, t in ipairs(T{ 'weapon_skills.names', 'weapon_skills', 'monsters.weapon_skills' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    local r = rm();
    if (r ~= nil and r.GetAbilityById ~= nil and id > 0 and id <= 0x200) then
        local ok, ab = pcall(function()
            return r:GetAbilityById(id);
        end);
        if (ok and ab ~= nil) then
            return ability_object_first_name(ab);
        end
    end
    return nil;
end

local function lookup_job_ability(id)
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil;
    end
    local r = rm();
    if (r ~= nil and r.GetAbilityById ~= nil) then
        local tries = {};
        if (id < 0x200) then
            tries[1] = id + 0x200;
        else
            tries[1] = id;
        end
        for ti = 1, #tries do
            local ok, ab = pcall(function()
                return r:GetAbilityById(tries[ti]);
            end);
            if (ok and ab ~= nil) then
                local nm = ability_object_first_name(ab);
                if (nm ~= nil and nm ~= '') then
                    return nm;
                end
            end
        end
    end
    for _, t in ipairs(T{ 'job_abilities.names', 'abilities.jobs', 'job_abilities' }) do
        local s = rm_string(t, id);
        if (s ~= nil and s ~= '') then
            return s;
        end
    end
    return nil;
end

local function lookup_mon_ability(id)
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
    return lookup_player_ws(id);
end

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

local function magic_action_categories()
    return T{ 7, 8, 9 };
end

local function action_id_for_packet(category, packetParam, firstAction)
    local cat = tonumber(category) or 0;
    local param = math.floor(tonumber(packetParam) or 0);
    if (magic_action_categories():contains(cat)) then
        local sliceId = (firstAction ~= nil) and math.floor(tonumber(firstAction.param) or 0) or 0;
        if (sliceId > 0) then
            return sliceId;
        end
        return param;
    end
    if (cat == 3 or cat == 4 or cat == 5 or cat == 6 or cat == 11 or cat == 13 or cat == 14 or cat == 15) then
        return param;
    end
    return param;
end

local function load_res_actmsg()
    if (res_actmsg ~= nil or res_actmsg_err ~= nil) then
        return res_actmsg;
    end
    local ok, data = pcall(function()
        return require('action_messages');
    end);
    if (not ok or type(data) ~= 'table') then
        res_actmsg_err = tostring(data);
        return nil;
    end
    res_actmsg = data;
    return res_actmsg;
end

local function message_indicates_action_begin(msg_id)
    msg_id = tonumber(msg_id) or 0;
    if (msg_id == 3 or msg_id == 327) then
        return true;
    end
    if (msg_id == 43 or msg_id == 326 or msg_id == 675 or msg_id == 716) then
        return true;
    end
    if (msg_id == 100 or msg_id == 101) then
        return true;
    end
    return false;
end

local function resolve_label_from_action_message(msg_id, actionId, _actorName)
    local row = load_res_actmsg() and load_res_actmsg()[msg_id];
    if (row == nil or row.en == nil) then
        return nil;
    end
    local en = tostring(row.en);
    actionId = math.floor(tonumber(actionId) or 0);
    if (actionId <= 0) then
        return nil;
    end
    if (en:find('${weapon_skill}', 1, true) ~= nil) then
        return skill_nonempty(lookup_mon_ability(actionId)) or ('#' .. tostring(actionId));
    end
    if (en:find('${ability}', 1, true) ~= nil) then
        return skill_nonempty(lookup_mon_ability(actionId)) or skill_nonempty(lookup_job_ability(actionId)) or ('#' .. tostring(actionId));
    end
    if (en:find('${spell}', 1, true) ~= nil) then
        return skill_nonempty(lookup_spell(actionId)) or skill_nonempty(lookup_mon_ability(actionId)) or ('#' .. tostring(actionId));
    end
    return nil;
end

local function resolve_label_from_action_packet(act, firstAction, actorName)
    if (act == nil or firstAction == nil) then
        return nil;
    end
    local msg_id = tonumber(firstAction.message) or 0;
    if (msg_id <= 0) then
        return nil;
    end
    local actionId = action_id_for_packet(act.category, act.param, firstAction);
    return resolve_label_from_action_message(msg_id, actionId, actorName);
end

local function message_indicates_action_resolved(msg_id)
    msg_id = tonumber(msg_id) or 0;
    if (msg_id == 16) then
        return true;
    end
    if (message_indicates_action_begin(msg_id)) then
        return false;
    end
    local row = load_res_actmsg() and load_res_actmsg()[msg_id];
    if (row == nil or row.en == nil) then
        return false;
    end
    local en = tostring(row.en);
    if (en:find('${spell}', 1, true) ~= nil
        or en:find('${ability}', 1, true) ~= nil
        or en:find('${weapon_skill}', 1, true) ~= nil) then
        return true;
    end
    return false;
end

local function get_target_server_id()
    local mm = AshitaCore:GetMemoryManager();
    if (mm == nil) then
        return nil;
    end
    local targetManager = mm:GetTarget();
    if (targetManager == nil) then
        return nil;
    end
    local targetIndex = targetManager:GetTargetIndex(0);
    if (targetIndex == nil or targetIndex == 0) then
        return nil;
    end
    local ent = GetEntity(targetIndex);
    if (ent == nil or ent.ServerId == nil or ent.ServerId == 0) then
        return nil;
    end
    return ent.ServerId, targetIndex;
end

local function actor_is_targeted_mob(actorServerId)
    if (actorServerId == nil or actorServerId == 0) then
        return false;
    end

    local targetSid, targetIndex = get_target_server_id();
    if (targetSid == nil) then
        return false;
    end
    if (actorServerId ~= targetSid) then
        return false;
    end

    local mm = AshitaCore:GetMemoryManager();
    local spawnFlags = mm:GetEntity():GetSpawnFlags(targetIndex);
    return bit.band(spawnFlags, 0x10) == 0x10;
end

local function clear_state()
    state.serverId = 0;
    state.label = '';
    state.expiresAt = 0;
end

local function clear_for_actor(actorId)
    actorId = tonumber(actorId) or 0;
    if (actorId ~= 0 and state.serverId == actorId) then
        clear_state();
    end
end

function M.clear_zone()
    clear_state();
end

function M.get_label(targetServerId)
    targetServerId = tonumber(targetServerId) or 0;
    if (targetServerId == 0 or state.serverId ~= targetServerId) then
        return nil;
    end
    if (state.label == nil or state.label == '') then
        return nil;
    end
    if (os.clock() > (state.expiresAt or 0)) then
        clear_state();
        return nil;
    end
    return state.label;
end

function M.ingest_0x28_packet(e)
    if (e == nil or e.data == nil) then
        return;
    end

    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    local legacyHeader = (chat ~= nil and chat.actionPacket28LegacyHeader == true);
    local act = action_packet28.parse_action_packet(e.data, legacyHeader);
    if (act == nil) then
        return;
    end

    local actorId = tonumber(act.actor_id) or 0;
    if (not actor_is_targeted_mob(actorId)) then
        return;
    end

    local category = tonumber(act.category) or 0;
    if (END_CATEGORIES[category] == true) then
        clear_for_actor(actorId);
        return;
    end

    local firstAction = nil;
    if (act.targets ~= nil and act.targets[1] ~= nil and act.targets[1].actions ~= nil) then
        firstAction = act.targets[1].actions[1];
    end
    if (firstAction == nil) then
        return;
    end

    local messageId = tonumber(firstAction.message) or 0;
    if (message_indicates_action_resolved(messageId)) then
        clear_for_actor(actorId);
        return;
    end

    if (not message_indicates_action_begin(messageId)) then
        return;
    end

    local actor_tbl = actor_parse.parse(actorId);
    local actorName = actor_tbl and actor_tbl.name or nil;
    local label = resolve_label_from_action_packet(act, firstAction, actorName);
    if (label == nil or label == '') then
        return;
    end

    state.serverId = actorId;
    state.label = label;
    state.expiresAt = os.clock() + DISPLAY_SEC;
end

function M.ingest_0x29_packet(e)
    if (e == nil or e.data == nil or #e.data < 0x1A) then
        return;
    end

    local actorId = struct.unpack('I', e.data, 0x05);
    local param1 = struct.unpack('I', e.data, 0x0D);
    local messageId = struct.unpack('H', e.data, 0x19) % 32768;

    if (not actor_is_targeted_mob(actorId)) then
        return;
    end

    if (message_indicates_action_begin(messageId)) then
        local actor_tbl = actor_parse.parse(actorId);
        local actorName = actor_tbl and actor_tbl.name or nil;
        local label = resolve_label_from_action_message(messageId, param1, actorName);
        if (label ~= nil and label ~= '') then
            state.serverId = actorId;
            state.label = label;
            state.expiresAt = os.clock() + DISPLAY_SEC;
        end
        return;
    end

    if (state.label == nil or state.label == '' or state.serverId ~= actorId) then
        return;
    end

    if (message_indicates_action_resolved(messageId)) then
        clear_for_actor(actorId);
    end
end

return M;
