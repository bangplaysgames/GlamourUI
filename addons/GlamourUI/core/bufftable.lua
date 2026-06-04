--[[Table and functions created by Tirem.  https://github.com/Tirem
License for use as described in licenses contained at https://github.com/Tirem/HXUI
]]--

require('common');
local chat = require('chat');


local buffTable = {}

buffTable.debuffs =
T{
    [1]     =   'WEAKNESS',
    [2]     =   'SLEEP_I',
    [3]     =   'POISON',
    [4]     =   'PARALYSIS',
    [5]     =   'BLINDNESS',
    [6]     =   'SILENCE',
    [7]     =   'PETRIFICATION',
    [8]     =   'DISEASE',
    [9]     =   'CURSE_I',
    [10]    =   'STUN',
    [11]    =   'BIND',
    [12]    =   'WEIGHT',
    [13]    =   'SLOW',
    [14]    =   'CHARM_I',
    [15]    =   'DOOM',
    [16]    =   'AMNESIA',
    [17]    =   'CHARM_II',
    [18]    =   'GRADUAL_PETRIFICATION',
    [19]    =   'SLEEP_II',
    [20]    =   'CURSE_II',
    [21]    =   'ADDLE',
    [22]    =   'INTIMIDATE',
    [23]    =   'KAUSTRA',
    [28]    =   'TERROR',
    [29]    =   'MUTE',
    [30]    =   'BANE',
    [31]    =   'PLAGUE',
    [128]   =   'BURN',
    [129]   =   'FROST',
    [130]   =   'CHOKE',
    [131]   =   'RASP',
    [132]   =   'SHOCK',
    [133]   =   'DROWN',
    [134]   =   'DIA',
    [135]   =   'BIO',
    [136]   =   'STR_DOWN',
    [137]   =   'DEX_DOWN',
    [138]   =   'VIT_DOWN',
    [139]   =   'AGI_DOWN',
    [140]   =   'INT_DOWN',
    [141]   =   'MND_DOWN',
    [142]   =   'CHR_DOWN',
    [143]   =   'LEVEL_RESTRICTION',
    [144]   =   'MAX_HP_DOWN',
    [145]   =   'MAX_MP_DOWN',
    [146]   =   'ACCURACY_DOWN',
    [147]   =   'ATTACK_DOWN',
    [148]   =   'EVASION_DOWN',
    [149]   =   'DEFENSE_DOWN',
    [155]   =   'MEDICINE',
    [156]   =   'FLASH',
    [168]   =   'INHIBIT_TP',
    [171]   =   'PAX',
    [172]   =   'INTENSION',
    [173]   =   'DREAD_SPIKES',
    [174]   =   'MAGIC_ACC_DOWN',
    [175]   =   'MAGIC_ATK_DOWN',
    [186]   =   'HELIX',
    [189]   =   'MAX_TP_DOWN',
    [192]   =   'REQUIEM',
    [193]   =   'LULLABY',
    [194]   =   'ELEGY',
    [259]   =   'ENCUMBRANCE_I',
    [260]   =   'OBLIVISCENCE',
    [261]   =   'IMPAIRMENT',
    [262]   =   'OMERTA',
    [263]   =   'DEBILITATION',
    [264]   =   'PATHOS',
    [291]   =   'ENMITY_DOWN',
    [298]   =   'CRIT_HIT_EVASION_DOWN',
    [299]   =   'OVERLOAD',
    [309]   =   'BUST',
    [391]   =   'SLUGGISH_DAZE_1',
    [392]   =   'SLUGGISH_DAZE_2',
    [393]   =   'SLUGGISH_DAZE_3',
    [394]   =   'SLUGGISH_DAZE_4',
    [395]   =   'SLUGGISH_DAZE_5',
    [396]   =   'WEAKENED_DAZE_1',
    [397]   =   'WEAKENED_DAZE_2',
    [398]   =   'WEAKENED_DAZE_3',
    [399]   =   'WEAKENED_DAZE_4',
    [400]   =   'WEAKENED_DAZE_5',
    [448]   =   'BEWILDERED_DAZE_1',
    [449]   =   'BEWILDERED_DAZE_2',
    [450]   =   'BEWILDERED_DAZE_3',
    [451]   =   'BEWILDERED_DAZE_4',
    [452]   =   'BEWILDERED_DAZE_5',
    [404]   =   'MAGIC_EVASION_DOWN',
    [557]   =   'GEO_ATTACK_DOWN',
    [536]   =   'GAMBIT',
    [558]   =   'GEO_DEFENSE_DOWN',
    [559]   =   'GEO_MAGIC_ATK_DOWN',
    [560]   =   'GEO_MAGIC_DEF_DOWN',
    [561]   =   'GEO_ACCURACY_DOWN',
    [562]   =   'GEO_EVASION_DOWN',
    [563]   =   'GEO_MAGIC_ACC_DOWN',
    [564]   =   'GEO_MAGIC_EVASION_DOWN',
    [565]   =   'GEO_SLOW',
    [566]   =   'GEO_PARALYSIS',
    [567]   =   'GEO_WEIGHT',
    [572]   =   'AVOIDANCE_DOWN',
    [576]   =   'DOUBT',
    [597]   =   'INUNDATION',
    [630]   =   'TAINT',
    [631]   =   'HAUNT'
}

buffTable.IsBuff = function(buffId)
    -- If we are in the debuff table we are not a buff, otherwise we are
    if(buffTable.debuffs[buffId] == nil) then
        return false;
    else
        return true;
    end
end

return buffTable;