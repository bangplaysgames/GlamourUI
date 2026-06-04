require('common');

local M = {};

local domain_buffs = T{
    250,
    257,
    267,
    511,
    603,
};

local gProfileFilterCombat = { enemies = true };

local function nf(field, subfield)
    if (field ~= nil) then
        return field[subfield];
    end
    return nil;
end

local function get_entity_by_server_id(sid)
    for x = 0, 2303 do
        local ent = GetEntity(x);
        if (ent ~= nil and ent.ServerId == sid) then
            return ent;
        end
    end
    return nil;
end

local function parse_party(resource, party, mod, count)
    if (count == 0 or count > 6) then
        return;
    end

    for i = 0, count - 1 do
        local index = i + mod;
        local id = party .. i;
        resource[id] = {};
        resource[id]['hp'] = AshitaCore:GetMemoryManager():GetParty():GetMemberHP(index);
        resource[id]['hpp'] = AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(index);
        resource[id]['mp'] = AshitaCore:GetMemoryManager():GetParty():GetMemberMP(index);
        resource[id]['mpp'] = AshitaCore:GetMemoryManager():GetParty():GetMemberMPPercent(index);
        resource[id]['tp'] = AshitaCore:GetMemoryManager():GetParty():GetMemberTP(index);
        resource[id]['zone'] = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(index);
        resource[id]['zone2'] = AshitaCore:GetMemoryManager():GetParty():GetMemberZone2(index);
        resource[id]['name'] = AshitaCore:GetMemoryManager():GetParty():GetMemberName(index);
        resource[id]['mob'] = GetEntity(AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(index));
    end
end

local function entity_spawn_is_mob(ent)
    if (ent == nil) then
        return false;
    end
    local flags = tonumber(ent.SpawnFlags) or 0;
    return bit.band(flags, 0x10) == 0x10;
end

local function get_party_data()
    local resource = {};

    parse_party(resource, 'p', 0, AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount1());
    parse_party(resource, 'al', 6, AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount2());
    parse_party(resource, 'a2', 12, AshitaCore:GetMemoryManager():GetParty():GetAlliancePartyMemberCount3());

    return resource;
end

local function pet_index_matches_server_id(pet_target_index, actor_server_id)
    local pet_idx = tonumber(pet_target_index) or 0;
    actor_server_id = tonumber(actor_server_id) or 0;
    if (pet_idx <= 0 or actor_server_id == 0 or GetEntity == nil) then
        return false;
    end
    local pet_ent = GetEntity(pet_idx);
    if (pet_ent == nil or pet_ent.ServerId == nil) then
        return false;
    end
    return tonumber(pet_ent.ServerId) == actor_server_id;
end

function M.server_id_is_summoned_pet(actor_server_id)
    actor_server_id = tonumber(actor_server_id) or 0;
    if (actor_server_id == 0) then
        return false;
    end
    local player_ent = (GetPlayerEntity ~= nil) and GetPlayerEntity() or nil;
    if (player_ent ~= nil) then
        if (pet_index_matches_server_id(player_ent.PetTargetIndex, actor_server_id)) then
            return true;
        end
        if (pet_index_matches_server_id(player_ent.FellowTargetIndex, actor_server_id)) then
            return true;
        end
    end
    for _, v in pairs(get_party_data()) do
        if (type(v) == 'table' and v.mob ~= nil) then
            if (pet_index_matches_server_id(v.mob.PetTargetIndex, actor_server_id)) then
                return true;
            end
            if (pet_index_matches_server_id(v.mob.FellowTargetIndex, actor_server_id)) then
                return true;
            end
        end
    end
    return false;
end

function M.parse(actor_id)
    local actor_table = get_entity_by_server_id(actor_id);
    local actor_name, typ, dmg, owner, filt, owner_name;

    if (actor_table == nil) then
        return {
            name = ('{Debug ID: %s}'):fmt(actor_id),
            id = '{DebugID}',
            is_npc = true,
            type = 'debug',
            damage = 'otherdmg',
            filter = 'others',
            owner = 'other',
            owner_name = '{Owner}',
            race = 0,
        };
    end

    local ActorIsNpc = bit.band(actor_table.SpawnFlags, 0x1) == 0;

    for i, v in pairs(get_party_data()) do
        if (type(v) == 'table' and v.mob and v.mob.ServerId == actor_table.ServerId) then
            typ = i;
            if (i == 'p0') then
                filt = 'me';
                dmg = 'mydmg';
            elseif (i:sub(1, 1) == 'p') then
                filt = 'party';
                dmg = 'partydmg';
            else
                filt = 'alliance';
                dmg = 'allydmg';
            end
        end
    end

    if (not filt) then
        if (ActorIsNpc) then
            --- Avatars / jug pets: PetTargetIndex on owner → pet entity ServerId must match this actor.
            if (M.server_id_is_summoned_pet(actor_id)) then
                local player_ent = (GetPlayerEntity ~= nil) and GetPlayerEntity() or nil;
                if (player_ent ~= nil and pet_index_matches_server_id(player_ent.PetTargetIndex, actor_id)) then
                    typ = 'my_pet';
                    filt = 'my_pet';
                    owner = 'p0';
                    dmg = 'mydmg';
                else
                    typ = 'other_pets';
                    filt = 'other_pets';
                    owner = 'other';
                    dmg = 'otherdmg';
                    for i, v in pairs(get_party_data()) do
                        if (type(v) == 'table' and v.mob ~= nil) then
                            if (pet_index_matches_server_id(v.mob.PetTargetIndex, actor_id)) then
                                if (i == 'p0') then
                                    typ = 'my_pet';
                                    filt = 'my_pet';
                                    dmg = 'mydmg';
                                end
                                owner = i;
                                owner_name = '';
                                break;
                            end
                        end
                    end
                end
            end
            if (typ == nil and entity_spawn_is_mob(actor_table)) then
                typ = 'mob';
                filt = 'monsters';
                dmg = 'mobdmg';

                if (gProfileFilterCombat.enemies) then
                    local SelfPlayer = AshitaCore:GetMemoryManager():GetPlayer();
                    if (SelfPlayer ~= nil and SelfPlayer.GetBuffs ~= nil) then
                        for _, v in pairs(SelfPlayer:GetBuffs()) do
                            if (domain_buffs:contains(v)) then
                                filt = 'enemies';
                                break;
                            end
                        end
                    end

                    if (filt ~= 'enemies') then
                        for _, v in pairs(get_party_data()) do
                            if (type(v) == 'table' and nf(v.mob, 'ServerId') == bit.band(actor_table.ClaimStatus, 0xFFFFFFFFFF)) then
                                filt = 'enemies';
                                break;
                            end
                        end
                    end
                end
            elseif (typ == nil) then
                -- Trusts and other allied NPCs (no 0x10 mob flag)
                typ = 'trust';
                filt = 'party';
                dmg = 'partydmg';
            end
        else
            typ = 'other';
            filt = 'others';
            dmg = 'otherdmg';
        end
    end

    if (actor_table.MonstrosityName ~= ' ') then
        actor_name = actor_table.Name;
    else
        actor_name = actor_table.MonstrosityName;
    end

    return {
        name = actor_name,
        id = actor_id,
        is_npc = ActorIsNpc,
        type = typ,
        damage = dmg,
        filter = filt,
        owner = (owner or nil),
        owner_name = (owner_name or ''),
        race = actor_table.Race,
    };
end

return M;
