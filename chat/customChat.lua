local installPath = AshitaCore and AshitaCore:GetInstallPath() or '';
local root = addon.path;
if (root == nil or root == '') then
    root = installPath .. 'addons/GlamourUI/';
end
if (root:sub(-1) ~= '/' and root:sub(-1) ~= '\\') then
    root = root .. '/';
end
local libPath = root .. 'chat/libs/';
if (not package.path:find(libPath, 1, true)) then
    package.path = libPath .. '?.lua;' .. package.path;
end

local protocol = require('glamourui_custom_chat_protocol');

local M = {};
local appendEntry = nil;
local registered = false;

function M.is_chat_windows_enabled()
    if (GlamourUI == nil or GlamourUI.settings == nil or GlamourUI.settings.Chat == nil) then
        return false;
    end
    local chat = GlamourUI.settings.Chat;
    if (chat.enabled ~= true) then
        return false;
    end
    local w1 = chat.window1;
    local w2 = chat.window2;
    return (w1 ~= nil and w1.enabled == true) or (w2 ~= nil and w2.enabled == true);
end

local function status_payload()
    local enabled = M.is_chat_windows_enabled();
    return {
        version = protocol.VERSION,
        chatWindowsEnabled = enabled,
        listening = enabled,
    };
end

function M.broadcast_status()
    if (not registered) then
        return;
    end
    protocol.raise_event(protocol.READY_EVENT, status_payload());
end

function M.init(append_entry_fn)
    appendEntry = append_entry_fn;
    if (GlamourUI ~= nil) then
        GlamourUI.broadcast_custom_chat_status = M.broadcast_status;
        GlamourUI.is_custom_chat_windows_enabled = M.is_chat_windows_enabled;
    end
end

local function handle_custom_chat_event(e)
    if (appendEntry == nil or not M.is_chat_windows_enabled()) then
        return;
    end

    local decoded;
    if (e.data_raw ~= nil) then
        decoded = protocol.decode_from_raw(e.data_raw);
    elseif (e.data ~= nil) then
        decoded = protocol.decode_from_table(e.data);
    end

    if (decoded == nil or decoded.message == nil or decoded.message == '') then
        return;
    end

    local purpose = (decoded.purpose ~= nil and decoded.purpose ~= '') and decoded.purpose or 'None';
    local sender = (decoded.sender ~= nil and decoded.sender ~= '') and decoded.sender or 'Addon';

    appendEntry({
        time = os.date('[%H:%M:%S]'),
        sender = sender,
        zone = nil,
        purpose = purpose,
        channel = 'addon',
        modeID = 'glam',
        modeBaseID = 'glam',
        rawMessage = nil,
        message = decoded.message,
        injected = decoded.injected ~= false,
        indent = 0,
        isTell = false,
        segments = decoded.segments,
        customChat = true,
        customChatNoDedupe = decoded.noDedupe == true,
    });
end

function M.register()
    if (registered) then
        M.broadcast_status();
        return;
    end
    registered = true;

    ashita.events.register('plugin_event', 'glamourui_custom_chat_cb', function(e)
        if (e.name == protocol.EVENT_NAME) then
            handle_custom_chat_event(e);
        elseif (e.name == protocol.PING_EVENT) then
            protocol.raise_pong(status_payload());
        end
    end);

    M.broadcast_status();
end

function M.on_unload()
    registered = false;
    if (GlamourUI ~= nil) then
        GlamourUI.broadcast_custom_chat_status = nil;
        GlamourUI.is_custom_chat_windows_enabled = nil;
    end
    protocol.raise_gone();
end

return M;
