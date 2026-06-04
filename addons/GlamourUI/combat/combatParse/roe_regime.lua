require('common');

local M = {};

M.REGIME_MSG = T{
    [690] = true,
    [697] = true,
    [704] = true,
    [705] = true,
};

M.PROGRESS_MSG = T{
    [558] = true,
    [698] = true,
    [740] = true,
};

local name_cache = T{};
local resolved_table = nil;
local vendored_names;

local function load_vendored_names()
    if (vendored_names ~= nil) then
        return vendored_names;
    end
    vendored_names = false;
    local ok, data = pcall(function()
        return require('roe_record_names');
    end);
    if (ok and type(data) == 'table') then
        vendored_names = data;
    end
    return vendored_names;
end

local REGIME_TABLE_CANDIDATES = {
    'roe.records.names',
    'roe.records',
    'records.eminence.names',
    'records.eminence',
    'records.of.eminence.names',
    'records.of.eminence',
    'eminence.records.names',
    'eminence.records',
    'roe.objectives.names',
    'roe.objectives',
    'objectives.roe.names',
    'RoERecords.names',
    'RoERecords',
};

local function rm()
    return AshitaCore and AshitaCore:GetResourceManager() or nil;
end

local function rm_string(tbl, id)
    if (id == nil) then
        return nil;
    end
    id = math.floor(tonumber(id) or 0);
    if (id <= 0 or id > 65535) then
        return nil;
    end
    local r = rm();
    if (r == nil or r.GetString == nil) then
        return nil;
    end
    local ok, s = pcall(function()
        local s1 = r:GetString(tbl, id, 2);
        if (s1 ~= nil and s1 ~= '') then
            return s1;
        end
        return r:GetString(tbl, id, 1);
    end);
    if (not ok or s == nil or s == '') then
        return nil;
    end
    return s;
end

local function clean_regime_name(s)
    if (s == nil) then
        return nil;
    end
    s = tostring(s):gsub('%z.*', ''):gsub('^%s+', ''):gsub('%s+$', '');
    if (s == '' or s:match('^#?%d+$')) then
        return nil;
    end
    return s;
end

function M.lookup_regime_name(id)
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil;
    end
    if (name_cache[id] ~= nil) then
        local c = name_cache[id];
        return (c ~= '') and c or nil;
    end

    local tables = {};
    if (resolved_table ~= nil) then
        tables[1] = resolved_table;
    end
    for _, t in ipairs(REGIME_TABLE_CANDIDATES) do
        if (t ~= resolved_table) then
            tables[#tables + 1] = t;
        end
    end

    for ti = 1, #tables do
        local hit = clean_regime_name(rm_string(tables[ti], id));
        if (hit ~= nil) then
            resolved_table = tables[ti];
            name_cache[id] = hit;
            return hit;
        end
    end

    local vend = load_vendored_names();
    if (type(vend) == 'table') then
        local v = clean_regime_name(vend[id]);
        if (v ~= nil) then
            name_cache[id] = v;
            return v;
        end
    end

    name_cache[id] = '';
    return nil;
end

function M.is_progress_message(message_id)
    message_id = tonumber(message_id) or 0;
    return M.PROGRESS_MSG[message_id] == true;
end

function M.format_progress_line(message_id, param_1, param_2)
    message_id = tonumber(message_id) or 0;
    if (not M.PROGRESS_MSG[message_id]) then
        return nil;
    end
    return ('%d/%d'):fmt(tonumber(param_1) or 0, tonumber(param_2) or 0);
end

function M.is_roe_message(message_id)
    message_id = tonumber(message_id) or 0;
    return M.REGIME_MSG[message_id] == true or M.PROGRESS_MSG[message_id] == true;
end

function M.purpose()
    return 'GoV';
end

return M;
