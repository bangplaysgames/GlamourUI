--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local imgui = require('imgui');
local panelStyle = require('panelStyle');
local env = require('scaling');
local chat = require('chat');
require('common');

local inventory = {}

inventory.timestamps = {}

inventory.settings = {}

inventory.treasurePool = T{}
inventory._treasurePoolFingerprint = nil;

inventory.render_inv_panel = function()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local zoning = player:GetIsZoning();

    if (zoning == 0) then
        if(GlamourUI.settings.Inv.enabled == true)then
            local invTex = gResources.getTex(GlamourUI.settings, 'Inv', 'lootbag.png');
            local wardTex = gResources.getTex(GlamourUI.settings, 'Inv', 'wardrobe.png');
            local safeTex = gResources.getTex(GlamourUI.settings, 'Inv', 'safe.png');
            local tPoolTex = gResources.getTex(GlamourUI.settings, 'Inv', 'treasure.png');
            local gilTex = gResources.getTex(GlamourUI.settings, 'Inv', 'gil.png');
            local mX = env.menu.w;
            local mY = env.menu.h;
            local wX = env.window.w;
            local wY = env.window.h;
            local scaleX = wX / mX;
            local scaleY = wY / mY;
            local size = {(115 * scaleX), (185 * scaleY)};
            local menu = {wX - (128 * scaleX), wY - (200 * scaleY)};
            local gil = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0);
            local wardCount = gInv.getInventory(8) + gInv.getInventory(10) + gInv.getInventory(11) + gInv.getInventory(12) + gInv.getInventory(13) + gInv.getInventory(14) + gInv.getInventory(15) + gInv.getInventory(16);
            local wardMax = gInv.getInventoryMax(8) + gInv.getInventoryMax(10) + gInv.getInventoryMax(11) + gInv.getInventoryMax(12) + gInv.getInventoryMax(13)+ gInv.getInventoryMax(14) + gInv.getInventoryMax(15) + gInv.getInventoryMax(16);
            local tPoolCount = AshitaCore:GetMemoryManager():GetInventory():GetTreasurePoolItemCount();
            local houseCount = gInv.getInventory(1) + gInv.getInventory(2) + gInv.getInventory(4) + gInv.getInventory(9);
            local houseMax = gInv.getInventoryMax(1) + gInv.getInventoryMax(2) + gInv.getInventoryMax(4) + gInv.getInventoryMax(9);

            imgui.SetNextWindowBgAlpha(1);
            imgui.SetNextWindowSize(size, ImGuiCond_Always);
            imgui.SetNextWindowPos(menu);
            local invBgPops = panelStyle.push_panel_background(GlamourUI.settings.Inv);
            if(imgui.Begin("InventoryPanel##GlamInv", GlamourUI.settings.Inv.enabled, bit.bor(ImGuiWindowFlags_NoDecoration)))then
                local fontPushed = gResources.push_font_scale((GlamourUI.settings.Inv.font_scale * 0.5) * GlamourUI.settings.Inv.font_scale);

                --Inventory Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(20 * scaleY);
                imgui.Text(tostring(gInv.getInventory(0)) .. '/' .. tostring(gInv.getInventoryMax(0)));
                imgui.SameLine();
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(16 * scaleY);
                imgui.Image(invTex, {15 * scaleX, 20 * scaleY})

                --Wardrobe Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(50 * scaleY);
                imgui.Text(tostring(wardCount).. '/' .. tostring(wardMax));
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(51 * scaleY);
                imgui.Image(wardTex, {15 * scaleX, 20 * scaleY});

                --MogSafe Counts
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(80 * scaleY);
                imgui.Text(tostring(houseCount) .. '/' .. tostring(houseMax));
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(81 * scaleY);
                imgui.Image(safeTex, {15 * scaleX, 20 * scaleY});

                --Treasure Pool
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(110 * scaleY);
                imgui.Text(tostring(tPoolCount));
                imgui.SetCursorPosX(80 * scaleX);
                imgui.SetCursorPosY(114 * scaleY);
                imgui.Image(tPoolTex, {25 * scaleX, 20 * scaleY});

                --Gil Count
                imgui.SetCursorPosX(15 * scaleX);
                imgui.SetCursorPosY(145 * scaleY);
                if gil ~= nil then
                    imgui.Text(tostring(gil.Count));
                end
                imgui.SetCursorPosX(85 * scaleX);
                imgui.SetCursorPosY(147 * scaleY);
                imgui.Image(gilTex, {15 * scaleX, 15 * scaleY});
                gResources.pop_font(fontPushed);
                imgui.End();
            end
            panelStyle.pop_panel_background(invBgPops);
        end
    end
end

