require('common');

local M = {};

local weapon_skill = nil;
local job_ability = nil;
local mon_skill = nil;
local mon_ability = nil;

local function populate()
    if (weapon_skill ~= nil) then
        return;
    end
    local t1 = {};
    local t2 = {};
    local t3 = {};
    local t4 = {};
    local r = AshitaCore:GetResourceManager();
    if (r == nil) then
        weapon_skill = t1;
        job_ability = t2;
        mon_skill = t3;
        mon_ability = t4;
        return;
    end

    local index = 1;
    for i = 1, 4116, 1 do
        local w_skill = r:GetAbilityById(i);
        if (w_skill and i <= 0x200) then
            t1[index] = w_skill;
            index = index + 1;
        else
            break;
        end
    end
    weapon_skill = t1;

    index = 1;
    for i = 0x201, 4116, 1 do
        local j_skill = r:GetAbilityById(i);
        if (j_skill and i <= 0x600) then
            t2[index] = j_skill;
            index = index + 1;
        else
            break;
        end
    end
    job_ability = t2;

    index = 1;
    for i = 0x601, 4116, 1 do
        local m_skill = r:GetAbilityById(i);
        if (m_skill) then
            t3[index] = m_skill;
            index = index + 1;
        else
            break;
        end
    end
    mon_skill = t3;

    index = 0x101;
    for i = 1, 4116, 1 do
        local ok, j_ability_en = pcall(function()
            return r:GetString('monsters.abilities', i, 2);
        end);
        local j_ability_jp = nil;
        if (ok and j_ability_en ~= nil and j_ability_en ~= '') then
            pcall(function()
                j_ability_jp = r:GetString('monsters.abilities', i, 1);
            end);
            t4[index] = { Name = { j_ability_en, j_ability_jp or j_ability_en } };
            index = index + 1;
        else
            break;
        end
    end
    mon_ability = t4;
end

function M.ensure()
    populate();
end

function M.weapon_skill_entry(abil_ID)
    M.ensure();
    return weapon_skill[math.floor(tonumber(abil_ID) or 0)];
end

function M.job_ability_entry(abil_ID)
    M.ensure();
    return job_ability[math.floor(tonumber(abil_ID) or 0)];
end

function M.mon_skill_entry(abil_ID)
    M.ensure();
    return mon_skill[math.floor(tonumber(abil_ID) or 0)];
end

function M.mon_ability_entry(abil_ID)
    M.ensure();
    return mon_ability[math.floor(tonumber(abil_ID) or 0)];
end

return M;
