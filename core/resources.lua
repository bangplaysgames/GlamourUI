--This file is comprised of functions pulled from StatusTimers by Heals/Shirk

local d3d8 = require('d3d8');
local ffi = require('ffi');
local chat = require('chat');
local compat = require('compat');
local imgui = require('imgui');
local gBuffs = require('buffTable');
local font_manager = require('font_manager');

local d3d8_device = d3d8.get_device();

local cache = T{
    theme = T{},
    paths = T{},
    textures = T{}
};

local icon_cache = T{

};

local item_icon_cache = T{

};

local buffIcon;
local debuffIcon;

local jobIcons = T{};

local id_overrides = T{

};

local INFINITE_DURATION = 0x7FFFFFFF;
local player_utcstamp_ptr = nil;

local function ensure_player_utcstamp_ptr()
    if (player_utcstamp_ptr ~= nil) then
        return player_utcstamp_ptr ~= 0;
    end

    local found = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????8B410C8B49108D04808D04808D04808D04C1C3', 2, 0);
    player_utcstamp_ptr = (found ~= nil and found ~= 0) and found or 0;
    return player_utcstamp_ptr ~= 0;
end

local function get_game_utcstamp()
    if (ensure_player_utcstamp_ptr() ~= true) then
        return INFINITE_DURATION;
    end

    local ptr = player_utcstamp_ptr;
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    return ashita.memory.read_uint32(ptr + 0x0C);
end

local function buff_duration_seconds(raw_duration)
    if (raw_duration == nil) then
        return nil;
    end

    if (raw_duration == INFINITE_DURATION) then
        return -1;
    end

    local vana_base_stamp = 0x3C307D70;
    local offset = get_game_utcstamp() - vana_base_stamp;
    local comparand = offset * 60;
    local real_duration = raw_duration - comparand;

    while (real_duration < -2147483648) do
        real_duration = real_duration + 0xFFFFFFFF;
    end

    if (real_duration < 1) then
        return 0;
    end

    return math.ceil(real_duration / 60);
end

local resources = {}

resources.fontBaseSize = 45;
resources.loaded_fonts = {};
resources.default_font_name = nil;

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
        icon_path = ('%s\\config\\addons\\GlamourUI\\icons\\%s\\%d'):append(ext):fmt(AshitaCore:GetInstallPath(), theme, status_id);
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
    item_icon_cache = T{};
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

