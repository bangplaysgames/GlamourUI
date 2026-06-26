--[[
    Weapon skill skillchain properties + skillchain resolution rules.

    Weapon skill table + chain-rule table ported from the "chains" Ashita addon
    (d:\...\Ashita\addons\chains\skills.lua, chains.lua) by Sippius / original
    Ashita-v3 skillchains by Ivaar. Used here under the same BSD-style license
    as the source (chains/skills.lua header): redistribution permitted with
    this attribution retained.

    BLU-physical-spell-under-Chain-Affinity/Azure-Lore and SCH-elemental-spell-
    under-Immanence tables ported from the "thotbar" Ashita addon
    (d:\...\Ashita\addons\thotbar\state\skillchain.lua), same addon-ecosystem
    attribution basis.
]]--

local M = {};

-- Weapon skill id -> { en = name, skillchain = { property, ... }, [aeonic=property, weapon=name] }
M.weapon_skills = {
    [1] = {en='Combo',skillchain={'Impaction'}},
    [2] = {en='Shoulder Tackle',skillchain={'Reverberation','Impaction'}},
    [3] = {en='One Inch Punch',skillchain={'Compression'}},
    [4] = {en='Backhand Blow',skillchain={'Detonation'}},
    [5] = {en='Raging Fists',skillchain={'Impaction'}},
    [6] = {en='Spinning Attack',skillchain={'Liquefaction','Impaction'}},
    [7] = {en='Howling Fist',skillchain={'Transfixion','Impaction'}},
    [8] = {en='Dragon Kick',skillchain={'Fragmentation'}},
    [9] = {en='Asuran Fists',skillchain={'Gravitation','Liquefaction'}},
    [10] = {en='Final Heaven',skillchain={'Light','Fusion'}},
    [11] = {en='Ascetic\'s Fury',skillchain={'Fusion','Transfixion'}},
    [12] = {en='Stringing Pummel',skillchain={'Gravitation','Liquefaction'}},
    [13] = {en='Tornado Kick',skillchain={'Induration','Detonation','Impaction'}},
    [14] = {en='Victory Smite',skillchain={'Light','Fragmentation'}},
    [15] = {en='Shijin Spiral',skillchain={'Fusion','Reverberation'},aeonic='Light',weapon='Godhand'},
    [16] = {en='Wasp Sting',skillchain={'Scission'}},
    [17] = {en='Viper Bite',skillchain={'Scission'}},
    [18] = {en='Shadowstitch',skillchain={'Reverberation'}},
    [19] = {en='Gust Slash',skillchain={'Detonation'}},
    [20] = {en='Cyclone',skillchain={'Detonation','Impaction'}},
    [23] = {en='Dancing Edge',skillchain={'Scission','Detonation'}},
    [24] = {en='Shark Bite',skillchain={'Fragmentation'}},
    [25] = {en='Evisceration',skillchain={'Gravitation','Transfixion'}},
    [26] = {en='Mercy Stroke',skillchain={'Darkness','Gravitation'}},
    [27] = {en='Mandalic Stab',skillchain={'Fusion','Compression'}},
    [28] = {en='Mordant Rime',skillchain={'Fragmentation','Distortion'}},
    [29] = {en='Pyrrhic Kleos',skillchain={'Distortion','Scission'}},
    [30] = {en='Aeolian Edge',skillchain={'Scission','Detonation','Impaction'}},
    [31] = {en='Rudra\'s Storm',skillchain={'Darkness','Distortion'}},
    [32] = {en='Fast Blade',skillchain={'Scission'}},
    [33] = {en='Burning Blade',skillchain={'Liquefaction'}},
    [34] = {en='Red Lotus Blade',skillchain={'Liquefaction','Detonation'}},
    [35] = {en='Flat Blade',skillchain={'Impaction'}},
    [36] = {en='Shining Blade',skillchain={'Scission'}},
    [37] = {en='Seraph Blade',skillchain={'Scission'}},
    [38] = {en='Circle Blade',skillchain={'Reverberation','Impaction'}},
    [40] = {en='Vorpal Blade',skillchain={'Scission','Impaction'}},
    [41] = {en='Swift Blade',skillchain={'Gravitation'}},
    [42] = {en='Savage Blade',skillchain={'Fragmentation','Scission'}},
    [43] = {en='Knights of Round',skillchain={'Light','Fusion'}},
    [44] = {en='Death Blossom',skillchain={'Fragmentation','Distortion'}},
    [45] = {en='Atonement',skillchain={'Fusion','Reverberation'}},
    [46] = {en='Expiacion',skillchain={'Distortion','Scission'}},
    [48] = {en='Hard Slash',skillchain={'Scission'}},
    [49] = {en='Power Slash',skillchain={'Transfixion'}},
    [50] = {en='Frostbite',skillchain={'Induration'}},
    [51] = {en='Freezebite',skillchain={'Induration','Detonation'}},
    [52] = {en='Shockwave',skillchain={'Reverberation'}},
    [53] = {en='Crescent Moon',skillchain={'Scission'}},
    [54] = {en='Sickle Moon',skillchain={'Scission','Impaction'}},
    [55] = {en='Spinning Slash',skillchain={'Fragmentation'}},
    [56] = {en='Ground Strike',skillchain={'Fragmentation','Distortion'}},
    [57] = {en='Scourge',skillchain={'Light','Fusion'}},
    [58] = {en='Herculean Slash',skillchain={'Induration','Detonation','Impaction'}},
    [59] = {en='Torcleaver',skillchain={'Light','Distortion'}},
    [60] = {en='Resolution',skillchain={'Fragmentation','Scission'},aeonic='Light',weapon='Lionheart'},
    [61] = {en='Dimidiation',skillchain={'Light','Fragmentation'}},
    [64] = {en='Raging Axe',skillchain={'Detonation','Impaction'}},
    [65] = {en='Smash Axe',skillchain={'Induration','Reverberation'}},
    [66] = {en='Gale Axe',skillchain={'Detonation'}},
    [67] = {en='Avalanche Axe',skillchain={'Scission','Impaction'}},
    [68] = {en='Spinning Axe',skillchain={'Liquefaction','Scission','Impaction'}},
    [69] = {en='Rampage',skillchain={'Scission'}},
    [70] = {en='Calamity',skillchain={'Scission','Impaction'}},
    [71] = {en='Mistral Axe',skillchain={'Fusion'}},
    [72] = {en='Decimation',skillchain={'Fusion','Reverberation'}},
    [73] = {en='Onslaught',skillchain={'Darkness','Gravitation'}},
    [74] = {en='Primal Rend',skillchain={'Gravitation','Reverberation'}},
    [75] = {en='Bora Axe',skillchain={'Scission','Detonation'}},
    [76] = {en='Cloudsplitter',skillchain={'Darkness','Fragmentation'}},
    [77] = {en='Ruinator',skillchain={'Distortion','Detonation'},aeonic='Darkness',weapon='Tri-Edge'},
    [80] = {en='Shield Break',skillchain={'Impaction'}},
    [81] = {en='Iron Tempest',skillchain={'Scission'}},
    [82] = {en='Sturmwind',skillchain={'Reverberation','Scission'}},
    [83] = {en='Armor Break',skillchain={'Impaction'}},
    [84] = {en='Keen Edge',skillchain={'Compression'}},
    [85] = {en='Weapon Break',skillchain={'Impaction'}},
    [86] = {en='Raging Rush',skillchain={'Induration','Reverberation'}},
    [87] = {en='Full Break',skillchain={'Distortion'}},
    [88] = {en='Steel Cyclone',skillchain={'Distortion','Detonation'}},
    [89] = {en='Metatron Torment',skillchain={'Light','Fusion'}},
    [90] = {en='King\'s Justice',skillchain={'Fragmentation','Scission'}},
    [91] = {en='Fell Cleave',skillchain={'Scission','Detonation','Impaction'}},
    [92] = {en='Ukko\'s Fury',skillchain={'Light','Fragmentation'}},
    [93] = {en='Upheaval',skillchain={'Fusion','Compression'},aeonic='Light',weapon='Chango'},
    [96] = {en='Slice',skillchain={'Scission'}},
    [97] = {en='Dark Harvest',skillchain={'Reverberation'}},
    [98] = {en='Shadow of Death',skillchain={'Induration','Reverberation'}},
    [99] = {en='Nightmare Scythe',skillchain={'Compression','Scission'}},
    [100] = {en='Spinning Scythe',skillchain={'Reverberation','Scission'}},
    [101] = {en='Vorpal Scythe',skillchain={'Transfixion','Scission'}},
    [102] = {en='Guillotine',skillchain={'Induration'}},
    [103] = {en='Cross Reaper',skillchain={'Distortion'}},
    [104] = {en='Spiral Hell',skillchain={'Distortion','Scission'}},
    [105] = {en='Catastrophe',skillchain={'Darkness','Gravitation'}},
    [106] = {en='Insurgency',skillchain={'Fusion','Compression'}},
    [107] = {en='Infernal Scythe',skillchain={'Compression','Reverberation'}},
    [108] = {en='Quietus',skillchain={'Darkness','Distortion'}},
    [109] = {en='Entropy',skillchain={'Gravitation','Reverberation'},aeonic='Darkness',weapon='Anguta'},
    [112] = {en='Double Thrust',skillchain={'Transfixion'}},
    [113] = {en='Thunder Thrust',skillchain={'Transfixion','Impaction'}},
    [114] = {en='Raiden Thrust',skillchain={'Transfixion','Impaction'}},
    [115] = {en='Leg Sweep',skillchain={'Impaction'}},
    [116] = {en='Penta Thrust',skillchain={'Compression'}},
    [117] = {en='Vorpal Thrust',skillchain={'Reverberation','Transfixion'}},
    [118] = {en='Skewer',skillchain={'Transfixion','Impaction'}},
    [119] = {en='Wheeling Thrust',skillchain={'Fusion'}},
    [120] = {en='Impulse Drive',skillchain={'Gravitation','Induration'}},
    [121] = {en='Geirskogul',skillchain={'Light','Distortion'}},
    [122] = {en='Drakesbane',skillchain={'Fusion','Transfixion'}},
    [123] = {en='Sonic Thrust',skillchain={'Transfixion','Scission'}},
    [124] = {en='Camlann\'s Torment',skillchain={'Light','Fragmentation'}},
    [125] = {en='Stardiver',skillchain={'Gravitation','Transfixion'},aeonic='Darkness',weapon='Trishula'},
    [128] = {en='Blade: Rin',skillchain={'Transfixion'}},
    [129] = {en='Blade: Retsu',skillchain={'Scission'}},
    [130] = {en='Blade: Teki',skillchain={'Reverberation'}},
    [131] = {en='Blade: To',skillchain={'Induration','Detonation'}},
    [132] = {en='Blade: Chi',skillchain={'Transfixion','Impaction'}},
    [133] = {en='Blade: Ei',skillchain={'Compression'}},
    [134] = {en='Blade: Jin',skillchain={'Detonation','Impaction'}},
    [135] = {en='Blade: Ten',skillchain={'Gravitation'}},
    [136] = {en='Blade: Ku',skillchain={'Gravitation','Transfixion'}},
    [137] = {en='Blade: Metsu',skillchain={'Darkness','Fragmentation'}},
    [138] = {en='Blade: Kamu',skillchain={'Fragmentation','Compression'}},
    [139] = {en='Blade: Yu',skillchain={'Reverberation','Scission'}},
    [140] = {en='Blade: Hi',skillchain={'Darkness','Gravitation'}},
    [141] = {en='Blade: Shun',skillchain={'Fusion','Impaction'},aeonic='Light',weapon='Heishi Shorinken'},
    [144] = {en='Tachi: Enpi',skillchain={'Transfixion','Scission'}},
    [145] = {en='Tachi: Hobaku',skillchain={'Induration'}},
    [146] = {en='Tachi: Goten',skillchain={'Transfixion','Impaction'}},
    [147] = {en='Tachi: Kagero',skillchain={'Liquefaction'}},
    [148] = {en='Tachi: Jinpu',skillchain={'Scission','Detonation'}},
    [149] = {en='Tachi: Koki',skillchain={'Reverberation','Impaction'}},
    [150] = {en='Tachi: Yukikaze',skillchain={'Induration','Detonation'}},
    [151] = {en='Tachi: Gekko',skillchain={'Distortion','Reverberation'}},
    [152] = {en='Tachi: Kasha',skillchain={'Fusion','Compression'}},
    [153] = {en='Tachi: Kaiten',skillchain={'Light','Fragmentation'}},
    [154] = {en='Tachi: Rana',skillchain={'Gravitation','Induration'}},
    [155] = {en='Tachi: Ageha',skillchain={'Compression','Scission'}},
    [156] = {en='Tachi: Fudo',skillchain={'Light','Distortion'}},
    [157] = {en='Tachi: Shoha',skillchain={'Fragmentation','Compression'},aeonic='Light',weapon='Dojikiri Yasutsuna'},
    [158] = {en='Tachi: Suikawari',skillchain={'Fusion'}},
    [160] = {en='Shining Strike',skillchain={'Impaction'}},
    [161] = {en='Seraph Strike',skillchain={'Impaction'}},
    [162] = {en='Brainshaker',skillchain={'Reverberation'}},
    [165] = {en='Skullbreaker',skillchain={'Induration','Reverberation'}},
    [166] = {en='True Strike',skillchain={'Detonation','Impaction'}},
    [167] = {en='Judgment',skillchain={'Impaction'}},
    [168] = {en='Hexa Strike',skillchain={'Fusion'}},
    [169] = {en='Black Halo',skillchain={'Fragmentation','Compression'}},
    [170] = {en='Randgrith',skillchain={'Light','Fragmentation'}},
    [172] = {en='Flash Nova',skillchain={'Induration','Reverberation'}},
    [174] = {en='Realmrazer',skillchain={'Fusion','Impaction'},aeonic='Light',weapon='Tishtrya'},
    [175] = {en='Exudation',skillchain={'Darkness','Fragmentation'}},
    [176] = {en='Heavy Swing',skillchain={'Impaction'}},
    [177] = {en='Rock Crusher',skillchain={'Impaction'}},
    [178] = {en='Earth Crusher',skillchain={'Detonation','Impaction'}},
    [179] = {en='Starburst',skillchain={'Compression','Reverberation'}},
    [180] = {en='Sunburst',skillchain={'Compression','Reverberation'}},
    [181] = {en='Shell Crusher',skillchain={'Detonation'}},
    [182] = {en='Full Swing',skillchain={'Liquefaction','Impaction'}},
    [184] = {en='Retribution',skillchain={'Gravitation','Reverberation'}},
    [185] = {en='Gate of Tartarus',skillchain={'Darkness','Distortion'}},
    [186] = {en='Vidohunir',skillchain={'Fragmentation','Distortion'}},
    [187] = {en='Garland of Bliss',skillchain={'Fusion','Reverberation'}},
    [188] = {en='Omniscience',skillchain={'Gravitation','Transfixion'}},
    [189] = {en='Cataclysm',skillchain={'Compression','Reverberation'}},
    [191] = {en='Shattersoul',skillchain={'Gravitation','Induration'},aeonic='Darkness',weapon='Khatvanga'},
    [192] = {en='Flaming Arrow',skillchain={'Liquefaction','Transfixion'}},
    [193] = {en='Piercing Arrow',skillchain={'Reverberation','Transfixion'}},
    [194] = {en='Dulling Arrow',skillchain={'Liquefaction','Transfixion'}},
    [196] = {en='Sidewinder',skillchain={'Reverberation','Transfixion','Detonation'}},
    [197] = {en='Blast Arrow',skillchain={'Induration','Transfixion'}},
    [198] = {en='Arching Arrow',skillchain={'Fusion'}},
    [199] = {en='Empyreal Arrow',skillchain={'Fusion','Transfixion'}},
    [200] = {en='Namas Arrow',skillchain={'Light','Distortion'}},
    [201] = {en='Refulgent Arrow',skillchain={'Reverberation','Transfixion'}},
    [202] = {en='Jishnu\'s Radiance',skillchain={'Light','Fusion'}},
    [203] = {en='Apex Arrow',skillchain={'Fragmentation','Transfixion'},aeonic='Light',weapon='Fail-Not'},
    [208] = {en='Hot Shot',skillchain={'Liquefaction','Transfixion'}},
    [209] = {en='Split Shot',skillchain={'Reverberation','Transfixion'}},
    [210] = {en='Sniper Shot',skillchain={'Liquefaction','Transfixion'}},
    [212] = {en='Slug Shot',skillchain={'Reverberation','Transfixion','Detonation'}},
    [213] = {en='Blast Shot',skillchain={'Induration','Transfixion'}},
    [214] = {en='Heavy Shot',skillchain={'Fusion'}},
    [215] = {en='Detonator',skillchain={'Fusion','Transfixion'}},
    [216] = {en='Coronach',skillchain={'Darkness','Fragmentation'}},
    [217] = {en='Trueflight',skillchain={'Fragmentation','Scission'}},
    [218] = {en='Leaden Salute',skillchain={'Gravitation','Transfixion'}},
    [219] = {en='Numbing Shot',skillchain={'Induration','Detonation','Impaction'}},
    [220] = {en='Wildfire',skillchain={'Darkness','Gravitation'}},
    [221] = {en='Last Stand',skillchain={'Fusion','Reverberation'},aeonic='Light',weapon='Fomalhaut'},
    [224] = {en='Exenterator',skillchain={'Fragmentation','Scission'},aeonic='Light',weapon='Aeneas'},
    [225] = {en='Chant du Cygne',skillchain={'Light','Distortion'}},
    [226] = {en='Requiescat',skillchain={'Gravitation','Scission'},aeonic='Darkness',weapon='Sequence'},
    [227] = {en='Knights of Rotund',skillchain={'Light'}},
    [228] = {en='Final Paradise',skillchain={'Light'}},
    [238] = {en='Uriel Blade',skillchain={'Light','Fragmentation'}},
    [239] = {en='Glory Slash',skillchain={'Light','Fusion'}},
};

