---
name: pet-skillchain-wiring
description: How pet (BST/SMN/PUP) TP moves are detected for combat-toast skillchains, and the two id schemes involved
metadata:
  type: project
---

Combat-toast skillchain support for player-pet TP moves (added 2026-06-17).

`skillchain_data.lua` `M.pet_skills` holds pet TP moves with SC properties. Two id schemes coexist in one table:
- **BST charmed Ready + SMN Blood Pact: Rage** → retail pet-ability ids, ~513–970 ("513-scheme"). Ported from `chains/skills.lua` `skills.playerPet` / `skills[13]`.
- **PUP automaton** → higher mob-skill ids, 1940–2301 ("1940-scheme"). Ported from `chains/skills.lua` `skills[11]` (NPC TP skills).

Detection wired in `packet_chat_emit.lua` `emit_0x28`: fires `combat_event_cb` with `kind='pet'` when `act.actor.type` is `my_pet`/`other_pets` AND (action message 110/317 OR `act.category==11`). ability id = `act.param % 0x10000`. `combat_toasts.lua` `handle_combat_event` has a `kind=='pet'` branch (skips party-slot filter — ownership already checked upstream).

**Why:** pet's actor id is never a party slot, so the normal party filter would drop it; chains uses an owned-pet check (`actor_parse.server_id_is_summoned_pet`) instead.

**Skillchain window + options panel** (added 2026-06-17): `combat_toasts` stamps each chain state with `windowOpen=clock+3.5` / `windowClose=clock+(9.8-depth)` (thotbar constants, replicated not require'd). `M.get_chain_window` returns phase pending/open/closing/closed + alpha; render panel ([render.lua](../ui/render.lua) skillchain panel) shows a countdown and fades out after close. `skillchain_data.get_chain_options` now merges weapon skills + castable chain spells (`get_available_chain_spells`) + pet moves (`get_available_pet_abilities`, pet-out gated), each tagged `kind`. Chain-spell gating is by JOB/LEVEL not buff (for planning): SCH spells shown only if main SCH lvl>=75 (Immanence level); BLU spells shown if BLU is main/sub. Each carries `requiresBuff` (buff not currently up) → panel marks it `*(buff)`. Note the toast-RECORDING path (combat_toasts spell branch) still requires the buff actually up, since a spell only truly chains when buffed. Damaging-spell toasts: every spell whose primary action message has color 'D' in action_messages.lua (nukes/banish/holy/BLU magical+physical) plus HP-drain msgs 227/274 — classified in packet_chat_emit (event.damaging), replacing the old elemental-name-only gate. Known approximations: depth is inferred from opener-landing (we don't read the SC-proc `AdditionalEffect.Message` like thotbar does).

**Pet option filtering (fixed 2026-06-20):** `get_available_pet_abilities` previously returned the ENTIRE `pet_skills` table whenever any pet was out -- so a DRG (wyvern out, `PetTargetIndex>0`) saw every pet move in the game. Now gated three ways: (1) main job must be a chaining pet job `PET_SC_MAIN_JOBS = {9 BST, 15 SMN, 18 PUP}` (DRG/etc. get nothing -- a wyvern can't skillchain), (2) a pet must be out, (3) only moves the CURRENT pet instance has actually been seen using. Moveset narrowed to THIS pet, detected exactly like the party list (`GetEntity(PlayerEntity.PetTargetIndex)`, via `current_pet_identity` returning ServerId+Name):
- **SMN**: the pet entity's Name IS the avatar name, so `SMN_AVATAR_MOVES[name]` resolves the avatar's fixed Blood Pact: Rage moveset immediately (no waiting). Map covers Carbuncle/Cait Sith/Fenrir/Ifrit/Titan/Leviathan/Garuda/Shiva/Ramuh/Diabolos (513-scheme ids). Odin/Alexander/Atomos have no SC-capable rage move so they're absent (empty = correct).
- **BST**: jug pets are a fixed named roster; a charmed wild mob has the mob's own name. `get_available_pet_abilities` only contributes options when `normalize_pet_name(pet.Name)` is in the `BST_JUG_PET_NAMES` whitelist (normalized = lowercase, spaces/`-`/`'`/`.` stripped) -- non-jug names are ignored per user directive. Moves themselves come from observation (jug movesets are family-specific; hardcoding risks the over-listing we killed). The whitelist is RETAIL-guessed -- if a real jug pet shows no options on CatseyeXI, dump `pet.Name` and add it.
- **PUP**: automaton moveset is attachment-dependent, observation-only.
Observation: `combat_toasts.handle_combat_event` pet branch calls `skillchain_data.note_pet_ability_used(event.abilId)`, keyed to pet ServerId (reset on pet change). `is_local_skillchain_pet` (recording gate) widened from PUP/SMN to also include BST. SMN unions avatar-map + observed (instant + augment); BST/PUP are observation-only. If CatseyeXI customized avatar rage moves, correct `SMN_AVATAR_MOVES` against ids dumped from emit_0x28.

**UNVERIFIED guesses (test, then correct):** that automaton arrives as category 11 (not msg 110/317), and that CatseyeXI's 0x28 packet carries the 513-scheme id for BST/SMN (Windower/ASB use a different "907-scheme" id — see `ASB:` comments in chains/skills.lua). `pet_skills` was dead code until this wiring, so neither scheme was ever live-tested on CatseyeXI. If pet toasts don't fire, dump `cat` / `act.param` / `firstAction.message` for a real pet move.
