-- condomino/init.lua
-- Autonomous NPC Colony Mod for Luanti/Minetest

condomino = {}
condomino.colonies = {}
condomino.next_colony_id = 1
condomino.used_names = {}

-- ===========================================================================
-- 1. DATA & CONFIGURATION
-- ===========================================================================

local NAMES = {
	"Matías", "Sebastián", "Mateo", "Nicolás", "Alejandro", "Samuel", "Diego", "Daniel", "Benjamín", "Leonardo",
	"Tomás", "Joaquín", "Gabriel", "Emiliano", "Martín", "Lucas", "Agustín", "David", "Iker", "Juan José",
	"Maximiliano", "Adrián", "Emmanuel", "Felipe", "Juan Pablo", "Andrés", "Jerónimo", "Ángel", "Rodrigo", "Bruno",
	"Alexander", "Thiago", "Pablo", "Ian", "Isaac", "Miguel Ángel", "Fernando", "Javier", "Emilio", "Juan Sebastián",
	"Alonso", "Aarón", "Rafael", "Esteban", "Juan Diego", "Axel", "Francisco", "Bautista", "Carlos", "Dylan",
	"Juan", "Julián", "Manuel", "Facundo", "Gael", "Valentino", "Damián", "Santino", "Vicente", "Máximo",
	"Christopher", "Jorge", "Luciano", "Dante", "Alan", "Cristóbal", "Jesús", "Lorenzo", "Alex", "Juan Esteban",
	"Patricio", "Pedro", "Juan Manuel", "Matthew", "Antonio", "Iván", "José", "Hugo", "Josué", "Lautaro",
	"Diego Alejandro", "Miguel", "Franco", "Kevin", "Luis", "Simón", "Elías", "Caleb", "Eduardo", "Ricardo",
	"Juan David", "Marcos", "Salvador", "Jacobo", "Juan Ignacio", "Camilo", "Mauricio", "Juan Felipe", "Gonzalo"
}

local HOUSE_SCHEMA = {
	{y=0,z=2,name="default:dirt",x=1}, {y=0,z=3,name="default:dirt",x=1}, {y=0,z=4,name="default:dirt",x=1}, {y=0,z=5,name="default:dirt",x=1},
	{y=1,z=2,name="default:dirt",x=1}, {y=1,z=3,name="default:dirt",x=1}, {y=1,z=4,name="default:dirt",x=1}, {y=1,z=5,name="default:dirt",x=1},
	{y=2,param1=159,param2=2,z=2,name="stairs:slab_glass",x=1}, {y=2,param1=175,param2=3,z=3,name="stairs:slab_glass",x=1}, {y=2,param1=159,z=4,name="stairs:slab_glass",x=1}, {y=2,param1=143,param2=3,z=5,name="stairs:slab_glass",x=1},
	{y=0,z=2,name="default:dirt",x=2}, {y=0,param1=190,meta={fields={infotext="Chest"}},param2=3,z=3,name="default:chest",x=2}, {y=0,param1=174,param2=3,z=4,name="beds:bed_top",x=2}, {y=0,z=5,name="default:dirt",x=2},
	{y=1,z=2,name="default:dirt",x=2}, {y=1,param1=207,param2=3,z=3,name="default:torch_wall",x=2}, {y=1,z=5,name="default:dirt",x=2},
	{y=2,param1=175,param2=2,z=2,name="stairs:slab_glass",x=2}, {y=2,param1=191,param2=3,z=3,name="stairs:slab_glass",x=2}, {y=2,param1=175,z=4,name="stairs:slab_glass",x=2}, {y=2,param1=159,param2=3,z=5,name="stairs:slab_glass",x=2},
	{y=0,z=2,name="default:dirt",x=3}, {y=0,param1=158,param2=3,z=4,name="beds:bed_bottom",x=3}, {y=0,z=5,name="default:dirt",x=3},
	{y=1,z=2,name="default:dirt",x=3}, {y=1,z=5,name="default:dirt",x=3},
	{y=2,param1=159,param2=2,z=2,name="stairs:slab_glass",x=3}, {y=2,param1=175,param2=3,z=3,name="stairs:slab_glass",x=3}, {y=2,param1=159,z=4,name="stairs:slab_glass",x=3}, {y=2,param1=143,param2=2,z=5,name="stairs:slab_glass",x=3},
	{y=0,z=2,name="default:dirt",x=4}, {y=0,z=5,name="default:dirt",x=4},
	{y=1,z=2,name="default:dirt",x=4}, {y=1,z=5,name="default:dirt",x=4},
	{y=2,param1=143,param2=3,z=2,name="stairs:slab_glass",x=4}, {y=2,param1=159,param2=3,z=3,name="stairs:slab_glass",x=4}, {y=2,param1=143,z=4,name="stairs:slab_glass",x=4}, {y=2,param1=127,param2=2,z=5,name="stairs:slab_glass",x=4}
}

