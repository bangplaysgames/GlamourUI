local ffi = require('ffi');
local zonesFloors = require('zonesFloors');

local M = {};

local MAP_TABLE_SIG = '8A0D????????5333C05684C95774??8A5424188B7424148B7C2410B9';
local ENTRY_SIZE = 0x0E;

ffi.cdef[[
    typedef int32_t (__thiscall* CheckFloorNumber_f)(void* pThis, float X, float Y, float Z);
    typedef struct FILE FILE;
    int fopen_s(FILE** pFile, const char* filename, const char* mode);
    int fclose(FILE* stream);
    int fseek(FILE* stream, long offset, int origin);
    long ftell(FILE* stream);
    size_t fread(void* buffer, size_t size, size_t count, FILE* stream);
]];

M.table_ptr = 0;
M.floor_func = nil;
M.floor_this_ptr = nil;
M.current_map_data = nil;
M.last_floor_id = nil;
M.last_floor_check_time = 0;

local function round2(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100;
end

function M.find_map_table()
    local addr = ashita.memory.find('FFXiMain.dll', 0, MAP_TABLE_SIG, 0, 0);
    if (addr == nil or addr == 0) then
        return nil, 'map table signature not found';
    end

    M.table_ptr = ashita.memory.read_uint32(addr + 0x1C);
    if (M.table_ptr == 0) then
        return nil, 'map table pointer null';
    end
    return M.table_ptr;
end

function M.init_floor_function()
    local func_addr = ashita.memory.find('FFXiMain.dll', 0, '8B542408568D4424108BF18B4C2410508B44240C', 0, 0);
    local this_addr = ashita.memory.find('FFXiMain.dll', 0, '8B7424148B4424108B7C240C8B0D', 0x0E, 0);

    if (func_addr == nil or func_addr == 0 or this_addr == nil or this_addr == 0) then
        return false, 'floor function signatures not found';
    end

    M.floor_func = ffi.cast('CheckFloorNumber_f', func_addr);
    M.floor_this_ptr = this_addr;
    return true;
end

function M.read_entry(index)
    if (M.table_ptr == 0) then
        local ok = M.find_map_table();
        if (not ok) then
            return nil, 'map table unavailable';
        end
    end

    local base = M.table_ptr + (index * ENTRY_SIZE);
    local zone = ashita.memory.read_uint16(base + 0x00);
    local floorId = ashita.memory.read_uint8(base + 0x02);
    local floorIndex = ashita.memory.read_uint8(base + 0x03);
    local flags = ashita.memory.read_uint8(base + 0x04);
    local scale_raw = ashita.memory.read_uint8(base + 0x05);
    local scale = (scale_raw >= 0x80) and (scale_raw - 0x100) or scale_raw;
    local keyoff_raw = ashita.memory.read_uint8(base + 0x06);
    local keyoff = (keyoff_raw >= 0x80) and (keyoff_raw - 0x100) or keyoff_raw;
    local unknown = ashita.memory.read_uint8(base + 0x07);
    local mapDatOffset = ashita.memory.read_uint16(base + 0x08);
    local offsetX_raw = ashita.memory.read_uint16(base + 0x0A);
    local offsetX = (offsetX_raw >= 0x8000) and (offsetX_raw - 0x10000) or offsetX_raw;
    local offsetY_raw = ashita.memory.read_uint16(base + 0x0C);
    local offsetY = (offsetY_raw >= 0x8000) and (offsetY_raw - 0x10000) or offsetY_raw;

    return {
        ZoneId = zone,
        FloorId = floorId,
        FloorIndex = floorIndex,
        Flags = flags,
        Scale = scale,
        KeyItemOffset = keyoff,
        Unknown0000 = unknown,
        MapDatOffset = mapDatOffset,
        OffsetX = offsetX,
        OffsetY = offsetY,
        _index = index,
        _base = base,
    };
end

function M.get_key_item_index(entry)
    local k = entry.KeyItemOffset;
    if (k < 0) then return 383; end
    if (k == 0) then return 384; end

    local top = bit.band(entry.Flags, 0xF0);
    if (top == 0x00) then return k + 384; end
    if (top == 0x10) then return k + 1855; end
    if (top == 0x20) then return k + 2301; end
    return 384;
end

function M.get_dat_index(entry)
    local low = bit.band(entry.Flags, 0x0F);
    if (low == 0) then return entry.MapDatOffset + 5312; end
    if (low == 1) then return entry.MapDatOffset + 53295; end
    if (low == 2) then return entry.MapDatOffset + 54295; end
    return 5522;
end

function M.make_zone_key(zoneId, floorId)
    return string.format('%d_%d', tonumber(zoneId) or 0, tonumber(floorId) or 0);
end

function M.get_floors_for_zone(zoneid)
    local floors = {};
    local zone_data = zonesFloors[zoneid];
    if (zone_data == nil) then
        return floors;
    end

    for floorid, _ in pairs(zone_data) do
        floors[#floors + 1] = floorid;
    end

    table.sort(floors, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0);
    end);

    return floors;
end

function M.find_entry_by_floor(zoneid, floorid)
    local zone_data = zonesFloors[zoneid];
    if (zone_data == nil) then
        return nil;
    end

    local entry_index = zone_data[floorid];
    if (entry_index == nil) then
        return nil;
    end

    return M.read_entry(entry_index);
end

function M.get_player_zone()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil) then
        return party:GetMemberZone(0);
    end
    return nil;
