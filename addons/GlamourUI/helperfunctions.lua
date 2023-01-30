--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--
local ffi = require('ffi')
local d3d8 = require('d3d8')
local imgui = require('imgui')
require('common')
local chat = require('chat')
local buffTable = require('buffTable')
local buffHandler = require('buffHandler')
local resources = require('resources')

local cache = T{
    theme = nil,
    paths = T{},
    textures = T{}
};

ffi.cdef[[
    typedef bool (__cdecl* isevent_f)(int8_t flag);
]];

local ptr = ashita.memory.find('FFXiMain.dll', 0, 'A0????????84C074??B001C366', 0, 0);
if (ptr == 0) then
    error('bad pointer');
end
is_event = ffi.cast('isevent_f', ptr);

function IsTargetLocked()
    return (bit.band(AshitaCore:GetMemoryManager():GetTarget():GetLockedOnFlags(), 1) == 1);
end

function isPartyLeader(p)
    return (bit.band(AshitaCore:GetMemoryManager():GetParty():GetMemberFlagMask(p), 0x4) == 0x4);
end

function isLevelSync(p)
    return (bit.band(AshitaCore:GetMemoryManager():GetParty():GetMemberFlagMask(p), 0x100) == 0x100);
end

function getName(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberName(index);
end

function getHP(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberHP(index);
end

function getHPP(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(index);
end

function getMP(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberMP(index);
end

function getMPP(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberMPPercent(index);
end

function getTP(index)
    return AshitaCore:GetMemoryManager():GetParty():GetMemberTP(index);
end

function getBuffs(p, t)
    local name = getName(p);
    local sid = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(p);
    print(chat.header(tostring(sid)));
    local pbuffs = buffHandler:get_member_status(sid);
    print(chat.header(tostring(pbuffs)));
    local buffs = {};
    local debuffs = {};
    for i = 0, #buffs do
        if (buffTable.IsBuff(pbuffs[i])) then
            table.insert(buffs, pbuffs[i]);
            if(t == 'buffs')then
                return buffs;
            end
        else
            table.insert(debuffs, pbuffs[i]);
            if(t == 'debuffs')then
                return debuffs;
            end
        end
    end
end

function getInventory(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCount(cont_id);
end

function getInventoryMax(cont_id)
    return AshitaCore:GetMemoryManager():GetInventory():GetContainerCountMax(cont_id);
end

function getNameplateColor(e)
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

function getClaimed(e)
    local c = {
        [0] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
        [1] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(1);
        [2] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(2);
        [3] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(3);
        [4] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(4);
        [5] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(5);
        [6] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(6);
        [7] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(7);
        [8] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(8);
        [9] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(9);
        [10] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(10);
        [11] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(11);
        [12] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(12);
        [13] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(13);
        [14] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(14);
        [15] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(15);
        [16] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(16);
        [17] = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(17);
    }
    if (e.ClaimStatus ~= nil)then
        if(e.ClaimStatus == 0)then
            return 'unclaimed';
        else
            if(table.contains(c, e.ClaimStatus))then
                return 'party';
            else
                return 'other';
            end
        end
    end
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function getNameStatus(f1, f2, e)
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

function GetSubTargetIndex()
    local targetMgr = AshitaCore:GetMemoryManager():GetTarget();
    if (targetMgr:GetIsSubTargetActive() == 1) then
        return targetMgr:GetTargetIndex(0);
    end
    return 0;
end

function getSubTargetEntity()
    local subTargetIndex = GetSubTargetIndex();
    if subTargetIndex ~= 0 then
        return GetEntity(subTargetIndex);
    end
    return nil;
end

function getZone(index)
    local id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(index);
    return AshitaCore:GetResourceManager():GetString('zones.names', id);
end

function getThemeID(theme)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    for i = 1,#dir,1 do
        if(dir[i] == theme) then
            return i;
        end
    end
end

function getLayoutID(layout)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\'):fmt(AshitaCore:GetInstallPath()));

    for i = 1,#dir,1 do
        if(dir[i] == layout) then
            return i;
        end
    end
end

function getFontID(font)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Fonts\\'):fmt(AshitaCore:GetInstallPath()));

    for i = 1,#dir,1 do
        if(dir[i] == font) then
            return i;
        end
    end
end

function getMenu()
    local menuBase = ashita.memory.find('FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0);

    local subPointer = ashita.memory.read_uint32(menuBase);
    local subValue = ashita.memory.read_uint32(subPointer);
    if (subValue == 0) then
        return '';
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4);
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16);
    local menuString = string.gsub(string.gsub(string.gsub(menuName, '\x00', ''), 'menu', ''), ' ', '');
    return menuString;
end

function ToBoolean(b)
    if(b == 1)then
        return true;
    else
        return false;
    end
end

function reloadGUI()
    AshitaCore:GetChatManager():QueueCommand(-1, '/addon reload GlamourUI');
end

function loadFont(f, s, p)
    if(p == 'partylist')then
        glamourUI.pListFont = imgui.AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), s);
    elseif(p == 'targetbar')then
        glamourUI.tBarFont = imgui.AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), s);
    elseif(p == 'playerStats')then
        glamourUI.pStatsFont = imgui.AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), s);
    elseif(p == 'alliancePanel')then
        glamourUI.aPanelFont = imgui.AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), s);
    elseif(p == 'invPanel')then
        glamourUI.iPanelFont = imgui.AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), s);
    end