local REQUIRED_ITEMS = {
	["default:dirt"] = 20,
	["stairs:slab_glass"] = 12,
	["default:chest"] = 1,
	["beds:bed_top"] = 1,
	["beds:bed_bottom"] = 1,
	["default:torch_wall"] = 1
}

local HOUSE_SLOTS = {
	{x=-9, z=-9}, {x=-3, z=-9}, {x=3, z=-9}, {x=9, z=-9},
	{x=-9, z=-3}, {x=-3, z=-3}, {x=3, z=-3}, {x=9, z=-3},
	{x=-9, z=3},  {x=-3, z=3}
}

-- ===========================================================================
-- 2. COLONY MANAGEMENT
-- ===========================================================================

local function get_active_colony()
	for id, c in pairs(condomino.colonies) do
		if c.phase ~= "DONE" and #c.members < 10 then return id end
	end
	return nil
end

local function create_colony(center_pos)
	local id = condomino.next_colony_id
	condomino.next_colony_id = condomino.next_colony_id + 1
	local c = vector.round(center_pos)
	condomino.colonies[id] = {
		id = id,
		center = c,
		mine_pos = {x = c.x + 50, y = c.y + 1, z = c.z}, -- +1 Y to avoid underground/water
		phase = "MINE",
		plaza_done = false,
		wall_done = false,
		wall_step = 0,
		houses_done = 0,
		members = {}
	}
	return id
end

-- ===========================================================================
-- 3. NPC ENTITY
-- ===========================================================================

