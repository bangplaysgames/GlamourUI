require('common');

local chat = require('chat');

local settings = require('settings');

local mapcore = require('mapcore');

local entity_ids = require('entity_ids');
local filter_wildcard = require('filter_wildcard');

local M = {};



local FILTER_SETTINGS_NAME = 'gmap_filters';



local default_filter_store = T{

    zones = T{},

};



local function save_filters()

    pcall(function()

        settings.save(FILTER_SETTINGS_NAME);

    end);

end



local function env_settings()

    return GlamourUI.settings and GlamourUI.settings.Env or nil;

end



local function current_zone_id()

    return tonumber(mapcore.get_player_zone());

end



local function empty_filter_lists()

    return T{

        out = T{ names = {}, ids = {} },

        focus = T{ names = {}, ids = {} },

    };

end



local function ensure_zone_entry(zones, zoneId)

    zoneId = tonumber(zoneId);

    if (zoneId == nil or zones == nil) then

        return nil;

    end



    local entry = zones[zoneId];

    if (entry == nil) then

        entry = zones[tostring(zoneId)];

    end



    if (entry == nil) then

        entry = empty_filter_lists();

        zones[zoneId] = entry;

    else

        if (entry.out == nil) then

            entry.out = T{ names = {}, ids = {} };

        end

        if (entry.focus == nil) then

            entry.focus = T{ names = {}, ids = {} };

        end

        if (entry.out.names == nil) then entry.out.names = {}; end

        if (entry.out.ids == nil) then entry.out.ids = {}; end

        if (entry.focus.names == nil) then entry.focus.names = {}; end

        if (entry.focus.ids == nil) then entry.focus.ids = {}; end

        zones[zoneId] = entry;

    end



    return entry;

end



function M.get_zone_filters(zoneId)

    if (M.store == nil or M.store.zones == nil) then

        return nil;

    end

    return ensure_zone_entry(M.store.zones, zoneId or current_zone_id());

end