-- property A -> property B -> { level, skillchain = result name }. property A is the
-- chain's current open property (from the WS that just landed); property B is a
-- candidate weapon skill's property. burst lists elements that detonate this chain step.
M.chain_info = {
    Radiance = {level = 4, burst = {'Fire','Wind','Lightning','Light'}},
    Umbra    = {level = 4, burst = {'Earth','Ice','Water','Dark'}},
    Light    = {level = 3, burst = {'Fire','Wind','Lightning','Light'},
        aeonic = {level = 4, skillchain = 'Radiance'},
        Light  = {level = 4, skillchain = 'Light'},
    },
    Darkness = {level = 3, burst = {'Earth','Ice','Water','Dark'},
        aeonic   = {level = 4, skillchain = 'Umbra'},
        Darkness = {level = 4, skillchain = 'Darkness'},
    },
    Gravitation = {level = 2, burst = {'Earth','Dark'},
        Distortion    = {level = 3, skillchain = 'Darkness'},
        Fragmentation = {level = 2, skillchain = 'Fragmentation'},
    },
    Fragmentation = {level = 2, burst = {'Wind','Lightning'},
        Fusion     = {level = 3, skillchain = 'Light'},
        Distortion = {level = 2, skillchain = 'Distortion'},
    },
    Distortion = {level = 2, burst = {'Ice','Water'},
        Gravitation = {level = 3, skillchain = 'Darkness'},
        Fusion      = {level = 2, skillchain = 'Fusion'},
    },
    Fusion = {level = 2, burst = {'Fire','Light'},
        Fragmentation = {level = 3, skillchain = 'Light'},
        Gravitation   = {level = 2, skillchain = 'Gravitation'},
    },
    Compression = {level = 1, burst = {'Darkness'},
        Transfixion = {level = 1, skillchain = 'Transfixion'},
        Detonation  = {level = 1, skillchain = 'Detonation'},
    },
    Liquefaction = {level = 1, burst = {'Fire'},
        Impaction = {level = 2, skillchain = 'Fusion'},
        Scission  = {level = 1, skillchain = 'Scission'},
    },
    Induration = {level = 1, burst = {'Ice'},
        Reverberation = {level = 2, skillchain = 'Fragmentation'},
        Compression   = {level = 1, skillchain = 'Compression'},
        Impaction     = {level = 1, skillchain = 'Impaction'},
    },
    Reverberation = {level = 1, burst = {'Water'},
        Induration = {level = 1, skillchain = 'Induration'},
        Impaction  = {level = 1, skillchain = 'Impaction'},
    },
    Transfixion = {level = 1, burst = {'Light'},
        Scission      = {level = 2, skillchain = 'Distortion'},
        Reverberation = {level = 1, skillchain = 'Reverberation'},
        Compression   = {level = 1, skillchain = 'Compression'},
    },
    Scission = {level = 1, burst = {'Earth'},
        Liquefaction  = {level = 1, skillchain = 'Liquefaction'},
        Reverberation = {level = 1, skillchain = 'Reverberation'},
        Detonation    = {level = 1, skillchain = 'Detonation'},
    },
    Detonation = {level = 1, burst = {'Wind'},
        Compression = {level = 2, skillchain = 'Gravitation'},
        Scission    = {level = 1, skillchain = 'Scission'},
    },
    Impaction = {level = 1, burst = {'Lightning'},
        Liquefaction = {level = 1, skillchain = 'Liquefaction'},
        Detonation   = {level = 1, skillchain = 'Detonation'},
    },
};

