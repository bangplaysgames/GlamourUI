
local M = {};

function M.check_filter(actor, target, _category, _msg)
    if (not actor or not target) then
        return false;
    end
    if (not actor.filter or not target.filter) then
        return false;
    end
    return true;
end

return M;
