local packet_codec = require('packet_codec');
local condense_action_packet = require('condense_action_packet');
local mode_options = require('mode_options');
local packet_chat_emit = require('packet_chat_emit');

local M = {};

function M.emit_packet_combat(e, append_cb)
    packet_chat_emit.emit_packet(e, append_cb);
end

function M.rewrite_incoming_0x28(e)
    if (e == nil or e.id ~= 0x28 or e.data == nil) then
        return;
    end
    if (GlamourUI == nil or GlamourUI.settings == nil or GlamourUI.settings.Chat == nil) then
        return;
    end
    local chat = GlamourUI.settings.Chat;
    if (chat.condensedCombatLog ~= true) then
        return;
    end

    local data = e.data;
    if (string.byte(data, 1) ~= 0x28) then
        return;
    end

    local act = packet_codec.string_to_act(data);
    if (act == nil or not act.target_count or act.target_count == 0) then
        return;
    end

    act.size = data:byte(5);

    local mode = mode_options.get_mode(chat);
    act = condense_action_packet.run(act, mode, nil);
    if (act == nil) then
        return;
    end

    local out = packet_codec.act_to_string(data, act);
    if (out ~= nil and type(out) == 'string') then
        e.data_modified = out;
    end
end

return M;
