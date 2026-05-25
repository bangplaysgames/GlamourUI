require('common');

local actor_parse = require('actor_parse');
local check_filter_mod = require('check_filter');
local message_map = require('message_map');

local Self;
local SelfPlayer;

local M = {};

function M.run(act, mode, check_filter)
    if (check_filter == nil) then
        check_filter = check_filter_mod.check_filter;
    end

    if (not Self) then
        Self = GetPlayerEntity();
        if (not Self) then
            return act;
        end
    end

    if (not SelfPlayer) then
        SelfPlayer = AshitaCore:GetMemoryManager():GetPlayer();
        if (not SelfPlayer) then
            return act;
        end
    end

    act.actor = actor_parse.parse(act.actor_id);
    act.action = { name = '' };

    if (not act.action) then
        return act;
    end

    for i, v in ipairs(act.targets) do
        v.target = {};
        v.target[1] = actor_parse.parse(v.server_id);
        if (#v.actions > 1) then
            for n, m in ipairs(v.actions) do
                m.number = 1;
                if (m.has_add_effect) then
                    m.add_effect_number = 1;
                end
                if (m.has_spike_effect) then
                    m.spike_effect_number = 1;
                end
                if (not check_filter(act.actor, v.target[1], act.category, m.message)) then
                    m.message = 0;
                    m.add_effect_message = 0;
                end
                if (m.spike_effect_message ~= 0 and not check_filter(v.target[1], act.actor, act.category, m.message)) then
                    m.spike_effect_message = 0;
                end
                if (mode.condensedamage and n > 1) then
                    for q = 1, n - 1 do
                        local r = v.actions[q];

                        if (r.message ~= 0 and m.message ~= 0) then
                            if (m.message == r.message or (mode.condensecrits and T{ 1, 67 }:contains(m.message) and T{ 1, 67 }:contains(r.message))) then
                                if ((m.effect == r.effect) or (T{ 1, 67 }:contains(m.message) and T{ 0, 1, 2, 3 }:contains(m.effect) and T{ 0, 1, 2, 3 }:contains(r.effect))) then
                                    if (m.reaction == r.reaction) then
                                        r.number = r.number + 1;
                                        if (not mode.sumdamage) then
                                            if (not r.cparam) then
                                                r.cparam = r.param;
                                                if (mode.condensecrits and r.message == 67) then
                                                    r.cparam = r.cparam .. '!';
                                                end
                                            end
                                            r.cparam = r.cparam .. ', ' .. m.param;
                                            if (mode.condensecrits and r.message == 67) then
                                                r.cparam = r.cparam .. '!';
                                            end
                                        end
                                        r.param = m.param + r.param;
                                        if (mode.condensecrits and m.message == 67) then
                                            r.message = m.message;
                                            r.effect = m.effect;
                                        end
                                        m.message = 0;
                                    end
                                end
                            end
                        end
                        if (m.has_add_effect and r.add_effect_message ~= 0) then
                            if (m.add_effect_effect == r.add_effect_effect and m.add_effect_message == r.add_effect_message and m.add_effect_message ~= 0) then
                                r.add_effect_number = r.add_effect_number + 1;
                                if (not mode.sumdamage) then
                                    r.cadd_effect_param = (r.cadd_effect_param or r.add_effect_param) .. ', ' .. m.add_effect_param;
                                end
                                r.add_effect_param = m.add_effect_param + r.add_effect_param;
                                m.add_effect_message = 0;
                            end
                        end
                        if (m.has_spike_effect and r.spike_effect_message ~= 0) then
                            if (r.spike_effect_effect == r.spike_effect_effect and m.spike_effect_message == r.spike_effect_message and m.spike_effect_message ~= 0) then
                                r.spike_effect_number = r.spike_effect_number + 1;
                                if (not mode.sumdamage) then
                                    r.cspike_effect_param = (r.cspike_effect_param or r.spike_effect_param) .. ', ' .. m.spike_effect_param;
                                end
                                r.spike_effect_param = m.spike_effect_param + r.spike_effect_param;
                                m.spike_effect_message = 0;
                            end
                        end
                    end
                end
            end
        else
            local tempact = v.actions[1];
            if (not check_filter(act.actor, v.target[1], act.category, tempact.message)) then
                tempact.message = 0;
                tempact.add_effect_message = 0;
            end
            if (tempact.spike_effect_message ~= 0 and not check_filter(v.target[1], act.actor, act.category, tempact.message)) then
                tempact.spike_effect_message = 0;
            end
            tempact.number = 1;
            if (tempact.has_add_effect and tempact.message ~= 674) then
                tempact.add_effect_number = 1;
            end
            if (tempact.has_spike_effect) then
                tempact.spike_effect_number = 1;
            end
        end
        if (mode.condensetargets and i > 1) then
            for n = 1, i - 1 do
                local mt = act.targets[n];
                if ((v.actions[1].message == mt.actions[1].message and v.actions[1].param == mt.actions[1].param)
                    or (message_map[mt.actions[1].message] and message_map[mt.actions[1].message]:contains(v.actions[1].message) and v.actions[1].param == mt.actions[1].param)
                    or (message_map[mt.actions[1].message] and message_map[mt.actions[1].message]:contains(v.actions[1].message) and v.actions[1].param == mt.actions[1].param)) then
                    mt.target[#mt.target + 1] = v.target[1];
                    v.target[1] = nil;
                    v.actions[1].message = 0;
                end
            end
        end
    end

    return act;
end

return M;
