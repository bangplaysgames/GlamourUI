require('common');

local bit = require('bit');
local action_packet28 = require('action_packet28');

local SPELL_TO_DEBUFF = T{
    [230] = 135, [23] = 134, [33] = 134, [24] = 134, [25] = 134,
    [58] = 4, [80] = 4, [56] = 13, [79] = 13, [357] = 13,
    [216] = 12, [217] = 12, [254] = 5, [276] = 5, [361] = 5,
    [59] = 6, [359] = 6, [253] = 2, [259] = 2, [273] = 2, [274] = 2,
    [258] = 11, [362] = 11, [252] = 10, [220] = 3, [221] = 3, [222] = 3,
    [223] = 3, [224] = 3, [225] = 3, [226] = 3, [227] = 3, [228] = 3, [229] = 3,
    [536] = 3,
    [239] = 132, [238] = 131, [237] = 130, [236] = 129, [608] = 129, [235] = 128, [240] = 133,
    [421] = 194, [422] = 194, [423] = 194,
    [368] = 192, [369] = 192, [370] = 192, [371] = 192, [372] = 192, [373] = 192,
    [463] = 193, [376] = 193,
    [454] = 217, [455] = 217, [456] = 217, [457] = 217, [458] = 217, [459] = 217,
    [460] = 217, [461] = 217,
    [278] = 186, [279] = 186, [280] = 186, [281] = 186, [282] = 186, [283] = 186, [284] = 186, [285] = 186,
    [885] = 186, [886] = 186, [887] = 186, [888] = 186, [889] = 186, [890] = 186, [891] = 186, [892] = 186,
    [231] = 135, [232] = 135,
    [112] = 156,
    [34] = 3, [35] = 3,
};

local buffTable = {};
buffTable.GetBuffIdBySpellId = function(spellId)
    return SPELL_TO_DEBUFF[spellId];
end

local enemy_debuff_tracker = {};
enemy_debuff_tracker.enemies = T{};

local reusableDebuffIds = {};
local reusableDebuffTimes = {};

local statusOnMes = {[101]=true, [127]=true, [160]=true, [164]=true, [166]=true, [186]=true, [194]=true, [203]=true, [205]=true, [230]=true, [236]=true, [266]=true, [267]=true, [268]=true, [269]=true, [237]=true, [271]=true, [272]=true, [277]=true, [278]=true, [279]=true, [280]=true, [319]=true, [320]=true, [375]=true, [412]=true, [645]=true, [754]=true, [755]=true, [804]=true};
local statusOffMes = {[64]=true, [159]=true, [168]=true, [204]=true, [206]=true, [321]=true, [322]=true, [341]=true, [342]=true, [343]=true, [344]=true, [350]=true, [378]=true, [531]=true, [647]=true, [805]=true, [806]=true};
local deathMes = {[6]=true, [20]=true, [97]=true, [113]=true, [406]=true, [605]=true, [646]=true};
local spellDamageMes = {[2]=true, [252]=true, [264]=true, [265]=true};
local additionalEffectJobAbilities = {[22]=true, [45]=true, [46]=true, [77]=true};
local additionalEffectMes = {[160]=true, [164]=true};

