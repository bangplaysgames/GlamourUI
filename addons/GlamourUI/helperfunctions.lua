local ffi = require('ffi')
local d3d8 = require('d3d8')
local imgui = require('imgui')

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
    ['targetbar'] = 2
}

function getTex(d3d8_device, tex_path, tex_ptr)
    local texcData = '';
    if(ffi.C.D3DXCreateTextureFromFileA(d3d8_device, tex_path, tex_ptr) == ffi.C.S_OK) then
        texcData = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', tex_ptr[0]));
    end

    if(texcData ~= nil)then
        return tonumber(ffi.cast('uint32_t', texcData));
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

function setscale(a,v)
    if(a == 'partylist')then
        glamourUI.settings.partylist.gui_scale = v + 0.0;
    end
    if(a == 'targetbar') then
        glamourUI.settings.targetbar.gui_scale = v + 0.0;
    end
end