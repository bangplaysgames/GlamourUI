local ffi = require('ffi');
local chat = require('chat');
local settings = require('settings');
local actionPacket28 = require('action_packet28');
local combatParse = require('combatParse');
local enemy_debuff_tracker = require('enemy_debuff_tracker');
local target_mob_action = require('target_mob_action');

ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

ffi.cdef[[
    typedef struct {
        char flag;
        char unknown1;
        short unknown2;
    } wsPacket;
]]

local WSPacket = ffi.new('wsPacket');
WSPacket.flag = 1;
WSPacket.unknown1 = 0;
WSPacket.unknown2 = 0;

local function pack_u32_le(n)
    n = math.floor(tonumber(n) or 0);
    if (n < 0) then
        n = 0;
    end
    n = n % 4294967296;
    return {
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256,
    };
end

local function pack_world_cli_packet_u32(payloadU32)
    local b = pack_u32_le(payloadU32);
    return { 0x00, 0x00, 0x00, 0x00, b[1], b[2], b[3], b[4] };
end


local function send_world_cli_u32(opcode, payloadU32)
    local pm = AshitaCore:GetPacketManager();
    if (pm == nil) then
        return;
    end
    local v = math.floor(tonumber(payloadU32) or 0) % 4294967296;
    if (pm.QueuePacket ~= nil) then
        pm:QueuePacket(opcode, 8, 0, 0, 0, function(ptr)
            local p = ffi.cast('unsigned char*', ptr);
            ffi.cast('unsigned int*', p + 4)[0] = v;
        end);
        return;
    end
    pm:AddOutgoingPacket(opcode, pack_world_cli_packet_u32(v));
end

local function send_tracking_cli_u32(opcode, payloadU32)
    local pm = AshitaCore:GetPacketManager();
    if (pm == nil) then
        return;
    end
    local v = math.floor(tonumber(payloadU32) or 0) % 4294967296;
    pm:AddOutgoingPacket(opcode, pack_world_cli_packet_u32(v));
end

local MAX_RATE_SAMPLES = 2048;

