--This file is comprised of functions pulled from StatusTimers by Heals/Shirk

local d3d8 = require('d3d8');
local ffi = require('ffi');
local chat = require('chat');
local compat = require('compat');
local imgui = require('imgui');

local d3d8_device = d3d8.get_device();

local cache = T{
    theme = T{},
    paths = T{},
    textures = T{}
};

local icon_cache = T{

};

local buffIcon;
local debuffIcon;

local jobIcons = T{};

local id_overrides = T{

};

local resources = {}

local function load_dummy_icon()
    local icon_path = ('%s\\addons\\%s\\ladybug.png'):fmt(AshitaCore:GetInstallPath(), 'GlamourUI');
    local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');

    if(ffi.C.D3DXCreateTextureFromFileA(d3d8_device, icon_path, dx_texture_ptr) == ffi.C.S_OK) then
        return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
    end

    return nil;
end

local function valid_server_id(server_id)
    -- TODO: test with (server_id & 0x0x1000000) == 0, anything below is not an NPC
    return server_id > 0 and server_id < 0x4000000;
end

local function is_player_valid()
    if (AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) ~= 0) then
        return AshitaCore:GetMemoryManager():GetPlayer():GetIsZoning() == 0;
    end
    return false;
end



local function load_status_icon_from_theme(theme, status_id)
    if (status_id == nil or status_id < 0 or status_id > 0x3FF) then
        return nil;
    end

    local icon_path;
    local supports_alpha = false;
    T{'.png', '.jpg','.jpeg', '.bmp'}:forieach(function(ext, _)
        if(icon_path ~= nil) then
            return;
        end
        supports_alpha = ext == '.png';
        icon_path = ('%s\\resources\\GlamourUI\\%s\\%d'):append(ext):fmt(AshitaCore:GetInstallPath(), theme, status_id);
        local handle = io.open(icon_path, 'r');
        if(handle ~= nil) then
            handle.close();
        else
            icon_path = nil;
        end
    end );
    if(icon_path == nil) then
        return gResources.load_status_icon_from_resource(status_id);
    end

    local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (supports_alpha) then
        if(ffi.C.D3DXCreateTextureFromFileA(d3d8_device, icon_path, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    else
        if (ffi.C.D3DXCreateTextureFromFileExA(d3d8_device, icon_path, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    end
    return load_dummy_icon();
end


resources.pokeCache = function(settings)
    local theme_key = ('%s_%s_%s_%s'):fmt(
            settings.Party.pList.theme,
            settings.TargetBar.theme,
            settings.Party.aPanel.theme,
            settings.PlayerStats.theme
    );

    if(cache.theme ~= theme_key) then
        -- theme key changed, invalidate the cache
        cache.theme = theme_key;
        cache.paths = T{};
        cache.textures = T{};
    end
end

resources.getTexturePath = function(settings, type, texture)
    local theme;
    if(settings:haskey(type) and settings[type]:haskey('theme')) then
        theme = settings[type].theme;
    end

    if(theme ~= nil) then
        local path = ('%s\\config\\addons\\%s\\Themes\\%s\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, theme, texture)
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

resources.getTex = function(settings, type, texture)
    local tex_path = gResources.getTexturePath(settings, type, texture);

    if(tex_path ~= nil) then
        if(not cache.textures:haskey(tex_path)) then
            local tex_ptr = ffi.new('IDirect3DTexture8*[1]');
            local cdata;
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

resources.get_icon_image = function(status_id)
    if(not icon_cache:haskey(status_id)) then
        local tex_ptr = gResources.load_status_icon_from_resource(status_id);
        if(tex_ptr == nil) then
            return nil;
        end
        return tonumber(ffi.cast("uint32_t", icon_cache[status_id]));
    end
end

resources.get_icon_from_theme = function(theme, status_id)
    if(not icon_cache:haskey(status_id)) then
        local tex_ptr = load_status_icon_from_theme(theme, status_id);
        if(tex_ptr == nil)then
            return nil;
        end
        icon_cache[status_id] = tex_ptr;
    end
    return tonumber(ffi.cast("uint32_t", icon_cache[status_id]));
end

resources.get_theme_index = function(theme)
    local paths = module.get_theme_paths();
    for i = 1,#paths,1 do
        if(paths[i] == theme)then
            return i;
        end
    end
end

resources.clear_cache = function()
    icon_cache = T{};
    buffIcon = nil;
    debuffIcon = nil;
    jobIcons = T{};
end

resources.load_status_icon_from_resource = function (status_id)
    if (status_id == nil or status_id < 0 or status_id > 0x3FF) then
        return nil;
    end

    local id_key = ("_%d"):fmt(status_id);
    if (id_overrides:haskey(id_key)) then
        status_id = id_overrides[id_key];
    end

    local icon = AshitaCore:GetResourceManager():GetStatusIconByIndex(status_id);
    if (icon ~= nil) then
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        if (ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d8_device, icon.Bitmap, compat.icon_size(icon), 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    end
    return load_dummy_icon();
end

resources.get_member_status = function(server_id, p)
    local party = AshitaCore:GetMemoryManager():GetParty();
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local BuffTable = {}
    if(party == nil or not valid_server_id(server_id))then
        return nil;
    end
    --Check if Player
    if (server_id == party:GetMemberServerId(0)) then
        if (player == nil or is_player_valid() == false) then
            return nil;
        end

        local icons = player:GetBuffs();

        for j = 0,31,1 do
            if (icons[j + 1] ~= 255 and icons[j + 1] > 0) then
                table.insert(BuffTable, icons[j+1]);
            end
        end

        if #BuffTable > 0 then
            return BuffTable;
        end
        return nil;
    elseif(server_id == party:GetMemberServerId(p))then
        return gPartyBuffs[server_id];
    end
    return nil;
end

resources.ReadPartyBuffsFromMemory = function()
    local ptrPartyBuffs = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('party.statusicons'));
    local partyBuffTable = {};
    for memberIndex = 0,4 do
        local memberPtr = ptrPartyBuffs + (0x30 * memberIndex);
        local playerId = ashita.memory.read_uint32(memberPtr);
        if (playerId ~= 0) then
            local buffs = {};
            local empty = false;
            for buffIndex = 0,31 do
                if empty then
                    buffs[buffIndex + 1] = -1;
                else
                    local highBits = ashita.memory.read_uint8(memberPtr + 8 + (math.floor(buffIndex / 4)));
                    local fMod = math.fmod(buffIndex, 4) * 2;
                    highBits = bit.lshift(bit.band(bit.rshift(highBits, fMod), 0x03), 8);
                    local lowBits = ashita.memory.read_uint8(memberPtr + 16 + buffIndex);
                    local buff = highBits + lowBits;
                    if buff == 255 then
                        empty = true;
                        buffs[buffIndex + 1] = -1;
                    else
                        buffs[buffIndex + 1] = buff;
                    end
                end
            end
            partyBuffTable[playerId] = buffs;
        end
    end
    return partyBuffTable;
end

resources.ReadPartyBuffsFromPacket = function(e)
    local partyBuffTable = {};
    for i = 0,4 do
        local memberOffset = 0x04 + (0x30 * i) + 1;
        local memberId = struct.unpack('L', e.data, memberOffset);
        if memberId > 0 then
            local buffs = {};
            local empty = false;
            for j = 0,31 do
                if empty then
                    buffs[j + 1] = -1;
                else
                    --This is at offset 8 from member start.. memberoffset is using +1 for the lua struct.unpacks
                    local highBits = bit.lshift(ashita.bits.unpack_be(e.data_raw, memberOffset + 7, j * 2, 2), 8);
                    local lowBits = struct.unpack('B', e.data, memberOffset + 0x10 + j);
                    local buff = highBits + lowBits;
                    if (buff == 255) then
                        buffs[j + 1] = -1;
                        empty = true;
                    else
                        buffs[j + 1] = buff;
                    end
                end
            end
            partyBuffTable[memberId] = buffs;
        end
    end
    return partyBuffTable;
end

resources.loadFont = function(f)
    GlamourUI.font = imgui.AddFontFromFileTTF(('%s\\config\\addons\\%s\\Fonts\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, f), 45);
end

resources.GetJobIcon = function()

end

resources.GetDayIcon = function(e)
    local tDay = {
        [1] = 'Fire',
        [2] = 'Earth',
        [3] = 'Water',
        [4] = 'Wind',
        [5] = 'Ice',
        [6] = 'Thunder',
        [7] = 'Light',
        [8] = 'Dark'
    }
    return gResources.getTex(GlamourUI.settings, 'Env', (tDay[e] .. '.png'));
end

resources.GetWeatherIcon = function(e)
    local tWeather = {
        [1] = 'Clear',
        [2] = 'Sunshine',
        [3] = 'Clouds',
        [4] = 'Fog',
        [5] = 'Fire',
        [6] = 'Fire',
        [7] = 'Water',
        [8] = 'Water',
        [9] = 'Earth',
        [10] = 'Earth',
        [11] = 'Wind',
        [12] = 'Wind',
        [13] = 'Ice',
        [14] = 'Ice',
        [15] = 'Thunder',
        [16] = 'Thunder',
        [17] = 'Light',
        [18] = 'Light',
        [19] = 'Dark',
        [20] = 'Dark'
    }
    local count = 0;
    local wbase = e - 4;
    if(wbase > 0)then
        if(wbase % 2 == 0)then
            count = 2;
        else
            count = 1;
        end
    end
    if(e >= 5)then
        return gResources.getTex(GlamourUI.settings, 'Env', (tWeather[e] .. '.png')), count;
    else
        return tWeather[e], 0;
    end
end

return resources;