end

function setHPColor(p)
    local hp = getHPP(p);
    if(hp >= 67)then
        imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 1.0, 1.0});
    elseif(hp < 67 and hp >= 50)then
        imgui.PushStyleColor(ImGuiCol_Text, {1.0, 1.0, 0.0, 1.0});
    elseif(hp < 50)then
        imgui.PushStyleColor(ImGuiCol_Text, {1.0, 0.0, 0.0, 1.0});
    end
end

--Function by Tirem.  Modified to apply to GlamourUI
function DrawBuffs(statusIds, iconSize, maxColumns, maxRows)
    if (statusIds ~= nil and #statusIds > 0) then
        local currentRow = 1;
        local currentColumn = 0;

        for i = 0,#statusIds do
            local icon = resources.load_status_icon_from_resource(statusIds[i]);
            if (icon ~= nil) then
                imgui.Image(icon, { iconSize, iconSize }, { 0, 0 }, { 1, 1 });
                currentColumn = currentColumn + 1;
                -- Handle multiple rows
                if (currentColumn < maxColumns) then
                    imgui.SameLine();
                else
                    currentRow = currentRow + 1;
                    if (currentRow > maxRows) then
                        return;
                    end
                    currentColumn = 0;
                end
            end
        end
    end
end

local d3d8_device = d3d8.get_device();

function pokeCache(settings)
-- checks `settings` for a change in theme and invalidates the texture cache if needed
    local theme_key = ('%s_%s_%s_%s_%s'):fmt(
        settings.partylist.theme,
        settings.targetbar.theme,
        settings.alliancePanel.theme,
        settings.alliancePanel2.theme,
        settings.playerStats.theme
    );

    if(cache.theme ~= theme_key) then
        -- theme key changed, invalidate the chache
        cache.theme = theme_key;
        cache.paths = T{};
        cache.textures = T{};
    end
end

function getTexturePath(settings, type, texture)
    local theme = nil;
    if(settings:haskey(type) and settings[type]:haskey('theme')) then
        theme = settings[type].theme;
    end

    if(theme ~= nil) then
        local path = ('%s\\config\\addons\\GlamourUI\\Themes\\%s\\%s'):fmt(AshitaCore:GetInstallPath(), theme, texture)
        if(not cache.paths:haskey(path)) then
            if(ashita.fs.exists(path)) then
                cache.paths[path] = path;
            else
                cache.paths[path] = nil;
            end
        end
        return cache.paths[path];
    end
    return nil;
end

function getTex(settings, type, texture)
    local tex_path = getTexturePath(settings, type, texture);

    if(tex_path ~= nil) then
        if(not cache.textures:haskey(tex_path)) then
            local tex_ptr = ffi.new('IDirect3DTexture8*[1]');
            local cdata = nil;
            if(ffi.C.D3DXCreateTextureFromFileA(d3d8_device, tex_path, tex_ptr) == ffi.C.S_OK) then
                cdata = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', tex_ptr[0]));
            end

            -- this *can be nil*
            cache.textures[tex_path] = cdata;
        end

        if(cache.textures[tex_path] ~= nil) then
            return tonumber(ffi.cast('uint32_t', cache.textures[tex_path]));
        end
    end
    return nil;
end

function renderPlayerThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, targ, plead, lsync, p)
    local element = glamourUI.layout.Priority;
    local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    local targetEntity = GetEntity(target);

    if element[e] == 'name' then
        imgui.SetCursorPosX(glamourUI.layout.NamePosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.NamePosition.y * glamourUI.settings.partylist.gui_scale);
        if(targetEntity ~= nil)then
            if(targetEntity.Name == getName(p))then
                imgui.Image(targ, {25 * glamourUI.settings.partylist.gui_scale, 25 * glamourUI.settings.partylist.gui_scale});
            end
        end
        imgui.SetCursorPosX((glamourUI.layout.NamePosition.x + 27) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.NamePosition.y * glamourUI.settings.partylist.gui_scale);
        if(isPartyLeader(p) == true)then
            imgui.Image(plead, {10 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale});
        end
        imgui.SetCursorPosX((40 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.NamePosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getName(p)));
        if(isLevelSync(p) == true)then
            imgui.SameLine();
            imgui.Image(lsync, {10 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale});
        end

        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {((getHPP(p) / 100) *glamourUI.settings.partylist.hpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale}, { 0, 0 }, { (getHPP(p) / 100), 1 });
        imgui.SetCursorPosX((30 + glamourUI.layout.HPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getHP(p)));
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {((getMPP(p) / 100) * glamourUI.settings.partylist.mpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale}, { 0, 0 }, { (getMPP(p) / 100), 1 });
        imgui.SetCursorPosX((30 + glamourUI.layout.MPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getMP(p)));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(math.clamp((getTP(p) / 1000), 0, 1) *glamourUI.settings.partylist.tpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale}, {0, 0}, {(math.clamp((getTP(p) / 1000), 0, 1)), 1});
        imgui.SetCursorPosX((30 + glamourUI.layout.TPBarPosition.x + 15)* glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getTP(p)));
        return;
    end
