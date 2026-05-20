--[[
    GlamourUI custom chat — fixed-size FFI wire format (shared by sender lib + receiver).

    Struct layout (4000 bytes, version 1):
      version, flags, segment_count, reserved
      sender[32], purpose[32]
      data[3920]  — UTF-8 message (NUL-terminated) + optional color runs

    Each color run (after message NUL):
      uint16 start   byte offset into message
      uint16 length  run length in bytes (0 = through end of message)
      uint8  r, g, b, a  (0–255)
]]

local ffi = require('ffi');
local bit = require('bit');

local M = {};

M.EVENT_NAME = 'GlamourUI_Custom_Chat_Event';
M.PING_EVENT = 'GlamourUI_Custom_Chat_Ping';
M.PONG_EVENT = 'GlamourUI_Custom_Chat_Pong';
M.READY_EVENT = 'GlamourUI_Custom_Chat_Ready';
M.GONE_EVENT = 'GlamourUI_Custom_Chat_Gone';
M.VERSION = 1;
M.STRUCT_SIZE = 4000;
M.ADDON_NAME = 'GlamourUI';

M.FLAG_INJECTED = 0x01;
M.FLAG_NO_DEDUPE = 0x02;

ffi.cdef[[
    typedef struct GlamourUI_CustomChat_t {
        int32_t version;
        int32_t flags;
        int32_t segment_count;
        int32_t reserved;
        char sender[32];
        char purpose[32];
        char data[3920];
    } GlamourUI_CustomChat_t;
]];

local function clamp_byte(v)
    v = math.floor(tonumber(v) or 0);
    if (v < 0) then return 0; end
    if (v > 255) then return 255; end
    return v;
end

local function color_to_bytes(color)
    if (color == nil) then
        return 255, 255, 255, 255;
    end
    local r = color[1] or color.r or 1.0;
    local g = color[2] or color.g or 1.0;
    local b = color[3] or color.b or 1.0;
    local a = color[4] or color.a or 1.0;
    if (r <= 1.0 and g <= 1.0 and b <= 1.0 and (a <= 1.0 or a == nil)) then
        return clamp_byte(r * 255), clamp_byte(g * 255), clamp_byte(b * 255), clamp_byte(a * 255);
    end
    return clamp_byte(r), clamp_byte(g), clamp_byte(b), clamp_byte(a);
end

local function color_to_rgba(color)
    local r, g, b, a = color_to_bytes(color);
    return { r / 255, g / 255, b / 255, a / 255 };
end

