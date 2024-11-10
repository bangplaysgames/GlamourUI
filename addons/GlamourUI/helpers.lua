local chat = require('chat');
local ffi = require('ffi');

ffi.cdef[[
    typedef bool (__cdecl* isevent_f)(int8_t flag);
]];
local event_ptr = ashita.memory.find('FFXiMain.dll', 0, 'A0????????84C074??B001C366', 0, 0);
local menuBase = ashita.memory.find('FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0);

local helpers = {}

helpers.hex2bin = function(v)
    local str = tostring(v);
    local map = {
        ['0'] = '0000',
        ['1'] = '0001',
        ['2'] = '0010',
        ['3'] = '0011',
        ['4'] = '0100',
        ['5'] = '0101',
        ['6'] = '0110',
        ['7'] = '0111',
        ['8'] = '1000',
        ['9'] = '1001',
        ['a'] = '1010',
        ['b'] = '1011',
        ['c'] = '1100',
        ['d'] = '1101',
        ['e'] = '1110',
        ['f'] = '1111'
    }
    return str:gsub('[0-9A-F]', map)
end

helpers.getMenu = function()
    local subPointer = ashita.memory.read_uint32(menuBase);
    local subValue = ashita.memory.read_uint32(subPointer);
    if (subValue == 0) then
        return '';
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4);
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16);
    local menuString = string.gsub(string.gsub(string.gsub(menuName, '\x00', ''), 'menu', ''), ' ', '');
    return menuString;
end

