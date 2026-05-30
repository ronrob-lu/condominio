condomino = {}
condomino.colonies = {}
condomino.next_colony_id = 1
condomino.used_names = {}

-- --------------------------------------------------------------------------
-- Data
-- --------------------------------------------------------------------------

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

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------

function condomino.get_unique_name()
    for _, name in ipairs(NAMES) do
        if not condomino.used_names[name] then
            condomino.used_names[name] = true
            return name
        end
    end
    return "Villager"
end

function condomino.create_colony(center_pos)
    local id = condomino.next_colony_id
    condomino.next_colony_id = condomino.next_colony_id + 1
    condomino.colonies[id] = {
        id = id,
        center = vector.round(center_pos),
        mine_pos = vector.add(vector.round(center_pos), {x=50, y=0, z=0}),
        phase = "PLAZA",
        plaza_done = false,
        houses_built = 0,
        wall_bounds = nil,
        wall_progress = 0,
        wall_done = false,
        members = {}
    }
    return id
end

function condomino.get_active_colony()
    for id, c in pairs(condomino.colonies) do
        if c.phase ~= "DEFEND" and #c.members < 10 then return id end
    end
    return nil
end

-- --------------------------------------------------------------------------
-- Entity
-- --------------------------------------------------------------------------

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
        automatic_rotate = false,
        nametag = "",
        infotext = "",
    },

    name = "",
    colony_id = 0,
    role = "FOLLOWER",
    plot_idx = 0,
    inventory = {},
    target_pos = nil,
    current_action = "Spawning",
    schema_idx = 1,
    gather_timer = 0,
    move_timer = 0,
    phase_state = "IDLE",
    house_built = false,
    sleep_pos = nil,
    yaw_dir = {x=0, z=0},

    on_activate = function(self, staticdata, dtime)
        self.object:set_acceleration({x=0, y=-9.8, z=0}) -- Real gravity
        self.object:set_armor_groups({fleshy=100})
        
        if staticdata ~= "" then
            local d = minetest.deserialize(staticdata)
            if d then
                self.name = d.name
                self.colony_id = d.colony_id
                self.role = d.role
                self.plot_idx = d.plot_idx
                self.inventory = d.inventory or {}
                self.phase_state = d.phase_state or "IDLE"
                self.schema_idx = d.schema_idx or 1
                self.gather_timer = d.gather_timer or 0
                self.house_built = d.house_built or false
                self.target_pos = d.target_pos
            end
        end
        
        self.object:set_nametag_attributes({text = self.name})
        local col = condomino.colonies[self.colony_id]
        if col then table.insert(col.members, self) end
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            name = self.name, colony_id = self.colony_id, role = self.role,
            plot_idx = self.plot_idx, inventory = self.inventory,
            phase_state = self.phase_state, schema_idx = self.schema_idx,
            gather_timer = self.gather_timer, house_built = self.house_built,
            target_pos = self.target_pos
        })
    end,

    on_step = function(self, dtime)
        if not self.colony_id then return end
        local col = condomino.colonies[self.colony_id]
        if not col then return end

        self.gather_timer = self.gather_timer + dtime
        self.move_timer = self.move_timer + dtime
        
        -- Hover tooltip (infotext shows on mouseover)
        self.object:set_properties({infotext = self.current_action})
        
        -- Sleep at night
        local tod = minetest.get_timeofday()
        if self.house_built and (tod < 0.25 or tod > 0.75) and col.phase ~= "PLAZA" then
            if self.phase_state ~= "SLEEP" then
                self.phase_state = "SLEEP"
                self.current_action = "Sleeping"
                self.object:set_velocity({x=0,y=0,z=0})
            end
            return
        end
        if self.phase_state == "SLEEP" and tod >= 0.25 and tod <= 0.75 then
            self.phase_state = "IDLE"
            self.current_action = "Waking"
        end

        -- Sync with colony phase
        if self.phase_state == "IDLE" or self.phase_state == "WALK" then
            self:sync_phase(col)
        elseif self.phase_state == "WALK" then
            self:handle_movement(col)
        elseif self.phase_state == "MINE" then
            self:handle_mining(col)
        elseif self.phase_state == "PLAZA" then
            self:handle_build_plaza(col)
        elseif self.phase_state == "HOUSE" then
            self:handle_build_house(col)
        elseif self.phase_state == "WALL" then
            self:handle_build_wall(col)
        elseif self.phase_state == "DEFEND" then
            self:handle_defend(col)
        end
    end,

    sync_phase = function(self, col)
        -- Leader handles plaza first
        if col.phase == "PLAZA" and self.role == "LEADER" and not col.plaza_done then
            self.phase_state = "PLAZA"
            self.current_action = "Building plaza"
            self.object:set_pos(col.center)
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        -- Followers go to mine during PLAZA phase
        if col.phase == "PLAZA" and self.role == "FOLLOWER" and not col.plaza_done then
            self.target_pos = col.mine_pos
            self.phase_state = "WALK"
            self.current_action = "Going to mine"
            return
        end
        
        -- Phase transition: PLAZA -> GATHER
        if col.phase == "PLAZA" and col.plaza_done then
            col.phase = "GATHER"
        end
        
        -- Everyone mines in GATHER phase
        if col.phase == "GATHER" and not self:has_materials() then
            self.target_pos = col.mine_pos
            if self.phase_state ~= "MINE" and self.phase_state ~= "WALK" then
                self.phase_state = "WALK"
                self.current_action = "Getting materials"
            end
            return
        end
        
        -- If everyone has materials, move to HOUSE phase
        if col.phase == "GATHER" then
            local all_ready = true
            for _, m in ipairs(col.members) do
                if not m:has_materials() then all_ready = false break end
            end
            if all_ready then
                col.phase = "BUILD_HOUSES"
                -- Assign fixed plot index once
                if self.plot_idx == 0 then
                    self.plot_idx = #col.members
                end
            end
        end
        
        -- Build houses
        if col.phase == "BUILD_HOUSES" and not self.house_built then
            if self.plot_idx == 0 then self.plot_idx = #col.members end
            self.phase_state = "HOUSE"
            self.current_action = "Building house"
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        -- Check if all houses done
        if col.phase == "BUILD_HOUSES" then
            local done = 0
            for _, m in ipairs(col.members) do if m.house_built then done = done + 1 end end
            if done >= #col.members then
                col.phase = "BUILD_WALL"
                col.wall_bounds = self:calc_bounds(col)
                col.wall_progress = 0
            end
        end
        
        -- Build wall
        if col.phase == "BUILD_WALL" and not col.wall_done then
            self.phase_state = "WALL"
            self.current_action = "Building wall"
            return
        end
        
        -- Defend
        if col.wall_done then
            col.phase = "DEFEND"
        end
        if col.phase == "DEFEND" then
            self.phase_state = "DEFEND"
            self.current_action = "Patrolling"
            return
        end
        
        -- Default idle
        self.phase_state = "IDLE"
        self.current_action = "Waiting"
        self.object:set_velocity({x=0,y=0,z=0})
    end,

    handle_movement = function(self, col)
        if not self.target_pos then
            self.phase_state = "IDLE"
            return
        end
        
        local pos = self.object:get_pos()
        local dist = vector.distance(pos, self.target_pos)
        
        if dist < 1.5 then
            if col.phase == "GATHER" then
                self.phase_state = "MINE"
                self.current_action = "Mining"
            else
                self.phase_state = "IDLE"
            end
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        -- Player-like walking physics
        local dir = vector.normalize(vector.subtract(self.target_pos, pos))
        local vel = self.object:get_velocity()
        
        -- Smooth turning
        self.yaw_dir.x = self.yaw_dir.x * 0.8 + dir.x * 0.2
        self.yaw_dir.z = self.yaw_dir.z * 0.8 + dir.z * 0.2
        local yaw = math.atan2(self.yaw_dir.z, self.yaw_dir.x) + math.pi/2
        self.object:set_yaw(yaw)
        
        -- X/Z movement, preserve gravity Y
        local speed = 2.2
        local new_vel = {x = self.yaw_dir.x * speed, y = math.max(vel.y, -6), z = self.yaw_dir.z * speed}
        
        -- Jump if hitting block ahead
        local check_pos = {x=pos.x+dir.x*0.6, y=pos.y+0.5, z=pos.z+dir.z*0.6}
        if minetest.get_node(check_pos).name ~= "air" then
            new_vel.y = 4.5
        end
        
        self.object:set_velocity(new_vel)
    end,

    handle_mining = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        self.current_action = "Mining & Crafting"
        
        if self.gather_timer > 1.2 then
            self.gather_timer = 0
            -- Simulate mining + crafting cycle
            local mats = {"default:stone", "default:dirt", "default:sand", "default:tree"}
            local got = mats[math.random(#mats)]
            self.inventory[got] = (self.inventory[got] or 0) + 1
            
            -- Auto-crafting simulation
            if self.inventory["default:sand"] and not self.inventory["default:glass"] then
                self.inventory["default:sand"] = self.inventory["default:sand"] - 1
                self.inventory["default:glass"] = (self.inventory["default:glass"] or 0) + 1
            end
            if self.inventory["default:glass"] and not self.inventory["stairs:slab_glass"] then
                self.inventory["default:glass"] = self.inventory["default:glass"] - 1
                self.inventory["stairs:slab_glass"] = (self.inventory["stairs:slab_glass"] or 0) + 1
            end
            
            if self:has_materials() and col.phase ~= "PLAZA" then
                self.phase_state = "IDLE"
                self.current_action = "Materials ready"
            end
        end
    end,

    handle_build_plaza = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if self.gather_timer < 0.25 then return end
        self.gather_timer = 0
        
        if not self.plaza_idx then self.plaza_idx = 1 end
        
        if self.plaza_idx <= 25 then
            local x_off = ((self.plaza_idx-1) % 5) - 2
            local z_off = math.floor((self.plaza_idx-1) / 5) - 2
            local p = {x=col.center.x+x_off, y=col.center.y-1, z=col.center.z+z_off}
            minetest.set_node(p, {name="default:stone"})
            minetest.set_node({x=p.x,y=p.y+1,z=p.z}, {name="air"})
            minetest.set_node({x=p.x,y=p.y+2,z=p.z}, {name="air"})
            self.plaza_idx = self.plaza_idx + 1
        else
            col.plaza_done = true
            self.plaza_idx = nil
            self.phase_state = "IDLE"
            self.current_action = "Plaza finished"
        end
    end,

    handle_build_house = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if self.plot_idx == 0 then self.plot_idx = 1 end
        
        -- Calculate house origin from fixed plot index
        local side = math.floor((self.plot_idx-1) / 4)
        local pos_in_side = (self.plot_idx-1) % 4
        local offset = 4 + (pos_in_side * 6)
        local base
        if side == 0 then base = {x=col.center.x+offset, y=col.center.y, z=col.center.z}
        elseif side == 1 then base = {x=col.center.x-offset, y=col.center.y, z=col.center.z}
        elseif side == 2 then base = {x=col.center.x, y=col.center.y, z=col.center.z+offset}
        else base = {x=col.center.x, y=col.center.y, z=col.center.z-offset}
        end
        
        if self.gather_timer < 0.12 then return end
        self.gather_timer = 0
        
        if self.schema_idx <= #HOUSE_SCHEMA then
            local item = HOUSE_SCHEMA[self.schema_idx]
            local p = {x=base.x+item.x, y=base.y+item.y, z=base.z+item.z}
            local mat = item.name
            
            -- Consume material
            if self.inventory[mat] and self.inventory[mat] > 0 then
                self.inventory[mat] = self.inventory[mat] - 1
                local node = {name=mat, param1=item.param1, param2=item.param2}
                minetest.set_node(p, node)
                if item.meta and item.meta.fields then
                    local meta = minetest.get_meta(p)
                    for k,v in pairs(item.meta.fields) do meta:set_string(k,v) end
                end
                self.schema_idx = self.schema_idx + 1
            else
                self.phase_state = "IDLE"
                self.current_action = "Missing "..mat
                -- Return to mine logic handled in sync_phase
            end
        else
            self.house_built = true
            col.houses_built = col.houses_built + 1
            self.phase_state = "IDLE"
            self.current_action = "House complete"
            self.schema_idx = 1
        end
    end,

    handle_build_wall = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        self.current_action = "Constructing wall"
        
        if self.gather_timer < 0.06 then return end
        self.gather_timer = 0
        
        local b = col.wall_bounds
        local w = b.max_x - b.min_x
        local d = b.max_z - b.min_z
        local perimeter = 2 * (w + d)
        local total = perimeter * 3
        
        if col.wall_progress < total then
            local layer = math.floor(col.wall_progress / perimeter) + 1
            local seg = col.wall_progress % perimeter
            local p
            if seg < w then
                p = {x=b.min_x+seg, y=b.y+layer, z=b.min_z}
            elseif seg < w+d then
                p = {x=b.max_x, y=b.y+layer, z=b.min_z+(seg-w)}
            elseif seg < 2*w+d then
                p = {x=b.max_x-(seg-w-d), y=b.y+layer, z=b.max_z}
            else
                p = {x=b.min_x, y=b.y+layer, z=b.max_z-(seg-2*w-d)}
            end
            
            -- 2-block wide entrance at front center, ground layer only
            local is_gate = (layer == 1 and p.z == b.min_z and math.abs(p.x - (b.min_x + w/2)) < 1.5)
            if not is_gate then minetest.set_node(p, {name="default:stone"}) end
            
            col.wall_progress = col.wall_progress + 1
        else
            col.wall_done = true
            self.phase_state = "DEFEND"
            self.current_action = "Defending colony"
            col.wall_progress = 0
        end
    end,

    handle_defend = function(self, col)
        if not col.wall_bounds then return end
        local pos = self.object:get_pos()
        local b = col.wall_bounds
        
        -- Patrol
        if self.move_timer > 3.5 then
            self.move_timer = 0
            self._patrol_target = {
                x = math.random(b.min_x+1, b.max_x-1),
                y = b.y + 1,
                z = math.random(b.min_z+1, b.max_z-1)
            }
        end
        if self._patrol_target then
            local dir = vector.normalize(vector.subtract(self._patrol_target, pos))
            local vel = self.object:get_velocity()
            self.yaw_dir.x = dir.x; self.yaw_dir.z = dir.z
            self.object:set_yaw(math.atan2(dir.z, dir.x) + math.pi/2)
            self.object:set_velocity({x=dir.x*1.8, y=math.max(vel.y, -5), z=dir.z*1.8})
        end
        
        -- Attack intruders
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 5)) do
            if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().type ~= "condomino:npc_entity") then
                self.current_action = "Defending!"
                obj:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=5}}, nil)
                local dir = vector.normalize(vector.subtract(obj:get_pos(), pos))
                self.object:set_velocity({x=dir.x*3.5, y=0, z=dir.z*3.5})
                return
            end
        end
    end,

    has_materials = function(self)
        for mat, cnt in pairs(REQUIRED_ITEMS) do
            if (self.inventory[mat] or 0) < cnt then return false end
        end
        return true
    end,

    calc_bounds = function(self, col)
        local minx, maxx, minz, maxz = 9999, -9999, 9999, -9999
        for _, m in ipairs(col.members) do
            if m.plot_idx then
                local side = math.floor((m.plot_idx-1)/4)
                local pos_in_side = (m.plot_idx-1)%4
                local off = 4 + (pos_in_side*6)
                if side==0 then minx = math.min(minx, col.center.x+off)
                elseif side==1 then maxx = math.max(maxx, col.center.x-off)
                elseif side==2 then minz = math.min(minz, col.center.z+off)
                else maxz = math.max(maxz, col.center.z-off) end
            end
        end
        return {min_x=minx-2, max_x=maxx+2, min_z=minz-2, max_z=maxz+2, y=col.center.y}
    end
})