end

function M.get_player_position()
    local entity = GetPlayerEntity();
    if (entity ~= nil and entity.Movement ~= nil and entity.Movement.LocalPosition ~= nil) then
        local lp = entity.Movement.LocalPosition;
        return lp.X, lp.Y, lp.Z;
    end
    return nil, nil, nil;
end

function M.get_floor_id(x, y, z)
    if (M.floor_func == nil or M.floor_this_ptr == nil) then
        local ok = M.init_floor_function();
        if (not ok) then
            return nil;
        end
    end

    local this_ptr_val = ashita.memory.read_uint32(ashita.memory.read_uint32(M.floor_this_ptr));
    if (this_ptr_val == 0) then
        return nil;
    end

    local this_obj = ffi.cast('void*', this_ptr_val);
    if (this_obj == nil) then
        return nil;
    end

    return M.floor_func(this_obj, x, z, y);
end

function M.get_current_map_entry()
    local zoneId = M.get_player_zone();
    if (zoneId == nil) then
        return nil, 'no zone';
    end

    local x, y, z = M.get_player_position();
    if (x == nil) then
        return nil, 'no position';
    end

    local floorId = M.get_floor_id(x, y, z);
    if (floorId == nil) then
        return nil, 'floor detection failed';
    end

    local entry = M.find_entry_by_floor(zoneId, floorId);
    if (entry == nil) then
        return nil, 'no map entry';
    end

    return entry, nil, floorId;
end

function M.get_dat_file_path(entry)
    if (entry == nil) then
        return nil, 'no entry';
    end

    local datIndex = M.get_dat_index(entry);
    local resourceMgr = AshitaCore:GetResourceManager();
    if (resourceMgr == nil) then
        return nil, 'no resource manager';
    end

    local filePath = resourceMgr:GetFilePath(datIndex);
    if (filePath == nil or filePath == '') then
        return nil, 'no dat path for index ' .. tostring(datIndex);
    end

    return filePath;
end

function M.load_map_dat(entry)
    local filePath, err = M.get_dat_file_path(entry);
    if (filePath == nil) then
        return nil, err;
    end

    local SEEK_END = 2;
    local SEEK_SET = 0;
    local filePtr = ffi.new('FILE*[1]');
    local result = ffi.C.fopen_s(filePtr, filePath, 'rb');

    if (result ~= 0 or filePtr[0] == nil) then
        if (filePtr[0] ~= nil) then
            ffi.C.fclose(filePtr[0]);
        end
        return nil, 'failed to open ' .. filePath;
    end

    local file = filePtr[0];
    if (ffi.C.fseek(file, 0, SEEK_END) ~= 0) then
        ffi.C.fclose(file);
        return nil, 'seek failed';
    end

    local size = ffi.C.ftell(file);
    if (size <= 0) then
        ffi.C.fclose(file);
        return nil, 'empty dat file';
    end

    if (ffi.C.fseek(file, 0, SEEK_SET) ~= 0) then
        ffi.C.fclose(file);
        return nil, 'rewind failed';
    end

    local buffer = ffi.new('uint8_t[?]', size);
    local bytesRead = ffi.C.fread(buffer, 1, size, file);
    ffi.C.fclose(file);

    if (bytesRead ~= size) then
        return nil, 'incomplete dat read';
    end

    return ffi.string(buffer, size);
end

