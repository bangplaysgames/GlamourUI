--[[
    Minimap texture color processing modes (applied when building RGBA map textures).
]]

require('common');

local M = {};

M.MODE_IDS = T{ 'normal', 'grayscale', 'invert', 'dark_mode', 'sepia', 'night', 'high_contrast' };

M.MODE_LABELS = T{
    'Normal',
    'Grayscale',
    'Invert',
    'Dark Mode',
    'Sepia',
    'Night',
    'High Contrast',
};

local function env_settings()
    return GlamourUI.settings and GlamourUI.settings.Env or nil;
end

function M.normalize_mode(mode)
    mode = tostring(mode or 'normal'):lower();
    for i = 1, #M.MODE_IDS do
        if (M.MODE_IDS[i] == mode) then
            return mode;
        end
    end
    return 'normal';
end

function M.get_mode()
    local s = env_settings();
    return M.normalize_mode(s and s.minimap_render_mode);
end

function M.mode_index(mode)
    mode = M.normalize_mode(mode);
    for i = 1, #M.MODE_IDS do
        if (M.MODE_IDS[i] == mode) then
            return i;
        end
    end
    return 1;
end

function M.label_for_mode(mode)
    local idx = M.mode_index(mode);
    return M.MODE_LABELS[idx] or 'Normal';
end

local function clamp_byte(v)
    return math.max(0, math.min(255, math.floor(tonumber(v) or 0)));
end

function M.apply_rgb(r, g, b, a, mode)
    r = clamp_byte(r);
    g = clamp_byte(g);
    b = clamp_byte(b);
    a = clamp_byte(a);
    mode = M.normalize_mode(mode);

    if (mode == 'grayscale') then
        local gray = clamp_byte(0.299 * r + 0.587 * g + 0.114 * b);
        return gray, gray, gray, a;
    end

    if (mode == 'invert') then
        return 255 - r, 255 - g, 255 - b, a;
    end

    if (mode == 'dark_mode') then
        local gray = clamp_byte(0.299 * r + 0.587 * g + 0.114 * b);
        local inv = 255 - gray;
        return inv, inv, inv, a;
    end

    if (mode == 'sepia') then
        return clamp_byte(r * 0.393 + g * 0.769 + b * 0.189),
            clamp_byte(r * 0.349 + g * 0.686 + b * 0.168),
            clamp_byte(r * 0.272 + g * 0.534 + b * 0.131),
            a;
    end

    if (mode == 'night') then
        local gray = 0.299 * r + 0.587 * g + 0.114 * b;
        return clamp_byte(gray * 0.45),
            clamp_byte(gray * 0.55),
            clamp_byte(gray * 0.85),
            a;
    end

    if (mode == 'high_contrast') then
        local function snap(v)
            return (v >= 128) and 255 or 0;
        end
        return snap(r), snap(g), snap(b), a;
    end

    return r, g, b, a;
end

return M;