local SPELL_DURATIONS = {
    [181] = {duration = 180, buffId = 149},
    [83] = {duration = 180, buffId = 149},
    [87] = {duration = 180, buffIds = {149, 147}},
    [155] = {duration = 180, buffId = 149},
    [187] = {duration = 180, buffId = 149},
    [89] = {duration = 180, buffId = 149},
    [85] = {duration = 180, buffId = 147},
    [185] = {duration = 180, buffId = 147},
    [107] = {duration = 180, buffId = 147},
    [16] = {duration = 90, buffId = 3},
    [17] = {duration = 90, buffId = 3},
    [18] = {duration = 30, buffId = 11},
    [35] = { wsPoison = 'viper' },
    [34] = { wsPoison = 'wasp' },
    [115] = {duration = 5, buffId = 10},
    [2] = {duration = 5, buffId = 10},
    [65] = {duration = 5, buffId = 10},
    [162] = {duration = 5, buffId = 10},
    [145] = {duration = 5, buffId = 10},
    [23] = {duration = 60}, [33] = {duration = 60}, [230] = {duration = 60},
    [24] = {duration = 120}, [231] = {duration = 120},
    [25] = {duration = 150}, [232] = {duration = 150},
    [278] = {duration = 90, buffId = 186}, [279] = {duration = 90, buffId = 186},
    [280] = {duration = 90, buffId = 186}, [281] = {duration = 90, buffId = 186},
    [282] = {duration = 90, buffId = 186}, [283] = {duration = 90, buffId = 186},
    [284] = {duration = 90, buffId = 186}, [285] = {duration = 90, buffId = 186},
    [885] = {duration = 90, buffId = 186}, [886] = {duration = 90, buffId = 186},
    [887] = {duration = 90, buffId = 186}, [888] = {duration = 90, buffId = 186},
    [889] = {duration = 90, buffId = 186}, [890] = {duration = 90, buffId = 186},
    [891] = {duration = 90, buffId = 186}, [892] = {duration = 90, buffId = 186},
    [58] = {duration = 120}, [80] = {duration = 120}, [56] = {duration = 180}, [79] = {duration = 180},
    [216] = {duration = 120}, [254] = {duration = 180}, [276] = {duration = 180},
    [59] = {duration = 120}, [359] = {duration = 120}, [253] = {duration = 60}, [273] = {duration = 60},
    [363] = {duration = 60}, [259] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}},
    [274] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}}, [364] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}},
    [258] = {duration = 60}, [362] = {duration = 60}, [252] = {duration = 5},
    [220] = { duration = 90, poisonWs = 'wasp' },
    [221] = { duration = 120, poisonWs = 'viper' },
    [341] = {duration = 180}, [344] = {duration = 180}, [347] = {duration = 180},
    [342] = {duration = 300}, [345] = {duration = 300}, [348] = {duration = 300},
    [235] = {duration = 120}, [236] = {duration = 120}, [237] = {duration = 120}, [238] = {duration = 120},
    [239] = {duration = 120}, [240] = {duration = 120},
    [454] = {duration = 78}, [455] = {duration = 78}, [456] = {duration = 78}, [457] = {duration = 78},
    [458] = {duration = 78}, [459] = {duration = 78}, [460] = {duration = 78}, [461] = {duration = 78},
    [422] = {duration = 216}, [421] = {duration = 216},
    [376] = {duration = 30}, [463] = {duration = 30}, [321] = {duration = 60},
    [688] = {duration = 45}, [690] = {duration = 45}, [691] = {duration = 60}, [692] = {duration = 60},
    [693] = {duration = 30}, [694] = {duration = 30}, [695] = {duration = 30},
    [22] = {duration = 120, buffId = 13}, [45] = {duration = 30, buffId = 448},
    [46] = {duration = 6, buffId = 10}, [77] = {duration = 6, buffId = 10},
    [149] = {duration = 60, additionalEffect = true}, [12] = {duration = 30, additionalEffect = true},
    [1908] = {duration = 60, buffId = 2, type = 13},
    [112] = { duration = 12, buffId = 156 },
};

