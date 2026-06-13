--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--


addon.name = 'GlamourUI';
addon.author = 'Banggugyangu';
addon.desc = "A modular and customizable interface for FFXI";
addon.version = '2.1.0';

local function glam_normalize_root(path)
    path = tostring(path or '');
    if (path == '') then
        path = AshitaCore:GetInstallPath() .. 'addons/GlamourUI/';
    end
    if (path:sub(-1) ~= '/' and path:sub(-1) ~= '\\') then
        path = path .. '/';
    end
    return path;
end

local function glam_setup_package_path()
    local root = glam_normalize_root(addon.path);
    GlamourUI_ROOT = root;
    local entries = {
        root .. '?.lua',
        root .. 'core/?.lua',
        root .. 'ui/?.lua',
        root .. 'chat/?.lua',
        root .. 'chat/libs/?.lua',
        root .. 'net/?.lua',
        root .. 'map/?.lua',
        root .. 'combat/?.lua',
        root .. 'combat/combatParse/?.lua',
        root .. 'data/?.lua',
    };
    -- Ashita already prepends addon root to package.path; do not skip subfolders when root is present.
    for i = #entries, 1, -1 do
        local entry = entries[i];
        if (package.path:find(entry, 1, true) == nil) then
            package.path = entry .. ';' .. package.path;
        end
    end
end

glam_setup_package_path();

local settings = require('settings');
require('common');

--Global Module Definitions
gParty = require('party');
gTarget = require('target');
gInv = require('inventory');
gRecast = require('recast');
gPacket = require('packethandler');
gEffects = require('effects');
gHelper = require('helpers');
gConf = require('conf');
gFirstRun = require('firstrun_wizard');
gUI = require('render');
gResources = require('resources');
gCBar = require('cbar');
gHide = require('hideDefault');
gEnv = require('environment');
gMinimap = require('minimap');
gFullscreenMap = require('fullscreen_map');
gChat = require('chatlog');
local customChat = require('customChat');
local chatGamepad = require('chat_gamepad');
local panelStyleLib = require('panelStyle');

local imgui = require('imgui');
local textShadow = require('textShadow');
textShadow.install(imgui);
local chat = require('chat');
local nativeStatusBlock = require('native_status_block');

local menu = '';
local lastGameMenu = nil;
local wasZoning = false;

-- Transient debug overlay for tracking menu names as they open.
local menuDebug = {
    name = '',
    shownUntilClock = 0,
};

-- Forward declarations (used before definition).
local unbind_buff_cancel_keys = nil;
local glam_sync_ui_keybinds = nil;
local buff_cancel_mode_off = nil;
local player_has_any_buff = nil;

-- Silent keybind helpers (no chatlog spam).
local modifiers = {
    ['!'] = 'alt',
    ['^'] = 'ctrl',
    ['@'] = 'win',
    ['+'] = 'shift',
    ['#'] = 'apps',
};

local function parse_hotkey(hotkey)
    local defaults = {
        alt = false,
        ctrl = false,
        win = false,
        apps = false,
        shift = false,
    };

    local working = hotkey;
    local firstChar = string.sub(working, 1, 1);
    while (modifiers[firstChar] ~= nil) do
        defaults[modifiers[firstChar]] = true;
        working = string.sub(working, 2);
        firstChar = string.sub(working, 1, 1);
    end

    return working, defaults;
end

local function kb_bind(hotkey, command)
    local working, mods = parse_hotkey(hotkey);
    local kb = AshitaCore:GetInputManager():GetKeyboard();
    kb:Bind(kb:S2D(working), true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, true, false, command);
end

local function kb_unbind(hotkey)
    local working, mods = parse_hotkey(hotkey);
    local kb = AshitaCore:GetInputManager():GetKeyboard();
    kb:Unbind(kb:S2D(working), true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, true, false);
end

local function apply_defaults(dst, defaults)
    if (dst == nil or type(dst) ~= 'table') then
        return defaults:copy(true);
    end
    if (defaults == nil or type(defaults) ~= 'table') then
        return dst;
    end
    for k, dv in pairs(defaults) do
        local v = dst[k];
        if (v == nil) then
            if (type(dv) == 'table') then
                dst[k] = dv:copy(true);
            else
                dst[k] = dv;
            end
        elseif (type(dv) == 'table') then
            if (type(v) ~= 'table') then
                dst[k] = dv:copy(true);
            else
                apply_defaults(v, dv);
            end
        end
    end
    return dst;
end

local struct = require('struct');
local xipacketsDecode = require('xipackets_decode');

local PACKET_DEBUG_RING_MAX = 128;
local packetDebugRing = {};
local PACKET_DEBUG_IGNORE_INCOMING = {
    [0x00E] = true, -- 0x0E
};
local PACKET_DEBUG_RAW_PREVIEW_BYTES = 512;

local packetDebugLogDirReady = false;
local packetDebugLogDir = nil;

local function ensure_packet_debug_log_dir()
    if (packetDebugLogDirReady == true) then
        return packetDebugLogDir;
    end
    local installPath = AshitaCore:GetInstallPath();
    local dir = ('%s\\config\\addons\\%s\\Logs'):fmt(installPath, addon.name);
    if (not ashita.fs.exists(dir)) then
        ashita.fs.create_directory(dir);
    end
    packetDebugLogDirReady = true;
    packetDebugLogDir = dir;
    return dir;
end