local function trim_exp_track()
    while (#gParty.EXPTable > MAX_RATE_SAMPLES) do
        local v = table.remove(gParty.EXPTable, 1);
        table.remove(gParty.EXPTimeTable, 1);
        if (v ~= nil) then
            gParty.EXPSum = gParty.EXPSum - v;
        end
    end
end

local function trim_cp_track()
    while (#gParty.CPTable > MAX_RATE_SAMPLES) do
        local v = table.remove(gParty.CPTable, 1);
        table.remove(gParty.CPTimeTable, 1);
        if (v ~= nil) then
            gParty.CPSum = gParty.CPSum - v;
        end
    end
end

local function trim_exemp_track()
    while (#gParty.ExemPTable > MAX_RATE_SAMPLES) do
        local v = table.remove(gParty.ExemPTable, 1);
        table.remove(gParty.ExemPTimeTable, 1);
        if (v ~= nil) then
            gParty.ExemPSum = gParty.ExemPSum - v;
        end
    end
end

local function fmt_time(t)
    local time = t / 60;
    local h = math.floor(time / (60 * 60));
    local m = math.floor(time / 60 - h * 60);
    local s = math.floor(time - (m + h * 60) * 60);
    if(h > 0) then
        return ('%02i:%02i:%02i'):fmt(h, m, s);
    elseif(m > 0) then
        return ('%02i:%02i'):fmt(m, s);
    else
        return('%02i'):fmt(s);
    end
end

local calcEXPperHour = function()
    if(gParty.EXPReset == true)then
        gParty.EXPperHour = 0;
        gParty.EXPSum = 0;
        gParty.EXPTimeDelta = 0;
        for k,_ in pairs(gParty.EXPTable)do
            table.remove(gParty.EXPTable, k);
        end
        for k,_ in pairs(gParty.EXPTimeTable)do
            table.remove(gParty.EXPTimeTable, k);
        end
        gParty.EXPTimeTable = nil;
        gParty.EXPTimeTable = {}
        gParty.EXPTable = nil;
        gParty.EXPTable = {}
        gParty.EXPReset = false;
        return;
    end
    if(gParty.EXPTimeTable[1] ~= nil)then
        gParty.EXPTimeDelta = (os.time() - gParty.EXPTimeTable[1]) / 3600;
    end
    gParty.EXPperHour = math.floor((gParty.EXPSum / gParty.EXPTimeDelta) * 100) / 100;
    if(gParty.EXPSum == 0)then
        gParty.EXPperHour = 0;
    end
end

local calcCPperHour = function(p)
    if(gParty.EXPReset == true)then
        gParty.CPperHour = 0;
        gParty.CPSum = 0;
        gParty.CPTimeDelta = 0;
        for k,_ in pairs(gParty.CPTable)do
            table.remove(gParty.CPTable, k);
        end
        for k,_ in pairs(gParty.CPTimeTable)do
            table.remove(gParty.CPTimeTable, k);
        end
        gParty.CPTimeTable = nil;
        gParty.CPTimeTable = {}
        gParty.CPTable = nil;
        gParty.CPTable = {}
        gParty.EXPReset = false;
    end
    if(gParty.CPTimeTable[1] ~= nil)then
        gParty.CPTimeDelta = (os.time() - gParty.CPTimeTable[1]) / 3600;
    end
    gParty.CPperHour = math.floor((gParty.CPSum / gParty.CPTimeDelta) * 100) / 100;
    if(gParty.CPSum == 0)then
        gParty.CPperHour = 0;
    end
end

local calcExemPperHour = function(p)
    if(gParty.EXPReset == true)then
        gParty.ExemPperHour = 0;
        gParty.ExemPSum = 0;
        gParty.ExemPTimeDelta = 0;
        for k,_ in pairs(gParty.ExemPTable)do
            table.remove(gParty.ExemPTable, k);
        end
        for k,_ in pairs(gParty.ExemPTimeTable)do
            table.remove(gParty.ExemPTimeTable, k);
        end
        gParty.ExemPTimeTable = nil;
        gParty.ExemPTimeTable = {}
        gParty.ExemPTable = nil;
        gParty.ExemPTable = {}
        gParty.EXPReset = false;
    end
    if(gParty.ExemPTimeTable[1] ~= nil)then
        gParty.ExemPTimeDelta = (os.time() - gParty.ExemPTimeTable[1]) / 3600;
    end
    gParty.ExemPperHour = math.floor((gParty.ExemPSum / gParty.ExemPTimeDelta) * 100) / 100;
    if(gParty.ExemPSum == 0)then
        gParty.ExemPperHour = 0;
    end
end

local setEXPmode = function()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if(player:GetIsExperiencePointsLocked() == true)then
        gParty.EXPMode = 'LP';
    else
        gParty.EXPMode = 'EXP';
    end
end

local packet = {}

packet.timer = 0;

packet.IncActionType = 0;
packet.IncActionMessage = {}

packet.Player = 0;
packet.action = {}
packet.action.Casting = false;
packet.action.Packet = {}
packet.action.Target = '';
packet.action.Type = '';
packet.action.Resource = {}
packet.action.Resource.Name = 'Awesome Spell';
packet.action.castBarSpellName = '';
packet.castBarInterruptHideDelaySec = 1.0;
packet.action.castBarDismissAt = nil;

packet._recentIncomingSync = {};
packet._recentIncomingSyncOrder = {};
packet._recentIncomingSyncMax = 512;
packet._recentIncomingSyncMaxAgeSec = 2.0;

local function incoming_packet_dedupe_key(e)
    local d = e and e.data;
    if (d == nil or type(d) ~= 'string' or #d < 4) then
        return nil;
    end
    return d;
end

local function should_drop_duplicate_incoming_packet(e)
    local key = incoming_packet_dedupe_key(e);
    if (key == nil) then
        return false;
    end
    local now = os.clock();
    local last = packet._recentIncomingSync[key];
    if (last ~= nil and (now - last) <= (tonumber(packet._recentIncomingSyncMaxAgeSec) or 2.0)) then
        return true;
    end
    packet._recentIncomingSync[key] = now;
    packet._recentIncomingSyncOrder[#packet._recentIncomingSyncOrder + 1] = { key = key, t = now };
    local maxN = tonumber(packet._recentIncomingSyncMax) or 512;
    local maxAge = tonumber(packet._recentIncomingSyncMaxAgeSec) or 2.0;
    while (#packet._recentIncomingSyncOrder > maxN) do
        local old = table.remove(packet._recentIncomingSyncOrder, 1);
        if (old ~= nil and old.key ~= nil and packet._recentIncomingSync[old.key] == old.t) then
            packet._recentIncomingSync[old.key] = nil;
        end
    end
    while (#packet._recentIncomingSyncOrder > 0) do
        local head = packet._recentIncomingSyncOrder[1];
        if (head == nil or head.t == nil or (now - head.t) <= maxAge) then
            break;
        end
        table.remove(packet._recentIncomingSyncOrder, 1);
        if (head.key ~= nil and packet._recentIncomingSync[head.key] == head.t) then
            packet._recentIncomingSync[head.key] = nil;
        end
    end
    return false;
end
packet.chat = {}
packet.buff = {}
packet.inviter = '';
packet.InviteActive = false;

--CharInfo
packet.CharInfo = {}

-- Widescan request throttling (used to fill missing mob levels on target).
packet._ws_last_request_clock = 0;
packet._ws_last_request_target = 0;
packet.widescan_is_open = false;

packet.tracking = {
    active = false,
    actIndex = 0,
    x = 0,
    y = 0,
    z = 0,
    state = 0,
    level = 0,
};

--Treasure Pool Drops
packet.TreasurePool = {}
packet.TreasurePool.Dropper = nil;
packet.TreasurePool.DroppedIndex = nil;
packet.TreasurePool.DroppedItem = nil;
packet.TreasurePool.Item = nil;
packet.TreasurePool.Drop = nil;
packet.TreasurePool.HighestLotter = nil;
packet.TreasurePool.CurrentLotter = nil;

packet.Kill = {}
packet.Kill.Param1 = { } ;
packet.Kill.Param2 = { };
packet.Kill.Message = { };
packet.Kill.Flags = { };

--Handle Login Packets
packet.LoginPacket = function(e)
    if (enemy_debuff_tracker ~= nil and enemy_debuff_tracker.clear_zone ~= nil) then
        enemy_debuff_tracker.clear_zone();
    end
    if (target_mob_action ~= nil and target_mob_action.clear_zone ~= nil) then
        target_mob_action.clear_zone();
    end
    local id = struct.unpack('L', e.data, 0x04 + 1);
    local name = struct.unpack('c16', e.data, 0x84 + 1);
    local i,j = string.find(name, '\0');
    if(i~=nil)then
        name = string.sub(name, 1, i-1);
    end
    coroutine.sleep(5);
    gPacket.Player = id
    if(gPacket.action.Target == nil and GetPlayerEntity() ~= nil)then
        gPacket.action.Target = GetPlayerEntity().TargetIndex;
    end
    packet.CharInfo = {}
    packet.timer = os.time() + 30;
end


--Handle Chat Message Packets
packet.ChatMessage = function(Packet)
    if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
        gChat.handle_packet_in(Packet);
    end
end

-- Spell / ability .Name from Ashita is often Sol userdata; type() is not "table".
local function resource_display_name_from_object(r)
    if (r == nil or r.Name == nil) then
        return nil;
    end
    local n = r.Name;
    local ok, a, b = pcall(function()
        return n[1], n[2];
    end);
    if (not ok) then
        return nil;
    end
    for i = 1, 2 do
        local v = (i == 1) and a or b;
        if (v ~= nil) then
            local s = tostring(v);
            if (s ~= '' and s ~= 'nil') then
                return s;
            end
        end
    end
    return nil;
end

local function apply_cast_display_from_action_id(resMgr, rawId)
    packet.action.castBarSpellName = '';
    if (resMgr == nil or rawId == nil or type(rawId) ~= 'number' or rawId <= 0) then
        return;
    end
    local candidates = { rawId };
    if (rawId > 0xFFFF) then
        candidates[#candidates + 1] = bit.band(rawId, 0xFFFF);
    end
    for ci = 1, #candidates do
        local id = candidates[ci];
        if (id ~= nil and id > 0) then
            local spell = resMgr:GetSpellById(id);
            local nm = resource_display_name_from_object(spell);
            if (nm ~= nil) then
                packet.action.Resource = spell;
                packet.action.castBarSpellName = nm;
                return;
            end
            local ab = resMgr:GetAbilityById(id);
            nm = resource_display_name_from_object(ab);
            if (nm ~= nil) then
                packet.action.Resource = (spell ~= nil) and spell or ab;
                packet.action.castBarSpellName = nm;
                return;
            end
        end
    end
    local spell = resMgr:GetSpellById(candidates[1]);
    if (spell ~= nil) then
        packet.action.Resource = spell;
    end
end


--Handle Action Packets
packet.ActionPacket = function(Packet)
    local category = struct.unpack('H', Packet, 0x0A + 0x01);
    local actionId = struct.unpack('H', Packet, 0x0C + 0x01);
    local targetIndex = struct.unpack('H', Packet, 0x08 + 0x01);

    if(category == 0x03) then
        gPacket.action.Packet = Packet:totable();
        gPacket.action.Target = targetIndex;
        gPacket.action.Type = 'Spell';
        apply_cast_display_from_action_id(AshitaCore:GetResourceManager(), actionId);
    end
end


local function action_packet_bytes_for_bits(packet)
    if (packet.data_modified ~= nil and type(packet.data_modified) == 'string') then
        return packet.data_modified:totable();
    end
    return packet.data_raw;
end

packet.IncActionPacket = function(Packet)
    local raw = Packet.data;
    if (Packet.data_modified ~= nil) then
        raw = Packet.data_modified;
    end
    local user = struct.unpack('L', raw, 0x05 + 1);
    local bytes = action_packet_bytes_for_bits(Packet);
    local category = ashita.bits.unpack_be(bytes, 82, 4);

    packet.IncActionType = category;

    if(gPacket.Player == 0) then
        gPacket.Player = GetPlayerEntity().ServerId;
    end

    local pe = GetPlayerEntity();
    local isSelf = (user == gPacket.Player) or (pe ~= nil and user == pe.ServerId);

    if(isSelf)then
        if(category == 8) then
            gPacket.action.castBarDismissAt = nil;
            gPacket.action.Casting = true;
            gPacket.action.Interrupt = false;
            local legacy28 = (GlamourUI ~= nil and GlamourUI.settings ~= nil and GlamourUI.settings.Chat ~= nil
                and GlamourUI.settings.Chat.actionPacket28LegacyHeader == true);
            local actParsed = actionPacket28.parse_action_packet(raw, legacy28);
            local rawId = 0;
            if (actParsed ~= nil) then
                if (actParsed.targets ~= nil and #actParsed.targets > 0) then
                    local t0 = actParsed.targets[1];
                    if (t0.actions ~= nil and #t0.actions > 0) then
                        rawId = actionPacket28.resolve_action_id(actParsed.category, actParsed.param, t0.actions[1]) or 0;
                        if (rawId == 0 and actParsed.param ~= nil and actParsed.param > 0) then
                            rawId = actParsed.param;
                        end
                    elseif (actParsed.param ~= nil and actParsed.param > 0) then
                        rawId = actParsed.param;
                    end
                elseif (actParsed.param ~= nil and actParsed.param > 0) then
                    rawId = actParsed.param;
                end
            end
            if (rawId > 0) then
                apply_cast_display_from_action_id(AshitaCore:GetResourceManager(), rawId);
            end
        elseif(category == 4) then
            gPacket.action.castBarDismissAt = nil;
            gPacket.action.Casting = false;
            gPacket.action.Interrupt = false;
            packet.action.castBarSpellName = '';
        elseif(category == 6)then
            packet.IncActionMessage.Actor = struct.unpack('L', raw, 0x05 +1);
            packet.IncActionMessage.Roll = ashita.bits.unpack_be(bytes, 86, 10);
            packet.IncActionMessage.Param = ashita.bits.unpack_be(bytes, 213, 17);
        end
    end
end

packet.ActionMessage = function(Packet)
    local actorId = struct.unpack('I', Packet.data, 0x04 + 1);
    local target = struct.unpack('H', Packet.data, 0x16 + 0x01);
    local entity = GetEntity(target);
    local p1 = struct.unpack('l', Packet.data, 0x0C + 0x01);
    local p2 = struct.unpack('l', Packet.data, 0x10 + 0x01);
    local t = struct.unpack('l', Packet.data, 0x08 + 0x01);
    local m = struct.unpack('H', Packet.data, 0x18 + 0x01);

    if(gPacket.Player == 0) then
        gPacket.Player = GetPlayerEntity().ServerId;
    end
    local messageId = bit.band(m, 0x7FFF);
    local pe = GetPlayerEntity();
    local isSelf = (actorId == gPacket.Player) or (pe ~= nil and actorId == pe.ServerId);
    if(isSelf and messageId == 16) then
        gPacket.action.Interrupt = true;
        local delaySec = tonumber(packet.castBarInterruptHideDelaySec) or 1.0;
        if (delaySec < 0) then
            delaySec = 0;
        end
        gPacket.action.castBarDismissAt = os.clock() + delaySec;
    end

    if (m == 6 or m == 20 or m == 97 or m == 113 or m == 406 or m == 605 or m == 646) then
        if (gPacket.CharInfo[target] ~= nil) then
            gPacket.CharInfo[target] = nil;
        end
    end

    if (target ~= nil and target ~= 0 and m >= 170 and m <= 178) then
        local lvl = tonumber(p1);
        if (lvl ~= nil and lvl > 0 and lvl < 200) then
            if (packet.CharInfo[target] == nil) then
                packet.CharInfo[target] = {};
            end
            packet.CharInfo[target].Level = lvl;
            packet.CharInfo[target].Type = 2;
            if (entity ~= nil and entity.Name ~= nil and entity.Name ~= '') then
                packet.CharInfo[target].Name = entity.Name;
                packet.CharInfo[target].ServerId = entity.ServerId;
            end
        end
    end

    if (gEffects ~= nil and gEffects.remove ~= nil and entity ~= nil and entity.ServerId ~= nil and entity.ServerId ~= 0) then
        if (messageId == 204 or messageId == 206) then
            local statusId = tonumber(p1);
            if (statusId ~= nil and statusId > 0) then
                gEffects.remove(entity.ServerId, statusId);
            end
        end
    end

    if (enemy_debuff_tracker ~= nil and enemy_debuff_tracker.handle_message_basic ~= nil
            and entity ~= nil and entity.ServerId ~= nil and entity.ServerId ~= 0) then
        enemy_debuff_tracker.handle_message_basic({
            message = messageId,
            target = entity.ServerId,
            param = tonumber(p1),
            value = tonumber(p2),
        });
    end
end

packet.MakeTreasureLot = {
    id = 0x041,
    name = 'Treasure Lot',
    parse = nil,
    make = function(this, slot)
        return this.id, { 0x00, 0x00, 0x00, 0x00, slot }
    end,
}

packet.MakeTreasurePass = {
    id = 0x042,
    name = 'Treasure Pass',
    parse = nil,
    make = function(this, slot)
        return this.id, { 0x00, 0x00, 0x00, 0x00, slot }
    end,
}

packet.KillMessage = function(pack)
    local player = GetPlayerEntity();
    local target = struct.unpack('I', pack.data, 0x08 + 1);
    local KMPlayer = struct.unpack('I', pack.data, 0x04 + 1);
    local KMEXP = struct.unpack('I', pack.data, 0x10 + 1);
    local Param1 = struct.unpack('I', pack.data, 0x10 + 1);
    local Param2 = struct.unpack('I', pack.data, 0x14 + 1);
    local Message = struct.unpack('H', pack.data, 0x18 + 1);
    local Flags = struct.unpack('H', pack.data, 0x1A + 1);

    if(KMPlayer == player.ServerId)then
        if Message == 735 then
            table.insert(gParty.CPTable, Param1);
            table.insert(gParty.CPTimeTable, os.time());
            gParty.CPSum = gParty.CPSum + Param1;
            trim_cp_track();
            calcCPperHour();
        elseif(Message == 810)then
            table.insert(gParty.ExemPTable, Param1);
            table.insert(gParty.ExemPTimeTable, os.time());
            gParty.ExemPSum = gParty.ExemPSum + Param1;
            trim_exemp_track();
            calcExemPperHour();
        else
            table.insert(gParty.EXPTimeTable, os.time());
            table.insert(gParty.EXPTable, KMEXP);
            gParty.EXPSum = gParty.EXPSum + KMEXP;
            trim_exp_track();
        end
    end

    if(gParty.EXPTable ~= nil)then
        local newest = gParty.EXPTimeTable[#gParty.EXPTimeTable];
        if(#gParty.EXPTable > 1)then
            gParty.EXPTimeDelta = (newest - gParty.EXPTimeTable[1]) / 3600;
            calcEXPperHour();
        end
    end

    if(gPacket.CharInfo[target] ~= nil)then
        gPacket.CharInfo[target] = nil
    end

    if (gEffects ~= nil and gEffects.purge_target ~= nil) then
        gEffects.purge_target(target);
    end

    if (enemy_debuff_tracker ~= nil and enemy_debuff_tracker.purge_server_id ~= nil) then
        enemy_debuff_tracker.purge_server_id(target);
    end

end


--Handle Item Packets
packet.ItemPacket = function(Packet)
    local itemIndex = struct.unpack('B', Packet, 0x0E + 0x01);
    local itemContainer = struct.unpack('B', Packet, 0x10 + 0x01);
    local targetIndex = struct.unpack('H', Packet, 0x0C + 0x01);
    local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(itemContainer,itemIndex);

    gPacket.action.Packet = Packet:totable();
    gPacket.action.Target = targetIndex;
    gPacket.action.Type = 'Item';

end


packet.WSInfo = function(Packet)
    local w = struct.unpack('I', Packet.data, 0x04 + 1);
    local Index = w % 65536;
    local Info = {};
    Info.Level = math.floor(w / 65536) % 256;
    Info.Type = math.floor(w / 16777216) % 8;
    Info.Name = struct.unpack('c16', Packet.data, 0x0C + 1);
    local ent = GetEntity(Index);
    if (ent ~= nil and ent.ServerId ~= nil) then
        Info.ServerId = ent.ServerId;
    end
    packet.CharInfo[Index] = Info;
end

packet.RequestWidescanList = function()
    send_world_cli_u32(0xF4, 1);
end

packet.RequestTrackingStart = function(actIndex)
    local idx = tonumber(actIndex) or 0;
    if (idx < 1 or idx > 65535) then
        return;
    end
    send_tracking_cli_u32(0xF5, idx);
end

packet.RequestTrackingEnd = function()
    send_tracking_cli_u32(0xF6, 0);
    packet.tracking.active = false;
    packet.tracking.actIndex = 0;
end

packet.TrackingPos = function(Packet)
    if (Packet.data == nil or #Packet.data < 0x14 + 1) then
        return;
    end
    local st = packet.tracking;
    st.x = struct.unpack('f', Packet.data, 0x04 + 1);
    st.y = struct.unpack('f', Packet.data, 0x08 + 1);
    st.z = struct.unpack('f', Packet.data, 0x0C + 1);
    st.level = struct.unpack('B', Packet.data, 0x10 + 1);
    st.actIndex = struct.unpack('H', Packet.data, 0x12 + 1);
    st.state = struct.unpack('B', Packet.data, 0x14 + 1);
    if (st.state == 2 or st.state == 3) then
        st.active = false;
        st.actIndex = 0;
    else
        st.active = true;
    end
end

packet.TrackingState = function(Packet)
    if (Packet.data == nil or #Packet.data < 0x04 + 1) then
        return;
    end
    packet.tracking.listState = struct.unpack('B', Packet.data, 0x04 + 1);
end

--- Runs every frame so interrupt dismissal fires even if cast UI briefly shows \"Interrupted\".
packet.TickCastBarDismiss = function()
    local dismissAt = gPacket.action.castBarDismissAt;
    if (dismissAt == nil) then
        return;
    end
    if (os.clock() < dismissAt) then
        return;
    end
    gPacket.action.castBarDismissAt = nil;
    gPacket.action.Casting = false;
    gPacket.action.Interrupt = false;
    packet.action.castBarSpellName = '';
end

packet.TickTargetMobLevel = function()
    local mm = MemoryManager or AshitaCore:GetMemoryManager();
    if (mm == nil) then
        return;
    end
    local targetMgr = mm:GetTarget();
    if (targetMgr == nil) then
        return;
    end

    local targetIndex = targetMgr:GetTargetIndex(0);
    if (targetIndex == nil or targetIndex == 0) then
        return;
    end

    local ent = GetEntity(targetIndex);
    if (ent == nil) then
        return;
    end
    local info = packet.CharInfo[targetIndex];
    if (info ~= nil and info.ServerId ~= nil and ent ~= nil and ent.ServerId ~= nil and ent.ServerId ~= 0) then
        if (info.ServerId ~= 0 and info.ServerId ~= ent.ServerId) then
            if (gEffects ~= nil and gEffects.purge_target ~= nil) then
                gEffects.purge_target(info.ServerId);
            end
            packet.CharInfo[targetIndex] = nil;
        end
    end

    local spawnFlags = 0;
    local em = mm:GetEntity();
    if (em ~= nil and em.GetSpawnFlags ~= nil) then
        spawnFlags = tonumber(em:GetSpawnFlags(targetIndex)) or 0;
    else
        spawnFlags = tonumber(ent.SpawnFlags) or 0;
    end
    if (bit.band(spawnFlags, 0x10) ~= 0x10) then
        return;
    end

    info = packet.CharInfo[targetIndex];
    if (info ~= nil and info.Level ~= nil and tonumber(info.Level) > 0) then
        return;
    end

    local now = os.clock();
    local lastT = packet._ws_last_request_target or 0;
    local lastC = packet._ws_last_request_clock or 0;
    local changed = (targetIndex ~= lastT);
    if (changed or (now - lastC) > 1.0) then
        packet._ws_last_request_clock = now;
        packet._ws_last_request_target = targetIndex;
        packet.RequestWidescanList();
    end
end

packet.BuildWidescanEntries = function()
    local entries = T{};
    for idx, info in pairs(packet.CharInfo) do
        if (type(info) == 'table' and info.Name ~= nil) then
            local name = tostring(info.Name):gsub('%z.*', '');
            local ai = tonumber(idx);
            if (ai == nil) then
                ai = idx;
            end
            entries[#entries + 1] = { actIndex = ai, name = name, level = info.Level, type = info.Type };
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.name) < tostring(b.name);
    end);
    return entries;
end


--NPC Message Packets
packet.NPCMessage = function(Packet)

end


--Party Buff Packet Handler
packet.PartyBuffs = function(Packet)
    gPacket.buff.Packet = Packet;
end


--Handle Party Invite Packet
packet.PartyInvite = function(Packet);
    gPacket.inviter = struct.unpack('c16', Packet.data, 0x0c + 1);
    gPacket.InviteActive = true;
end

--Handle Response to Party Invite
packet.PartyInviteResponse = function(Packet)
    gPacket.InviteActive = false;
end

--Item Drop Packet
packet.ItemDrop = function(pack)
    gInv.getTreasurePool();
end

--Item Lot Packet
packet.ItemLots = function(pack)
    gInv.getTreasurePool();
end

--Packet Sort
packet.HandleIncoming = function(e)
    if (should_drop_duplicate_incoming_packet(e)) then
        return;
    end
    if(e.id == 0x0A)then
        packet.LoginPacket(e);
    elseif(e.id == 0x17)then
        packet.ChatMessage(e);
    elseif(e.id == 0x28)then
        if (enemy_debuff_tracker ~= nil and enemy_debuff_tracker.ingest_0x28_packet ~= nil) then
            enemy_debuff_tracker.ingest_0x28_packet(e);
        end
        if (target_mob_action ~= nil and target_mob_action.ingest_0x28_packet ~= nil) then
            target_mob_action.ingest_0x28_packet(e);
        end
        if (combatParse ~= nil and combatParse.rewrite_incoming_0x28 ~= nil) then
            combatParse.rewrite_incoming_0x28(e);
        end
        if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
            gChat.handle_packet_in(e);
        end
        packet.IncActionPacket(e);
    elseif(e.id == 0x29)then
        if (target_mob_action ~= nil and target_mob_action.ingest_0x29_packet ~= nil) then
            target_mob_action.ingest_0x29_packet(e);
        end
        if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
            gChat.handle_packet_in(e);
        end
        packet.ActionMessage(e);
    elseif(e.id == 0x02D)then
        if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
            gChat.handle_packet_in(e);
        end
        packet.KillMessage(e);
    elseif(e.id == 0x36)then
        if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
            gChat.handle_packet_in(e);
        end
    elseif(e.id == 0x32)then
        if (gChat ~= nil and gChat.handle_packet_in ~= nil) then
            gChat.handle_packet_in(e);
        end
    elseif(e.id == 0x76)then
        packet.PartyBuffs(e);
    elseif(e.id == 0xDC)then
        packet.PartyInvite(e);
    elseif(e.id == 0xD2)then
        packet.ItemDrop(e);
    elseif(e.id == 0xD3)then
        packet.ItemLots(e);
    elseif(e.id == 0xF4)then
        packet.WSInfo(e);
    elseif(e.id == 0xF5)then
        packet.TrackingPos(e);
    elseif(e.id == 0xF6)then
        packet.TrackingState(e);
    end
    calcEXPperHour();
    calcCPperHour();
    setEXPmode();
end



packet.HandleOutgoingChunk = function(e)
    local time = os.clock();
       
    
    local offset = 0;
    while (offset < e.chunk_size) do
        local id    = ashita.bits.unpack_be(e.chunk_data_raw, offset, 0, 9);
        local size  = ashita.bits.unpack_be(e.chunk_data_raw, offset, 9, 7) * 4;
        if (id == 0x1A) then
            gPacket.ActionPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1));
        elseif (id == 0x37) then
            gPacket.ItemPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1));
        elseif(id == 0x074)then
            gPacket.PartyInviteResponse(e);
        elseif(id == 0x0DD)then
            packet.RequestWidescanList();
        end

        offset = offset + size;
    end
end


packet.HandleOutgoing = function(e)
    if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
        gPacket.HandleOutgoingChunk(e);
    end

    if (gChat ~= nil and gChat.handle_packet_out ~= nil) then
        gChat.handle_packet_out(e);
    end
end

packet.InjectWSPacket = function()
    packet.RequestWidescanList();
end

return packet;
