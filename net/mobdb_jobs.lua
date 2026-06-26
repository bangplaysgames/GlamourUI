--[[
    Mob job abbreviations for the target bar via MobDB zone data (addons/mobdb/data/<zone>.lua).
    Lookup: entity index first, then mob name. Jobs come from mob pool MainJob (humanoid families only).
]]

require('common');
local struct = require('struct');

local M = {};

local currentZone = nil;
local names = T{};
local indices = T{};
local jobsTable = nil;

local function resolve_jobs_table()
    if (jobsTable ~= nil) then
        return jobsTable;
    end
    local rm = AshitaCore:GetResourceManager();
    if (rm ~= nil and rm:GetString('jobs.names_abbr', 1) == 'WAR') then
        jobsTable = 'jobs.names_abbr';
    else
        jobsTable = 'jobs_abbr';
    end
    return jobsTable;
end

local function load_zone(zone)
    zone = tonumber(zone) or 0;
    if (zone == currentZone) then
        return;
    end

    currentZone = zone;
    names = T{};
    indices = T{};

    if (zone == 0) then
        return;
    end

    local path = string.format('%saddons/mobdb/data/%u.lua', AshitaCore:GetInstallPath(), zone);
    if (not ashita.fs.exists(path)) then
        return;
    end

    local fn, loadErr = loadfile(path);
    if (fn == nil) then
        return;
    end

    local ok, output = pcall(fn);
    if (not ok or type(output) ~= 'table') then
        return;
    end

    names = output.Names or T{};
    indices = output.Indices or T{};
end

local function lookup_record(targetIndex)
    targetIndex = tonumber(targetIndex) or 0;
    if (targetIndex <= 0) then
        return nil;
    end

    local mem = AshitaCore:GetMemoryManager();
    if (mem == nil) then
        return nil;
    end

    local entMgr = mem:GetEntity();
    if (entMgr == nil) then
        return nil;
    end

    if (bit.band(entMgr:GetSpawnFlags(targetIndex), 0x10) == 0) then
        return nil;
    end

    local party = mem:GetParty();
    if (party == nil) then
        return nil;
    end

    load_zone(party:GetMemberZone(0));

    local record = indices[targetIndex];
    if (record == nil) then
        local mobName = entMgr:GetName(targetIndex);
        if (mobName ~= nil and mobName ~= '') then
            record = names[mobName];
        end
    end

    return record;
end

function M.get_job_abbr(targetIndex)
    local record = lookup_record(targetIndex);
    if (record == nil) then
        return nil;
    end

    local jobId = tonumber(record.Job) or 0;
    if (jobId <= 0) then
        return nil;
    end

    local rm = AshitaCore:GetResourceManager();
    if (rm == nil) then
        return nil;
    end

    local abbr = rm:GetString(resolve_jobs_table(), jobId);
    if (abbr == nil or abbr == '') then
        return nil;
    end

    return abbr;
end

function M.get_record(targetIndex)
    return lookup_record(targetIndex);
end

--- Target bar label: "75WAR" when job known, else "Lv. 75".
function M.format_level_text(level, targetIndex)
    local lv = tonumber(level);
    if (lv == nil or lv <= 0) then
        return nil;
    end

    local job = M.get_job_abbr(targetIndex);
    if (job ~= nil) then
        return ('%d%s'):fmt(lv, job);
    end

    return 'Lv. ' .. tostring(lv);
end

--- MobDB pool level range for the target bar icon row (e.g. "18-21").
function M.format_level_range_text(record)
    if (type(record) ~= 'table') then
        return nil;
    end

    local minLv = tonumber(record.MinLevel);
    local maxLv = tonumber(record.MaxLevel);
    if (minLv == nil or maxLv == nil or minLv <= 0 or maxLv <= 0) then
        return nil;
    end

    if (minLv == maxLv) then
        return tostring(minLv);
    end

    return ('%d-%d'):fmt(minLv, maxLv);
end

ashita.events.register('packet_in', 'glam_mobdb_jobs_zone', function(e)
    if (e.id == 0x00A) then
        local zone = struct.unpack('H', e.data, 0x30 + 1);
        load_zone(zone);
    end
end);

pcall(function()
    load_zone(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0));
end);

return M;