inventory.getInventory = function(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCount(cont_id);
end

inventory.getInventoryMax = function(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCountMax(cont_id);
end

inventory.getTreasurePool = function()
    local res = AshitaCore:GetResourceManager()
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local player = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    local now = os.time()

    -- Fast path: detect no change in pool state, skip rebuild.
    local fpParts = {};
    local any = false;
    for i = 0,9 do
        local treasureDrop = inv:GetTreasurePoolItem(i)
        if treasureDrop ~= nil and treasureDrop.ItemId > 0 then
            any = true;
            fpParts[#fpParts + 1] = string.format('%d:%d:%d:%d:%d', i, treasureDrop.ItemId or 0, treasureDrop.DropTime or 0, treasureDrop.Lot or 0, treasureDrop.WinningLot or 0);
        end
    end
    local fp = any and table.concat(fpParts, '|') or '';
    if (fp == (inventory._treasurePoolFingerprint or '')) then
        return;
    end
    inventory._treasurePoolFingerprint = fp;

    inventory.treasurePool = T{}

    for i = 0,9 do
        local treasureDrop = inv:GetTreasurePoolItem(i)
        if treasureDrop ~= nil and treasureDrop.ItemId > 0 then
            local itemInfo = res:GetItemById(treasureDrop.ItemId)

            if not inventory.timestamps[treasureDrop.DropTime] then
                inventory.timestamps[treasureDrop.DropTime] = now + 300
            end

            local drop = {}
            drop.id = treasureDrop.ItemId;
            drop.icon = gResources.get_item_icon(treasureDrop.ItemId, itemInfo);
            drop.slot = i;
            drop.name = itemInfo.Name[1];
            drop.expiresAt = inventory.timestamps[treasureDrop.DropTime];
            drop.winner = {}
            drop.winner.exists = treasureDrop.WinningLot > 0;
            drop.winner.name = treasureDrop.WinningEntityName;
            drop.winner.lot = string.format('%4i', treasureDrop.WinningLot);
            drop.current = {}
            drop.current.name = player;
            drop.current.lot = string.format('%4i', treasureDrop.Lot);
            drop.current.hasRolled = treasureDrop.Lot > 0 and treasureDrop.Lot < 1000;
            drop.current.hasPassed = treasureDrop.Lot > 1000;

            table.insert(inventory.treasurePool, drop);
        end
    end
end

inventory.TPoolLot = function(slot)
        AshitaCore:GetPacketManager():AddOutgoingPacket(gPacket.MakeTreasureLot:make(slot));
end

inventory.TPoolPass = function(slot)
    AshitaCore:GetPacketManager():AddOutgoingPacket(gPacket.MakeTreasurePass:make(slot));
end

local ITEM_FLAG_RARE = 0x8000;

local LOT_VISIBLE_CONTAINERS = { 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

local function pool_item_display_name(drop, itemRes)
    if (drop ~= nil and drop.name ~= nil and drop.name ~= '') then
        return tostring(drop.name);
    end
    if (itemRes ~= nil and itemRes.Name ~= nil and itemRes.Name[1] ~= nil) then
        return tostring(itemRes.Name[1]);
    end
    if (drop ~= nil and drop.id ~= nil) then
        return ('Item #%u'):fmt(tonumber(drop.id) or 0);
    end
    return 'Item';
end

local function container_contains_item_id(inv, containerId, itemId)
    local maxIdx = inv:GetContainerCountMax(containerId);
    if (maxIdx == nil or maxIdx <= 0) then
        return false;
    end
    for idx = 0, maxIdx - 1 do
        local it = inv:GetContainerItem(containerId, idx);
        if (it ~= nil and it.Id == itemId and (it.Count or 0) > 0) then
            return true;
        end
    end
    return false;
end

local function equipment_contains_item_id(inv, itemId)
    for slot = 0, 15 do
        local eitem = inv:GetEquippedItem(slot);
        if (eitem ~= nil and eitem.Index ~= nil and eitem.Index ~= 0) then
            local cont = bit.band(eitem.Index, 0xFF00) / 256;
            local index = bit.band(eitem.Index, 0xFF);
            local it = inv:GetContainerItem(cont, index);
            if (it ~= nil and it.Id == itemId and (it.Count or 0) > 0) then
                return true;
            end
        end
    end
    return false;
end

local function player_owns_item_id(inv, itemId)
    for i = 1, #LOT_VISIBLE_CONTAINERS do
        if (container_contains_item_id(inv, LOT_VISIBLE_CONTAINERS[i], itemId) == true) then
            return true;
        end
    end
    return equipment_contains_item_id(inv, itemId);
end

---@param drop table
---@return boolean ok
---@return string|nil reason
inventory.canLot = function(drop)
    if (drop == nil or drop.id == nil or tonumber(drop.id) == nil or tonumber(drop.id) <= 0) then
        return false, 'Unable to cast lot for item.  Reason:  Invalid item.';
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local res = AshitaCore:GetResourceManager();
    local itemRes = res:GetItemById(drop.id);
    if (itemRes == nil) then
        return false, ('Unable to cast lot for %s.  Reason:  Unknown item.'):fmt(pool_item_display_name(drop, nil));
    end

    local name = pool_item_display_name(drop, itemRes);

    local bagCount = inv:GetContainerCount(0);
    local bagMax = inv:GetContainerCountMax(0);
    if (bagMax ~= nil and bagMax > 0 and bagCount ~= nil and bagCount >= bagMax) then
        return false, ('Unable to cast lot for %s.  Reason:  Inventory is full.'):fmt(name);
    end

    local flags = tonumber(itemRes.Flags) or 0;
    if (bit.band(flags, ITEM_FLAG_RARE) ~= 0) then
        if (player_owns_item_id(inv, drop.id) == true) then
            return false, ('Unable to cast lot for %s.  Reason:  You already possess this rare item.'):fmt(name);
        end
    end

    return true;
end

inventory.tryLotDrop = function(drop)
    local ok, reason = inventory.canLot(drop);
    if (not ok) then
        print(chat.error(reason));
        return false;
    end
    inventory.TPoolLot(drop.slot);
    return true;
end

inventory.tryLotSlot = function(slotNum)
    local n = tonumber(slotNum);
    if (n == nil) then
        print(chat.error('Unable to cast lot.  Reason:  Invalid slot.'));
        return false;
    end
    inventory.getTreasurePool();
    for i = 1, #inventory.treasurePool do
        local drop = inventory.treasurePool[i];
        if (drop.slot == n) then
            return inventory.tryLotDrop(drop);
        end
    end
    print(chat.error(('Unable to cast lot.  Reason:  No item in treasure pool slot %s.'):fmt(tostring(slotNum))));
    return false;
end

return inventory;
