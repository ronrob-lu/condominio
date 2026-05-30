condomino = {}
condomino.colonies = {}
condomino.next_colony_id = 1
condomino.used_names = {} -- Global tracker for unique names

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

function condomino.distance(pos1, pos2)
    return vector.distance(pos1, pos2)
end

-- --------------------------------------------------------------------------
-- Colony Logic
-- --------------------------------------------------------------------------

function condomino.create_colony(center_pos)
    local id = condomino.next_colony_id
    condomino.next_colony_id = condomino.next_colony_id + 1
    
    condomino.colonies[id] = {
        id = id,
        center = center_pos,
        mine_pos = vector.add(center_pos, {x=50, y=0, z=0}),
        state = "INIT", 
        members = {},
        houses_built = 0,
        plaza_built = false,
        wall_built = false,
        wall_bounds = nil,
        wall_progress = 0
    }
    return id
end

function condomino.get_active_colony()
    for id, col in pairs(condomino.colonies) do
        if col.state ~= "DEFEND" and #col.members < 10 then
            return id
        end
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
        collisionbox = {-0.3, -0.5, -0.3, 0.3, 1.7, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        stepheight = 1.1,
        nametag = "",
    },

    name = "",
    colony_id = 0,
    role = "FOLLOWER",
    state = "IDLE",
    inventory = {},
    target_pos = nil,
    timer = 0,
    current_action = "Spawning",
    house_pos = nil,
    schema_idx = 1,
    build_idx = 1,
    
    on_activate = function(self, staticdata, dtime_s)
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self.name = data.name
                self.colony_id = data.colony_id
                self.role = data.role
                self.inventory = data.inventory or {}
                self.state = data.state or "IDLE"
                self.house_pos = data.house_pos
                self.schema_idx = data.schema_idx or 1
                self.build_idx = data.build_idx or 1
            end
        end
        
        if self.name then
            self.object:set_nametag_attributes({text = self.name})
        end
        
        local col = condomino.colonies[self.colony_id]
        if col then
            table.insert(col.members, self)
        end
        
        self.object:set_armor_groups({fleshy=100})
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            name = self.name,
            colony_id = self.colony_id,
            role = self.role,
            inventory = self.inventory,
            state = self.state,
            house_pos = self.house_pos,
            schema_idx = self.schema_idx,
            build_idx = self.build_idx
        })
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        
        local pos = self.object:get_pos()
        local col = condomino.colonies[self.colony_id]
        
        if not col then return end

        -- Update Tooltip
        self.object:set_nametag_attributes({text = self.name .. "\n" .. self.current_action})

        -- State Machine
        if self.state == "IDLE" then
            self:determine_next_task(col)
            
        elseif self.state == "MOVING" then
            self:handle_movement(dtime, pos)
            
        elseif self.state == "MINING" then
            self:handle_mining(dtime, pos, col)
            
        elseif self.state == "BUILDING_PLAZA" then
            self:handle_build_plaza(dtime, pos, col)
            
        elseif self.state == "BUILDING_HOUSE" then
            self:handle_build_house(dtime, pos, col)
            
        elseif self.state == "BUILDING_WALL" then
            self:handle_build_wall(dtime, pos, col)
            
        elseif self.state == "DEFEND" then
            self:handle_defend(dtime, pos, col)
            
        elseif self.state == "SLEEPING" then
            local time = minetest.get_timeofday()
            if time > 0.2 and time < 0.8 then
                self.state = "IDLE"
                self.current_action = "Waking up"
            end
        end
    end,

    determine_next_task = function(self, col)
        local time = minetest.get_timeofday()
        -- Sleep logic
        if (time > 0.8 or time < 0.2) and self.house_pos and col.state ~= "INIT" then
            self.state = "SLEEPING"
            self.current_action = "Sleeping"
            local bed_pos = {x=self.house_pos.x+2, y=self.house_pos.y, z=self.house_pos.z+4}
            self.object:set_pos(bed_pos)
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end

        if col.state == "INIT" or col.state == "PLAZA" then
            if self.role == "LEADER" then
                if not col.plaza_built then
                    self.state = "MOVING"
                    self.target_pos = col.center
                    self.current_action = "Building Plaza"
                else
                    self.state = "BUILDING_HOUSE"
                    self.current_action = "Building House"
                end
            else
                if not col.mine_pos then
                     col.mine_pos = vector.add(col.center, {x=50, y=0, z=0})
                end
                self.state = "MOVING"
                self.target_pos = col.mine_pos
                self.current_action = "Going to Mine"
            end
            
        elseif col.state == "BUILDING" then
            if not self.house_built then
                self.state = "BUILDING_HOUSE"
                self.current_action = "Building House"
            else
                if col.houses_built >= #col.members then
                    col.state = "WALL"
                end
                self.state = "IDLE" 
                self.current_action = "Waiting"
            end
            
        elseif col.state == "WALL" then
             if not col.wall_built then
                 self.state = "BUILDING_WALL"
                 self.current_action = "Building Wall"
             else
                 col.state = "DEFEND"
                 self.state = "DEFEND"
                 self.current_action = "Defending"
             end
             
        elseif col.state == "DEFEND" then
            self.state = "DEFEND"
            self.current_action = "Patrolling"
        end
    end,

    handle_movement = function(self, dtime, pos)
        if not self.target_pos then
            self.state = "IDLE"
            return
        end
        
        local dist = condomino.distance(pos, self.target_pos)
        if dist < 1.5 then
            self.state = "IDLE"
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        local dir = vector.normalize(vector.subtract(self.target_pos, pos))
        local vel = {x=dir.x*2, y=0, z=dir.z*2}
        
        -- Simple jump
        local node_below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
        if node_below == "air" then
             vel.y = -5
        elseif minetest.get_node({x=pos.x+dir.x, y=pos.y, z=pos.z+dir.z}).name ~= "air" then
             vel.y = 3
        end
        
        self.object:set_velocity(vel)
        local yaw = math.atan2(dir.z, dir.x) + math.pi/2
        self.object:set_yaw(yaw)
    end,

    handle_mining = function(self, dtime, pos, col)
        if condomino.distance(pos, col.mine_pos) > 5 then
            self.state = "MOVING"
            self.target_pos = col.mine_pos
            return
        end
        
        self.current_action = "Mining"
        self.object:set_velocity({x=0,y=0,z=0})
        
        if self.timer > 2 then
            self.timer = 0
            local r = math.random(1,3)
            if r==1 then self:add_item("default:stone")
            elseif r==2 then self:add_item("default:dirt")
            else self:add_item("default:sand")
            end
            
            -- Followers return to build phase after some mining
            if self.role ~= "LEADER" and col.plaza_built then
                 self.state = "IDLE"
            end
        end
    end,

    handle_build_plaza = function(self, dtime, pos, col)
        if self.role ~= "LEADER" then self.state = "IDLE"; return end
        
        self.current_action = "Building Plaza"
        self.object:set_velocity({x=0,y=0,z=0})
        
        if self.timer > 0.2 then
            self.timer = 0
            
            if not self.build_idx then self.build_idx = 1 end
            
            local c = col.center
            local x_off = ((self.build_idx-1) % 5) - 2
            local z_off = (math.floor((self.build_idx-1) / 5)) - 2
            
            if self.build_idx <= 25 then
                local p = {x=c.x+x_off, y=c.y-1, z=c.z+z_off}
                minetest.set_node(p, {name="default:stone"})
                minetest.set_node({x=p.x, y=p.y+1, z=p.z}, {name="air"})
                minetest.set_node({x=p.x, y=p.y+2, z=p.z}, {name="air"})
                self.build_idx = self.build_idx + 1
            else
                col.plaza_built = true
                col.state = "BUILDING"
                self.state = "IDLE"
                self.build_idx = nil
            end
        end
    end,

    handle_build_house = function(self, dtime, pos, col)
        self.current_action = "Building House"
        self.object:set_velocity({x=0,y=0,z=0})
        
        if not self.house_pos then
            local idx = #col.members
            local side = math.floor((idx-1) / 4)
            local pos_in_side = (idx-1) % 4
            local offset = 4 + (pos_in_side * 6)
            
            if side == 0 then self.house_pos = vector.add(col.center, {x=offset, y=0, z=0})
            elseif side == 1 then self.house_pos = vector.add(col.center, {x=-offset, y=0, z=0})
            elseif side == 2 then self.house_pos = vector.add(col.center, {x=0, y=0, z=offset})
            else self.house_pos = vector.add(col.center, {x=0, y=0, z=-offset})
            end
        end
        
        if self.timer > 0.1 then
            self.timer = 0
            
            if self.schema_idx <= #HOUSE_SCHEMA then
                local item = HOUSE_SCHEMA[self.schema_idx]
                
                -- Simulate having materials (Creative mode for NPCs to prevent stuck state)
                -- Or check inventory. For stability, we assume they have it if they are in this state.
                local abs_pos = {
                    x = self.house_pos.x + item.x,
                    y = self.house_pos.y + item.y,
                    z = self.house_pos.z + item.z
                }
                
                local node = {name=item.name, param1=item.param1, param2=item.param2}
                if item.meta then
                    minetest.set_node(abs_pos, node)
                    local meta = minetest.get_meta(abs_pos)
                    for k,v in pairs(item.meta.fields) do meta:set_string(k,v) end
                else
                    minetest.set_node(abs_pos, node)
                end
                
                self.schema_idx = self.schema_idx + 1
            else
                self.house_built = true
                col.houses_built = col.houses_built + 1
                self.state = "IDLE"
                self.current_action = "House Done"
                self.schema_idx = 1
            end
        end
    end,

    handle_build_wall = function(self, dtime, pos, col)
        self.current_action = "Building Wall"
        self.object:set_velocity({x=0,y=0,z=0})
        
        if not col.wall_bounds then
            local min_x, max_x, min_z, max_z = 9999, -9999, 9999, -9999
            for _, m in ipairs(col.members) do
                if m.house_pos then
                    if m.house_pos.x < min_x then min_x = m.house_pos.x end
                    if m.house_pos.x > max_x then max_x = m.house_pos.x end
                    if m.house_pos.z < min_z then min_z = m.house_pos.z end
                    if m.house_pos.z > max_z then max_z = m.house_pos.z end
                end
            end
            col.wall_bounds = {
                min_x = min_x - 4,
                max_x = max_x + 4,
                min_z = min_z - 4,
                max_z = max_z + 4,
                y = col.center.y
            }
            col.wall_progress = 0
        end
        
        if self.timer > 0.05 then
            self.timer = 0
            
            local b = col.wall_bounds
            local p = col.wall_progress
            
            local width = b.max_x - b.min_x
            local depth = b.max_z - b.min_z
            local total = 2 * (width + depth) * 3
            
            if p < total then
                local layer = math.floor(p / (2*(width+depth))) + 1
                local rem = p % (2*(width+depth))
                
                local pos_to_build = nil
                
                if rem < width then
                    pos_to_build = {x=b.min_x + rem, y=b.y + layer, z=b.min_z}
                elseif rem < width + depth then
                    pos_to_build = {x=b.max_x, y=b.y + layer, z=b.min_z + (rem-width)}
                elseif rem < 2*width + depth then
                    pos_to_build = {x=b.max_x - (rem-(width+depth)), y=b.y + layer, z=b.max_z}
                else
                    pos_to_build = {x=b.min_x, y=b.y + layer, z=b.max_z - (rem-(2*width+depth))}
                end
                
                local is_entrance = false
                if layer == 1 and math.abs(pos_to_build.x - (b.min_x + width/2)) < 1 and pos_to_build.z == b.min_z then
                    is_entrance = true
                end
                
                if not is_entrance then
                    minetest.set_node(pos_to_build, {name="default:stone"})
                end
                
                col.wall_progress = p + 1
            else
                col.wall_built = true
                col.state = "DEFEND"
                self.state = "DEFEND"
            end
        end
    end,

    handle_defend = function(self, dtime, pos, col)
        self.current_action = "Patrolling"
        
        if col.wall_bounds then
            local b = col.wall_bounds
            if pos.x >= b.min_x and pos.x <= b.max_x and pos.z >= b.min_z and pos.z <= b.max_z then
                local objects = minetest.get_objects_inside_radius(pos, 5)
                for _, obj in ipairs(objects) do
                    if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().type ~= "condomino:npc_entity") then
                        self.current_action = "Attacking!"
                        obj:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=5}}, nil)
                        local dir = vector.normalize(vector.subtract(obj:get_pos(), pos))
                        self.object:set_velocity({x=dir.x*3, y=0, z=dir.z*3})
                        return
                    end
                end
            end
        end
        
        if self.timer > 5 then
            self.timer = 0
            if col.wall_bounds then
                local rx = math.random(col.wall_bounds.min_x, col.wall_bounds.max_x)
                local rz = math.random(col.wall_bounds.min_z, col.wall_bounds.max_z)
                self.target_pos = {x=rx, y=col.center.y, z=rz}
                self.state = "MOVING"
            end
        end
    end,

    add_item = function(self, name)
        self.inventory[name] = (self.inventory[name] or 0) + 1
    end,
})

