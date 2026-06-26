require('common');

local M = {};

local ARROW = string.char(129, 168);
local ROLL_SEP = string.char(129, 170);
M.ARROW = ARROW;

local TEXT = {
    line_aoe = ('AOE ${numb} %s ${target}'):fmt(ARROW),
    line_aoebuff = ('${actor} ${abil} %s ${target} (${status})'):fmt(ARROW),
    line_full = ('[${actor}] ${numb} ${abil} %s ${target}'):fmt(ARROW),
    line_itemnum = ('[${actor}] ${abil} %s ${target} (${numb} ${item2})'):fmt(ARROW),
    line_item = ('[${actor}] ${abil} %s ${target} (${item2})'):fmt(ARROW),
    line_steal = ('[${actor}] ${abil} %s ${target} (${item})'):fmt(ARROW),
    line_noability = ('${numb} %s ${target}'):fmt(ARROW),
    line_noactor = ('${abil} ${numb} %s ${target}'):fmt(ARROW),
    line_nonumber = ('[${actor}] ${abil} %s ${target}'):fmt(ARROW),
    line_notarget = ('[${actor}] ${abil} %s ${number}'):fmt(ARROW),
    --- Msg 140: no ${target} in retail ("finds a ${item2}") — item after arrow is the recovered ammo/item id.
    line_item_direct = ('[${actor}] ${abil} %s ${item2}'):fmt(ARROW),
    line_roll = ('${actor} ${abil} %s ${target} %s ${number}'):fmt(ARROW, ROLL_SEP),
};

local EXCLUDED = T{
    23, 64, 133, 204, 210, 211, 212, 213, 214, 350, 442, 516, 531, 557, 565, 582,
    --- Records of Eminence / FoV-GoV (${regime}, ${number}/${number2}) — simplify drops placeholders.
    558, 690, 697, 698, 704, 705, 740,
    --- /checkparam and other debug stat readouts (hit-eva, atk-def, HIT-EVA, ATK-DEF, etc.).
    79, 80, 81, 99, 105, 179, 180, 181, 182, 183, 184,
    --- Experience / limit / capacity point messages (keep retail wording).
    8, 10, 21, 37, 253, 371, 372, 718, 735,
};

local STATUS_FORCE = T{
    93, 273, 522, 653, 654, 655, 656, 85, 284, 75, 114, 156, 189, 248, 283, 312, 323, 336, 351, 355, 408, 422, 423, 425, 453, 659, 158, 245, 324, 658,
};

local ABILITY_SC_IDS = T{
    129, 152, 161, 162, 163, 165, 229, 384, 453, 603, 652, 798,
};

local DESPOIL_LABEL = {
    [593] = 'Attack Down',
    [594] = 'Defense Down',
    [595] = 'Magic Atk. Down',
    [596] = 'Magic Def. Down',
    [597] = 'Evasion Down',
    [598] = 'Accuracy Down',
    [599] = 'Slow',
};

function M.search_fields(message)
    local fieldarr = {};
    if (message == nil) then
        return fieldarr;
    end
    string.gsub(message, '{(.-)}', function(a)
        fieldarr[a] = true;
    end);
    return fieldarr;
end

function M.apply_field_overrides(msg_id, fields)
    if (EXCLUDED:contains(msg_id)) then
        return;
    end
    if (STATUS_FORCE:contains(msg_id)) then
        fields.status = true;
    end
    if (msg_id == 31 or msg_id == 798 or msg_id == 799) then
        fields.actor = true;
    end
    if ((msg_id > 287 and msg_id < 303) or (msg_id > 384 and msg_id < 399) or (msg_id > 766 and msg_id < 771) or ABILITY_SC_IDS:contains(msg_id)) then
        fields.ability = true;
    end
    if (T{ 125, 593, 594, 595, 596, 597, 598, 599 }:contains(msg_id)) then
        fields.ability = true;
        fields.item = true;
    end
    if (T{ 129, 152, 153, 160, 161, 162, 163, 164, 165, 166, 167, 168, 229, 244, 652 }:contains(msg_id)) then
        fields.actor = true;
        fields.target = true;
    end
    if (msg_id == 139) then
        fields.number = true;
    end
end

