require ('common');
local ffi = require ('ffi');
local imgui = require('imgui');


local stptPointer = ashita.memory.find('FFXIMain.dll', 0, '891D????????74??4874??88', 0x02, 0x00);



local function GetSubTargetIndex()
    local targetMgr = AshitaCore:GetMemoryManager():GetTarget();
    if (targetMgr:GetIsSubTargetActive() == 1) then
        return targetMgr:GetTargetIndex(0);
    end
    return 0;
end

--Returns if entity is claimed, and if so, if it's by the player's party/alliance or not.
local function getClaimed(e)
    local claimStatus = e.ClaimStatus;
    if (claimStatus == 0) then
        return 'unclaimed';
    end

    local party = AshitaCore:GetMemoryManager():GetParty();
    for i = 1,18 do
        if (party:GetMemberIsActive(i) == 1) and (party:GetMemberServerId(i) == claimStatus) then
            return 'party';
        end
    end

    return 'other';
end

--Target Bar Nameplate Status
local function getNameStatus(f1, f2, e)
    local t = {
        mob = false,
        player = false,
        otherPlayer = false,
        cfh = false,
        partyClaimed = false,
        otherClaimed = false,
        charmed = false,
        anon = false,
        seekParty = false,
        npc = false
    }
    if(bit.band(f1, 0x800))then
        t.npc = true;
    end
    if(bit.band(f1, 0x2000000) == 0x2000000)then
        t.mob = true;

        if(bit.band(f2, 0x2000) == 0x2000)then
            t.charmed = true;
        end
        if(bit.band(f1, 0x1000000) == 0x1000000)then
            t.cfh = true;
        end
        if(getClaimed(e) == 'party')then
            t.partyClaimed = true;
        elseif(getClaimed(e) == 'other')then
            t.otherClaimed = true;
        end
    end
    if(bit.band(f1, 0x3000000) == 0x3000000)then
        t.cfh = true;
    end
    if(bit.band(f1, 0x8000000) == 0x8000000)then
        if(bit.band(f1, 0x2000800) == 0x2000800)then
            t.mob = false;
            t.otherPlayer = true;
            t.npc = false;
        else
            t.player = true;
            t.npc = false;
        end
    end
    if(bit.band(f1, 0x800000) == 0x800000)then
        t.anon = true;
    end
    if(bit.band(f1, 0x100000) == 0x100000)then
        t.seekParty = true;
    end
    return t;
end



local target = {}

--Returns true if targetlocked
target.IsTargetLocked = function()
    return (bit.band(AshitaCore:GetMemoryManager():GetTarget():GetLockedOnFlags(), 1) == 1);
end

--Returns the Entity of the sub-target.
target.getSubTargetEntity = function()
    local subTargetIndex = GetSubTargetIndex();
    if subTargetIndex ~= 0 then
        return GetEntity(subTargetIndex);
    end
    return nil;
end

--Returns the Color of Target Bar Nameplate
target.GetNameplateColor = function(e)
    local flags1 = e.Render.Flags1;
    local flags3 = e.Render.Flags3;
    local status = getNameStatus(flags1, flags3, e);

    if(status.mob == true)then
        if(status.partyClaimed == true)then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.2, 1.0});
            return;
        elseif(status.otherClaimed == true)then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.8, 1.0});
            return;
        elseif(status.cfh == true) then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.7, 0.3, 1.0});
            return;
        else
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 0.2, 1.0});
            return;
        end
    end
    if(status.npc == true)then
        imgui.PushStyleColor(ImGuiCol_Text, {0.2, 0.8, 0.2, 1.0});
        return;
    end

    if(status.seekParty == true)then
        imgui.PushStyleColor(ImGuiCol_Text, {0.8, 0.8, 1.0, 1.0});
        return;
    end
    if(status.player == true or status.otherPlayer == true) then
        if(status.anon == true)then
            imgui.PushStyleColor(ImGuiCol_Text, {0.24, 0.56, 0.73, 1.0});
            return;
        else
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
            return;
        end
    end
end

target.is_open = false;

--Paryt-List Cursor outside of normal target indicator
target.GetSelectedAllianceMember = function()
    local structPointer = ashita.memory.read_uint32(stptPointer);
    return ashita.memory.read_uint32(structPointer + 0x00), ashita.memory.read_uint32(structPointer + 0x04) > 0;
end


return target;