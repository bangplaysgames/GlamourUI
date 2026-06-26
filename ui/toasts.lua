--[[
    Transient "you obtained X" toast notifications (EXP, Limit Points, Capacity
    Points, Spoils/items/gil). Pure state/timing here; ui/render.lua owns the
    actual ImGui drawing.
]]--

local M = {};

local active = {}; -- ordered list of { id, purpose, text, color, createdClock, duration }
local nextId = 1;

local toastPurposeFallbackColors = {
    PartyInvite = {0.45, 0.85, 1.0, 1.0},
    TradeRequest = {1.0, 0.72, 0.0, 1.0},
};

local function settings()
    return GlamourUI and GlamourUI.settings and GlamourUI.settings.Toasts or nil;
end

--- Picks the first non-empty string out of a resource Name/Description-style array --
--- these commonly come back with an empty string in slot [1] and the real text in [2]
--- (language-table quirk), not nil, so a plain `arr[1] or fallback` silently keeps
--- the empty string instead of falling through.
local function first_nonempty(arr)
    if (arr == nil) then
        return nil;
    end
    for i = 1, 2 do
        local v = arr[i];
        if (v ~= nil) then
            local s = tostring(v);
            if (s ~= '' and s ~= 'nil') then
                return s;
            end
        end
    end
    return nil;
end

--- Resolves {name, icon, desc} for an item id via the resource manager, robust to the
--- empty-string-in-Name[1] quirk above.
function M.resolve_item_info(itemId)
    itemId = math.floor(tonumber(itemId) or 0);
    if (itemId <= 0) then
        return { name = 'an item', icon = nil, desc = nil };
    end
    local res = AshitaCore and AshitaCore:GetResourceManager() or nil;
    local item = (res ~= nil and res.GetItemById ~= nil) and res:GetItemById(itemId) or nil;
    if (item == nil) then
        return { name = ('Item #%u'):format(itemId), icon = nil, desc = nil };
    end
    local name = first_nonempty(item.Name) or ('Item #%u'):format(itemId);
    local desc = first_nonempty(item.Description);
    local icon = (gResources and gResources.get_item_icon) and gResources.get_item_icon(itemId, item) or nil;
    return { name = name, icon = icon, desc = desc };
end

--- Theme gil.png from the Inv panel theme (same asset inventory.lua uses).
function M.resolve_gil_icon()
    if (gResources == nil or gResources.getTex == nil or GlamourUI == nil or GlamourUI.settings == nil) then
        return nil;
    end
    return gResources.getTex(GlamourUI.settings, 'Inv', 'gil.png');
end

local function is_valid_toast_icon(icon)
    icon = tonumber(icon);
    return icon ~= nil and icon > 0;
end

local function attach_gil_icon_if_needed(purpose, text, opts)
    if (opts['icon'] ~= nil or purpose ~= 'Spoils') then
        return;
    end
    text = tostring(text or '');
    if (not text:find('gil', 1, true)) then
        return;
    end
    opts['icon'] = M.resolve_gil_icon();
end

--- Queues a new toast if the given purpose is enabled for toasts. Safe to call
--- unconditionally from the chat pipeline; no-ops when disabled/unconfigured.
--- @param purpose string chat purpose (eg. 'Spoils', 'Experience')
--- @param text string the message to display
--- @param opts table|nil { icon = texturePtr, tooltip = descriptionString }
function M.push(purpose, text, opts)
    local s = settings();
    if (s == nil or s.enabled ~= true) then
        return;
    end
    if (purpose == nil or s.purposes == nil or s.purposes[purpose] ~= true) then
        return;
    end
    text = tostring(text or '');
    if (text == '') then
        return;
    end
    -- Only accept a table for opts -- never treat a bare number as an icon id (gil amounts
    -- and other small integers were rendering as white imgui.Image placeholders).
    if (type(opts) ~= 'table') then
        opts = {};
    end
    attach_gil_icon_if_needed(purpose, text, opts);

    local color = nil;
    local chat = GlamourUI.settings.Chat;
    if (chat ~= nil and chat.purposeColors ~= nil) then
        color = chat.purposeColors[purpose];
    end
    if (color == nil) then
        color = toastPurposeFallbackColors[purpose];
    end

    -- A keyed toast is a singleton: re-pushing the same key replaces the existing one
    -- (so a re-sent party invite refreshes rather than stacking) and lets callers dismiss
    -- it later by key (see M.dismiss).
    local optKey = opts['key'];
    if (optKey ~= nil) then
        local i = 1;
        while (i <= #active) do
            if (active[i].key == optKey) then
                table.remove(active, i);
            else
                i = i + 1;
            end
        end
    end

    local maxStack = math.max(1, tonumber(s.maxStack) or 5);
    while (#active >= maxStack) do
        table.remove(active, 1);
    end

    active[#active + 1] = {
        id = nextId,
        purpose = purpose,
        text = text,
        color = color or {1.0, 1.0, 1.0, 1.0},
        icon = is_valid_toast_icon(opts['icon']) and opts['icon'] or nil,
        tooltip = opts['tooltip'],
        key = optKey,
        createdClock = os.clock(),
        duration = tonumber(opts['duration']) or tonumber(s.duration) or 10.0,
    };
    nextId = nextId + 1;
end

--- Removes any active toast(s) flagged with the given key. Used to dismiss a keyed,
--- long-lived toast early -- e.g. a party invite once it's accepted/declined/expired.
function M.dismiss(key)
    if (key == nil) then
        return;
    end
    local i = 1;
    while (i <= #active) do
        if (active[i].key == key) then
            table.remove(active, i);
        else
            i = i + 1;
        end
    end
end

--- Prunes expired toasts. Cheap, safe to call every frame.
function M.tick()
    if (#active == 0) then
        return;
    end
    local now = os.clock();
    local i = 1;
    while (i <= #active) do
        local t = active[i];
        if ((now - t.createdClock) >= t.duration) then
            table.remove(active, i);
        else
            i = i + 1;
        end
    end
end

--- Returns the active toast list, oldest first.
function M.get_active()
    return active;
end

--- Computes this frame's visual state for a toast.
--- @return number slideT 0..1, 0 = fully off-screen (just spawned), 1 = fully slid in
--- @return number alpha 0..1 overall opacity (handles fade-out near expiry)
--- @return number remainingRatio 0..1, 1 = just spawned, 0 = about to expire (drives the gradient bar)
function M.get_visual_state(toast, now)
    local s = settings();
    now = now or os.clock();
    local age = now - toast.createdClock;
    local duration = tonumber(toast.duration) or 10.0;
    local slideInDuration = math.max(0.01, tonumber(s and s.slideInDuration) or 0.25);
    local fadeOutDuration = math.max(0.01, tonumber(s and s.fadeOutDuration) or 1.5);

    local slideT = math.min(1.0, age / slideInDuration);
    -- Ease-out cubic for the slide so it decelerates into place instead of landing linearly.
    slideT = 1.0 - (1.0 - slideT) ^ 3;

    local remaining = math.max(0, duration - age);
    local remainingRatio = math.min(1.0, remaining / duration);

    local alpha = 1.0;
    if (remaining < fadeOutDuration) then
        alpha = math.max(0.0, remaining / fadeOutDuration);
    end

    return slideT, alpha, remainingRatio;
end

function M.clear()
    active = {};
end

return M;
