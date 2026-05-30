# Condomino Mod

Autonomous NPC colonies for Minetest.

## Features
- **Unique Names**: Each NPC gets a unique name from a predefined list.
- **Colony Building**: NPCs build a plaza, houses, and a defensive wall.
- **States**: Mining, Building, Sleeping, Defending.
- **Player-like**: Uses the standard character model and moves like a player.

## Usage
1. Place `condomino:npc` (Yellow Wool block).
2. The first NPC becomes the Leader.
3. Subsequent NPCs join the colony until 10 members are reached.
4. Once the wall is built, the colony is complete. New spawners start new colonies.

## Dependencies
- default
- beds
- stairs
- wool# Condomino Mod

An autonomous NPC colony simulator for Minetest/Luanti.

## Features
- **Autonomous NPCs**: Spawn NPCs that look like players and act independently.
- **Colony Building**: NPCs work together to build a village.
  - **Leader**: Builds a central stone plaza.
  - **Followers**: Mine resources and build individual houses.
  - **Defense**: Once houses are complete, the colony builds a defensive stone wall.
- **Resource Gathering**: NPCs travel to a mine site (50 blocks away) to gather stone, dirt, and sand.
- **Day/Night Cycle**: NPCs sleep in their beds at night.
- **Defense Mode**: After the wall is built, NPCs defend the colony against intruders.

## Usage
1. Craft or obtain the `condomino:npc` block (Yellow Wool appearance).
2. Place the block in the world.
3. An NPC will spawn.
   - The first NPC becomes the **Leader** and starts building the plaza.
   - Subsequent NPCs become **Followers** and assist in mining and building houses.
4. Watch them build their village!

## Mechanics
- **Names**: NPCs are assigned unique Spanish names from a predefined list.
- **Limit**: Each colony supports up to 10 NPCs.
- **New Colonies**: Once a colony finishes its wall, the next spawner placed will start a new, independent colony.
- **Interaction**: You cannot interact with NPCs directly. Hover over them to see their current action. They can be killed.

## Dependencies
- `default`
- `beds`
- `stairs`
- `wool`

## Technical Notes
- No external textures are used; it relies on standard game assets.
- AI is deterministic and state-based (Mine -> Craft -> Build -> Defend).
- Pathfinding is basic (direct movement with simple jump/obstacle handling).