resources.load_item_icon_from_resource = function (item)
    if (item == nil or item.Bitmap == nil) then
        return load_dummy_icon();
    end
    local size = -1;
    if (ashita.interface_version == nil) then
        size = item.ImageSize;
        if (size == nil or size <= 0) then
            return load_dummy_icon();
        end
    end

    local function decode_item_bitmap(sz)
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        if (ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d8_device, item.Bitmap, sz, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
        return nil;
    end

    local tex = decode_item_bitmap(size);
    if (tex == nil and size == -1 and item.ImageSize ~= nil and item.ImageSize > 0) then
        tex = decode_item_bitmap(item.ImageSize);
    end
    if (tex ~= nil) then
        return tex;
    end

    return load_dummy_icon();
end

resources.get_item_icon = function(itemId, item)
    if (not item_icon_cache:haskey(itemId)) then
        local tex_ptr = resources.load_item_icon_from_resource(item);
        if (tex_ptr == nil) then
            return nil;
        end
        item_icon_cache[itemId] = tex_ptr;
    end
    return tonumber(ffi.cast('uint32_t', item_icon_cache[itemId]));
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

resources.get_player_buff_timer_seconds_split = function()
    local buffSecs = T{};
    local debuffSecs = T{};

    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil or is_player_valid() ~= true) then
        return buffSecs, debuffSecs;
    end

    if (player.GetBuffs == nil or player.GetStatusTimers == nil) then
        return buffSecs, debuffSecs;
    end

    local icons = player:GetBuffs();
    local timers = player:GetStatusTimers();
    if (icons == nil or timers == nil) then
        return buffSecs, debuffSecs;
    end

    for j = 0, 31 do
        local id = icons[j + 1];
        if (id ~= nil and id ~= 255 and id > 0) then
            local secs = buff_duration_seconds(timers[j + 1]);
            if (gBuffs.IsBuff(id) == true) then
                buffSecs[#buffSecs + 1] = secs;
            else
                debuffSecs[#debuffSecs + 1] = secs;
            end
        end
    end

    return buffSecs, debuffSecs;
end

local function get_glyph_merge_font_candidates()
    local candidates = {
        'C:\\Windows\\Fonts\\seguisym.ttf',
        'C:\\Windows\\Fonts\\arial.ttf',
        'C:\\Windows\\Fonts\\DejaVuSans.ttf',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        '/Library/Fonts/Arial.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/TTF/DejaVuSans.ttf',
    };
    return candidates;
end

local function merge_font_glyphs(fontSize, codepoints)
    if (ImFontConfig == nil or codepoints == nil or #codepoints == 0) then
        return false;
    end

    local mergeCandidates = get_glyph_merge_font_candidates();
    local ok = false;

    for c = 1, #mergeCandidates do
        local mergePath = mergeCandidates[c];
        if (ashita.fs.exists(mergePath)) then
            local mergeOk = pcall(function()
                local rangeCount = (#codepoints * 2) + 1;
                local ranges = ffi.new('uint16_t[?]', rangeCount);
                for i = 1, #codepoints do
                    local cp = codepoints[i];
                    ranges[(i - 1) * 2] = cp;
                    ranges[(i - 1) * 2 + 1] = cp;
                end
                ranges[rangeCount - 1] = 0;
                local cfg = ImFontConfig();
                cfg.MergeMode = true;
                cfg.PixelSnapH = true;
                imgui.AddFontFromFileTTF(mergePath, fontSize, cfg, ranges);
            end);
            if (mergeOk == true) then
                ok = true;
                break;
            end
        end
    end

    return ok;
end

local function merge_gob_star_glyph(fontSize)
    return merge_font_glyphs(fontSize, { 0x2605, 0x2606 });
end

local function merge_backslash_glyph(fontSize)
    -- Many JP/CJK fonts draw U+005C as yen; merge an ASCII backslash glyph.
    return merge_font_glyphs(fontSize, { 0x005C });
end

resources.resolve_font_name = function(fontName)
    if (fontName ~= nil and fontName ~= '') then
        return fontName;
    end
    if (GlamourUI ~= nil and GlamourUI.settings ~= nil and GlamourUI.settings.font ~= nil and GlamourUI.settings.font ~= '') then
        return GlamourUI.settings.font;
    end
    return resources.default_font_name;
end

resources.get_font = function(fontName)
    local name = resources.resolve_font_name(fontName);
    if (name == nil or name == '') then
        return nil;
    end

    local cached = resources.loaded_fonts[name];
    if (cached ~= nil) then
        return cached;
    end

    local path = font_manager.get_font_path(name);
    if (path == nil or ashita.fs.exists(path) ~= true) then
        return nil;
    end

    local fontSize = resources.fontBaseSize;
    local font = imgui.AddFontFromFileTTF(path, fontSize);
    if (font == nil) then
        return nil;
    end

    local starMerged = merge_gob_star_glyph(fontSize);
    merge_backslash_glyph(fontSize);
    if (GlamourUI ~= nil) then
        GlamourUI.starGlyphMerged = starMerged;
    end
    resources.loaded_fonts[name] = font;
    return font;
end

resources.loadFont = function(f)
    resources.default_font_name = f;
    GlamourUI.font = resources.get_font(f);
end

resources.reload_font = function(fontName)
    if (fontName == nil or fontName == '') then
        return;
    end
    resources.loaded_fonts[fontName] = nil;
    resources.get_font(fontName);
    if (resources.resolve_font_name(fontName) == resources.resolve_font_name(nil)) then
        GlamourUI.font = resources.get_font(fontName);
    end
end

local function add_font_name_to_set(set, fontName)
    if (fontName ~= nil and fontName ~= '') then
        set[fontName] = true;
    end
end

-- Codepoints FFXI chat commonly needs after CP932 decode.
local SHIFT_JIS_PROBE_CODEPOINTS = {
    0x0041,
    0x3042,
    0x30A2,
    0x65E5,
    0x3000,
    0xFF0F,
};

local function font_name_suggests_shift_jis(fontName)
    if (fontName == nil or fontName == '') then
        return false;
    end
    local n = fontName:lower();
    return n:find('kosugi', 1, true) ~= nil
        or n:find('maru', 1, true) ~= nil
        or n:find('fff', 1, true) ~= nil
        or n:find('tusj', 1, true) ~= nil
        or n:find('spicy', 1, true) ~= nil
        or n:find('strawberry', 1, true) ~= nil
        or n:find('mystic', 1, true) ~= nil
        or n:find('mincho', 1, true) ~= nil
        or n:find('gothic', 1, true) ~= nil
        or n:find('notosanscjk', 1, true) ~= nil
        or n:find('msgothic', 1, true) ~= nil
        or n:find('cjk', 1, true) ~= nil;
end

resources.font_supports_shift_jis = function(fontName)
    if (fontName == nil or fontName == '') then
        return false;
    end

    if (font_manager.supports_shift_jis(fontName)) then
        return true;
    end

    local font = resources.get_font(fontName);
    if (font ~= nil and font.IsGlyphInFont ~= nil) then
        local glyphOk = true;
        for i = 1, #SHIFT_JIS_PROBE_CODEPOINTS do
            if (font:IsGlyphInFont(SHIFT_JIS_PROBE_CODEPOINTS[i]) ~= true) then
                glyphOk = false;
                break;
            end
        end
        if (glyphOk) then
            return true;
        end
    end

    return font_name_suggests_shift_jis(fontName);
end

resources.update_shift_jis_font_list = function()
    font_manager.shift_jis_font_names = T{};
    local names = font_manager.get_all_font_names();
    for i = 1, #names do
        local name = names[i];
        if (resources.font_supports_shift_jis(name)) then
            font_manager.shift_jis_font_names[#font_manager.shift_jis_font_names + 1] = name;
            local meta = font_manager.get_meta(name);
            if (meta ~= nil) then
                meta.supports_shift_jis = true;
            end
        end
    end
    table.sort(font_manager.shift_jis_font_names);
end

resources.preload_configured_fonts = function(settings)
    if (settings == nil) then
        return;
    end

    local names = {};
    add_font_name_to_set(names, settings.font);
    if (settings.Party ~= nil) then
        if (settings.Party.pList ~= nil) then add_font_name_to_set(names, settings.Party.pList.font); end
        if (settings.Party.aPanel ~= nil) then add_font_name_to_set(names, settings.Party.aPanel.font); end
    end
    add_font_name_to_set(names, settings.TargetBar and settings.TargetBar.font);
    add_font_name_to_set(names, settings.PlayerStats and settings.PlayerStats.font);
    add_font_name_to_set(names, settings.Inv and settings.Inv.font);
    add_font_name_to_set(names, settings.rcPanel and settings.rcPanel.font);
    add_font_name_to_set(names, settings.cBar and settings.cBar.font);
    add_font_name_to_set(names, settings.Compass and settings.Compass.font);
    add_font_name_to_set(names, settings.Env and settings.Env.font);

    local chat = settings.Chat;
    if (chat ~= nil) then
        add_font_name_to_set(names, chat.font);
        if (chat.window1 ~= nil) then add_font_name_to_set(names, chat.window1.font); end
        if (chat.window2 ~= nil) then add_font_name_to_set(names, chat.window2.font); end
    end

    for fontName, _ in pairs(names) do
        resources.get_font(fontName);
    end
end

resources.push_font_scale = function(scale, fontOrSettings)
    local fontName = nil;
    if (type(fontOrSettings) == 'table') then
        fontName = fontOrSettings.font;
    elseif (type(fontOrSettings) == 'string') then
        fontName = fontOrSettings;
    end

    local font = resources.get_font(fontName);
    if (font == nil) then
        return false;
    end

    local fontSize = math.max(resources.fontBaseSize * (tonumber(scale) or 1), 1);
    imgui.PushFont(font, fontSize);
    return true;
end

resources.pop_font = function(isPushed)
    if(isPushed)then
        imgui.PopFont();
    end
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
        [0] = { Type = 'Clear', Count = 0 },
        [1] = { Type = 'Sunshine', Count = 0 },
        [2] = { Type = 'Clouds', Count = 0 },
        [3] = { Type = 'Fog', Count = 0 },
        [4] = { Type = 'Fire', Count = 1 },
        [5] = { Type = 'Fire', Count = 2 },    --Fire x2
        [6] = { Type = 'Water', Count = 1 },  --Water x1
        [7] = { Type = 'Water', Count = 2 },
        [8] = { Type = 'Earth', Count = 1 }, --Earth x1
        [9] = { Type = 'Earth', Count = 2 },
        [10] = { Type = 'Wind', Count = 1 }, --Wind x1
        [11] = { Type = 'Wind', Count = 2 },
        [12] = { Type = 'Ice', Count = 1 },  --Ice
        [13] = { Type = 'Ice', Count = 2 },  --Ice x2
        [14] = { Type = 'Thunder', Count = 1 }, --Thunder x1
        [15] = { Type = 'Thunder', Count = 2 },
        [16] = { Type = 'Light', Count = 1 },
        [17] = { Type = 'Light', Count = 2 }, --Light x2
        [18] = { Type = 'Dark', Count = 1 }, --Dark
        [19] = { Type = 'Dark', Count = 2 }, --Dark x2
    }

    local weather = tWeather[e];

    if(e >= 4)then
        weather.Type = gResources.getTex(GlamourUI.settings, 'Env', (tWeather[e].Type .. '.png'));
        return weather;
    else
        return weather;
    end
end

return resources;
