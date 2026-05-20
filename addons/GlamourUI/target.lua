require('common');
local imgui = require('imgui');
local chat = require('chat');

local stptPointer = ashita.memory.find('FFXIMain.dll', 0, '891D????????74??4874??88', 0x02, 0x00);

local target = {};

local get_memory_manager = function()
    return MemoryManager or AshitaCore:GetMemoryManager();
end

local get_target_manager = function()
    return get_memory_manager():GetTarget();
end

local get_sub_target_index = function()
    local targetManager = get_target_manager();
    if(targetManager:GetIsSubTargetActive() == 1)then
        return targetManager:GetTargetIndex(0);
    end

    return 0;
end

local get_claim_status = function(entityIndex)
    local memoryManager = get_memory_manager();
    local claimStatus = memoryManager:GetEntity():GetClaimStatus(entityIndex);
    if(claimStatus == 0)then
        return 'unclaimed';
    end

    local partyManager = memoryManager:GetParty();
    for i = 1,18,1 do
        if(partyManager:GetMemberIsActive(i) == 1 and partyManager:GetMemberServerId(i) == claimStatus)then
            return 'party';
        end
    end

    return 'other';
end

local get_name_status = function()
    local memoryManager = get_memory_manager();
    local targetIndex = memoryManager:GetTarget():GetTargetIndex(0);
    local spawnFlags = memoryManager:GetEntity():GetSpawnFlags(targetIndex);
    local nameStatus = {
        type = '',
        status = '',
    };

    if(bit.band(spawnFlags, 0x02) == 0x02)then
        nameStatus.type = 'npc';
    elseif(bit.band(spawnFlags, 0x10) == 0x10)then
        nameStatus.type = 'mob';

        local claimStatus = get_claim_status(targetIndex);
        if(claimStatus == 'party')then
            nameStatus.status = 'partyClaimed';
        elseif(claimStatus == 'other')then
            nameStatus.status = 'otherClaimed';
        else
            nameStatus.status = 'unclaimed';
        end
    elseif(bit.band(spawnFlags, 0x01) == 0x01 or bit.band(spawnFlags, 0x0D) == 0x0D)then
        nameStatus.type = 'player';
    end

    return nameStatus;
end

target.ftTable = {};
target.is_open = false;
target.ft_is_open = false;

target.is_target_locked = function()
    return (bit.band(get_target_manager():GetLockedOnFlags(), 1) == 1);
end

target.get_sub_target_entity = function()
    local subTargetIndex = get_sub_target_index();
    if(subTargetIndex ~= 0)then
        return GetEntity(subTargetIndex);
    end

    return nil;
end

target.push_nameplate_color = function()
    local nameStatus = get_name_status();

    if(nameStatus.type == 'mob')then
        if(nameStatus.status == 'partyClaimed')then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.2, 1.0});
            return;
        elseif(nameStatus.status == 'otherClaimed')then
            imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.2, 0.8, 1.0});
            return;
        elseif(nameStatus.status == 'cfh')then
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

    if(nameStatus.type == 'player')then
        if(nameStatus.status == 'anon')then
            imgui.PushStyleColor(ImGuiCol_Text, {0.24, 0.56, 0.73, 1.0});
            return;
        end

        imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
    end
end

target.get_name_status = function()
    return get_name_status();
end

target.add_focus_target = function()
    local targetManager = get_target_manager();
    local targetIndex = targetManager:GetTargetIndex(targetManager:GetIsSubTargetActive());
    local targetEntity = GetEntity(targetIndex);
    if(targetEntity == nil)then
        print(chat.header('No Target Selected to Add to Focus List'));
        return;
    end

    table.insert(gTarget.ftTable, targetEntity);
end

target.add_focus_target_by_index = function(entityIndex)
    local idx = tonumber(entityIndex) or 0;
    if (idx == 0) then
        return;
    end
    local ent = GetEntity(idx);
    if (ent == nil) then
        return;
    end
    table.insert(gTarget.ftTable, ent);
end

target.remove_focus_target = function(targetIndex)
    gTarget.ftTable = gHelper.ArrayRemove(gTarget.ftTable, targetIndex);
end

target.clear_focus_target = function()
    gTarget.ftTable = {};
end

target.get_selected_alliance_member = function()
    local structPointer = ashita.memory.read_uint32(stptPointer);
    return ashita.memory.read_uint32(structPointer + 0x00), ashita.memory.read_uint32(structPointer + 0x04) > 0;
end

return target;