function M.set_map_data_for_entry(zoneid, floorid)
    local entry = M.find_entry_by_floor(zoneid, floorid);
    if (entry == nil) then
        M.current_map_data = nil;
        return nil, 'no map entry';
    end

    local datPath, pathErr = M.get_dat_file_path(entry);
    if (datPath == nil) then
        M.current_map_data = nil;
        return nil, pathErr;
    end

    M.current_map_data = {
        entry = entry,
        datIndex = M.get_dat_index(entry),
        keyItemIndex = M.get_key_item_index(entry),
        datPath = datPath,
        floorId = floorid,
    };

    return M.current_map_data;
end

function M.load_current_map_dat()
    local entry, err, floorId = M.get_current_map_entry();
    if (entry == nil) then
        return nil, err;
    end

    return M.set_map_data_for_entry(entry.ZoneId, floorId);
end

function M.clear_map_cache()
    M.current_map_data = nil;
end

function M.get_divisor(entry)
    local scale = math.abs(entry.Scale);
    if (scale == 0) then
        return 0.0;
    end
    return 2560.0 / scale;
end

function M.world_to_map_coords(entry, worldX, worldY, worldZ)
    local divisor = M.get_divisor(entry);
    if (divisor == 0) then
        return nil, nil;
    end

    local v5 = 1.0 / divisor;
    local mapX = worldX * v5 * 512.0;
    local mapY = -(worldY * v5 * 512.0);

    mapX = math.max(-32768, math.min(32767, mapX));
    mapY = math.max(-32768, math.min(32767, mapY));

    return round2(mapX), round2(mapY);
end

function M.map_coords_to_texture(entry, mapX, mapY, textureWidth)
    local scale = textureWidth / 512.0;
    local texX = (mapX - entry.OffsetX) * scale;
    local texY = (mapY - entry.OffsetY) * scale;
    return texX, texY;
end

function M.world_to_screen(entry, worldX, worldY, worldZ, textureWidth, originX, originY, offsetX, offsetY, zoom)
    local mapX, mapY = M.world_to_map_coords(entry, worldX, worldY, worldZ);
    if (mapX == nil) then
        return nil, nil;
    end

    local texX, texY = M.map_coords_to_texture(entry, mapX, mapY, textureWidth);
    zoom = tonumber(zoom) or 1;
    return (tonumber(originX) or 0) + (tonumber(offsetX) or 0) + texX * zoom,
        (tonumber(originY) or 0) + (tonumber(offsetY) or 0) + texY * zoom;
end

function M.get_zone_key()
    local data = M.current_map_data;
    if (data == nil or data.entry == nil) then
        return nil;
    end
    return M.make_zone_key(data.entry.ZoneId, data.entry.FloorId);
end

function M.init()
    M.find_map_table();
    M.init_floor_function();
end

function M.tick()
    local now = os.clock();
    if (now - M.last_floor_check_time < 1.0) then
        return;
    end
    M.last_floor_check_time = now;

    local x, y, z = M.get_player_position();
    if (x == nil) then
        return;
    end

    local floorId = M.get_floor_id(x, y, z);
    if (floorId == nil) then
        return;
    end

    local loadedEntry = M.current_map_data and M.current_map_data.entry;
    if (loadedEntry ~= nil and loadedEntry.ZoneId == 0 and loadedEntry.FloorId == 0) then
        if (M.on_map_reload ~= nil) then
            M.on_map_reload();
        end
        return;
    end

    if (M.last_floor_id ~= nil and floorId ~= M.last_floor_id) then
        M.last_floor_id = floorId;
        local zoneId = M.get_player_zone();
        if (zoneId ~= nil and M.on_floor_changed ~= nil) then
            M.on_floor_changed(zoneId, floorId);
        elseif (M.on_map_reload ~= nil) then
            M.on_map_reload();
        end
        return;
    end

    M.last_floor_id = floorId;
end

function M.on_zone_packet(e)
    if (e.id ~= 0x000A) then
        return;
    end

    if (struct.unpack('b', e.data_modified, 0x80 + 0x01) == 1) then
        M.clear_map_cache();
        M.last_floor_id = nil;
        if (M.on_zone_cache_clear ~= nil) then
            M.on_zone_cache_clear();
        end
        return;
    end

    M.clear_map_cache();
    M.last_floor_id = nil;

    local newZone = struct.unpack('H', e.data, 0x30 + 1);
    local newSubZone = struct.unpack('H', e.data, 0x9E + 1);

    ashita.tasks.once(1, function()
        if (M.on_zone_changed ~= nil) then
            M.on_zone_changed(newZone, newSubZone);
        elseif (M.on_map_reload ~= nil) then
            M.on_map_reload();
        end
    end);
end

return M;