local function copy_c_string(dst, src, maxLen)
    maxLen = maxLen or 31;
    ffi.fill(dst, maxLen + 1, 0);
    if (src == nil or src == '') then
        return;
    end
    ffi.copy(dst, tostring(src), math.min(#tostring(src), maxLen));
end

local function read_c_string(src)
    if (src == nil) then
        return '';
    end
    return ffi.string(src):match('^([^%z]*)') or '';
end

local function utf8_char_advance(message, byteIndex)
    local c0 = message:byte(byteIndex);
    if (c0 == nil) then
        return 0;
    end
    if (c0 >= 0xF0) then return 4; end
    if (c0 >= 0xE0) then return 3; end
    if (c0 >= 0xC0) then return 2; end
    return 1;
end

local function resolve_cycle_color(entry, defaultColor)
    if (entry == nil) then
        return defaultColor;
    end
    if (type(entry) == 'table' and entry.color ~= nil) then
        return entry.color;
    end
    return entry;
end

--- Colorize each UTF-8 character by cycling through `colors` (wraps at end of array).
function M.segments_from_cycle_colors(message, colors, defaultColor)
    message = tostring(message or '');
    if (colors == nil or #colors == 0) then
        return nil;
    end

    local runs = {};
    local colorCount = #colors;
    local charIndex = 0;
    local byteIndex = 1;

    while (byteIndex <= #message) do
        local len = utf8_char_advance(message, byteIndex);
        if (len <= 0) then
            break;
        end
        charIndex = charIndex + 1;
        local color = resolve_cycle_color(colors[((charIndex - 1) % colorCount) + 1], defaultColor);
        runs[#runs + 1] = {
            start = byteIndex - 1,
            length = len,
            color = color,
        };
        byteIndex = byteIndex + len;
    end

    return (#runs > 0) and runs or nil;
end

local function colors_equal(a, b)
    if (a == b) then
        return true;
    end
    if (a == nil or b == nil) then
        return false;
    end
    local ar, ag, ab, aa = color_to_bytes(a);
    local br, bg, bb, ba = color_to_bytes(b);
    return ar == br and ag == bg and ab == bb and aa == ba;
end

local function merge_adjacent_runs(runs)
    if (runs == nil or #runs == 0) then
        return nil;
    end
    local out = {
        {
            start = runs[1].start,
            length = runs[1].length,
            color = runs[1].color,
        },
    };
    for i = 2, #runs do
        local cur = runs[i];
        local prev = out[#out];
        if (colors_equal(prev.color, cur.color) and (prev.start + prev.length) == cur.start) then
            prev.length = prev.length + cur.length;
        else
            out[#out + 1] = {
                start = cur.start,
                length = cur.length,
                color = cur.color,
            };
        end
    end
    return out;
end

--- Merge adjacent runs with identical color; fill gaps with defaultColor.
local function normalize_runs(message, runs, defaultColor)
    if (runs == nil or #runs == 0) then
        return nil;
    end
    local msgLen = #message;
    table.sort(runs, function(a, b) return a.start < b.start; end);
    local out = {};
    local cursor = 0;
    for i = 1, #runs do
        local run = runs[i];
        local start = math.max(0, math.min(msgLen, tonumber(run.start) or 0));
        local length = tonumber(run.length);
        if (length == nil or length == 0) then
            length = msgLen - start;
        end
        length = math.max(0, math.min(msgLen - start, length));
        if (start > cursor and defaultColor ~= nil) then
            out[#out + 1] = { start = cursor, length = start - cursor, color = defaultColor };
        end
        if (length > 0) then
            out[#out + 1] = { start = start, length = length, color = run.color or defaultColor };
            cursor = start + length;
        end
    end
    if (cursor < msgLen and defaultColor ~= nil) then
        out[#out + 1] = { start = cursor, length = msgLen - cursor, color = defaultColor };
    end
    return (#out > 0) and out or nil;
end

local function segments_to_runs(segments, message, defaultColor)
    if (segments == nil or #segments == 0) then
        return nil;
    end
    local runs = {};
    local offset = 0;
    for i = 1, #segments do
        local seg = segments[i];
        local text = tostring(seg.text or '');
        if (text ~= '') then
            runs[#runs + 1] = {
                start = offset,
                length = #text,
                color = seg.color or defaultColor,
            };
            offset = offset + #text;
        end
    end
    if (message ~= nil and #message > 0 and offset ~= #message) then
        -- segments may not cover full message string; trust explicit message length.
        offset = #message;
    end
    return normalize_runs(message or '', runs, defaultColor);
end

function M.encode(opts)
    opts = opts or {};
    local message = tostring(opts.message or opts.text or '');
    local defaultColor = opts.color or opts.defaultColor;
    local runs = opts.runs;

    if (message == '' and opts.segments ~= nil and #opts.segments > 0) then
        local parts = {};
        for i = 1, #opts.segments do
            parts[i] = tostring(opts.segments[i].text or '');
        end
        message = table.concat(parts);
    end

    if (runs == nil and opts.segments ~= nil) then
        runs = segments_to_runs(opts.segments, message, defaultColor);
    elseif (runs == nil and (opts.colors ~= nil or opts.cycleColors ~= nil)) then
        local cycle = opts.colors or opts.cycleColors;
        runs = M.segments_from_cycle_colors(message, cycle, defaultColor);
        runs = merge_adjacent_runs(runs);
    end

    local struct = ffi.new('GlamourUI_CustomChat_t');
    struct.version = M.VERSION;
    struct.flags = tonumber(opts.flags) or M.FLAG_INJECTED;
    if (opts.injected == false) then
        struct.flags = bit.band(struct.flags, bit.bnot(M.FLAG_INJECTED));
    end
    if (opts.noDedupe == true) then
        struct.flags = bit.bor(struct.flags, M.FLAG_NO_DEDUPE);
    end

    copy_c_string(struct.sender, opts.sender or 'Addon', 31);
    copy_c_string(struct.purpose, opts.purpose or 'None', 31);

    local payloadMax = ffi.sizeof(struct.data);
    if (#message + 1 > payloadMax) then
        message = message:sub(1, payloadMax - 1);
    end

    local payloadOffset = #message + 1;
    ffi.copy(struct.data, message, #message);
    struct.data[payloadOffset - 1] = 0;

    local segCount = 0;
    if (runs ~= nil) then
        for i = 1, #runs do
            local run = runs[i];
            local start = tonumber(run.start) or 0;
            local length = tonumber(run.length) or 0;
            if (length == 0) then
                length = math.max(0, #message - start);
            end
            if (length > 0 and start < #message) then
                local need = payloadOffset + 8;
                if (need > payloadMax) then
                    break;
                end
                local r, g, b, a = color_to_bytes(run.color or defaultColor);
                struct.data[payloadOffset + 0] = bit.band(start, 0xFF);
                struct.data[payloadOffset + 1] = bit.rshift(start, 8);
                struct.data[payloadOffset + 2] = bit.band(length, 0xFF);
                struct.data[payloadOffset + 3] = bit.rshift(length, 8);
                struct.data[payloadOffset + 4] = r;
                struct.data[payloadOffset + 5] = g;
                struct.data[payloadOffset + 6] = b;
                struct.data[payloadOffset + 7] = a;
                payloadOffset = payloadOffset + 8;
                segCount = segCount + 1;
            end
        end
    end

    struct.segment_count = segCount;
    return ffi.string(struct, ffi.sizeof(struct)):totable();
end

function M.decode_from_raw(dataRaw)
    if (dataRaw == nil) then
        return nil;
    end
    local struct = ffi.cast('GlamourUI_CustomChat_t*', dataRaw);
    return M.decode_struct(struct);
end

function M.decode_from_table(dataTable)
    if (dataTable == nil or #dataTable < M.STRUCT_SIZE) then
        return nil;
    end
    local buf = ffi.new('char[?]', M.STRUCT_SIZE);
    for i = 1, M.STRUCT_SIZE do
        buf[i - 1] = string.char(bit.band(tonumber(dataTable[i]) or 0, 0xFF));
    end
    return M.decode_struct(ffi.cast('GlamourUI_CustomChat_t*', buf));
end

function M.decode_struct(struct)
    if (struct == nil) then
        return nil;
    end
    if (tonumber(struct.version) ~= M.VERSION) then
        return nil;
    end

    local data = ffi.string(struct.data, ffi.sizeof(struct.data));
    local message = data:match('^([^%z]*)') or '';
    local payloadStart = #message + 2;
    local segments = {};
    local segCount = tonumber(struct.segment_count) or 0;

    for si = 1, segCount do
        local base = payloadStart + (si - 1) * 8;
        if (base + 7 > #data) then
            break;
        end
        local start = data:byte(base) + data:byte(base + 1) * 256;
        local length = data:byte(base + 2) + data:byte(base + 3) * 256;
        local r = data:byte(base + 4);
        local g = data:byte(base + 5);
        local b = data:byte(base + 6);
        local a = data:byte(base + 7);
        if (length == 0) then
            length = math.max(0, #message - start);
        end
        local text = message:sub(start + 1, start + length);
        if (text ~= nil and text ~= '') then
            segments[#segments + 1] = {
                text = text,
                color = { (r or 255) / 255, (g or 255) / 255, (b or 255) / 255, (a or 255) / 255 },
                lockedColor = true,
            };
        end
    end

  local flags = tonumber(struct.flags) or 0;
    return {
        version = struct.version,
        flags = flags,
        message = message,
        sender = read_c_string(struct.sender),
        purpose = read_c_string(struct.purpose),
        segments = (#segments > 0) and segments or nil,
        injected = bit.band(flags, M.FLAG_INJECTED) ~= 0,
        noDedupe = bit.band(flags, M.FLAG_NO_DEDUPE) ~= 0,
    };
end

M.color_to_rgba = color_to_rgba;

function M.raise_event(name, data)
    if (AshitaCore == nil) then
        return;
    end
    AshitaCore:GetPluginManager():RaiseEvent(name, data or {});
end

function M.raise_ping()
    M.raise_event(M.PING_EVENT, { version = M.VERSION });
end

function M.raise_pong(payload)
    M.raise_event(M.PONG_EVENT, payload or { version = M.VERSION, chatWindowsEnabled = false });
end

function M.raise_ready(payload)
    M.raise_event(M.READY_EVENT, payload or { version = M.VERSION, chatWindowsEnabled = false });
end

function M.raise_gone()
    M.raise_event(M.GONE_EVENT, {});
end

function M.is_addon_loaded()
    if (AddonManager ~= nil and AddonManager.IsLoaded ~= nil) then
        return AddonManager:IsLoaded(M.ADDON_NAME) == true;
    end
    return false;
end

return M;
