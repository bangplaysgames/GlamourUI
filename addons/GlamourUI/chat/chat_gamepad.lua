-- Xbox (XInput) bindings for chat log focus / expand / buff-cancel modes.
-- Button IDs match Ashita's xinput_button mapping (see ThornyFFXI/cBind controllers/xinput.lua).

require('common');

local M = {};

local BTN = {
    DPAD_UP = 0,
    DPAD_DOWN = 1,
    DPAD_LEFT = 2,
    DPAD_RIGHT = 3,
    A = 12,
    B = 13,
    X = 14,
};

local DPAD_BY_BTN = {
    [BTN.DPAD_UP] = 'up',
    [BTN.DPAD_DOWN] = 'down',
    [BTN.DPAD_LEFT] = 'left',
    [BTN.DPAD_RIGHT] = 'right',
};

local BUTTON_COOLDOWN_SEC = 0.15;
local lastCommandAt = 0;

local gameMenuPauseFn = nil;

local function buttons_ready()
    return (os.clock() - lastCommandAt) >= BUTTON_COOLDOWN_SEC;
end

local function queue_glam(subcmd)
    AshitaCore:GetChatManager():QueueCommand(-1, '/glam ' .. subcmd);
    lastCommandAt = os.clock();
end

local function ensure_dpad_state()
    if (GlamourUI.gamepadDpadDown == nil) then
        GlamourUI.gamepadDpadDown = {};
    end
end

local function plus_active()
    local plist = GlamourUI.settings and GlamourUI.settings.Party and GlamourUI.settings.Party.pList;
    return (plist ~= nil and plist.hideNativeStatusIcons == true);
end

local function update_dpad(btn, down)
    local id = DPAD_BY_BTN[btn];
    if (id == nil) then
        return;
    end
    ensure_dpad_state();
    GlamourUI.gamepadDpadDown[id] = down;
end

local function should_block_button(btn)
    if (gameMenuPauseFn ~= nil and gameMenuPauseFn()) then
        return false;
    end

    if (btn == BTN.X and plus_active()) then
        return true;
    end

    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
    if (nav ~= nil and nav.active == true) then
        return btn == BTN.DPAD_LEFT
            or btn == BTN.DPAD_RIGHT
            or btn == BTN.A
            or btn == BTN.B
            or btn == BTN.X;
    end

    if (GlamourUI.chatExpandOpen == true) then
        return btn == BTN.B
            or btn == BTN.X
            or DPAD_BY_BTN[btn] ~= nil;
    end

    if (GlamourUI.chatLogFocus == true) then
        return btn == BTN.A or btn == BTN.B;
    end

    return false;
end

local function handle_press(btn)
    if (not buttons_ready()) then
        return false;
    end

    if (gameMenuPauseFn ~= nil and gameMenuPauseFn()) then
        return false;
    end

    if (btn == BTN.X and plus_active()) then
        queue_glam('plus');
        return true;
    end

    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
    if (nav ~= nil and nav.active == true) then
        if (btn == BTN.DPAD_LEFT) then
            queue_glam('buffPrev');
            return true;
        end
        if (btn == BTN.DPAD_RIGHT) then
            queue_glam('buffNext');
            return true;
        end
        if (btn == BTN.A) then
            queue_glam('buffCancelBuff');
            return true;
        end
        if (btn == BTN.B) then
            queue_glam('uiReset');
            return true;
        end
        return false;
    end

    if (GlamourUI.chatExpandOpen == true) then
        if (btn == BTN.B) then
            queue_glam('uiReset');
            return true;
        end
        return false;
    end

    if (GlamourUI.chatLogFocus == true) then
        if (btn == BTN.A) then
            queue_glam('chatExpandOpen');
            return true;
        end
        if (btn == BTN.B) then
            queue_glam('uiReset');
            return true;
        end
    end

    return false;
end

function M.register(pauseUiFn)
    gameMenuPauseFn = pauseUiFn;

    ashita.events.register('xinput_button', 'glam_chat_gamepad_cb', function(e)
        if (e == nil or e.injected == true) then
            return;
        end

        local btn = tonumber(e.button);
        if (btn == nil) then
            return;
        end

        local dpadId = DPAD_BY_BTN[btn];
        if (dpadId ~= nil) then
            update_dpad(btn, e.state == 1);
        end

        if (should_block_button(btn)) then
            e.blocked = true;
        end

        if (e.state ~= 1) then
            return;
        end

        if (handle_press(btn)) then
            e.blocked = true;
        end
    end);
end

return M;