minetest.register_entity("condomino:npc_entity", {
	initial_properties = {
		hp_max = 20,
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"character.png"},
		stepheight = 1.1,
		automatic_rotate = 0, -- FIXED: Must be a number (0 = disabled)
		nametag = "",
		nametag_color = {a=255, r=255, g=255, b=255},
		infotext = ""
	},

	name = "",
	colony_id = 0,
	role = "FOLLOWER",
	slot_idx = 0,
	inventory = {},
	target = nil,
	action = "Arriving",
	schema_step = 0,
	plaza_step = 0,
	timer = 0,
	task = "IDLE",
	house_built = false,
	yaw_dir = {x=0, z=0},

	on_activate = function(self, staticdata, dtime)
		self.object:set_acceleration({x=0, y=-9.8, z=0})
		self.object:set_armor_groups({fleshy=100})
		
		if staticdata ~= "" then
			local d = minetest.deserialize(staticdata)
			if d then
				self.name = d.name
				self.colony_id = d.colony_id
				self.role = d.role
				self.slot_idx = d.slot_idx
				self.inventory = d.inventory or {}
				self.task = d.task or "IDLE"
				self.schema_step = d.schema_step or 0
				self.plaza_step = d.plaza_step or 0
				self.timer = d.timer or 0
				self.house_built = d.house_built or false
				self.target = d.target
			end
		end
		
		self.object:set_nametag_attributes({text = self.name})
		local col = condomino.colonies[self.colony_id]
		if col then table.insert(col.members, self) end
	end,

	get_staticdata = function(self)
		return minetest.serialize({
			name = self.name, colony_id = self.colony_id, role = self.role,
			slot_idx = self.slot_idx, inventory = self.inventory,
			task = self.task, schema_step = self.schema_step,
			plaza_step = self.plaza_step, timer = self.timer,
			house_built = self.house_built, target = self.target
		})
	end,

	on_step = function(self, dtime)
		if not self.colony_id then return end
		local col = condomino.colonies[self.colony_id]
		if not col then return end

		self.timer = self.timer + dtime
		self.object:set_properties({infotext = self.action})

		-- Night sleep logic
		local tod = minetest.get_timeofday()
		if self.house_built and (tod < 0.25 or tod > 0.75) and col.phase ~= "MINE" then
			if self.task ~= "SLEEP" then
				self.task = "SLEEP"
				self.action = "Sleeping"
				self.object:set_velocity({x=0, y=0, z=0})
				if self.target then
					self.object:set_pos({x=self.target.x+2, y=self.target.y, z=self.target.z+4})
				end
			end
			return
		end
		if self.task == "SLEEP" and tod >= 0.25 and tod <= 0.75 then
			self.task = "IDLE"
			self.action = "Waking"
		end

		-- Task router
		if self.task == "IDLE" then self:think(col)
		elseif self.task == "WALK" then self:walk(col)
		elseif self.task == "MINE" then self:mine(col)
		elseif self.task == "BUILD" then
			if self.role == "LEADER" and col.phase == "PLAZA" then self:build_plaza(col)
			elseif col.phase == "HOUSES" and not self.house_built then self:build_house(col)
			elseif self.role == "LEADER" and col.phase == "WALL" then self:build_wall(col)
			else self.task = "IDLE"
			end
		elseif self.task == "DEFEND" then self:defend(col)
		end
	end,

	think = function(self, col)
		if col.phase == "MINE" then
			self.target = col.mine_pos
			self.task = "WALK"
			self.action = "Going to mine"
			return
		end

		if col.phase == "PLAZA" and self.role == "LEADER" and not col.plaza_done then
			self.task = "BUILD"
			self.action = "Building plaza"
			self.object:set_pos(col.center)
			self.object:set_velocity({x=0, y=0, z=0})
			return
		end

		if col.phase == "HOUSES" and not self.house_built then
			if self.slot_idx == 0 then self.slot_idx = #col.members end
			local slot = HOUSE_SLOTS[self.slot_idx] or {x=-3, z=-3}
			self.target = {x = col.center.x + slot.x, y = col.center.y, z = col.center.z + slot.z}
			self.task = "BUILD"
			self.action = "Building house"
			self.object:set_velocity({x=0, y=0, z=0})
			return
		end

		if col.phase == "HOUSES" and self.house_built then
			local done = 0
			for _, m in ipairs(col.members) do if m.house_built then done = done + 1 end end
			if done >= #col.members then col.phase = "WALL" end
		end
		if col.phase == "WALL" and self.role == "LEADER" and not col.wall_done then
			self.task = "BUILD"
			self.action = "Building wall"
			self.object:set_pos(col.center)
			self.object:set_velocity({x=0, y=0, z=0})
			return
		end

		if col.wall_done then col.phase = "DONE" end
		if col.phase == "DONE" then
			self.task = "DEFEND"
			self.action = "Patrolling"
			return
		end

		self.task = "IDLE"
		self.action = "Waiting"
		self.object:set_velocity({x=0, y=0, z=0})
	end,

	walk = function(self, col)
		if not self.target then self.task = "IDLE"; return end
		local pos = self.object:get_pos()
		local dist = vector.distance(pos, self.target)
		
		if dist < 1.5 then
			if col.phase == "MINE" then
				self.task = "MINE"
				self.action = "Mining & Gathering"
			else
				self.task = "IDLE"
			end
			self.object:set_velocity({x=0, y=0, z=0})
			return
		end
		
		-- Smooth player-like movement
		local dir = vector.normalize(vector.subtract(self.target, pos))
		self.yaw_dir.x = self.yaw_dir.x * 0.8 + dir.x * 0.2
		self.yaw_dir.z = self.yaw_dir.z * 0.8 + dir.z * 0.2
		self.object:set_yaw(math.atan2(self.yaw_dir.z, self.yaw_dir.x) + math.pi/2)
		
		local vel = self.object:get_velocity()
		local speed = 2.4
		local new_vel = {x = self.yaw_dir.x * speed, y = math.max(vel.y, -10), z = self.yaw_dir.z * speed}
		
		-- Auto-jump if hitting a block ahead
		local ahead = {x = pos.x + dir.x*0.7, y = pos.y + 0.6, z = pos.z + dir.z*0.7}
		if minetest.get_node(ahead).name ~= "air" then new_vel.y = 5.5 end
		
		self.object:set_velocity(new_vel)
	end,

	mine = function(self, col)
		self.object:set_velocity({x=0, y=0, z=0})
		if self.timer < 1.0 then return end
		self.timer = 0
		
		local r = math.random(1,4)
		if r==1 then self.inventory["default:stone"] = (self.inventory["default:stone"] or 0) + 1
		elseif r==2 then self.inventory["default:dirt"] = (self.inventory["default:dirt"] or 0) + 1
		elseif r==3 then self.inventory["default:sand"] = (self.inventory["default:sand"] or 0) + 1
		else self.inventory["default:tree"] = (self.inventory["default:tree"] or 0) + 1 end
		
		if (self.inventory["default:sand"] or 0) > 0 and (self.inventory["default:glass"] or 0) < 12 then
			self.inventory["default:sand"] = self.inventory["default:sand"] - 1
			self.inventory["default:glass"] = (self.inventory["default:glass"] or 0) + 1
		end
		if (self.inventory["default:glass"] or 0) > 0 and (self.inventory["stairs:slab_glass"] or 0) < 12 then
			self.inventory["default:glass"] = self.inventory["default:glass"] - 1
			self.inventory["stairs:slab_glass"] = (self.inventory["stairs:slab_glass"] or 0) + 1
		end
		
		if self:has_materials() then
			if self.role == "LEADER" then
				col.phase = "PLAZA"
				self.task = "IDLE"
				self.action = "Ready for plaza"
			else
				self.target = col.center
				self.task = "WALK"
				self.action = "Returning with materials"
			end
		end
	end,

	build_plaza = function(self, col)
		self.object:set_velocity({x=0, y=0, z=0})
		if self.timer < 0.12 then return end
		self.timer = 0
		
		if self.plaza_step < 625 then
			local x = (self.plaza_step % 25) - 12
			local z = math.floor(self.plaza_step / 25) - 12
			local p = {x = col.center.x + x, y = col.center.y - 1, z = col.center.z + z}
			minetest.set_node(p, {name = "default:stone"})
			minetest.set_node({x=p.x, y=p.y+1, z=p.z}, {name="air"})
			minetest.set_node({x=p.x, y=p.y+2, z=p.z}, {name="air"})
			self.plaza_step = self.plaza_step + 1
		else
			col.plaza_done = true
			col.phase = "HOUSES"
			self.plaza_step = 0
			self.task = "IDLE"
			self.action = "Plaza finished"
		end
	end,

	build_house = function(self, col)
		self.object:set_velocity({x=0, y=0, z=0})
		if self.slot_idx == 0 then self.slot_idx = 1 end
		local slot = HOUSE_SLOTS[self.slot_idx] or {x=-3, z=-3}
		local base = {x = col.center.x + slot.x, y = col.center.y, z = col.center.z + slot.z}
		
		if self.timer < 0.1 then return end
		self.timer = 0
		
		if self.schema_step <= #HOUSE_SCHEMA then
			local item = HOUSE_SCHEMA[self.schema_step]
			local p = {x = base.x + item.x, y = base.y + item.y, z = base.z + item.z}
			
			if (self.inventory[item.name] or 0) > 0 then
				self.inventory[item.name] = self.inventory[item.name] - 1
				local node = {name = item.name, param1 = item.param1, param2 = item.param2}
				minetest.set_node(p, node)
				if item.meta and item.meta.fields then
					local meta = minetest.get_meta(p)
					for k,v in pairs(item.meta.fields) do meta:set_string(k, v) end
				end
				self.schema_step = self.schema_step + 1
			else
				self.task = "WALK"
				self.target = col.mine_pos
				self.action = "Need " .. item.name
			end
		else
			self.house_built = true
			col.houses_done = col.houses_done + 1
			self.schema_step = 1
			self.task = "IDLE"
			self.action = "House complete"
		end
	end,

	build_wall = function(self, col)
		self.object:set_velocity({x=0, y=0, z=0})
		self.action = "Constructing wall"
		if self.timer < 0.04 then return end
		self.timer = 0
		
		local b = {min_x = col.center.x - 14, max_x = col.center.x + 14, min_z = col.center.z - 14, max_z = col.center.z + 14, y = col.center.y}
		local w = b.max_x - b.min_x
		local d = b.max_z - b.min_z
		local perimeter = 2 * (w + d)
		local total = perimeter * 3
		
		if col.wall_step < total then
			local layer = math.floor(col.wall_step / perimeter) + 1
			local seg = col.wall_step % perimeter
			local p
			if seg < w then p = {x = b.min_x + seg, y = b.y + layer, z = b.min_z}
			elseif seg < w + d then p = {x = b.max_x, y = b.y + layer, z = b.min_z + (seg - w)}
			elseif seg < 2*w + d then p = {x = b.max_x - (seg - w - d), y = b.y + layer, z = b.max_z}
			else p = {x = b.min_x, y = b.y + layer, z = b.max_z - (seg - 2*w - d)} end
			
			local is_gate = (layer == 1 and p.z == b.min_z and math.abs(p.x - (b.min_x + w/2)) < 1.5)
			if not is_gate then minetest.set_node(p, {name = "default:stone"}) end
			col.wall_step = col.wall_step + 1
		else
			col.wall_done = true
			self.task = "DEFEND"
			self.action = "Defending colony"
		end
	end,

	defend = function(self, col)
		local pos = self.object:get_pos()
		local b = {min_x=col.center.x-14, max_x=col.center.x+14, min_z=col.center.z-14, max_z=col.center.z+14}
		
		if self.timer > 4.0 then
			self.timer = 0
			self._patrol = {x = math.random(b.min_x, b.max_x), y = b.y + 1, z = math.random(b.min_z, b.max_z)}
		end
		if self._patrol then
			local dir = vector.normalize(vector.subtract(self._patrol, pos))
			local vel = self.object:get_velocity()
			self.yaw_dir.x = dir.x; self.yaw_dir.z = dir.z
			self.object:set_yaw(math.atan2(dir.z, dir.x) + math.pi/2)
			self.object:set_velocity({x = dir.x * 1.8, y = math.max(vel.y, -6), z = dir.z * 1.8})
		end
		
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 5)) do
			if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().type ~= "condomino:npc_entity") then
				self.action = "Defending!"
				obj:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=5}}, nil)
				local dir = vector.normalize(vector.subtract(obj:get_pos(), pos))
				self.object:set_velocity({x = dir.x * 3.5, y = 0, z = dir.z * 3.5})
				return
			end
		end
	end,

	has_materials = function(self)
		for mat, cnt in pairs(REQUIRED_ITEMS) do
			if (self.inventory[mat] or 0) < cnt then return false end
		end
		return true
	end
})