function M.pick_template(msg_id, fields)
    if (EXCLUDED:contains(msg_id)) then
        return nil;
    end
    if (TEXT.line_item_direct and msg_id == 140 and fields.item2) then
        return TEXT.line_item_direct;
    end
    if (TEXT.line_full and fields.number and fields.target and fields.actor) then
        return TEXT.line_full;
    end
    if (TEXT.line_aoebuff and fields.status and fields.target) then
        return TEXT.line_aoebuff;
    end
    if (TEXT.line_item and fields.item2) then
        if (fields.number) then
            return TEXT.line_itemnum;
        end
        return TEXT.line_item;
    end
    if (TEXT.line_steal and fields.item and fields.ability) then
        if (T{ 593, 594, 595, 596, 597, 598, 599 }:contains(msg_id)) then
            local ae = DESPOIL_LABEL[msg_id] or '';
            return TEXT.line_steal .. '\7' .. 'AE: ' .. ae;
        end
        return TEXT.line_steal;
    end
    if (TEXT.line_nonumber and not fields.number) then
        return TEXT.line_nonumber;
    end
    if (TEXT.line_aoe and T{ 264 }:contains(msg_id)) then
        return TEXT.line_aoe;
    end
    if (TEXT.line_noactor and not fields.actor and (fields.spell or fields.ability or fields.item or fields.weapon_skill)) then
        return TEXT.line_noactor;
    end
    if (TEXT.line_noability and not fields.actor) then
        return TEXT.line_noability;
    end
    if (TEXT.line_notarget and fields.actor and fields.number) then
        if (msg_id == 798) then
            return TEXT.line_notarget .. '%';
        end
        if (msg_id == 799) then
            return TEXT.line_notarget .. '% (${actor} overloaded)';
        end
        return TEXT.line_notarget;
    end
    return nil;
end

--- Plain English label for spell/JA/WS/item from resources (SpellParse-style, no colors).
function M.english_simp_name(act, msg_id, m, plain_action_label)
    local cat = tonumber(act.category) or 0;
    local plain = plain_action_label();

    if (m.reaction == 11 and cat == 1) then
        return 'parried by';
    end
    if (msg_id == 1 and (cat == 1 or cat == 11)) then
        return 'hit';
    end
    if (msg_id == 15) then
        return 'missed';
    end
    if (msg_id == 29 or msg_id == 84) then
        return 'is paralyzed';
    end
    if (msg_id == 30) then
        return 'anticipated by';
    end
    if (msg_id == 31) then
        return 'absorbed by';
    end
    if (msg_id == 32) then
        return 'dodged by';
    end
    if (msg_id == 67 and (cat == 1 or cat == 11)) then
        return 'critical hit';
    end
    if (msg_id == 106) then
        return 'intimidated by';
    end
    if (msg_id == 153) then
        return plain .. ' fails';
    end
    if (msg_id == 244) then
        return 'Mug fails';
    end
    if (msg_id == 282) then
        return 'evaded by';
    end
    if (msg_id == 373) then
        return 'absorbed by';
    end
    if (msg_id == 352) then
        return 'RA';
    end
    if (msg_id == 353) then
        return 'critical RA';
    end
    if (msg_id == 354) then
        return 'missed RA';
    end
    if (msg_id == 576) then
        return 'RA hit squarely';
    end
    if (msg_id == 577) then
        return 'RA struck true';
    end
    if (msg_id == 157) then
        return 'Barrage';
    end
    if (msg_id == 76) then
        return 'No targets within range';
    end
    if (msg_id == 77) then
        return 'Sange';
    end
    if (msg_id == 360) then
        return plain .. ' (JA reset)';
    end
    if (msg_id == 426 or msg_id == 427) then
        return 'Bust! ' .. plain;
    end
    if (msg_id == 435 or msg_id == 436) then
        return plain .. ' (JAs)';
    end
    if (msg_id == 437 or msg_id == 438) then
        return plain .. ' (JAs and TP)';
    end
    if (msg_id == 439 or msg_id == 440) then
        return plain .. ' (SPs, JAs, TP, and MP)';
    end
    if (T{ 252, 265, 268, 269, 271, 272, 274, 275, 379, 650, 747 }:contains(msg_id)) then
        return 'Magic Burst! ' .. plain;
    end

    return plain;
end

return M;
