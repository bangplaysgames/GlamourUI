--[[
    GlamourUI custom chat — sender API for third-party addons.

    Setup (once per addon):
        package.path = AshitaCore:GetInstallPath() .. 'addons/GlamourUI/chat/libs/?.lua;' .. package.path
        local glamChat = require('glamourui_chat')

    Dual-mode usage:
        glamChat.print('Hello', { purpose = 'Say', sender = 'MyAddon' })
        -- Uses GlamourUI when chat windows are enabled; otherwise native AddChatMessage.

        if glamChat.IsGlamourUI() then
            -- custom RGB segments / cycle colors (chat logs + a window enabled)
        else
            -- your own fallback
        end

    Listen for GlamourUI load/unload (optional):
        ashita.events.register('plugin_event', 'my_glam_cb', function(e)
            if (e.name == glamChat.READY_EVENT) then ... end
            if (e.name == glamChat.GONE_EVENT) then ... end
        end)
]]

local installPath = AshitaCore and AshitaCore:GetInstallPath() or '';
local libPath = installPath .. 'addons/GlamourUI/chat/libs/';
if (not package.path:find(libPath, 1, true)) then
    package.path = libPath .. '?.lua;' .. package.path;
end

local protocol = require('glamourui_custom_chat_protocol');

local M = {};

M.EVENT_NAME = protocol.EVENT_NAME;
M.PING_EVENT = protocol.PING_EVENT;
M.PONG_EVENT = protocol.PONG_EVENT;
M.READY_EVENT = protocol.READY_EVENT;
M.GONE_EVENT = protocol.GONE_EVENT;
M.VERSION = protocol.VERSION;

local chatWindowsEnabled = false;
local lastStatusClock = 0;
local statusCacheSec = 3.0;
local listenerRegistered = false;

local function apply_status_from_event(e)
    local data = e.data;
    if (type(data) ~= 'table') then
        chatWindowsEnabled = false;
        return;
    end
    if (data.chatWindowsEnabled ~= nil) then
        chatWindowsEnabled = data.chatWindowsEnabled == true;
    else
        chatWindowsEnabled = data.listening == true;
    end
    lastStatusClock = os.clock();
end

local PURPOSE_CHAT_MODE = {
    ['Say'] = 0x00,
    ['Shout'] = 0x01,
    ['Tell'] = 0x03,
    ['Party'] = 0x04,
    ['LS[1]'] = 0x05,
    ['System'] = 0x06,
    ['Emote'] = 0x0A,
    ['Yell'] = 0x1A,
    ['LS[2]'] = 0x1B,
    ['Unity'] = 0x21,
    ['Echo'] = 0xCE,
    ['None'] = 0x06,
};

local function normalize_payload(messageOrOpts, opts)
    if (type(messageOrOpts) == 'table') then
        return messageOrOpts;
    end
    local payload = opts or {};
    payload.message = messageOrOpts;
    return payload;
end

local function purpose_to_chat_mode(purpose)
    return PURPOSE_CHAT_MODE[purpose or 'None'] or 0x06;
end

local function build_fallback_line(payload)
    local message = tostring(payload.message or payload.text or '');
    if (message == '') then
        if (payload.segments ~= nil) then
            local parts = {};
            for i = 1, #payload.segments do
                parts[i] = tostring(payload.segments[i].text or '');
            end
            message = table.concat(parts);
        end
    end
    local sender = tostring(payload.sender or '');
    if (sender ~= '' and sender ~= 'Addon') then
        return ('[%s] %s'):fmt(sender, message);
    end
    return message;
end

local function register_listener_once()
    if (listenerRegistered) then
        return;
    end
    listenerRegistered = true;

    ashita.events.register('plugin_event', 'glamourui_chat_lib_cb', function(e)
        if (e.name == protocol.PONG_EVENT or e.name == protocol.READY_EVENT) then
            apply_status_from_event(e);
        elseif (e.name == protocol.GONE_EVENT) then
            chatWindowsEnabled = false;
            lastStatusClock = 0;
        end
    end);
end

register_listener_once();

--- True when GlamourUI chat logs are enabled and at least one chat window is on (cached briefly).
--- @param forceRefresh boolean|nil pass true to ignore cache and ping again
function M.IsGlamourUI(forceRefresh)
    register_listener_once();

    local now = os.clock();
    if (forceRefresh ~= true and (now - lastStatusClock) < statusCacheSec) then
        return chatWindowsEnabled;
    end

    if (not protocol.is_addon_loaded()) then
        chatWindowsEnabled = false;
        lastStatusClock = 0;
        return false;
    end

    chatWindowsEnabled = false;
    protocol.raise_ping();
    return chatWindowsEnabled;
end

--- Same as IsGlamourUI; name reflects what is actually checked.
M.IsChatWindowsEnabled = M.IsGlamourUI;

--- Alias for common typo.
M.IsGlarmouUI = M.IsGlamourUI;

--- Post to native FFXI chat (no custom RGB). Used when GlamourUI is unavailable.
function M.print_fallback(payload)
    payload = payload or {};
    local line = build_fallback_line(payload);
    if (line == nil or line == '') then
        return false;
    end
    local cm = AshitaCore and AshitaCore:GetChatManager() or nil;
    if (cm == nil or cm.AddChatMessage == nil) then
        return false;
    end
    cm:AddChatMessage(purpose_to_chat_mode(payload.purpose), false, line);
    return true;
end

--- Post a line to GlamourUI when chat windows are enabled; otherwise native chat (unless requireGlamourUI).
--- @param messageOrOpts string|table
--- @param opts table|nil requireGlamourUI, forceFallback, purpose, sender, segments, colors, …
function M.print(messageOrOpts, opts)
    local payload = normalize_payload(messageOrOpts, opts);

    if (payload.forceFallback == true) then
        return M.print_fallback(payload);
    end

    if (M.IsGlamourUI()) then
        local tableStruct = protocol.encode(payload);
        protocol.raise_event(M.EVENT_NAME, tableStruct);
        return true;
    end

    if (payload.requireGlamourUI == true) then
        return false;
    end

    return M.print_fallback(payload);
end

M.send = M.print;
M.encode = protocol.encode;
M.segments_from_cycle_colors = protocol.segments_from_cycle_colors;

return M;
