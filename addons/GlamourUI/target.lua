require ('common');
local ffi = require ('ffi');
local imgui = require('imgui');
local chat = require('chat');


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
    local claimStatus = AshitaCore:GetMemoryManager():GetEntity():GetClaimStatus(e);
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
getNameStatus = function(f1, f2, e)
    local spawnFlags = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(e);
    local t = {
        type = '',
        status = '',
    }
    if(bit.band(spawnFlags, 0x02) == 0x02)then
        t.type = 'npc';
    elseif(bit.band(spawnFlags, 0x10) == 0x10)then
        t.type = 'mob';
        if(bit.band(f2, 0x2000) == 0x2000)then
            t.status = 'charmed';
        elseif(bit.band(f1, 0x1000000) == 0x1000000)then
            t.status = 'cfh';
        elseif(getClaimed(e) == 'party')then
            t.status = 'partyClaimed';
        elseif(getClaimed(e) == 'other')then
            t.status = 'otherClaimed';
        else
            t.status = 'unclaimed';
        end
    elseif(bit.band(spawnFlags, 0x01) == 0x01 or bit.band(spawnFlags, 0x0d) == 0x0d)then
        t.type = 'player'

        if(bit.band(f1, 0x800000) == 0x800000)then
            t.status = 'anon';
        elseif(bit.band(f1, 0x100000) == 0x100000)then
            t.status = 'seekParty';
        end
    end
    return t;
end



local target = {}

target.ftTable = {}

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
    local flags1 = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags1(e);
    local flags3 = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags3(e);
    local nameStatus = getNameStatus(flags1, flags3, e);

    if(nameStatus.type == 'mob')then
        if(nameStatus.status == 'partyClaimed')then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.2, 1.0});
            return;
        elseif(nameStatus.status == 'otherClaimed')then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.8, 1.0});
            return;
        elseif(nameStatus.status == 'cfh') then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.7, 0.3, 1.0});
            return;
        elseif(nameStatus.status == 'unclaimed')then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 0.2, 1.0});
            return;
        end
    end
    if(nameStatus.type == 'npc')then
        imgui.PushStyleColor(ImGuiCol_Text, {0.2, 0.8, 0.2, 1.0});
        return;
    end

    if(nameStatus.status == 'seekParty')then
        imgui.PushStyleColor(ImGuiCol_Text, {0.8, 0.8, 1.0, 1.0});
        return;
    end
    if(nameStatus.type == 'player') then
        if(nameStatus.status == 'anon')then
            imgui.PushStyleColor(ImGuiCol_Text, {0.24, 0.56, 0.73, 1.0});
            return;
        else
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
            return;
        end
    end
end

target.AddFocusTarget = function()
    local targ = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive());
    local targetEntity = GetEntity(targ);
    if(targetEntity == nil)then
        print(chat.header('No Target Selected to Add to Focus List'));
        return;
    end
    table.insert(gTarget.ftTable, targetEntity);
end

target.RemoveFocusTarget = function(t)
    gTarget.ftTable = gHelper.ArrayRemove(gTarget.ftTable, t);
end

target.ClearFocusTarget = function()
    gTarget.ftTable = nil
    gTarget.ftTable = {}
end

target.is_open = false;

target.ft_is_open = false;

--Paryt-List Cursor outside of normal target indicator
target.GetSelectedAllianceMember = function()
    local structPointer = ashita.memory.read_uint32(stptPointer);
    return ashita.memory.read_uint32(structPointer + 0x00), ashita.memory.read_uint32(structPointer + 0x04) > 0;
end


return target;