local FALLBACK_DURATION_SEC_BY_STATUS_ID = {
    [156] = 12,  -- FLASH (fallback when spell row missing)
    [10] = 5,    -- STUN
    [28] = 10,   -- TERROR
    [2] = 60,    -- SLEEP_I
    [19] = 90,   -- SLEEP_II
    [4] = 120,   -- PARALYSIS
    [5] = 180,   -- BLINDNESS
    [6] = 120,   -- SILENCE
    [13] = 180,  -- SLOW
    [11] = 60,   -- BIND
    [12] = 90,   -- WEIGHT
    [3] = 90,    -- POISON
    [134] = 60,  -- DIA (ballpark)
    [135] = 60,  -- BIO (ballpark)
    [186] = 90,  -- HELIX (ballpark)
    [193] = 60,  -- LULLABY (ballpark)
    [194] = 120, -- ELEGY (ballpark)
    [1] = 300,   -- WEAKNESS
    [7] = 60,    -- PETRIFICATION
    [8] = 180,   -- DISEASE
    [9] = 300,   -- CURSE_I
    [14] = 120, -- CHARM_I
    [15] = 60,   -- DOOM (display only; actual doom is special)
    [16] = 120,  -- AMNESIA
    [17] = 120,  -- CHARM_II
    [20] = 300,  -- CURSE_II
    [21] = 120,  -- ADDLE
    [22] = 60,   -- INTIMIDATE
    [23] = 60,   -- KAUSTRA
    [30] = 120,  -- BANE
    [31] = 90,   -- PLAGUE
    [128] = 90,  -- BURN
    [129] = 90,  -- FROST
    [130] = 90,  -- CHOKE
    [131] = 90,  -- RASP
    [132] = 90,  -- SHOCK
    [133] = 90,  -- DROWN
    [136] = 120, [137] = 120, [138] = 120, [139] = 120, [140] = 120, [141] = 120, [142] = 120,
    [146] = 120, [147] = 120, [148] = 120, [149] = 120, [150] = 120,
    [168] = 120, -- INHIBIT_TP
    [171] = 180, -- PAX
    [172] = 120, -- INTENSION
    [173] = 120, -- DREAD_SPIKES (mob debuff display)
    [174] = 120, -- MAGIC_ACC_DOWN
    [175] = 120, -- MAGIC_ATK_DOWN
    [189] = 120, -- MAX_TP_DOWN
    [192] = 120, -- REQUIEM
};

local POISON_WS_DURATION_CAP_SEC = 0;

local ENFEEBLING_POISON_SPELL_IDS = {
    [16] = true, -- Poison
    [17] = true, -- Poison II
};

local function tp_from_action_info(info)
    if (info == nil) then
        return nil;
    end
    local n = tonumber(info);
    if (n == nil or n == 0) then
        return nil;
    end
    local lo = bit.band(n, 0xFFFF);
    if (lo > 3000 and lo <= 30000) then
        lo = math.floor(lo / 10);
    end
    if (lo >= 1000 and lo <= 3000) then
        return lo;
    end
    local mid = bit.band(bit.rshift(n, 8), 0xFFFF);
    if (mid >= 1000 and mid <= 3000) then
        return mid;
    end
    local hi = bit.band(bit.rshift(n, 16), 0xFFFF);
    if (hi >= 1000 and hi <= 3000) then
        return hi;
    end
    return nil;
end

local function duration_viper_bite_poison_from_tp(tp)
    if (tp == nil) then
        return 90;
    end
    if (tp >= 3000) then
        return 180;
    end
    if (tp >= 2000) then
        return 120;
    end
    return 90;
end

local function duration_wasp_sting_poison_from_tp(tp)
    if (tp == nil) then
        return 90;
    end
    if (tp >= 3000) then
        return 135;
    end
    if (tp >= 2000) then
        return 105;
    end
    return 90;
end

local function apply_poison_ws_cap(dur)
    local cap = tonumber(POISON_WS_DURATION_CAP_SEC) or 0;
    if (cap > 0 and dur ~= nil and dur > cap) then
        return cap;
    end
    return dur;
end

local function resolve_poison_weapon_skill_duration(spell, spellData, actionInfo)
    local tp = tp_from_action_info(actionInfo);
    local curve = spellData.wsPoison or spellData.poisonWs;
    local dur;
    if (curve == 'wasp') then
        dur = duration_wasp_sting_poison_from_tp(tp);
    else
        dur = duration_viper_bite_poison_from_tp(tp);
    end
    return apply_poison_ws_cap(dur);
end

