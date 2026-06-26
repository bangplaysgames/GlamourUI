require('common');

local M = {};

local JOB_ROLE_STYLES = {
    ['WAR'] = { 'hybrid' },
    ['MNK'] = { 'damage' },
    ['THF'] = { 'damage' },
    ['WHM'] = { 'healer' },
    ['BLM'] = { 'damage' },
    ['RDM'] = { 'healer', 'damage' },
    ['PLD'] = { 'tank' },
    ['DRK'] = { 'damage' },
    ['NIN'] = { 'hybrid' },
    ['SAM'] = { 'damage' },
    ['DRG'] = { 'damage' },
    ['RNG'] = { 'damage' },
    ['SMN'] = { 'damage', 'healer' },
    ['BST'] = { 'damage' },
    ['BRD'] = { 'damage', 'healer' },
    ['BLU'] = { 'damage' },
    ['COR'] = { 'damage' },
    ['PUP'] = { 'damage' },
    ['DNC'] = { 'damage', 'healer' },
    ['SCH'] = { 'damage', 'healer' },
    ['GEO'] = { 'damage' },
    ['RUN'] = { 'tank' },
};

local DEFAULT_TRINITY_COLORS = {
    tank = { 0.25, 0.55, 1.0, 1.0 },
    healer = { 0.20, 0.90, 0.35, 1.0 },
    damage = { 1.0, 0.25, 0.25, 1.0 },
    hybrid = { 0.72, 0.35, 1.0, 1.0 },
    monster = { 1.0, 0.45, 0.62, 1.0 },
    other = { 1.0, 1.0, 1.0, 1.0 },
};

local rosterCache = nil;
local rosterCacheTime = 0;

local function normalize_member_name(name)
    if (name == nil) then
        return '';
    end
    return tostring(name):gsub('%z.*', ''):gsub('%s+$', '');
end

local function escape_pattern_literal(s)
    return (tostring(s or ''):gsub('(%W)', '%%%1'));
end

local function get_trinity_colors()
    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    local src = (chat ~= nil and chat.trinityColors ~= nil) and chat.trinityColors or DEFAULT_TRINITY_COLORS;
    return src;
end

local function color_vec(c)
    if (c == nil) then
        return { 1.0, 1.0, 1.0, 1.0 };
    end
    return {
        tonumber(c[1]) or 1.0,
        tonumber(c[2]) or 1.0,
        tonumber(c[3]) or 1.0,
        tonumber(c[4]) or 1.0,
    };
end

local function is_trust_entity(entity)
    if (entity == nil) then
        return false;
    end
    local spawnFlags = entity.SpawnFlags or 0;
    if (bit.band(spawnFlags, 0x1000) == 0x1000) then
        return true;
    end
    return (tonumber(entity.TrustOwnerTargetIndex) or 0) > 0;
end

local function party_entity_for_slot(partyManager, slot)
    if (partyManager == nil or slot == nil) then
        return nil;
    end
    local tidx = tonumber(partyManager:GetMemberTargetIndex(slot)) or 0;
    if (tidx > 0 and GetEntity ~= nil) then
        return GetEntity(tidx);
    end
    return nil;
end

local function find_party_slot_by_name(partyManager, name)
    if (partyManager == nil or name == nil or name == '') then
        return nil;
    end
    for i = 0, 17 do
        if (partyManager:GetMemberIsActive(i) > 0) then
            local memberName = normalize_member_name(partyManager:GetMemberName(i));
            if (memberName ~= '' and memberName == name) then
                return i;
            end
        end
    end
    return nil;
end

