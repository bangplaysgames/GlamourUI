local ffi = require('ffi');
local chat = require('chat');
local settings = require('settings');

ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];


local packet = {}

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
end


--Handle Chat Message Packets
packet.ChatMessage = function(packet)

end


--Handle Action Packets
packet.ActionPacket = function(packet)
    local category = struct.unpack('H', packet, 0x0A + 0x01);
    local actionId = struct.unpack('H', packet, 0x0C + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x08 + 0x01);

    if(category == 0x03) then
        gPacket.action.Packet = packet:totable();
        gPacket.action.Target = targetIndex;
        gPacket.action.Type = 'Spell';
        gPacket.action.Resource = AshitaCore:GetResourceManager():GetSpellById(actionId);
    end
end


--Handle Incoming Action Packet
packet.IncActionPacket = function(packet)
    local user = struct.unpack('L', packet.data, 0x05 + 1);
    local actionType = ashita.bits.unpack_be(packet.data_raw, 10, 2, 4);

    
    --Check if player server ID set.  If not, Set it.
    if(gPacket.Player == 0) then
        gPacket.Player = GetPlayerEntity().ServerId;
    end
    

    if(user == gPacket.Player)then
        if(actionType == 8) then
            gPacket.action.Casting = true;
            if(ashita.bits.unpack_be(packet.data_raw, 10, 6, 16) == 28787)then
                gPacket.action.Interrupt = true;
            else
                gPacket.action.Interrupt = false;
            end
            coroutine.sleep(gPacket.action.Resource.CastTime * .4);
            gPacket.action.Casting = false;
        end
    end
end

--Handle Action Message Packets
packet.ActionMessage = function(packet)
    

end


--Handle Kill Message Packets
packet.KillMessage = function(packet)

end


--Handle Item Packets
packet.ItemPacket = function(packet)
    local itemIndex = struct.unpack('B', packet, 0x0E + 0x01);
    local itemContainer = struct.unpack('B', packet, 0x10 + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x0C + 0x01);
    local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(itemContainer,itemIndex);

    gPacket.action.Packet = packet:totable();
    gPacket.action.Target = targetIndex;
    gPacket.action.Type = 'Item';

end


--NPC Message Packets
packet.NPCMessage = function(packet)

end


--Party Buff Packet Handler
packet.PartyBuffs = function(packet)
    gPacket.buff.Packet = packet;
end


--Handle Party Invite Packet
packet.PartyInvite = function(packet);
    gPacket.inviter = struct.unpack('c16', packet.data, 0x0c + 1);
    gPacket.InviteActive = true;
end


--Packet Sort
packet.HandleIncoming = function(e)
    if(e.id == 0x0A)then
        gPacket.LoginPacket(e);
    elseif(e.id == 0x17)then
        gPacket.ChatMessage(e);
    elseif(e.id == 0x28)then
        gPacket.IncActionPacket(e);
    elseif(e.id == 0x29)then
        gPacket.ActionMessage(e);
    elseif(e.id == 0x2D)then
        gPacket.KillMessage(e);
    elseif(e.id == 0x36)then
        gPacket.NPCMessage(e);
    elseif(e.id == 0x76)then
        gPacket.PartyBuffs(e);
    elseif(e.id == 0xDC)then
        gPacket.PartyInvite(e);
    end
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