end

function renderPlayerBuffs()
    local partyCount = 0;
    for i = 1,6,1 do
        if(AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i-1) > 0) then
            partyCount = partyCount +1;
        end
    end
    if (buffs ~= nil and #buffs > 0)then
        imgui.SetNextWindowPos({glamourUI.partylist.x + partylistW, glamourUI.partylist.y}, ImGuiCond_Always);;
        if(imgui.Begin('Status', glamourUI.is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_AlwaysAutoResize)))then
            local yOffset = p * 40;
            imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
            for i=0,partyCount,1 do
                local p = i - 1;
                local buffs = getBuffs(p, 'buffs');
                imgui.SetCursorPosY(yOffset);
                DrawBuffs(buffs, 25, 6, 2);

            end
            imgui.PopStyleVar();
            imgui.End();
        end
        if(imgui.Begin('Status'))then
            local p = i - 1;
            local debuffs = getBuffs(0, 'debuffs');
            imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {5,1});
            --DrawBuffs(debuffs, 25, 6, 2);
            imgui.PopStyleVar();
            imgui.End();
        end
    end
end

function renderPartyThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, targ, plead, lsync, p)
    local element = glamourUI.layout.Priority;
    local party = AshitaCore:GetMemoryManager():GetParty();
    local partyLeader = party:GetAlliancePartyLeaderServerId1();
    local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    local targetEntity = GetEntity(target);
    local yOffset = (p * 40) + (p * glamourUI.layout.padding);
    if element[e] == 'name' then
        imgui.SetCursorPosX(glamourUI.layout.NamePosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        if(targetEntity ~= nil)then
            if(targetEntity.Name == getName(p))then
                imgui.Image(targ, {25 * glamourUI.settings.partylist.gui_scale, 25 * glamourUI.settings.partylist.gui_scale});
            end
        end
        imgui.SetCursorPosX((glamourUI.layout.NamePosition.x + 27) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        if(partyLeader == party:GetMemberServerId(p))then
            imgui.Image(plead, {10 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale});
        end
        imgui.SetCursorPosX((40 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getName(p)));
        if(isLevelSync(p) == true)then
            imgui.SameLine();
            imgui.Image(lsync, {10 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale});
        end
        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {((getHPP(p) / 100) *glamourUI.settings.partylist.hpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale}, { 0, 0 }, { (getHPP(p) / 100), 1 });
        imgui.SetCursorPosX((30 + glamourUI.layout.HPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getHP(p)));
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {((getMPP(p) / 100) * glamourUI.settings.partylist.mpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale}, { 0, 0 }, { (getMPP(p) / 100), 1 });
        imgui.SetCursorPosX((30 + glamourUI.layout.MPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getMP(p)));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(math.clamp((getTP(p) / 1000), 0, 1) *glamourUI.settings.partylist.tpBarDim.l) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale}, {0, 0}, {(math.clamp((getTP(p) / 1000), 0, 1)), 1});
        imgui.SetCursorPosX((30 + glamourUI.layout.TPBarPosition.x + 15)* glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getTP(p)));
        return;
    end
