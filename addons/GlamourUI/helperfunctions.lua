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

function getThemeID(theme)
    local dir = ashita.fs.get_directory(('%s\\config\\addons\\GlamourUI\\Themes\\'):fmt(AshitaCore:GetInstallPath()));
    for i = 1,#dir,1 do
        if(dir[i] == theme) then
            return i;
        end
    end
end

function ToBoolean(b)
    if(b == 1)then
        return true;
    else
        return false;
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

function renderPlayerThemed(hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p)

    imgui.Text(tostring(getName(p)));
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpfT, {(200 * (getHPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(27 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getHP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpfT, {(200 * (getMPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(242 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getMP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpfT, {(200 * (math.clamp((getTP(p) / 1000), 0, 1) * glamourUI.settings.partylist.gui_scale)), 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(457 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getTP(p)));
end

function renderPartyThemed(hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p)
    imgui.Text(tostring(getName(p)));
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpfT, {(200 * (getHPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(27 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getHP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpfT, {(200 * (getMPP(p) / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(242 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getMP(p)));
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpfT, {(200 * (math.clamp((getTP(p) / 1000),0,1)) * glamourUI.settings.partylist.gui_scale), 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(457 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(getTP(p)));
end

function renderPetThemed(hpbT, hpfT, mpbT, mpfT, tpbT, tpfT, p)
    imgui.Text('');
    imgui.Text(p.Name);
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(25 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(hpfT, {(200 * (p.HPPercent / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(27 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(p.HPPercent));
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(240 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(mpfT, {(200 * (AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent() / 100)) * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(242 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetMPPercent()));
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpbT, {200 * glamourUI.settings.partylist.gui_scale, 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(455 * glamourUI.settings.partylist.gui_scale);
    imgui.Image(tpfT, {(200 * (math.clamp((AshitaCore:GetMemoryManager():GetPlayer():GetPetTP() / 1000), 0, 1) * glamourUI.settings.partylist.gui_scale)), 16 * glamourUI.settings.partylist.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(457 * glamourUI.settings.partylist.gui_scale);
    imgui.Text(tostring(AshitaCore:GetMemoryManager():GetPlayer():GetPetTP()));
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
    imgui.ProgressBar(getHPP(a) / 100, {100 * glamourUI.settings.alliancePanel.gui_scale, 16 * glamourUI.settings.alliancePanel.gui_scale}, getName(a));
end

function renderAllianceThemed(hpbT, hpfT, a, o)
    imgui.SetCursorPosX(o);
    imgui.Image(hpbT, {100 * glamourUI.settings.alliancePanel.gui_scale, 16 * glamourUI.settings.alliancePanel.gui_scale});
    imgui.SameLine();
    imgui.Image(hpfT, {100 * glamourUI.Settings.AlliancePanel.gui_scale, 16 * glamourUI.settings.alliancePanel.gui_scale});
end

function renderPlayerStats(b, f, s, p, o)
    imgui.SetCursorPosX(o + 5);
    imgui.Image(b, {225 * glamourUI.settings.playerStats.gui_scale, 16 * glamourUI.settings.playerStats.gui_scale});
    imgui.SameLine();
    imgui.SetCursorPosX(o);
    if(p ~= nil)then
        imgui.Image(f, {(225 * glamourUI.settings.playerStats.gui_scale) * p / 100, 16* glamourUI.settings.playerStats.gui_scale});
    else
        imgui.Image(f, {225  * (math.clamp((s / 1000), 0, 1) * glamourUI.settings.playerStats.gui_scale), 16 * glamourUI.settings.playerStats.gui_scale});
    end
    imgui.SameLine();
    imgui.SetCursorPosX(o + 5);
    imgui.Text(tostring(s));
end

function setscale(a,v)
    if(a == 'partylist')then
        glamourUI.settings.partylist.gui_scale = v + 0.0;
    end
    if(a == 'targetbar') then
        glamourUI.settings.targetbar.gui_scale = v + 0.0;
    end
end