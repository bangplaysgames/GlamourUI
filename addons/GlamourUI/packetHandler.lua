local ffi = require('ffi');
local chat = require('chat');
local settings = require('settings');

ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

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
    gParty.GetParty();
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
packet.chat = {}
packet.buff = {}
packet.inviter = '';
packet.InviteActive = false;

--CharInfo
packet.CharInfo = {}

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
end


--Handle Chat Message Packets
packet.ChatMessage = function(Packet)

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
        gPacket.action.Resource = AshitaCore:GetResourceManager():GetSpellById(actionId);
    end
end


--Handle Incoming Action Packet
packet.IncActionPacket = function(Packet)
    local user = struct.unpack('L', Packet.data, 0x05 + 1);
    local actionType = ashita.bits.unpack_be(Packet.data_raw, 10, 2, 4);


    packet.IncActionType = actionType;
    
    --Check if player server ID set.  If not, Set it.
    if(gPacket.Player == 0) then
        gPacket.Player = GetPlayerEntity().ServerId;
    end

    if(user == gPacket.Player)then
        if(actionType == 8) then
            gPacket.action.Casting = true;
            if(ashita.bits.unpack_be(Packet.data_raw, 10, 6, 16) == 28787)then
                gPacket.action.Interrupt = true;
            else
                gPacket.action.Interrupt = false;
            end
            coroutine.sleep(gPacket.action.Resource.CastTime * .4);
            gPacket.action.Casting = false;
        elseif(actionType == 6)then
            packet.IncActionMessage.Actor = struct.unpack('L', Packet.data, 0x05 +1);
            packet.IncActionMessage.Roll = ashita.bits.unpack_be(Packet.data_raw, 86, 10);
            packet.IncActionMessage.Param = ashita.bits.unpack_be(Packet.data_raw, 213, 17);
        end
    end
end

--Handle Action Message Packets
packet.ActionMessage = function(Packet)
    local target = struct.unpack('H', Packet.data, 0x16 + 0x01);
    local entity = GetEntity(target);
    local p1    = struct.unpack('l', Packet.data, 0x0C + 0x01);

    if (gPacket.CharInfo[target] == nil) then
        gPacket.CharInfo[target] = {}
        gPacket.CharInfo[target].Level = p1;
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

--Handle Kill Message Packets
packet.KillMessage = function(pack)
    local player = GetPlayerEntity();
    local target = struct.unpack('L', pack.data, 0x08 +1);
    local KMPlayer = struct.unpack('L', pack.data, 0x04 + 1);
    local KMEXP = struct.unpack('L', pack.data, 0x10 + 1);
    local Param1 = struct.unpack('L', pack.data, 0x10 +1);
    local Param2 = struct.unpack('L', pack.data, 0x14 +1);
    local Message = struct.unpack('H', pack.data, 0x18 +1);
    local Flags = struct.unpack('H', pack.data, 0x1A +1);

    if(KMPlayer == player.ServerId)then
        if Message == 735 then
            table.insert(gParty.CPTable, Param1);
            table.insert(gParty.CPTimeTable, os.time());
            gParty.CPSum = gParty.CPSum + Param1;
            calcCPperHour();
        elseif(Message == 810)then
            table.insert(gParty.ExemPTable, Param1);
            table.insert(gParty.ExemPTimeTable, os.time());
            gParty.ExemPSum = gParty.ExemPSum + Param1;
            calcExemPperHour();
        else
            table.insert(gParty.EXPTimeTable, os.time());
            table.insert(gParty.EXPTable, KMEXP);
            gParty.EXPSum = gParty.EXPSum + KMEXP;
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
    local Info = {}
    local Index = struct.unpack('H', Packet.data, 0x04 + 1);
    Info.Level = struct.unpack('B', Packet.data, 0x06 + 1);
    Info.Type = struct.unpack('B', Packet.data, 0x07 + 1);
    Info.Name = struct.unpack('c16', Packet.data, 0x0C + 1);
    packet.CharInfo[Index] = Info;
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
end

--Item Lot Packet
packet.ItemLots = function(pack)
end

--Packet Sort
packet.HandleIncoming = function(e)
    --print(chat.error(tostring(e.id)));
    if(e.id == 0x0A)then
        packet.LoginPacket(e);
    elseif(e.id == 0x17)then
        packet.ChatMessage(e);
    elseif(e.id == 0x28)then
        packet.IncActionPacket(e);
    elseif(e.id == 0x29)then
        packet.ActionMessage(e);
    elseif(e.id == 0x02D)then
        packet.KillMessage(e);
    elseif(e.id == 0x36)then
        packet.NPCMessage(e);
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
    end
    calcEXPperHour();
    calcCPperHour();
    setEXPmode();
end



packet.HandleOutgoingChunk = function(e)
    --Clear expired actions.
    local time = os.clock();
       
    
    --Read ahead to handle any action packets, so we aren't doing idle and action at once.
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
        end

        offset = offset + size;
    end
end


packet.HandleOutgoing = function(e)
    --If we're in a new outgoing chunk, handle idle / action stuff.
    if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
        gPacket.HandleOutgoingChunk(e);
    end
end


return packet;