local function build_packet_in_disk_block(entry)
    local stamp = os.date('!%Y-%m-%dT%H:%M:%SZ');
    local parts = {};
    parts[#parts + 1] = '================================================================================';
    parts[#parts + 1] = ('[%s] id=0x%03X  size=%u bytes'):fmt(stamp, entry.id, entry.size);
    if (entry.extra ~= nil) then
        parts[#parts + 1] = ('flags: %s'):fmt(entry.extra);
    end
    parts[#parts + 1] = ('--- e.data raw hex + ASCII (first %u bytes) ---'):fmt(PACKET_DEBUG_RAW_PREVIEW_BYTES);
    parts[#parts + 1] = entry.rawHexPreview or '';
    parts[#parts + 1] = '--- XiPackets typed decode (e.data) ---';
    parts[#parts + 1] = entry.xipacketsText or '';
    parts[#parts + 1] = '--- packet_in event fields ---';
    parts[#parts + 1] = entry.eventFields or '';
    parts[#parts + 1] = '--- heuristic decode (grids / full hex) ---';
    parts[#parts + 1] = entry.analysis or '';
    if (entry.hasModified == true) then
        parts[#parts + 1] = ('--- e.data_modified (%u bytes) raw preview ---'):fmt(entry.modifiedSize or 0);
        parts[#parts + 1] = entry.modifiedHexPreview or '';
        parts[#parts + 1] = '--- XiPackets (data_modified) ---';
        parts[#parts + 1] = entry.xipacketsModified or '';
        parts[#parts + 1] = '--- heuristic (data_modified) ---';
        parts[#parts + 1] = entry.modifiedAnalysis or '';
    end
    parts[#parts + 1] = '================================================================================';
    parts[#parts + 1] = '';
    return table.concat(parts, '\n');
end

local function append_packet_in_disk(entry)
    pcall(function()
        local dir = ensure_packet_debug_log_dir();
        local path = ('%s\\packet_in_%s.log'):fmt(dir, os.date('%Y-%m-%d'));
        local f = io.open(path, 'a+');
        if (f == nil) then
            return;
        end
        f:write(build_packet_in_disk_block(entry));
        f:close();
    end);
end

local PACKET_DEBUG_HEX_CAP = 65536;
local PACKET_DEBUG_SCALAR_MAX = 1024;

local function hex_dump_packet_payload(str, maxBytes)
    if (str == nil or #str == 0) then
        return '(empty)';
    end
    maxBytes = maxBytes or PACKET_DEBUG_HEX_CAP;
    maxBytes = math.min(maxBytes, #str, PACKET_DEBUG_HEX_CAP);
    local lines = {};
    local width = 16;
    for offset = 0, maxBytes - 1, width do
        local hex = {};
        local asc = {};
        for i = 1, math.min(width, maxBytes - offset) do
            local b = string.byte(str, offset + i);
            hex[#hex + 1] = ('%02X '):format(b);
            asc[#asc + 1] = (b >= 32 and b < 127) and string.char(b) or '.';
        end
        lines[#lines + 1] = ('%04X  %s | %s'):format(offset, table.concat(hex), table.concat(asc));
    end
    if (#str > maxBytes) then
        lines[#lines + 1] = ('... %u more byte(s) not shown (cap=%u)'):format(#str - maxBytes, PACKET_DEBUG_HEX_CAP);
    end
    return table.concat(lines, '\n');
end

local function dump_packet_event_fields(e)
    if (type(e) ~= 'table') then
        return '(event is not a table)';
    end
    local keys = {};
    for k in pairs(e) do
        keys[#keys + 1] = k;
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b);
    end);
    local out = {};
    for i = 1, #keys do
        local k = keys[i];
        local v = e[k];
        local t = type(v);
        if (t == 'string') then
            out[#out + 1] = ('%s = <string, %u bytes>'):format(tostring(k), #v);
        elseif (t == 'table') then
            out[#out + 1] = ('%s = <table>'):format(tostring(k));
        elseif (t == 'boolean' or t == 'number' or t == 'nil') then
            out[#out + 1] = ('%s = %s'):format(tostring(k), tostring(v));
        else
            out[#out + 1] = ('%s = <%s>'):format(tostring(k), t);
        end
    end
    if (#out == 0) then
        return '(empty event table)';
    end
    return table.concat(out, '\n');
end

local function try_printable_substring(data, n, start0)
    if (start0 < 0 or start0 >= n) then
        return nil;
    end
    local maxLen = math.min(96, n - start0);
    local chunk = string.sub(data, start0 + 1, start0 + maxLen);
    local z = string.find(chunk, '\0', 1, true);
    local s = z and string.sub(chunk, 1, z - 1) or chunk;
    if (s == nil or #s < 2) then
        return nil;
    end
    local printable = 0;
    for j = 1, #s do
        local b = string.byte(s, j);
        if (b >= 32 and b < 127) then
            printable = printable + 1;
        end
    end
    if (printable < math.max(2, math.floor(#s * 0.65))) then
        return nil;
    end
    return s;
end

local function analyze_incoming_packet_payload(packetId, data)
    if (data == nil or #data == 0) then
        return 'size=0';
    end
    local lines = {};
    local n = #data;
    local span = math.min(n, PACKET_DEBUG_SCALAR_MAX);
    lines[#lines + 1] = ('size=%u bytes'):format(n);
    lines[#lines + 1] = ('packet id (event e.id): 0x%03X'):format(tonumber(packetId) or 0);
    lines[#lines + 1] = '\n--- heuristic decode (raw offsets / grids / hex — XiPackets + raw preview are shown above in the debug window) ---';

    pcall(function()
        if (n >= 2) then
            local hdr = struct.unpack('H', data, 1);
            local sizeWords = bit.rshift(hdr, 9);
            local hdrLow = bit.band(hdr, 0x01FF);
            lines[#lines + 1] = ('wire u16 @0x00: 0x%04X | sizeWords=%u (%u byte hint) | low9=0x%03X'):format(
                hdr, sizeWords, sizeWords * 4, hdrLow);
        end
        if (n >= 4) then
            local v = struct.unpack('I', data, 1);
            lines[#lines + 1] = ('u32 LE @0x00: %u (0x%08X)'):format(v, v);
        end
        pcall(function()
            if (n >= 4) then
                local be = struct.unpack('>I', data, 1);
                lines[#lines + 1] = ('u32 BE @0x00: %u (0x%08X)'):format(be, be);
            end
        end);
        if (n >= 5) then
            local b = struct.unpack('B', data, 5);
            lines[#lines + 1] = ('u8 @0x04: %u / 0x%02X'):format(b, b);
        end
        if (n >= 8) then
            local v = struct.unpack('I', data, 5);
            lines[#lines + 1] = ('u32 LE @0x04: %u (0x%08X)'):format(v, v);
        end
        if (n >= 10) then
            local v = struct.unpack('H', data, 9);
            lines[#lines + 1] = ('u16 LE @0x08: %u (0x%04X)'):format(v, v);
        end
        if (n >= 12) then
            local v = struct.unpack('H', data, 11);
            lines[#lines + 1] = ('u16 LE @0x0A: %u (0x%04X)'):format(v, v);
        end
    end);

    lines[#lines + 1] = ('\n--- u16 LE grid (first %u bytes, 8 values per row) ---'):format(span);
    for row = 0, span - 1, 16 do
        local parts = {};
        for col = 0, 14, 2 do
            local o = row + col;
            if (o + 2 <= n) then
                local u = struct.unpack('H', data, o + 1);
                parts[#parts + 1] = ('%04X'):format(u);
            end
        end
        if (#parts > 0) then
            lines[#lines + 1] = ('  0x%02X  %s'):format(row, table.concat(parts, ' '));
        end
    end

    lines[#lines + 1] = ('\n--- u32/i32/f32 LE @ 4-byte aligned (first %u bytes) ---'):format(span);
    for o = 0, span - 4, 4 do
        if (o + 4 <= n) then
            local okU, u = pcall(function()
                return struct.unpack('I', data, o + 1);
            end);
            if (okU and u ~= nil) then
                local bits = { ('  0x%02X  u32=%u (0x%08X)'):format(o, u, u) };
                pcall(function()
                    bits[#bits + 1] = ('i32=%d'):format(struct.unpack('i', data, o + 1));
                end);
                pcall(function()
                    bits[#bits + 1] = ('f=%g'):format(struct.unpack('f', data, o + 1));
                end);
                lines[#lines + 1] = table.concat(bits, '  ');
            end
        end
    end

    lines[#lines + 1] = '\n--- printable / null-terminated probes (first 128 start offsets) ---';
    local strHits = 0;
    local maxStrHits = 48;
    for start0 = 0, math.min(n - 1, 127) do
        local s = try_printable_substring(data, n, start0);
        if (s ~= nil) then
            strHits = strHits + 1;
            if (strHits <= maxStrHits) then
                lines[#lines + 1] = ('  @0x%02X  %q'):format(start0, s);
            end
        end
    end
    if (strHits > maxStrHits) then
        lines[#lines + 1] = ('  ... %u more probe hit(s) omitted'):format(strHits - maxStrHits);
    end

    lines[#lines + 1] = ('\nhex + ASCII (up to %u bytes):\n%s'):format(PACKET_DEBUG_HEX_CAP, hex_dump_packet_payload(data, nil));
    return table.concat(lines, '\n');
end

local function packet_debug_capture_incoming(e)
    if (GlamourUI.debug ~= true or e == nil) then
        return;
    end
    local id = tonumber(e.id) or 0;
    if (PACKET_DEBUG_IGNORE_INCOMING[id] == true) then
        return;
    end
    local data = e.data or '';
    local mod = e.data_modified;
    local extra = {};
    if (e.blocked ~= nil) then
        extra[#extra + 1] = ('blocked=%s'):format(tostring(e.blocked));
    end
    if (e.injected ~= nil) then
        extra[#extra + 1] = ('injected=%s'):format(tostring(e.injected));
    end

    local xiText = '';
    pcall(function()
        xiText = xipacketsDecode.format_world_server_packet(id, data);
    end);
    local xiModified = '';
    if (mod ~= nil and type(mod) == 'string' and mod ~= data and #mod > 0) then
        pcall(function()
            xiModified = xipacketsDecode.format_world_server_packet(id, mod);
        end);
    end

    local entry = {
        id = id,
        size = #data,
        clock = os.clock(),
        extra = (#extra > 0) and table.concat(extra, ', ') or nil,
        rawHexPreview = hex_dump_packet_payload(data, PACKET_DEBUG_RAW_PREVIEW_BYTES),
        xipacketsText = xiText,
        eventFields = dump_packet_event_fields(e),
        analysis = analyze_incoming_packet_payload(id, data),
        hasModified = (mod ~= nil and type(mod) == 'string' and mod ~= data and #mod > 0),
    };

    if (entry.hasModified == true) then
        entry.modifiedSize = #mod;
        entry.modifiedHexPreview = hex_dump_packet_payload(mod, PACKET_DEBUG_RAW_PREVIEW_BYTES);
        entry.xipacketsModified = xiModified;
        entry.modifiedAnalysis = analyze_incoming_packet_payload(id, mod);
        entry.modifiedHex = hex_dump_packet_payload(mod, nil);
    end

    table.insert(packetDebugRing, 1, entry);
    while (#packetDebugRing > PACKET_DEBUG_RING_MAX) do
        table.remove(packetDebugRing);
    end

    append_packet_in_disk(entry);
end

local PACKET_DEBUG_UI_TEXT_CHUNK = 16384;

local function imgui_text_wrapped_chunked(s)
    if (s == nil or type(s) ~= 'string' or s == '') then
        return;
    end
    if (#s <= PACKET_DEBUG_UI_TEXT_CHUNK) then
        imgui.TextWrapped(s);
        return;
    end
    local i = 1;
    while (i <= #s) do
        local j = math.min(#s, i + PACKET_DEBUG_UI_TEXT_CHUNK - 1);
        if (j < #s) then
            local rel = s:sub(i, j):match('.*()\n');
            if (rel ~= nil and rel > 1) then
                j = i + rel - 1;
            end
        end
        imgui.TextWrapped(s:sub(i, j));
        i = j + 1;
    end
end

local function render_packet_debug_window()
    if (GlamourUI.debug ~= true) then
        return;
    end

    imgui.SetNextWindowSize({760, 560}, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowPos({40, 80}, ImGuiCond_FirstUseEver);

    local flags = bit.bor(ImGuiWindowFlags_None, ImGuiWindowFlags_NoCollapse);

    local open = imgui.Begin('GlamourUI packet debug##GlamPktDbg', true, flags);
    local okDraw, drawErr = pcall(function()
        if (not open) then
            return;
        end
        imgui.TextDisabled(('Last %u incoming packets (newest first). Toggle: /glam debug'):format(PACKET_DEBUG_RING_MAX));
        if (GlamourUI.PartyList ~= nil and GlamourUI.PartyList.Pos ~= nil) then
            imgui.Text(('PartyList.Pos: %s'):format(tostring(GlamourUI.PartyList.Pos)));
        end
        if (imgui.Button('Clear packet log')) then
            packetDebugRing = {};
        end
        imgui.SameLine();
        imgui.TextDisabled('(does not affect gameplay)');

        imgui.Separator();

        imgui.BeginChild('glam_pkt_scroll', { 0, -20 }, ImGuiChildFlags_Borders);
        if (#packetDebugRing == 0) then
            imgui.TextWrapped('No packets captured yet. Wait for traffic, or confirm /glam debug is on.');
        else
            for i = 1, #packetDebugRing do
                local ent = packetDebugRing[i];
                local title = string.format('0x%03X  %u bytes  #%u', ent.id, ent.size, i);
                if (ent.extra ~= nil) then
                    title = title .. ('  [' .. ent.extra .. ']');
                end
                if (imgui.CollapsingHeader(title, bit.bor(ImGuiTreeNodeFlags_CollapsingHeader, ImGuiTreeNodeFlags_DefaultOpen))) then
                    imgui.TextColored({ 1.0, 0.92, 0.35, 1.0 }, ('PACKET DATA  |  e.data  %u bytes  |  opcode 0x%03X'):format(ent.size or 0, ent.id or 0));
                    imgui.Spacing();
                    imgui.TextColored({ 1.0, 0.85, 0.45, 1.0 }, ('Raw payload (hex + ASCII, first %u bytes of e.data)'):format(PACKET_DEBUG_RAW_PREVIEW_BYTES));
                    imgui_text_wrapped_chunked(ent.rawHexPreview or '(empty)');
                    imgui.Separator();
                    imgui.TextColored({ 0.45, 1.0, 0.82, 1.0 }, 'XiPackets typed fields (world/server — github.com/atom0s/XiPackets)');
                    imgui_text_wrapped_chunked(ent.xipacketsText ~= nil and ent.xipacketsText ~= '' and ent.xipacketsText or '(none / unpack failed)');
                    imgui.Separator();
                    imgui.TextDisabled('packet_in event table (Ashita):');
                    imgui_text_wrapped_chunked(ent.eventFields or '');
                    imgui.Separator();
                    imgui.TextColored({ 0.72, 0.82, 1.0, 1.0 }, 'Heuristic decode (grids, probes, full hex — scroll down)');
                    imgui.PushStyleColor(ImGuiCol_Text, { 0.75, 0.85, 1.0, 1.0 });
                    imgui_text_wrapped_chunked(ent.analysis or '');
                    imgui.PopStyleColor();
                    if (ent.hasModified == true) then
                        imgui.Spacing();
                        imgui.TextColored({ 1.0, 0.55, 0.55, 1.0 }, ('e.data_modified  %u bytes  (differs from e.data)'):format(ent.modifiedSize or 0));
                        imgui.TextColored({ 1.0, 0.85, 0.45, 1.0 }, ('Modified raw preview (first %u bytes)'):format(PACKET_DEBUG_RAW_PREVIEW_BYTES));
                        imgui_text_wrapped_chunked(ent.modifiedHexPreview or '');
                        imgui.Separator();
                        imgui.TextColored({ 0.45, 1.0, 0.82, 1.0 }, 'XiPackets (data_modified)');
                        imgui_text_wrapped_chunked(ent.xipacketsModified or '');
                        imgui.Separator();
                        imgui.TextColored({ 0.72, 0.82, 1.0, 1.0 }, 'Heuristic (data_modified)');
                        imgui_text_wrapped_chunked(ent.modifiedAnalysis or '');
                        if (ent.modifiedHex ~= nil) then
                            imgui.Separator();
                            imgui.TextDisabled('Full hex dump (data_modified)');
                            imgui_text_wrapped_chunked(ent.modifiedHex);
                        end
                    end
                end
            end
        end
        imgui.EndChild();
    end);
    if (okDraw ~= true and drawErr ~= nil) then
        print(('[GlamourUI] packet debug draw: %s'):format(tostring(drawErr)));
    end
    imgui.End();
end

local chatCombatPurposeOrder = T{
    'Add Buff',
    'Add Debuff',
    'Lose Effect',
    'Lose Debuff',
    'Damage Dealt',
    'Damage Taken',
    'Mob Ready',
    'Evade',
    'Miss',
    'HP Recovered',
    'Spell Cast',
    'Spell Complete',
    'Kill',
    'Spoils',
    'Interrupted',
    'After Battle',
    'Ability Not Ready',
    'Remove Debuff',
};

local chatPurposeOrder = T{
    'Say',
    'Emote',
    'Party',
    'LS[1]',
    'LS[2]',
    'Tell',
    'Shout',
    'Yell',
    'System',
    'Check',
    'Unity',
    'Assist[J]',
    'Assist[E]',
    'NPC',
    'Add Effect',
    'Special',
    'GoV',
    'Echo',
    'Command Error',
    'None',
};

for i = 1, #chatCombatPurposeOrder do
    chatPurposeOrder[#chatPurposeOrder + 1] = chatCombatPurposeOrder[i];
end

local function argb_to_rgba01(argb)
    argb = tonumber(argb) or 0xFFFFFFFF;
    return {
        bit.band(bit.rshift(argb, 16), 0xFF) / 255.0,
        bit.band(bit.rshift(argb, 8), 0xFF) / 255.0,
        bit.band(argb, 0xFF) / 255.0,
        bit.band(bit.rshift(argb, 24), 0xFF) / 255.0,
    };
end

-- FFXI retail battle-log channel colors (ARGB from native chat mode palette).
local COMBAT_COLOR = argb_to_rgba01(0xFFDCF1FC);
local COMBAT_SPELL_COLOR = argb_to_rgba01(0xFFDDC9FF);
local COMBAT_SYSTEM_COLOR = argb_to_rgba01(0xFFFFF3DA);

local defaultChatCombatPurposeColors = T{
    ['Add Buff'] = COMBAT_SPELL_COLOR,
    ['Add Debuff'] = COMBAT_SPELL_COLOR,
    ['Lose Effect'] = COMBAT_SPELL_COLOR,
    ['Lose Debuff'] = COMBAT_SPELL_COLOR,
    ['Damage Dealt'] = COMBAT_COLOR,
    ['Damage Taken'] = COMBAT_COLOR,
    ['Mob Ready'] = COMBAT_COLOR,
    ['Evade'] = COMBAT_COLOR,
    ['Miss'] = COMBAT_COLOR,
    ['HP Recovered'] = COMBAT_SPELL_COLOR,
    ['Spell Cast'] = COMBAT_SPELL_COLOR,
    ['Spell Complete'] = COMBAT_SPELL_COLOR,
    ['Kill'] = COMBAT_COLOR,
    ['Spoils'] = COMBAT_SYSTEM_COLOR,
    ['Interrupted'] = COMBAT_COLOR,
    ['After Battle'] = COMBAT_SYSTEM_COLOR,
    ['Ability Not Ready'] = COMBAT_COLOR,
    ['Remove Debuff'] = COMBAT_SPELL_COLOR,
};

local knownChatColorCodes = T{
    { code = '01', label = 'Default Text', color = { 1.0, 1.0, 1.0, 1.0 } },
    { code = '02', label = 'Item / Highlight Text', color = { 1.0, 0.9, 0.2, 1.0 } },
    { code = '06', label = 'System Header', color = { 0.35, 0.8, 1.0, 1.0 } },
    { code = '08', label = 'RoE Objective Highlight', color = { 1.0, 0.65, 0.2, 1.0 } },
    { code = '44', label = 'Error Framing Text', color = { 1.0, 0.45, 0.45, 1.0 } },
    { code = '52', label = 'Check NM Name', color = { 1.0, 0.82, 0.20, 1.0 } },
    { code = '51', label = 'Header Brackets', color = { 0.85, 0.85, 0.9, 1.0 } },
    { code = '68', label = 'Error Subject', color = { 0.8, 0.55, 1.0, 1.0 } },
    { code = '6A', label = 'System Detail Text', color = { 0.75, 0.85, 0.95, 1.0 } },
    { code = '9C', label = 'Actor Name Group A', color = { 0.45, 0.75, 1.0, 1.0 } },
    { code = 'F7', label = 'Actor Name Group B', color = { 1.0, 0.95, 0.95, 1.0 } },
};

local defaultChatTrinityColors = T{
    tank = { 0.25, 0.55, 1.0, 1.0 },
    healer = { 0.20, 0.90, 0.35, 1.0 },
    damage = { 1.0, 0.25, 0.25, 1.0 },
    hybrid = { 0.72, 0.35, 1.0, 1.0 },
    monster = { 1.0, 0.45, 0.62, 1.0 },
    other = { 1.0, 1.0, 1.0, 1.0 },
};

local defaultChatPurposeColors = T{
    ['Say'] = {1.0, 1.0, 1.0, 1.0 },
    ['Emote'] = {0.95, 0.55, 0.95, 1.0 },
    ['Party'] = {0.0, 0.1, 1.0, 1.0 },
    ['LS[1]'] = {0.0, 1.0, 0.0, 1.0 },
    ['LS[2]'] = {0.2, 1.0, 0.2, 1.0 },
    ['Tell'] = {0.3, 0.0, 1.0, 1.0 },
    ['Shout'] = {0.8, 0.8, 0.4, 1.0 },
    ['Yell'] = {0.9, 0.7, 0.3, 1.0 },
    ['System'] = {0.8, 0.8, 0.8, 1.0 },
    ['Check'] = {0.92, 0.92, 0.88, 1.0 },
    ['Unity'] = {0.85, 0.8, 0.4, 1.0 },
    ['Assist[J]'] = {1.0, 1.0, 1.0, 1.0 },
    ['Assist[E]'] = {1.0, 1.0, 1.0, 1.0 },
    ['NPC'] = {1.0, 1.0, 1.0, 1.0 },
    ['Add Effect'] = {0.1, 0.7, 0.8, 1.0 },
    ['Special'] = {0.2, 0.5, 0.75, 1.0 },
    ['Echo'] = {0.8, 0.8, 0.6, 1.0 },
    ['Command Error'] = {1.0, 0.2, 0.2, 1.0},
    ['GoV'] = {0.75, 0.75, 0.75, 0.75 },
    ['None'] = {0.65, 0.65, 0.65, 1.0 },
};

for i = 1, #chatCombatPurposeOrder do
    local purpose = chatCombatPurposeOrder[i];
    defaultChatPurposeColors[purpose] = defaultChatCombatPurposeColors[purpose];
end

local function build_chat_window_defaults(enabled, combatEnabled)
    local window = T{
        enabled = enabled,
        x = 10,
        y = enabled and 500 or 100,
        width = 760,
        height = 260,
        font_scale = 1.0,
    };

    for i = 1, #chatPurposeOrder do
        window[chatPurposeOrder[i]] = false;
    end

    if (combatEnabled) then
        window['Add Effect'] = true;
        window['Check'] = true;
        window['Special'] = true;
        window['None'] = true;
        for i = 1, #chatCombatPurposeOrder do
            window[chatCombatPurposeOrder[i]] = true;
        end
    else
        window['Say'] = true;
        window['Emote'] = true;
        window['Party'] = true;
        window['LS[1]'] = true;
        window['LS[2]'] = true;
        window['Tell'] = true;
        window['Shout'] = true;
        window['Yell'] = true;
        window['Check'] = true;
        window['Unity'] = true;
        window['Assist[J]'] = true;
        window['Assist[E]'] = true;
        window['NPC'] = true;
    end

    return window;
end

local function build_chat_code_colors()
    local colors = T{};
    for i = 1, #knownChatColorCodes do
        local entry = knownChatColorCodes[i];
        colors[entry.code] = {
            entry.color[1],
            entry.color[2],
            entry.color[3],
            entry.color[4],
        };
    end
    return colors;
end

local function build_chat_defaults()
    return T{
        enabled = true,
        persistChatLog = true,
        actionPacket28LegacyHeader = false,
        forceNativeChatHidden = true,
        maxEntries = 1000,
        selectedColorCode = '01',
        inputFontScale = 1.0,
        inputPanelBackground = nil,
        purposeColors = T(defaultChatPurposeColors),
        trinityColors = T(defaultChatTrinityColors),
        partyNameRoleColors = true,
        codeColors = build_chat_code_colors(),
        window1 = build_chat_window_defaults(true, false),
        window2 = build_chat_window_defaults(true, true),
        suppressionDisabled = true,
        condensedCombatLog = false,
        condenseDamage = true,
        condenseTargets = true,
        sumDamage = true,
        condenseCrits = false,
    };
end

local function normalize_chat_settings(chatSettings)
    local defaults = build_chat_defaults();
    local settingsTable = chatSettings or defaults;

    if (settingsTable.purposeColors == nil) then
        settingsTable.purposeColors = T(defaults.purposeColors);
    end
    if (settingsTable.codeColors == nil) then
        settingsTable.codeColors = build_chat_code_colors();
    end
    if (settingsTable.trinityColors == nil) then
        settingsTable.trinityColors = T(defaultChatTrinityColors);
    else
        for role, color in pairs(defaultChatTrinityColors) do
            if (settingsTable.trinityColors[role] == nil) then
                settingsTable.trinityColors[role] = {
                    color[1], color[2], color[3], color[4],
                };
            end
        end
    end
    if (settingsTable.partyNameRoleColors == nil) then
        settingsTable.partyNameRoleColors = true;
    end
    if (settingsTable.window1 == nil) then
        settingsTable.window1 = build_chat_window_defaults(true, false);
    end
    if (settingsTable.window2 == nil) then
        settingsTable.window2 = build_chat_window_defaults(true, true);
    end
    if (settingsTable.window1.font_scale == nil) then
        settingsTable.window1.font_scale = 1.0;
    end
    if (settingsTable.window2.font_scale == nil) then
        settingsTable.window2.font_scale = 1.0;
    end
    if (settingsTable.window1.maxLines ~= nil) then
        local m = math.floor(tonumber(settingsTable.window1.maxLines) or 0);
        if (m < 100) then m = 100; end
        if (m > 20000) then m = 20000; end
        settingsTable.window1.maxLines = m;
    end
    if (settingsTable.window2.maxLines ~= nil) then
        local m = math.floor(tonumber(settingsTable.window2.maxLines) or 0);
        if (m < 100) then m = 100; end
        if (m > 20000) then m = 20000; end
        settingsTable.window2.maxLines = m;
    end
    if (settingsTable.selectedColorCode == nil) then
        settingsTable.selectedColorCode = '01';
    end
    if (settingsTable.enabled == nil) then
        settingsTable.enabled = true;
    end
    if (settingsTable.persistChatLog == nil) then
        settingsTable.persistChatLog = true;
    end
    if (settingsTable.actionPacket28LegacyHeader == nil) then
        settingsTable.actionPacket28LegacyHeader = false;
    end
    if (settingsTable.forceNativeChatHidden == nil) then
        settingsTable.forceNativeChatHidden = true;
    end
    if (settingsTable.maxEntries == nil) then
        settingsTable.maxEntries = 1000;
    end
    if (settingsTable.inputFontScale == nil) then
        settingsTable.inputFontScale = 1.0;
    end
    if (settingsTable.inputPanelBackgroundEnabled == nil) then
        settingsTable.inputPanelBackgroundEnabled = true;
    end
    if (settingsTable.inputPanelRounding == nil) then
        settingsTable.inputPanelRounding = 0;
    end
    if (settingsTable.inputPanelBorderSize == nil) then
        settingsTable.inputPanelBorderSize = 0;
    end
    if (settingsTable.suppressionDisabled == nil) then
        settingsTable.suppressionDisabled = true;
    end
    if (settingsTable.condensedCombatLog == nil) then
        settingsTable.condensedCombatLog = false;
    end
    if (settingsTable.condenseDamage == nil) then
        settingsTable.condenseDamage = true;
    end
    if (settingsTable.condenseTargets == nil) then
        settingsTable.condenseTargets = true;
    end
    if (settingsTable.sumDamage == nil) then
        settingsTable.sumDamage = true;
    end
    if (settingsTable.condenseCrits == nil) then
        settingsTable.condenseCrits = false;
    end

    for i = 1, #chatPurposeOrder do
        local purpose = chatPurposeOrder[i];
        local defaultColor = defaultChatPurposeColors[purpose];
        if (settingsTable.purposeColors[purpose] == nil) then
            if (defaultColor ~= nil) then
                settingsTable.purposeColors[purpose] = {
                    defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4],
                };
            else
                settingsTable.purposeColors[purpose] = { 1.0, 1.0, 1.0, 1.0 };
            end
        end
        if (settingsTable.window1[purpose] == nil) then
            settingsTable.window1[purpose] = defaults.window1[purpose] == true;
        end
        if (settingsTable.window2[purpose] == nil) then
            settingsTable.window2[purpose] = defaults.window2[purpose] == true;
        end
    end

    for i = 1, #knownChatColorCodes do
        local code = knownChatColorCodes[i].code;
        if (settingsTable.codeColors[code] == nil) then
            settingsTable.codeColors[code] = defaults.codeColors[code];
        end
    end

    return settingsTable;
end

local function normalize_player_stats_settings(pstats)
    if(pstats == nil)then
        return;
    end
    if(type(pstats.barPadding) ~= 'number')then
        pstats.barPadding = 50;
    end
    if(type(pstats.rowGap) ~= 'number')then
        pstats.rowGap = 8;
    end
    if(pstats.expBarDim == nil)then
        pstats.expBarDim = T{ l = 600, g = 14 };
    end
    if(type(pstats.expBarDim.l) ~= 'number')then
        pstats.expBarDim.l = 600;
    end
    if(type(pstats.expBarDim.g) ~= 'number')then
        pstats.expBarDim.g = 14;
    end
end

local function normalize_party_p_list_settings()
    local p = GlamourUI.settings.Party and GlamourUI.settings.Party.pList;
    if (p == nil) then
        return;
    end

    if (p.buff_gui_scale == nil) then
        p.buff_gui_scale = p.gui_scale or 1;
    end
end

local function normalize_all_panel_style(dst)
    if (dst == nil) then
        return;
    end
    local ps = panelStyleLib;
    local list = {
        dst.Party and dst.Party.pList,
        dst.Party and dst.Party.aPanel,
        dst.Inv,
        dst.TargetBar,
        dst.PlayerStats,
        dst.rcPanel,
        dst.cBar,
        dst.Env,
        dst.Compass,
    };
    for i = 1, #list do
        ps.normalize_settings(list[i]);
    end
    if (dst.Chat ~= nil) then
        ps.normalize_settings(dst.Chat.window1);
        ps.normalize_settings(dst.Chat.window2);
    end
    normalize_player_stats_settings(dst.PlayerStats);
end

local function refreshManagers()
    MemoryManager = AshitaCore:GetMemoryManager();
    ResourceManager = AshitaCore:GetResourceManager();
end

local update_menu_state = function()
    local currentMenu = gHelper.getMenu();
    local prevGameMenu = lastGameMenu;
    lastGameMenu = currentMenu;

    if(currentMenu == 'loot')then
        menu = 'loot';
    elseif(currentMenu == '')then
        menu = '';
    end

    if (prevGameMenu ~= currentMenu and currentMenu ~= nil and currentMenu ~= '') then
        menuDebug.name = tostring(currentMenu);
        menuDebug.shownUntilClock = os.clock() + 4.0;
    end

    if (prevGameMenu ~= currentMenu and glam_sync_ui_keybinds ~= nil) then
        glam_sync_ui_keybinds();
    end
end

local WIZARD_SETTINGS_VERSION = 2;

local function migrate_wizard_settings(s)
    if (s == nil) then
        return false;
    end
    local ver = tonumber(s.settings_version) or 1;
    if (ver < WIZARD_SETTINGS_VERSION) then
        s.settings_version = WIZARD_SETTINGS_VERSION;
        s.firstrun_completed = true;
        if (s.packet_injection_enabled == nil) then
            s.packet_injection_enabled = false;
        end
        return true;
    end
    return false;
end

local ensure_loaded = function(playerServerId)
    if(GlamourUI.firstLoad == false or playerServerId == 0)then
        return loaded;
    end

    GlamourUI.firstLoad = false;
    print(chat.header('GlamourUI Loading...'));
    coroutine.sleep(3);
    GlamourUI.settings = settings.load(default_settings);
    if (migrate_wizard_settings(GlamourUI.settings)) then
        settings.save();
    end
    GlamourUI.settings = apply_defaults(GlamourUI.settings, default_settings);
    GlamourUI.settings.Chat = normalize_chat_settings(GlamourUI.settings.Chat);
    normalize_configured_fonts(GlamourUI.settings);
    normalize_party_p_list_settings();
    normalize_all_panel_style(GlamourUI.settings);
    gHelper.loadLayout(GlamourUI.settings.Party.pList.layout);
    local fontPath = ('%s\\config\\addons\\%s\\Fonts\\'):fmt(AshitaCore:GetInstallPath(), addon.name);
    require('font_manager').scan_directory(fontPath);
    if (gResources.update_shift_jis_font_list ~= nil) then
        gResources.update_shift_jis_font_list();
    end
    normalize_configured_fonts(GlamourUI.settings);
    gResources.loadFont(GlamourUI.settings.font);
    gResources.preload_configured_fonts(GlamourUI.settings);
    gParty.Party = gParty.get_party();
    gParty.set_party_leads();
    if (package.loaded['chatPartyNames'] ~= nil) then
        require('chatPartyNames').invalidate_roster_cache();
    end
    coroutine.sleep(1);
    loaded = true;

    if (firstrun_auto_opened ~= true and gFirstRun ~= nil and gFirstRun.should_auto_open ~= nil and gFirstRun.should_auto_open()) then
        firstrun_auto_opened = true;
        gFirstRun.open();
    end

    return loaded;
end

local render_frame = function()
    local fontPushed = gResources.push_font_scale(1);
    gHide.HideParty(GlamourUI.settings.Party.pList.hideDefault);

    local hideChat = false;
    do
        local mm = MemoryManager or AshitaCore:GetMemoryManager();
        local player = mm and mm:GetPlayer() or nil;
        if (player ~= nil and player:GetIsZoning() == 1) then
            hideChat = true;
        end
        if (not hideChat and gHelper ~= nil and gHelper.getMenu ~= nil) then
            local m = tostring(gHelper.getMenu() or '');
            if (m == 'map' or m:lower() == 'fep') then
                hideChat = true;
            end
        end
    end

    if (not hideChat) then
        gUI.render_chat_logs();
    end

    gUI.render_compass();

    if(not gHelper.is_event(0))then
        if (gPacket ~= nil and gPacket.TickTargetMobLevel ~= nil) then
            gPacket.TickTargetMobLevel();
        end
        gUI.render_recast();
        gParty.render_party_list();
        gUI.render_target_bar();
        gParty.render_alliance_panel();
        gParty.render_player_stats();
        gUI.render_invite();
        gConf.render_config();
        if (gFirstRun ~= nil and gFirstRun.render ~= nil) then
            gFirstRun.render();
        end
        if (gPacket ~= nil and gPacket.TickCastBarDismiss ~= nil) then
            gPacket.TickCastBarDismiss();
        end
        gUI.render_cast_bar();
        gUI.render_environment();
        if (gFullscreenMap ~= nil and gFullscreenMap.draw ~= nil) then
            gFullscreenMap.draw();
        end
        gUI.render_f_target();
        if(menu == 'loot')then
            gUI.render_lot();
        end
        gUI.render_skills();
        gInv.render_inv_panel();
    end

    pcall(function()
        if (GlamourUI.debug == true and (tonumber(menuDebug.shownUntilClock) or 0) > os.clock()) then
            local flags = bit.bor(
                ImGuiWindowFlags_NoDecoration,
                ImGuiWindowFlags_AlwaysAutoResize,
                ImGuiWindowFlags_NoSavedSettings,
                ImGuiWindowFlags_NoFocusOnAppearing,
                ImGuiWindowFlags_NoNav
            );
            imgui.SetNextWindowBgAlpha(0.75);
            imgui.SetNextWindowPos({ 20, 20 }, 0);
            if (imgui.Begin('MenuDebug##GlamMenuDbg', true, flags)) then
                imgui.TextColored({ 0.45, 1.0, 0.82, 1.0 }, 'FFXI Menu Opened');
                imgui.Separator();
                imgui.Text(('menu=%s'):format(tostring(menuDebug.name or '')));
            end
            imgui.End();
        end
    end);

    gResources.pop_font(fontPushed);
end

local update_party_after_zone = function()
    local player = MemoryManager:GetPlayer();
    local isZoning = player ~= nil and player:GetIsZoning() == 1;

    if(wasZoning and not isZoning)then
        gParty.Party = gParty.get_party();
        gParty.set_party_leads();
        if (package.loaded['chatPartyNames'] ~= nil) then
            require('chatPartyNames').invalidate_roster_cache();
        end
    end

    wasZoning = isZoning;
end

local update_pet_debuff_timer = function(pet)
    if(gRecast.PetDeg.time > 0 and pet ~= nil)then
        if((gRecast.PetDeg.time <= gRecast.PetDeg.endtime) and gRecast.PetDeg.endtime > 0)then
            gRecast.calcPetDeg(pet.Name);
        else
            gRecast.PetDeg.time = 0;
            gRecast.PetDeg.endtime = 0;
        end
    elseif(pet == nil)then
        gRecast.PetDeg.max = 0;
        gRecast.PetDeg.time = 0;
        gRecast.PetDeg.endtime = 0;
    end
end

local function glam_game_menu_should_pause_ui()
    if (gHelper == nil or gHelper.getMenu == nil) then
        return false;
    end
    local m = tostring(gHelper.getMenu() or '');
    if (m == '') then
        return false;
    end
    if (m:lower() == 'playermo') then
        return false;
    end
    return true;
end

local function glam_should_block_key_vk(vk)
    vk = tonumber(vk) or 0;
    if (vk == 0) then
        return false;
    end

    if (glam_game_menu_should_pause_ui()) then
        return false;
    end

    local plist = GlamourUI.settings and GlamourUI.settings.Party and GlamourUI.settings.Party.pList;
    local plusActive = (plist ~= nil and plist.hideNativeStatusIcons == true);

    if (vk == 0x6B) then -- VK_ADD
        return plusActive;
    end

    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
    if (nav ~= nil and nav.active == true) then
        return (vk == 0x25 or vk == 0x26 or vk == 0x27 or vk == 0x28 or vk == 0x0D or vk == 0x1B);
    end

    if (GlamourUI.chatExpandOpen == true) then
        return (vk == 0x1B); -- VK_ESCAPE
    end

    if (GlamourUI.chatLogFocus == true) then
        return (vk == 0x0D or vk == 0x1B); -- VK_RETURN / VK_ESCAPE
    end

    if (gFullscreenMap ~= nil and gFullscreenMap.is_open ~= nil and gFullscreenMap.is_open()) then
        if (gFullscreenMap.tick_movement ~= nil) then
            gFullscreenMap.tick_movement();
        end
        if (gFullscreenMap.is_player_moving ~= nil and gFullscreenMap.is_player_moving()) then
            return false;
        end
        if (vk == 0x1B) then -- VK_ESCAPE
            if (gFullscreenMap.close ~= nil) then
                gFullscreenMap.close();
            end
            return true;
        end
    end

    return false;
end

ashita.events.register('key', 'glam_key_block_cb', function(e)
    if (e == nil or e.blocked == true) then
        return;
    end
    if (glam_should_block_key_vk(e.wparam)) then
        e.blocked = true;
    end
end);

local function normalize_panel_font(panel, defaultFont, requireShiftJis)
    if (panel == nil) then
        return;
    end
    if (panel.font == nil) then
        panel.font = '';
    end
    if (panel.font == '') then
        return;
    end
    local fm = require('font_manager');
    if (requireShiftJis == true) then
        panel.font = fm.pick_shift_jis_fallback(panel.font, defaultFont);
    end
end

function normalize_configured_fonts(settings)
    if (settings == nil) then
        return;
    end

    local defaultFont = settings.font or '';
    if (settings.Party ~= nil) then
        normalize_panel_font(settings.Party.pList, defaultFont, false);
        normalize_panel_font(settings.Party.aPanel, defaultFont, false);
    end
    normalize_panel_font(settings.TargetBar, defaultFont, false);
    normalize_panel_font(settings.PlayerStats, defaultFont, false);
    normalize_panel_font(settings.Inv, defaultFont, false);
    normalize_panel_font(settings.rcPanel, defaultFont, false);
    normalize_panel_font(settings.cBar, defaultFont, false);
    normalize_panel_font(settings.Compass, defaultFont, false);
    normalize_panel_font(settings.Env, defaultFont, false);

    local chat = settings.Chat;
    if (chat ~= nil) then
        normalize_panel_font(chat, defaultFont, true);
        if (chat.window1 ~= nil) then
            normalize_panel_font(chat.window1, defaultFont, true);
        end
        if (chat.window2 ~= nil) then
            normalize_panel_font(chat.window2, defaultFont, true);
        end
    end
end

local default_settings = T{
    Party = T{
        pList = T{
            hp1Color = {1.0, 1.0, 1.0, 1.0},
            hp2Color = {1.0, 1.0, 0.0, 1.0},
            hp3Color = {1.0, 0.0, 0.0, 1.0},
            enabled = true,
            hideDefault = true,
            font_scale = 1,
            gui_scale = 1,
            buff_scale = 1,
            buffTheme = 'Default',
            layout = 'Default',
            FillDown = false,
            hideNativeStatusIcons = false,
            highlightSelectedBuff = true,
            theme = 'Default',
            themed = true,
            x = 12,
            y = 150
        },
        aPanel = T{
            enabled = true,
            font_scale = 1,
            gui_scale = 1,
            theme = 'Default',
            themed = true,
            x1 = 12,
            y1 = 700,
            hpBarDim = T{
                l = 200,
                g = 16
            }
        }
    },
    Inv = T{
        enabled = true,
        theme = 'Default',
        font_scale = 1,
    },
    TargetBar = T{
        enabled = true,
        theme = 'Default',
        themed = true,
        gui_scale = 1,
        font_scale = 1,
        x = 1000,
        y = 150,
        hpBarDim = T{
            l = 600,
            g = 16
        },
        mobdbIcons = true,
        mobdbIconScale = 1.0,
        mobdbTextScale = 0.4,
    },
    PlayerStats = T{
        enabled = true,
        theme = 'Default',
        themed = true,
        gui_scale = 1,
        font_scale = 1,
        x = 600,
        y = 800,
        BarDim = T{
            l = 200,
            g = 16
        },
        barPadding = 50,
        expBarDim = T{
            l = 600,
            g = 14
        },
        rowGap = 8,
    },
    rcPanel = T{
        enabled = true,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        font_scale = 1
    },
    cBar = {
        enabled = true,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        font_scale = 1,
        BarDim = {
            l = 400,
            g = 12
        },
        x = 1500,
        y = 850
    },
    Env = {
        font_scale = 1,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        minimap_enabled = true,
        minimap_width = 180,
        minimap_height = 180,
        minimap_zoom_step = 0.1,
        minimap_default_zoom = 1.0,
        fullscreen_map_default_zoom = 1.0,
        minimap_opacity = 1.0,
        minimap_transit_opacity = 0.45,
        minimap_render_mode = 'normal',
        minimap_zone_zoom = {},
        fullscreen_map_zone_zoom = {},
        minimap_cache_max = 64,
        minimap_overlay_opacity = 1.0,
        minimap_show_npcs = true,
        minimap_show_mobs = true,
        minimap_show_party = true,
        minimap_show_alliance = true,
        minimap_show_other_players = true,
        minimap_show_target = true,
        minimap_label_hover_only = false,
        minimap_label_mobs = false,
        minimap_label_players = false,
        minimap_label_npcs = false,
        minimap_label_target = true,
        minimap_label_hostile = true,
        minimap_label_font_scale = 0.85,
        minimap_label_color_mobs = { 1.0, 0.55, 0.50, 1.0 },
        minimap_label_color_players = { 0.65, 0.82, 1.0, 1.0 },
        minimap_label_color_npcs = { 0.98, 0.94, 0.55, 1.0 },
        minimap_label_color_target = { 1.0, 0.92, 0.2, 1.0 },
        minimap_label_color_hostile = { 1.0, 0.45, 0.35, 1.0 },
        minimap_scan_distance = 50,
        minimap_icon_target = 8,
        minimap_color_target = { 1.0, 0.92, 0.2, 1.0 },
        minimap_scan_interval = 2,
        minimap_icon_npc = 4,
        minimap_icon_mob = 4,
        minimap_icon_party = 6,
        minimap_icon_alliance = 5,
        minimap_icon_player = 5,
        minimap_color_npc = { 0.95, 0.90, 0.25, 0.95 },
        minimap_color_mob = { 0.95, 0.35, 0.30, 0.95 },
        minimap_color_party = { 0.20, 0.85, 0.35, 0.95 },
        minimap_color_alliance = { 0.35, 0.65, 1.00, 0.95 },
        minimap_color_player = { 0.55, 0.75, 1.00, 0.95 },
    },
    Compass = T{
        enabled = true,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        font_scale = 1,
        x = 700,
        y = 15,
        width = 540,
        height = 58,
        fov_deg = 120,
        tick_deg = 5,
        major_tick_deg = 15,
        label_deg = 45,
        show_degrees = false,
        show_heading_value = false,
        geoCardinalGlow = true,
        geoCardinalGlowOpacity = 1.0,
        geoCardinalColors = T{
            Water = { 0.0, 0.42307734489440918, 1.0, 1.0 },
            Fire = { 1.0, 0.23529410362243652, 0.0, 1.0 },
            Dark = { 0.0, 0.0, 0.0, 1.0 },
            Light = { 1.0, 1.0, 1.0, 1.0 },
            Ice = { 0.55, 0.90, 1.0, 1.0 },
            Wind = { 0.0, 0.93013101816177368, 0.18602624535560608, 1.0 },
            Earth = { 0.98689955472946167, 0.64557880163192749, 0.13359779119491577, 1.0 },
            Lightning = { 0.78388655185699463, 0.095230832695960999, 0.99126636981964111, 1.0 },
        },
        panelBackground = nil,
        ribbonColor = nil,
        tickColor = nil,
        labelColor = nil,
        centerColor = nil,
    },
    Chat = build_chat_defaults(),
    font = 'SpicyTaste.ttf',
    settings_version = 2,
    firstrun_completed = false,
    packet_injection_enabled = false,
}

GlamourUI = T{
    firstLoad = true,
    settings = settings.load(default_settings),
    font = nil,
    starGlyphMerged = false,
    backslashGlyphMerged = false,
    debug = false,
    chatLogFocus = false,
    chatExpandOpen = false,
    chatExpandTab = 1,
    expandScrollOp = nil,
    expandLastViewportH = 400,
    expandLastLineH = 16,
    chatExpandSnapBottomPending = false,
    expandArrowRepeat = nil,
    PartyList = {
        Drag = true,
        x = 0,
        y = 0,
        BuffSelection = {
            locked = false,
            memberIndex = nil,
            statusId = nil,
        }
    }
}

GlamourUI.PartyList.BuffNav = {
    active = false,
    index = 1,
    list = T{},
};

if (migrate_wizard_settings(GlamourUI.settings)) then
    settings.save();
end
GlamourUI.settings = apply_defaults(GlamourUI.settings, default_settings);
GlamourUI.settings.Chat = normalize_chat_settings(GlamourUI.settings.Chat);
normalize_party_p_list_settings();
normalize_all_panel_style(GlamourUI.settings);
GlamourUI.chatPurposeOrder = chatPurposeOrder;
GlamourUI.chatCombatPurposeOrder = chatCombatPurposeOrder;
GlamourUI.knownChatColorCodes = knownChatColorCodes;

MemoryManager = nil;
ResourceManager = nil;

local loaded = false;
local firstrun_auto_opened = false;

settings.register('settings', 'settings_update', function(s)
    if (s ~= nil) then
        GlamourUI.settings = s;
        migrate_wizard_settings(GlamourUI.settings);
        GlamourUI.settings = apply_defaults(GlamourUI.settings, default_settings);
        GlamourUI.settings.Chat = normalize_chat_settings(GlamourUI.settings.Chat);
        if (gChat.rebuild_window_entry_lists ~= nil) then
            gChat.rebuild_window_entry_lists();
        end
        normalize_party_p_list_settings();
        normalize_all_panel_style(GlamourUI.settings);
    end
    if (GlamourUI.settings ~= nil and GlamourUI.settings.Party ~= nil and GlamourUI.settings.Party.pList ~= nil) then
        if (GlamourUI.settings.Party.pList.hideNativeStatusIcons == true) then
            nativeStatusBlock.apply();
            glam_sync_ui_keybinds();
        else
            nativeStatusBlock.remove();
            if (buff_cancel_mode_off ~= nil) then
                buff_cancel_mode_off();
            else
                if (GlamourUI.PartyList ~= nil and GlamourUI.PartyList.BuffNav ~= nil) then
                    GlamourUI.PartyList.BuffNav.active = false;
                end
            end
            if (unbind_buff_cancel_keys ~= nil) then
                unbind_buff_cancel_keys();
            end
        end
    end
    settings.save();
end)

ashita.events.register('load', 'load_cb', function()
    refreshManagers();
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts'):fmt(AshitaCore:GetInstallPath(), addon.name)))then
        ashita.fs.create_directory(('%s\\config\\addons\\%s\\Layouts'):fmt(AshitaCore:GetInstallPath(), addon.name));
        print(chat.header('Creating Layout Directory'));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath(), addon.name)))then
        ashita.fs.create_directory(('%s\\config\\addons\\%s\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath(), addon.name));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts\\Default\\layout.lua'):fmt(AshitaCore:GetInstallPath(), addon.name))) then
        gHelper.createLayout('Default');
        print(chat.header('Creating Default Layout'));
    end
    gPartyBuffs = gResources.ReadPartyBuffsFromMemory();
    gHide.Load();
    gChat.on_load();
    customChat.init(gChat.append_custom_entry);
    customChat.register();
    if (GlamourUI.settings ~= nil and GlamourUI.settings.Party ~= nil and GlamourUI.settings.Party.pList ~= nil) then
        if (GlamourUI.settings.Party.pList.hideNativeStatusIcons == true) then
            nativeStatusBlock.apply();
            glam_sync_ui_keybinds();
        end
    end
    GlamourUI.PartyList.x = GlamourUI.settings.Party.pList.x;
    GlamourUI.PartyList.y = GlamourUI.settings.Party.pList.y;
    gMinimap.init();
end)

ashita.events.register('d3d_present', 'present_cb', function()
    refreshManagers();
    update_party_after_zone();
    if (gMinimap ~= nil and gMinimap.tick ~= nil) then
        gMinimap.tick();
    end
    if (gFullscreenMap ~= nil and gFullscreenMap.is_open ~= nil and gFullscreenMap.is_open()
        and gFullscreenMap.tick_movement ~= nil) then
        gFullscreenMap.tick_movement();
    end
    gChat.on_present();
    do
        local plist = GlamourUI.settings and GlamourUI.settings.Party and GlamourUI.settings.Party.pList;
        local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
        if (plist ~= nil and plist.hideNativeStatusIcons == true and nav ~= nil and nav.active == true) then
            if (player_has_any_buff ~= nil and player_has_any_buff() ~= true and buff_cancel_mode_off ~= nil) then
                buff_cancel_mode_off();
            end
        end
    end
    local playerServerId = MemoryManager:GetParty():GetMemberServerId(0);
    local player = GetPlayerEntity();
    local pet = nil;
    if(player ~= nil)then
        pet = GetEntity(player.PetTargetIndex);
    end

    update_menu_state();

    if(not ensure_loaded(playerServerId))then
        return;
    end

    if(playerServerId == 0 or player == nil)then
        update_pet_debuff_timer(pet);
        return;
    end

    render_frame();
    update_pet_debuff_timer(pet);

    pcall(function()
        if (GlamourUI.debug == true) then
            local fp = nil;
            if (loaded == true) then
                fp = gResources.push_font_scale(1);
            end
            pcall(render_packet_debug_window);
            if (fp ~= nil) then
                gResources.pop_font(fp);
            end
        end
    end);
end)

ashita.events.register('unload', 'unload_cb', function()
    pcall(function()
        require('maptexture').clear_all();
    end);
    settings.save();
    if (customChat.on_unload ~= nil) then
        customChat.on_unload();
    end
    nativeStatusBlock.remove();
    if (buff_cancel_mode_off ~= nil) then
        buff_cancel_mode_off();
    end
    unbind_buff_cancel_keys();
end)

unbind_buff_cancel_keys = function()
    kb_unbind('ADD');
    kb_unbind('LEFT');
    kb_unbind('RIGHT');
    kb_unbind('UP');
    kb_unbind('DOWN');
    kb_unbind('ENTER');
    kb_unbind('NUMPADENTER');
    kb_unbind('ESCAPE');
end

chatGamepad.register(glam_game_menu_should_pause_ui);

glam_sync_ui_keybinds = function()
    kb_unbind('LEFT');
    kb_unbind('RIGHT');
    kb_unbind('UP');
    kb_unbind('DOWN');
    kb_unbind('ENTER');
    kb_unbind('NUMPADENTER');
    kb_unbind('ESCAPE');

    if (glam_game_menu_should_pause_ui()) then
        kb_unbind('ADD');
        return;
    end

    local plist = GlamourUI.settings and GlamourUI.settings.Party and GlamourUI.settings.Party.pList;
    if (plist == nil or plist.hideNativeStatusIcons ~= true) then
        kb_unbind('ADD');
        return;
    end

    kb_bind('ADD', '/glam plus');

    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
    if (nav ~= nil and nav.active == true) then
        kb_bind('LEFT', '/glam buffPrev');
        kb_bind('RIGHT', '/glam buffNext');
        kb_bind('ENTER', '/glam buffCancelBuff');
        kb_bind('NUMPADENTER', '/glam buffCancelBuff');
        kb_bind('ESCAPE', '/glam uiReset');
    elseif (GlamourUI.chatExpandOpen == true) then
        kb_bind('ESCAPE', '/glam uiReset');
    elseif (GlamourUI.chatLogFocus == true) then
        kb_bind('ENTER', '/glam chatExpandOpen');
        kb_bind('NUMPADENTER', '/glam chatExpandOpen');
        kb_bind('ESCAPE', '/glam uiReset');
    end
end

player_has_any_buff = function()
    local mm = MemoryManager or AshitaCore:GetMemoryManager();
    if (mm == nil) then
        return false;
    end
    local player = mm:GetPlayer();
    if (player == nil) then
        return false;
    end
    local icons = player:GetBuffs();
    if (icons == nil) then
        return false;
    end
    for j = 0, 31 do
        local b = icons[j + 1];
        if (b ~= nil and b ~= 255 and b > 0) then
            return true;
        end
    end
    return false;
end

buff_cancel_mode_off = function()
    if (GlamourUI.PartyList ~= nil and GlamourUI.PartyList.BuffNav ~= nil) then
        GlamourUI.PartyList.BuffNav.active = false;
        GlamourUI.PartyList.BuffNav.index = 1;
        GlamourUI.PartyList.BuffNav.list = T{};
    end
    if (GlamourUI.PartyList ~= nil and GlamourUI.PartyList.BuffSelection ~= nil) then
        GlamourUI.PartyList.BuffSelection.locked = false;
        GlamourUI.PartyList.BuffSelection.memberIndex = nil;
        GlamourUI.PartyList.BuffSelection.statusId = nil;
    end
    if (glam_sync_ui_keybinds ~= nil) then
        glam_sync_ui_keybinds();
    end
end

ashita.events.register('text_in', 'text_in_cb', function(e)
    gChat.handle_text_in(e);
end)

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    refreshManagers();
    packet_debug_capture_incoming(e);
    if (e.id == 0x076) then
        gPartyBuffs = gResources.ReadPartyBuffsFromPacket(e);
    end

    if (e.id == 0x29) then
        local mob_check = require('mob_check');
        local block, _ = mob_check.try_handle_packet_in(e);
        if (block) then
            e.blocked = true;
        end
    end

    gPacket.HandleIncoming(e);
    gParty.Party = gParty.get_party();
    gParty.set_party_leads();
    if (package.loaded['chatPartyNames'] ~= nil) then
        require('chatPartyNames').invalidate_roster_cache();
    end
    gPartyBuffs = gResources.ReadPartyBuffsFromMemory();
end)

ashita.events.register('packet_out', 'packet_out_cb', function(e)
    refreshManagers();
    gPacket.HandleOutgoing(e);
    gParty.Party = gParty.get_party();
    gParty.set_party_leads();
    if (package.loaded['chatPartyNames'] ~= nil) then
        require('chatPartyNames').invalidate_roster_cache();
    end
    gPartyBuffs = gResources.ReadPartyBuffsFromMemory();
end)

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args > 0 and args[1]:any('/gmap')) then
        local gmapCmd = require('gmap');
        if (gmapCmd.handle_command(args) == true) then
            e.blocked = true;
            return;
        end
    end

    if((args[1] == '/join' or args[1] == '/decline'))then
        gPacket.InviteActive = false;
        return;
    end

    if(#args > 0)then
        if(args[1]:any('/glam') and (#args ==1 or args[2]:any('help'))) then
            e.blocked = true;
            print(chat.header('Glamour UI Commands:'));
            print(chat.message('/glam - Show this help text'))
            print(chat.message('/glam config - Opens the Configuration window'));
            print(chat.message('/glam newlayout layoutname - Creates a new layout with name: layoutname'));
            print(chat.message('/glam lot slot# - Lots on the treasure pool item in slot: slot#'));
            print(chat.message('/glam pass slot# - Passes on the treasure pool item in slot: slot#'));
            print(chat.message('/glam debug - Toggle incoming packet debug (UI + append to Logs\\packet_in_DATE.log)'));
            print(chat.message('/glam firstrun - Open or close the first-run setup wizard'));
            print(chat.error('The slot number is reflected in the GlamourUI Treasure Pool.  This number may not reflect the positioning in the default Treasure Pool Window'));
        elseif(args[1]:any('/glam'))then
            e.blocked = true;
            if(#args > 1) then
                if (args[2] == 'config') then
                    gConf.is_open = not gConf.is_open;
                end
                if (args[2]:any('firstrun')) then
                    if (gFirstRun ~= nil and gFirstRun.toggle ~= nil) then
                        gFirstRun.toggle();
                    end
                end
                if (args[2] == 'newlayout') then
                    if(args[3] ~= nil)then
                        gHelper.createLayout(args[3]);
                    end
                end
                if(args[2] == 'debug' )then
                    GlamourUI.debug = not GlamourUI.debug;
                    if (GlamourUI.debug == true) then
                        local logPath;
                        pcall(function()
                            local dir = ensure_packet_debug_log_dir();
                            logPath = ('%s\\packet_in_%s.log'):fmt(dir, os.date('%Y-%m-%d'));
                            local f = io.open(logPath, 'a+');
                            if (f ~= nil) then
                                f:write(('*** packet_in disk log session START %s ***\n'):fmt(os.date('!%Y-%m-%dT%H:%M:%SZ')));
                                f:close();
                            end
                        end);
                        print(chat.header(('GlamourUI: packet debug ON — also appending to %s'):fmt(logPath or '(config\\addons\\GlamourUI\\Logs\\packet_in_DATE.log)')));
                    else
                        pcall(function()
                            local dir = ensure_packet_debug_log_dir();
                            local path = ('%s\\packet_in_%s.log'):fmt(dir, os.date('%Y-%m-%d'));
                            local f = io.open(path, 'a+');
                            if (f ~= nil) then
                                f:write(('*** packet_in disk log session END %s ***\n'):fmt(os.date('!%Y-%m-%dT%H:%M:%SZ')));
                                f:close();
                            end
                        end);
                        print(chat.header('GlamourUI: packet debug OFF'));
                    end
                end
                if(args[2] == 'plus')then
                    if (GlamourUI.chatExpandOpen == true) then
                        local t = (tonumber(GlamourUI.chatExpandTab) or 1) + 1;
                        if (t > 8) then
                            t = 1;
                        end
                        GlamourUI.chatExpandTab = t;
                        GlamourUI.chatExpandSnapBottomPending = true;
                    else
                        local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                        if (nav ~= nil and nav.active == true) then
                            if (buff_cancel_mode_off ~= nil) then
                                buff_cancel_mode_off();
                            end
                        elseif (GlamourUI.chatLogFocus == true) then
                            if (nav ~= nil) then
                                nav.active = true;
                                nav.index = 1;
                                if (glam_sync_ui_keybinds ~= nil) then
                                    glam_sync_ui_keybinds();
                                end
                            end
                        else
                            GlamourUI.chatLogFocus = true;
                            if (glam_sync_ui_keybinds ~= nil) then
                                glam_sync_ui_keybinds();
                            end
                        end
                    end
                end
                if(args[2] == 'chatExpandOpen')then
                    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                    if (nav == nil or nav.active ~= true) then
                        if (GlamourUI.chatLogFocus == true) then
                            GlamourUI.chatExpandOpen = true;
                            GlamourUI.chatExpandSnapBottomPending = true;
                            GlamourUI.expandArrowRepeat = nil;
                            if (glam_sync_ui_keybinds ~= nil) then
                                glam_sync_ui_keybinds();
                            end
                        end
                    end
                end
                if(args[2] == 'uiReset')then
                    GlamourUI.chatExpandOpen = false;
                    GlamourUI.chatLogFocus = false;
                    GlamourUI.chatExpandTab = 1;
                    GlamourUI.expandScrollOp = nil;
                    GlamourUI.chatExpandSnapBottomPending = false;
                    GlamourUI.expandArrowRepeat = nil;
                    GlamourUI.gamepadDpadDown = nil;
                    if (buff_cancel_mode_off ~= nil) then
                        buff_cancel_mode_off();
                    elseif (glam_sync_ui_keybinds ~= nil) then
                        glam_sync_ui_keybinds();
                    end
                end
                if(args[2] == 'buffCancel')then
                    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                    if (nav ~= nil) then
                        nav.active = not nav.active;
                        nav.index = 1;
                        if (nav.active) then
                            if (glam_sync_ui_keybinds ~= nil) then
                                glam_sync_ui_keybinds();
                            end
                        else
                            if (buff_cancel_mode_off ~= nil) then
                                buff_cancel_mode_off();
                            end
                        end
                    end
                end
                if(args[2] == 'buffCancelOff')then
                    if (buff_cancel_mode_off ~= nil) then
                        buff_cancel_mode_off();
                    end
                end
                if(args[2] == 'buffPrev')then
                    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                    if (nav ~= nil and nav.active == true) then
                        local list = nav.list or T{};
                        local count = #list;
                        if (count > 0) then
                            local idx = nav.index or 1;
                            idx = idx - 1;
                            if (idx < 1) then idx = count; end
                            nav.index = idx;
                        end
                    end
                end
                if(args[2] == 'buffNext')then
                    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                    if (nav ~= nil and nav.active == true) then
                        local list = nav.list or T{};
                        local count = #list;
                        if (count > 0) then
                            local idx = nav.index or 1;
                            idx = idx + 1;
                            if (idx > count) then idx = 1; end
                            nav.index = idx;
                        end
                    end
                end
                if(args[2] == 'buffCancelBuff')then
                    local nav = GlamourUI.PartyList and GlamourUI.PartyList.BuffNav;
                    if (nav ~= nil and nav.active == true) then
                        local list = nav.list or T{};
                        local count = #list;
                        if (count > 0) then
                            local idx = math.max(1, math.min(nav.index or 1, count));
                            local statusId = list[idx];
                            if (statusId ~= nil) then
                                local hi = bit.rshift(statusId, 8);
                                local lo = bit.band(statusId, 0xff);
                                AshitaCore:GetPacketManager():AddOutgoingPacket(0xf1, { 0x00, 0x00, 0x00, 0x00, lo, hi, 0x00, 0x00 });
                            end
                        end
                    end
                end
                if (args[2] == 'chatmode') then
                    if (gChat.debug_dump_native_chat_mode ~= nil) then
                        for _, line in ipairs(gChat.debug_dump_native_chat_mode()) do
                            print(chat.header('GlamourUI'):append(chat.message(line)));
                        end
                    end
                end
                if(args[2] == 'chatdebug')then
                    if (args[3] ~= nil and args[3]:any('on')) then
                        gChat.set_debug_logging(true);
                    elseif (args[3] ~= nil and args[3]:any('off')) then
                        gChat.set_debug_logging(false);
                    elseif (args[3] ~= nil and args[3]:any('clear')) then
                        gChat.clear_debug_logs();
                    end
                end
                if(args[2]:any('focus'))then
                    if(args[3]:any('add'))then
                        gTarget.add_focus_target();
                    end
                    if(args[3]:any('clear'))then
                        gTarget.clear_focus_target();
                    end
                end
                if(args[2]:any('skills'))then
                    gParty.ShowSkills = not gParty.ShowSkills;
                end
                if(args[2]:any('pass'))then
                    gInv.TPoolPass(args[3]);
                end
                if(args[2]:any('lot'))then
                    if (gInv.tryLotSlot ~= nil) then
                        gInv.tryLotSlot(args[3]);
                    else
                        gInv.TPoolLot(args[3]);
                    end
                end
            end
        end
    end
end)
