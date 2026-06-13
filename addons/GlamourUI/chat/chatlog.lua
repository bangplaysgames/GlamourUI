local imgui = require('imgui');
local ffi = require('ffi');
require('common');
local compat = require('compat');
local chatRoll = require('chatRoll');

local function is_valid_status_id(id)
    id = tonumber(id);
    return id ~= nil and id >= 1 and id <= 0x3FF and id ~= 255;
end

ffi.cdef[[
    int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, uint16_t* lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const uint16_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
    void* GetModuleHandleA(const char* lpModuleName);
    typedef int32_t (__cdecl* get_config_value_t)(int32_t);
    typedef int32_t (__cdecl* set_config_value_t)(int32_t, int32_t);
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

local kernel32 = ffi.load('kernel32');
local CP_SHIFT_JIS = 932;
local CP_UTF8 = 65001;

local chatlog = T{
    suppressionDisabled = true,
    entries = T{},
    windowEntries = T{
        T{},
        T{},
    },
    recentKey = '',
    recentTime = 0,
    recentMessage = '',
    recentNormMessage = '',
    recentNormPurpose = '',
    recentNpcDialogKeys = T{},
    debug = T{
        enabled = false,
        dirReady = false,
        dir = nil,
        file1 = 'chat_window1.log',
        file2 = 'chat_window2.log',
        fileTextInNotShown = 'chat_text_in_not_shown.log',
    },
    lastInputPurpose = 'Say',
    lastTellFrom = nil,
    lastTellTo = nil,
    lastCombatPacketEmitClock = nil,
    recentTrustCastByPlayer = T{},
    fsTextInputDisplay = T{
        ready = false,
        source = 'uninitialized',
        globalAddress = 0,
        objectAddress = 0,
        modeOffset = 0x1A,
    },
    fsPreParser = T{
        ready = false,
        source = 'uninitialized',
        ptrAddress = 0,
        objectAddress = 0,
        resolvedHeaderOffset = 0x08,
        offsetDefaultHeader = 0x08,
        offsetCurrentIndex = 0x0108,
    },
    persist = T{
        loaded = false,
        lastWriteClock = 0,
        writeIntervalSec = 10.0,
        keepLines = 1000,
        filename = 'chat_persist.lua',
    },
};


local function glam_no_chat_suppression()
    local chatSettings = GlamourUI.settings and GlamourUI.settings.Chat;
    if (chatSettings ~= nil and chatSettings.suppressionDisabled ~= nil) then
        return chatSettings.suppressionDisabled == true;
    end
    return chatlog.suppressionDisabled == true;
end

local recentRollEvent = chatRoll.recentRollEvent;
local recentPacketChatLines = {};
local recentPacketChatLinesLastPruneClock = 0;
local lastNpcDialog = { sender = nil, time = 0 };

local normalize_for_dedupe;
local clean_str = nil;

local rollAuxPruneAt = 0;
local function maybe_prune_roll_aux_tables(now)
    if ((now - rollAuxPruneAt) < 1.25) then
        return;
    end
    rollAuxPruneAt = now;
    chatRoll.prune_roll_events(now);
end

local function maybe_prune_recent_packet_chat(now)
    now = tonumber(now) or os.clock();
    local last = tonumber(recentPacketChatLinesLastPruneClock) or 0;
    if ((now - last) < 1.0) then
        return;
    end
    recentPacketChatLinesLastPruneClock = now;
    for k, t in pairs(recentPacketChatLines) do
        local ts = (type(t) == 'table') and tonumber(t.time) or tonumber(t);
        if ((now - (ts or 0)) > 1.0) then
            recentPacketChatLines[k] = nil;
        end
    end
end

local function record_packet_chat_line(message, shown)
    local now = os.clock();
    local m = tostring(message or '');
    shown = (shown == true);

    local keys = {
        normalize_for_dedupe(m),
        normalize_for_dedupe(clean_str(m)),
    };
    for i = 1, #keys do
        local key = keys[i];
        if (key ~= nil and key ~= '') then
            recentPacketChatLines[key] = { time = now, shown = shown };
        end
    end
    maybe_prune_recent_packet_chat(now);
end

local function record_linkshell_echo_dedupe_keys(sender, purpose, bodyText)
    if (purpose ~= 'LS[1]' and purpose ~= 'LS[2]') then
        return;
    end
    if (sender == nil or sender == '' or sender == 'System') then
        return;
    end
    local slot = (purpose == 'LS[2]') and 2 or 1;
    local name = tostring(sender):gsub('%z.*', '');
    local body = tostring(bodyText or '');
    local synthetic = ('[%u]<%s> %s'):fmt(slot, name, body);
    local now = os.clock();
    local keys = {
        normalize_for_dedupe(synthetic),
        normalize_for_dedupe(clean_str(synthetic)),
    };
    for i = 1, #keys do
        local key = keys[i];
        if (key ~= nil and key ~= '') then
            recentPacketChatLines[key] = { time = now, shown = true };
        end
    end
    maybe_prune_recent_packet_chat(now);
end

local function record_party_echo_dedupe_keys(sender, purpose, bodyText)
    if (purpose ~= 'Party') then
        return;
    end
    if (sender == nil or sender == '' or sender == 'System') then
        return;
    end
    local name = tostring(sender):gsub('%z.*', '');
    local body = tostring(bodyText or '');
    local synthetics = {
        ('(%s) %s'):fmt(name, body),
        ('(%s) %s'):fmt('<' .. name .. '>', body),
    };
    local now = os.clock();
    for s = 1, #synthetics do
        local syn = synthetics[s];
        local keys = {
            normalize_for_dedupe(syn),
            normalize_for_dedupe(clean_str(syn)),
        };
        for i = 1, #keys do
            local key = keys[i];
            if (key ~= nil and key ~= '') then
                recentPacketChatLines[key] = { time = now, shown = true };
            end
        end
    end
    maybe_prune_recent_packet_chat(now);
end

local function record_say_echo_dedupe_keys(sender, bodyText)
    if (sender == nil or sender == '' or sender == 'System') then
        return;
    end
    local name = tostring(sender):gsub('%z.*', '');
    local body = tostring(bodyText or '');
    local synthetics = {
        ('%s : %s'):fmt(name, body),
        ('%s: %s'):fmt(name, body),
    };
    local now = os.clock();
    for s = 1, #synthetics do
        local syn = synthetics[s];
        local keys = {
            normalize_for_dedupe(syn),
            normalize_for_dedupe(clean_str(syn)),
        };
        for i = 1, #keys do
            local key = keys[i];
            if (key ~= nil and key ~= '') then
                recentPacketChatLines[key] = { time = now, shown = true };
            end
        end
    end
    maybe_prune_recent_packet_chat(now);
end

local function packet_echo_dup_match_keys(message)
    local m = tostring(message or '');
    local keys = {
        normalize_for_dedupe(m),
        normalize_for_dedupe(clean_str(m)),
    };
    local lsBody = m:match('^%[%d+%]<[^>]+>%s*(.*)$');
    if (lsBody ~= nil and lsBody ~= '') then
        keys[#keys + 1] = normalize_for_dedupe(lsBody);
        keys[#keys + 1] = normalize_for_dedupe(clean_str(lsBody));
    end
    local partyBody = m:match('^%(%<[^>]+%>)%s*(.*)$');
    if (partyBody == nil or partyBody == '') then
        partyBody = m:match('^%([^)]+%)%s*(.*)$');
    end
    if (partyBody ~= nil and partyBody ~= '') then
        keys[#keys + 1] = normalize_for_dedupe(partyBody);
        keys[#keys + 1] = normalize_for_dedupe(clean_str(partyBody));
    end
    local sayBody = m:match('^%s*[^:]+:%s*(.+)$');
    if (sayBody ~= nil and sayBody ~= '') then
        keys[#keys + 1] = normalize_for_dedupe(sayBody);
        keys[#keys + 1] = normalize_for_dedupe(clean_str(sayBody));
    end
    return keys;
end

local function recent_packet_dup_hit(keys)
    local now = os.clock();
    local win = 0.45;
    for i = 1, #keys do
        local key = keys[i];
        if (key ~= nil and key ~= '') then
            local last = recentPacketChatLines[key];
            local ts = (type(last) == 'table') and tonumber(last.time) or tonumber(last);
            local shown = (type(last) == 'table') and (last.shown == true);
            if (ts ~= nil and shown and (now - ts) < win) then
                return true;
            end
        end
    end
    return false;
end

--CatseyeXI FoV/GoV progress strings
local function message_is_experience_line(text)
    local s = tostring(text or ''):lower();
    if (s == '') then
        return false;
    end
    if (s:find('experience point', 1, true)) then
        return true;
    end
    if (s:find('exp chain', 1, true) or s:find('limit chain', 1, true) or s:find('capacity chain', 1, true)) then
        return true;
    end
    if (s:find('capacity point', 1, true) or s:find('limit point', 1, true)) then
        return true;
    end
    if (s:find('no experience points', 1, true) or s:find('too far from the battle to gain experience', 1, true)) then
        return true;
    end
    return false;
end

local function tag_experience_chat_entry(entry)
    if (entry == nil or not message_is_experience_line(entry.message)) then
        return;
    end
    entry.experienceLine = true;
    entry.channel = 'combat';
    if (entry.purpose == nil or entry.purpose == '' or entry.purpose == 'NPC') then
        entry.purpose = 'None';
    end
    if (entry.sender == nil or entry.sender == '') then
        entry.sender = 'System';
    end
end

local function message_is_catseye_gov_progress(text)
    local lt = tostring(text or ''):lower();
    if (lt:find('defeat mobs', 1, true)) then
        return true;
    end
    if (lt:find('conflict:', 1, true)) then
        return true;
    end
    if (lt:find('training regime', 1, true) or lt:find('field manual', 1, true) or lt:find('regime', 1, true)
        or lt:find('grounds of valor', 1, true) or lt:find('fields of valor', 1, true)) then
        return true;
    end
    return false;
end

local function should_suppress_as_packet_chat_dup(message)
    if (glam_no_chat_suppression()) then
        return false;
    end
    return recent_packet_dup_hit(packet_echo_dup_match_keys(message));
end

local function should_suppress_packet_echo_dup_always(message)
    return recent_packet_dup_hit(packet_echo_dup_match_keys(message));
end

local NPC_DIALOG_DEDUPE_SEC = 3.0;

local function npc_dialog_dedupe_keys(sender, message)
    local norm = normalize_for_dedupe(message);
    if (norm == nil or norm == '') then
        return {};
    end
    local keys = {
        'NPC||' .. norm,
    };
    local senderNorm = normalize_for_dedupe(tostring(sender or ''));
    if (senderNorm ~= nil and senderNorm ~= '') then
        keys[#keys + 1] = ('NPC|%s|%s'):fmt(senderNorm, norm);
    end
    return keys;
end

local function prune_npc_dialog_keys(now)
    now = tonumber(now) or os.clock();
    local keys = chatlog.recentNpcDialogKeys;
    if (keys == nil) then
        return;
    end
    for k, t in pairs(keys) do
        if ((now - (tonumber(t) or 0)) > NPC_DIALOG_DEDUPE_SEC) then
            keys[k] = nil;
        end
    end
end

local function npc_dialog_is_duplicate(sender, message, now)
    now = tonumber(now) or os.clock();
    prune_npc_dialog_keys(now);
    local keys = npc_dialog_dedupe_keys(sender, message);
    local seen = chatlog.recentNpcDialogKeys or T{};
    for i = 1, #keys do
        local key = keys[i];
        if (key ~= nil and key ~= '' and seen[key] ~= nil) then
            return true;
        end
    end
    return false;
end

local function npc_dialog_mark_seen(sender, message, now)
    now = tonumber(now) or os.clock();
    if (chatlog.recentNpcDialogKeys == nil) then
        chatlog.recentNpcDialogKeys = T{};
    end
    local keys = npc_dialog_dedupe_keys(sender, message);
    for i = 1, #keys do
        local key = keys[i];
        if (key ~= nil and key ~= '') then
            chatlog.recentNpcDialogKeys[key] = now;
        end
    end
    prune_npc_dialog_keys(now);
end

local function should_suppress_npc_dialog_dup(sender, message)
    return npc_dialog_is_duplicate(sender, message, os.clock());
end
local get_purpose_color = nil;

local venturesEchoUntil = 0;


local function looks_like_formatted_chat_echo(msg, playerName)
    if (msg == nil or msg == '') then
        return false;
    end
    if (msg:match('^%[%d+%]<[^>]+>%s*')) then
        return true;
    end
    if (msg:match('^%(%<[^>]+%>)%s*')) then
        return true;
    end
    if (msg:match('^%([^)]+%)%s*')) then
        return true;
    end
    if (msg:match('^%{[^}]+%}%s*')) then
        return true;
    end
    if (msg:match('^[^%[%]]+%[[^%]]+%]:%s')) then
        return true;
    end
    if (playerName ~= nil and playerName ~= '') then
        if (msg:match('^' .. playerName:gsub('(%W)', '%%%1') .. '%s*:%s+')) then
            return true;
        end
    end
    if (msg:match('^%S+>>%s*.+$')) then
        return true;
    end
    return false;
end

local nativeConfig = T{
    ready = false,
    get = nil,
    set = nil,
};

local function ensure_chat_settings()
    return GlamourUI.settings.Chat or T{};
end

local function get_player_name_safe()
    local player = GetPlayerEntity();
    if (player ~= nil and player.Name ~= nil and player.Name ~= '') then
        return player.Name;
    end

    return 'You';
end

local function initialize_native_config()
    if (nativeConfig.ready) then
        return true;
    end

    local ptr = ashita.memory.find(0, 0, '8B0D????????85C974??8B44240450E8????????C383C8FFC3', 0, 0);
    if (ptr == nil or ptr == 0) then
        return false;
    end

    nativeConfig.get = ffi.cast('get_config_value_t', ptr);
    nativeConfig.set = ffi.cast('set_config_value_t', ashita.memory.find(0, 0, '85C974??8B4424088B5424045052E8????????C383C8FFC3', -6, 0));
    nativeConfig.ready = nativeConfig.get ~= nil and nativeConfig.set ~= nil;
    return nativeConfig.ready;
end

local function apply_native_chatline_override(force)
    local chatSettings = ensure_chat_settings();
    if (chatSettings.forceNativeChatHidden ~= true) then
        return;
    end

    if (not initialize_native_config()) then
        return;
    end

    if (force ~= true and nativeConfig.get ~= nil and nativeConfig.get(15) == 0) then
        return;
    end

    nativeConfig.set(15, 0);
end

-- CP932 / Shift-JIS maps wire byte 0x5C to U+00A5 (yen). FFXI uses 0x5C as ASCII backslash.
local SJIS_YEN_UTF8 = '\xc2\xa5';
local SJIS_WIDE_YEN = 0x00A5;
local ASCII_BACKSLASH = '\\';
-- Fullwidth reverse solidus: CJK fonts render this as "\\", not "¥".
local DISPLAY_BACKSLASH = '\xef\xbc\xbc';

local function normalize_sjis_yen_to_backslash(s)
    if (s == nil or s == '') then
        return s;
    end
    return tostring(s):gsub(SJIS_YEN_UTF8, ASCII_BACKSLASH);
end

local function normalize_backslash_for_display(s)
    if (s == nil or s == '') then
        return s;
    end

    s = normalize_sjis_yen_to_backslash(s);
    if (GlamourUI ~= nil and GlamourUI.backslashGlyphMerged == true) then
        return s;
    end
    return s:gsub(ASCII_BACKSLASH, DISPLAY_BACKSLASH);
end

local function normalize_ffxi_star_glyph(s)
    if (s == nil or s == '') then
        return s;
    end
    return tostring(s)
        :gsub(string.char(0x81, 0x9A), '★')
        :gsub('笘・', '★')
        :gsub('\xe2\x80\xbb', '★')   -- CP932 0x819A → ※
        :gsub('\xef\xbc\x8a', '★');  -- fullwidth asterisk
end

local function normalize_utf8_arrow_glyphs(s)
    if (s == nil) then
        return '';
    end
    s = tostring(s);
    s = s:gsub(string.char(129, 168), '→');
    s = s
        :gsub('çŤăť', '→')
        :gsub('â', '→')
        :gsub('竊・', '→')
        :gsub('竊探', '→')
        :gsub('\226\134\146', '→');
    s = s
        :gsub('â†', '←')
        :gsub('\226\134\144', '←');
    s = normalize_sjis_yen_to_backslash(s);
    return normalize_ffxi_star_glyph(s);
end

local function prepare_sjis_wire_text(str)
    if (str == nil or #str == 0) then
        return str;
    end
    str = str:gsub(string.char(0x81, 0x40), ' ');
    str = str:gsub(string.char(0x07), ' ');
    return str;
end

local function post_decode_utf8_normalize(result)
    if (result == nil or result == '') then
        return result or '';
    end
    result = result
        :gsub('\xe3\x80\x80', ' ')
        :gsub('\xc2\xa0', ' ');
    result = result
        :gsub('\xe3\x80\x9c', '\xef\xbd\x9e')
        :gsub('\xe2\x88\xbc', '\xef\xbd\x9e')
        :gsub('ã€œ', '～')
        :gsub('ï½ž', '～');
    result = result
        :gsub('([%w])・([%w])', '%1 %2')
        :gsub('([%w])･([%w])', '%1 %2');
    result = normalize_sjis_yen_to_backslash(result);
    return normalize_utf8_arrow_glyphs(result);
end

local function shift_jis_wire_to_utf8(str)
    if (str == nil or #str == 0) then
        return '';
    end

    str = prepare_sjis_wire_text(str);

    local wideLen = kernel32.MultiByteToWideChar(CP_SHIFT_JIS, 0, str, #str, nil, 0);
    if (wideLen <= 0) then
        return str;
    end

    local wideBuffer = ffi.new('uint16_t[?]', wideLen + 1);
    if (kernel32.MultiByteToWideChar(CP_SHIFT_JIS, 0, str, #str, wideBuffer, wideLen) <= 0) then
        return str;
    end

    for j = 0, wideLen - 1 do
        if (wideBuffer[j] == SJIS_WIDE_YEN) then
            wideBuffer[j] = 0x005C;
        end
    end

    local utf8Len = kernel32.WideCharToMultiByte(CP_UTF8, 0, wideBuffer, wideLen, nil, 0, nil, nil);
    if (utf8Len <= 0) then
        return str;
    end

    local utf8Buffer = ffi.new('char[?]', utf8Len + 1);
    if (kernel32.WideCharToMultiByte(CP_UTF8, 0, wideBuffer, wideLen, utf8Buffer, utf8Len, nil, nil) <= 0) then
        return str;
    end

    return post_decode_utf8_normalize(ffi.string(utf8Buffer, utf8Len));
end

local function sjis_to_utf8(str)
    return shift_jis_wire_to_utf8(str);
end

clean_str = function(str)
    if (str == nil) then
        return '';
    end

    str = AshitaCore:GetChatManager():ParseAutoTranslate(str, true);
    str = str:strip_colors();
    str = str:strip_translate(true);
    str = str:gsub(string.char(0x07), ' ');
    str = str:gsub('[\x00-\x06\x08\x0B\x0C\x0E-\x1F]', '');

    while (true) do
        local hasN = str:endswith('\n');
        local hasR = str:endswith('\r');
        if (not hasN and not hasR) then
            break;
        end
        if (hasN) then
            str = str:trimend('\n');
        end
        if (hasR) then
            str = str:trimend('\r');
        end
    end

    return shift_jis_wire_to_utf8(str);
end



local function setmode(m)
    if(m == 0x00 or m == 0x0d)then
        return 'Say';
    elseif(m == 0x01 or m == 0x0e)then
        return 'Shout';
    elseif(m == 0x02)then
        return 'None';
    elseif(m == 0x03)then
        return 'Tell';
    elseif(m == 0x0a or m == 0x0b or m == 0x0c)then
        return 'Emote';
    elseif(m == 0x04)then
        return 'Party';
    elseif(m == 0x0f)then
        return 'Emote';
    elseif(m == 0x05 or m == 0x10)then
        return 'LS[1]';
    elseif(m == 0x06 or m == 0x07)then
        return 'System';
    elseif(m == 0x14)then
        return 'Damage Dealt';
    elseif(m == 0x15 or m == 0x6e)then
        return 'Mob Ready';
    elseif(m == 0x1a)then
        return 'Yell';
    elseif(m == 0x1b)then
        return 'LS[2]';
    elseif(m == 0x1c)then
        return 'Damage Taken';
    elseif(m == 0x1d)then
        return 'Miss';
    elseif(m == 0x16 or m == 0x1f)then
        return 'HP Recovered';
    elseif(m == 0x21)then
        return 'Unity';
    elseif(m == 0x22)then
        return 'Assist[J]';
    elseif(m == 0x23)then
        return 'Assist[E]';
    elseif(m == 0x24)then
        return 'Kill';
    elseif(m == 0x32 or m == 0x34)then
        return 'Spell Cast';
    elseif(m == 0x38 or m == 0x65)then
        return 'Add Effect';
    elseif(m == 0x40)then
        return 'Remove Debuff';
    elseif(m == 0x41)then
        return 'Add Debuff';
    elseif(m == 0x7a)then
        return 'Interrupted';
    elseif(m == 0x7b)then
        return 'None';
    elseif(m == 0x7f)then
        return 'After Battle';
    elseif(m == 0x83)then
        return 'Spoils';
    elseif(m == 0xbf)then
        return 'Lose Effect';
    elseif(m == 0xd1)then
        return 'Ability Not Ready';
    elseif(m == 0x296)then
        return 'NPC';
    elseif(m == 0x28e)then
        return 'NPC';
    elseif(m == 0x40000ce or m == 0x50000ce)then
        return 'Echo';
    elseif(m == 0x500009d or m == 0x9d)then
        return 'Command Error';
    end

    return 'None';
end

local function resolve_mode(m)
    local mm = tonumber(m) or 0;
    local mode = setmode(mm);
    if (mode ~= 'None') then
        return mode, mm;
    end

    local lowWord = bit.band(mm, 0xFFFF);
    mode = setmode(lowWord);
    if (mode ~= 'None') then
        return mode, lowWord;
    end

    return 'None', mm;
end

local suppress_text_in_for_battle_log_purpose = {
    ['Damage Dealt'] = true,
    ['Mob Ready'] = true,
    ['Damage Taken'] = true,
    ['Miss'] = true,
    ['HP Recovered'] = true,
    ['Kill'] = true,
    ['Spell Cast'] = true,
    ['Add Effect'] = true,
    ['Remove Debuff'] = true,
    ['Add Debuff'] = true,
    ['Interrupted'] = true,
    ['After Battle'] = true,
    ['Spoils'] = true,
    ['Lose Effect'] = true,
    ['Ability Not Ready'] = true,
    ['Assist[J]'] = true,
    ['Assist[E]'] = true,
};

local function should_suppress_battle_log_text_in_echo(entry, modeWord)
    local purpose = entry.purpose;
    local msg = entry.message;
    if (purpose == 'Miss' and msg ~= nil and msg:find('Venture mobs must be', 1, true)) then
        return false;
    end
    local lowPurpose = setmode(bit.band(tonumber(modeWord) or 0, 0xFFFF));
    if (suppress_text_in_for_battle_log_purpose[purpose]
        or suppress_text_in_for_battle_log_purpose[lowPurpose]) then
        return true;
    end
    return false;
end

local function message_looks_like_broken_trust_join_echo(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    msg = tostring(msg);
    if (msg:match('^%([^)]+%)%s+%.$') ~= nil) then
        return true;
    end
    if (msg:match('^%([^)]+%)%s+%${item}$') ~= nil) then
        return true;
    end
    if (msg:match('^%([^)]+%)%s+Indi%-') ~= nil or msg:match('^%([^)]+%)%s+Geo%-') ~= nil) then
        return true;
    end
    return false;
end

local function should_suppress_system_mode_combat_text_in_echo(entry)
    if (entry.injected) then
        return false;
    end
    if (entry.experienceLine == true or message_is_experience_line(entry.message)) then
        return false;
    end
    if (entry.channel ~= 'system' or entry.sender ~= 'System' or entry.purpose ~= 'System') then
        return false;
    end
    local msg = entry.message;
    if (msg == nil or #msg < 12) then
        return false;
    end
    if (msg:find('Venture mobs must be', 1, true)) then
        return false;
    end
    local last = chatlog.lastCombatPacketEmitClock;
    if (last == nil) then
        return false;
    end
    return (os.clock() - last) <= 0.12;
end

local function looks_like_retail_battle_message_echo(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    msg = tostring(msg);
    if (msg:find('points of damage', 1, true)) then
        return true;
    end
    if (msg:find('scores a critical hit', 1, true)) then
        return true;
    end
    if (msg:match('recovers %d+ HP')) then
        return true;
    end
    if (msg:find('completely resists the spell', 1, true)) then
        return true;
    end
    if (msg:find('resists the spell', 1, true)) then
        return true;
    end
    if (msg:find(' casts ', 1, true) and msg:find('resists', 1, true)) then
        return true;
    end
    if (msg:find('anticipates the attack', 1, true)) then
        return true;
    end
    if (msg:find('dodges the attack', 1, true)) then
        return true;
    end
    return false;
end

local function should_suppress_retail_battle_message_echo(entry)
    if (entry.injected == true) then
        return false;
    end
    if (entry.experienceLine == true or message_is_experience_line(entry.message)) then
        return false;
    end
    if (entry.sender ~= 'System') then
        return false;
    end
    if (not looks_like_retail_battle_message_echo(entry.message)) then
        return false;
    end
    local last = chatlog.lastCombatPacketEmitClock;
    if (last == nil) then
        return false;
    end
    return (os.clock() - last) <= 4.0;
end

local function message_looks_like_retail_miss_battle_sentence(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    msg = tostring(msg);
    if (msg:find('misses the', 1, true) or msg:find('missed the', 1, true)) then
        return true;
    end
    if (msg:find(' misses ', 1, true) or msg:find(' missed ', 1, true)) then
        return true;
    end
    if (msg:find('anticipates the attack', 1, true)) then
        return true;
    end
    if (msg:find('dodges the attack', 1, true)) then
        return true;
    end
    if (msg:find('blocks ', 1, true) and msg:find("'s attack", 1, true)) then
        return true;
    end
    return false;
end

local function message_looks_like_retail_parry_battle_sentence(msg)
    if (msg == nil or msg == '') then
        return false;
    end
    msg = tostring(msg);
    if (not msg:find(' parries ', 1, true)) then
        return false;
    end
    if (not msg:find('attack with', 1, true)) then
        return false;
    end
    return msg:find('weapon', 1, true);
end

local function reclassify_routed_miss_battle_line(entry)
    local msg = entry.message;
    if (not message_looks_like_retail_miss_battle_sentence(msg)
        and not message_looks_like_retail_parry_battle_sentence(msg)) then
        return;
    end
    if (entry.purpose ~= 'Yell' and entry.purpose ~= 'None' and entry.purpose ~= 'Unity') then
        return;
    end
    entry.purpose = 'Miss';
    entry.sender = 'Battle';
    entry.channel = 'combat';
end

local function reclassify_addon_bracket_system_line(entry)
    local msg = entry.message;
    if (msg == nil or msg == '') then
        return;
    end
    local tag = msg:match('^%[([^%]]+)%]');
    if (tag == nil or tag == '' or not tag:find('[%w]')) then
        return;
    end
    entry.purpose = 'None';
    entry.sender = 'System';
    entry.channel = 'system';
    entry.purposeLabel = nil;
end

local isChatMode = {
    ['Say'] = true,
    ['Shout'] = true,
    ['Tell'] = true,
    ['Party'] = true,
    ['Emote'] = true,
    ['LS[1]'] = true,
    ['LS[2]'] = true,
    ['System'] = true,
    ['Unity'] = true,
    ['Assist[J]'] = true,
    ['Assist[E]'] = true,
    ['Yell'] = true,
    ['GoV'] = true,
};

normalize_for_dedupe = function(str)
    if (str == nil or str == '') then
        return '';
    end

    str = str:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ');
    return str;
end

local FS_PRE_PARSER_SIG = '8B0D????????5685C975??8B4424105EF7D8C383';
local FS_PRE_PARSER_PTR_OFFSET = 2;

-- FS_CMD_INDEX from g_fsPreParser TOKEN_TBL (screenshot / client RE).
local FS_CMD_INDEX_TO_PURPOSE = {
    [0] = 'Say',
    [1] = 'Shout',
    [2] = 'Tell',
    [3] = 'Party',
    [4] = 'LS[1]',
    [5] = 'Emote',
    [6] = 'Emote',
    [9] = 'Unity',
    [10] = 'LS[2]',
    [11] = 'Assist[J]',
    [12] = 'Assist[E]',
};

local function purpose_from_fs_cmd_index(index)
    index = tonumber(index);
    if (index == nil or index < 0 or index == 0xFF) then
        return nil;
    end
    return FS_CMD_INDEX_TO_PURPOSE[index];
end

local function initialize_fs_text_input_display()
    if (chatlog.fsTextInputDisplay.ready) then
        return (chatlog.fsTextInputDisplay.globalAddress or 0) ~= 0;
    end

    local globalAddress = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????E8????????84C074??6683451AF06A00', 2, 0);
    if (globalAddress == nil or globalAddress == 0) then
        globalAddress = ashita.memory.find(0, 0, '8B0D????????E8????????84C074??6683451AF06A00', 2, 0);
    end
    if (globalAddress == nil or globalAddress == 0) then
        chatlog.fsTextInputDisplay.source = 'unresolved';
        chatlog.fsTextInputDisplay.ready = true;
        chatlog.fsTextInputDisplay.globalAddress = 0;
        return false;
    end

    chatlog.fsTextInputDisplay.source = 'signature';
    chatlog.fsTextInputDisplay.ready = true;
    chatlog.fsTextInputDisplay.globalAddress = globalAddress;
    return true;
end

local FS_CMD_NAME_TO_PURPOSE = {
    ['say'] = 'Say',
    ['s'] = 'Say',
    ['shout'] = 'Shout',
    ['sh'] = 'Shout',
    ['tell'] = 'Tell',
    ['t'] = 'Tell',
    ['party'] = 'Party',
    ['p'] = 'Party',
    ['linkshell'] = 'LS[1]',
    ['l'] = 'LS[1]',
    ['linkshell2'] = 'LS[2]',
    ['l2'] = 'LS[2]',
    ['emote'] = 'Emote',
    ['em'] = 'Emote',
    ['message'] = 'Emote',
    ['me'] = 'Emote',
    ['unity'] = 'Unity',
    ['u'] = 'Unity',
    ['assistj'] = 'Assist[J]',
    ['aj'] = 'Assist[J]',
    ['assiste'] = 'Assist[E]',
    ['ae'] = 'Assist[E]',
};

local function initialize_fs_pre_parser()
    if (chatlog.fsPreParser.ready and (chatlog.fsPreParser.ptrAddress or 0) ~= 0) then
        return true;
    end

    chatlog.fsPreParser.ready = false;
    chatlog.fsPreParser.ptrAddress = 0;
    chatlog.fsPreParser.objectAddress = 0;

    local ptrAddress = ashita.memory.find('FFXiMain.dll', 0, FS_PRE_PARSER_SIG, FS_PRE_PARSER_PTR_OFFSET, 0);
    if (ptrAddress == nil or ptrAddress == 0) then
        ptrAddress = ashita.memory.find(0, 0, FS_PRE_PARSER_SIG, FS_PRE_PARSER_PTR_OFFSET, 0);
    end
    if (ptrAddress == nil or ptrAddress == 0) then
        ptrAddress = ashita.memory.find('FFXiMain.dll', 0, FS_PRE_PARSER_SIG, 0, 0);
    end

    chatlog.fsPreParser.ready = true;
    if (ptrAddress == nil or ptrAddress == 0) then
        local fallback = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????E8????????84C074??6683451AF06A00', 2, 0);
        if (fallback == nil or fallback == 0) then
            fallback = ashita.memory.find(0, 0, '8B0D????????E8????????84C074??6683451AF06A00', 2, 0);
        end
        if (fallback ~= nil and fallback ~= 0) then
            chatlog.fsPreParser.source = 'signature_textinput_fallback';
            chatlog.fsPreParser.ptrAddress = fallback;
            return true;
        end
        chatlog.fsPreParser.source = 'unresolved';
        return false;
    end

    chatlog.fsPreParser.source = 'signature';
    chatlog.fsPreParser.ptrAddress = ptrAddress;
    return true;
end

local function normalize_fs_header_string(header)
    if (header == nil or header == '') then
        return nil;
    end
    header = tostring(header):gsub('%z.*$', ''):gsub('%s+$', '');
    if (header == '') then
        return nil;
    end
    return header;
end

local function purpose_from_header_text(header)
    header = normalize_fs_header_string(header);
    if (header == nil) then
        return nil;
    end

    local cmd = header:match('^/?%s*([^%s]+)');
    if (cmd ~= nil and cmd ~= '') then
        return FS_CMD_NAME_TO_PURPOSE[cmd:lower()];
    end

    return nil;
end

local function read_fs_default_header_at(obj, headerOffset)
    obj = tonumber(obj) or 0;
    headerOffset = tonumber(headerOffset) or 0x08;
    if (obj == 0) then
        return nil;
    end

    local header = ashita.memory.read_string(obj + headerOffset, 128);
    header = normalize_fs_header_string(header);
    if (header == nil) then
        return nil;
    end
    if (purpose_from_header_text(header) == nil) then
        return nil;
    end
    return header;
end

local function scan_fs_header_in_object(obj)
    obj = tonumber(obj) or 0;
    if (obj == 0) then
        return nil, nil;
    end

    local preferred = { 0x08, 0x00, 0x10, 0x18, 0x20, 0x28 };
    for i = 1, #preferred do
        local header = read_fs_default_header_at(obj, preferred[i]);
        if (header ~= nil) then
            return header, preferred[i];
        end
    end

    for off = 0, 0x180 do
        if (ashita.memory.read_uint8(obj + off) == 0x2F) then
            local header = read_fs_default_header_at(obj, off);
            if (header ~= nil) then
                return header, off;
            end
        end
    end

    return nil, nil;
end

local function collect_fs_object_candidates(ptrAddress)
    local candidates = {};
    local seen = {};
    local function add_candidate(addr)
        addr = tonumber(addr) or 0;
        if (addr ~= 0 and seen[addr] == nil) then
            seen[addr] = true;
            candidates[#candidates + 1] = addr;
        end
    end

    ptrAddress = tonumber(ptrAddress) or 0;
    if (ptrAddress == 0) then
        return candidates;
    end

    local p1 = ashita.memory.read_uint32(ptrAddress) or 0;
    add_candidate(p1);
    add_candidate(ptrAddress);
    if (p1 ~= 0) then
        add_candidate(ashita.memory.read_uint32(p1) or 0);
    end

    return candidates;
end

local function resolve_fs_pre_parser_object(ptrAddress)
    ptrAddress = tonumber(ptrAddress) or 0;
    if (ptrAddress == 0) then
        return 0, nil, nil;
    end

    local candidates = collect_fs_object_candidates(ptrAddress);
    for i = 1, #candidates do
        local base = candidates[i];
        local header, off = scan_fs_header_in_object(base);
        if (header ~= nil) then
            chatlog.fsPreParser.objectAddress = base;
            chatlog.fsPreParser.resolvedHeaderOffset = off;
            return base, off, header;
        end
    end

    local fallbackObj = candidates[1] or 0;
    if (fallbackObj ~= 0) then
        chatlog.fsPreParser.objectAddress = fallbackObj;
        chatlog.fsPreParser.resolvedHeaderOffset = 0x08;
    end
    return fallbackObj, 0x08, nil;
end

local function read_fs_pre_parser_object()
    chatlog.fsPreParser.objectAddress = 0;
    chatlog.fsPreParser.resolvedHeaderOffset = nil;

    if (not initialize_fs_pre_parser()) then
        return 0;
    end

    local ptrAddress = chatlog.fsPreParser.ptrAddress or 0;
    if (ptrAddress == 0) then
        return 0;
    end

    local obj = resolve_fs_pre_parser_object(ptrAddress);
    return obj;
end

local function read_fs_default_header(obj)
    obj = tonumber(obj) or read_fs_pre_parser_object();
    if (obj == 0) then
        return nil;
    end

    local header, off = scan_fs_header_in_object(obj);
    if (header ~= nil) then
        chatlog.fsPreParser.resolvedHeaderOffset = off;
        return header;
    end

    local fallbackOff = tonumber(chatlog.fsPreParser.resolvedHeaderOffset)
        or tonumber(chatlog.fsPreParser.offsetDefaultHeader)
        or 0x08;
    return read_fs_default_header_at(obj, fallbackOff);
end

local function read_fs_cmd_index(obj)
    obj = tonumber(obj) or 0;
    if (obj == 0) then
        return nil;
    end

    local idxOff = tonumber(chatlog.fsPreParser.offsetCurrentIndex) or 0x0108;
    local idx = ashita.memory.read_uint32(obj + idxOff);
    if (purpose_from_fs_cmd_index(idx) ~= nil) then
        return idx;
    end

    return nil;
end

local function get_native_input_mode_word()
    if (not initialize_fs_text_input_display()) then
        return nil;
    end
    local ga = chatlog.fsTextInputDisplay.globalAddress or 0;
    if (ga == 0) then
        return nil;
    end
    local obj = ashita.memory.read_uint32(ga) or 0;
    chatlog.fsTextInputDisplay.objectAddress = obj;
    if (obj == 0) then
        return nil;
    end
    local off = tonumber(chatlog.fsTextInputDisplay.modeOffset) or 0x1A;
    local mode = ashita.memory.read_uint16(obj + off);
    if (mode == nil or mode == 0) then
        return nil;
    end
    return mode;
end

local function parse_input_prefix(inputText)
    local raw = tostring(inputText or '');
    local trimmed = raw:gsub('^%s+', '');
    if (trimmed == '') then
        return nil;
    end
    if (trimmed:sub(1, 1) ~= '/') then
        return nil;
    end

    local cmd = trimmed:match('^/([^%s]+)') or '';
    cmd = cmd:lower();

    local function parse_next_word(afterCmd)
        if (afterCmd == nil) then
            return nil;
        end
        local rest = afterCmd:gsub('^%s+', '');
        local word = rest:match('^([^%s]+)');
        return word;
    end

    if (cmd == 'say' or cmd == 's') then
        return { purpose = 'Say', label = 'Say' };
    elseif (cmd == 'party' or cmd == 'p') then
        return { purpose = 'Party', label = 'Party' };
    elseif (cmd == 'linkshell' or cmd == 'l') then
        local name = (chatlog.get_linkshell_name ~= nil) and chatlog.get_linkshell_name(1) or nil;
        local label = (name ~= nil and name ~= '') and ('[' .. name .. ']') or 'Linkshell 1';
        return { purpose = 'LS[1]', label = label };
    elseif (cmd == 'linkshell2' or cmd == 'l2') then
        local name = (chatlog.get_linkshell_name ~= nil) and chatlog.get_linkshell_name(2) or nil;
        local label = (name ~= nil and name ~= '') and ('[' .. name .. ']') or 'Linkshell 2';
        return { purpose = 'LS[2]', label = label };
    elseif (cmd == 'shout' or cmd == 'sh') then
        return { purpose = 'Shout', label = 'Shout' };
    elseif (cmd == 'yell' or cmd == 'y') then
        return { purpose = 'Yell', label = 'Yell' };
    elseif (cmd == 'echo') then
        return { purpose = 'Echo', label = 'Echo' };
    elseif (cmd == 'tell' or cmd == 't') then
        local target = parse_next_word(trimmed:gsub('^/[^%s]+', '', 1));
        local arrow = '→';
        if (target ~= nil and target ~= '') then
            return { purpose = 'Tell', label = ('Tell ' .. arrow .. ' ' .. target), tellTarget = target };
        end
        return { purpose = 'Tell', label = 'Tell' };
    elseif (cmd == 'reply' or cmd == 'r') then
        local target = chatlog.lastTellFrom or chatlog.lastTellTo;
        local arrow = '→';
        if (target ~= nil and target ~= '') then
            return { purpose = 'Tell', label = ('Reply ' .. arrow .. ' ' .. target), tellTarget = target };
        end
        return { purpose = 'Tell', label = 'Reply' };
    elseif (cmd == 'me' or cmd == 'message') then
        return { purpose = 'Emote', label = 'Me' };
    elseif (cmd == 'unity' or cmd == 'u') then
        return { purpose = 'Unity', label = 'Unity' };
    elseif (cmd == 'assistj' or cmd == 'aj') then
        return { purpose = 'Assist[J]', label = 'Assist[J]' };
    elseif (cmd == 'assiste' or cmd == 'ae') then
        return { purpose = 'Assist[E]', label = 'Assist[E]' };
    end

    return { purpose = 'Command Error', label = 'Command Input' };
end

local function purpose_from_default_header(header)
    header = normalize_fs_header_string(header);
    if (header == nil) then
        return nil;
    end
    local parsed = parse_input_prefix(header);
    if (parsed ~= nil and parsed.purpose ~= nil and parsed.purpose ~= 'Command Error') then
        return parsed.purpose;
    end
    return nil;
end

local function purpose_from_chat_manager_buffers()
    local cm = AshitaCore:GetChatManager();
    if (cm == nil) then
        return nil;
    end

    local purpose;
    if (cm.GetInputTextParsed ~= nil) then
        purpose = purpose_from_header_text(cm:GetInputTextParsed());
        if (purpose ~= nil) then
            return purpose;
        end
    end
    if (cm.GetInputTextDisplay ~= nil) then
        purpose = purpose_from_header_text(cm:GetInputTextDisplay());
        if (purpose ~= nil) then
            return purpose;
        end
    end
    if (cm.GetInputTextRaw ~= nil) then
        purpose = purpose_from_header_text(cm:GetInputTextRaw());
        if (purpose ~= nil) then
            return purpose;
        end
    end
    return nil;
end

--- Default chat mode when input has no leading /command (from g_fsPreParser).
--- @return string|nil purpose
--- @return number|nil cmdIndex FS_CMD_INDEX
--- @return string|nil defaultHeader m_defaultHeader
local function get_native_default_chat_mode()
    local obj = read_fs_pre_parser_object();
    local header = (obj ~= 0) and read_fs_default_header(obj) or nil;
    local cmdIndex = (obj ~= 0) and read_fs_cmd_index(obj) or nil;

    local purpose = purpose_from_header_text(header);
    if (purpose == nil) then
        purpose = purpose_from_fs_cmd_index(cmdIndex);
    end
    if (purpose ~= nil) then
        return purpose, cmdIndex, header;
    end

    purpose = purpose_from_chat_manager_buffers();
    if (purpose ~= nil) then
        return purpose, cmdIndex, header;
    end

    if (initialize_fs_text_input_display()) then
        local ga = chatlog.fsTextInputDisplay.globalAddress or 0;
        if (ga ~= 0) then
            local legacyObj = ashita.memory.read_uint32(ga) or 0;
            if (legacyObj ~= 0) then
                local legacyHeader = scan_fs_header_in_object(legacyObj);
                purpose = purpose_from_header_text(legacyHeader);
                local legacyIdx = ashita.memory.read_uint32(legacyObj + 0x0108);
                if (purpose == nil) then
                    purpose = purpose_from_fs_cmd_index(legacyIdx);
                end
                if (purpose ~= nil) then
                    return purpose, legacyIdx, legacyHeader;
                end
            end
        end
    end

    local modeWord = get_native_input_mode_word();
    if (modeWord ~= nil) then
        local legacyPurpose = setmode(modeWord);
        if (legacyPurpose ~= nil and legacyPurpose ~= 'None') then
            return legacyPurpose, cmdIndex, header;
        end
    end

    return nil, nil, header;
end

function chatlog.debug_dump_native_chat_mode()
    local lines = {};
    local function add(fmt, ...)
        lines[#lines + 1] = fmt and fmt:fmt(...) or '';
    end

    add('fsPreParser.source=%s ptr=0x%X ready=%s',
        tostring(chatlog.fsPreParser.source),
        tonumber(chatlog.fsPreParser.ptrAddress) or 0,
        tostring(chatlog.fsPreParser.ready));

    local obj = read_fs_pre_parser_object();
    add('fsPreParser.object=0x%X headerOff=0x%X',
        tonumber(obj) or 0,
        tonumber(chatlog.fsPreParser.resolvedHeaderOffset) or -1);

    local header = (obj ~= 0) and read_fs_default_header(obj) or nil;
    local idx = (obj ~= 0) and read_fs_cmd_index(obj) or nil;
    add('header=%s cmdIndex=%s headerPurpose=%s indexPurpose=%s',
        tostring(header),
        tostring(idx),
        tostring(purpose_from_header_text(header)),
        tostring(purpose_from_fs_cmd_index(idx)));

    local p, i, h = get_native_default_chat_mode();
    add('resolved purpose=%s index=%s header=%s', tostring(p), tostring(i), tostring(h));

    local cm = AshitaCore:GetChatManager();
    if (cm ~= nil) then
        add('parsed=%s display=%s raw=%s',
            tostring(cm.GetInputTextParsed ~= nil and cm:GetInputTextParsed() or ''),
            tostring(cm.GetInputTextDisplay ~= nil and cm:GetInputTextDisplay() or ''),
            tostring(cm.GetInputTextRaw ~= nil and cm:GetInputTextRaw() or ''));
    end

    return lines;
end

chatlog.get_native_default_chat_mode = get_native_default_chat_mode;

chatlog.get_input_display_state = function(inputText)
    local parsed = parse_input_prefix(inputText);
    if (parsed ~= nil and parsed.purpose ~= nil) then
        return parsed;
    end

    local nativePurpose, _cmdIndex, defaultHeader = get_native_default_chat_mode();
    local purpose = nativePurpose;
    if (purpose == nil or purpose == 'None') then
        purpose = chatlog.lastInputPurpose or 'Say';
    elseif (isChatMode[purpose] == true) then
        chatlog.lastInputPurpose = purpose;
    end

    local headerParsed = (defaultHeader ~= nil) and parse_input_prefix(defaultHeader) or nil;
    local label = (headerParsed ~= nil and headerParsed.label ~= nil) and headerParsed.label or purpose;
    if (purpose == 'LS[1]') then
        local name = (chatlog.get_linkshell_name ~= nil) and chatlog.get_linkshell_name(1) or nil;
        label = (name ~= nil and name ~= '') and ('[' .. name .. ']') or 'Linkshell 1';
    elseif (purpose == 'LS[2]') then
        local name = (chatlog.get_linkshell_name ~= nil) and chatlog.get_linkshell_name(2) or nil;
        label = (name ~= nil and name ~= '') and ('[' .. name .. ']') or 'Linkshell 2';
    end

    return { purpose = purpose, label = label };
end

do
    local ls_cache = { [1] = { t = 0, name = nil }, [2] = { t = 0, name = nil } };

    local function trim_zeros(s)
        if (s == nil) then
            return nil;
        end
        s = tostring(s);
        s = s:match('^([^%z]*)') or s;
        s = s:gsub('%s+$', '');
        return s;
    end

    local function bytes_to_string(t, maxLen)
        if (type(t) ~= 'table') then
            return nil;
        end
        maxLen = tonumber(maxLen) or 16;
        local out = {};
        for i = 1, math.min(#t, maxLen) do
            local b = tonumber(t[i]) or 0;
            if (b == 0) then
                break;
            end
            out[#out + 1] = string.char(b);
        end
        return table.concat(out);
    end

    local function decode_item_index_to_container(invIndex)
        local idx = tonumber(invIndex) or 0;
        if (idx <= 0) then
            return nil, nil;
        end
        if (idx < 2048) then
            return 0, idx;
        elseif (idx < 2560) then
            return 8, idx - 2048;
        elseif (idx < 2816) then
            return 10, idx - 2560;
        elseif (idx < 3072) then
            return 11, idx - 2816;
        elseif (idx < 3328) then
            return 12, idx - 3072;
        end
        return nil, nil;
    end

    local function get_linkshell_name_uncached(slot)
        local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
        local inv = mm and mm:GetInventory() or nil;
        if (inv == nil or inv.GetEquippedItem == nil or inv.GetContainerItem == nil) then
            return nil;
        end

        local slotCandidates = (tonumber(slot) == 2) and { 17, 16, 15 } or { 16, 15, 17 };
        for i = 1, #slotCandidates do
            local eq = inv:GetEquippedItem(slotCandidates[i]);
            local invIndex = eq and eq.ItemIndex or 0;
            local cont, idx = decode_item_index_to_container(invIndex);
            if (cont ~= nil and idx ~= nil) then
                local it = inv:GetContainerItem(cont, idx);
                if (it ~= nil and tonumber(it.Id) == 513) then -- 513 = Linkshell
                    local sig = it.Signature or it.signature or it.Extra or it.extra;
                    local name = nil;
                    if (type(sig) == 'string') then
                        name = trim_zeros(sig);
                    elseif (type(sig) == 'table') then
                        name = trim_zeros(bytes_to_string(sig, 16));
                    end
                    if (name ~= nil and name ~= '') then
                        return name;
                    end
                end
            end
        end
        return nil;
    end

    chatlog.get_linkshell_name = function(slot)
        slot = tonumber(slot) or 1;
        if (slot ~= 1 and slot ~= 2) then
            slot = 1;
        end

        local now = os.clock();
        local c = ls_cache[slot];
        if (c ~= nil and c.name ~= nil and (now - (tonumber(c.t) or 0)) < 0.75) then
            return c.name;
        end

        local name = get_linkshell_name_uncached(slot);
        if (c ~= nil) then
            c.t = now;
            c.name = name;
        end
        return name;
    end
end

local function ensure_debug_dir()
    if (chatlog.debug.dirReady) then
        return chatlog.debug.dir;
    end
    local installPath = AshitaCore:GetInstallPath();
    local dir = ('%s\\config\\addons\\%s\\Logs'):fmt(installPath, addon.name);
    if (not ashita.fs.exists(dir)) then
        ashita.fs.create_directory(dir);
    end
    chatlog.debug.dirReady = true;
    chatlog.debug.dir = dir;
    return dir;
end

local function append_debug_line(path, line)
    local f = io.open(path, 'a+');
    if (f == nil) then
        return;
    end
    f:write(line);
    f:write('\n');
    f:close();
end


local function get_persist_path()
    local dir = ensure_debug_dir();
    return ('%s\\%s'):fmt(dir, chatlog.persist.filename);
end

local function persist_entry_minimal(e)
    return {
        time = e.time,
        date = e.date,
        sender = e.sender,
        zone = e.zone,
        purpose = e.purpose,
        purposeLabel = e.purposeLabel,
        channel = e.channel,
        modeID = e.modeID,
        modeBaseID = e.modeBaseID,
        message = e.message,
        isTell = e.isTell == true,
        tellDirection = e.tellDirection,
        tellName = e.tellName,
        indent = e.indent,
    };
end

local function write_persisted_chat()
    local chatSettings = ensure_chat_settings();
    if (chatSettings.persistChatLog ~= true) then
        return;
    end

    local keep = tonumber(chatlog.persist.keepLines) or 1000;
    if (keep < 1) then keep = 1000; end

    local total = #chatlog.entries;
    local startIndex = math.max(1, total - keep + 1);

    local path = get_persist_path();
    local f = io.open(path, 'w+');
    if (f == nil) then
        return;
    end

    f:write('return {\n');
    for i = startIndex, total do
        local e = chatlog.entries[i];
        if (e ~= nil and e.message ~= nil and e.message ~= '') then
            local pe = persist_entry_minimal(e);
            f:write(string.format('{ time=%q, date=%q, sender=%q, zone=%s, purpose=%q, purposeLabel=%q, channel=%q, modeID=%q, modeBaseID=%q, message=%q, isTell=%s, tellDirection=%q, tellName=%q, indent=%s },\n',
                tostring(pe.time or ''),
                tostring(pe.date or ''),
                tostring(pe.sender or 'System'),
                (pe.zone ~= nil) and tostring(tonumber(pe.zone) or 0) or 'nil',
                tostring(pe.purpose or 'None'),
                tostring(pe.purposeLabel or ''),
                tostring(pe.channel or 'system'),
                tostring(pe.modeID or ''),
                tostring(pe.modeBaseID or ''),
                tostring(pe.message or ''),
                (pe.isTell == true) and 'true' or 'false',
                tostring(pe.tellDirection or ''),
                tostring(pe.tellName or ''),
                (pe.indent ~= nil) and tostring(tonumber(pe.indent) or 0) or 'nil'
            ));
        end
    end
    f:write('}\n');
    f:close();
end

local function load_persisted_chat_once()
    local chatSettings = ensure_chat_settings();
    if (chatSettings.persistChatLog ~= true) then
        chatlog.persist.loaded = true;
        return;
    end
    if (chatlog.persist.loaded == true) then
        return;
    end
    chatlog.persist.loaded = true;

    local path = get_persist_path();
    if (not ashita.fs.exists(path)) then
        return;
    end

    local chunk = loadfile(path);
    if (chunk == nil) then
        return;
    end
    local ok, data = pcall(chunk);
    if (not ok or type(data) ~= 'table') then
        return;
    end

    local keep = tonumber(chatlog.persist.keepLines) or 1000;
    if (keep < 1) then keep = 1000; end

    local persisted = {};
    for i = 1, math.min(#data, keep) do
        local e = data[i];
        if (type(e) == 'table' and e.message ~= nil and e.message ~= '') then
            local d = e.date;
            if (d ~= nil) then
                d = tostring(d);
                if (d == '') then
                    d = nil;
                end
            end
            persisted[#persisted + 1] = T{
                time = tostring(e.time or ''),
                date = d,
                sender = tostring(e.sender or 'System'),
                zone = e.zone,
                purpose = tostring(e.purpose or 'None'),
                purposeLabel = (e.purposeLabel ~= nil and tostring(e.purposeLabel) ~= '') and tostring(e.purposeLabel) or nil,
                channel = tostring(e.channel or 'system'),
                modeID = tostring(e.modeID or ''),
                modeBaseID = tostring(e.modeBaseID or e.modeID or ''),
                rawMessage = nil,
                message = tostring(e.message or ''),
                injected = true,
                indent = tonumber(e.indent) or 0,
                isTell = e.isTell == true,
                tellDirection = e.tellDirection,
                tellName = e.tellName,
                segments = nil,
            };
        end
    end

    if (#persisted == 0) then
        return;
    end

    local today = os.date('%Y-%m-%d');
    local function make_date_marker(msg)
        return T{
            time = '',
            date = nil,
            sender = 'System',
            zone = nil,
            purpose = 'None',
            channel = 'system',
            modeID = '',
            modeBaseID = '',
            rawMessage = nil,
            message = msg,
            injected = true,
            indent = 0,
            isTell = false,
            tellDirection = nil,
            tellName = nil,
            segments = nil,
        };
    end

    local wrapped = T{};
    local openOldDate = nil;
    for i = 1, #persisted do
        local e = persisted[i];
        local d = e.date;
        local isOld = (d ~= nil and d ~= '' and d ~= today);

        if (isOld) then
            if (openOldDate ~= d) then
                if (openOldDate ~= nil) then
                    wrapped[#wrapped + 1] = make_date_marker(('↑↑%s↑↑'):fmt(openOldDate));
                end
                openOldDate = d;
                wrapped[#wrapped + 1] = make_date_marker(('↓↓%s↓↓'):fmt(openOldDate));
            end
            wrapped[#wrapped + 1] = e;
        else
            if (openOldDate ~= nil) then
                wrapped[#wrapped + 1] = make_date_marker(('↑↑%s↑↑'):fmt(openOldDate));
                openOldDate = nil;
            end
            wrapped[#wrapped + 1] = e;
        end
    end
    if (openOldDate ~= nil) then
        wrapped[#wrapped + 1] = make_date_marker(('↑↑%s↑↑'):fmt(openOldDate));
    end

    local combined = T{};
    for i = 1, #wrapped do
        combined[#combined + 1] = wrapped[i];
    end
    for i = 1, #chatlog.entries do
        combined[#combined + 1] = chatlog.entries[i];
    end
    chatlog.entries = combined;
    chatlog.rebuild_window_entry_lists();

    local maxEntries = tonumber(chatSettings.maxEntries) or 1000;
    if (maxEntries > 20000) then maxEntries = 20000; end
    if (maxEntries < 100) then maxEntries = 100; end
    while (#chatlog.entries > maxEntries) do
        table.remove(chatlog.entries, 1);
    end
    chatlog.rebuild_window_entry_lists();
end

local function entry_matches_window(windowSettings, entry, wi)
    if (windowSettings == nil or windowSettings.enabled ~= true) then
        return false;
    end

    local purpose = entry.purpose or 'None';
    if (windowSettings[purpose] == true) then
        return true;
    end

    if (wi == 2 and entry.channel == 'combat') then
        return true;
    end

    return false;
end

local function append_entry_shown_in_window(entry)
    local chatSettings = ensure_chat_settings();
    local w1 = chatSettings.window1;
    local w2 = chatSettings.window2;
    if (w1 ~= nil and entry_matches_window(w1, entry, 1)) then
        return true;
    end
    if (w2 ~= nil and entry_matches_window(w2, entry, 2)) then
        return true;
    end
    return false;
end

local function debug_log_text_in_not_shown(entry, reason)
    if (chatlog.debug.enabled ~= true or entry == nil) then
        return;
    end
    local chatSettings = ensure_chat_settings();
    local w1 = chatSettings.window1;
    local w2 = chatSettings.window2;
    local purpose = tostring(entry.purpose or 'None');
    local msg = tostring(entry.message or '');
    local norm = normalize_for_dedupe(msg);
    local stamp = os.date('!%Y-%m-%dT%H:%M:%SZ');
    local line = ('[%s] reason=%s purpose=%s sender=%s modeID=%s injected=%s w1_match=%s w2_match=%s msg=%q norm=%q'):fmt(
        stamp,
        tostring(reason or '?'),
        purpose,
        tostring(entry.sender or ''),
        tostring(entry.modeID or ''),
        tostring(entry.injected == true),
        (w1 ~= nil and entry_matches_window(w1, entry, 1)) and 'yes' or 'no',
        (w2 ~= nil and entry_matches_window(w2, entry, 2)) and 'yes' or 'no',
        msg,
        norm
    );
    local dir = ensure_debug_dir();
    append_debug_line(('%s\\%s'):fmt(dir, chatlog.debug.fileTextInNotShown), line);
end

local function debug_log_entry(entry)
    if (chatlog.debug.enabled ~= true) then
        return;
    end
    local chatSettings = ensure_chat_settings();
    local w1 = chatSettings.window1;
    local w2 = chatSettings.window2;
    if (w1 == nil or w2 == nil) then
        return;
    end

    local purpose = tostring(entry.purpose or 'None');
    local source = (entry.injected == true) and 'text_in' or 'packet';
    local sender = tostring(entry.sender or '');
    local modeID = tostring(entry.modeID or '');
    local msg = tostring(entry.message or '');
    local raw = tostring(entry.rawMessage or '');
    local norm = normalize_for_dedupe(msg);

    local function to_hex_preview(s, maxBytes)
        if (s == nil) then
            return '';
        end
        s = tostring(s);
        maxBytes = tonumber(maxBytes) or 80;
        if (maxBytes < 1) then
            maxBytes = 80;
        end
        local n = math.min(#s, maxBytes);
        local t = {};
        for i = 1, n do
            t[#t + 1] = string.format('%02X', s:byte(i));
        end
        if (#s > n) then
            t[#t + 1] = '...';
        end
        return table.concat(t, ' ');
    end

    local parsedAT = '';
    pcall(function()
        parsedAT = AshitaCore:GetChatManager():ParseAutoTranslate(raw, true) or '';
    end);

    local function extract_autotranslate_item_ids(s)
        local out = {};
        if (s == nil) then
            return out;
        end
        s = tostring(s);
        local i = 1;
        while (i <= #s - 5) do
            if (s:byte(i) == 0xFD and s:byte(i + 1) == 0x07 and s:byte(i + 2) == 0x02 and s:byte(i + 5) == 0xFD) then
                local hi = s:byte(i + 3);
                local lo = s:byte(i + 4);
                out[#out + 1] = (hi * 256) + lo;
                i = i + 6;
            else
                i = i + 1;
            end
        end
        return out;
    end

    local atItemIds = extract_autotranslate_item_ids(raw);
    local atItemIdStr = (#atItemIds > 0) and table.concat(atItemIds, ',') or '';

    local stamp = os.date('!%Y-%m-%dT%H:%M:%SZ');
    local header = ('[%s] source=%s purpose=%s sender=%s modeID=%s msg=%q raw=%q raw_hex=%q at=%q at_item_ids=%q norm=%q'):fmt(
        stamp, source, purpose, sender, modeID, msg, raw, to_hex_preview(raw, 120), tostring(parsedAT), atItemIdStr, norm
    );

    local dir = ensure_debug_dir();
    if (entry_matches_window(w1, entry, 1)) then
        append_debug_line(('%s\\%s'):fmt(dir, chatlog.debug.file1), header);
    end
    if (entry_matches_window(w2, entry, 2)) then
        append_debug_line(('%s\\%s'):fmt(dir, chatlog.debug.file2), header);
    end
end

local function append_entry_to_window_lists(entry)
    local chatSettings = ensure_chat_settings();
    for wi = 1, 2 do
        local ws = (wi == 1) and chatSettings.window1 or chatSettings.window2;
        if (entry_matches_window(ws, entry, wi)) then
            table.insert(chatlog.windowEntries[wi], entry);
        end
    end
end

local function get_effective_window_line_cap(chatSettings, wi)
    local w = (wi == 1) and chatSettings.window1 or chatSettings.window2;
    local cap = tonumber(w.maxLines);
    if (cap == nil or cap < 1) then
        cap = tonumber(chatSettings.maxEntries);
    end
    if (cap == nil or cap < 1) then
        cap = 1000;
    end
    if (cap > 20000) then
        cap = 20000;
    elseif (cap < 100) then
        cap = 100;
    end
    return math.floor(cap);
end

local function trim_chat_window_list(wi)
    local chatSettings = ensure_chat_settings();
    local cap = get_effective_window_line_cap(chatSettings, wi);
    local list = chatlog.windowEntries[wi];
    while (#list > cap) do
        table.remove(list, 1);
    end
end

local function trim_both_chat_window_lists()
    trim_chat_window_list(1);
    trim_chat_window_list(2);
end


chatlog.rebuild_window_entry_lists = function()
    local chatSettings = ensure_chat_settings();
    for wi = 1, 2 do
        chatlog.windowEntries[wi] = T{};
    end
    for i = 1, #chatlog.entries do
        local entry = chatlog.entries[i];
        if entry_matches_window(chatSettings.window1, entry, 1) then
            table.insert(chatlog.windowEntries[1], entry);
        end
        if entry_matches_window(chatSettings.window2, entry, 2) then
            table.insert(chatlog.windowEntries[2], entry);
        end
    end
    trim_both_chat_window_lists();
end

local function append_entry(entry)
    local chatSettings = ensure_chat_settings();
    if (entry == nil or entry.message == nil or entry.message == '') then
        return false, false;
    end

    local fromTextIn = (entry.fromTextIn == true);
    local now = os.clock();
    local skipDedupe = (entry.customChat == true and entry.customChatNoDedupe == true);
    local purpose = tostring(entry.purpose or 'None');
    if ((purpose == 'LS[1]' or purpose == 'LS[2]') and (entry.purposeLabel == nil or entry.purposeLabel == '')) then
        local slot = (purpose == 'LS[2]') and 2 or 1;
        local name = (chatlog.get_linkshell_name ~= nil) and chatlog.get_linkshell_name(slot) or nil;
        if (name ~= nil and name ~= '') then
            entry.purposeLabel = '[' .. name .. ']';
        end
    end
    if (entry.date == nil or entry.date == '') then
        entry.date = os.date('%Y-%m-%d');
    end
    entry.message = normalize_utf8_arrow_glyphs(tostring(entry.message or ''));
    tag_experience_chat_entry(entry);
    if (entry.experienceLine == true) then
        purpose = tostring(entry.purpose or 'None');
    end

    if (purpose == 'Miss' and entry.message:find('Venture mobs must be', 1, true)) then
        entry.purpose = 'System';
        purpose = 'System';
        entry.sender = 'System';
    end

    if (purpose == 'None') then
        if (tostring(entry.modeID or '') == '66' or entry.message:find('Bust!', 1, true)) then
            local newMsg, newSegments = chatRoll.enrich_bust_roll_message(entry.message);
            if (newMsg ~= nil) then
                entry.purpose = 'Add Effect';
                purpose = 'Add Effect';
                entry.message = newMsg;
                entry.segments = newSegments;
            end
        end
    end

    if (purpose == 'Add Effect' or purpose == 'None') then
        local newMsg, newSegments = chatRoll.enrich_add_effect_roll_message(entry.message);
        if (newMsg ~= nil) then
            entry.message = newMsg;
            entry.segments = newSegments;
            entry.purpose = 'Add Effect';
            purpose = 'Add Effect';
        end
    elseif (purpose == 'Special') then
        if (chatRoll.message_looks_like_corsair_roll(entry.message)) then
            local parsed = chatRoll.try_parse_add_effect_roll_line(entry.message);
            local rollName = (parsed ~= nil and parsed.rollName ~= nil) and parsed.rollName or nil;
            if (rollName == nil) then
                rollName = entry.message:match(":%s+([^%[]- Roll)%s*→")
                    or entry.message:match("%]%s+([^%[]- Roll)%s*→")
                    or entry.message:match(":%s+(Bust!%s*[^%[]- Roll)%s*→")
                    or entry.message:match("%]%s+(Bust!%s*[^%[]- Roll)%s*→");
                rollName = chatRoll.normalize_roll_name(rollName);
            end
            if (rollName ~= nil) then
                local re = recentRollEvent[rollName];
                if (re ~= nil and (now - (re.time or 0)) < 2.0) then
                    if (fromTextIn) then
                        debug_log_text_in_not_shown(entry, 'corsair_roll_special_recent_dup');
                    end
                    return false, false;
                end
            end
        end
    end

    local normMsg = normalize_for_dedupe(entry.message);

    if (purpose == 'NPC' and entry.experienceLine ~= true and normMsg ~= '' and not skipDedupe) then
        if (npc_dialog_is_duplicate(entry.sender, entry.message, now)) then
            if (fromTextIn) then
                debug_log_text_in_not_shown(entry, 'npc_dialog_dedupe');
            end
            return false, false;
        end
    end

    if (not skipDedupe and not glam_no_chat_suppression()) then
        if (normMsg ~= ''
            and normMsg == chatlog.recentNormMessage
            and purpose == chatlog.recentNormPurpose
            and (now - (chatlog.recentTime or 0)) < 0.35) then
            if (fromTextIn) then
                debug_log_text_in_not_shown(entry, 'norm_message_dedupe');
            end
            return false, false;
        end

        local dedupeKey;
        if (purpose == 'None') then
            dedupeKey = purpose .. '|' .. normMsg;
        elseif (purpose == 'Tell') then
            dedupeKey = ('Tell|%s|%s'):fmt(tostring(entry.sender or ''), normMsg);
        else
            dedupeKey = ('%s|%s|%s|%s'):fmt(
                purpose,
                tostring(entry.sender or ''),
                normMsg,
                tostring(entry.modeID or '')
            );
        end

        if (chatlog.recentKey == dedupeKey and (now - (chatlog.recentTime or 0)) < 0.3) then
            if (fromTextIn) then
                debug_log_text_in_not_shown(entry, 'dedupe_key');
            end
            return false, false;
        end

        chatlog.recentKey = dedupeKey;
        chatlog.recentMessage = entry.message;
        chatlog.recentNormMessage = normMsg;
        chatlog.recentNormPurpose = purpose;
        chatlog.recentTime = now;
    else
        chatlog.recentKey = '';
        chatlog.recentMessage = entry.message;
        chatlog.recentNormMessage = normMsg;
        chatlog.recentNormPurpose = purpose;
        chatlog.recentTime = now;
    end


    entry._clock = now;
    if (purpose == 'NPC' and normMsg ~= '' and not skipDedupe) then
        npc_dialog_mark_seen(entry.sender, entry.message, now);
    end
    table.insert(chatlog.entries, entry);
    append_entry_to_window_lists(entry);

    if (fromTextIn) then
        local w1 = chatSettings.window1;
        local w2 = chatSettings.window2;
        local inW1 = (w1 ~= nil) and entry_matches_window(w1, entry, 1);
        local inW2 = (w2 ~= nil) and entry_matches_window(w2, entry, 2);
        if (not inW1 and not inW2) then
            debug_log_text_in_not_shown(entry, 'no_window_purpose_match');
        end
    end

    local maxEntries = tonumber(chatSettings.maxEntries);
    if (maxEntries == nil or maxEntries < 1) then
        maxEntries = 1000;
    end
    if (maxEntries > 20000) then
        maxEntries = 20000;
    elseif (maxEntries < 100) then
        maxEntries = 100;
    end

    local trimTotal = 0;
    while (#chatlog.entries > maxEntries) do
        table.remove(chatlog.entries, 1);
        trimTotal = trimTotal + 1;
    end
    if (trimTotal > 1) then
        chatlog.rebuild_window_entry_lists();
    else
        trim_both_chat_window_lists();
    end

    debug_log_entry(entry);
    return true, append_entry_shown_in_window(entry);
end


get_purpose_color = function(purpose)
    local chatSettings = ensure_chat_settings();
    return chatSettings.purposeColors[purpose] or { 1.0, 1.0, 1.0, 1.0 };
end
chatRoll.init(get_purpose_color);


local function invalidate_chat_draw_token_cache()
    local function clear_entry(entry)
        if (entry == nil) then
            return;
        end
        entry._chatTokenCacheKey = nil;
        entry._chatDrawTokens = nil;
    end

    for i = 1, #chatlog.entries do
        clear_entry(chatlog.entries[i]);
    end
    for wi = 1, 2 do
        local list = chatlog.windowEntries[wi];
        if (list ~= nil) then
            for i = 1, #list do
                clear_entry(list[i]);
            end
        end
    end
end

chatlog.on_load = function()
    apply_native_chatline_override(true);
    load_persisted_chat_once();
    invalidate_chat_draw_token_cache();
    chatlog.rebuild_window_entry_lists();
end

chatlog.on_present = function()
    apply_native_chatline_override(false);
    local now = os.clock();
    maybe_prune_roll_aux_tables(now);

    local chatSettings = ensure_chat_settings();
    if (chatSettings.persistChatLog == true) then
        local last = tonumber(chatlog.persist.lastWriteClock) or 0;
        local interval = tonumber(chatlog.persist.writeIntervalSec) or 10.0;
        if ((now - last) >= interval) then
            chatlog.persist.lastWriteClock = now;
            pcall(write_persisted_chat);
        end
    end
end

chatlog.get_entries = function()
    return chatlog.entries;
end

chatlog.get_window_entries = function(windowIndex)
    if (windowIndex == 1 or windowIndex == 2) then
        return chatlog.windowEntries[windowIndex];
    end
    return chatlog.entries;
end

chatlog.get_entries_for_purpose = function(purpose)
    local want = purpose or 'None';
    local out = T{};
    for i = 1, #chatlog.entries do
        local entry = chatlog.entries[i];
        if ((entry.purpose or 'None') == want) then
            table.insert(out, entry);
        end
    end
    return out;
end

chatlog.get_purpose_color = function(purpose)
    return get_purpose_color(purpose);
end

chatlog.invalidate_draw_cache = function()
    invalidate_chat_draw_token_cache();
end

chatlog.sjis_to_utf8 = function(str)
    return sjis_to_utf8(str);
end

chatlog.clean_str = function(str)
    return clean_str(str);
end

chatlog.normalize_sjis_yen_to_backslash = function(str)
    return normalize_sjis_yen_to_backslash(str);
end

chatlog.normalize_backslash_for_display = function(str)
    return normalize_backslash_for_display(str);
end

chatlog.get_code_color = function(code, defaultColor)
    local chatSettings = ensure_chat_settings();
    local color = chatSettings.codeColors[string.format('%02X', code)];
    if (color == nil) then
        color = chatSettings.codeColors[string.format('%02x', code)];
    end
    return color or defaultColor;
end

chatlog.entry_matches_window = function(windowSettings, entry, wi)
    return entry_matches_window(windowSettings, entry, wi);
end

chatlog.get_window_settings = function(index)
    local chatSettings = ensure_chat_settings();
    if (index == 1) then
        return chatSettings.window1;
    end
    if (index == 2) then
        return chatSettings.window2;
    end
    return nil;
end

chatlog.set_debug_logging = function(enabled)
    chatlog.debug.enabled = enabled == true;
    chatlog.debug.dirReady = false;
end

chatlog.clear_debug_logs = function()
    local dir = ensure_debug_dir();
    pcall(function() os.remove(('%s\\%s'):fmt(dir, chatlog.debug.file1)); end);
    pcall(function() os.remove(('%s\\%s'):fmt(dir, chatlog.debug.file2)); end);
    pcall(function() os.remove(('%s\\%s'):fmt(dir, chatlog.debug.fileTextInNotShown)); end);
end

local function unpack_inbound_chat_sender(packetData)
    local raw = struct.unpack('c15', packetData, 0x08 + 1);
    if (raw == nil or raw == '') then
        return '';
    end
    local s = raw:match('^([^%z]*)') or '';
    return (s:gsub('%s+$', ''));
end

local function unpack_inbound_chat_message_0x17(e)
    if (e == nil or e.data == nil) then
        return '';
    end
    local hdr = struct.unpack('H', e.data, 0x00 + 1);
    local sizeWords = bit.rshift(hdr, 9);
    local totalBytes = (tonumber(sizeWords) or 0) * 4;
    local mesOffset = 0x17;
    local avail = totalBytes - mesOffset;
    if (avail < 0) then
        avail = 0;
    end
    local len = math.min(150, avail);
    if (len <= 0) then
        return '';
    end
    local buf = e.data;
    if (buf == nil or type(buf) ~= 'string' or #buf < mesOffset + len) then
        buf = e.data_modified;
    end
    if (buf == nil or type(buf) ~= 'string' or #buf < mesOffset + len) then
        return '';
    end
    local raw = struct.unpack(('c%d'):fmt(len), buf, mesOffset + 1);
    if (raw == nil or raw == '') then
        return '';
    end
    return raw:match('^([^%z]*)') or raw;
end

local npcDialogStringTableCache = nil;

local NPC_DIALOG_GETSTRING_TABLE_CANDIDATES = {
    'dialog',
    'server.messages',
    'messages.server',
    'messages.dialog',
    'SevMess',
    'sev_mess',
    'sev_mess.dialog',
    'sevmess',
};

local function try_get_string_resource(rm, tbl, idx)
    if (rm == nil or tbl == nil or idx == nil) then
        return nil;
    end
    local langs = { 2, 1 };
    for li = 1, #langs do
        local ok, v = pcall(function()
            return rm:GetString(tbl, idx, langs[li]);
        end);
        if (ok and type(v) == 'string' and v ~= '') then
            return v;
        end
    end
    local ok2, v2 = pcall(function()
        return rm:GetString(tbl, idx);
    end);
    if (ok2 and type(v2) == 'string' and v2 ~= '') then
        return v2;
    end
    return nil;
end

local function npc_dialog_string_lookup(messageIndex)
    local rm = AshitaCore and AshitaCore:GetResourceManager() or nil;
    if (rm == nil or messageIndex == nil) then
        return nil;
    end
    local idx = tonumber(messageIndex) or 0;
    if (idx < 0) then
        return nil;
    end

    if (npcDialogStringTableCache ~= nil) then
        local hit = try_get_string_resource(rm, npcDialogStringTableCache, idx);
        if (hit ~= nil) then
            return hit;
        end
    end

    for ti = 1, #NPC_DIALOG_GETSTRING_TABLE_CANDIDATES do
        local tbl = NPC_DIALOG_GETSTRING_TABLE_CANDIDATES[ti];
        local hit = try_get_string_resource(rm, tbl, idx);
        if (hit ~= nil) then
            npcDialogStringTableCache = tbl;
            return hit;
        end
    end

    return nil;
end

local eventMessStringTableCache = nil;

local EVENT_MESSAGE_GETSTRING_TABLE_CANDIDATES = {
    'EventMess',
    'events.messages',
    'messages.events',
    'event.messages',
    'messages.event',
};

local function lookup_event_message_string(messageIndex)
    local rm = AshitaCore and AshitaCore:GetResourceManager() or nil;
    if (rm == nil or messageIndex == nil) then
        return nil;
    end
    local idx = tonumber(messageIndex) or 0;
    if (idx < 0) then
        return nil;
    end

    if (eventMessStringTableCache ~= nil) then
        local hit = try_get_string_resource(rm, eventMessStringTableCache, idx);
        if (hit ~= nil) then
            return hit;
        end
    end

    for ti = 1, #EVENT_MESSAGE_GETSTRING_TABLE_CANDIDATES do
        local tbl = EVENT_MESSAGE_GETSTRING_TABLE_CANDIDATES[ti];
        local hit = try_get_string_resource(rm, tbl, idx);
        if (hit ~= nil) then
            eventMessStringTableCache = tbl;
            return hit;
        end
    end

    return nil;
end

local function resolve_gp_serv_event_0x32_text(data)
    if (data == nil or #data < 0x14) then
        return nil;
    end
    local eventNum = struct.unpack('H', data, 0x0A + 1);
    local eventPara = struct.unpack('H', data, 0x0C + 1);
    local eventNum2 = struct.unpack('H', data, 0x10 + 1);
    local eventPara2 = struct.unpack('H', data, 0x12 + 1);

    local function try_index(idx)
        if (idx == nil) then
            return nil;
        end
        local i = tonumber(idx);
        if (i == nil or i < 0) then
            return nil;
        end
        local ev = lookup_event_message_string(i);
        if (ev ~= nil and ev ~= '') then
            return ev;
        end
        local nv = npc_dialog_string_lookup(i);
        if (nv ~= nil and nv ~= '') then
            return nv;
        end
        return nil;
    end

    local t = try_index(eventPara);
    if (t ~= nil) then
        return t;
    end
    if (tonumber(eventPara2) ~= nil and tonumber(eventPara2) > 0) then
        t = try_index(eventPara2);
        if (t ~= nil) then
            return t;
        end
    end
    t = try_index(bit.band(tonumber(eventNum) or 0, 0x7FFF));
    if (t ~= nil) then
        return t;
    end
    t = try_index(bit.band(tonumber(eventNum2) or 0, 0x7FFF));
    if (t ~= nil) then
        return t;
    end

    return nil;
end

local displayMessageTableCache = nil;

local DISPLAY_MESSAGE_GETSTRING_TABLE_CANDIDATES = {
    'messages',
    'messages.special',
    'system.messages',
    'display.messages',
    'msg.display',
};

local function lookup_display_message_template(messageIndex)
    local rm = AshitaCore and AshitaCore:GetResourceManager() or nil;
    if (rm == nil or messageIndex == nil) then
        return nil;
    end
    local idx = tonumber(messageIndex) or 0;
    if (idx < 0) then
        return nil;
    end
    if (displayMessageTableCache ~= nil) then
        local hit = try_get_string_resource(rm, displayMessageTableCache, idx);
        if (hit ~= nil) then
            return hit;
        end
    end
    for ti = 1, #DISPLAY_MESSAGE_GETSTRING_TABLE_CANDIDATES do
        local tbl = DISPLAY_MESSAGE_GETSTRING_TABLE_CANDIDATES[ti];
        local hit = try_get_string_resource(rm, tbl, idx);
        if (hit ~= nil) then
            displayMessageTableCache = tbl;
            return hit;
        end
    end
    return nil;
end

local function format_display_message_template(template, p1, p2, p3, p4, playerName)
    if (template == nil or template == '') then
        return nil;
    end
    local t = template;
    t = t:gsub('%${lb}', '\n');
    local n1 = tonumber(p1) or 0;
    local n2 = tonumber(p2) or 0;
    local n3 = tonumber(p3) or 0;
    local n4 = tonumber(p4) or 0;
    t = t:gsub('%${number}', tostring(n1));
    t = t:gsub('%${number2}', tostring(n2));
    t = t:gsub('%${number3}', tostring(n3));
    t = t:gsub('%${number4}', tostring(n4));
    if (playerName ~= nil and playerName ~= '') then
        t = t:gsub('%${player}', playerName);
    end
    return clean_str(t);
end

local function resolve_display_message_or_fallback(msgId, msgType, p1, p2, p3, p4, playerName)
    local template = lookup_display_message_template(msgId);
    local text = format_display_message_template(template, p1, p2, p3, p4, playerName);
    if (text ~= nil and text ~= '') then
        return text;
    end
    if (template ~= nil and template ~= '') then
        return clean_str(template);
    end
    return ('[DisplayMsg %u] type=%u p1=%u p2=%u p3=%u p4=%u (%s)'):fmt(
        tonumber(msgId) or 0,
        tonumber(msgType) or 0,
        tonumber(p1) or 0,
        tonumber(p2) or 0,
        tonumber(p3) or 0,
        tonumber(p4) or 0,
        tostring(playerName or '')
    );
end

local function handle_string_message_packet_0x27(e)
    if (e == nil or e.data == nil or #e.data < 0x30) then
        return;
    end
    local playerIdx = struct.unpack('H', e.data, 0x08 + 1);
    local rawMid = struct.unpack('H', e.data, 0x0A + 1);
    local msgId = bit.band(tonumber(rawMid) or 0, 0x7FFF);
    local msgType = struct.unpack('I', e.data, 0x0C + 1);
    local p1 = struct.unpack('I', e.data, 0x10 + 1);
    local p2 = struct.unpack('I', e.data, 0x14 + 1);
    local p3 = struct.unpack('I', e.data, 0x18 + 1);
    local p4 = struct.unpack('I', e.data, 0x1C + 1);
    local nameRaw = struct.unpack('c16', e.data, 0x20 + 1);
    local playerName = '';
    if (nameRaw ~= nil and nameRaw ~= '') then
        playerName = ((nameRaw:match('^([^%z]*)') or ''):gsub('%s+$', ''));
    end
    if (playerName == '' and playerIdx ~= nil and tonumber(playerIdx) ~= nil and tonumber(playerIdx) > 0 and GetEntity ~= nil) then
        local ent = GetEntity(tonumber(playerIdx));
        if (ent ~= nil and ent.Name ~= nil and tostring(ent.Name) ~= '') then
            playerName = tostring(ent.Name):gsub('%z.*', '');
        end
    end
    local sender = (playerName ~= nil and playerName ~= '') and playerName or 'System';
    local text = resolve_display_message_or_fallback(msgId, msgType, p1, p2, p3, p4, playerName);

    local committed, shown = append_entry(T{
        time = os.date('[%H:%M:%S]'),
        sender = sender,
        zone = nil,
        purpose = 'NPC',
        channel = 'npc',
        modeID = '27',
        modeBaseID = '27',
        rawMessage = nil,
        message = text,
        injected = false,
        isTell = false,
        displayMsgId = msgId,
        displayMsgType = msgType,
    });
    if (committed and shown) then
        record_packet_chat_line(text, true);
    end
end

local function handle_servmes_packet_0x4d(e)
    if (e == nil or e.data == nil or #e.data < 0x19) then
        return;
    end
    local len = tonumber(struct.unpack('I', e.data, 0x0A + 1)) or 0;
    if (len < 0 or len > 8192) then
        len = 0;
    end
    local maxRead = len;
    if (maxRead <= 0) then
        maxRead = math.max(0, #e.data - 24);
    end
    maxRead = math.min(maxRead, #e.data - 24, 4096);
    if (maxRead <= 0) then
        return;
    end
    local raw = struct.unpack(('c%d'):fmt(maxRead), e.data, 0x18 + 1);
    if (raw == nil or raw == '') then
        return;
    end
    local cut = raw:match('^([^%z]*)') or raw;
    local text = clean_str(cut);
    if (text == nil or text == '') then
        return;
    end

    local committed, shown = append_entry(T{
        time = os.date('[%H:%M:%S]'),
        sender = 'System',
        zone = nil,
        purpose = 'System',
        channel = 'system',
        modeID = '4d',
        modeBaseID = '4d',
        rawMessage = cut,
        message = text,
        injected = false,
        isTell = false,
    });
    if (committed and shown) then
        record_packet_chat_line(text, true);
    end
end

local function handle_system_message_packet_0x53(e)
    if (e == nil or e.data == nil or #e.data < 0x10) then
        return;
    end
    local param = struct.unpack('I', e.data, 0x04 + 1);
    local msgId = struct.unpack('H', e.data, 0x0C + 1);
    local mid = bit.band(tonumber(msgId) or 0, 0x7FFF);
    local template = lookup_display_message_template(mid);
    if (template == nil or template == '') then
        template = npc_dialog_string_lookup(mid);
    end
    local text = format_display_message_template(template, param, 0, 0, 0, nil);
    if (text == nil or text == '') then
        if (template ~= nil and template ~= '') then
            text = clean_str(template);
        else
            text = ('[SystemMsg %u] param=%u'):fmt(mid, tonumber(param) or 0);
        end
    end

    local committed, shown = append_entry(T{
        time = os.date('[%H:%M:%S]'),
        sender = 'System',
        zone = nil,
        purpose = 'System',
        channel = 'system',
        modeID = '53',
        modeBaseID = '53',
        rawMessage = nil,
        message = text,
        injected = false,
        isTell = false,
        systemMsgId = mid,
    });
    if (committed and shown) then
        record_packet_chat_line(text, true);
    end
end

local TRUST_JOIN_MESSAGE_ID = 711;
local TRUST_CAST_RECENT_TTL = 8.0;

local function resource_object_display_name(obj)
    if (obj == nil or obj.Name == nil) then
        return nil;
    end
    local nm = obj.Name;
    local ok, a, b = pcall(function()
        return nm[1], nm[2];
    end);
    if (ok) then
        for i = 1, 2 do
            local v = (i == 1) and a or b;
            if (v ~= nil) then
                local s = tostring(v);
                if (s ~= '' and s ~= 'nil') then
                    return s;
                end
            end
        end
    elseif (type(nm) == 'string' and nm ~= '') then
        return nm;
    end
    return nil;
end

local function prune_recent_trust_casts(now)
    now = tonumber(now) or os.clock();
    local store = chatlog.recentTrustCastByPlayer;
    if (store == nil) then
        return;
    end
    for player, rec in pairs(store) do
        if (rec == nil or (now - (tonumber(rec.time) or 0)) > TRUST_CAST_RECENT_TTL) then
            store[player] = nil;
        end
    end
end

function chatlog.note_recent_trust_spell_cast(message)
    if (message == nil or message == '') then
        return;
    end
    local player, trust, target = tostring(message):match('^%[([^%]]+)%]%s+(.-)%s+→%s*(.+)%s*$');
    if (player == nil or trust == nil or target == nil) then
        return;
    end
    player = player:match('^%s*(.-)%s*$') or player;
    target = target:match('^%s*(.-)%s*$') or target;
    trust = trust:match('^%s*(.-)%s*$') or trust;
    if (player == '' or trust == '' or trust == '.' or player ~= target) then
        return;
    end
    if (chatlog.recentTrustCastByPlayer == nil) then
        chatlog.recentTrustCastByPlayer = T{};
    end
    chatlog.recentTrustCastByPlayer[player] = {
        trust = trust,
        time = os.clock(),
    };
    prune_recent_trust_casts();
end

local function trust_spell_name_is_geo_indi(name)
    if (name == nil or name == '') then
        return false;
    end
    name = tostring(name);
    if (name:find('^Indi%-', 1) ~= nil or name:find('^Geo%-', 1) ~= nil) then
        return true;
    end
    return false;
end

local function trust_name_is_plausible(name)
    if (name == nil) then
        return false;
    end
    name = tostring(name):match('^%s*(.-)%s*$') or '';
    if (name == '' or name == '.' or name == '?' or name:find('^#%d+$') ~= nil) then
        return false;
    end
    return true;
end

local function spell_name_and_trust_flag_from_id(id)
    id = math.floor(tonumber(id) or 0);
    if (id <= 0) then
        return nil, false;
    end

    local rm2 = AshitaCore and AshitaCore:GetResourceManager() or nil;
    if (rm2 ~= nil and rm2.GetSpellById ~= nil) then
        local ok, spell = pcall(function()
            return rm2:GetSpellById(id);
        end);
        if (ok and spell ~= nil) then
            local raw = resource_object_display_name(spell);
            if (raw ~= nil and raw ~= '') then
                local isTrust = raw:find('^Trust:') ~= nil;
                return raw:gsub('^Trust:%s*', ''), isTrust;
            end
        end
    end

    if (rm2 ~= nil) then
        for _, tbl in ipairs(T{ 'spells.names', 'spells.names_short', 'spells' }) do
            local hit = try_get_string_resource(rm2, tbl, id);
            if (hit ~= nil and hit ~= '') then
                local isTrust = hit:find('^Trust:') ~= nil;
                return hit:gsub('^Trust:%s*', ''), isTrust;
            end
        end
    end

    return nil, false;
end

local function trust_name_from_entity_index(idx, actorName)
    idx = tonumber(idx) or 0;
    if (idx <= 0 or GetEntity == nil) then
        return nil;
    end
    local ent = GetEntity(idx);
    if (ent == nil or ent.Name == nil) then
        return nil;
    end
    local nm = tostring(ent.Name):gsub('%z.*', '');
    if (not trust_name_is_plausible(nm)) then
        return nil;
    end
    if (actorName ~= nil and actorName ~= '' and nm == actorName) then
        return nil;
    end
    return nm;
end

local function resolve_trust_join_name_711(p, actorName)
    prune_recent_trust_casts();
    local now = os.clock();

    if (actorName ~= nil and actorName ~= '' and chatlog.recentTrustCastByPlayer ~= nil) then
        local rec = chatlog.recentTrustCastByPlayer[actorName];
        if (rec ~= nil and trust_name_is_plausible(rec.trust) and (now - (tonumber(rec.time) or 0)) <= TRUST_CAST_RECENT_TTL) then
            return rec.trust;
        end
    end

    local ids = {};
    local function add_id(v)
        v = math.floor(tonumber(v) or 0);
        if (v > 0) then
            ids[#ids + 1] = v;
            local lo = bit.band(v, 0xFFFF);
            if (lo > 0 and lo ~= v) then
                ids[#ids + 1] = lo;
            end
        end
    end
    add_id(p.p1);
    add_id(p.p2);

    for i = 1, #ids do
        local nm, isTrust = spell_name_and_trust_flag_from_id(ids[i]);
        if (isTrust and trust_name_is_plausible(nm) and not trust_spell_name_is_geo_indi(nm)) then
            return nm;
        end
    end

    for _, idx in ipairs(T{ p.actIndexTar, p.actIndexCas }) do
        local nm = trust_name_from_entity_index(idx, actorName);
        if (nm ~= nil) then
            return nm;
        end
    end

    return nil;
end

local function append_trust_join_message_711(actorName, trustName)
    if (not trust_name_is_plausible(actorName) or not trust_name_is_plausible(trustName)) then
        return;
    end

    local text = ('(%s) %s'):fmt(actorName, trustName);
    local committed, shown = append_entry(T{
        time = os.date('[%H:%M:%S]'),
        sender = 'System',
        zone = nil,
        purpose = 'System',
        channel = 'system',
        modeID = '2d',
        modeBaseID = '2d',
        rawMessage = nil,
        message = text,
        injected = false,
        isTell = false,
        killMsgId = TRUST_JOIN_MESSAGE_ID,
    });
    if (committed and shown) then
        record_packet_chat_line(text, true);
    end
end

local function handle_kill_message_packet_0x2d(e)
    if (e == nil or e.data == nil or #e.data < 0x18) then
        return;
    end

    local selfEnt = GetPlayerEntity ~= nil and GetPlayerEntity() or nil;
    local selfSid = (selfEnt ~= nil and selfEnt.ServerId ~= nil) and selfEnt.ServerId or 0;
    local selfIndex = (selfEnt ~= nil and selfEnt.TargetIndex ~= nil) and tonumber(selfEnt.TargetIndex) or 0;

    local function try_parse(playerOff)
        playerOff = tonumber(playerOff) or 0;
        local need = (playerOff == 0) and 0x18 or 0x1C;
        if (#e.data < need) then
            return nil;
        end
        local playerSid = struct.unpack('I', e.data, playerOff + 0x00 + 1);
        local targetSid = struct.unpack('I', e.data, playerOff + 0x04 + 1);
        local actIndexCas = struct.unpack('H', e.data, playerOff + 0x08 + 1);
        local actIndexTar = struct.unpack('H', e.data, playerOff + 0x0A + 1);
        local p1 = struct.unpack('I', e.data, playerOff + 0x0C + 1);
        local p2 = struct.unpack('I', e.data, playerOff + 0x10 + 1);
        local rawMid = struct.unpack('H', e.data, playerOff + 0x14 + 1);
        local mid = bit.band(tonumber(rawMid) or 0, 0x7FFF);
        local typeByte = struct.unpack('B', e.data, playerOff + 0x16 + 1);

        local sidMatch = (selfSid ~= 0) and ((playerSid == selfSid) or (targetSid == selfSid));
        local idxMatch = (selfIndex ~= 0) and ((tonumber(actIndexCas) == selfIndex) or (tonumber(actIndexTar) == selfIndex));
        local midPlausible = (mid > 0 and mid < 65535);
        return {
            playerOff = playerOff,
            playerSid = playerSid,
            targetSid = targetSid,
            actIndexCas = actIndexCas,
            actIndexTar = actIndexTar,
            p1 = p1,
            p2 = p2,
            mid = mid,
            typeByte = typeByte,
            sidMatch = sidMatch,
            idxMatch = idxMatch,
            midPlausible = midPlausible,
        };
    end

    local parseA = try_parse(0x04); -- header included: player @ 0x04
    local parseB = try_parse(0x00); -- header stripped: player @ 0x00

    local p = nil;
    if (parseA ~= nil and (parseA.sidMatch or parseA.idxMatch) and parseA.midPlausible) then
        p = parseA;
    elseif (parseB ~= nil and (parseB.sidMatch or parseB.idxMatch) and parseB.midPlausible) then
        p = parseB;
    else
        p = parseA or parseB;
    end
    if (p == nil) then
        return;
    end

    local playerSid = p.playerSid;
    local targetSid = p.targetSid;
    local actIndexCas = p.actIndexCas;
    local actIndexTar = p.actIndexTar;
    local p1 = p.p1;
    local p2 = p.p2;
    local mid = p.mid;
    local typeByte = p.typeByte;

    if (selfSid ~= 0) then
        local sidMatch = (playerSid == selfSid) or (targetSid == selfSid);
        local idxMatch = (selfIndex ~= 0) and ((tonumber(actIndexCas) == selfIndex) or (tonumber(actIndexTar) == selfIndex));
        if (not sidMatch and not idxMatch) then
            return;
        end
    end

    if (mid == TRUST_JOIN_MESSAGE_ID) then
        local actorName = nil;
        if (selfEnt ~= nil and selfEnt.Name ~= nil and (playerSid == selfSid or targetSid == selfSid)) then
            actorName = tostring(selfEnt.Name):gsub('%z.*', '');
        end
        local trustName = resolve_trust_join_name_711(p, actorName);
        if (trustName ~= nil) then
            append_trust_join_message_711(actorName or '???', trustName);
        end
        return;
    end

    local rm = AshitaCore and AshitaCore:GetResourceManager() or nil;
    local BtlMessStringTableCandidates = {
        'btlmess',
        'BtlMess',
        'btlmess.special',
        'messages.btlmess',
        'battle.messages',
    };
    local templ = nil;
    if (rm ~= nil) then
        for ti = 1, #BtlMessStringTableCandidates do
            local tbl = BtlMessStringTableCandidates[ti];
            local hit = try_get_string_resource(rm, tbl, mid);
            if (hit ~= nil and hit ~= '') then
                templ = hit;
                break;
            end
        end
    end

    if (templ == nil or templ == '') then
        local ok, actmsg = pcall(function()
            return require('action_messages');
        end);
        if (ok and type(actmsg) == 'table') then
            local row = actmsg[mid];
            templ = row and (row.en or row.jp) or nil;
        end
    end

    local function fmt_btlmess(t)
        if (t == nil or t == '') then
            return nil;
        end
        local out = t;
        out = out:gsub('%${lb}', '\n');
        out = out:gsub('\7', '\n');
        out = out:gsub('%${number}', tostring(tonumber(p1) or 0));
        out = out:gsub('%${number2}', tostring(tonumber(p2) or 0));
        out = out:gsub('%${number3}', tostring(tonumber(p1) or 0));
        out = out:gsub('%${number4}', tostring(tonumber(p2) or 0));
        local regime_name = nil;
        pcall(function()
            if (package.loaded['combatParse'] == nil) then
                require('combatParse');
            end
            local roe = require('roe_regime');
            regime_name = roe.lookup_regime_name(p1);
        end);
        out = out:gsub('%${regime}', regime_name or ('#' .. tostring(tonumber(p1) or 0)));

        local function item_name_from_id(id)
            id = math.floor(tonumber(id) or 0);
            if (id <= 0 or id > 65535) then
                return nil;
            end
            local rm2 = AshitaCore and AshitaCore:GetResourceManager() or nil;
            if (rm2 ~= nil and rm2.GetItemById ~= nil) then
                local okI, item = pcall(function()
                    return rm2:GetItemById(id);
                end);
                if (okI and item ~= nil and item.Name ~= nil) then
                    local n = item.Name;
                    local okN, a, b = pcall(function()
                        return n[1], n[2];
                    end);
                    if (okN) then
                        local s = tostring(a or b or '');
                        if (s ~= '' and s ~= 'nil') then
                            return s;
                        end
                    elseif (type(n) == 'string') then
                        if (n ~= '') then
                            return n;
                        end
                    end
                end
            end
            if (rm2 ~= nil) then
                for _, tbl in ipairs(T{ 'items.names_log', 'items.names', 'items' }) do
                    local hit = try_get_string_resource(rm2, tbl, id);
                    if (hit ~= nil and hit ~= '') then
                        return hit;
                    end
                end
            end
            return nil;
        end

        local function spell_name_from_id(id)
            local nm = spell_name_and_trust_flag_from_id(id);
            return nm;
        end

        local item1 = spell_name_from_id(p1) or item_name_from_id(p1) or '';
        local item2 = spell_name_from_id(p2) or item_name_from_id(p2) or '';
        if (item1 == '' and GetEntity ~= nil) then
            for _, idx in ipairs(T{ actIndexTar, actIndexCas }) do
                idx = tonumber(idx) or 0;
                if (idx > 0) then
                    local ent = GetEntity(idx);
                    if (ent ~= nil and ent.Name ~= nil) then
                        local nm = tostring(ent.Name):gsub('%z.*', '');
                        if (nm ~= '' and nm ~= 'nil') then
                            item1 = nm;
                            break;
                        end
                    end
                end
            end
        end
        out = out:gsub('%${item2}', item2);
        out = out:gsub('%${item}', item1);

        if (selfEnt ~= nil and selfEnt.Name ~= nil and (playerSid == selfSid or targetSid == selfSid)) then
            local nm = tostring(selfEnt.Name):gsub('%z.*', '');
            if (nm ~= nil and nm ~= '') then
                out = out:gsub('%${actor}', nm);
                out = out:gsub("%${actor}'s", nm .. "'s");
                out = out:gsub('%${player}', nm);
            end
        end
        return clean_str(out);
    end

    local text = fmt_btlmess(templ);
    if (text == nil or text == '') then
        text = ('[KillMsg %u] type=%u p1=%u p2=%u'):fmt(mid, tonumber(typeByte) or 0, tonumber(p1) or 0, tonumber(p2) or 0);
    end

    local purpose = 'System';
    if (message_is_catseye_gov_progress(text)) then
        purpose = 'GoV';
    end

    local committed, shown = append_entry(T{
        time = os.date('[%H:%M:%S]'),
        sender = 'System',
        zone = nil,
        purpose = purpose,
        channel = 'system',
        modeID = '2d',
        modeBaseID = '2d',
        rawMessage = nil,
        message = text,
        injected = false,
        isTell = false,
        killMsgId = mid,
    });
    if (committed and shown) then
        record_packet_chat_line(text, true);
    end
end

local function handle_event_packet_0x32(e)
    if (e == nil or e.data == nil or #e.data < 0x14) then
        return;
    end
    local uniqueNo = struct.unpack('I', e.data, 0x04 + 1);
    local actIndex = struct.unpack('H', e.data, 0x08 + 1);
    local senderName = nil;
    if (actIndex ~= nil and tonumber(actIndex) ~= nil and tonumber(actIndex) > 0 and GetEntity ~= nil) then
        local ent = GetEntity(tonumber(actIndex));
        if (ent ~= nil and ent.Name ~= nil and tostring(ent.Name) ~= '') then
            senderName = tostring(ent.Name):gsub('%z.*', '');
            lastNpcDialog.sender = senderName;
            lastNpcDialog.time = os.clock();
        end
    end

    local resolved = resolve_gp_serv_event_0x32_text(e.data);
    if (resolved ~= nil and resolved ~= '') then
        local msg = clean_str(resolved);
        if (msg ~= nil and msg ~= '') then
            local committed, shown = append_entry(T{
                time = os.date('[%H:%M:%S]'),
                sender = (senderName ~= nil and senderName ~= '') and senderName or 'NPC',
                zone = nil,
                purpose = 'NPC',
                channel = 'npc',
                modeID = '32',
                modeBaseID = '32',
                rawMessage = nil,
                message = msg,
                injected = false,
                indent = 0,
                isTell = false,
                tellDirection = nil,
                tellName = nil,
                uniqueNo = uniqueNo,
                actIndex = actIndex,
            });
            if (committed and shown) then
                record_packet_chat_line(msg, true);
            end
        end
    end
end

chatlog.handle_packet_in = function(e)
    if (e.id == 0x32) then
        handle_event_packet_0x32(e);
        return;
    end

    if (e.id == 0x2D) then
        handle_kill_message_packet_0x2d(e);
        return;
    end

    if (e.id == 0x29) then
        local mob_check = require('mob_check');
        local parsed = mob_check.parse_0x29(e);
        if (parsed ~= nil and mob_check.should_block_native(parsed.messageId, parsed.checkType)) then
            local entity = GetEntity(parsed.targetIndex);
            local bodyColor = get_purpose_color('Check');
            local plain, raw, segments = mob_check.build_chat_display(
                entity,
                parsed.messageId,
                parsed.level,
                parsed.checkType,
                parsed.targetIndex,
                bodyColor
            );
            if (plain ~= nil and plain ~= '') then
                local committed, shown = append_entry(T{
                    time = os.date('[%H:%M:%S]'),
                    sender = 'System',
                    zone = nil,
                    purpose = 'Check',
                    channel = 'check',
                    modeID = '29',
                    modeBaseID = '29',
                    rawMessage = raw,
                    message = clean_str(plain),
                    segments = segments,
                    injected = false,
                });
                if (committed and shown) then
                    record_packet_chat_line(plain, true);
                end
            end
            return;
        end
    end

    if (e.id == 0x28 or e.id == 0x29) then
        local combatParse = require('combatParse');
        if (combatParse.emit_packet_combat ~= nil) then
            combatParse.emit_packet_combat(e, function(purpose, message)
                chatlog.lastCombatPacketEmitClock = os.clock();
                if (purpose == 'Spell Cast') then
                    chatlog.note_recent_trust_spell_cast(message);
                end
                local committed, shown = append_entry(T{
                    time = os.date('[%H:%M:%S]'),
                    sender = 'Battle',
                    zone = nil,
                    purpose = purpose,
                    channel = 'combat',
                    modeID = string.format('%x', e.id),
                    rawMessage = message,
                    message = clean_str(message),
                    injected = false,
                });
                if (committed and shown) then
                    record_packet_chat_line(message, true);
                end
            end);
        end
        return;
    end

    if (e.id == 0x27) then
        handle_string_message_packet_0x27(e);
        return;
    end
    if (e.id == 0x4D) then
        handle_servmes_packet_0x4d(e);
        return;
    end
    if (e.id == 0x53) then
        handle_system_message_packet_0x53(e);
        return;
    end

    if (e.id == 0x17) then
        local kind = struct.unpack('B', e.data, 0x04 + 1);
        local attr = struct.unpack('B', e.data, 0x05 + 1);
        local data = struct.unpack('H', e.data, 0x06 + 1);
        local sender = unpack_inbound_chat_sender(e.data);
        local message = unpack_inbound_chat_message_0x17(e);

        if (sender ~= nil and string.find(sender, 'CUSTOM_MENU')) then
            return;
        end

        local purpose = setmode(kind) or 'None';
        local cleaned = clean_str(message or '');

        do
            local allowNamePrefixPromote =
                (kind == 0x0D or kind == 0x0E or kind == 0x0F or kind == 0x10 or kind == 0x1C or kind == 0x1F)
                or (sender == nil or sender == '' or sender == 'System');
            if (allowNamePrefixPromote) then
                local n, rest = cleaned:match('^%s*([^:]+)%s+:%s+(.+)$');
                if (n ~= nil and rest ~= nil and n ~= '' and rest ~= '') then
                    purpose = 'NPC';
                    sender = n;
                    cleaned = rest;
                end
            end
        end

        do
            local now = os.clock();
            if (purpose ~= 'NPC'
                and kind == 0x0D
                and cleaned ~= nil
                and cleaned:sub(1, 1) == ' '
                and lastNpcDialog.sender ~= nil
                and (now - (tonumber(lastNpcDialog.time) or 0)) < 3.0) then
                purpose = 'NPC';
                sender = lastNpcDialog.sender;
                cleaned = cleaned:gsub('^%s+', '');
            end
        end

        if (sender == nil or sender == '') then
            sender = 'System';
        end
        if (attr ~= nil and bit.band(attr, 0x01) ~= 0) then
            if (sender ~= 'System') then
                sender = '[GM] ' .. tostring(sender);
            end
        end

        local zone = nil;
        if (kind == 0x1A) then
            zone = tonumber(data) or nil; -- Yell: sender zone id.
        end

        local playerName = get_player_name_safe();
        if (sender == playerName) then
            local now = os.clock();
            if (cleaned:find("Today's Goblin Ventures", 1, true)
                or cleaned:find('Pool A:', 1, true)
                or cleaned:find('Pool B:', 1, true)
                or cleaned:find('HVNM:', 1, true)
                or cleaned:find('!ventures', 1, true)
                ) then
                venturesEchoUntil = now + 1.25;
                sender = 'System';
                purpose = 'None';
            elseif (venturesEchoUntil ~= nil and now < venturesEchoUntil) then
                sender = 'System';
                purpose = 'None';
            end
        end

        local tellDir;
        local tellPeer;
        if (purpose == 'Tell') then
            tellDir = 'in';
            tellPeer = sender;
            if (tellPeer ~= nil and tellPeer ~= '') then
                chatlog.lastTellFrom = tellPeer;
            end
        end

        if (purpose == 'NPC') then
            local digits = cleaned:match('^%s*(%d+)%s*$');
            if (digits ~= nil) then
                local resolved = npc_dialog_string_lookup(tonumber(digits));
                if (resolved ~= nil and resolved ~= '') then
                    cleaned = resolved;
                    message = resolved;
                end
            end
        end

        local entry = T{
            time = os.date('[%H:%M:%S]'),
            sender = sender,
            zone = zone,
            purpose = purpose,
            channel = 'chat',
            modeID = string.format('%x', kind),
            rawMessage = message,
            message = cleaned,
            isTell = (purpose == 'Tell'),
            tellDirection = tellDir,
            tellName = tellPeer,
        };
        reclassify_routed_miss_battle_line(entry);
        reclassify_addon_bracket_system_line(entry);
        tag_experience_chat_entry(entry);
        if (should_suppress_retail_battle_message_echo(entry)) then
            return;
        end
        local committed, shown = append_entry(entry);
        if (committed and shown) then
            record_packet_chat_line(cleaned, true);
            record_linkshell_echo_dedupe_keys(sender, purpose, cleaned);
            record_party_echo_dedupe_keys(sender, purpose, cleaned);
            if (purpose == 'Say') then
                record_say_echo_dedupe_keys(sender, cleaned);
            end
        end
        if (purpose == 'NPC' and sender ~= nil and sender ~= '' and sender ~= 'System') then
            lastNpcDialog.sender = sender;
            lastNpcDialog.time = os.clock();
        end
        return;
    end

    if (e.id == 0x36) then
        local uniqueNo = struct.unpack('L', e.data, 0x04 + 1);
        local actIndex = struct.unpack('H', e.data, 0x08 + 1);
        local mesNum = struct.unpack('H', e.data, 0x0A + 1);
        local msgIndex = bit.band(tonumber(mesNum) or 0, 0x7FFF);
        local ignoreName = bit.band(tonumber(mesNum) or 0, 0x8000) ~= 0;

        local sender = 'System';
        if (ignoreName ~= true and actIndex ~= nil and actIndex > 0) then
            local ent = GetEntity and GetEntity(actIndex) or nil;
            if (ent ~= nil and ent.Name ~= nil and tostring(ent.Name) ~= '') then
                sender = tostring(ent.Name):gsub('%z.*', '');
            end
        end

        local text = npc_dialog_string_lookup(msgIndex);
        if (text == nil or text == '') then
            text = ('[SevMess:%d]'):fmt(msgIndex);
        end

        local committed, shown = append_entry(T{
            time = os.date('[%H:%M:%S]'),
            sender = sender,
            zone = nil,
            purpose = 'NPC',
            channel = 'npc',
            modeID = '36',
            modeBaseID = '36',
            rawMessage = nil,
            message = clean_str(text),
            injected = false,
            indent = 0,
            isTell = false,
            tellDirection = nil,
            tellName = nil,
            uniqueNo = uniqueNo,
            actIndex = actIndex,
        });
        if (committed and shown) then
            record_packet_chat_line(text, true);
        end
        return;
    end

    return;
end

chatlog.handle_packet_out = function(e)
    if (e.id == 0x0B5) then
        local mode = struct.unpack('b', e.data, 0x04 + 1);
        local message = struct.unpack('s', e.data_modified, 0x07);
        local purpose = setmode(mode) or 'None';
        if (string.format('%x', mode) == '1') then
            purpose = 'Shout';
        end
        if (purpose ~= nil and purpose ~= 'None') then
            chatlog.lastInputPurpose = purpose;
        end

        append_entry(T{
            time = os.date('[%H:%M:%S]'),
            sender = get_player_name_safe(),
            purpose = purpose,
            channel = 'chat',
            modeID = string.format('%x', mode),
            rawMessage = message,
            message = clean_str(message),
            isTell = false,
        });
    elseif (e.id == 0x0B6) then
        local sender = struct.unpack('s', e.data_modified, 0x07);
        local message = struct.unpack('s', e.data_modified, 0x16);
        if (sender ~= nil and string.find(sender, 'CUSTOM_MENU')) then
            return;
        end
        if (sender ~= nil and sender ~= '') then
            chatlog.lastTellTo = sender;
            chatlog.lastInputPurpose = 'Tell';
        end

        append_entry(T{
            time = os.date('[%H:%M:%S]'),
            sender = sender,
            purpose = 'Tell',
            channel = 'chat',
            modeID = 'b6',
            rawMessage = message,
            message = clean_str(message),
            isTell = true,
            tellDirection = 'out',
            tellName = sender,
        });
    end
end

chatlog.handle_text_in = function(e)
    if (e == nil or e.mode == 0x500009d or e.mode == 0x102be) then
        return;
    end

    local resolvedMode, resolvedBaseMode = resolve_mode(e.mode);
    local entry = T{
        time = os.date('[%H:%M:%S]'),
        sender = 'System',
        channel = 'system',
        purpose = resolvedMode or 'None',
        modeID = string.format('%x', e.mode),
        modeBaseID = string.format('%x', resolvedBaseMode or 0),
        rawMessage = e.message,
        message = clean_str(e.message),
        injected = e.injected,
        indent = e.indent,
        isTell = false,
        fromTextIn = true,
    };

    local function drop_text_in(reason)
        debug_log_text_in_not_shown(entry, reason);
    end

    if (string.find(entry.modeID, '4079') or message_is_catseye_gov_progress(entry.message)) then
        entry.purpose = 'GoV';
    end

    if (not glam_no_chat_suppression() and entry.sender ~= nil and string.find(entry.sender, 'CUSTOM_MENU')) then
        drop_text_in('custom_menu');
        return;
    end

    if (looks_like_formatted_chat_echo(entry.message, get_player_name_safe())) then
        drop_text_in('formatted_chat_echo');
        return;
    end

    if (should_suppress_packet_echo_dup_always(entry.message)) then
        drop_text_in('packet_echo_dup');
        return;
    end

    if (not isChatMode[entry.purpose]) then
        local lowPurpose = setmode(bit.band(tonumber(e.mode) or 0, 0xFFFF));
        if (isChatMode[lowPurpose]) then
            entry.purpose = lowPurpose;
        else
            local name, rest = entry.message:match('^%s*([^:]+)%s+:%s+(.+)$');
            if (name ~= nil and rest ~= nil and name ~= '' and rest ~= '') then
                entry.purpose = 'NPC';
                entry.sender = name;
                entry.message = rest;
            end
        end
    end

    reclassify_routed_miss_battle_line(entry);
    reclassify_addon_bracket_system_line(entry);
    tag_experience_chat_entry(entry);

    if (entry.purpose == 'NPC' and entry.experienceLine ~= true
        and should_suppress_npc_dialog_dup(entry.sender, entry.message)) then
        drop_text_in('npc_dialog_dup');
        return;
    end

    if (should_suppress_battle_log_text_in_echo(entry, e.mode)) then
        drop_text_in('battle_log_echo');
        return;
    end

    if (should_suppress_system_mode_combat_text_in_echo(entry)) then
        drop_text_in('system_mode_combat_echo');
        return;
    end

    if (should_suppress_retail_battle_message_echo(entry)) then
        drop_text_in('retail_battle_echo');
        return;
    end

    if (message_looks_like_broken_trust_join_echo(entry.message)) then
        drop_text_in('broken_trust_join_echo');
        return;
    end

    if (not glam_no_chat_suppression() and isChatMode[entry.purpose] and entry.purpose ~= 'Emote') then
        drop_text_in('chat_mode_0x17_dup');
        return;
    end

    if (should_suppress_as_packet_chat_dup(entry.message)) then
        drop_text_in('packet_chat_dup');
        return;
    end

    append_entry(entry);
end

chatlog.npc_dialog_string_lookup = npc_dialog_string_lookup;
chatlog.lookup_display_message_template = lookup_display_message_template;
chatlog.resolve_gp_serv_event_0x32_text = resolve_gp_serv_event_0x32_text;

chatlog.append_custom_entry = function(entry)
    if (entry == nil) then
        return;
    end
    entry.customChat = true;
    entry.injected = true;
    append_entry(entry);
end;

return chatlog;
