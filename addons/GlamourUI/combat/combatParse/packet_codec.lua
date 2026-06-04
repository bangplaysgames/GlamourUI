local M = {};

local function assemble_bit_packed(init, val, initial_length, final_length)
    if (not init) then
        return init;
    end

    if (type(val) == 'boolean') then
        if (val) then
            val = 1;
        else
            val = 0;
        end
    elseif (type(val) ~= 'number') then
        return false;
    end

    local bits = initial_length % 8;
    local byte_length = math.ceil(final_length / 8);

    local out_val = 0;
    if (bits > 0) then
        out_val = init:byte(#init);
        init = init:sub(1, #init - 1);
    end
    out_val = out_val + val * 2 ^ bits;

    while (out_val > 0) do
        init = init .. string.char(out_val % 256);
        out_val = math.floor(out_val / 256);
    end
    while (#init < byte_length) do
        init = init .. string.char(0);
    end
    return init;
end

function M.string_to_act(packet)
    local act_table = {};
    if (string.byte(packet) ~= 0x28) then
        return act_table;
    end
    act_table['size'] = ashita.bits.unpack_be(packet:totable(), 32, 8);
    act_table['actor_id'] = ashita.bits.unpack_be(packet:totable(), 40, 32);
    act_table['actor_index'] = struct.unpack('L', packet, 0x05 + 1);
    act_table['target_count'] = ashita.bits.unpack_be(packet:totable(), 72, 10);
    act_table['category'] = ashita.bits.unpack_be(packet:totable(), 82, 4);
    act_table['param'] = ashita.bits.unpack_be(packet:totable(), 86, 16);
    act_table['msg'] = ashita.bits.unpack_be(packet:totable(), 230, 10);
    act_table['unknown'] = ashita.bits.unpack_be(packet:totable(), 102, 16);
    act_table['recast'] = ashita.bits.unpack_be(packet:totable(), 118, 32);
    act_table['targets'] = {};

    local offset = 150;
    for i = 1, act_table.target_count do
        local target = {};
        target['offset_start'] = offset;
        target['server_id'] = ashita.bits.unpack_be(packet:totable(), offset, 32);
        target['action_count'] = ashita.bits.unpack_be(packet:totable(), offset + 32, 4);
        target['actions'] = {};
        offset = offset + 36;
        for n = 1, target.action_count do
            local action = {};
            action['offset_start'] = offset;
            action['reaction'] = ashita.bits.unpack_be(packet:totable(), offset, 5);
            action['animation'] = ashita.bits.unpack_be(packet:totable(), offset + 5, 12);
            action['effect'] = ashita.bits.unpack_be(packet:totable(), offset + 17, 4);
            action['stagger'] = ashita.bits.unpack_be(packet:totable(), offset + 21, 3);
            action['knockback'] = ashita.bits.unpack_be(packet:totable(), offset + 24, 3);
            action['param'] = ashita.bits.unpack_be(packet:totable(), offset + 27, 17);
            action['message'] = ashita.bits.unpack_be(packet:totable(), offset + 44, 10);
            action['unknown'] = ashita.bits.unpack_be(packet:totable(), offset + 54, 31);

            action['has_add_effect'] = ashita.bits.unpack_be(packet:totable(), offset + 85, 1);
            action['has_add_effect'] = action.has_add_effect == 1;
            offset = offset + 86;
            if (action.has_add_effect) then
                action['add_effect_animation'] = ashita.bits.unpack_be(packet:totable(), offset, 6);
                action['add_effect_effect'] = ashita.bits.unpack_be(packet:totable(), offset + 6, 4);
                action['add_effect_param'] = ashita.bits.unpack_be(packet:totable(), offset + 10, 17);
                action['add_effect_message'] = ashita.bits.unpack_be(packet:totable(), offset + 27, 10);
                offset = offset + 37;
            end
            action['has_spike_effect'] = ashita.bits.unpack_be(packet:totable(), offset, 1);
            action['has_spike_effect'] = action.has_spike_effect == 1;
            offset = offset + 1;
            if (action.has_spike_effect) then
                action['spike_effect_animation'] = ashita.bits.unpack_be(packet:totable(), offset, 6);
                action['spike_effect_effect'] = ashita.bits.unpack_be(packet:totable(), offset + 6, 4);
                action['spike_effect_param'] = ashita.bits.unpack_be(packet:totable(), offset + 10, 14);
                action['spike_effect_message'] = ashita.bits.unpack_be(packet:totable(), offset + 24, 10);
                offset = offset + 34;
            end
            action['offset_end'] = offset;
            table.insert(target['actions'], action);
        end
        target['offset_end'] = offset;
        table.insert(act_table['targets'], target);
    end

    return act_table;
end

function M.act_to_string(original, act)
    if (type(act) ~= 'table') then
        return act;
    end

    local react = assemble_bit_packed(tostring(original):sub(1, 4), act.size, 32, 40);
    react = assemble_bit_packed(react, act.actor_id, 40, 72);
    react = assemble_bit_packed(react, act.target_count, 72, 82);
    react = assemble_bit_packed(react, act.category, 82, 86);
    react = assemble_bit_packed(react, act.param, 86, 102);
    react = assemble_bit_packed(react, act.unknown, 102, 118);
    react = assemble_bit_packed(react, act.recast, 118, 150);

    local offset = 150;
    for i = 1, act.target_count do
        react = assemble_bit_packed(react, act.targets[i].server_id, offset, offset + 32);
        react = assemble_bit_packed(react, act.targets[i].action_count, offset + 32, offset + 36);
        offset = offset + 36;
        for n = 1, act.targets[i].action_count do
            react = assemble_bit_packed(react, act.targets[i].actions[n].reaction, offset, offset + 5);
            react = assemble_bit_packed(react, act.targets[i].actions[n].animation, offset + 5, offset + 17);
            react = assemble_bit_packed(react, act.targets[i].actions[n].effect, offset + 17, offset + 21);
            react = assemble_bit_packed(react, act.targets[i].actions[n].stagger, offset + 21, offset + 24);
            react = assemble_bit_packed(react, act.targets[i].actions[n].knockback, offset + 24, offset + 27);
            react = assemble_bit_packed(react, act.targets[i].actions[n].param, offset + 27, offset + 44);
            react = assemble_bit_packed(react, act.targets[i].actions[n].message, offset + 44, offset + 54);
            react = assemble_bit_packed(react, act.targets[i].actions[n].unknown, offset + 54, offset + 85);

            react = assemble_bit_packed(react, act.targets[i].actions[n].has_add_effect, offset + 85, offset + 86);
            offset = offset + 86;
            if (act.targets[i].actions[n].has_add_effect) then
                react = assemble_bit_packed(react, act.targets[i].actions[n].add_effect_animation, offset, offset + 6);
                react = assemble_bit_packed(react, act.targets[i].actions[n].add_effect_effect, offset + 6, offset + 10);
                react = assemble_bit_packed(react, act.targets[i].actions[n].add_effect_param, offset + 10, offset + 27);
                react = assemble_bit_packed(react, act.targets[i].actions[n].add_effect_message, offset + 27, offset + 37);
                offset = offset + 37;
            end
            react = assemble_bit_packed(react, act.targets[i].actions[n].has_spike_effect, offset, offset + 1);
            offset = offset + 1;
            if (act.targets[i].actions[n].has_spike_effect) then
                react = assemble_bit_packed(react, act.targets[i].actions[n].spike_effect_animation, offset, offset + 6);
                react = assemble_bit_packed(react, act.targets[i].actions[n].spike_effect_effect, offset + 6, offset + 10);
                react = assemble_bit_packed(react, act.targets[i].actions[n].spike_effect_param, offset + 10, offset + 24);
                react = assemble_bit_packed(react, act.targets[i].actions[n].spike_effect_message, offset + 24, offset + 34);
                offset = offset + 34;
            end
        end
    end
    if (react) then
        while (#react < #original) do
            react = react .. original:sub(#react + 1, #react + 1);
        end
    end
    return react;
end

return M;
