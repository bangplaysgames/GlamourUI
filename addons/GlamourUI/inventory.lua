--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local imgui = require('imgui');
local env = require('scaling');
require('common');

local inventory = {}

inventory.settings = {}

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
            local houseMax = gInv.getInventoryMax(1) + gInv.getInventoryMax(2) + gInv.getInventoryMax(4);

            imgui.SetNextWindowBgAlpha(1);
            imgui.SetNextWindowSize(size, ImGuiCond_Always);
            imgui.SetNextWindowPos(menu);
            if(imgui.Begin("InventoryPanel##GlamInv", GlamourUI.settings.Inv.enabled, bit.bor(ImGuiWindowFlags_NoDecoration)))then
                imgui.SetWindowFontScale((GlamourUI.settings.Inv.font_scale * 0.5) * GlamourUI.settings.Inv.font_scale);

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
                imgui.End();
            end
        end
    end
end

inventory.getInventory = function(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCount(cont_id);
end

inventory.getInventoryMax = function(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCountMax(cont_id);
end

return inventory;