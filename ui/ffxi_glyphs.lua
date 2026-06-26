local imgui = require('imgui');

local ffxi_glyphs = {};

ffxi_glyphs.STAR_CHAR = '★';
ffxi_glyphs.STAR_UTF8 = '\226\152\133';
ffxi_glyphs.STAR_ALT_UTF8 = '\xe2\x80\xbb';
ffxi_glyphs.EMPTY_STAR_CHAR = '☆';
ffxi_glyphs.EMPTY_STAR_UTF8 = '\226\152\134';
ffxi_glyphs.MOB_CHECK_PREFIX = string.char(0xAB);
ffxi_glyphs.MOB_CHECK_PREFIX_UTF8_CORRUPT = '\239\189\171';
ffxi_glyphs.STAR_SENTINEL_EMPTY = string.char(0x7F, 0x7F);
ffxi_glyphs.STAR_SENTINEL_FILLED = string.char(0x7F, 0x7E);
ffxi_glyphs.STAR_COLOR = { 1.0, 0.88, 0.35, 1.0 };
ffxi_glyphs.MOB_CHECK_STAR_TEXT = '☆';
ffxi_glyphs.MOB_CHECK_STAR_COLOR = { 1.0, 0.88, 0.35, 1.0 };
ffxi_glyphs.STAR_FALLBACK = '*';
ffxi_glyphs.EMPTY_STAR_FALLBACK = '*';
ffxi_glyphs.STAR_SCALE = 1.2;
ffxi_glyphs.TARGET_BAR_NAME_Y_LIFT = 5;

function ffxi_glyphs.mob_check_star_part()
    return {
        draw = 'ffxi_empty_star',
        text = ffxi_glyphs.MOB_CHECK_STAR_TEXT,
        color = ffxi_glyphs.MOB_CHECK_STAR_COLOR,
    };
end

function ffxi_glyphs.draw_mob_check_star_part(part)
    part = part or ffxi_glyphs.mob_check_star_part();
    ffxi_glyphs.draw_empty_star_text(part.color, part.text);
end

function ffxi_glyphs.draw_mob_check_star_beside_row(rowX, rowY, nameLineH)
    nameLineH = tonumber(nameLineH) or imgui.GetTextLineHeight();
    if (type(nameLineH) ~= 'number' or nameLineH <= 0) then
        nameLineH = imgui.GetFontSize() or 14;
    end
    local starH = ffxi_glyphs.star_text_height();
    local starW = ffxi_glyphs.star_scaled_text_width(ffxi_glyphs.MOB_CHECK_STAR_TEXT);
    local starY = rowY + (nameLineH - starH) * 0.5;
    imgui.SetCursorPos({ rowX, starY });
    ffxi_glyphs.draw_mob_check_star_part();
    imgui.SetCursorPos({ rowX + starW, rowY });
    return starW;
end

function ffxi_glyphs.make_mob_check_star_wrap_token()
    local part = ffxi_glyphs.mob_check_star_part();
    return {
        text = part.text,
        color = part.color,
        newline = false,
        atomic = true,
        parts = T{ part },
    };
end

function ffxi_glyphs.make_empty_star_wrap_token(_starColor)
    return ffxi_glyphs.make_mob_check_star_wrap_token();
end

local function calc_text_width(str)
    if (str == nil or str == '') then
        return 0;
    end
    local w = imgui.CalcTextSize(str);
    if (type(w) == 'number') then
        return w;
    end
    if (type(w) == 'table') then
        return tonumber(w[1]) or tonumber(w.x) or 0;
    end
    return 0;
end

local function calc_line_height()
    local h = imgui.GetTextLineHeightWithSpacing();
    if (type(h) == 'number') then
        return math.max(1, h);
    end
    if (type(h) == 'table') then
        local n = tonumber(h[2]) or tonumber(h.y);
        if (n ~= nil and n > 0) then
            return n;
        end
    end
    local fs = imgui.GetFontSize();
    if (type(fs) == 'number') then
        return math.max(1, fs + 2);
    end
    return 14;
end

local function star_font_size(scale)
    local fs = calc_line_height();
    if (imgui.GetFontSize ~= nil) then
        local current = imgui.GetFontSize();
        if (type(current) == 'number' and current > 0) then
            fs = current;
        end
    end
    scale = tonumber(scale) or 1;
    return math.max(1, fs * ffxi_glyphs.STAR_SCALE * scale);
