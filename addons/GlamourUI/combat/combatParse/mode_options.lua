local M = {};

function M.get_mode(chatSettings)
    local c = chatSettings or {};
    local function on(v, default)
        if (v == nil) then
            return default;
        end
        return v == true;
    end
    return {
        condensedamage = on(c.condenseDamage, true),
        condensetargets = on(c.condenseTargets, true),
        sumdamage = on(c.sumDamage, true),
        condensecrits = on(c.condenseCrits, false),
        simplify = on(c.condensedCombatLog, false),
    };
end

return M;