local function ApplyMessage(debuffs, action)
    if (action == nil) then
        return;
    end

    local now = os.time();

    for _, target in pairs(action.Targets) do
        for _, ability in pairs(target.Actions) do
            local spell = action.Param;
            local message = ability.Message;
            local additionalEffect;

            if (ability.AdditionalEffect ~= nil and ability.AdditionalEffect.Message ~= nil) then
                additionalEffect = ability.AdditionalEffect.Message;
            end

            if (debuffs[target.Id] == nil) then
                debuffs[target.Id] = T{};
            end

            if action.Type == 13 and spell == 1908 then
                debuffs[target.Id][2] = now + 60;
            elseif action.Type == 3 and message == 185 then
                local spellData = SPELL_DURATIONS[spell];
                if spellData and spellData.duration then
                    if spellData.buffId then
                        debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                    end
                    if spellData.buffIds then
                        for _, buffId in ipairs(spellData.buffIds) do
                            debuffs[target.Id][buffId] = now + spellData.duration;
                        end
                    end
                end
            elseif action.Type == 4 and spellDamageMes[message] then
                local spellData = SPELL_DURATIONS[spell];
                if spellData and spellData.duration then
                    local expiry = now + spellData.duration;
                    if spell == 23 or spell == 24 or spell == 25 or spell == 33 then
                        debuffs[target.Id][134] = expiry;
                        debuffs[target.Id][135] = nil;
                    elseif spell == 230 or spell == 231 or spell == 232 then
                        debuffs[target.Id][134] = nil;
                        debuffs[target.Id][135] = expiry;
                    elseif (spell >= 278 and spell <= 285) or (spell >= 885 and spell <= 892) then
                        debuffs[target.Id][spellData.buffId] = expiry;
                    end
                end
            elseif statusOnMes[message] then
                local buffId = ability.Param or (action.Type == 4 and buffTable.GetBuffIdBySpellId(spell) or nil);
                if (buffId ~= nil) then
                    local spellData = SPELL_DURATIONS[spell];
                    if spellData then
                        if spellData.clearsBuffs then
                            for _, clearBuffId in ipairs(spellData.clearsBuffs) do
                                debuffs[target.Id][clearBuffId] = nil;
                            end
                        end
                        local paramStatus = ability.Param;
                        local finalBuffId;
                        if (paramStatus ~= nil and paramStatus > 0) then
                            finalBuffId = paramStatus;
                        else
                            finalBuffId = spellData.buffId or buffId;
                        end

                        local dur = spellData.duration;
                        if (spellData.wsPoison ~= nil and finalBuffId == 3) then
                            dur = resolve_poison_weapon_skill_duration(spell, spellData, action.Info);
                        elseif (spellData.poisonWs ~= nil and finalBuffId == 3) then
                            dur = resolve_poison_weapon_skill_duration(spell, spellData, action.Info);
                        elseif (finalBuffId == 3 and SPELL_TO_DEBUFF[spell] == 3 and not ENFEEBLING_POISON_SPELL_IDS[spell]) then
                            if (spell == 34 or spell == 220) then
                                dur = apply_poison_ws_cap(duration_wasp_sting_poison_from_tp(tp_from_action_info(action.Info)));
                            elseif (spell == 35 or spell == 221 or (spell >= 222 and spell <= 229)) then
                                dur = apply_poison_ws_cap(duration_viper_bite_poison_from_tp(tp_from_action_info(action.Info)));
                            end
                        elseif (spellData.buffId ~= nil and paramStatus ~= nil and paramStatus > 0 and spellData.buffId ~= paramStatus) then
                            dur = FALLBACK_DURATION_SEC_BY_STATUS_ID[paramStatus] or dur or 120;
                        elseif (dur == nil) then
                            dur = FALLBACK_DURATION_SEC_BY_STATUS_ID[finalBuffId] or 120;
                        end

                        debuffs[target.Id][finalBuffId] = now + dur;
                    else
                        local guess = FALLBACK_DURATION_SEC_BY_STATUS_ID[buffId] or 120;
                        if (buffId == 3 and spell >= 222 and spell <= 229) then
                            guess = apply_poison_ws_cap(duration_viper_bite_poison_from_tp(tp_from_action_info(action.Info)));
                        end
                        debuffs[target.Id][buffId] = now + guess;
                    end
                end
            elseif statusOffMes[message] then
                if (ability.Param == nil) then
                    -- skip
                else
                    debuffs[target.Id][ability.Param] = nil;
                end
            elseif action.Type == 3 and additionalEffectJobAbilities[spell] then
                local spellData = SPELL_DURATIONS[spell];
                if spellData and spellData.buffId and spellData.duration and (message == 185 or spell ~= 22) then
                    if (debuffs[target.Id][spellData.buffId] == nil or debuffs[target.Id][spellData.buffId] < now) then
                        debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                    end
                end
            elseif additionalEffect ~= nil and additionalEffectMes[additionalEffect] then
                local buffId = ability.AdditionalEffect.Param;
                if (buffId ~= nil) then
                    local spellData = SPELL_DURATIONS[buffId];
                    if spellData and spellData.additionalEffect and spellData.duration then
                        debuffs[target.Id][buffId] = now + spellData.duration;
                    else
                        debuffs[target.Id][buffId] = now + 30;
                    end
                end
            end
        end
    end
