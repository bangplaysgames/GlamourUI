--[[
    Typed world/server packet fields aligned with atom0s/XiPackets (world/server/<opcode>/README.md).
    Reference: https://github.com/atom0s/XiPackets/tree/main/world/server
    Header:    https://github.com/atom0s/XiPackets/blob/main/world/Header.md
]]--

local struct = require('struct');

local M = {};

local function trim_c_string(s)
    if (s == nil or type(s) ~= 'string') then
        return '';
    end
    local z = s:find('%z', 1, true);
    if (z) then
        return s:sub(1, z - 1);
    end
    return (s:gsub('%s+$', ''));
end

--- XiPackets world Header.md — first u16 is id:9 | size:7, second u16 sync.
local function decode_header(data, lines)
    if (data == nil or #data < 4) then
        lines[#lines + 1] = '  (packet too short for 4-byte world header)';
        return nil;
    end
    local idSize = struct.unpack('H', data, 1);
    local sync = struct.unpack('H', data, 3);
    local id = bit.band(idSize, 0x01FF);
    local size_words = bit.rshift(idSize, 9);
    local size_bytes = size_words * 4;
    lines[#lines + 1] = ('  IdSize u16 @0x00: 0x%04X  →  id=%u  size_words=%u  →  nominal_size_bytes=%u'):format(
        idSize, id, size_words, size_bytes);
    lines[#lines + 1] = ('  sync u16 @0x02: 0x%04X (%u)'):format(sync, sync);
    return {
        idSize = idSize,
        id = id,
        size_words = size_words,
        size_bytes = size_bytes,
        sync = sync,
    };
end

--- GP_SERV_CHAT_STD 0x0017 — GP_SERV_COMMAND_CHAT_STD / RecvStdChat
local function decode_0x0017(data, lines, hdr)
    if (#data < 8) then
        lines[#lines + 1] = '  (body too short for Kind/Attr/Data)';
        return;
    end
    local kind = struct.unpack('B', data, 5);
    local attr = struct.unpack('B', data, 6);
    local data_u16 = struct.unpack('H', data, 7);
    lines[#lines + 1] = ('  Kind u8 @0x04: %u (0x%02X)'):format(kind, kind);
    lines[#lines + 1] = ('  Attr u8 @0x05: %u (0x%02X)'):format(attr, attr);
    lines[#lines + 1] = ('  Data u16 @0x06: %u (0x%04X)'):format(data_u16, data_u16);
    if (#data >= 23) then
        local sName = trim_c_string(struct.unpack('c15', data, 9));
        lines[#lines + 1] = ('  sName char[15] @0x08: %q'):format(sName);
    end
    -- Mes @0x17: length from packet size (XiPackets FUNC_enQueAddSizeGet); clamp 150.
    local mes_start_lua = 24;
    if (#data >= mes_start_lua) then
        local mes_len = math.min(150, math.max(0, #data - 23));
        if (mes_len > 0) then
            local mes = struct.unpack(('c%d'):format(mes_len), data, mes_start_lua);
            lines[#lines + 1] = ('  Mes variable @0x17 (len=%u, max 150): %q'):format(mes_len, trim_c_string(mes));
        end
    end
    if (hdr ~= nil) then
        lines[#lines + 1] = '  note: Kind table / Attr flags / GM & DAT sscanf modes — see XiPackets world/server/0x0017/README.md';
    end
end

--- GP_SERV_TALKNUM 0x0036 — GP_SERV_COMMAND_TALKNUM / RecvMessageTalkNum (SevMess / zone strings)
local function decode_0x0036(data, lines)
    if (#data < 16) then
        lines[#lines + 1] = '  (expected >= 0x10 bytes for GP_SERV_TALKNUM)';
        return;
    end
    local uniqueNo = struct.unpack('I', data, 5);
    local actIndex = struct.unpack('H', data, 9);
    local mesNum = struct.unpack('H', data, 11);
    local typ = struct.unpack('B', data, 13);
    lines[#lines + 1] = ('  UniqueNo u32 @0x04: %u (0x%08X)'):format(uniqueNo, uniqueNo);
    lines[#lines + 1] = ('  ActIndex u16 @0x08: %u'):format(actIndex);
    lines[#lines + 1] = ('  MesNum u16 @0x0A: %u  (message=%u  skip_entity_check=%s)'):format(
        mesNum,
        bit.band(mesNum, 0x7FFF),
        tostring(bit.band(mesNum, 0x8000) ~= 0));
    lines[#lines + 1] = ('  Type u8 @0x0C: %u'):format(typ);
end

--- GP_SERV_EVENT 0x0032 — GP_SERV_COMMAND_EVENT / RecvEventCalc (begin NPC / event VM)
local function decode_0x0032(data, lines)
    if (#data < 8) then
        lines[#lines + 1] = '  (body too short after header)';
        return;
    end
    if (#data < 20) then
        lines[#lines + 1] = ('  (short: have %u bytes, XiPackets nominal size 0x14)'):format(#data);
    end
    local uniqueNo = struct.unpack('I', data, 5);
    lines[#lines + 1] = ('  UniqueNo u32 @0x04: %u (0x%08X)  (entity server id)'):format(uniqueNo, uniqueNo);
    if (#data >= 20) then
        local actIndex = struct.unpack('H', data, 9);
        local eventNum = struct.unpack('H', data, 11);
        local eventPara = struct.unpack('H', data, 13);
        local mode = struct.unpack('H', data, 15);
        local eventNum2 = struct.unpack('H', data, 17);
        local eventPara2 = struct.unpack('H', data, 19);
        lines[#lines + 1] = ('  ActIndex u16 @0x08: %u'):format(actIndex);
        lines[#lines + 1] = ('  EventNum u16 @0x0A: %u'):format(eventNum);
        lines[#lines + 1] = ('  EventPara u16 @0x0C: %u'):format(eventPara);
        lines[#lines + 1] = ('  Mode u16 @0x0E: %u'):format(mode);
        lines[#lines + 1] = ('  EventNum2 u16 @0x10: %u'):format(eventNum2);
        lines[#lines + 1] = ('  EventPara2 u16 @0x12: %u'):format(eventPara2);
    end
    lines[#lines + 1] = '  note: EventNum/EventNum2 → event DAT; zone sub-instance — XiPackets world/server/0x0032/README.md';
end

--- GP_SERV_TALKNUMWORK2 0x0027 — GP_SERV_COMMAND_TALKNUMWORK2 / RecvMessageTalkNumWork2
local function decode_0x0027(data, lines)
    if (#data < 0x70) then
        lines[#lines + 1] = ('  (short: have %u bytes, XiPackets size 0x70)'):format(#data);
    end
    if (#data < 16) then
        return;
    end
    local uniqueNo = struct.unpack('I', data, 5);
    local actIndex = struct.unpack('H', data, 9);
    local mesNum = struct.unpack('H', data, 11);
    local typ = struct.unpack('H', data, 13);
    local flags = struct.unpack('B', data, 15);
    lines[#lines + 1] = ('  UniqueNo u32 @0x04: %u (0x%08X)'):format(uniqueNo, uniqueNo);
    lines[#lines + 1] = ('  ActIndex u16 @0x08: %u'):format(actIndex);
    lines[#lines + 1] = ('  MesNum u16 @0x0A: %u  (message=%u  skip_entity_check=%s)'):format(
        mesNum, bit.band(mesNum, 0x7FFF), tostring(bit.band(mesNum, 0x8000) ~= 0));
    lines[#lines + 1] = ('  Type u16 @0x0C: %u'):format(typ);
    lines[#lines + 1] = ('  Flags u8 @0x0E: %u'):format(flags);
    if (#data >= 80) then
        local n1 = {};
        for i = 0, 3 do
            n1[#n1 + 1] = tostring(struct.unpack('I', data, 17 + i * 4));
        end
        lines[#lines + 1] = ('  Num1 u32[4] @0x10: %s'):format(table.concat(n1, ', '));
    end
    if (#data >= 64) then
        lines[#lines + 1] = ('  String1 char[32] @0x20: %q'):format(trim_c_string(struct.unpack('c32', data, 33)));
    end
    if (#data >= 80) then
        lines[#lines + 1] = ('  String2 char[16] @0x40: %q'):format(trim_c_string(struct.unpack('c16', data, 65)));
    end
    if (#data >= 112) then
        local n2 = {};
        for i = 0, 7 do
            n2[#n2 + 1] = tostring(struct.unpack('I', data, 81 + i * 4));
        end
        lines[#lines + 1] = ('  Num2 u32[8] @0x50: %s'):format(table.concat(n2, ', '));
    end
end

--- GP_SERV_SYSTEMMES 0x0053 — GP_SERV_COMMAND_SYSTEMMES / RecvSystemMessage
local function decode_0x0053(data, lines)
    if (#data < 16) then
        lines[#lines + 1] = '  (expected >= 0x10 bytes)';
        return;
    end
    local para = struct.unpack('I', data, 5);
    local para2 = struct.unpack('I', data, 9);
    local number = struct.unpack('H', data, 13);
    lines[#lines + 1] = ('  para u32 @0x04: %u (0x%08X)'):format(para, para);
    lines[#lines + 1] = ('  para2 u32 @0x08: %u (0x%08X)'):format(para2, para2);
    lines[#lines + 1] = ('  Number u16 @0x0C: %u (SystemMess DAT index)'):format(number);
end

--- GP_SERV_FRAGMENTS 0x004D — GP_SERV_COMMAND_FRAGMENTS / RecvFragments (servmes, event VM / NPC fragments)
local function decode_0x004d(data, lines)
    if (#data < 24) then
        lines[#lines + 1] = '  (expected at least fixed prefix to 0x18)';
        return;
    end
    local cmd = struct.unpack('B', data, 5);
    local result = struct.unpack('b', data, 6);
    local value1 = struct.unpack('B', data, 7);
    local value2 = struct.unpack('B', data, 8);
    local timestamp = struct.unpack('i', data, 9);
    local size_total = struct.unpack('i', data, 13);
    local offset = struct.unpack('i', data, 17);
    local data_size = struct.unpack('i', data, 21);
    lines[#lines + 1] = ('  Command u8 @0x04: %u'):format(cmd);
    lines[#lines + 1] = ('  Result i8 @0x05: %d'):format(result);
    lines[#lines + 1] = ('  value1 u8 @0x06: %u (fragment cause / type)'):format(value1);
    lines[#lines + 1] = ('  value2 u8 @0x07: %u (e.g. language id for servmes)'):format(value2);
    lines[#lines + 1] = ('  timestamp i32 @0x08: %d'):format(timestamp);
    lines[#lines + 1] = ('  size_total i32 @0x0C: %d'):format(size_total);
    lines[#lines + 1] = ('  offset i32 @0x10: %d'):format(offset);
    lines[#lines + 1] = ('  data_size i32 @0x14: %d'):format(data_size);
    if (#data > 24) then
        local chunk_len = math.min(#data - 24, math.max(0, data_size));
        if (chunk_len > 0) then
            local chunk = struct.unpack(('c%d'):format(chunk_len), data, 25);
            if (value1 == 1) then
                lines[#lines + 1] = ('  data[%u] @0x18 (text preview): %q'):format(chunk_len, trim_c_string(chunk));
            else
                lines[#lines + 1] = ('  data[%u] @0x18 (binary / ranking chunk); hex preview: %s'):format(
                    chunk_len,
                    (chunk:sub(1, 48):gsub('.', function(c)
                        return ('%02X '):format(string.byte(c));
                    end)));
            end
        end
    end
end

--- GP_SERV_FAQ_GMPARAM 0x00B5 — Help Desk menu response
local function decode_0x00b5(data, lines)
    if (#data < 32) then
        lines[#lines + 1] = '  (expected >= 0x20 bytes)';
        return;
    end
    local rescueCount = struct.unpack('I', data, 5);
    lines[#lines + 1] = ('  RescueCount u32 @0x04: %u'):format(rescueCount);
    for i = 0, 3 do
        lines[#lines + 1] = ('  params[%u] u32 @0x%02X: %u'):format(i + 1, 8 + i * 4, struct.unpack('I', data, 9 + i * 4));
    end
    local id = struct.unpack('H', data, 25);
    local option = struct.unpack('H', data, 27);
    local status = struct.unpack('H', data, 29);
    local rescueTime = struct.unpack('H', data, 31);
    lines[#lines + 1] = ('  Id u16 @0x18: %u (client request id)'):format(id);
    lines[#lines + 1] = ('  Option u16 @0x1A: %u'):format(option);
    lines[#lines + 1] = ('  Status u16 @0x1C: %u'):format(status);
    lines[#lines + 1] = ('  RescueTime u16 @0x1E: %u'):format(rescueTime);
end

--- GP_SERV_SET_GMMSG 0x00B6 — GM reply chunks
local function decode_0x00b6(data, lines)
    if (#data < 12) then
        lines[#lines + 1] = '  (expected header + msgId/seq/pkt)';
        return;
    end
    local msgId = struct.unpack('I', data, 5);
    local seqId = struct.unpack('H', data, 9);
    local pktNum = struct.unpack('H', data, 11);
    lines[#lines + 1] = ('  msgId u32 @0x04: %u (unix ts / message id)'):format(msgId);
    lines[#lines + 1] = ('  seqId u16 @0x08: %u'):format(seqId);
    lines[#lines + 1] = ('  pktNum u16 @0x0A: %u (0 = last fragment)'):format(pktNum);
    if (#data > 12) then
        local mlen = #data - 12;
        local msg = struct.unpack(('c%d'):format(mlen), data, 13);
        lines[#lines + 1] = ('  Msg[%u] @0x0C: %q'):format(mlen, trim_c_string(msg));
    end
end

local PACKET_META = {
    [0x0017] = { name = 'GP_SERV_COMMAND_CHAT_STD', readme = '0x0017', decode = decode_0x0017 },
    [0x0027] = { name = 'GP_SERV_COMMAND_TALKNUMWORK2', readme = '0x0027', decode = decode_0x0027 },
    [0x0032] = { name = 'GP_SERV_COMMAND_EVENT', readme = '0x0032', decode = decode_0x0032 },
    [0x0036] = { name = 'GP_SERV_COMMAND_TALKNUM', readme = '0x0036', decode = decode_0x0036 },
    [0x004D] = { name = 'GP_SERV_COMMAND_FRAGMENTS', readme = '0x004D', decode = decode_0x004d },
    [0x0053] = { name = 'GP_SERV_COMMAND_SYSTEMMES', readme = '0x0053', decode = decode_0x0053 },
    [0x00B5] = { name = 'GP_SERV_COMMAND_FAQ_GMPARAM', readme = '0x00B5', decode = decode_0x00b5 },
    [0x00B6] = { name = 'GP_SERV_COMMAND_SET_GMMSG', readme = '0x00B6', decode = decode_0x00b6 },
};

function M.format_world_server_packet(opcode, data)
    local lines = {};
    local op = tonumber(opcode) or 0;
    lines[#lines + 1] = '--- XiPackets world/server (typed fields; offsets from packet start, Lua struct.unpack positions = offset+1) ---';
    lines[#lines + 1] = '    Source: https://github.com/atom0s/XiPackets/tree/main/world/server';

    local hdr = decode_header(data, lines);
    local meta = PACKET_META[op];
    if (meta ~= nil) then
        lines[#lines + 1] = ('  opcode 0x%03X: %s — see README %s'):format(op, meta.name, meta.readme);
        pcall(function()
            meta.decode(data, lines, hdr);
        end);
    else
        lines[#lines + 1] = ('  opcode 0x%03X: no typed layout in GlamourUI xipackets_decode.lua yet.'):format(op);
        lines[#lines + 1] = ('  Add fields from: https://github.com/atom0s/XiPackets/tree/main/world/server/0x%03X/README.md'):format(op);
    end

    if (hdr ~= nil and bit.band(hdr.id, 0x01FF) ~= bit.band(op, 0x01FF)) then
        lines[#lines + 1] = ('  warn: event id (0x%03X) ~= wire header id (%u) — compare Ashita event vs buffer'):format(op, hdr.id);
    end

    return table.concat(lines, '\n');
end

return M;
