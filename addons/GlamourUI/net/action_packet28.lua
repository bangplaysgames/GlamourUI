require('common');

local M = {};

local function parse_action_packet_is_0x28(packet)
    if (packet == nil or #packet < 2) then
        return false;
    end
    if (string.byte(packet, 1) == 0x28) then
        return true;
    end
    local idSize = struct.unpack('H', packet, 1);
    return (bit.band(idSize, 0x01FF) == 0x028);
end

--- XiPackets / retail layout.
local function parse_action_packet_retail(packet)
    local bytes = packet:totable();

    local function read_bits(bitOffset, bitCount)
        return ashita.bits.unpack_be(bytes, bitOffset, bitCount);
    end

    local bitOffset = 8 * 5;

    local act = {
        actor_id = read_bits(bitOffset, 32),
        targets = {},
    };
    bitOffset = bitOffset + 32;

    act.target_count = read_bits(bitOffset, 6);
    bitOffset = bitOffset + 6;

    act.res_sum = read_bits(bitOffset, 4);
    bitOffset = bitOffset + 4;

    act.cmd_no = read_bits(bitOffset, 4);
    bitOffset = bitOffset + 4;

    act.cmd_arg = read_bits(bitOffset, 32);
    bitOffset = bitOffset + 32;

    act.info = read_bits(bitOffset, 32);
    bitOffset = bitOffset + 32;

    act.category = act.cmd_no;
    act.param = act.cmd_arg;

    if (act.target_count > 64) then
        return nil;
    end

    for _ = 1, act.target_count do
        local target = {
            server_id = read_bits(bitOffset, 32),
            action_count = 0,
            actions = {},
        };
        bitOffset = bitOffset + 32;

        target.action_count = read_bits(bitOffset, 4);
        bitOffset = bitOffset + 4;

        if (target.action_count > 8) then
            return nil;
        end

        for _ = 1, target.action_count do
            local action = {
                reaction = read_bits(bitOffset, 3),
                kind = read_bits(bitOffset + 3, 2),
                animation = read_bits(bitOffset + 5, 12),
                effect = read_bits(bitOffset + 17, 5),
                stagger = read_bits(bitOffset + 22, 5),
                knockback = 0,
                param = read_bits(bitOffset + 27, 17),
                message = read_bits(bitOffset + 44, 10),
                unknown = read_bits(bitOffset + 54, 31),
            };
            bitOffset = bitOffset + 85;

            local has_proc = (read_bits(bitOffset, 1) == 1);
            bitOffset = bitOffset + 1;
            action.has_add_effect = has_proc;
            if (has_proc) then
                action.add_effect_animation = read_bits(bitOffset, 6);
                action.add_effect_effect = read_bits(bitOffset + 6, 4);
                action.add_effect_param = read_bits(bitOffset + 10, 17);
                action.add_effect_message = read_bits(bitOffset + 27, 10);
                bitOffset = bitOffset + 37;
            end

            local has_react = (read_bits(bitOffset, 1) == 1);
            bitOffset = bitOffset + 1;
            action.has_spike_effect = has_react;
            if (has_react) then
                action.spike_effect_animation = read_bits(bitOffset, 6);
                action.spike_effect_effect = read_bits(bitOffset + 6, 4);
                action.spike_effect_param = read_bits(bitOffset + 10, 14);
                action.spike_effect_message = read_bits(bitOffset + 24, 10);
                bitOffset = bitOffset + 34;
            end

            table.insert(target.actions, action);
        end

        table.insert(act.targets, target);
    end

    return act;
end

local function parse_action_packet_legacy(packet)
    local bytes = packet:totable();

    local function rb(o, n)
        return ashita.bits.unpack_be(bytes, o, n);
    end

    local act = {
        actor_id = rb(40, 32),
        targets = {},
    };

    act.target_count = rb(72, 10);
    act.cmd_no = rb(82, 4);
    act.cmd_arg = rb(86, 16);
    act.info = rb(118, 32);
    act.res_sum = 0;

    act.category = act.cmd_no;
    act.param = act.cmd_arg;

    if (act.target_count > 64) then
        return nil;
    end

    local bitOffset = 150;

    for _ = 1, act.target_count do
        local target = {
            server_id = rb(bitOffset, 32),
            action_count = 0,
            actions = {},
        };
        bitOffset = bitOffset + 32;

        target.action_count = rb(bitOffset, 4);
        bitOffset = bitOffset + 4;

        if (target.action_count > 8) then
            return nil;
        end

        for _ = 1, target.action_count do
            local r5 = rb(bitOffset, 5);
            local action = {
                reaction = bit.band(r5, 0x7),
                kind = bit.band(bit.rshift(r5, 3), 0x3),
                animation = rb(bitOffset + 5, 12),
                effect = rb(bitOffset + 17, 4),
                stagger = rb(bitOffset + 21, 3),
                knockback = rb(bitOffset + 24, 3),
                param = rb(bitOffset + 27, 17),
                message = rb(bitOffset + 44, 10),
                unknown = rb(bitOffset + 54, 31),
            };
            bitOffset = bitOffset + 85;

            local has_proc = (rb(bitOffset, 1) == 1);
            bitOffset = bitOffset + 1;
            action.has_add_effect = has_proc;
            if (has_proc) then
                action.add_effect_animation = rb(bitOffset, 6);
                action.add_effect_effect = rb(bitOffset + 6, 4);
                action.add_effect_param = rb(bitOffset + 10, 17);
                action.add_effect_message = rb(bitOffset + 27, 10);
                bitOffset = bitOffset + 37;
            end

            local has_react = (rb(bitOffset, 1) == 1);
            bitOffset = bitOffset + 1;
            action.has_spike_effect = has_react;
            if (has_react) then
                action.spike_effect_animation = rb(bitOffset, 6);
                action.spike_effect_effect = rb(bitOffset + 6, 4);
                action.spike_effect_param = rb(bitOffset + 10, 14);
                action.spike_effect_message = rb(bitOffset + 24, 10);
                bitOffset = bitOffset + 34;
            end

            table.insert(target.actions, action);
        end

        table.insert(act.targets, target);
    end

    return act;
end

local PACKET_0x28_MIN_BODY_ONE_RESULT = 34;

local function parse_0x28_first_action_message(act)
    if (act == nil or act.targets[1] == nil or act.targets[1].actions[1] == nil) then
        return nil;
    end
    return tonumber(act.targets[1].actions[1].message);
end

local function parse_0x28_count_actions(act)
    if (act == nil) then
        return 0;
    end
    local n = 0;
    for ti = 1, #act.targets do
        local t = act.targets[ti];
        if (t ~= nil and t.actions ~= nil) then
            n = n + #t.actions;
        end
    end
    return n;
end

local function parse_0x28_msg_id_plausible(id)
    id = tonumber(id) or 0;
    return id > 0 and id < 1024;
end

function M.parse_action_packet(packet, legacyHeader)
    if (not parse_action_packet_is_0x28(packet)) then
        return nil;
    end

    local retail = parse_action_packet_retail(packet);
    local legacy = parse_action_packet_legacy(packet);

    if (legacyHeader == true) then
        if (legacy ~= nil) then
            return legacy;
        end
        return retail;
    end

    local legOk = (legacy ~= nil and legacy.target_count > 0 and #packet >= PACKET_0x28_MIN_BODY_ONE_RESULT);
    local retOk = (retail ~= nil and retail.target_count > 0);

    if (not legOk and not retOk) then
        return retail or legacy;
    end
    if (legOk and not retOk) then
        return legacy;
    end
    if (retOk and not legOk) then
        return retail;
    end

    local rm = parse_0x28_first_action_message(retail);
    local lm = parse_0x28_first_action_message(legacy);
    local rc = parse_0x28_count_actions(retail);
    local lc = parse_0x28_count_actions(legacy);

    if (parse_0x28_msg_id_plausible(lm) and not parse_0x28_msg_id_plausible(rm)) then
        return legacy;
    end
    if (parse_0x28_msg_id_plausible(rm) and not parse_0x28_msg_id_plausible(lm)) then
        return retail;
    end
    if (lc > rc) then
        return legacy;
    end
    if (rc > lc) then
        return retail;
    end
    return retail;
end

function M.resolve_action_id(category, packetParam, actionData)
    local actionId = packetParam;
    if (actionData ~= nil and (category == 7 or category == 8 or category == 9)) then
        actionId = actionData.param;
    end
    return actionId;
end

return M;