-- ===========================================================================
-- 4. SPAWN BLOCK
-- ===========================================================================

minetest.register_node("condomino:npc", {
	description = "Colony Spawner",
	tiles = {"wool_yellow.png"},
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	is_ground_content = false,
	
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if not pos then return itemstack end
		local node = minetest.get_node(pos)
		if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to then
			return itemstack
		end
		
		local cid = get_active_colony() or create_colony(pos)
		local col = condomino.colonies[cid]
		
		if #col.members >= 10 then
			minetest.chat_send_player(placer:get_player_name(), "Colony full (10 max).")
			return itemstack
		end
		
		local name = "Villager"
		for _, n in ipairs(NAMES) do
			if not condomino.used_names[n] then
				name = n
				condomino.used_names[n] = true
				break
			end
		end
		
		local role = (#col.members == 0) and "LEADER" or "FOLLOWER"
		local ent = minetest.add_entity(pos, "condomino:npc_entity")
		if ent then
			local lua = ent:get_luaentity()
			lua.name = name
			lua.colony_id = cid
			lua.role = role
			lua.inventory = {}
			lua.action = "Arriving"
			lua.task = "WALK"
			lua.target = col.mine_pos
			itemstack:take_item()
		end
		return itemstack
	end
})

minetest.log("action", "[condomino] Mod loaded successfully.")
