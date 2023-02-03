require('common')


local rchelper = {}

local oneHour = T{
    ['WAR'] = 'Mighty Strikes',
    ['MNK'] = 'Hundred Fists',
    ['WHM'] = 'Benediction',
    ['BLM'] = 'Manafont',
    ['RDM'] = 'Chainspell',
    ['THF'] = 'Perfect Dodge',
    ['PLD'] = 'Invincible',
    ['DRK'] = 'Blood Weapon',
    ['BST'] = 'Familiar',
    ['BRD'] = 'Soul Voice',
    ['RNG'] = 'Eagle Eye Shot',
    ['SAM'] = 'Meikyo Shisui',
    ['NIN'] = 'Mijin Gakure',
    ['DRG'] = 'Spirit Surge',
    ['SMN'] = 'Astral Flow',
    ['BLU'] = 'Azure Lore',
    ['COR'] = 'Wild Card',
    ['PUP'] = 'Overdrive',
    ['DNC'] = 'Trance',
    ['SCH'] = 'Tabula Rasa',
    ['GEO'] = 'Bolster',
    ['RUN'] = 'Elemental Sforzo'
}

local function fmt_time(t)
    local time = t / 60;
    local h = math.floor(time / (60 * 60));
    local m = math.floor(time / 60 - h * 60);
    local s = math.floor(time - (m + h * 60) * 60);
    if(h > 0) then
        return ('%02i:%02i:%02i'):fmt(h, m, s);
    elseif(m > 0) then
        return ('%02i:%02i'):fmt(m, s);
    else
        return('%02i'):fmt(s);
    end
end

rchelper.Recast = {};

rchelper.renderRecast = function()
    local resMgr = AshitaCore:GetResourceManager();
    local Recast = AshitaCore:GetMemoryManager():GetRecast();
    local timers = {};
    local acts = {};
    local prog = {};


    for i = 0,31 do
        local id = Recast:GetAbilityTimerId(i);
        local timer = Recast:GetAbilityTimer(i);
        local max = AshitaCore:GetMemoryManager():GetPlayer():GetAbilityRecast(i);

        if ((id ~= 0 or i == 0) and timer > 0) then
            local act = resMgr:GetAbilityByTimerId(id);
            local name = ('Unknown Ability:  %d'):fmt(id);

            if (i == 0) then
                local job = resMgr:GetString("jobs.names_abbr", AshitaCore:GetMemoryManager():GetPlayer():GetMainJob());
                name = oneHour[job];
            elseif (id == 231) then

                local player = AshitaCore:GetMemoryManager():GetPlayer();
                local lvl = (player:GetMainJob() == 20) and player:GetMainJobLevel() or player:GetSubJobLevel();

                local val = 48;
                if(lvl < 30) then
                    val = 240;
                elseif(lvl < 50) then
                    val = 120;
                elseif(lvl < 70) then
                    val = 80;
                elseif(lvl < 90) then
                    val = 60;
                end

                local strata = 0;
                if(lvl == 99 and rchelper.sch_jp >= 550) then
                    val = 33;
                    strata = math.floor((165 - (timer / 60)) / val);
                else
                    strata = math.floor((240 - (timer / 60)) / val);
                end

                name = ('Stratagems:  [%d]'):fmt(strata);
                timer = math.fmod(timer, val * 60);
            elseif(act ~= nil) then
                name = act.Name[1];
            elseif(act == nil) then
                ability = getActName(id);
                if(act ~= nil) then
                    name = act.Name[1];
                end
            end

            table.insert(timers, fmt_time(timer));
            table.insert(acts, name);
            table.insert(prog, ((timer / 60) / max));
        end
    end

    for i = 0, 1024 do
        local id = i;
        local timer = Recast:GetSpellTimer(i);

        if(timer > 0) then
            local spell = resMgr:GetSpellById(id);
            local name = 'Unknown Spell';

            if(spell ~= nil) then
                name = spell.Name[1];
            end
            if(spell == nil or name:len() == 0) then
                name = ('Unknown Spell:  %d'):fmt(id);
            end

            table.insert(timers, fmt_time(timer));
            table.insert(acts, name);
            table.insert(prog, ((timer / 60 )/ max));
        end
    end
    
    return acts, timers, prog;
end

return rchelper;