require('common');

local M = {};

local state = T{
    pointer = T{ 0, 0, 0 },
    opcodes = T{ 0, 0, 0 },
    patched = false,
    tried_init = false,
};

local function init_pointers()
    if (state.tried_init) then
        return (state.pointer[1] ~= 0 and state.pointer[2] ~= 0 and state.pointer[3] ~= 0);
    end
    state.tried_init = true;

    state.pointer[1] = ashita.memory.find('FFXiMain.dll', 0, '75??8B4E0851B9', 0, 0);
    state.pointer[2] = ashita.memory.find('FFXiMain.dll', 0, '7D??33C05EC20400C6', 0, 0);
    state.pointer[3] = ashita.memory.find('FFXiMain.dll', 0, '85C00F??????????6A0232DBE8', 0, 0);

    if (state.pointer[1] == 0 or state.pointer[2] == 0 or state.pointer[3] == 0) then
        return false;
    end

    state.opcodes[1] = ashita.memory.read_uint16(state.pointer[1]);
    state.opcodes[2] = ashita.memory.read_uint16(state.pointer[2]);
    state.opcodes[3] = ashita.memory.read_uint16(state.pointer[3]);

    return true;
end

M.apply = function()
    if (state.patched) then
        return true;
    end
    if (not init_pointers()) then
        return false;
    end

    if (state.opcodes[1] == 0x9090 or state.opcodes[2] == 0x9090 or state.opcodes[3] == 0xC031) then
        return false;
    end

    ashita.memory.write_uint16(state.pointer[1], 0x9090);
    ashita.memory.write_uint16(state.pointer[2], 0x9090);
    ashita.memory.write_uint16(state.pointer[3], 0xC031);

    state.patched = true;
    return true;
end

M.remove = function()
    if (not state.patched) then
        return true;
    end
    if (state.pointer[1] ~= 0 and state.opcodes[1] ~= 0) then
        ashita.memory.write_uint16(state.pointer[1], state.opcodes[1]);
    end
    if (state.pointer[2] ~= 0 and state.opcodes[2] ~= 0) then
        ashita.memory.write_uint16(state.pointer[2], state.opcodes[2]);
    end
    if (state.pointer[3] ~= 0 and state.opcodes[3] ~= 0) then
        ashita.memory.write_uint16(state.pointer[3], state.opcodes[3]);
    end
    state.patched = false;
    return true;
end

return M;

