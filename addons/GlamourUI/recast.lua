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
    ['HareFamiliar'] = 5400,
    ['SheepFamiliar'] = 3600,
    ['FlowerpotBill'] = 3600,
    ['TigerFamiliar']= 3600,
    ['FlytrapFamiliar'] = 3600,
    ['LizardFamiliar'] = 3600,
    ['MayflyFamiliar'] = 3600,
    ['EftFamiliar'] = 3600,
    ['BeetleFamiliar'] = 3600,
    ['AntlionFamiliar'] = 1800,
    ['CrabFamiliar'] = 1800,
    ['MiteFamiliar'] = 3600,
    ['KeenearedSteffi'] = 5400,
    ['LullabyMelodia'] = 3600,
    ['FlowerpotBen'] = 3600,
    ['SaberSiravarde'] = 3600,
    ['FunguarFamiliar'] = 3600,
    ['ShellbusterOrob'] = 3600,
    ['ColdbloodComo'] = 3600,
    ['CourierCarrie'] = 1800,
    ['Homunculus'] = 3600,
    ['VoraciousAudrey'] = 3600,
    ['AmbusherAllie'] = 3600,
    ['PanzerGalahad'] = 3600,
    ['LifedrinkerLars'] = 1800,
    ['ChopsueyChuky'] = 1800,
    ['AmigoSabotender'] = 1800,
    ['NurseryNazuna'] = 7200,
    ['CraftyClyvonne'] = 7200,
    ['PrestoJulio'] = 7200,
    ['SwiftSieghard'] = 7200,
    ['MailbusterCetas'] = 7200,
    ['AudaciousAnna'] = 7200,
    ['SlipperySilas'] = 1800,
    ['TurbidToloi'] = 7200,
    ['LuckyLulush'] = 7200,
    ['DipperYuly'] = 7200,
    ['FlowerpotMerle'] = 10800,
    ['DapperMac'] = 7200,
    ['DiscreetLouise'] = 7200,
    ['FatsoFargann'] = 7200,
    ['FaithfulFalcorr'] = 7200,
    ['BugeyedBroncha'] = 7200,
    ['BloodclawShasra'] = 7200,
    ['GorefangHobs'] = 7200,
    ['GooeyGerard'] = 5400,
    ['CrudeRaphie'] = 5400,
    ['DroppyDortwin'] = 7200,
    ['SunburstMalfik'] = 7200,
    ['WarlikePatrick'] = 7200,
    ['ScissorlegXerin'] = 7200,
    ['RhymingShizuna'] = 7200,
    ['AttentiveIbuki'] = 7200,
    ['AmiableRoche'] = 7200,
    ['BrainyWaluis'] = 7200,
    ['HeraldHenry'] = 7200,
    ['SuspiciousAlice'] = 7200,
    ['HeadbreakerKen'] = 7200,
    ['RedolentCandi'] = 7200,
    ['AnklebiterJedd'] = 7200,
    ['CaringKiyomaro'] = 7200,
    ['HurlerPercival'] = 7200,
    ['BlackbeardRandy'] = 7200,
    ['FleetReinhard'] = 7200,
    ['AlluringHoney'] = 7200,
    ['BouncingBertha'] = 7200,
    ['BraveHeroGlenn'] = 7200,
    ['CursedAnnabelle'] = 7200,
    ['GenerousArthur'] = 7200,
    ['SharpwitHermes'] = 7200,
    ['SwoopingZhivago'] = 7200,
    ['ThreestarLynn'] = 7200
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
    if(jugs:haskey(n))then
        return true;
    end
    return false;
end

local function getReady(t)
    t = t / 60;

    if (rchelper.max[102] == nil or rchelper.max[102] == 0 or rchelper.max[102] == 30 or rchelper.max[102] == 45) then
        if(t >= 35 and t < 70)then
            rchelper.max[102] = t * 3;
        elseif(t >= 70 and t < 91)then
            rchelper.max[102] = (t / 2) * 3;
        elseif(t >= 21 and t < 60)then
            rchelper.max[102] = t * 3;
        elseif(t >= 60 and t < 90)then
            rchelper.max[102] = (t / 2) * 3;
        end
    end

    local max = rchelper.max[102];

    if (max ~= nil) then
        return (max - t) / (max / 3);
    end
end
        
rchelper.max = {};

rchelper.PetDeg = {
    max = 0,
    time = 0,
    endtime = 0
}

rchelper.calcPetDeg = function(n)
    if(jugs:haskey(n))then
        rchelper.PetDeg.max = jugs[n];
        rchelper.PetDeg.time = os.time();
        if(rchelper.PetDeg.endtime <= 0)then
            rchelper.PetDeg.endtime = os.time() + rchelper.PetDeg.max;
        end
    end
end

rchelper.makeTimers = function()
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
            elseif(id == 104 or id == 94)then
                local player = GetPlayerEntity();
                local pet = GetEntity(player.PetTargetIndex);
                if(pet ~= nil and rchelper.PetDeg.time == 0)then
                    rchelper.calcPetDeg(pet.Name);
                end
                if(id == 94)then
                    name = "Bestial Loyalty";
                else
                    name = "Call Beast";
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