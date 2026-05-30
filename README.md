# Condomino Mod v2.0

Fixed autonomous NPC colonies for Minetest.

## Fixes Applied
- ✅ Unique names for each NPC (no duplicates)
- ✅ Proper gravity/movement (no flying)
- ✅ All NPCs build houses (fixed plot assignment)
- ✅ Mining actually required before building
- ✅ Wall builds after ALL houses are done
- ✅ State synchronization between colony members

## How It Works
1. Place `condomino:npc` (yellow wool block)
2. First NPC = Leader → builds 5×5 stone plaza at spawn
3. Other NPCs = Followers → mine 50 blocks away for materials
4. When plaza done + materials gathered → each builds their house
5. When ALL houses done → colony builds defensive stone wall
6. Wall complete → NPCs defend against intruders
7. Night time → NPCs sleep in their beds

## Limits
- Max 10 NPCs per colony
- When wall is finished, next spawner starts NEW colony
- Names are unique globally (no repeats ever)

## Dependencies
`default`, `beds`, `stairs`, `wool` (all from Minetest Game)
