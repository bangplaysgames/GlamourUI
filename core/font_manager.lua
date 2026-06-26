require('common');
local ffi = require('ffi');

ffi.cdef[[
    int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, uint16_t* lpWideCharStr, int cchWideChar);
]];

local kernel32 = ffi.load('kernel32');
local CP_SHIFT_JIS = 932;

local M = {};

M.cache = {};
M.font_names = T{};
M.shift_jis_font_names = T{};

-- Representative Shift-JIS wire bytes (same CP932 path as chatlog.lua).
local SJIS_WIRE_SAMPLES = {
    'ABC 0123 /command',
    string.char(0x81, 0x40),
    string.char(0x81, 0x44),
    string.char(0x81, 0x68),
    string.char(0x81, 0x6A),
    string.char(0x81, 0x73),
    string.char(0x81, 0x7B),
    string.char(0x81, 0x91),
    string.char(0x81, 0x92),
    string.char(0x81, 0x9B),
    string.char(0x81, 0x9F),
    string.char(0x81, 0xE0),
    string.char(0x81, 0xE3),
    string.char(0x81, 0xE7),
    string.char(0x82, 0xA0),
    string.char(0x82, 0xA2),
    string.char(0x82, 0xA4),
    string.char(0x82, 0xC5),
    string.char(0x82, 0xDC),
    string.char(0x83, 0x40),
    string.char(0x83, 0x4B),
    string.char(0x83, 0x93),
    string.char(0x88, 0x9E),
    string.char(0x93, 0xFA),
    string.char(0x95, 0x73),
    string.char(0x96, 0x7B),
    string.char(0x97, 0x4C),
    string.char(0x8C, 0xEA),
    string.char(0x8E, 0xA9),
};

local function read_u8(data, off)
    return data:byte(off) or 0;
end

local function read_u16_be(data, off)
    return read_u8(data, off) * 256 + read_u8(data, off + 1);
end

local function read_u32_be(data, off)
    return read_u16_be(data, off) * 65536 + read_u16_be(data, off + 2);
end

