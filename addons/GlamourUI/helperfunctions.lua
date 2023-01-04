local ffi = require('ffi')
local d3d8 = require('d3d8')
local imgui = require('imgui')
require('common')

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

function ToBoolean(b)
    if(b == 1)then
        return true;
    else
        return false;
    end
end

local modules = T{
    ['partylist'] = 1,
    ['targetbar'] = 2,
    ['alliancepanel'] = 3,
    ['alliancepanel2'] = 4
}

local d3d8_device = d3d8.get_device();

function getTex(d3d8_device, tex_path, tex_ptr)
    local texcData = '';
    if(ffi.C.D3DXCreateTextureFromFileA(d3d8_device, tex_path, tex_ptr) == ffi.C.S_OK) then
        texcData = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', tex_ptr[0]));
    end

    if(texcData ~= nil)then
        return tonumber(ffi.cast('uint32_t', texcData));
    end

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
    imgui.Text('');
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

function loadTextures(t)
    if (ashita.fs.exists((t .. 'hpBar.png'))) then
        hpbTexPath = (t .. 'hpBar.png');
        hpbTex = getTex(d3d8_device, hpbTexPath, hpbTexPtr);
    end
    if(ashita.fs.exists((t .. 'mpBar.png'))) then
        mpbTexPath = (t .. 'mpBar.png');
        mpbTex = getTex(d3d8_device, mpbTexPath, mpbTexPtr);
    end
    if(ashita.fs.exists((t .. 'tpBar.png'))) then
        tpbTexPath = (t .. 'tpBar.png');
        tpbTex = getTex(d3d8_device, tpbTexPath, tpbTexPtr);
    end
    if(ashita.fs.exists((t .. 'hpFill.png'))) then
        hpfTexPath = (t .. 'hpFill.png');
        hpfTex = getTex(d3d8_device, hpfTexPath, hpfTexPtr);
    end
    if(ashita.fs.exists((t .. 'mpFill.png'))) then
        mpfTexPath = (t .. 'mpFill.png');
        mpfTex = getTex(d3d8_device, mpfTexPath, mpfTexPtr);
    end
    if(ashita.fs.exists((t .. 'tpFill.png'))) then
        tpfTexPath = (t .. 'tpFill.png');
        tpfTex = getTex(d3d8_device, tpfTexPath, tpfTexPtr);
    end
    if(ashita.fs.exists(t .. 'LockOn.png')) then
        lockTexPath = (t .. 'LockOn.png');
        lockedTex = getTex(d3d8_device, lockTexPath, lockTexPtr);
    end
end

function setscale(a,v)
    if(a == 'partylist')then
        glamourUI.settings.partylist.gui_scale = v + 0.0;
    end
    if(a == 'targetbar') then
        glamourUI.settings.targetbar.gui_scale = v + 0.0;
    end
end