end

function renderPetThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, targ, p, c)
    local yOffset = (c * 40) + (c * glamourUI.layout.padding);
    local element = glamourUI.layout.Priority;
    local target = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    local targetEntity = GetEntity(target);

    if element[e] == 'name' then
        imgui.SetCursorPosX(glamourUI.layout.NamePosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        if(targetEntity ~= nil)then
            if(targetEntity.Name == p.Name)then
                imgui.Image(targ, {25 * glamourUI.settings.partylist.gui_scale, 25 * glamourUI.settings.partylist.gui_scale});
            end
        end
        imgui.SetCursorPosX((40 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(p.Name);
        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {(glamourUI.settings.partylist.hpBarDim.l * (p.HPPercent / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale}, {0, 0}, {(p.HPPercent / 100), 1});
        imgui.SetCursorPosX((30 + glamourUI.layout.HPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(p.HPPercent) .. '%%');
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {(glamourUI.settings.partylist.mpBarDim.l * (AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale}, {0,0},{(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100),1});
        imgui.SetCursorPosX((30 + glamourUI.layout.MPBarPosition.x + 15) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(30 + glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(glamourUI.settings.partylist.tpBarDim.l * (math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1))), glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale}, {0, 0}, {(math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1)), 1});
        imgui.SetCursorPosX((30 + glamourUI.layout.TPBarPosition.x + 15)* glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP()));
        return;
    end

end

function renderParty(p)
    imgui.Text('');
    imgui.Text(tostring(getName(p)));
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.25, 0.25, 1.0 });
    imgui.ProgressBar(getHPP(p) / 100, { 200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale }, '');
    imgui.PopStyleColor(1);
    imgui.SameLine();
    imgui.SetCursorPosX(27 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getHP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.5, 0.0, 1.0 });
    imgui.ProgressBar(getMPP(p) / 100, { 200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale}, '');
    imgui.PopStyleColor(1);
    imgui.SameLine();
    imgui.SetCursorPosX(242 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getMP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.45, 1.0, 1.0});
    imgui.ProgressBar(getTP(p) / 1000, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale}, '');
    imgui.PopStyleColor(1);
    if(getTP(p) > 1000) then
        imgui.SameLine();
        imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
        imgui.ProgressBar((getTP(p) -1000) /1000, {200 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale}, '');
        imgui.PopStyleColor(1);
    end
    if(getTP(p) > 2000) then
        imgui.SameLine();
        imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
        imgui.ProgressBar((getTP(p) -2000) /1000, {200 * glamourUI.settings.partylist.gui_scale, 4 * glamourUI.settings.partylist.gui_scale}, '');
        imgui.PopStyleColor(1);
    end
    imgui.SameLine();
    imgui.SetCursorPosX(457 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getTP(p)));
end

function renderAllianceMember(a)
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, {1.0, 0.25, 0.25, 1.0});
    imgui.ProgressBar(getHPP(a) / 100, {glamourUI.settings.alliancePanel.hpBarDim.l * glamourUI.settings.alliancePanel.gui_scale, glamourUI.settings.alliancePanel.hpBarDim.g * glamourUI.settings.alliancePanel.gui_scale}, getName(a));
