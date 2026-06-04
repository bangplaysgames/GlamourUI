local ffi = require('ffi');
local d3d8 = require('d3d8');
local mapcore = require('mapcore');
local map_render = require('map_render');

local C = ffi.C;
local M = {};

local d3d8_device = d3d8.get_device();
local DEFAULT_MAX_CACHE = 64;

local IMAGE_TYPE = {
    BITMAP = 0x0000000A,
    DXT1 = 0x44585431,
    DXT2 = 0x44585432,
    DXT3 = 0x44585433,
    DXT4 = 0x44585434,
    DXT5 = 0x44585435,
};

ffi.cdef[[
    typedef struct {
        uint32_t structLength;
        int32_t width;
        int32_t height;
        uint16_t planes;
        uint16_t bitCount;
        uint32_t compression;
        uint32_t imageSize;
        uint32_t horizontalResolution;
        uint32_t verticalResolution;
        uint32_t usedColors;
        uint32_t importantColors;
        uint32_t type;
    } GlamMapImageHeader;
]];

M.cache = {};
M.active_key = nil;
M.texture_id = nil;
M.width = 0;
M.height = 0;

local function max_cache_size()
    local s = GlamourUI.settings and GlamourUI.settings.Env;
    return math.max(8, math.min(256, tonumber(s and s.minimap_cache_max) or DEFAULT_MAX_CACHE));
end

local function cache_count()
    local n = 0;
    for _ in pairs(M.cache) do
        n = n + 1;
    end
    return n;
end

local function read_u8(data, offset)
    return string.byte(data, offset + 1);
end

local function read_u16(data, offset)
    return read_u8(data, offset) + read_u8(data, offset + 1) * 256;
end

local function read_u32(data, offset)
    return read_u8(data, offset)
        + read_u8(data, offset + 1) * 256
        + read_u8(data, offset + 2) * 65536
        + read_u8(data, offset + 3) * 16777216;
end

local function cache_key(zoneId, floorId)
    return ('%s:%s'):fmt(mapcore.make_zone_key(zoneId, floorId), map_render.get_mode());
end

local function write_bgra_pixel(dest, surfaceOffset, r, g, b, a)
    dest[surfaceOffset + 0] = b;
    dest[surfaceOffset + 1] = g;
    dest[surfaceOffset + 2] = r;
    dest[surfaceOffset + 3] = a;
end

local function write_bgra_pixel_mode(dest, surfaceOffset, r, g, b, a, mode)
    r, g, b, a = map_render.apply_rgb(r, g, b, a, mode);
    write_bgra_pixel(dest, surfaceOffset, r, g, b, a);
end

local function decode_rgb565(rgb565)
    local r = math.floor(bit.band(bit.rshift(rgb565, 11), 0x1F) * 255 / 31);
    local g = math.floor(bit.band(bit.rshift(rgb565, 5), 0x3F) * 255 / 63);
    local b = math.floor(bit.band(rgb565, 0x1F) * 255 / 31);
    return r, g, b;
end

local function read_color(data, offset, bitDepth)
    if (bitDepth == 8) then
        local gray = read_u8(data, offset);
        return gray, gray, gray, 255, 1;
    elseif (bitDepth == 16) then
        local rgb565 = read_u16(data, offset);
        local r, g, b = decode_rgb565(rgb565);
        return r, g, b, 255, 2;
    elseif (bitDepth == 24) then
        local b = read_u8(data, offset);
        local g = read_u8(data, offset + 1);
        local r = read_u8(data, offset + 2);
        return r, g, b, 255, 3;
    elseif (bitDepth == 32) then
        local b = read_u8(data, offset);
        local g = read_u8(data, offset + 1);
        local r = read_u8(data, offset + 2);
        local a = read_u8(data, offset + 3);
        a = (a > 0) and 255 or 0;
        return r, g, b, a, 4;
    end
    return 255, 0, 255, 255, 0;
end

