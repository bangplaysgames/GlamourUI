--[[
  Fake drop shadow for ImGui.Text / TextColored / TextDisabled / TextWrapped.
  Use suppress_begin/suppress_end around regions that must not be shadowed (e.g. chat).
]]

local M = {
    _depth = 0,
    _orig = nil,
};

local SHADOW_DX = 1;
local SHADOW_DY = 1;

function M.is_suppressed()
    return M._depth > 0;
end

function M.suppress_begin()
    M._depth = M._depth + 1;
end

function M.suppress_end()
    if (M._depth > 0) then
        M._depth = M._depth - 1;
    end
end

local function rgba_to_shadow(col)
    if (type(col) ~= 'table') then
        return { 0, 0, 0, 0.85 };
    end
    local a = tonumber(col[4] or col.a or 1.0) or 1.0;
    return { 0, 0, 0, math.min(1.0, a * 0.92) };
end

local function get_style_text_rgba(imgui, colId)
    if (imgui.GetStyleColorVec4 ~= nil) then
        local v = imgui.GetStyleColorVec4(colId);
        if (type(v) == 'table') then
            return {
                tonumber(v[1] or v.x) or 1,
                tonumber(v[2] or v.y) or 1,
                tonumber(v[3] or v.z) or 1,
                tonumber(v[4] or v.w) or 1,
            };
        end
    end
    return { 1, 1, 1, 1 };
end

--- Draw-list text with optional shadow (respects suppress).
function M.draw_list_add_text_shadowed(imgui, dl, pos, fgU32, text)
    if (dl == nil or text == nil or dl.AddText == nil) then
        return;
    end
    if (M.is_suppressed()) then
        dl:AddText(pos, fgU32, text);
        return;
    end
    local px = pos[1] or pos.x;
    local py = pos[2] or pos.y;
    local su = imgui.GetColorU32({ 0, 0, 0, 0.86 });
    dl:AddText({ px + SHADOW_DX, py + SHADOW_DY }, su, text);
    dl:AddText({ px, py }, fgU32, text);
end

function M.install(imgui)
    if (M._orig ~= nil) then
        return;
    end

    M._orig = {
        Text = imgui.Text,
        TextColored = imgui.TextColored,
        TextDisabled = imgui.TextDisabled,
        TextWrapped = imgui.TextWrapped,
    };

    local orig = M._orig;

    imgui.Text = function(text)
        if (M.is_suppressed()) then
            return orig.Text(text);
        end
        local x, y = imgui.GetCursorPos();
        local rgba = get_style_text_rgba(imgui, ImGuiCol_Text);
        local sh = rgba_to_shadow(rgba);
        imgui.PushStyleColor(ImGuiCol_Text, sh);
        imgui.SetCursorPos({ x + SHADOW_DX, y + SHADOW_DY });
        orig.Text(text);
        imgui.PopStyleColor();
        imgui.SetCursorPos({ x, y });
        orig.Text(text);
    end

    imgui.TextWrapped = function(text)
        if (M.is_suppressed()) then
            return orig.TextWrapped(text);
        end
        local x, y = imgui.GetCursorPos();
        local rgba = get_style_text_rgba(imgui, ImGuiCol_Text);
        local sh = rgba_to_shadow(rgba);
        imgui.PushStyleColor(ImGuiCol_Text, sh);
        imgui.SetCursorPos({ x + SHADOW_DX, y + SHADOW_DY });
        orig.TextWrapped(text);
        imgui.PopStyleColor();
        imgui.SetCursorPos({ x, y });
        orig.TextWrapped(text);
    end

    imgui.TextColored = function(col, text)
        if (M.is_suppressed()) then
            return orig.TextColored(col, text);
        end
        local x, y = imgui.GetCursorPos();
        local sh = rgba_to_shadow(col);
        imgui.PushStyleColor(ImGuiCol_Text, sh);
        imgui.SetCursorPos({ x + SHADOW_DX, y + SHADOW_DY });
        orig.Text(text);
        imgui.PopStyleColor();
        imgui.SetCursorPos({ x, y });
        orig.TextColored(col, text);
    end

    imgui.TextDisabled = function(text)
        if (M.is_suppressed()) then
            return orig.TextDisabled(text);
        end
        local x, y = imgui.GetCursorPos();
        local rgba = get_style_text_rgba(imgui, ImGuiCol_TextDisabled);
        local sh = rgba_to_shadow(rgba);
        imgui.PushStyleColor(ImGuiCol_Text, sh);
        imgui.SetCursorPos({ x + SHADOW_DX, y + SHADOW_DY });
        orig.Text(text);
        imgui.PopStyleColor();
        imgui.SetCursorPos({ x, y });
        orig.TextDisabled(text);
    end
end

return M;