-- --------------------------------------------------------------------------
-- Spawn Node
-- --------------------------------------------------------------------------

minetest.register_node("condomino:npc", {
    description = "NPC Spawner",
    tiles = {"wool_yellow.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3},
    
    on_place = function(itemstack, placer, pointed_thing)
        local pos = pointed_thing.above
        if not pos then return itemstack end
        
        local node = minetest.get_node(pos)
        if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to then
            return itemstack
        end
        
        local col_id = condomino.get_active_colony()
        if not col_id then
            col_id = condomino.create_colony(pos)
        end
        
        local col = condomino.colonies[col_id]
        
        if #col.members >= 10 then
            minetest.chat_send_player(placer:get_player_name(), "Colony full.")
            return itemstack
        end
        
        local name = condomino.get_unique_name()
        local role = (#col.members == 0) and "LEADER" or "FOLLOWER"
        
        local entity = minetest.add_entity(pos, "condomino:npc_entity")
        if entity then
            local luaent = entity:get_luaentity()
            luaent.name = name
            luaent.colony_id = col_id
            luaent.role = role
            luaent.inventory = {}
            
            if role == "LEADER" then
                luaent.state = "BUILDING_PLAZA"
                luaent.current_action = "Starting Plaza"
                col.state = "PLAZA"
            else
                luaent.state = "MOVING"
                luaent.target_pos = col.mine_pos
                luaent.current_action = "Going to Mine"
            end
            
            itemstack:take_item()
        end
        
        return itemstack
    end
})
