-- ============================================================
-- CONDOMINO MOD — Autonomous NPC Colonies
-- Dependencies: default, beds, stairs, wool
-- All NPCs spawn pre-stocked; no mining required.
-- Phase sequence: PLAZA → HOUSES → WALL → DONE
-- ============================================================

condomino = {}

-- ============================================================
-- 🔧 HELPER: Logging (MUST be defined before any calls to it)
-- ============================================================
local function clog(msg)
	minetest.log("action", "[Condomino] " .. tostring(msg))
end

-- ============================================================
-- SECTION 1: DYNAMIC .WE SCHEMA LOADER & GRID GENERATOR
-- ============================================================

condomino.names = {
	"Matías","Sebastián","Mateo","Nicolás","Alejandro","Samuel","Diego","Daniel",
	"Benjamín","Leonardo","Tomás","Joaquín","Gabriel","Emiliano","Martín","Lucas",
	"Agustín","David","Iker","Juan José","Maximiliano","Adrián","Emmanuel","Felipe",
	"Juan Pablo","Andrés","Jerónimo","Ángel","Rodrigo","Bruno","Alexander","Thiago",
	"Pablo","Ian","Isaac","Miguel Ángel","Fernando","Javier","Emilio","Juan Sebastián",
	"Alonso","Aarón","Rafael","Esteban","Juan Diego","Axel","Francisco","Bautista",
	"Carlos","Dylan","Juan","Julián","Manuel","Facundo","Gael","Valentino","Damián",
	"Santino","Vicente","Máximo","Christopher","Jorge","Luciano","Dante","Alan",
	"Cristóbal","Jesús","Lorenzo","Alex","Juan Esteban","Patricio","Pedro","Juan Manuel",
	"Matthew","Antonio","Iván","José","Hugo","Josué","Lautaro","Diego Alejandro",
	"Miguel","Franco","Kevin","Luis","Simón","Elías","Caleb","Eduardo","Ricardo",
	"Juan David","Marcos","Salvador","Jacobo","Juan Ignacio","Camilo","Mauricio",
	"Juan Felipe","Gonzalo"
}

-- Parse WorldEdit .we files (Lua-serialized tables)
local function load_we_schema(filepath)
	local f = io.open(filepath, "r")
	if not f then return nil end
	
	local content = f:read("*all")
	f:close()
	
	if not content or content == "" then return nil end
	
	-- Strip WorldEdit version prefix (e.g., "5:" or "6:")
	content = content:gsub("^%d+:", "")
	
	-- Minetest uses LuaJIT (Lua 5.1), which requires loadstring()
	local fn, err = loadstring(content, "schema_" .. filepath)
	if not fn then
		clog("ERROR: Failed to compile .we file " .. filepath .. ": " .. tostring(err))
		return nil
	end
	
	local success, schema = pcall(fn)
	if not success then
		clog("ERROR: Failed to execute .we file " .. filepath .. ": " .. tostring(schema))
		return nil
	end
	
	if type(schema) ~= "table" then
		clog("ERROR: .we file " .. filepath .. " did not return a valid table")
		return nil
	end
	
	return schema
end

-- Load schemas at startup
condomino.house_schemas = {}
local mod_path = minetest.get_modpath(minetest.get_current_modname())
local schema_dir = mod_path .. "/schema"

