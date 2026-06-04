require('common');

local M = {};

--- In-game entity name; filter "???" is literal, not three wildcard slots.
local LITERAL_QUESTION_NAME = '???';

local function is_literal_question_name(pattern)
    return pattern == LITERAL_QUESTION_NAME;
end

function M.is_wildcard_only_pattern(pattern)
    if (pattern == nil or pattern == '') then
        return true;
    end
    if (is_literal_question_name(pattern)) then
        return false;
    end
    return pattern:match('^[%*%?]+$') ~= nil;
end

local function escape_lua_pattern_literal(text)
    return (text:gsub('([%%^%$%(%)%.%[%]%*%+%-%?])', '%%%1'));
end

function M.wildcard_to_lua_pattern(pattern)
    if (pattern == nil) then
        return '^$';
    end

    local parts = {};
    for i = 1, #pattern do
        local c = pattern:sub(i, i);
        if (c == '*') then
            parts[#parts + 1] = '.*';
        elseif (c == '?') then
            parts[#parts + 1] = '.';
        else
            parts[#parts + 1] = escape_lua_pattern_literal(c);
        end
    end

    return '^' .. table.concat(parts) .. '$';
end

function M.wildcard_match(text, pattern)
    if (text == nil or pattern == nil) then
        return false;
    end
    if (is_literal_question_name(pattern)) then
        return tostring(text) == LITERAL_QUESTION_NAME;
    end
    if (M.is_wildcard_only_pattern(pattern)) then
        return false;
    end

    text = tostring(text):lower();
    pattern = tostring(pattern):lower();
    local luaPattern = M.wildcard_to_lua_pattern(pattern);
    return text:match(luaPattern) ~= nil;
end

function M.list_name_matches(name, patterns)
    if (patterns == nil or name == nil) then
        return false;
    end
    for i = 1, #patterns do
        if (M.wildcard_match(name, patterns[i])) then
            return true;
        end
    end
    return false;
end

return M;
