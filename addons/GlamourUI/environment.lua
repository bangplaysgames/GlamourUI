local environment = {}

environment.is_open = true;

local weatherpointer = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0);
local timepointer = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0);

environment.GetWeather = function()
    local ptr = ashita.memory.read_uint32(weatherpointer + 0x02);
    local weather = ashita.memory.read_uint8(ptr + 0);
    local rtn, count = gResources.GetWeatherIcon(weather);
    return rtn, count;
end

environment.GetTime = function()
    local ptr = ashita.memory.read_uint32(timepointer + 0x34);
    local time = ashita.memory.read_uint32(ptr + 0x0C) + 92514960;
    local timetable = {}
    timetable.day = (math.floor(time / 3456) % 8) + 1;
    timetable.hour = math.floor(time / 144) % 24;
    local minute = math.floor((time % 144) / 2.4);
    timetable.minute = string.format("%02d", minute);
    return timetable;
end

return environment;