local function load_and_log(idx, filename)
	local path = schema_dir .. "/" .. filename
	local schema = load_we_schema(path)
	if schema and #schema > 0 then
		condomino.house_schemas[idx] = schema
		clog("Loaded house #" .. idx .. " (" .. #schema .. " blocks) from " .. filename)
	else
		clog("WARN: Missing, empty, or invalid schematic for house #" .. idx .. " at " .. path)
	end
end

-- Load house 1 (tries standard_house1.we, falls back to standard_house.we)
load_and_log(1, "standard_house1.we")
if not condomino.house_schemas[1] then
	load_and_log(1, "standard_house.we")
end
-- Load houses 2-10
for i = 2, 10 do
	load_and_log(i, "standard_house" .. i .. ".we")
end

-- ============================================================
-- 📐 DYNAMIC HOUSE SLOT GENERATOR (Guarantees exactly 3-block gaps)
-- ============================================================
local GAP = 3
local max_x, max_z = 0, 0

-- Find largest footprint across all loaded schemas
for _, schema in ipairs(condomino.house_schemas) do
	for _, step in ipairs(schema) do
		if step.x > max_x then max_x = step.x end
		if step.z > max_z then max_z = step.z end
	end
end

-- Fallback defaults if no schemas loaded yet
if max_x == 0 then max_x = 6 end
if max_z == 0 then max_z = 5 end

local spacing_x = max_x + GAP
local spacing_z = max_z + GAP

-- Generate 10 slots in a 4x3 grid, perfectly centered around (0,0)
condomino.house_slots = {}
local grid_layout = {
	{col=0, row=0}, {col=1, row=0}, {col=2, row=0}, {col=3, row=0},
	{col=0, row=1}, {col=1, row=1}, {col=2, row=1}, {col=3, row=1},
	{col=0, row=2}, {col=1, row=2},
}

for _, p in ipairs(grid_layout) do
	-- Center offset: 4 cols → -1.5, 3 rows → -1.0
	table.insert(condomino.house_slots, {
		x = (p.col - 1.5) * spacing_x,
		z = (p.row - 1.0) * spacing_z,
	})
end

clog(string.format("House grid auto-generated: X spacing=%d, Z spacing=%d (Gap between houses=%d)", spacing_x, spacing_z, GAP))

-- Pre-filled inventory every NPC spawns with (simulated; building always succeeds)
condomino.start_inventory = {
	["default:dirt"]       = 25,
	["stairs:slab_glass"]  = 15,
	["default:chest"]      = 1,
	["beds:bed_top"]       = 1,
	["beds:bed_bottom"]    = 1,
	["default:torch_wall"] = 2,
	["default:stone"]      = 200,  -- leader uses this for plaza + wall
}

-- ============================================================
-- SECTION 2: COLONY MANAGER
-- ============================================================

condomino.colonies = {}
local storage = minetest.get_mod_storage()

local function save_colonies()
	storage:set_string("colonies", minetest.serialize(condomino.colonies))
end

local function load_colonies()
	local raw = storage:get_string("colonies")
	if raw and raw ~= "" then
		condomino.colonies = minetest.deserialize(raw) or {}
	end
end

load_colonies()

-- Find a non-DONE colony within 80 nodes
local function find_colony(pos)
	for i, col in ipairs(condomino.colonies) do
		if col.phase ~= "DONE" and vector.distance(pos, col.center) < 80 then
			return col, i
		end
	end
	return nil, nil
end

-- Create brand-new colony; colony starts in PLAZA phase immediately
local function new_colony(pos)
	local col = {
		center       = vector.round(pos),
		phase        = "PLAZA",
		npcs         = {},
		houses_built = {},
	}
	table.insert(condomino.colonies, col)
	save_colonies()
	clog("New colony #" .. #condomino.colonies .. " at " .. minetest.pos_to_string(col.center))
	return col, #condomino.colonies
end

-- ============================================================
-- SECTION 3: NPC ENTITY DEFINITION
-- ============================================================

minetest.register_entity("condomino:npc_entity", {

	initial_properties = {
		visual          = "mesh",
		mesh            = "character.b3d",
		textures        = {"character.png"},
		collisionbox    = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		stepheight      = 0.6,
		visual_size     = {x = 1, y = 1},
		physical        = true,
		automatic_rotate = 0,
		makes_footstep_sound = true,
	},

	get_staticdata = function(self)
		return minetest.serialize({
			npc_name    = self.npc_name,
			role        = self.role,
			colony_idx  = self.colony_idx,
			house_idx   = self.house_idx,
			task        = self.task,
			build_step  = self.build_step,
			wall_idx    = self.wall_idx,
			plaza_ix    = self.plaza_ix,
			plaza_iz    = self.plaza_iz,
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		local data = {}
		if staticdata and staticdata ~= "" then
			data = minetest.deserialize(staticdata) or {}
		end

		self.npc_name   = data.npc_name   or condomino.names[math.random(#condomino.names)]
		self.role       = data.role       or "FOLLOWER"
		self.colony_idx = data.colony_idx
		self.house_idx  = data.house_idx
		self.task       = data.task       or "IDLE"
		self.build_step = data.build_step or 1
		self.wall_idx   = data.wall_idx   or 1
		self.plaza_ix   = data.plaza_ix   or -24
		self.plaza_iz   = data.plaza_iz   or -24

		self.timer      = 0
		self.anim_timer = 0
		self.patrol_pos = nil
		self.stuck_timer = 0
		self.last_pos   = nil

		self.object:set_properties({
			nametag       = self.npc_name,
			nametag_color = (self.role == "LEADER") and "#FFD700" or "#FFFFFF",
			infotext      = self.role .. ": " .. self.task,
		})

		self.object:set_acceleration({x = 0, y = -9.8, z = 0})
	end,

	move_toward = function(self, target, dtime, tol)
		tol = tol or 1.5
		local my = self.object:get_pos()
		if not my then return true end

		local dx = target.x - my.x
		local dz = target.z - my.z
		local flat_dist = math.sqrt(dx*dx + dz*dz)

		if flat_dist < tol then
			local vy = self.object:get_velocity().y
			self.object:set_velocity({x = 0, y = vy, z = 0})
			return true
		end

		local inv = 1 / flat_dist
		local dirx = dx * inv
		local dirz = dz * inv

		local want_yaw = math.atan2(-dirx, dirz)
		local cur_yaw  = self.object:get_yaw() or 0
		local diff = want_yaw - cur_yaw
		if diff >  math.pi then diff = diff - 2 * math.pi end
		if diff < -math.pi then diff = diff + 2 * math.pi end
		self.object:set_yaw(cur_yaw + diff * math.min(dtime * 12, 1))

		local speed = 3.5
		local vy    = self.object:get_velocity().y
		self.object:set_velocity({x = dirx * speed, y = vy, z = dirz * speed})

		local ahead = {
			x = my.x + dirx * 0.8,
			y = my.y + 0.5,
			z = my.z + dirz * 0.8,
		}
		local node_name = minetest.get_node(ahead).name
		local ndef = minetest.registered_nodes[node_name]
		if ndef and ndef.walkable and vy <= 0.1 then
			local above = {x = ahead.x, y = my.y + 1.8, z = ahead.z}
			local top_name = minetest.get_node(above).name
			local tdef = minetest.registered_nodes[top_name]
			if not tdef or not tdef.walkable then
				self.object:set_velocity({x = dirx * speed, y = 5.5, z = dirz * speed})
			end
		end

		return false
	end,

	update_anim = function(self)
		local vel = self.object:get_velocity()
		local hspeed = math.sqrt(vel.x*vel.x + vel.z*vel.z)
		if hspeed > 0.5 then
			self.object:set_animation({x = 168, y = 188}, 30, 0, true)
		else
			self.object:set_animation({x = 0,   y = 79},  30, 0, true)
		end
	end,

	place_block = function(self, pos, step)
		local cur = minetest.get_node(pos).name
		local cur_def = minetest.registered_nodes[cur]
		if cur_def and cur_def.buildable_to == false and cur ~= "air" then
			return
		end
		local param1 = step.param1 or 0
		local param2 = step.param2 or 0
		minetest.set_node(pos, {name = step.name, param1 = param1, param2 = param2})
		if step.meta and step.meta.fields then
			local meta = minetest.get_meta(pos)
			for k, v in pairs(step.meta.fields) do
				meta:set_string(k, v)
			end
		end
	end,

	set_info = function(self, text)
		self.object:set_properties({infotext = self.role .. " | " .. text})
	end,

	do_plaza = function(self, col, dtime)
		if self.role ~= "LEADER" then
			self:set_info("Waiting for plaza...")
			self:move_toward(col.center, dtime, 2)
			return
		end

		self:set_info("Building plaza floor...")

		local HALF = 24
		local blocks_per_tick = 30
		local placed = 0

		while placed < blocks_per_tick do
			if self.plaza_ix > HALF then
				col.phase = "HOUSES"
				self.task  = "IDLE"
				self.build_step = 1
				save_colonies()
				clog("Colony plaza done. Phase→HOUSES")
				return
			end

			local bpos = {
				x = col.center.x + self.plaza_ix,
				y = col.center.y,
				z = col.center.z + self.plaza_iz,
			}
			minetest.set_node(bpos, {name = "default:stone"})
			minetest.remove_node({x = bpos.x, y = bpos.y + 1, z = bpos.z})
			minetest.remove_node({x = bpos.x, y = bpos.y + 2, z = bpos.z})

			self.plaza_iz = self.plaza_iz + 1
			if self.plaza_iz > HALF then
				self.plaza_iz = -HALF
				self.plaza_ix = self.plaza_ix + 1
			end

			placed = placed + 1
		end

		self:move_toward(col.center, dtime, 3)
	end,

	do_houses = function(self, col, dtime)
		if col.houses_built[self.house_idx] then
			self:set_info("House done. Resting...")
			self:move_toward(col.center, dtime, 3)

			if self.role == "LEADER" then
				local all_done = true
				for i = 1, #col.npcs do
					if not col.houses_built[i] then
						all_done = false
						break
					end
				end
				if all_done then
					col.phase = "WALL"
					self.task  = "IDLE"
					self.wall_idx = 1
					self:build_wall_list(col)
					save_colonies()
					clog("All houses done. Phase→WALL")
				end
			end
			return
		end

		local slot = condomino.house_slots[self.house_idx]
		if not slot then
			clog("ERROR: no slot for house_idx " .. tostring(self.house_idx))
			return
		end

		local origin = {
			x = col.center.x + slot.x,
			y = col.center.y + 1,
			z = col.center.z + slot.z,
		}

		local work_pos = {
			x = origin.x + 2,
			y = origin.y,
			z = origin.z + 0,
		}

		if not self:move_toward(work_pos, dtime, 1.5) then
			self:set_info("Walking to house slot #" .. self.house_idx)
			return
		end

		-- ✅ DYNAMIC SCHEMA SELECTION
		local schema = condomino.house_schemas[self.house_idx]
		if not schema then
			clog("ERROR: No schema loaded for house_idx " .. tostring(self.house_idx))
			return
		end

		local step = schema[self.build_step]
		if not step then
			col.houses_built[self.house_idx] = true
			self.task = "IDLE"
			save_colonies()
			self:set_info("House complete!")
			clog(self.npc_name .. " finished house #" .. self.house_idx)
			return
		end

		self:set_info("Building house step " .. self.build_step .. "/" .. #schema)

		local block_pos = {
			x = origin.x + step.x,
			y = origin.y + step.y,
			z = origin.z + step.z,
		}
		self:place_block(block_pos, step)
		self.build_step = self.build_step + 1
	end,

	build_wall_list = function(self, col)
		if col.wall_nodes and #col.wall_nodes > 0 then return end
		col.wall_nodes = {}
		local R = 27

		for layer = 0, 2 do
			for xi = -R, R do
				table.insert(col.wall_nodes, {x = xi, y = layer, z = -R})
				table.insert(col.wall_nodes, {x = xi, y = layer, z =  R})
			end
			for zi = -R+1, R-1 do
				table.insert(col.wall_nodes, {x = -R, y = layer, z = zi})
				table.insert(col.wall_nodes, {x =  R, y = layer, z = zi})
			end
		end
		save_colonies()
	end,

	do_wall = function(self, col, dtime)
		if self.role ~= "LEADER" then
			self:set_info("Waiting for wall...")
			self:move_toward(col.center, dtime, 3)
			return
		end

		if not col.wall_nodes or #col.wall_nodes == 0 then
			self:build_wall_list(col)
		end

		self:set_info("Building wall... " .. tostring(self.wall_idx) .. "/" .. #col.wall_nodes)

		local blocks_per_tick = 40
		local placed = 0

		while placed < blocks_per_tick do
			if self.wall_idx > #col.wall_nodes then
				col.phase = "DONE"
				self.task  = "PATROL"
				save_colonies()
				clog("Wall done. Phase→DONE")
				return
			end

			local off = col.wall_nodes[self.wall_idx]
			local is_gate = (off.z == -27) and (off.x == 0 or off.x == 1) and (off.y <= 1)

			if not is_gate then
				local wpos = {
					x = col.center.x + off.x,
					y = col.center.y + off.y,
					z = col.center.z + off.z,
				}
				minetest.set_node(wpos, {name = "default:stone"})
			end

			self.wall_idx = self.wall_idx + 1
			placed = placed + 1
		end

		self:move_toward(col.center, dtime, 3)
	end,

	do_patrol = function(self, col, dtime)
		local tod   = minetest.get_timeofday()
		local night = tod < 0.25 or tod > 0.75

		if night then
			self:set_info("Sleeping... Zzz")
			local slot = condomino.house_slots[self.house_idx]
			if slot then
				local bed_pos = {
					x = col.center.x + slot.x + 2,
					y = col.center.y,
					z = col.center.z + slot.z + 4,
				}
				self:move_toward(bed_pos, dtime, 1.5)
			end
			return
		end

		self:set_info("Patrolling...")

		if not self.patrol_pos or self:move_toward(self.patrol_pos, dtime, 2) then
			self.patrol_pos = {
				x = col.center.x + math.random(-20, 20),
				y = col.center.y,
				z = col.center.z + math.random(-20, 20),
			}
		end

		local my_pos = self.object:get_pos()
		if not my_pos then return end
		for _, obj in ipairs(minetest.get_objects_inside_radius(my_pos, 8)) do
			local le = obj:get_luaentity()
			local hostile = obj:is_player()
				or (le and le.name and le.name ~= "condomino:npc_entity"
					and not le.is_npc)
			if hostile then
				local opos = obj:get_pos()
				if opos then
					self:move_toward(opos, dtime, 1)
					if vector.distance(my_pos, opos) < 1.8 then
						obj:punch(self.object, 1.0, {
							full_punch_interval = 1.0,
							damage_groups = {fleshy = 2},
						})
					end
				end
				break
			end
		end
	end,

	on_step = function(self, dtime)
		self.timer      = (self.timer or 0)      + dtime
		self.anim_timer = (self.anim_timer or 0) + dtime

		if self.anim_timer >= 0.15 then
			self:update_anim()
			self.anim_timer = 0
		end

		if self.timer < 0.1 then return end
		local dt = self.timer
		self.timer = 0

		local col = condomino.colonies[self.colony_idx]
		if not col then
			self:set_info("No colony?")
			return
		end

		if col.phase == "PLAZA" then
			self:do_plaza(col, dt)
		elseif col.phase == "HOUSES" then
			self:do_houses(col, dt)
		elseif col.phase == "WALL" then
			self:do_wall(col, dt)
		elseif col.phase == "DONE" then
			self:do_patrol(col, dt)
		end
	end,

})  -- end register_entity

-- ============================================================
-- SECTION 4: SPAWN NODE
-- ============================================================

minetest.register_node("condomino:npc", {
	description  = "Colony NPC Spawner (Yellow)",
	tiles        = {"wool_yellow.png"},
	groups       = {cracky = 3, oddly_breakable_by_hand = 3},
	is_ground_content = false,

	on_construct = function(pos)
		local col, cidx = find_colony(pos)
		if not col or #col.npcs >= 10 then
			col, cidx = new_colony(pos)
		end

		local role      = (#col.npcs == 0) and "LEADER" or "FOLLOWER"
		local house_idx = #col.npcs + 1

		local ent = minetest.add_entity(pos, "condomino:npc_entity",
			minetest.serialize({
				npc_name   = condomino.names[math.random(#condomino.names)],
				role       = role,
				colony_idx = cidx,
				house_idx  = house_idx,
				task       = "IDLE",
				build_step = 1,
				wall_idx   = 1,
				plaza_ix   = -24,
				plaza_iz   = -24,
			})
		)

		if ent then
			table.insert(col.npcs, house_idx)
			save_colonies()
			clog("Spawned " .. role .. " #" .. house_idx .. " for colony #" .. cidx)
		end

		minetest.remove_node(pos)
	end,
})

-- ============================================================
-- SECTION 5: DEBUG COMMAND
-- ============================================================

minetest.register_chatcommand("condomino_debug", {
	description = "Print colony status to chat",
	func = function(name)
		if #condomino.colonies == 0 then
			minetest.chat_send_player(name, "[Condomino] No colonies yet.")
			return
		end
		for i, col in ipairs(condomino.colonies) do
			local houses = 0
			for _ in pairs(col.houses_built) do houses = houses + 1 end
			minetest.chat_send_player(name,
				string.format("[Col #%d] center=%s phase=%s npcs=%d houses_done=%d",
					i,
					minetest.pos_to_string(col.center),
					col.phase,
					#col.npcs,
					houses
				)
			)
		end
	end,
})

-- ============================================================
-- SECTION 6: CLEAR ALL COLONIES (admin reset)
-- ============================================================

minetest.register_chatcommand("condomino_reset", {
	description = "Reset all colony data (admin)",
	privs = {server = true},
	func = function(name)
		condomino.colonies = {}
		storage:set_string("colonies", "")
		minetest.chat_send_player(name, "[Condomino] All colony data cleared.")
	end,
})