end

function renderAllianceThemed(hpbT, hpfT, a, o)
    imgui.SetCursorPosX(o + 10);
    imgui.Image(hpbT, {glamourUI.settings.alliancePanel.hpBarDim.l * glamourUI.settings.alliancePanel.gui_scale, glamourUI.settings.alliancePanel.hpBarDim.g * glamourUI.settings.alliancePanel.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(o + 10);
    imgui.Image(hpfT, {(glamourUI.settings.alliancePanel.hpBarDim.l * glamourUI.settings.alliancePanel.gui_scale) * (getHPP(a)/100), glamourUI.settings.alliancePanel.hpBarDim.g * glamourUI.settings.alliancePanel.gui_scale}, {0, 0}, { getHPP(a) / 100, 1});
    imgui.SameLine();
    imgui.SetCursorPosX(o + 15);
    imgui.Text(getName(a));
end

function renderPlayerStats(b, f, s, p, o)
        imgui.SetCursorPosX(o + 5);
        imgui.Image(b, {glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale});
        imgui.SameLine();
        imgui.SetCursorPosX(o + 5);
        if(p ~= nil)then
            imgui.Image(f, {(((p / 100) * glamourUI.settings.playerStats.BarDim.l) * glamourUI.settings.playerStats.gui_scale), glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale}, { 0, 0 }, { p / 100, 1 });
        else
            imgui.Image(f, {(math.clamp(s / 1000, 0, 1)) * glamourUI.settings.playerStats.BarDim.l  * (glamourUI.settings.playerStats.gui_scale), glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale}, { 0, 0 }, { math.clamp((s / 1000), 0, 1), 1 });
        end
        imgui.SameLine();
        imgui.SetCursorPosX(o + 10);
        imgui.Text(tostring(s));
end

function renderPlayerNoTheme(o, c, p, pp)
    imgui.SetCursorPosX(o + 5);
    imgui.PushStyleColor(ImGuiCol_PlotHistogram, c);
    if(pp ~= nil) then
        imgui.ProgressBar(pp / 100, { glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale }, '');
    else
        imgui.ProgressBar(p / 1000, {glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale}, '');
        if(p > 1000) then
            imgui.SameLine();
            imgui.SetCursorPosX(o+5);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 0.75, 1.0, 1.0});
            imgui.ProgressBar((p -1000) /1000, {glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.partylist.gui_scale}, '');
            imgui.PopStyleColor(1);
        end
        if(p > 2000) then
            imgui.SameLine();
            imgui.SetCursorPosX(o+5);
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.0, 1.0, 1.0, 1.0});
            imgui.ProgressBar((p -2000) /1000, {glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.partylist.gui_scale}, '');
            imgui.PopStyleColor(1);
        end
    end
    imgui.SameLine();
    imgui.SetCursorPosX(o+5);
    imgui.Text(tostring(p));
end