-- Property/skillchain-name -> RGBA display color (ported from chains/chains.lua's `colors`).
M.colors = {
    Light =         { 1.0, 1.0, 1.0, 1.0 },
    Dark =          { 0.0, 0.0, 0.8, 1.0 },
    Ice =           { 0.0, 1.0, 1.0, 1.0 },
    Water =         { 0.0, 1.0, 1.0, 1.0 },
    Earth =         { 0.6, 0.5, 0.0, 1.0 },
    Wind =          { 0.4, 1.0, 0.4, 1.0 },
    Fire =          { 1.0, 0.0, 0.0, 1.0 },
    Lightning =     { 1.0, 0.0, 1.0, 1.0 },
    Gravitation =   { 0.4, 0.2, 0.0, 1.0 },
    Fragmentation = { 1.0, 0.6, 1.0, 1.0 },
    Fusion =        { 1.0, 0.4, 0.4, 1.0 },
    Distortion =    { 0.2, 0.6, 1.0, 1.0 },
};
M.colors.Darkness =      M.colors.Dark;
M.colors.Umbra =         M.colors.Dark;
M.colors.Compression =   M.colors.Dark;
M.colors.Radiance =      M.colors.Light;
M.colors.Transfixion =   M.colors.Light;
M.colors.Induration =    M.colors.Ice;
M.colors.Reverberation = M.colors.Water;
M.colors.Scission =      M.colors.Earth;
M.colors.Detonation =    M.colors.Wind;
M.colors.Liquefaction =  M.colors.Fire;
M.colors.Impaction =     M.colors.Lightning;

-- Resonation enum + the two chain-capable-spell tables below are ported from
-- thotbar/state/skillchain.lua, translated from enum ints to the property name
-- strings used throughout this file (same canonical property set either way).
local Resonation = {
    Liquefaction = 1, Induration = 2, Detonation = 3, Scission = 4, Impaction = 5,
    Reverberation = 6, Transfixion = 7, Compression = 8, Fusion = 9, Gravitation = 10,
    Distortion = 11, Fragmentation = 12, Light = 13, Darkness = 14,
};
local RESONATION_NAMES = {
    [1] = 'Liquefaction', [2] = 'Induration', [3] = 'Detonation', [4] = 'Scission',
    [5] = 'Impaction', [6] = 'Reverberation', [7] = 'Transfixion', [8] = 'Compression',
    [9] = 'Fusion', [10] = 'Gravitation', [11] = 'Distortion', [12] = 'Fragmentation',
    [13] = 'Light', [14] = 'Darkness',
};
local function resonation_to_names(list)
    local out = {};
    for i = 1, #list do
        out[i] = RESONATION_NAMES[list[i]];
    end
    return out;
end

-- Ability id (the BLU spell's job-ability-style packet id) -> Resonation list. Only
-- carries these properties while the caster has Azure Lore (163) or Chain Affinity
-- (164) active -- see M.blu_required_buffs / actor_has_buff in ui/combat_toasts.lua.
local CHAIN_AFFINITY_RAW = {
    [519] = {Resonation.Transfixion, Resonation.Scission}, --Screwdriver
    [527] = {Resonation.Detonation}, --Smite of Rage
    [529] = {Resonation.Liquefaction}, --Bludgeon
    [539] = {Resonation.Compression, Resonation.Reverberation}, --Terror Touch
    [540] = {Resonation.Scission, Resonation.Detonation}, --Spinal Cleave
    [543] = {Resonation.Induration}, --Mandibular Bite
    [545] = {Resonation.Compression}, --Sickle Slash
    [551] = {Resonation.Reverberation}, --Power Attack
    [554] = {Resonation.Compression, Resonation.Reverberation}, --Death Scissors
    [560] = {Resonation.Induration}, --Frenetic Rip
    [564] = {Resonation.Impaction}, --Body Slam
    [567] = {Resonation.Transfixion}, --Helldive
    [569] = {Resonation.Impaction}, --Jet Stream
    [577] = {Resonation.Detonation}, --Foot Kick
    [585] = {Resonation.Fragmentation}, --Ram Charge
    [587] = {Resonation.Scission}, --Claw Cyclone
    [589] = {Resonation.Transfixion, Resonation.Impaction}, --Dimensional Death
    [594] = {Resonation.Liquefaction, Resonation.Impaction}, --Uppercut
    [596] = {Resonation.Liquefaction}, --Pinecone Bomb
    [597] = {Resonation.Reverberation}, --Sprout Smack
    [599] = {Resonation.Compression}, --Queasyshroom
    [603] = {Resonation.Transfixion}, --Wild Oats
    [611] = {Resonation.Distortion}, --Disseverment
    [617] = {Resonation.Gravitation}, --Vertical Cleave
    [620] = {Resonation.Impaction}, --Battle Dance
    [622] = {Resonation.Induration}, --Grand Slam
    [623] = {Resonation.Impaction}, --Head Butt
    [628] = {Resonation.Impaction}, --Frypan
    [631] = {Resonation.Reverberation}, --Hydro Shot
    [638] = {Resonation.Transfixion}, --Feather Storm
    [640] = {Resonation.Reverberation}, --Tail Slap
    [641] = {Resonation.Detonation}, --Hysteric Barrage
    [643] = {Resonation.Fusion}, --Cannonball
    [650] = {Resonation.Induration, Resonation.Detonation}, --Seedspray
    [652] = {Resonation.Transfixion}, --Spiral Spin
    [653] = {Resonation.Liquefaction, Resonation.Impaction}, --Asuran Claws
    [654] = {Resonation.Fragmentation}, --Sub-zero Smash
    [665] = {Resonation.Fusion}, --Final Sting
    [666] = {Resonation.Fusion, Resonation.Impaction}, --Goblin Rush
    [667] = {Resonation.Transfixion, Resonation.Scission}, --Vanity Dive
    [669] = {Resonation.Scission, Resonation.Detonation}, --Whirl of Rage
    [670] = {Resonation.Gravitation, Resonation.Transfixion}, --Benthic Typhoon
    [673] = {Resonation.Distortion, Resonation.Scission}, --Quad. Continuum
    [677] = {Resonation.Compression, Resonation.Scission}, --Empty Thrash
    [682] = {Resonation.Liquefaction, Resonation.Detonation}, --Delta Thrust
    [688] = {Resonation.Fragmentation, Resonation.Transfixion}, --Heavy Strike
    [692] = {Resonation.Detonation}, --Sudden Lunge
    [693] = {Resonation.Liquefaction, Resonation.Scission, Resonation.Impaction}, --Quadrastrike
    [697] = {Resonation.Gravitation}, --Amorphic Spikes
    [699] = {Resonation.Distortion, Resonation.Scission}, --Barbed Crescent
    [704] = {Resonation.Gravitation}, --Paralyzing Triad
    [706] = {Resonation.Fragmentation}, --Glutinous Dart
    [709] = {Resonation.Fusion}, --Thrashing Assault
    [714] = {Resonation.Gravitation, Resonation.Reverberation}, --Sinker Drill
    [723] = {Resonation.Fragmentation, Resonation.Distortion}, --Saurian Slide
    [740] = {Resonation.Light, Resonation.Fragmentation}, --Tourbillion
    [742] = {Resonation.Darkness, Resonation.Gravitation}, --Bilgestorm
    [743] = {Resonation.Darkness, Resonation.Distortion}, --Bloodrake
    [885] = {Resonation.Scission}, --Geohelix II
    [886] = {Resonation.Reverberation}, --Hydrohelix II
    [887] = {Resonation.Detonation}, --Anemohelix II
    [888] = {Resonation.Liquefaction}, --Pyrohelix II
    [889] = {Resonation.Induration}, --Cryohelix II
    [890] = {Resonation.Impaction}, --Ionohelix II
    [891] = {Resonation.Compression}, --Noctohelix II
    [892] = {Resonation.Transfixion}, --Luminohelix II
};

-- Spell id (elemental nuke) -> Resonation list. Only carries these properties while
-- the caster has Immanence (170) active.
local IMMANENCE_RAW = {
    [144] = {Resonation.Liquefaction}, --Fire
    [145] = {Resonation.Liquefaction}, --Fire II
    [146] = {Resonation.Liquefaction}, --Fire III
    [147] = {Resonation.Liquefaction}, --Fire IV
    [148] = {Resonation.Liquefaction}, --Fire V
    [149] = {Resonation.Induration}, --Blizzard
    [150] = {Resonation.Induration}, --Blizzard II
    [151] = {Resonation.Induration}, --Blizzard III
    [152] = {Resonation.Induration}, --Blizzard IV
    [153] = {Resonation.Induration}, --Blizzard V
    [154] = {Resonation.Detonation}, --Aero
    [155] = {Resonation.Detonation}, --Aero II
    [156] = {Resonation.Detonation}, --Aero III
    [157] = {Resonation.Detonation}, --Aero IV
    [158] = {Resonation.Detonation}, --Aero V
    [159] = {Resonation.Scission}, --Stone
    [160] = {Resonation.Scission}, --Stone II
    [161] = {Resonation.Scission}, --Stone III
    [162] = {Resonation.Scission}, --Stone IV
    [163] = {Resonation.Scission}, --Stone V
    [164] = {Resonation.Impaction}, --Thunder
    [165] = {Resonation.Impaction}, --Thunder II
    [166] = {Resonation.Impaction}, --Thunder III
    [167] = {Resonation.Impaction}, --Thunder IV
    [168] = {Resonation.Impaction}, --Thunder V
    [169] = {Resonation.Reverberation}, --Water
    [170] = {Resonation.Reverberation}, --Water II
    [171] = {Resonation.Reverberation}, --Water III
    [172] = {Resonation.Reverberation}, --Water IV
    [173] = {Resonation.Reverberation}, --Water V
    [278] = {Resonation.Scission}, --Geohelix
    [279] = {Resonation.Reverberation}, --Hydrohelix
    [280] = {Resonation.Detonation}, --Anemohelix
    [281] = {Resonation.Liquefaction}, --Pyrohelix
    [282] = {Resonation.Induration}, --Cryohelix
    [283] = {Resonation.Impaction}, --Ionohelix
    [284] = {Resonation.Compression}, --Noctohelix
    [285] = {Resonation.Transfixion}, --Luminohelix
    [503] = {Resonation.Compression}, --Impact
};

-- ability/spell id -> { propertyName, ... }, name-string form (see resonation_to_names).
M.blu_spells = {};
for id, list in pairs(CHAIN_AFFINITY_RAW) do
    M.blu_spells[id] = resonation_to_names(list);
end
M.sch_spells = {};
for id, list in pairs(IMMANENCE_RAW) do
    M.sch_spells[id] = resonation_to_names(list);
end

-- Buff ids gating the two tables above (per thotbar's GetSpellResonation).
M.AZURE_LORE_BUFF_ID = 163;
M.CHAIN_AFFINITY_BUFF_ID = 164;
M.IMMANENCE_BUFF_ID = 170;

-- Player-pet TP moves that carry skillchain properties: BST charmed-pet Ready moves +
-- SMN avatar Blood Pact: Rage + PUP automaton attacks. The BST/SMN block is ported from
-- chains/skills.lua's `skills.playerPet`; cross-checked against ffxiclopedia's Ready /
-- Blood Pact "SC Attributes" (eg. Wing Slap=Gravitation+Liquefaction, Tegmina Buffet=
-- Distortion+Detonation, Pentapeck=Light+Distortion, Somnolence=Compression). The PUP
-- automaton block (1940-class ids) is ported from chains/skills.lua's skills[11] -- see
-- the note above that block re: the two id schemes. No buff gating needed -- these always
-- carry their properties when they land, unlike the BLU/SCH tables above.
M.pet_skills = {
    [513] = {en='Poison Nails',skillchain={'Transfixion'}},
    [521] = {en='Regal Scratch',skillchain={'Scission'}},
    [528] = {en='Moonlit Charge',skillchain={'Compression'}},
    [529] = {en='Crescent Fang',skillchain={'Transfixion'}},
    [534] = {en='Eclipse Bite',skillchain={'Gravitation','Scission'}},
    [544] = {en='Punch',skillchain={'Liquefaction'}},
    [546] = {en='Burning Strike',skillchain={'Impaction'}},
    [547] = {en='Double Punch',skillchain={'Compression'}},
    [550] = {en='Flaming Crush',skillchain={'Fusion','Reverberation'}},
    [560] = {en='Rock Throw',skillchain={'Scission'}},
    [562] = {en='Rock Buster',skillchain={'Reverberation'}},
    [563] = {en='Megalith Throw',skillchain={'Induration'}},
    [566] = {en='Mountain Buster',skillchain={'Gravitation','Induration'}},
    [570] = {en='Crag Throw',skillchain={'Gravitation','Scission'}},
    [576] = {en='Barracuda Dive',skillchain={'Reverberation'}},
    [578] = {en='Tail Whip',skillchain={'Detonation'}},
    [582] = {en='Spinning Dive',skillchain={'Distortion','Detonation'}},
    [592] = {en='Claw',skillchain={'Detonation'}},
    [598] = {en='Predator Claws',skillchain={'Fragmentation','Scission'}},
    [608] = {en='Axe Kick',skillchain={'Induration'}},
    [612] = {en='Double Slap',skillchain={'Scission'}},
    [614] = {en='Rush',skillchain={'Distortion','Scission'}},
    [624] = {en='Shock Strike',skillchain={'Impaction'}},
    [630] = {en='Chaotic Strike',skillchain={'Fragmentation','Transfixion'}},
    [634] = {en='Volt Strike',skillchain={'Fragmentation','Scission'}},
    [656] = {en='Camisado',skillchain={'Compression'}},
    [657] = {en='Somnolence',skillchain={'Compression'}},
    [667] = {en='Blindside',skillchain={'Gravitation','Transfixion'}},
    [672] = {en='Foot Kick',skillchain={'Reverberation'}},
    [674] = {en='Whirl Claws',skillchain={'Impaction'}},
    [675] = {en='Head Butt',skillchain={'Detonation'}},
    [677] = {en='Wild Oats',skillchain={'Transfixion'}},
    [678] = {en='Leaf Dagger',skillchain={'Scission'}},
    [681] = {en='Razor Fang',skillchain={'Impaction'}},
    [682] = {en='Claw Cyclone',skillchain={'Scission'}},
    [683] = {en='Tail Blow',skillchain={'Impaction'}},
    [685] = {en='Blockhead',skillchain={'Reverberation'}},
    [686] = {en='Brain Crush',skillchain={'Liquefaction'}},
    [689] = {en='Lamb Chop',skillchain={'Impaction'}},
    [691] = {en='Sheep Charge',skillchain={'Reverberation'}},
    [695] = {en='Big Scissors',skillchain={'Scission'}},
    [698] = {en='Needleshot',skillchain={'Transfixion'}},
    [699] = {en='??? Needles',skillchain={'Darkness','Fragmentation'}},
    [700] = {en='Frogkick',skillchain={'Compression'}},
    [707] = {en='Power Attack',skillchain={'Reverberation'}},
    [709] = {en='Rhino Attack',skillchain={'Detonation'}},
    [717] = {en='Mandibular Bite',skillchain={'Detonation'}},
    [723] = {en='Nimble Snap',skillchain={'Impaction'}},
    [724] = {en='Cyclotail',skillchain={'Impaction'}},
    [726] = {en='Double Claw',skillchain={'Liquefaction'}},
    [727] = {en='Grapple',skillchain={'Reverberation'}},
    [728] = {en='Spinning Top',skillchain={'Impaction'}},
    [732] = {en='Suction',skillchain={'Compression'}},
    [736] = {en='Sudden Lunge',skillchain={'Impaction'}},
    [737] = {en='Spiral Spin',skillchain={'Scission'}},
    [743] = {en='Scythe Tail',skillchain={'Liquefaction'}},
    [744] = {en='Ripper Fang',skillchain={'Induration'}},
    [745] = {en='Chomp Rush',skillchain={'Darkness','Gravitation'}},
    [749] = {en='Back Heel',skillchain={'Reverberation'}},
    [753] = {en='Tortoise Stomp',skillchain={'Liquefaction'}},
    [756] = {en='Wing Slap',skillchain={'Gravitation','Liquefaction'}},
    [757] = {en='Beak Lunge',skillchain={'Scission'}},
    [759] = {en='Recoil Dive',skillchain={'Transfixion'}},
    [761] = {en='Sensilla Blades',skillchain={'Scission'}},
    [762] = {en='Tegmina Buffet',skillchain={'Distortion','Detonation'}},
    [764] = {en='Swooping Frenzy',skillchain={'Fusion','Reverberation'}},
    [765] = {en='Sweeping Gouge',skillchain={'Induration'}},
    [767] = {en='Pentapeck',skillchain={'Light','Distortion'}},
    [768] = {en='Tickling Tendrils',skillchain={'Impaction'}},
    [772] = {en='Somersault',skillchain={'Compression'}},
    [776] = {en='Pecking Flurry',skillchain={'Transfixion'}},
    [777] = {en='Sickle Slash',skillchain={'Transfixion'}},
    [780] = {en='Regal Gash',skillchain={'Distortion','Detonation'}},
    [961] = {en='Welt',skillchain={'Scission'}},
    [964] = {en='Roundhouse',skillchain={'Detonation'}},
    [970] = {en='Hysteric Assault',skillchain={'Fragmentation','Transfixion'}},

    -- PUP automaton TP moves. Ported from chains/skills.lua's skills[11] (NPC TP skills)
    -- automaton block, cross-checked against the bg-wiki Automaton page. NOTE these use a
    -- DIFFERENT id scheme than the BST/SMN entries above: the BST/SMN ids are the retail
    -- pet-ability ids (513-class), while automaton moves come through as category-11 NPC
    -- TP moves keyed by the higher mob-skill ids (1940-class). Both schemes coexist here
    -- because emit_0x28 looks pet moves up in this one table regardless of which path
    -- (pet-message 110/317 vs category 11) the packet arrived on.
    [1940] = {en='Chimera Ripper',skillchain={'Induration','Detonation'}},
    [1941] = {en='String Clipper',skillchain={'Scission','Impaction'}},
    [1942] = {en='Arcuballista',skillchain={'Liquefaction','Transfixion'}},
    [1943] = {en='Slapstick',skillchain={'Reverberation','Impaction'}},
    [2065] = {en='Cannibal Blade',skillchain={'Compression','Reverberation'}},
    [2066] = {en='Daze',skillchain={'Transfixion'}},
    [2067] = {en='Knockout',skillchain={'Scission','Detonation'}},
    [2299] = {en='Bone Crusher',skillchain={'Fragmentation'}},
    [2300] = {en='Armor Piercer',skillchain={'Gravitation'}},
    [2301] = {en='Magic Mortar',skillchain={'Fusion'}},
};

--- Looks up the player's equipped-weapon-eligible weapon skills (skill must be
--- usable with the current weapon per the client, via HasWeaponSkill).
function M.get_available_weaponskills()
    local result = {};
    local player = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetPlayer() or nil;
    if (player == nil or player.HasWeaponSkill == nil) then
        return result;
    end
    for id, entry in pairs(M.weapon_skills) do
        local ok, has = pcall(function() return player:HasWeaponSkill(id); end);
        if (ok and has) then
            result[#result + 1] = { id = id, en = entry.en, skillchain = entry.skillchain };
        end
    end
    return result;
end

--- True if the local player currently has any of buffIds active. Reads the player's own
--- buff list directly (GetPlayer():GetBuffs()); 255 is the empty-slot terminator.
local function player_has_buff(buffIds)
    local player = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetPlayer() or nil;
    if (player == nil or player.GetBuffs == nil) then
        return false;
    end
    local ok, buffs = pcall(function() return player:GetBuffs(); end);
    if (not ok or buffs == nil) then
        return false;
    end
    for i = 1, #buffs do
        local b = buffs[i];
        if (b == 255) then
            break;
        end
        for j = 1, #buffIds do
            if (b == buffIds[j]) then
                return true;
            end
        end
    end
    return false;
end

--- True if the spell (by id) is off recast right now. Timer of 0 means ready
--- (GetRecast():GetSpellTimer, same source thotbar's updaters/spell.lua uses). If the
--- recast table is unreadable we assume ready rather than hide a usable spell.
local function spell_recast_ready(spellId)
    local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
    if (mm == nil) then
        return false;
    end
    local recast = mm:GetRecast();
    if (recast == nil or recast.GetSpellTimer == nil) then
        return true;
    end
    local okT, timer = pcall(function() return recast:GetSpellTimer(spellId); end);
    return (not okT) or (tonumber(timer) or 0) == 0;
end

--- True if the spell (by id) is castable right now: known AND off recast.
local function spell_castable(spellId)
    local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
    if (mm == nil) then
        return false;
    end
    local player = mm:GetPlayer();
    if (player == nil or player.HasSpell == nil) then
        return false;
    end
    local okHas, has = pcall(function() return player:HasSpell(spellId); end);
    if (not okHas or not has) then
        return false;
    end
    return spell_recast_ready(spellId);
end

-- BLU "set spells" detection, ported from thotbar (state/player.lua UpdateBLUSpells):
-- player:HasSpell only tells you a BLU spell is LEARNED, not that it's currently set in
-- one of your blue magic slots. The set list lives in FFXiMain.dll memory; we read the
-- 20 slot bytes and map each (slotValue + 512) to a spell id. Offset is resolved once via
-- a code-signature scan. blu_set_spell_ids() returns a { [spellId]=true } set, or nil if
-- memory is unreadable (caller then falls back to the learned check).
local bluOffsetAddr = nil;
local bluOffsetResolved = false;
local function get_blu_offset()
    if (bluOffsetResolved) then
        return bluOffsetAddr;
    end
    bluOffsetResolved = true;
    if (ashita == nil or ashita.memory == nil) then
        return nil;
    end
    local ok, addr = pcall(function()
        return ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0));
    end);
    if (ok and addr ~= nil and addr ~= 0) then
        bluOffsetAddr = addr;
    end
    return bluOffsetAddr;
end

local function blu_set_spell_ids(mainJob)
    local bluOffset = get_blu_offset();
    if (bluOffset == nil) then
        return nil;
    end
    local rm = AshitaCore and AshitaCore:GetResourceManager() or nil;
    if (rm == nil) then
        return nil;
    end
    local out = {};
    local ok = pcall(function()
        local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if (ptr == nil or ptr == 0) then
            return;
        end
        ptr = ashita.memory.read_uint32(ptr);
        if (ptr == nil or ptr == 0) then
            return;
        end
        -- BLU set list sits at +0x04 when BLU is main job, +0xA0 when it's the sub job.
        local base = (ptr + bluOffset) + ((mainJob == 16) and 0x04 or 0xA0);
        local slots = ashita.memory.read_array(base, 0x14);
        for _, entry in pairs(slots) do
            local spell = rm:GetSpellById((tonumber(entry) or 0) + 512);
            if (spell ~= nil) then
                out[spell.Index] = true;
            end
        end
    end);
    if (not ok) then
        return nil;
    end
    return out;
end

--- Chain-capable spells the player knows + can cast (off recast) that could continue a
--- chain. These spells only carry skillchain properties while a gating buff is up (SCH:
--- Immanence; BLU: Azure Lore / Chain Affinity), but we list them for PLANNING even when
--- the buff isn't active -- you can pop the buff then cast -- and mark requiresBuff=true so
--- the panel can flag it. Eligibility instead of buff:
---   * SCH (sch_spells): only if you can actually use Immanence, i.e. main job SCH (20) at
---     level >= 75 (Immanence's level). Below that, omit entirely.
---   * BLU (blu_spells): only if BLU (16) is your main or sub job (Chain Affinity available).
--- requiresBuff is set per entry based on whether the relevant buff is currently up.
--- Each entry: { id, en, skillchain, requiresBuff }.
local SCH_JOB_ID = 20;
local BLU_JOB_ID = 16;
local IMMANENCE_LEVEL = 75;
function M.get_available_chain_spells()
    local result = {};
    local mm = AshitaCore and AshitaCore:GetMemoryManager() or nil;
    if (mm == nil) then
        return result;
    end
    local player = mm:GetPlayer();
    if (player == nil or player.HasSpell == nil) then
        return result;
    end
    local rm = AshitaCore:GetResourceManager();
    local function spell_name(id)
        if (rm == nil) then return ('#%d'):fmt(id); end
        local ok, sp = pcall(function() return rm:GetSpellById(id); end);
        if (ok and sp ~= nil and sp.Name ~= nil and sp.Name[1] ~= nil and sp.Name[1] ~= '') then
            return sp.Name[1];
        end
        return ('#%d'):fmt(id);
    end

    local mainJob = tonumber(player:GetMainJob()) or 0;
    local mainLvl = tonumber(player:GetMainJobLevel()) or 0;
    local subJob = tonumber(player:GetSubJob()) or 0;

    -- SCH: needs main-job SCH at Immanence level. (Sub can't reach 75, so main only.)
    if (mainJob == SCH_JOB_ID and mainLvl >= IMMANENCE_LEVEL) then
        local immanenceUp = player_has_buff({ M.IMMANENCE_BUFF_ID });
        for id, props in pairs(M.sch_spells) do
            if (spell_castable(id)) then
                result[#result + 1] = { id = id, en = spell_name(id), skillchain = props, requiresBuff = (not immanenceUp) };
            end
        end
    end

    -- BLU: needs BLU as main or sub (Chain Affinity / Azure Lore available). Only SET blue
    -- magic counts -- a learned-but-not-set spell can't be cast -- so gate on the memory-read
    -- set list (thotbar parity). If that read fails (setIds == nil), fall back to the learned
    -- HasSpell check so the feature degrades instead of going blank.
    if (mainJob == BLU_JOB_ID or subJob == BLU_JOB_ID) then
        local bluUp = player_has_buff({ M.AZURE_LORE_BUFF_ID, M.CHAIN_AFFINITY_BUFF_ID });
        local setIds = blu_set_spell_ids(mainJob);
        for id, props in pairs(M.blu_spells) do
            local usable;
            if (setIds ~= nil) then
                usable = (setIds[id] == true) and spell_recast_ready(id);
            else
                usable = spell_castable(id);
            end
            if (usable) then
                result[#result + 1] = { id = id, en = spell_name(id), skillchain = props, requiresBuff = (not bluUp) };
            end
        end
    end
    return result;
end

-- Only these MAIN jobs field a pet that can skillchain. A DRG's wyvern, a BLU/PLD
-- familiar, etc. cannot chain at all -- they must never contribute pet options.
local PET_SC_MAIN_JOBS = {
    [9]  = true, -- BST (charmed / jug pet Ready moves)
    [15] = true, -- SMN (Blood Pact: Rage)
    [18] = true, -- PUP (automaton TP moves)
};

-- SMN avatars have a FIXED Blood Pact: Rage moveset, and the pet entity's Name is the
-- avatar name -- so for SMN we can resolve the exact moveset from the pet's identity
-- (same entity the party list reads). Keyed by avatar Name -> pet_skills ids (513-scheme).
-- BST jug/charmed pets and PUP automatons have name/attachment-dependent movesets we
-- can't map statically; those fall back to learned-by-observation (note_pet_ability_used).
local SMN_AVATAR_MOVES = {
    ['Carbuncle'] = { 513 },                         -- Poison Nails
    ['Cait Sith'] = { 521, 780 },                    -- Regal Scratch, Regal Gash
    ['Fenrir']    = { 528, 529, 534 },               -- Moonlit Charge, Crescent Fang, Eclipse Bite
    ['Ifrit']     = { 544, 546, 547, 550 },          -- Punch, Burning Strike, Double Punch, Flaming Crush
    ['Titan']     = { 560, 562, 563, 566, 570 },     -- Rock Throw, Rock Buster, Megalith Throw, Mountain Buster, Crag Throw
    ['Leviathan'] = { 576, 578, 582 },               -- Barracuda Dive, Tail Whip, Spinning Dive
    ['Garuda']    = { 592, 598 },                    -- Claw, Predator Claws
    ['Shiva']     = { 608, 612, 614 },               -- Axe Kick, Double Slap, Rush
    ['Ramuh']     = { 624, 630, 634 },               -- Shock Strike, Chaotic Strike, Volt Strike
    ['Diabolos']  = { 656, 667 },                    -- Camisado, Blindside
};

-- BST jug pets are a FIXED, finite roster with proper names. A charmed wild mob has the
-- mob's own name, which is NOT in this set, so we ignore it (per design: only jug pets
-- contribute options). We whitelist the NAME here and source the actual moves from
-- observation (note_pet_ability_used) -- a jug pet's moveset is family-specific and not
-- worth hardcoding (and risks the over-listing we're trying to kill). Keys are normalized
-- (lowercase, spaces/punctuation stripped) so "Sharp-Eared Ophira" etc. match regardless
-- of exact spacing. Extend this list if a jug pet shows no options (dump pet.Name first).
local function normalize_pet_name(name)
    if (name == nil) then return nil; end
    return tostring(name):lower():gsub("[%s%-'%.]", "");
end

local BST_JUG_PET_NAMES = {};
do
    local names = {
        -- Broth "Familiar" pets.
        'Hare Familiar', 'Sheep Familiar', 'Tiger Familiar', 'Flowerpot Familiar',
        'Flytrap Familiar', 'Crab Familiar', 'Lizard Familiar', 'Mayfly Familiar',
        'Eft Familiar', 'Beetle Familiar', 'Antlion Familiar', 'Mosquito Familiar',
        'Bird Familiar', 'Coeurl Familiar', 'Caterpillar Familiar', 'Funguar Familiar',
        -- Named vendor / quest jug pets (Pet Food roster).
        'CourierCarrie', 'Discreet Louise', 'Fatso Fargann', 'Generous Arthur',
        'Lucky Lulush', 'Brave Horus', 'Crude Raphie', 'Daring Roland',
        'Faithful Falcorr', 'Headbreaker Ken', 'Sultry Patrice', 'Swift Sieghard',
        'Warlike Patrick', 'Amiable Roche', 'Anklebiter Jedd', 'Audacious Anna',
        'Bouncing Bertha', 'Brainy Waluis', 'Cursed Annabelle', 'Dapper Mac',
        'Ferocious Festo', 'Gooey Gerard', 'Hurler Percival', 'Left-Handed Yoko',
        'Mailbuster Cetas', 'Nursery Nazuna', 'Pondering Peter', 'Rhyming Shizuna',
        'Scissorleg Xerin', 'Sharp-Eared Ophira', 'Shellbuster Orthros',
        'Submersible Gregale', 'Suspicious Alice', 'Swooping Zhivago',
        'Threestar Lynn', 'Vivacious Vickie', 'Chopsuey Chamberlain',
        'Panzer Galahad', 'Lullaby Melodia', 'Colibri Familiar', 'Spider Familiar',
        'Tulfaire Familiar',
    };
    for _, n in ipairs(names) do
        BST_JUG_PET_NAMES[normalize_pet_name(n)] = true;
    end
end

-- We cannot read a pet's actual moveset from the client, so we LEARN it: every time
-- our own chaining pet uses a charted TP move (combat_toasts -> note_pet_ability_used),
-- we remember that move id for the current pet instance. Only learned moves are offered
-- as chain options -- so the list reflects THIS pet, not every pet in the game. The set
-- is keyed to the pet's ServerId and reset when a different pet comes out.
M._pet_observed = {};         -- [abilityId] = true (moves seen from the current pet)
M._pet_observed_owner = nil;  -- ServerId the observed set belongs to

--- Identity of the local player's current pet -- detected exactly like the party list:
--- GetEntity(PlayerEntity.PetTargetIndex). Returns (ServerId, Name) or nil if no pet out.
local function current_pet_identity()
    local player_ent = (GetPlayerEntity ~= nil) and GetPlayerEntity() or nil;
    local petIdx = player_ent and tonumber(player_ent.PetTargetIndex) or 0;
    if (petIdx == nil or petIdx <= 0 or GetEntity == nil) then
        return nil;
    end
    local pet_ent = GetEntity(petIdx);
    if (pet_ent == nil) then
        return nil;
    end
    local name = pet_ent.Name and tostring(pet_ent.Name):gsub('%z.*', '') or nil;
    return tonumber(pet_ent.ServerId), name;
end

--- The local player's MAIN job id if it's a skillchaining pet job, else nil.
local function local_pet_sc_job()
    local player = AshitaCore and AshitaCore:GetMemoryManager()
        and AshitaCore:GetMemoryManager():GetPlayer() or nil;
    if (player == nil or player.GetMainJob == nil) then
        return nil;
    end
    local ok, job = pcall(function() return player:GetMainJob(); end);
    job = tonumber(job) or 0;
    return PET_SC_MAIN_JOBS[job] and job or nil;
end

--- Record that the current pet just used pet TP move `id`. Resets the learned set when
--- a new pet (different ServerId) comes out so one pet's moves never leak onto another.
function M.note_pet_ability_used(id)
    id = tonumber(id);
    if (id == nil or M.pet_skills[id] == nil) then
        return;
    end
    local sid = current_pet_identity();
    if (sid == nil) then
        return;
    end
    if (M._pet_observed_owner ~= sid) then
        M._pet_observed = {};
        M._pet_observed_owner = sid;
    end
    M._pet_observed[id] = true;
end

--- Pet TP moves available to continue a chain, narrowed to THIS pet by job:
---  * SMN -- the avatar's Name resolves its fixed Blood Pact: Rage moveset immediately,
---    augmented by anything observed (in case a server tweaked an avatar).
---  * BST -- only if the pet's Name is a known jug pet (charmed wild mobs are ignored);
---    moves come from observation (jug movesets are family-specific, not worth hardcoding).
---  * PUP -- automaton moveset depends on attachments, so it's observation-only.
--- A pet must be out and the main job must be a chaining pet job. Each: { id, en, skillchain }.
function M.get_available_pet_abilities()
    local result = {};
    local job = local_pet_sc_job();
    if (job == nil) then
        return result; -- e.g. DRG wyvern -- pet cannot skillchain
    end
    local sid, name = current_pet_identity();
    if (sid == nil) then
        return result; -- no pet out
    end
    if (M._pet_observed_owner ~= sid) then
        -- Different pet than the one we have observations for: stale, start fresh.
        M._pet_observed = {};
        M._pet_observed_owner = sid;
    end

    local ids = {};
    if (job == 15) then
        -- SMN: avatar Name -> fixed moveset, plus observed augment.
        local avatarMoves = name and SMN_AVATAR_MOVES[name] or nil;
        if (avatarMoves ~= nil) then
            for _, id in ipairs(avatarMoves) do
                ids[id] = true;
            end
        end
        for id in pairs(M._pet_observed) do
            ids[id] = true;
        end
    elseif (job == 9) then
        -- BST: only recognized jug pets contribute; charmed mobs are ignored.
        if (BST_JUG_PET_NAMES[normalize_pet_name(name)] == true) then
            for id in pairs(M._pet_observed) do
                ids[id] = true;
            end
        end
    else
        -- PUP automaton: observation-only.
        for id in pairs(M._pet_observed) do
            ids[id] = true;
        end
    end

    for id in pairs(ids) do
        local entry = M.pet_skills[id];
        if (entry ~= nil) then
            result[#result + 1] = { id = id, en = entry.en, skillchain = entry.skillchain };
        end
    end
    return result;
end

--- Given the chain's current open properties (a list, eg. {'Light','Fusion'}) and a
--- candidate's properties, returns the resulting {level, skillchain} or nil if the
--- pairing doesn't form a valid skillchain. Mirrors chains.lua's GetSkillchains inner loop.
function M.resolve_chain(sourceProperties, candidateProperties)
    if (sourceProperties == nil or candidateProperties == nil) then
        return nil;
    end
    for _, prop1 in ipairs(sourceProperties) do
        local rule = M.chain_info[prop1];
        if (rule ~= nil) then
            for _, prop2 in ipairs(candidateProperties) do
                local match = rule[prop2];
                if (match ~= nil) then
                    return { level = match.level, skillchain = match.skillchain };
                end
            end
        end
    end
    return nil;
end

--- For the given source properties (the most recent chain-opening action's skillchain
--- properties), returns every action the player can use RIGHT NOW that would continue/close
--- a chain from there: equipped weapon skills, plus chain-capable spells (if the gating buff
--- is up) and pet TP moves (if a pet is out). Sorted highest skillchain level first.
--- Each entry: { id, en, level, skillchain, kind = 'ws'|'spell'|'pet' }.
function M.get_chain_options(sourceProperties)
    local options = {};
    if (sourceProperties == nil) then
        return options;
    end
    local function add_from(candidates, kind)
        for _, c in ipairs(candidates) do
            local match = M.resolve_chain(sourceProperties, c.skillchain);
            if (match ~= nil) then
                options[#options + 1] = { id = c.id, en = c.en, level = match.level, skillchain = match.skillchain, kind = kind, requiresBuff = c.requiresBuff };
            end
        end
    end
    add_from(M.get_available_weaponskills(), 'ws');
    add_from(M.get_available_chain_spells(), 'spell');
    add_from(M.get_available_pet_abilities(), 'pet');
    -- Highest skillchain level first; stable tiebreak by name so the list doesn't jitter.
    table.sort(options, function(a, b)
        if (a.level ~= b.level) then return a.level > b.level; end
        return tostring(a.en) < tostring(b.en);
    end);
    return options;
end

return M;