local function find_table_offset(data, tag)
    if (#data < 12) then
        return nil;
    end
    local numTables = read_u16_be(data, 4);
    for i = 0, numTables - 1 do
        local rec = 12 + (i * 16) + 1;
        if (data:sub(rec, rec + 3) == tag) then
            return read_u32_be(data, rec + 8);
        end
    end
    return nil;
end

local function cmap_format4_has_glyph(data, subOffset, codepoint)
    local base = subOffset + 1;
    local format = read_u16_be(data, base);
    if (format ~= 4) then
        return nil;
    end

    local segCount = read_u16_be(data, base + 6) / 2;
    if (segCount < 1) then
        return false;
    end

    local endCodeOff = base + 10;
    local startCodeOff = endCodeOff + (segCount * 2) + 2;
    local idDeltaOff = startCodeOff + (segCount * 2);
    local idRangeOff = idDeltaOff + (segCount * 2);
    local glyphIdArrayOff = idRangeOff + (segCount * 2);

    for seg = 0, segCount - 1 do
        local endCode = read_u16_be(data, endCodeOff + (seg * 2));
        local startCode = read_u16_be(data, startCodeOff + (seg * 2));
        if (codepoint >= startCode and codepoint <= endCode) then
            if (endCode == 0xFFFF) then
                return false;
            end
            local idRangeOffsetPos = idRangeOff + (seg * 2);
            local idDelta = read_u16_be(data, idDeltaOff + (seg * 2));
            local idRangeOffset = read_u16_be(data, idRangeOffsetPos);
            if (idRangeOffset ~= 0) then
                local glyphIndex = read_u16_be(data, idRangeOffsetPos + idRangeOffset + ((codepoint - startCode) * 2));
                return glyphIndex ~= 0;
            end
            local glyphId = (codepoint + idDelta) % 65536;
            return glyphId ~= 0;
        end
    end

    return false;
end

local function cmap_format12_has_glyph(data, subOffset, codepoint)
    local base = subOffset + 1;
    if (read_u16_be(data, base) ~= 12) then
        return nil;
    end

    local numGroups = read_u32_be(data, base + 12);
    local groupsOff = base + 16;
    for g = 0, numGroups - 1 do
        local go = groupsOff + (g * 12);
        local startChar = read_u32_be(data, go);
        local endChar = read_u32_be(data, go + 4);
        if (codepoint >= startChar and codepoint <= endChar) then
            local startGlyph = read_u32_be(data, go + 8);
            return (startGlyph + (codepoint - startChar)) ~= 0;
        end
    end
    return false;
end

local function cmap_subtable_priority(platform, encoding)
    if (platform == 3 and encoding == 10) then
        return 1;
    end
    if (platform == 3 and encoding == 1) then
        return 2;
    end
    if (platform == 0 and encoding == 4) then
        return 3;
    end
    if (platform == 0 and encoding == 3) then
        return 4;
    end
    if (platform == 0 and encoding == 1) then
        return 5;
    end
    return nil;
end

local function collect_cmap_subtables(data)
    local cmapOffset = find_table_offset(data, 'cmap');
    if (cmapOffset == nil) then
        return {};
    end

    local base = cmapOffset + 1;
    local numSub = read_u16_be(data, base + 2);
    local subs = {};

    for i = 0, numSub - 1 do
        local rec = base + 4 + (i * 8);
        local platform = read_u16_be(data, rec);
        local encoding = read_u16_be(data, rec + 2);
        local subOffset = read_u32_be(data, rec + 4);
        local priority = cmap_subtable_priority(platform, encoding);
        if (priority ~= nil) then
            subs[#subs + 1] = { priority = priority, offset = subOffset };
        end
    end

    table.sort(subs, function(a, b)
        return a.priority < b.priority;
    end);

    return subs;
end

local function cmap_has_glyph(data, codepoint, subtables)
    subtables = subtables or collect_cmap_subtables(data);
    for i = 1, #subtables do
        local sub = subtables[i].offset;
        local r12 = cmap_format12_has_glyph(data, sub, codepoint);
        if (r12 ~= nil) then
            return r12;
        end
        local r4 = cmap_format4_has_glyph(data, sub, codepoint);
        if (r4 ~= nil) then
            return r4;
        end
    end
    return false;
end

local function sjis_wire_to_codepoints(wire)
    if (wire == nil or #wire == 0) then
        return T{};
    end

    local wideLen = kernel32.MultiByteToWideChar(CP_SHIFT_JIS, 0, wire, #wire, nil, 0);
    if (wideLen <= 0) then
        return T{};
    end

    local wide = ffi.new('uint16_t[?]', wideLen);
    if (kernel32.MultiByteToWideChar(CP_SHIFT_JIS, 0, wire, #wire, wide, wideLen) <= 0) then
        return T{};
    end

    local out = T{};
    local seen = {};
    for i = 0, wideLen - 1 do
        local cp = wide[i];
        if (cp ~= nil and cp > 0 and seen[cp] ~= true) then
            seen[cp] = true;
            out[#out + 1] = cp;
        end
    end
    return out;
end

-- Extra Unicode used in FFXI chat rendering (autotranslate arrows, fullwidth, etc.).
local UNICODE_ESSENTIALS = {
    0x3000, 0x3001, 0x3002, 0x3042, 0x3044, 0x306F, 0x30A2, 0x30AB,
    0x4E00, 0x65E5, 0x8A9E, 0xFF0F, 0x2190, 0x2192, 0x25A0, 0x2605,
};

local function collect_wire_codepoints()
    local required = T{};
    local seen = {};

    local function add(cp)
        cp = tonumber(cp);
        if (cp == nil or cp <= 0 or seen[cp] == true) then
            return;
        end
        seen[cp] = true;
        required[#required + 1] = cp;
    end

    for i = 1, #SJIS_WIRE_SAMPLES do
        local cps = sjis_wire_to_codepoints(SJIS_WIRE_SAMPLES[i]);
        for j = 1, #cps do
            add(cps[j]);
        end
    end

    return required;
end

local SHIFT_JIS_WIRE_CODEPOINTS = collect_wire_codepoints();
local SHIFT_JIS_ESSENTIAL_CODEPOINTS = T{};
do
    local seen = {};
    for i = 1, #SHIFT_JIS_WIRE_CODEPOINTS do
        local cp = SHIFT_JIS_WIRE_CODEPOINTS[i];
        if (seen[cp] ~= true) then
            seen[cp] = true;
            SHIFT_JIS_ESSENTIAL_CODEPOINTS[#SHIFT_JIS_ESSENTIAL_CODEPOINTS + 1] = cp;
        end
    end
    for i = 1, #UNICODE_ESSENTIALS do
        local cp = UNICODE_ESSENTIALS[i];
        if (seen[cp] ~= true) then
            seen[cp] = true;
            SHIFT_JIS_ESSENTIAL_CODEPOINTS[#SHIFT_JIS_ESSENTIAL_CODEPOINTS + 1] = cp;
        end
    end
end

function M.test_shift_jis_coverage_from_bytes(data)
    if (data == nil or #data < 12) then
        return false, 0, 0;
    end

    local subtables = collect_cmap_subtables(data);
    if (#subtables == 0) then
        return false, 0, 0;
    end

    local wireMissing = 0;
    for i = 1, #SHIFT_JIS_WIRE_CODEPOINTS do
        if (not cmap_has_glyph(data, SHIFT_JIS_WIRE_CODEPOINTS[i], subtables)) then
            wireMissing = wireMissing + 1;
        end
    end

    local essentialMissing = 0;
    for i = 1, #SHIFT_JIS_ESSENTIAL_CODEPOINTS do
        if (not cmap_has_glyph(data, SHIFT_JIS_ESSENTIAL_CODEPOINTS[i], subtables)) then
            essentialMissing = essentialMissing + 1;
        end
    end

    local wireTotal = #SHIFT_JIS_WIRE_CODEPOINTS;
    local essentialTotal = #SHIFT_JIS_ESSENTIAL_CODEPOINTS;
    local essentialCovered = essentialTotal - essentialMissing;
    local wireOk = (wireMissing == 0);
    local essentialOk = (essentialTotal == 0) or (essentialCovered / essentialTotal >= 0.85);
    local ok = wireOk and essentialOk;

    return ok, essentialCovered, essentialTotal;
end

function M.analyze_font_file(path)
    local f = io.open(path, 'rb');
    if (f == nil) then
        return {
            supports_shift_jis = false,
            tested = 0,
            covered = 0,
            error = 'unreadable',
        };
    end

    local data = f:read('*all');
    f:close();

    local ok, covered, total = M.test_shift_jis_coverage_from_bytes(data);
    return {
        supports_shift_jis = ok == true,
        tested = total,
        covered = covered,
        error = nil,
    };
end

function M.get_font_path(filename)
    if (filename == nil or filename == '') then
        return nil;
    end
    return ('%s\\config\\addons\\%s\\Fonts\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, filename);
end

local function list_ttf_filenames(dir)
    local out = {};
    local seen = {};

    local function add_entry(name)
        if (type(name) ~= 'string') then
            return;
        end
        local base = name:match('[^\\/]+$') or name;
        if (not base:lower():find('%.ttf$')) then
            return;
        end
        if (seen[base] == true) then
            return;
        end
        seen[base] = true;
        out[#out + 1] = base;
    end

    local lists = {
        ashita.fs.get_directory(dir, '.ttf'),
        ashita.fs.get_dir(dir, '.ttf'),
        ashita.fs.get_dir(dir, '.*'),
    };

    for li = 1, #lists do
        local files = lists[li];
        if (files ~= nil) then
            for i = 1, #files do
                add_entry(files[i]);
            end
        end
    end

    table.sort(out);
    return out;
end

function M.scan_directory(dir)
    M.cache = {};
    M.font_names = T{};
    M.shift_jis_font_names = T{};

    local files = list_ttf_filenames(dir);
    for i = 1, #files do
        local name = files[i];
        local path = dir .. name;
        local meta = M.analyze_font_file(path);
        meta.filename = name;
        M.cache[name] = meta;
        M.font_names[#M.font_names + 1] = name;
        if (meta.supports_shift_jis == true) then
            M.shift_jis_font_names[#M.shift_jis_font_names + 1] = name;
        end
    end

    table.sort(M.font_names);
    table.sort(M.shift_jis_font_names);
end

function M.get_meta(filename)
    return M.cache[filename];
end

function M.supports_shift_jis(filename)
    local meta = M.cache[filename];
    return meta ~= nil and meta.supports_shift_jis == true;
end

function M.get_all_font_names()
    return M.font_names;
end

function M.get_shift_jis_font_names()
    return M.shift_jis_font_names;
end

function M.pick_shift_jis_fallback(preferred, defaultName)
    if (preferred ~= nil and preferred ~= '' and M.supports_shift_jis(preferred)) then
        return preferred;
    end
    if (defaultName ~= nil and defaultName ~= '' and M.supports_shift_jis(defaultName)) then
        return defaultName;
    end
    if (#M.shift_jis_font_names > 0) then
        return M.shift_jis_font_names[1];
    end
    return preferred or defaultName;
end

return M;
