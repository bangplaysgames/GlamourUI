--[[
    Classifies a resolved spell name as a damaging elemental nuke (or not). Exact-match
    against a generated set of real tier names, not prefix matching -- a prefix check
    would false-positive on things like "Stoneskin" matching "Stone".
]]--

local M = {};

local ELEMENT_BASE_SPELLS = {
    Stone = 'Earth', Water = 'Water', Aero = 'Wind', Fire = 'Fire', Blizzard = 'Ice', Thunder = 'Lightning',
};
local TIER_SUFFIXES = { '', ' II', ' III', ' IV', ' V', ' VI' };
local AOE_SUFFIXES = { 'ga', 'ga II', 'ga III' };

local ANCIENT_MAGIC = {
    Quake = 'Earth', Flood = 'Water', Tornado = 'Wind', Flare = 'Fire', Freeze = 'Ice', Burst = 'Lightning',
};
local ANCIENT_TIERS = { '', ' II' };

local SPELL_ELEMENT = {};
for base, element in pairs(ELEMENT_BASE_SPELLS) do
    for _, suffix in ipairs(TIER_SUFFIXES) do
        SPELL_ELEMENT[base .. suffix] = element;
    end
    for _, suffix in ipairs(AOE_SUFFIXES) do
        SPELL_ELEMENT[base .. suffix] = element;
    end
end
for base, element in pairs(ANCIENT_MAGIC) do
    for _, suffix in ipairs(ANCIENT_TIERS) do
        SPELL_ELEMENT[base .. suffix] = element;
    end
end

--- Returns the element name ('Fire','Ice','Wind','Earth','Lightning','Water') if the
--- given resolved spell name is a damaging elemental nuke (incl. AOE -ga tiers and
--- Ancient Magic), or nil if it isn't (buffs, cures, enfeebles, ninjutsu, etc).
function M.element_for(spellName)
    if (spellName == nil) then
        return nil;
    end
    return SPELL_ELEMENT[tostring(spellName)];
end

return M;