end

local function ClearMessage(debuffs, basic)
    if deathMes[basic.message] and debuffs[basic.target] then
        debuffs[basic.target] = nil;
    elseif (basic.message == 321) then
        if (debuffs[basic.target] == nil or basic.value == nil) then
            return;
        end
        debuffs[basic.target][basic.value] = nil;
    elseif statusOffMes[basic.message] then
        if debuffs[basic.target] == nil then
            return;
        end
        if (basic.param ~= nil) then
            if (basic.param == 2) then
                debuffs[basic.target][2] = nil;
                debuffs[basic.target][193] = nil;
                debuffs[basic.target][19] = nil;
            else
                debuffs[basic.target][basic.param] = nil;
            end
        end
    end
end

enemy_debuff_tracker.ingest_0x28_packet = function(e)
    if (e == nil or e.data == nil) then
        return;
    end
    local chat = (GlamourUI ~= nil and GlamourUI.settings ~= nil) and GlamourUI.settings.Chat or nil;
    local legacyHeader = (chat ~= nil and chat.actionPacket28LegacyHeader == true);
    local act = action_packet28.parse_action_packet(e.data, legacyHeader);
    if (act == nil or act.targets == nil) then
        return;
    end

    local xi = {
        Param = act.param,
        Type = act.category,
        Info = act.info,
        Targets = {},
    };
    for _, t in ipairs(act.targets) do
        local T = {
            Id = t.server_id,
            Actions = {},
        };
        for _, a in ipairs(t.actions or {}) do
            local ab = {
                Message = a.message,
                Param = a.param,
            };
            if (a.has_add_effect) then
                ab.AdditionalEffect = {
                    Message = a.add_effect_message,
                    Param = a.add_effect_param,
                };
            end
            table.insert(T.Actions, ab);
        end
        table.insert(xi.Targets, T);
    end
    ApplyMessage(enemy_debuff_tracker.enemies, xi);
end

enemy_debuff_tracker.handle_message_basic = function(basic)
    ClearMessage(enemy_debuff_tracker.enemies, basic);
end

enemy_debuff_tracker.clear_zone = function()
    enemy_debuff_tracker.enemies = {};
end

enemy_debuff_tracker.purge_server_id = function(serverId)
    if (serverId ~= nil and serverId ~= 0) then
        enemy_debuff_tracker.enemies[serverId] = nil;
    end
end

enemy_debuff_tracker.GetActiveDebuffs = function(serverId)
    if (enemy_debuff_tracker.enemies[serverId] == nil) then
        return nil;
    end

    local count = 0;
    for i = 1, #reusableDebuffIds do
        reusableDebuffIds[i] = nil;
        reusableDebuffTimes[i] = nil;
    end

    local currentTime = os.time();
    for buffId, expiryTime in pairs(enemy_debuff_tracker.enemies[serverId]) do
        if (expiryTime ~= 0 and expiryTime > currentTime) then
            count = count + 1;
            reusableDebuffIds[count] = buffId;
            reusableDebuffTimes[count] = expiryTime - currentTime;
        end
    end

    if count == 0 then
        return nil;
    end

    return reusableDebuffIds, reusableDebuffTimes;
end

return enemy_debuff_tracker;