local function split_comma_preserve(payload)

    local tokens = {};

    if (payload == nil or payload == '') then

        return tokens;

    end



    local start = 1;

    while (true) do

        local i = payload:find(',', start, true);

        if (i == nil) then

            tokens[#tokens + 1] = payload:sub(start);

            break;

        end

        tokens[#tokens + 1] = payload:sub(start, i - 1);

        start = i + 1;

    end



    return tokens;

end



local function parse_filter_token(token)
    return entity_ids.parse_filter_token(token);
end



local function append_unique(list, value)

    for i = 1, #list do

        if (list[i] == value) then

            return;

        end

    end

    list[#list + 1] = value;

end



local function payload_from_args(args, startIndex)

    if (startIndex > #args) then

        return '';

    end

    return table.concat(args, ' ', startIndex);

end



local function migrate_env_filters_to_store()

    local s = env_settings();

    if (s == nil or M.store == nil) then

        return;

    end



    local outNames = s.minimap_filter_out_names;

    local outIds = s.minimap_filter_out_ids;

    local focusNames = s.minimap_filter_focus_names;

    local focusIds = s.minimap_filter_focus_ids;



    local hadLegacy = (outNames ~= nil and #outNames > 0)

        or (outIds ~= nil and #outIds > 0)

        or (focusNames ~= nil and #focusNames > 0)

        or (focusIds ~= nil and #focusIds > 0);



    if (not hadLegacy) then

        return;

    end



    local zoneId = current_zone_id();

    if (zoneId == nil) then

        return;

    end



    local entry = ensure_zone_entry(M.store.zones, zoneId);

    if (entry == nil) then

        return;

    end



    local function copy_list(dst, src)

        if (src == nil) then

            return;

        end

        for i = 1, #src do

            append_unique(dst, src[i]);

        end

    end



    copy_list(entry.out.names, outNames);

    copy_list(entry.out.ids, outIds);

    copy_list(entry.focus.names, focusNames);

    copy_list(entry.focus.ids, focusIds);



    s.minimap_filter_out_names = nil;

    s.minimap_filter_out_ids = nil;

    s.minimap_filter_focus_names = nil;

    s.minimap_filter_focus_ids = nil;



    pcall(function()

        settings.save();

    end);

    save_filters();

end



function M.init()

    M.store = settings.load(default_filter_store, FILTER_SETTINGS_NAME);

    if (M.store.zones == nil) then

        M.store.zones = T{};

    end

    migrate_env_filters_to_store();

end



function M.apply_filter(mode, payload)

    if (M.store == nil) then

        M.init();

    end



    local zoneId = current_zone_id();

    if (zoneId == nil) then

        return false, 'Player zone unknown';

    end



    mode = tostring(mode or ''):lower();

    if (mode ~= 'out' and mode ~= 'focus') then

        return false, 'Usage: /gmap filter out|focus <name,id,...>';

    end



    local entry = ensure_zone_entry(M.store.zones, zoneId);

    if (entry == nil) then

        return false, 'Could not create filter entry for zone';

    end



    local bucket = (mode == 'out') and entry.out or entry.focus;

    local newNames = {};

    local newIds = {};

    local tokens = split_comma_preserve(payload);

    local nameCount = 0;

    local idCount = 0;

    local wildcardOnlyCount = 0;



    for i = 1, #tokens do

        local kind, value = parse_filter_token(tokens[i]);

        if (kind == 'name') then

            if (filter_wildcard.is_wildcard_only_pattern(value)) then

                wildcardOnlyCount = wildcardOnlyCount + 1;

            else

                append_unique(newNames, value);

                nameCount = nameCount + 1;

            end

        elseif (kind == 'id' and value ~= nil) then

            append_unique(newIds, value);

            idCount = idCount + 1;

        end

    end



    if (nameCount == 0 and idCount == 0) then

        if (wildcardOnlyCount > 0) then

            return false, 'Filter pattern cannot consist of only wildcards (* and ?).';

        end

        return false, 'No valid filter names or IDs in command.';

    end



    bucket.names = newNames;

    bucket.ids = newIds;

    save_filters();



    local msg = ('Filter %s (zone %d): %d name pattern(s), %d id(s)'):fmt(mode, zoneId, nameCount, idCount);

    if (wildcardOnlyCount > 0) then

        msg = msg .. (' (%d wildcard-only pattern(s) ignored)'):fmt(wildcardOnlyCount);

    end

    return true, msg;

end



function M.has_focus_filter()

    local entry = M.get_zone_filters();

    if (entry == nil) then

        return false;

    end

    return #entry.focus.names > 0 or #entry.focus.ids > 0;

end



function M.entity_passes_filter(row)

    if (row == nil) then

        return false;

    end



    local entry = M.get_zone_filters();

    if (entry == nil) then

        return true;

    end



    local name = row.name;

    local id = tonumber(row.id);



    if (M.has_focus_filter()) then

        if (name ~= nil and filter_wildcard.list_name_matches(name, entry.focus.names)) then

            return true;

        end

        if (id ~= nil and entity_ids.list_matches_filter_id(entry.focus.ids, id, row.kind)) then

            return true;

        end

        return false;

    end



    if (name ~= nil and filter_wildcard.list_name_matches(name, entry.out.names)) then

        return false;

    end

    if (id ~= nil and entity_ids.list_matches_filter_id(entry.out.ids, id, row.kind)) then

        return false;

    end



    return true;

end



function M.clear_filters()

    if (M.store == nil) then

        M.init();

    end



    local zoneId = current_zone_id();

    if (zoneId == nil) then

        return nil;

    end



    M.store.zones[zoneId] = nil;

    M.store.zones[tostring(zoneId)] = nil;

    save_filters();

    return zoneId;

end



function M.print_help()

    print(chat.header('GlamourUI /gmap'));

    print(chat.message('/gmap filter out <name,id,...> — hide matching entities (current zone)'));

    print(chat.message('/gmap filter focus <name,id,...> — show only matching entities (current zone)'));

    print(chat.message('/gmap filter clear — remove filters for the current zone'));

    print(chat.message('Filters are per-zone; saved to config/addons/GlamourUI/gmap_filters.lua'));

    print(chat.message('IDs: use the hex on the target bar (e.g. 2f or 0x2f). 0x is optional; matches that id only.'));

    print(chat.message('Names: wildcards * (any length) and ? (one char); case-insensitive. Example: ???hpemde'));

    print(chat.message('Patterns with only * and ? are rejected, except exactly ??? (literal name).'));

    print(chat.message('/gmap — open or close full-screen map (Escape closes when not moving)'));

end



function M.handle_command(args)

    if (#args < 1 or not args[1]:any('/gmap')) then

        return false;

    end



    if (#args == 1) then

        require('fullscreen_map').toggle();

        return true;

    end



    if (args[2]:any('help')) then

        M.print_help();

        return true;

    end



    if (args[2]:any('filter')) then

        if (#args >= 3 and args[3]:any('clear')) then

            local zoneId = M.clear_filters();

            if (zoneId ~= nil) then

                print(chat.header('GlamourUI'):append(chat.message(('Minimap filters cleared for zone %d.'):fmt(zoneId))));

            else

                print(chat.header('GlamourUI'):append(chat.error('Could not determine current zone.')));

            end

            return true;

        end



        if (#args >= 4 and (args[3]:any('out') or args[3]:any('focus'))) then

            local mode = args[3];

            local payload = payload_from_args(args, 4);

            local ok, msg = M.apply_filter(mode, payload);

            if (ok) then

                print(chat.header('GlamourUI'):append(chat.message(msg)));

            else

                print(chat.header('GlamourUI'):append(chat.error(msg)));

            end

            return true;

        end



        print(chat.header('GlamourUI'):append(chat.error('Usage: /gmap filter out|focus <name,id,...>  or  /gmap filter clear')));

        return true;

    end



    M.print_help();

    return true;

end



return M;

