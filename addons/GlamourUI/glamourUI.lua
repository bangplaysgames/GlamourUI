--[[
---MIT License---
Copyright 2022 Banggugyangu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--


addon.name = 'GlamourUI';
addon.author = 'Banggugyangu';
addon.desc = "A modular and customizable interface for FFXI";
addon.version = '1.1.5';

local settings = require('settings');

--Global Module Definitions
gParty = require('party');
gTarget = require('target');
gInv = require('inventory');
gRecast = require('recast');
gPacket = require('packethandler');
gHelper = require('helpers');
gConf = require('conf');
gUI = require('render');
gResources = require('resources');
gCBar = require('cbar');
gHide = require('hideDefault');

local imgui = require('imgui');
local chat = require('chat');

local render_debug = function()
    local party = gParty.GetParty();

    if(GlamourUI.debug == true)then
        if(imgui.Begin('Debug##GlamDebug', GlamourUI.debug, ImGuiWindow_AlwaysAutoResize))then
            imgui.Text(tostring(gParty.GroupHeight1.x .. 'x' .. gParty.GroupHeight1.y));
            imgui.Text(tostring(gParty.GroupHeight2.x .. 'x' .. gParty.GroupHeight2.y));
        end
    end
end

local default_settings = T{
    Party = T{
        pList = T{
            hp1Color = {1.0, 1.0, 1.0, 1.0},
            hp2Color = {1.0, 1.0, 0.0, 1.0},
            hp3Color = {1.0, 0.0, 0.0, 1.0},
            enabled = true,
            hideDefault = true,
            font_scale = 1,
            gui_scale = 1,
            buff_scale = 1,
            buffTheme = 'Default',
            layout = 'Default',
            theme = 'Default',
            themed = true,
            x = 12,
            y = 150
        },
        aPanel = T{
            enabled = true,
            font_scale = 1,
            gui_scale = 1,
            theme = 'Default',
            themed = true,
            x1 = 12,
            y1 = 700,
            hpBarDim = T{
                l = 200,
                g = 16
            }
        }
    },
    Inv = T{
        enabled = true,
        theme = 'Default',
        font_scale = 1,
    },
    TargetBar = T{
        enabled = true,
        theme = 'Default',
        themed = true,
        gui_scale = 1,
        font_scale = 1,
        x = 1000,
        y = 150,
        hpBarDim = T{
            l = 600,
            g = 16
        }
    },
    PlayerStats = T{
        enabled = true,
        theme = 'Default',
        themed = true,
        gui_scale = 1,
        font_scale = 1,
        x = 600,
        y = 800,
        BarDim = T{
            l = 200,
            g = 16
        },
    },
    rcPanel = T{
        enabled = true,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        font_scale = 1
    },
    cBar = {
        enabled = true,
        themed = true,
        theme = 'Default',
        gui_scale = 1,
        font_scale = 1,
        BarDim = {
            l = 400,
            g = 12
        },
        x = 1500,
        y = 850
    },
    font = 'SpicyTaste.ttf'
}

GlamourUI = T{
    firstLoad = true,
    settings = settings.load(default_settings),
    font = nil,
    debug = true
}

local loaded = false;

settings.register('settings', 'settings_update', function(s)
    if (s ~= nil) then
        GlamourUI.settings = s;
    end
    settings.save();
end)

ashita.events.register('load', 'load_cb', function()
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts'):fmt(AshitaCore:GetInstallPath(), addon.name)))then
        ashita.fs.create_directory(('%s\\config\\addons\\%s\\Layouts'):fmt(AshitaCore:GetInstallPath(), addon.name));
        print(chat.header('Creating Layout Directory'));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath(), addon.name)))then
        ashita.fs.create_directory(('%s\\config\\addons\\%s\\Layouts\\Default'):fmt(AshitaCore:GetInstallPath(), addon.name));
    end
    if(not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts\\Default\\layout.lua'):fmt(AshitaCore:GetInstallPath(), addon.name))) then
        gHelper.createLayout('Default');
        print(chat.header('Creating Default Layout'));
    end
    gPartyBuffs = gResources.ReadPartyBuffsFromMemory();
    gHide.Load();
end)

ashita.events.register('d3d_present', 'present_cb', function()
    local playerSID = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    local player = GetPlayerEntity();
    local pet = nil;
    if(player ~= nil)then
        pet = GetEntity(player.PetTargetIndex);
    end

    gParty.Party = gParty.GetParty();

    if(GlamourUI.firstLoad == true and playerSID ~= 0)then
        GlamourUI.firstLoad = false;
        print(chat.header('GlamourUI Loading...'));
        coroutine.sleep(3);
        GlamourUI.settings = settings.load(default_settings);
        gHelper.loadLayout(GlamourUI.settings.Party.pList.layout);
        gResources.loadFont(GlamourUI.settings.font);
        coroutine.sleep(1);
        loaded = true;
    end
    if(playerSID ~= 0 and player ~= nil and loaded == true)then
        imgui.PushFont(GlamourUI.font);
        gInv.render_inv_panel();
        gHide.HideParty(GlamourUI.settings.Party.pList.hideDefault);
        if(not gHelper.is_event(0))then
            gUI.renderRecast();
            gParty.render_party_list();
            gUI.RenderTargetBar();
            gParty.render_alliance_panel();
            gParty.render_player_stats();
            gUI.render_invite();
            gConf.render_config();
            gUI.renderCastBar();
            if(gHelper.getMenu() == 'loot')then
                --gUI.renderLot();
            end
        end
        --render_debug();
        imgui.PopFont();
        if(gRecast.PetDeg.time > 0 and pet ~= nil)then
            if((gRecast.PetDeg.time <= gRecast.PetDeg.endtime) and gRecast.PetDeg.endtime > 0)then
                gRecast.calcPetDeg(pet.Name);
            else
                gRecast.PetDeg.time = 0;
                gRecast.PetDeg.endtime = 0;
            end
        elseif(pet == nil)then
            gRecast.PetDeg.max = 0;
            gRecast.PetDeg.time = 0;
            gRecast.PetDeg.endtime = 0;
        end
    end

end)

ashita.events.register('unload', 'unload_cb', function()
    settings.save();
end)

ashita.events.register('text_in', 'text_in_cb', function(e)

end)

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    --Party Buff Update
    if (e.id == 0x076) then
        gPartyBuffs = gResources.ReadPartyBuffsFromPacket(e);
    end

    gPacket.HandleIncoming(e);

    --Party Update
    if(e.id == 0x0DD) then
        gParty.Party = gParty.GetParty();
    end
end)

ashita.events.register('packet_out', 'packet_out_cb', function(e)
    gPacket.HandleOutgoing(e);
end)

ashita.events.register('command', 'command_cb', function (e)
    --Parse Arguments
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/glam')) then
        if((args[1] == '/join' or args[1] == '/decline'))then
            gPacket.InviteActive = false;
        end
        return;
    end

    --Block all related commands
    e.blocked = true;

    --Show Help
    if(args[1]:any('/glam') and (#args ==1 or args[2]:any('help'))) then
        print(chat.header('Glamour UI Commands:'));
        print(chat.message('/glam - Show this help text'))
        print(chat.message('/glam config - Opens the Configuration window'));
        print(chat.message('/glam newlayout layoutname - Creates a new layout with name: layoutname'))
    end
    --Handle Command
    if(#args > 1) then
        if (args[2] == 'config') then
            gConf.is_open = not gConf.is_open;
        end
        if (args[2] == 'newlayout') then
            if(args[3] ~= nil)then
                gHelper.createLayout(args[3]);
            end
        end
    end



end)