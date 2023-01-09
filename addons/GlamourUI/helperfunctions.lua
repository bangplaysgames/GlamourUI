local ffi = require('ffi')
local d3d8 = require('d3d8')
local imgui = require('imgui')
require('common')
local chat = require('chat')

local cache = T{
    theme = nil,
    paths = T{},
    textures = T{}
};

function IsTargetLocked()
    return (bit.band(AshitaCore:GetMemoryManager():GetTarget():GetLockedOnFlags(), 1) == 1);
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

function loadFont(f)
    glamourUI.font = imgui.lua_imgui_AddFontFromFileTTF(('%s\\config\\addons\\GlamourUI\\Fonts\\%s\\font.ttf'):fmt(AshitaCore:GetInstallPath(), f), 16.0);
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

function renderPlayerThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p)
    local element = glamourUI.layout.Priority;
    if element[e] == 'name' then
        imgui.SetCursorPosX((5 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.NamePosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getName(p)));
        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {(glamourUI.settings.partylist.hpBarDim.l * (getHPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.HPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.HPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getHP(p)));
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {(glamourUI.settings.partylist.mpBarDim.l * (getMPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.MPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.MPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getMP(p)));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(glamourUI.settings.partylist.tpBarDim.l * (math.clamp((getTP(p) / 1000), 0, 1) * glamourUI.settings.partylist.gui_scale)), glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.TPBarPosition.x + 2)* glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY(glamourUI.layout.TPBarPosition.y * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getTP(p)));
        return;
    end
end

function renderPartyThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p)
    local element = glamourUI.layout.Priority;
    local yOffset = (p * 40) + (p * glamourUI.layout.padding);
    if element[e] == 'name' then
        imgui.SetCursorPosX((5 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getName(p)));
        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {(glamourUI.settings.partylist.hpBarDim.l * (getHPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.HPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getHP(p)));
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {(glamourUI.settings.partylist.mpBarDim.l * (getMPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.MPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getMP(p)));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(glamourUI.settings.partylist.tpBarDim.l * (math.clamp((getTP(p) / 1000), 0, 1) * glamourUI.settings.partylist.gui_scale)), glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.TPBarPosition.x + 2)* glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(getTP(p)));
        return;
    end
end

function renderPetThemed(e, hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p, c)
    local yOffset = (c * 40) + (c * glamourUI.layout.padding);
    local element = glamourUI.layout.Priority;

    if element[e] == 'name' then
        imgui.SetCursorPosX((5 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(p.Name);
        return;
    end
    if element[e] == 'hp' then
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpbT, {glamourUI.settings.partylist.hpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.HPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(hpfT, {(glamourUI.settings.partylist.hpBarDim.l * (p.HPPercent / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.hpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.HPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.HPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(p.HPPercent));
        return;
    end
    if element[e] == 'mp' then
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpbT, {glamourUI.settings.partylist.mpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.MPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(mpfT, {(glamourUI.settings.partylist.mpBarDim.l * (AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100)) * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.mpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.MPBarPosition.x + 2) * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.MPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()));
        return;
    end
    if element[e] == 'tp' then
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpbT, {glamourUI.settings.partylist.tpBarDim.l * glamourUI.settings.partylist.gui_scale, glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX(glamourUI.layout.TPBarPosition.x * glamourUI.settings.partylist.gui_scale);
        imgui.SetCursorPosY((yOffset + glamourUI.layout.TPBarPosition.y) * glamourUI.settings.partylist.gui_scale);
        imgui.Image(tpfT, {(glamourUI.settings.partylist.tpBarDim.l * (math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1))), glamourUI.settings.partylist.tpBarDim.g * glamourUI.settings.partylist.gui_scale});
        imgui.SetCursorPosX((glamourUI.layout.TPBarPosition.x + 2)* glamourUI.settings.partylist.gui_scale);
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
    imgui.SetCursorPosX(o);
    imgui.Image(hpbT, {glamourUI.settings.alliancePanel.hpBarDim.l * glamourUI.settings.alliancePanel.gui_scale, glamourUI.settings.alliancePanel.hpBarDim.g * glamourUI.settings.alliancePanel.gui_scale});
    imgui.SameLine();
    imgui.Image(hpfT, {glamourUI.settings.alliancePanel.hpBarDim.l * glamourUI.Settings.AlliancePanel.gui_scale, glamourUI.settings.alliancePanel.hpBarDim.g * glamourUI.settings.alliancePanel.gui_scale});
end

function renderPlayerStats(b, f, s, p, o)
        imgui.SetCursorPosX(o + 5);
        imgui.Image(b, {glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale});
        imgui.SameLine();
        imgui.SetCursorPosX(o+5);
        if(p ~= nil)then
            imgui.Image(f, {(glamourUI.settings.playerStats.BarDim.l * glamourUI.settings.playerStats.gui_scale) * p / 100, glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale});
        else
            imgui.Image(f, {glamourUI.settings.playerStats.BarDim.l  * (math.clamp((s / 1000), 0, 1) * glamourUI.settings.playerStats.gui_scale), glamourUI.settings.playerStats.BarDim.g * glamourUI.settings.playerStats.gui_scale});
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

function renderPartyZone(p)
    local yOffset = (p * 40) + (p * glamourUI.layout.padding);
    imgui.SetCursorPosX((5 + glamourUI.layout.NamePosition.x) * glamourUI.settings.partylist.gui_scale);
    imgui.SetCursorPosY((yOffset + glamourUI.layout.NamePosition.y) * glamourUI.settings.partylist.gui_scale);
    imgui.Text(getName(p));
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
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