end

function ffxi_glyphs.star_display_char()
    if (GlamourUI ~= nil and GlamourUI.starGlyphMerged == true) then
        return ffxi_glyphs.STAR_CHAR;
    end
    return ffxi_glyphs.STAR_FALLBACK;
end

function ffxi_glyphs.empty_star_display_char()
    if (GlamourUI ~= nil and GlamourUI.starGlyphMerged == true) then
        return ffxi_glyphs.EMPTY_STAR_CHAR;
    end
    return ffxi_glyphs.EMPTY_STAR_FALLBACK;
end

function ffxi_glyphs.star_scaled_text_width(text, scale)
    text = text or ffxi_glyphs.star_display_char();
    scale = tonumber(scale) or 1;
    if (GlamourUI == nil or GlamourUI.font == nil or imgui.PushFont == nil) then
        return calc_text_width(text) * ffxi_glyphs.STAR_SCALE * scale;
    end
    imgui.PushFont(GlamourUI.font, star_font_size(scale));
    local w = calc_text_width(text);
    imgui.PopFont();
    return w;
end

function ffxi_glyphs.draw_star_text(color, text)
    text = text or ffxi_glyphs.star_display_char();
    local pushed = false;
    if (GlamourUI ~= nil and GlamourUI.font ~= nil and imgui.PushFont ~= nil) then
        imgui.PushFont(GlamourUI.font, star_font_size());
        pushed = true;
    end
    imgui.TextColored(color or ffxi_glyphs.STAR_COLOR, text);
    if (pushed) then
        imgui.PopFont();
    end
end

function ffxi_glyphs.normalize_star_markers(text)
    return ffxi_glyphs.normalize_mob_check_markers(text);
end