helpers.loadLayout = function(name)
    local path = (('%s\\config\\addons\\%s\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), addon.name, name));
    gParty.layout = gHelper.LoadFile(path);
    print(chat.header(path));
end

helpers.createLayout = function(name)
    local path = ('%s\\config\\addons\\%s\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), addon.name, name);
    if ashita.fs.exists(path)then
        print(chat.header(('Layout with name: \"%s\" already exists.'):fmt(name)));
        return;
    end

    if (not ashita.fs.exists(('%s\\config\\addons\\%s\\Layouts\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, name))) then
        ashita.fs.create_directory(('%s\\config\\addons\\%s\\Layouts\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, name));
    end

    local file = io.open(path, 'w');
    if(file == nil) then
        print(chat.header(('Error Creating new Layout')));
        return;
    end;
    file:write('local layout = {\n');
    file:write('    Priority = {\n');
    file:write('        \'name\',\n');
    file:write('        \'hp\',\n');
    file:write('        \'mp\',\n');
    file:write('        \'tp\',\n');
    file:write('        \'buffs\',\n');
    file:write('        \'jobIcon\'\n');
    file:write('    },\n');
    file:write('    NamePosition = {\n');
    file:write('        x = 0,\n');
    file:write('        y = 0\n');
    file:write('    },\n');
    file:write('    HPBarPosition = {\n');
    file:write('        x = 25,\n');
    file:write('        y = 20,\n');
    file:write('        textX = 0,\n');
    file:write('        textY = 0\n');
    file:write('    },\n');
    file:write('    hpBarDim = {\n');
    file:write('        l = 200,\n');
    file:write('        g = 16\n');
    file:write('    },\n');
    file:write('    MPBarPosition = {\n');
    file:write('        x = 240,\n');
    file:write('        y = 20,\n');
    file:write('        textX = 0,\n');
    file:write('        textY = 0\n');
    file:write('    },\n');
    file:write('    mpBarDim = {\n');
    file:write('        l = 200,\n');
    file:write('        g = 16\n');
    file:write('    },\n');
    file:write('    TPBarPosition = {\n');
    file:write('        x = 455,\n');
    file:write('        y = 20,\n');
    file:write('        textX = 0,\n');
    file:write('        textY = 0\n');
    file:write('    },\n')
    file:write('    tpBarDim = {\n');
    file:write('        l = 200,\n');
    file:write('        g = 16\n');
    file:write('    },\n');
    file:write('    BuffPos = {\n');
    file:write('        x = 670,\n');
    file:write('        y = 0\n');
    file:write('    },\n');
    file:write('    jobIconPos = {\n');
    file:write('        x = 0,\n');
    file:write('        y = 0\n');
    file:write('    },\n')
    file:write('    padding = 0')
    file:write('};\n')
    file:write('return layout;')
    file:close();
end

helpers.updateLayoutFile = function(name)
    local path = ('%s\\config\\addons\\GlamourUI\\Layouts\\%s\\layout.lua'):fmt(AshitaCore:GetInstallPath(), name);

    local file = io.open(path, 'w+');
    if(file == nil) then
        print(chat.header(('Error Creating new Layout')));
        return;
    end;
    file:write('local layout = {\n');
    file:write('    Priority = {\n');
    file:write('        \'name\',\n');
    file:write('        \'hp\',\n');
    file:write('        \'mp\',\n');
    file:write('        \'tp\',\n');
    file:write('        \'buffs\',\n');
    file:write('        \'jobIcon\n');
    file:write('    },\n');
    file:write('    NamePosition = {\n');
    file:write(('        x = %s,\n'):fmt(gParty.layout.NamePosition.x));
    file:write(('        y = %s\n'):fmt(gParty.layout.NamePosition.y));
    file:write('    },\n');
    file:write('    HPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(gParty.layout.HPBarPosition.x));
    file:write(('        y = %s,\n'):fmt(gParty.layout.HPBarPosition.y));
    file:write(('       textX = %s,\n'):fmt(gParty.layout.HPBarPosition.textX));
    file:write(('       textY = %s\n'):fmt(gParty.layout.HPBarPosition.textY));
    file:write('    },\n');
    file:write('    hpBarDim = {\n');
    file:write(('        l = %s,\n'):fmt(gParty.layout.hpBarDim.l));
    file:write(('        g = %s\n'):fmt(gParty.layout.hpBarDim.g));
    file:write('    },\n')
    file:write('    MPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(gParty.layout.MPBarPosition.x));
    file:write(('        y = %s,\n'):fmt(gParty.layout.MPBarPosition.y));
    file:write(('       textX = %s,\n'):fmt(gParty.layout.MPBarPosition.textX));
    file:write(('       textY = %s\n'):fmt(gParty.layout.MPBarPosition.textY));
    file:write('    },\n');
    file:write('    mpBarDim = {\n');
    file:write(('        l = %s,\n'):fmt(gParty.layout.mpBarDim.l));
    file:write(('        g = %s\n'):fmt(gParty.layout.mpBarDim.g));
    file:write('    },\n')
    file:write('    TPBarPosition = {\n');
    file:write(('        x = %s,\n'):fmt(gParty.layout.TPBarPosition.x));
    file:write(('        y = %s,\n'):fmt(gParty.layout.TPBarPosition.y));
    file:write(('       textX = %s,\n'):fmt(gParty.layout.TPBarPosition.textX));
    file:write(('       textY = %s\n'):fmt(gParty.layout.TPBarPosition.textY));
    file:write('    },\n')
    file:write('    tpBarDim = {\n');
    file:write(('        l = %s,\n'):fmt(gParty.layout.tpBarDim.l));
    file:write(('        g = %s\n'):fmt(gParty.layout.tpBarDim.g));
    file:write('    },\n')
    file:write('    BuffPos = {\n');
    file:write(('        x = %s,\n'):fmt(gParty.layout.BuffPos.x));
    file:write(('        y = %s\n'):fmt(gParty.layout.BuffPos.y));
    file:write('    },\n');
    file:write('        jobIconPos = {\n')
    file:write(('        x = %s,\n'):fmt(gParty.layout.jobIconPos.x));
    file:write(('        y = %s\n'):fmt(gParty.layout.jobIconPos.y));
    file:write(('   },\n'))
    file:write(('    padding = %s'):fmt(gParty.layout.padding));
    file:write('};\n')
    file:write('return layout;')
    file:close();
end

helpers.LoadFile = function(filepath)
    if not ashita.fs.exists(filepath) then
        return nil;
    end

    local success, loadError = loadfile(filepath);
    if not success then
        print(string.format('Failed to load resource file: %s', filePath));
        print(string.format('Error: %s', loadError));
        return nil;
    end

    local result, output = pcall(success);
    if not result then
        print(string.format('Failed to call resource file: %s', filePath));
        print(string.format('Error: %s', loadError));
        return nil;
    end

    return output;
end

helpers.tablecontains = function(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

helpers.ArrayRemove = function(t, targ)
    local tab = {}
    for i = 1, #t do
        if(i ~= targ)then
            table.insert(tab, t[i]);
        end
    end
    return tab;
end

helpers.is_event = ffi.cast('isevent_f', event_ptr);

helpers.chatIsOpen = false;

return helpers;