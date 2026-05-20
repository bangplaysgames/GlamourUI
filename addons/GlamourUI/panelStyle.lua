local imgui = require('imgui');

local M = {};

--[[
    Returns a pop handle: { colors = n, vars = n }.
    Legacy code may still pass a plain number from older builds; pop_panel_background accepts both.
]]

local function style_var_child_rounding()
    return rawget(_G, 'ImGuiStyleVar_ChildRounding');
end

local function style_var_window_border_size()
    return rawget(_G, 'ImGuiStyleVar_WindowBorderSize');
end

local function style_var_child_border_size()
    return rawget(_G, 'ImGuiStyleVar_ChildBorderSize');
end

function M.push_panel_background(settingsTable)
    local handle = { colors = 0, vars = 0 };
    if (settingsTable == nil) then
        return handle;
    end

    local varPushes = 0;
    local function push_var(id, val)
        if (id == nil) then
            return;
        end
        local ok = pcall(function()
            imgui.PushStyleVar(id, val);
        end);
        if (ok) then
            varPushes = varPushes + 1;
        end
    end

    local rnd = tonumber(settingsTable.panelRounding);
    if (rnd ~= nil and rnd > 0) then
        push_var(ImGuiStyleVar_WindowRounding, rnd);
        local cr = style_var_child_rounding();
        if (cr ~= nil) then
            push_var(cr, rnd);
        end
    end

    local padX = tonumber(settingsTable.panelPaddingX);
    local padY = tonumber(settingsTable.panelPaddingY);
    if (padX ~= nil and padY ~= nil) then
        push_var(ImGuiStyleVar_WindowPadding, { padX, padY });
    end

    -- Always push border sizes (including 0) so "0 px" removes stock ImGui borders on windows and child regions.
    local border = tonumber(settingsTable.panelBorderSize);
    if (border == nil) then
        border = 0;
    end
    border = math.max(0, border);
    local bs = style_var_window_border_size();
    if (bs ~= nil) then
        push_var(bs, border);
    end
    local cbs = style_var_child_border_size();
    if (cbs ~= nil) then
        push_var(cbs, border);
    end

    handle.vars = varPushes;

    -- Custom fill only when enabled; frame vars above always apply.
    if (settingsTable.panelBackgroundEnabled == false) then
        return handle;
    end

    local c = settingsTable.panelBackground;
    if (c == nil or type(c) ~= 'table') then
        return handle;
    end
    local r = tonumber(c[1]);
    local g = tonumber(c[2]);
    local b = tonumber(c[3]);
    local a = tonumber(c[4]);
    if (r == nil or g == nil or b == nil or a == nil) then
        return handle;
    end
    imgui.PushStyleColor(ImGuiCol_WindowBg, { r, g, b, a });
    imgui.PushStyleColor(ImGuiCol_ChildBg, { r, g, b, a });
    handle.colors = 2;
    return handle;
end

function M.pop_panel_background(handle)
    if (handle == nil) then
        return;
    end
    if (type(handle) == 'number') then
        if (handle > 0) then
            imgui.PopStyleColor(handle);
        end
        return;
    end
    if (handle.colors ~= nil and handle.colors > 0) then
        imgui.PopStyleColor(handle.colors);
    end
    if (handle.vars ~= nil and handle.vars > 0) then
        imgui.PopStyleVar(handle.vars);
    end
end

--[[
    Fills missing panel-style keys so saved configs stay valid.
    panelBackgroundEnabled: when false, skip custom WindowBg/ChildBg tint only (rounding, padding, border still apply).
]]
function M.normalize_settings(settingsTable)
    if (settingsTable == nil or type(settingsTable) ~= 'table') then
        return;
    end
    if (settingsTable.panelBackgroundEnabled == nil) then
        settingsTable.panelBackgroundEnabled = true;
    end
    if (settingsTable.panelRounding == nil) then
        settingsTable.panelRounding = 0;
    end
    if (settingsTable.panelPaddingX == nil) then
        settingsTable.panelPaddingX = nil;
    end
    if (settingsTable.panelPaddingY == nil) then
        settingsTable.panelPaddingY = nil;
    end
    if (settingsTable.panelBorderSize == nil) then
        settingsTable.panelBorderSize = 0;
    end
end

return M;