function ffxi_glyphs.normalize_mob_check_markers(text)
    if (text == nil or text == '') then
        return text;
    end
    return tostring(text)
        :gsub(ffxi_glyphs.STAR_ALT_UTF8, ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub(string.char(0x81, 0x9A), ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub(ffxi_glyphs.MOB_CHECK_PREFIX_UTF8_CORRUPT, ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub('\239\189' .. ffxi_glyphs.EMPTY_STAR_CHAR, ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub('\194\171', ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub(ffxi_glyphs.MOB_CHECK_PREFIX, ffxi_glyphs.EMPTY_STAR_CHAR)
        :gsub(ffxi_glyphs.EMPTY_STAR_CHAR .. '+', ffxi_glyphs.EMPTY_STAR_CHAR);
end

local function mob_check_star_marker_patterns()
    return {
        ffxi_glyphs.EMPTY_STAR_UTF8,
        ffxi_glyphs.EMPTY_STAR_CHAR,
        ffxi_glyphs.STAR_UTF8,
        ffxi_glyphs.STAR_CHAR,
        ffxi_glyphs.STAR_ALT_UTF8,
        ffxi_glyphs.MOB_CHECK_PREFIX_UTF8_CORRUPT,
        ffxi_glyphs.MOB_CHECK_PREFIX,
        string.char(0x81, 0x9A),
    };
end

function ffxi_glyphs.find_next_mob_check_star(text, startIndex)
    if (text == nil or text == '') then
        return nil, nil;
    end
    startIndex = tonumber(startIndex) or 1;
    local bestPos;
    local bestLen;
    for _, pattern in ipairs(mob_check_star_marker_patterns()) do
        local pos = text:find(pattern, startIndex, true);
        if (pos ~= nil and (bestPos == nil or pos < bestPos)) then
            bestPos = pos;
            bestLen = #pattern;
        end
    end
    return bestPos, bestLen;
end

function ffxi_glyphs.shield_star_markers_for_sjis(text)
    if (text == nil or text == '') then
        return text;
    end
    return tostring(text)
        :gsub(ffxi_glyphs.EMPTY_STAR_UTF8, ffxi_glyphs.STAR_SENTINEL_EMPTY)
        :gsub(ffxi_glyphs.STAR_UTF8, ffxi_glyphs.STAR_SENTINEL_EMPTY)
        :gsub(ffxi_glyphs.MOB_CHECK_PREFIX_UTF8_CORRUPT, ffxi_glyphs.STAR_SENTINEL_EMPTY)
        :gsub(ffxi_glyphs.STAR_ALT_UTF8, ffxi_glyphs.STAR_SENTINEL_EMPTY)
        :gsub(string.char(0x81, 0x9A), ffxi_glyphs.STAR_SENTINEL_EMPTY)
        :gsub(ffxi_glyphs.MOB_CHECK_PREFIX, ffxi_glyphs.STAR_SENTINEL_EMPTY);
end

function ffxi_glyphs.restore_star_markers_after_sjis(text)
    if (text == nil or text == '') then
        return text;
    end
    return tostring(text)
        :gsub(ffxi_glyphs.STAR_SENTINEL_EMPTY, ffxi_glyphs.EMPTY_STAR_UTF8)
        :gsub(ffxi_glyphs.STAR_SENTINEL_FILLED, ffxi_glyphs.EMPTY_STAR_UTF8);
end

function ffxi_glyphs.make_mob_check_prefix_segment(rawStart, color)
    color = color or ffxi_glyphs.MOB_CHECK_STAR_COLOR;
    local part = ffxi_glyphs.mob_check_star_part();
    part.color = color;
    return {
        rawStart = rawStart,
        rawEnd = rawStart,
        text = ffxi_glyphs.MOB_CHECK_STAR_TEXT,
        color = color,
        atomic = true,
        parts = T{ part },
    };
end

function ffxi_glyphs.make_filled_star_wrap_token(starColor)
    local starText = ffxi_glyphs.star_display_char();
    starColor = starColor or ffxi_glyphs.STAR_COLOR;
    return {
        text = starText,
        color = starColor,
        newline = false,
        atomic = true,
        parts = T{ { draw = 'ffxi_star', text = starText, color = starColor } },
    };
end

function ffxi_glyphs.star_text_height(scale)
    scale = tonumber(scale) or 1;
    if (GlamourUI ~= nil and GlamourUI.font ~= nil and imgui.PushFont ~= nil) then
        imgui.PushFont(GlamourUI.font, star_font_size(scale));
        local h = imgui.GetTextLineHeight();
        imgui.PopFont();
        if (type(h) == 'number' and h > 0) then
            return h;
        end
    end
    return calc_line_height() * ffxi_glyphs.STAR_SCALE * scale;
end

function ffxi_glyphs.draw_empty_star_text(color, text, scale)
    text = text or ffxi_glyphs.MOB_CHECK_STAR_TEXT;
    local pushed = false;
    if (GlamourUI ~= nil and GlamourUI.font ~= nil and imgui.PushFont ~= nil) then
        imgui.PushFont(GlamourUI.font, star_font_size(scale));
        pushed = true;
    end
    imgui.TextColored(color or ffxi_glyphs.MOB_CHECK_STAR_COLOR, text);
    if (pushed) then
        imgui.PopFont();
    end
end

function ffxi_glyphs.draw_empty_star_inline(color, text, scale)
    ffxi_glyphs.draw_empty_star_text(color, text, scale);
end

function ffxi_glyphs.draw_empty_star_beside_text(color, text, scale, nameLineH)
    text = text or ffxi_glyphs.empty_star_display_char();
    ffxi_glyphs.draw_empty_star_inline(color, text, scale);
    return ffxi_glyphs.star_scaled_text_width(text, scale);
end

function ffxi_glyphs.star_part_is_star(p)
    if (p == nil) then
        return false;
    end
    if (p.draw == 'ffxi_star') then
        return true;
    end
    local t = tostring(p.text or '');
    return (t == ffxi_glyphs.STAR_CHAR) or (t == ffxi_glyphs.STAR_FALLBACK) or (t == ffxi_glyphs.STAR_UTF8);
end

function ffxi_glyphs.empty_star_part_is_star(p)
    if (p == nil) then
        return false;
    end
    if (p.draw == 'ffxi_empty_star') then
        return true;
    end
    local t = tostring(p.text or '');
    return (t == ffxi_glyphs.MOB_CHECK_STAR_TEXT)
        or (t == ffxi_glyphs.EMPTY_STAR_CHAR)
        or (t == ffxi_glyphs.EMPTY_STAR_FALLBACK)
        or (t == ffxi_glyphs.EMPTY_STAR_UTF8);
end

return ffxi_glyphs;