local function split_colored_name_segments(name, roleSpec, trinity)
    if (name == nil or name == '') then
        return {};
    end
    if (roleSpec == nil or #roleSpec == 0) then
        return { { text = name, color = color_vec(trinity.other), lockedColor = true } };
    end
    if (#roleSpec == 1) then
        return {
            { text = name, color = color_vec(trinity[roleSpec[1]]), lockedColor = true },
        };
    end
    local midpoint = math.max(1, math.floor(#name / 2));
    return {
        { text = name:sub(1, midpoint), color = color_vec(trinity[roleSpec[1]]), lockedColor = true },
        { text = name:sub(midpoint + 1), color = color_vec(trinity[roleSpec[2]]), lockedColor = true },
    };
end

function M.get_party_member_name_segments(name)
    name = normalize_member_name(name);
    if (name == '') then
        return nil;
    end

    local partyManager = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (partyManager == nil) then
        return nil;
    end

    local slot = find_party_slot_by_name(partyManager, name);
    if (slot == nil) then
        return nil;
    end

    local trinity = get_trinity_colors();
    local ent = party_entity_for_slot(partyManager, slot);
    if (is_trust_entity(ent)) then
        return { { text = name, color = color_vec(trinity.other), lockedColor = true } };
    end

    local rm = AshitaCore:GetResourceManager();
    local jobId = partyManager:GetMemberMainJob(slot);
    local jobAbbr = nil;
    if (rm ~= nil and jobId ~= nil and tonumber(jobId) > 0) then
        jobAbbr = rm:GetString('jobs.names_abbr', jobId);
    end
    if (jobAbbr ~= nil and jobAbbr ~= '') then
        local roleSpec = JOB_ROLE_STYLES[jobAbbr];
        return split_colored_name_segments(name, roleSpec, trinity);
    end

    return { { text = name, color = color_vec(trinity.other), lockedColor = true } };
end

--- Single trinity-role color for a party member BY NAME, by their main job --
--- unlike get_party_member_name_segments this does NOT special-case trusts, so
--- a trust is colored by its job the same as a player. Returns nil if the name
--- isn't in the party roster or its job has no role mapping.
function M.get_role_color(name)
    name = normalize_member_name(name);
    if (name == '') then
        return nil;
    end
    local partyManager = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (partyManager == nil) then
        return nil;
    end
    local slot = find_party_slot_by_name(partyManager, name);
    if (slot == nil) then
        return nil;
    end
    local rm = AshitaCore:GetResourceManager();
    local jobId = partyManager:GetMemberMainJob(slot);
    if (rm == nil or jobId == nil or tonumber(jobId) <= 0) then
        return nil;
    end
    local jobAbbr = rm:GetString('jobs.names_abbr', jobId);
    local roleSpec = (jobAbbr ~= nil and jobAbbr ~= '') and JOB_ROLE_STYLES[jobAbbr] or nil;
    if (roleSpec == nil or roleSpec[1] == nil) then
        return nil;
    end
    return color_vec(get_trinity_colors()[roleSpec[1]]);
end

local function build_roster()
    local roster = {};
    local partyManager = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty() or nil;
    if (partyManager == nil) then
        return roster;
    end

    local rm = AshitaCore:GetResourceManager();
    local trinity = get_trinity_colors();

    for i = 0, 17 do
        if (partyManager:GetMemberIsActive(i) > 0) then
            local name = normalize_member_name(partyManager:GetMemberName(i));
            if (name ~= '') then
                local ent = party_entity_for_slot(partyManager, i);
                local isTrust = is_trust_entity(ent);
                local jobAbbr = nil;
                if (not isTrust and rm ~= nil) then
                    local jobId = partyManager:GetMemberMainJob(i);
                    if (jobId ~= nil and tonumber(jobId) > 0) then
                        jobAbbr = rm:GetString('jobs.names_abbr', jobId);
                    end
                end
                local roleSpec = (not isTrust and jobAbbr ~= nil) and JOB_ROLE_STYLES[jobAbbr] or nil;
                local nameSegs = isTrust
                    and { { text = name, color = color_vec(trinity.other), lockedColor = true } }
                    or split_colored_name_segments(name, roleSpec, trinity);
                roster[#roster + 1] = {
                    name = name,
                    nameLen = #name,
                    possessiveLen = #name + 2,
                    esc = escape_pattern_literal(name),
                    segments = nameSegs,
                };
            end
        end
    end

    table.sort(roster, function(a, b)
        return (a.nameLen or 0) > (b.nameLen or 0);
    end);
    return roster;
end

local function get_roster()
    local now = os.clock();
    if (rosterCache ~= nil and (now - rosterCacheTime) < 0.2) then
        return rosterCache;
    end
    rosterCache = build_roster();
    rosterCacheTime = now;
    return rosterCache;
end

function M.invalidate_roster_cache()
    rosterCache = nil;
    rosterCacheTime = 0;
end

local function append_plain_segment(out, text, color)
    if (text == nil or text == '') then
        return;
    end
    out[#out + 1] = { text = text, color = color };
end

local function append_name_segments(out, nameSegments)
    for i = 1, #nameSegments do
        out[#out + 1] = {
            text = nameSegments[i].text or '',
            color = nameSegments[i].color,
            lockedColor = nameSegments[i].lockedColor == true,
        };
    end
end

function M.build_colored_segments(message, defaultColor)
    defaultColor = defaultColor or { 1.0, 1.0, 1.0, 1.0 };
    message = tostring(message or '');
    if (message == '') then
        return { { text = '', color = defaultColor } };
    end

    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    if (chat ~= nil and chat.partyNameRoleColors == false) then
        return { { text = message, color = defaultColor } };
    end

    local roster = get_roster();
    if (#roster == 0) then
        return { { text = message, color = defaultColor } };
    end

    local out = {};
    local pos = 1;
    while (pos <= #message) do
        local best = nil;
        local bestAt = nil;

        for ri = 1, #roster do
            local entry = roster[ri];
            local possessive = entry.esc .. "'s";
            local pStart = message:find(possessive, pos, true);
            if (pStart ~= nil and (bestAt == nil or pStart < bestAt)) then
                bestAt = pStart;
                best = { entry = entry, start = pStart, finish = pStart + entry.possessiveLen - 1, text = message:sub(pStart, pStart + entry.possessiveLen - 1) };
            end
            local nStart = message:find(entry.name, pos, true);
            if (nStart ~= nil and (bestAt == nil or nStart < bestAt)) then
                bestAt = nStart;
                best = { entry = entry, start = nStart, finish = nStart + entry.nameLen - 1, text = entry.name };
            end
        end

        if (best == nil) then
            append_plain_segment(out, message:sub(pos), defaultColor);
            break;
        end

        if (best.start > pos) then
            append_plain_segment(out, message:sub(pos, best.start - 1), defaultColor);
        end

        if (best.text == best.entry.name) then
            append_name_segments(out, best.entry.segments);
        else
            local segs = best.entry.segments;
            if (#segs == 1) then
                out[#out + 1] = { text = best.text, color = segs[1].color, lockedColor = true };
            else
                local mid = math.max(1, math.floor(#best.entry.name / 2));
                local part1 = best.text:sub(1, mid);
                local part2 = best.text:sub(mid + 1);
                out[#out + 1] = { text = part1, color = segs[1].color, lockedColor = true };
                if (part2 ~= '') then
                    out[#out + 1] = { text = part2, color = (segs[2] and segs[2].color) or segs[1].color, lockedColor = true };
                end
            end
        end

        pos = best.finish + 1;
    end

    if (#out == 0) then
        return { { text = message, color = defaultColor } };
    end
    return out;
end

local function segment_list_has_atomic(segments)
    for i = 1, #segments do
        if (segments[i].atomic == true) then
            return true;
        end
    end
    return false;
end

local function segment_list_has_locked_color(segments)
    for i = 1, #segments do
        if (segments[i].lockedColor == true) then
            return true;
        end
    end
    return false;
end

local function colors_equal(a, b)
    if (a == b) then
        return true;
    end
    if (a == nil or b == nil) then
        return false;
    end
    return (tonumber(a[1]) or 0) == (tonumber(b[1]) or 0)
        and (tonumber(a[2]) or 0) == (tonumber(b[2]) or 0)
        and (tonumber(a[3]) or 0) == (tonumber(b[3]) or 0)
        and (tonumber(a[4]) or 1) == (tonumber(b[4]) or 1);
end

local function segment_list_has_distinct_colors(segments)
    if (segments == nil or #segments <= 1) then
        return false;
    end
    local ref = segments[1].color;
    for i = 2, #segments do
        if (not colors_equal(ref, segments[i].color)) then
            return true;
        end
    end
    return false;
end

function M.apply_to_segments(segments, message, defaultColor)
    if (segments == nil or #segments == 0) then
        return M.build_colored_segments(message or '', defaultColor);
    end

    local preserveStructure = segment_list_has_atomic(segments)
        or segment_list_has_locked_color(segments)
        or segment_list_has_distinct_colors(segments);

    if (not preserveStructure) then
        if (message == nil or message == '') then
            local parts = {};
            for i = 1, #segments do
                parts[i] = segments[i].text or '';
            end
            message = table.concat(parts);
        end
        return M.build_colored_segments(message, defaultColor);
    end

    local out = {};
    for i = 1, #segments do
        local seg = segments[i];
        if (seg.atomic == true or seg.lockedColor == true) then
            out[#out + 1] = seg;
        else
            local expanded = M.build_colored_segments(seg.text or '', seg.color or defaultColor);
            for j = 1, #expanded do
                out[#out + 1] = expanded[j];
            end
        end
    end
    return out;
end

function M.is_enabled()
    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    return chat == nil or chat.partyNameRoleColors ~= false;
end

function M.get_roster_cache_stamp()
    return rosterCacheTime or 0;
end

return M;
