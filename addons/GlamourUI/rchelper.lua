require('common')
local chat = require('chat')
local ffi = require('ffi')

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

local jugs = T{
    'HareFamiliar',
    'SheepFamiliar',
    'FlowerpotBill',
    'TigerFamiliar',
    'FlytrapFamiliar',
    'LizardFamiliar',
    'MayflyFamiliar',
    'EftFamiliar',
    'BeetleFamiliar',
    'AntlionFamiliar',
    'CrabFamiliar',
    'MiteFamiliar',
    'KeenearedSteffi',
    'LullabyMelodia',
    'FlowerpotBen',
    'SaberSiravarde',
    'FunguarFamiliar',
    'ShellbusterOrob',
    'ColdbloodComo',
    'CourierCarrie',
    'Homunculus',
    'VoraciousAudrey',
    'AmbusherAllie',
    'PanzerGalahad',
    'LifedrinkerLars',
    'ChopsueyChuky',
    'AmigoSabotender',
    'NurseryNazuna',
    'CraftyClyvonne',
    'PrestoJulio',
    'SwiftSieghard',
    'MailbusterCetas',
    'AudaciousAnna',
    'SlipperySilas',
    'TurbidToloi',
    'LuckyLulush',
    'DipperYuly',
    'FlowerpotMerle',
    'DapperMac',
    'DiscreetLouise',
    'FatsoFargann',
    'FaithfulFalcorr',
    'BugeyedBroncha',
    'BloodclawShasra',
    'GorefangHobs',
    'GooeyGerard',
    'CrudeRaphie',
    'DroppyDortwin',
    'SunburstMalfik',
    'WarlikePatrick',
    'ScissorlegXerin',
    'RhymingShizuna',
    'AttentiveIbuki',
    'AmiableRoche',
    'BrainyWaluis',
    'HeraldHenry',
    'SuspiciousAlice',
    'HeadbreakerKen',
    'RedolentCandi',
    'AnklebiterJedd',
    'CaringKiyomaro',
    'HurlerPercival',
    'BlackbeardRandy',
    'FleetReinhard',
    'AlluringHoney',
    'BouncingBertha',
    'BraveHeroGlenn',
    'CursedAnnabelle',
    'GenerousArthur',
    'SharpwitHermes',
    'SwoopingZhivago',
    'ThreestarLynn'
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

local function getActName(id)
    local resMgr = AshitaCore:GetResourceManager();
    for i = 0, 2048 do
        local act = resMgr:GetAbilityById(i);
        if(act ~= nil and act.RecastTimerId == id) then
            return act;
        end
    end
    return nil;
end

local function isJugPet(n)
    for i = 1,#jugs,1 do
        if(n == jugs[i]) then
            return true;
        end
    end
    return false;
end

local function getReady(t)
    local max = rchelper.max[102];
    t = t / 60;

    if (max ~= nil) then
        if(max > 90) then
            if(t > 90) then
                return 0;
            elseif(t <= 90 and t > 45)then
                return 1;
            elseif(t <= 45 and t > 0) then
                return 2;
            else
                return 3;
            end
        else
            if(t >= 61) then
                return 0;
            elseif(t <= 60 and t > 30)then
                return 1;
            elseif(t <= 30 and t > 0)then
                return 2;
            else
                return 3;
            end
        end
    end
end
        
rchelper.max = {};



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

        --Populate max duration table with longest found duration
        if(rchelper.max[id] == nil or (rchelper.max[id] ~= nil and max > rchelper.max[id]))then
            rchelper.max[id] = max;
        end

        if ((id ~= 0 or i == 0) and timer > 0) then
            local act = resMgr:GetAbilityByTimerId(id);
            local name = ('Unknown Ability:  %d'):fmt(id);

            if (i == 0) then
                local job = resMgr:GetString("jobs.names_abbr", AshitaCore:GetMemoryManager():GetPlayer():GetMainJob());
                name = oneHour[job];
            elseif(id == 131) then
                timer = nil;
                name = nil;
                max = nil;
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
            elseif(id == 102)then
                local player = GetPlayerEntity();
                local pet = GetEntity(player.PetTargetIndex);
                if(pet ~= nil)then
                    if(isJugPet(pet.Name) == true) then
                        name = ('Ready  [%d]'):fmt(getReady(timer));
                    else
                        name = 'Sic';
                    end
                elseif(pet == nil or pet.Name == '')then
                    name = 'Sic/Ready';
                end
            elseif(act ~= nil) then
                name = act.Name[1];
            elseif(act == nil) then
                act = getActName(id);
                if(act ~= nil) then
                    name = act.Name[1];
                end
            end
            if(timer ~= nil and name ~= nil and max ~= nil) then
                table.insert(timers, fmt_time(timer));
                table.insert(acts, name);
                table.insert(prog, ((timer / 60 ) / rchelper.max[id]));
            end
        end
    end

    for i = 0, 1024 do
        local id = i;
        local timer = Recast:GetSpellTimer(i);
        local max = Recast:GetSpellTimer(i) / 60;

        --Populate max duration table with longest found duration
        if(rchelper.max[id] == nil or (rchelper.max[id] ~= nil and max > rchelper.max[id]))then
            rchelper.max[id] = max;
        end

        if(timer > 0) then
            local spell = resMgr:GetSpellById(id);
            local name = 'Unknown Spell';

            if(spell ~= nil) then
                name = spell.Name[1];
            end
            if(spell == nil or name:len() == 0) then
                name = ('Unknown Spell:  %d'):fmt(id);
            end
            if(timer ~= nil and name ~= nil and max ~= nil) then
                table.insert(timers, fmt_time(timer));
                table.insert(acts, name);
                table.insert(prog, ((timer /60 ) / rchelper.max[id]));
            end
        end
    end
    
    return acts, timers, prog;
end

return rchelper;