-- --------------------------------------------------------------------------
-- Spawn Node
-- --------------------------------------------------------------------------

minetest.register_node("condomino:npc", {
    description = "Colony Spawner",
    tiles = {"wool_yellow.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3},
    is_ground_content = false,
    
    on_place = function(itemstack, placer, pointed_thing)
        local pos = pointed_thing.above
        if not pos then return itemstack end
        local node = minetest.get_node(pos)
        if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to then
            return itemstack
        end
        
        local cid = condomino.get_active_colony() or condomino.create_colony(pos)
        local col = condomino.colonies[cid]
        
        if #col.members >= 10 then
            minetest.chat_send_player(placer:get_player_name(), "Colony reached maximum size (10).")
            return itemstack
        end
        
        local name = condomino.get_unique_name()
        local role = (#col.members == 0) and "LEADER" or "FOLLOWER"
        local ent = minetest.add_entity(pos, "condomino:npc_entity")
        if ent then
            local lua = ent:get_luaentity()
            lua.name = name
            lua.colony_id = cid
            lua.role = role
            lua.inventory = {}
            lua.current_action = "Arriving"
            
            if role == "LEADER" then
                lua.phase_state = "PLAZA"
                lua.current_action = "Starting plaza"
            else
                lua.target_pos = col.mine_pos
                lua.phase_state = "WALK"
                lua.current_action = "Going to mine"
            end
            itemstack:take_item()
        end
        return itemstack
    end
})

minetest.log("action", "[condomino] Mod loaded successfully.")