local function parse_image_header(data, offset)
    if (#data < offset + ffi.sizeof('GlamMapImageHeader')) then
        return nil, 'header too small';
    end

    local header = ffi.cast('GlamMapImageHeader*', ffi.cast('uint8_t*', ffi.cast('const char*', data)) + offset)[0];
    return {
        width = header.width,
        height = header.height,
        bitCount = header.bitCount,
        type = header.type,
    };
end

local function copy_bitmap(data, header, dataOffset)
    local result, dx_texture = d3d8_device:CreateTexture(
        header.width,
        header.height,
        1,
        0,
        C.D3DFMT_A8R8G8B8,
        C.D3DPOOL_MANAGED
    );

    if (result ~= C.S_OK or dx_texture == nil) then
        return nil, nil, 'bitmap texture create failed';
    end

    local lockResult, lockedRect = dx_texture:LockRect(0, nil, 0);
    if (lockResult ~= C.S_OK or lockedRect == nil or lockedRect.pBits == nil) then
        dx_texture:Release();
        return nil, nil, 'bitmap lock failed';
    end

    local dest = ffi.cast('uint8_t*', lockedRect.pBits);
    local pitch = lockedRect.Pitch;
    local offset = dataOffset;
    local palette = nil;

    if (header.bitCount == 8) then
        palette = {};
        for i = 0, 255 do
            local r, g, b, a = read_color(data, offset, 32);
            palette[i] = { r = r, g = g, b = b, a = a };
            offset = offset + 4;
        end
    end

    local pixelCount = header.width * header.height;
    if (header.bitCount == 8) then
        for pixelIdx = 0, pixelCount - 1 do
            local paletteIdx = read_u8(data, offset);
            offset = offset + 1;
            local color = palette[paletteIdx];
            if (color ~= nil) then
                local x = pixelIdx % header.width;
                local y = math.floor(pixelIdx / header.width);
                local flippedY = header.height - 1 - y;
                local surfaceOffset = flippedY * pitch + x * 4;
                write_bgra_pixel_mode(dest, surfaceOffset, color.r, color.g, color.b, color.a, map_render.get_mode());
            end
        end
    else
        for pixelIdx = 0, pixelCount - 1 do
            local r, g, b, a, bytesRead = read_color(data, offset, header.bitCount);
            offset = offset + bytesRead;
            local x = pixelIdx % header.width;
            local y = math.floor(pixelIdx / header.width);
            local flippedY = header.height - 1 - y;
            local surfaceOffset = flippedY * pitch + x * 4;
            write_bgra_pixel_mode(dest, surfaceOffset, r, g, b, a, map_render.get_mode());
        end
    end

    dx_texture:UnlockRect(0);
    local gcTexture = d3d8.gc_safe_release(ffi.cast('IDirect3DBaseTexture8*', dx_texture));
    return gcTexture, { width = header.width, height = header.height };
end

local function lerp_channel(a, b, t)
    return math.floor(a * (1 - t) + b * t + 0.5);
end

local function build_dxt_color_palette(c0, c1)
    local r0, g0, b0 = decode_rgb565(c0);
    local r1, g1, b1 = decode_rgb565(c1);
    local colors = {};

    if (c0 > c1) then
        colors[1] = { r = r0, g = g0, b = b0 };
        colors[2] = { r = r1, g = g1, b = b1 };
        colors[3] = {
            r = lerp_channel(r0, r1, 1 / 3),
            g = lerp_channel(g0, g1, 1 / 3),
            b = lerp_channel(b0, b1, 1 / 3),
        };
        colors[4] = {
            r = lerp_channel(r0, r1, 2 / 3),
            g = lerp_channel(g0, g1, 2 / 3),
            b = lerp_channel(b0, b1, 2 / 3),
        };
    else
        colors[1] = { r = r0, g = g0, b = b0 };
        colors[2] = { r = r1, g = g1, b = b1 };
        colors[3] = {
            r = lerp_channel(r0, r1, 0.5),
            g = lerp_channel(g0, g1, 0.5),
            b = lerp_channel(b0, b1, 0.5),
        };
        colors[4] = { r = 0, g = 0, b = 0 };
    end

    return colors, (c0 <= c1);
end

local function read_bit_range(data, byteOffset, bitStart, bitCount)
    local value = 0;
    for b = 0, bitCount - 1 do
        local bitPos = bitStart + b;
        local byteIdx = byteOffset + math.floor(bitPos / 8);
        local shift = bitPos % 8;
        local byteVal = read_u8(data, byteIdx);
        if (bit.band(bit.rshift(byteVal, shift), 1) ~= 0) then
            value = value + bit.lshift(1, b);
        end
    end
    return value;
end

local function build_dxt5_alpha_palette(data, blockOff)
    local a0 = read_u8(data, blockOff);
    local a1 = read_u8(data, blockOff + 1);
    local alphas = {};

    if (a0 > a1) then
        alphas[1] = a0;
        alphas[2] = a1;
        alphas[3] = math.floor((6 * a0 + 1 * a1) / 7);
        alphas[4] = math.floor((5 * a0 + 2 * a1) / 7);
        alphas[5] = math.floor((4 * a0 + 3 * a1) / 7);
        alphas[6] = math.floor((3 * a0 + 4 * a1) / 7);
        alphas[7] = math.floor((2 * a0 + 5 * a1) / 7);
        alphas[8] = math.floor((1 * a0 + 6 * a1) / 7);
    else
        alphas[1] = a0;
        alphas[2] = a1;
        alphas[3] = math.floor((4 * a0 + 1 * a1) / 5);
        alphas[4] = math.floor((3 * a0 + 2 * a1) / 5);
        alphas[5] = math.floor((2 * a0 + 3 * a1) / 5);
        alphas[6] = math.floor((1 * a0 + 4 * a1) / 5);
        alphas[7] = 0;
        alphas[8] = 255;
    end

    return alphas;
end

local function alpha_for_dxt_block(data, blockOff, blockBytes, imageType, px, py)
    local pixelIndex = py * 4 + px;

    if (blockBytes == 8) then
        return 255;
    end

    if (imageType == IMAGE_TYPE.DXT3 or imageType == IMAGE_TYPE.DXT4) then
        local nibble = read_bit_range(data, blockOff, pixelIndex * 4, 4);
        return math.floor(nibble * 255 / 15 + 0.5);
    end

    -- DXT5, DXT2 (treat as DXT5-style alpha for color processing)
    local alphas = build_dxt5_alpha_palette(data, blockOff);
    local alphaIndex = read_bit_range(data, blockOff + 2, pixelIndex * 3, 3) + 1;
    return alphas[alphaIndex] or 255;
end

local function copy_dxt_decompressed(data, header, dataOffset, imageType)
    local result, dx_texture = d3d8_device:CreateTexture(
        header.width,
        header.height,
        1,
        0,
        C.D3DFMT_A8R8G8B8,
        C.D3DPOOL_MANAGED
    );

    if (result ~= C.S_OK or dx_texture == nil) then
        return nil, nil, 'dxt rgba texture create failed';
    end

    local lockResult, lockedRect = dx_texture:LockRect(0, nil, 0);
    if (lockResult ~= C.S_OK or lockedRect == nil or lockedRect.pBits == nil) then
        dx_texture:Release();
        return nil, nil, 'dxt rgba lock failed';
    end

    local dest = ffi.cast('uint8_t*', lockedRect.pBits);
    local pitch = lockedRect.Pitch;
    local mode = map_render.get_mode();
    local w = header.width;
    local h = header.height;
    local blockBytes = (imageType == IMAGE_TYPE.DXT1) and 8 or 16;
    local colorOffset = (blockBytes == 8) and 0 or 8;
    local blocksX = math.max(1, math.floor((w + 3) / 4));
    local blocksY = math.max(1, math.floor((h + 3) / 4));

    for blockY = 0, blocksY - 1 do
        for blockX = 0, blocksX - 1 do
            local blockOff = dataOffset + (blockY * blocksX + blockX) * blockBytes;
            local colorOff = blockOff + colorOffset;
            local c0 = read_u16(data, colorOff);
            local c1 = read_u16(data, colorOff + 2);
            local bits = read_u32(data, colorOff + 4);
            local colors, transparentBlack = build_dxt_color_palette(c0, c1);

            for py = 0, 3 do
                for px = 0, 3 do
                    local x = blockX * 4 + px;
                    local y = blockY * 4 + py;
                    if (x < w and y < h) then
                        local shift = (py * 4 + px) * 2;
                        local idx = bit.band(bit.rshift(bits, shift), 3) + 1;
                        local color = colors[idx];
                        local a = alpha_for_dxt_block(data, blockOff, blockBytes, imageType, px, py);
                        if (transparentBlack and idx == 4) then
                            a = 0;
                        end
                        local surfaceOffset = y * pitch + x * 4;
                        write_bgra_pixel_mode(dest, surfaceOffset, color.r, color.g, color.b, a, mode);
                    end
                end
            end
        end
    end

    dx_texture:UnlockRect(0);
    local gcTexture = d3d8.gc_safe_release(ffi.cast('IDirect3DBaseTexture8*', dx_texture));
    return gcTexture, { width = w, height = h };
end

local function should_decompress_dxt(imageType)
    if (map_render.get_mode() == 'normal') then
        return false;
    end
    return imageType == IMAGE_TYPE.BITMAP
        or imageType == IMAGE_TYPE.DXT1
        or imageType == IMAGE_TYPE.DXT2
        or imageType == IMAGE_TYPE.DXT3
        or imageType == IMAGE_TYPE.DXT4
        or imageType == IMAGE_TYPE.DXT5;
end

local function copy_dxt(data, header, offset, d3dFormat)
    local result, dx_texture = d3d8_device:CreateTexture(
        header.width,
        header.height,
        1,
        0,
        d3dFormat,
        C.D3DPOOL_MANAGED
    );

    if (result ~= C.S_OK or dx_texture == nil) then
        return nil, nil, 'dxt texture create failed';
    end

    local lockResult, lockedRect = dx_texture:LockRect(0, nil, 0);
    if (lockResult ~= C.S_OK or lockedRect == nil or lockedRect.pBits == nil) then
        dx_texture:Release();
        return nil, nil, 'dxt lock failed';
    end

    local compressedSize;
    if (header.type == IMAGE_TYPE.DXT1) then
        compressedSize = math.max(1, header.width / 4) * math.max(1, header.height / 4) * 8;
    else
        compressedSize = math.max(1, header.width / 4) * math.max(1, header.height / 4) * 16;
    end

    local src = ffi.cast('const uint8_t*', ffi.cast('const char*', data)) + offset;
    local dest = ffi.cast('uint8_t*', lockedRect.pBits);
    ffi.copy(dest, src, compressedSize);

    dx_texture:UnlockRect(0);
    local gcTexture = d3d8.gc_safe_release(ffi.cast('IDirect3DBaseTexture8*', dx_texture));
    return gcTexture, { width = header.width, height = header.height };
end

local function load_texture_from_dat(datData)
    local header, err = parse_image_header(datData, 0x41);
    if (header == nil) then
        return nil, nil, err;
    end

    if (header.width <= 0 or header.height <= 0) then
        return nil, nil, 'invalid dimensions';
    end

    local dataOffset = 0x41 + ffi.sizeof('GlamMapImageHeader');

    if (header.type == IMAGE_TYPE.BITMAP) then
        return copy_bitmap(datData, header, dataOffset);
    end

    if (should_decompress_dxt(header.type)) then
        local offset = dataOffset + 8;
        return copy_dxt_decompressed(datData, header, offset, header.type);
    end

    local d3dFormat;
    if (header.type == IMAGE_TYPE.DXT1) then
        d3dFormat = C.D3DFMT_DXT1;
    elseif (header.type == IMAGE_TYPE.DXT2) then
        d3dFormat = C.D3DFMT_DXT2;
    elseif (header.type == IMAGE_TYPE.DXT3) then
        d3dFormat = C.D3DFMT_DXT3;
    elseif (header.type == IMAGE_TYPE.DXT4) then
        d3dFormat = C.D3DFMT_DXT4;
    elseif (header.type == IMAGE_TYPE.DXT5) then
        d3dFormat = C.D3DFMT_DXT5;
    else
        return nil, nil, 'unsupported image type';
    end

    local offset = dataOffset + 8;
    return copy_dxt(datData, header, offset, d3dFormat);
end

function M.clear_active()
    M.active_key = nil;
    M.texture_id = nil;
    M.width = 0;
    M.height = 0;
end

function M.clear_all()
    M.cache = {};
    M.clear_active();
    collectgarbage('collect');
end

function M.purge_except_zone(keepZoneId)
    keepZoneId = tonumber(keepZoneId);
    if (keepZoneId == nil) then
        return;
    end

    local remove = {};
    for key, item in pairs(M.cache) do
        if (item.zoneId ~= keepZoneId) then
            remove[#remove + 1] = key;
        end
    end

    for i = 1, #remove do
        if (M.active_key == remove[i]) then
            M.clear_active();
        end
        M.cache[remove[i]] = nil;
    end

    if (#remove > 0) then
        collectgarbage('collect');
    end
end

function M.enforce_cache_limit()
    local keepZoneId = mapcore.get_player_zone();
    if (keepZoneId == nil) then
        return;
    end

    if (cache_count() > max_cache_size()) then
        M.purge_except_zone(keepZoneId);
    end
end

function M.load_entry_to_cache(zoneId, floorId)
    zoneId = tonumber(zoneId);
    floorId = tonumber(floorId);
    if (zoneId == nil or floorId == nil) then
        return nil;
    end

    local key = cache_key(zoneId, floorId);
    local cached = M.cache[key];
    if (cached ~= nil) then
        return cached;
    end

    local entry = mapcore.find_entry_by_floor(zoneId, floorId);
    if (entry == nil) then
        return nil;
    end

    local datData, datErr = mapcore.load_map_dat(entry);
    if (datData == nil) then
        return nil;
    end

    local gcTexture, info, texErr = load_texture_from_dat(datData);
    datData = nil;

    if (gcTexture == nil) then
        return nil;
    end

    cached = {
        texture_id = gcTexture,
        width = info.width,
        height = info.height,
        zoneId = zoneId,
        floorId = floorId,
    };
    M.cache[key] = cached;
    return cached;
end

function M.cache_zone(zoneId)
    zoneId = tonumber(zoneId);
    if (zoneId == nil) then
        return 0;
    end

    local floors = mapcore.get_floors_for_zone(zoneId);
    local loaded = 0;

    for i = 1, #floors do
        if (M.load_entry_to_cache(zoneId, floors[i]) ~= nil) then
            loaded = loaded + 1;
        end
    end

    M.enforce_cache_limit();
    return loaded;
end

function M.activate(zoneId, floorId)
    zoneId = tonumber(zoneId);
    floorId = tonumber(floorId);
    if (zoneId == nil or floorId == nil) then
        M.clear_active();
        mapcore.clear_map_cache();
        return false, 'invalid zone/floor';
    end

    local item = M.load_entry_to_cache(zoneId, floorId);
    if (item == nil) then
        M.clear_active();
        mapcore.clear_map_cache();
        return false, 'texture unavailable';
    end

    local mapData, err = mapcore.set_map_data_for_entry(zoneId, floorId);
    if (mapData == nil) then
        M.clear_active();
        return false, err;
    end

    M.active_key = cache_key(zoneId, floorId);
    M.texture_id = item.texture_id;
    M.width = item.width;
    M.height = item.height;
    return true;
end

function M.activate_current_floor()
    local zoneId = mapcore.get_player_zone();
    if (zoneId == nil) then
        return false, 'no zone';
    end

    M.cache_zone(zoneId);

    local x, y, z = mapcore.get_player_position();
    if (x == nil) then
        return false, 'no position';
    end

    local floorId = mapcore.get_floor_id(x, y, z);
    if (floorId == nil) then
        return false, 'floor detection failed';
    end

    return M.activate(zoneId, floorId);
end

function M.release()
    M.clear_active();
end

function M.is_ready()
    return M.texture_id ~= nil and M.width > 0 and M.height > 0;
end

return M;