function renderPartyZone(p, plead)
    local yOffset = (p * 40) + (p * glamourUI.layout.padding);
    local party = AshitaCore:GetMemoryManager():GetParty();
    local partyLeader = party:GetAlliancePartyLeaderServerId1();
    imgui.SetCursorPosX(5+(glamourUI.layout.NamePosition.x * glamourUI.settings.partylist.gui_scale));
    imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
    if(partyLeader == party:GetMemberServerId(p))then
        imgui.Image(plead, {10 * glamourUI.settings.partylist.gui_scale, 10 * glamourUI.settings.partylist.gui_scale});
    end
    imgui.SetCursorPosX((35 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
    imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
    imgui.Text(getName(p));
    imgui.SetCursorPosX(55 * glamourUI.settings.partylist.gui_scale);
    imgui.Text('(|  '..getZone(p)..'  |)');
end

function createLayout(name)
    local path = ('%s\\config\\addons\\GlamourUI\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), name);
    if ashita.fs.exists(path)then
        print(chat.header(('Layout with name: \"%s\" already exists.'):fmt(name)));
        return;
    end

    if (not ashita.fs.exists(('%s\\config\\addons\\GlamourUI\\Layouts\\%s'):fmt(AshitaCore:GetInstallPath(), name))) then
        ashita.fs.create_directory(('%s\\config\\addons\\GlamourUI\\Layouts\\%s'):fmt(AshitaCore:GetInstallPath(), name));
    end

    local file = io.open(path, 'w');
    if(file == nil) then
        print(chat.header(('Error Creating new Layout')));
        return;
    end;
    file:write('local layout = {\n');
    file:write('    Priority = {\n');
    file:write('        \'name\',\n');
    file:write('        \'hp\',\n');
    file:write('        \'mp\',\n');
    file:write('        \'tp\'\n');
    file:write('    },\n');
    file:write('    NamePosition = {\n');
    file:write('        x = 0,\n');
    file:write('        y = 0\n');
    file:write('    },\n');
    file:write('    HPBarPosition = {\n');
    file:write('        x = 25,\n');
    file:write('        y = 20\n');
    file:write('    },\n');
    file:write('    MPBarPosition = {\n');
    file:write('        x = 240,\n');
    file:write('        y = 20\n');
    file:write('    },\n');
    file:write('    TPBarPosition = {\n');
    file:write('        x = 455,\n');
    file:write('        y = 20\n');
    file:write('    },\n')
    file:write('    padding = 0')
    file:write('};\n')
    file:write('return layout;')
    file:close();
end

function updateLayoutFile(name)
    local path = ('%s\\config\\addons\\GlamourUI\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), name);

    local file = io.open(path, 'w+');
    if(file == nil) then
        print(chat.header(('Error Creating new Layout')));
        return;
    end;
    file:write('local layout = {\n');
    file:write('    Priority = {\n');
    file:write('        \'name\',\n');
    file:write('        \'hp\',\n');
    file:write('        \'mp\',\n');
    file:write('        \'tp\'\n');
    file:write('    },\n');
    file:write('    NamePosition = {\n');
    file:write(('        x = %s,\n'):fmt(glamourUI.layout.NamePosition.x));
    file:write(('        y = %s\n'):fmt(glamourUI.layout.NamePosition.y));
    file:write('    },\n');
    file:write('    HPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(glamourUI.layout.HPBarPosition.x));
    file:write(('        y = %s\n'):fmt(glamourUI.layout.HPBarPosition.y));
    file:write('    },\n');
    file:write('    MPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(glamourUI.layout.MPBarPosition.x));
    file:write(('        y = %s\n'):fmt(glamourUI.layout.MPBarPosition.y));
    file:write('    },\n');
    file:write('    TPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(glamourUI.layout.TPBarPosition.x));
    file:write(('        y = %s\n'):fmt(glamourUI.layout.TPBarPosition.y));
    file:write('    },\n')
    file:write(('    padding = %s'):fmt(glamourUI.layout.padding));
    file:write('};\n')
    file:write('return layout;')
    file:close();
end

function LoadFile(filePath)
    if not ashita.fs.exists(filePath) then
        return nil;
    end

    local success, loadError = loadfile(filePath);
    if not success then
        print(string.format('Failed to load resource file: %s', filePath));
        print(string.format('Error: %s', loadError));
        return nil;
    end

    local result, output = pcall(success);
    if not result then
        print(string.format('Failed to call resource file: %s', filePath));
        print(string.format('Error: %s', loadError));
        return nil;
    end

    return output;
end

function loadLayout(name)
    local path = (('%s\\config\\addons\\GlamourUI\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), name));
    glamourUI.layout = LoadFile(path);
    print(chat.header(path));
end

function setscale(a,v)
    if(a == 'partylist')then
        glamourUI.settings.partylist.gui_scale = v + 0.0;
    end
    if(a == 'targetbar') then
        glamourUI.settings.targetbar.gui_scale = v + 0.0;
    end
end

function makeChat(e)
    local newline = AshitaCore:GetChatManager():ParseAutoTranslate(e.message, true);
    if(table.getn(chatTable) <= 10000)then
        table.insert(chatTable, newline);
        chatScroll = true;
    else
        table.remove(chatTable, 1);
        table.insert(chatTable, newline);
        chatScroll = true;
    end

end