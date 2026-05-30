condomino = {}
condomino.colonies = {}
condomino.next_colony_id = 1
condomino.used_names = {}

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

-- Material requirements per house (simplified)
local HOUSE_MATERIALS = {
    ["default:dirt"] = 20,
    ["stairs:slab_glass"] = 12,
    ["default:chest"] = 1,
    ["beds:bed_top"] = 1,
    ["beds:bed_bottom"] = 1,
    ["default:torch_wall"] = 1
}

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
        state = "PLAZA",
        members = {},
        plaza_done = false,
        houses_done = 0,
        wall_done = false,
        wall_bounds = nil,
        wall_idx = 0
    }
    return id
end

minetest.register_entity("condomino:npc_entity", {
    initial_properties = {
        hp_max = 20,
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        stepheight = 1.1,
        automatic_rotate = false,
        nametag = "",
    },

    on_activate = function(self, staticdata, dtime)
        self.object:set_acceleration({x=0, y=-9.8, z=0}) -- Gravity!
        self.object:set_armor_groups({fleshy=100})
        
        if staticdata ~= "" then
            local d = minetest.deserialize(staticdata)
            if d then
                self.name = d.name
                self.colony_id = d.colony_id
                self.role = d.role
                self.plot_idx = d.plot_idx
                self.inventory = d.inventory or {}
                self.state = d.state or "IDLE"
                self.target = d.target
                self.schema_i = d.schema_i or 1
                self.plaza_i = d.plaza_i or 1
            end
        end
        
        if self.name then
            self.object:set_nametag_attributes({text = self.name})
        end
        
        local col = condomino.colonies[self.colony_id]
        if col then table.insert(col.members, self) end
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            name = self.name, colony_id = self.colony_id, role = self.role,
            plot_idx = self.plot_idx, inventory = self.inventory,
            state = self.state, target = self.target,
            schema_i = self.schema_i, plaza_i = self.plaza_i
        })
    end,

    on_step = function(self, dtime)
        if not self.colony_id then return end
        local col = condomino.colonies[self.colony_id]
        if not col then return end
        
        self._timer = (self._timer or 0) + dtime
        self.object:set_nametag_attributes({text = self.name.."\n"..(self.action or "Idle")})
        
        -- Sleep at night
        local tod = minetest.get_timeofday()
        if self.house_built and (tod < 0.25 or tod > 0.75) and col.state ~= "PLAZA" then
            if self.state ~= "SLEEP" then
                self.state = "SLEEP"
                self.action = "Sleeping"
                self.object:set_velocity({x=0,y=0,z=0})
            end
            return
        end
        if self.state == "SLEEP" and tod >= 0.25 and tod <= 0.75 then
            self.state = "IDLE"
            self.action = "Waking"
        end
        
        -- State machine
        if self.state == "IDLE" then self:think(col)
        elseif self.state == "MOVE" then self:move_to(col)
        elseif self.state == "MINE" then self:mine(col)
        elseif self.state == "PLAZA" then self:build_plaza(col)
        elseif self.state == "HOUSE" then self:build_house(col)
        elseif self.state == "WALL" then self:build_wall(col)
        elseif self.state == "DEFEND" then self:defend(col)
        end
    end,

    think = function(self, col)
        -- Leader builds plaza first
        if self.role == "LEADER" and col.state == "PLAZA" and not col.plaza_done then
            self.state = "PLAZA"
            self.action = "Building plaza"
            self.object:set_pos(col.center)
            return
        end
        
        -- Everyone mines if plaza not done (followers) or if lacking materials
        if not col.plaza_done and self.role ~= "LEADER" then
            self.state = "MOVE"
            self.target = col.mine_pos
            self.action = "Going to mine"
            return
        end
        
        -- Check materials for house
        if col.plaza_done and not self.house_built then
            local need = false
            for mat, cnt in pairs(HOUSE_MATERIALS) do
                if (self.inventory[mat] or 0) < cnt then need = true break end
            end
            if need then
                self.state = "MOVE"
                self.target = col.mine_pos
                self.action = "Getting materials"
                return
            end
            -- Assign plot ONCE when ready to build
            if not self.plot_idx then
                self.plot_idx = #col.members  -- Fixed index at assignment time
            end
            self.state = "HOUSE"
            self.action = "Building house"
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        -- Wall phase
        if self.house_built and col.plaza_done and not col.wall_done then
            -- Count done houses
            local done = 0
            for _, m in ipairs(col.members) do if m.house_built then done = done + 1 end end
            if done >= #col.members then
                col.state = "WALL"
                col.wall_bounds = self:calc_wall_bounds(col)
            end
        end
        
        if col.state == "WALL" and not col.wall_done then
            self.state = "WALL"
            self.action = "Building wall"
            return
        end
        
        -- Defend
        if col.wall_done then
            self.state = "DEFEND"
            self.action = "Patrolling"
            return
        end
        
        -- Idle wait
        self.action = "Waiting"
        self.object:set_velocity({x=0,y=0,z=0})
    end,

    move_to = function(self, col)
        if not self.target then self.state = "IDLE"; return end
        local pos = self.object:get_pos()
        local dist = vector.distance(pos, self.target)
        
        if dist < 2 then
            if self.state == "MOVE" and self.target == col.mine_pos then
                self.state = "MINE"
                self.action = "Mining"
            else
                self.state = "IDLE"
            end
            self.object:set_velocity({x=0,y=0,z=0})
            return
        end
        
        local dir = vector.normalize(vector.subtract(self.target, pos))
        -- Move on XZ plane, let gravity handle Y
        local vel = self.object:get_velocity()
        self.object:set_velocity({x=dir.x*2.5, y=vel.y, z=dir.z*2.5})
        -- Face direction
        local yaw = math.atan2(dir.z, dir.x) + math.pi/2
        self.object:set_yaw(yaw)
    end,

    mine = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if self._timer < 1.5 then return end
        self._timer = 0
        
        -- Add random materials
        local mats = {"default:stone", "default:dirt", "default:sand", "default:tree"}
        local got = mats[math.random(#mats)]
        self.inventory[got] = (self.inventory[got] or 0) + 1
        
        -- Simple crafting simulation
        if got == "default:sand" and (self.inventory["default:glass"] or 0) < 12 then
            self.inventory["default:sand"] = self.inventory["default:sand"] - 1
            self.inventory["default:glass"] = (self.inventory["default:glass"] or 0) + 1
        end
        if self.inventory["default:glass"] and (self.inventory["stairs:slab_glass"] or 0) < 12 then
            self.inventory["default:glass"] = self.inventory["default:glass"] - 1
            self.inventory["stairs:slab_glass"] = (self.inventory["stairs:slab_glass"] or 0) + 1
        end
        
        -- Check if we have enough
        local ready = true
        for mat, cnt in pairs(HOUSE_MATERIALS) do
            if (self.inventory[mat] or 0) < cnt then ready = false break end
        end
        if ready and col.plaza_done then
            self.state = "IDLE"
            self.action = "Got materials"
        end
    end,

    build_plaza = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if self._timer < 0.3 then return end
        self._timer = 0
        
        if self.plaza_i <= 25 then
            local x_off = ((self.plaza_i-1) % 5) - 2
            local z_off = math.floor((self.plaza_i-1) / 5) - 2
            local p = {x=col.center.x+x_off, y=col.center.y-1, z=col.center.z+z_off}
            minetest.set_node(p, {name="default:stone"})
            minetest.set_node({x=p.x,y=p.y+1,z=p.z}, {name="air"})
            minetest.set_node({x=p.x,y=p.y+2,z=p.z}, {name="air"})
            self.plaza_i = self.plaza_i + 1
        else
            col.plaza_done = true
            col.state = "BUILD"
            self.state = "IDLE"
            self.action = "Plaza done"
            self.plaza_i = 1
        end
    end,

    build_house = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if not self.plot_idx then self.plot_idx = 1 end
        
        -- Calculate house position based on FIXED plot_idx
        local side = math.floor((self.plot_idx-1) / 4)
        local pos_in_side = (self.plot_idx-1) % 4
        local offset = 4 + (pos_in_side * 6)
        local base
        if side == 0 then base = {x=col.center.x+offset, y=col.center.y, z=col.center.z}
        elseif side == 1 then base = {x=col.center.x-offset, y=col.center.y, z=col.center.z}
        elseif side == 2 then base = {x=col.center.x, y=col.center.y, z=col.center.z+offset}
        else base = {x=col.center.x, y=col.center.y, z=col.center.z-offset}
        end
        
        if self._timer < 0.15 then return end
        self._timer = 0
        
        if self.schema_i <= #HOUSE_SCHEMA then
            local item = HOUSE_SCHEMA[self.schema_i]
            local p = {x=base.x+item.x, y=base.y+item.y, z=base.z+item.z}
            
            -- Consume material
            local mat = item.name
            if self.inventory[mat] and self.inventory[mat] > 0 then
                self.inventory[mat] = self.inventory[mat] - 1
                local node = {name=mat, param1=item.param1, param2=item.param2}
                minetest.set_node(p, node)
                if item.meta and item.meta.fields then
                    local meta = minetest.get_meta(p)
                    for k,v in pairs(item.meta.fields) do meta:set_string(k,v) end
                end
                self.schema_i = self.schema_i + 1
            else
                -- Missing material! Go mine
                self.state = "MOVE"
                self.target = col.mine_pos
                self.action = "Need "..mat
                return
            end
        else
            self.house_built = true
            col.houses_done = (col.houses_done or 0) + 1
            self.state = "IDLE"
            self.action = "House done"
            self.schema_i = 1
        end
    end,

    build_wall = function(self, col)
        self.object:set_velocity({x=0,y=0,z=0})
        if not col.wall_bounds then col.wall_bounds = self:calc_wall_bounds(col) end
        if self._timer < 0.08 then return end
        self._timer = 0
        
        local b = col.wall_bounds
        local w = b.max_x - b.min_x
        local d = b.max_z - b.min_z
        local perimeter = 2 * (w + d)
        local total = perimeter * 3  -- 3 layers
        
        if col.wall_idx < total then
            local layer = math.floor(col.wall_idx / perimeter) + 1
            local seg = col.wall_idx % perimeter
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
            -- Gate: 2 blocks wide at front center, layer 1 only
            local gate = (layer==1 and p.z==b.min_z and math.abs(p.x-(b.min_x+w/2))<1.5)
            if not gate then minetest.set_node(p, {name="default:stone"}) end
            col.wall_idx = col.wall_idx + 1
        else
            col.wall_done = true
            col.state = "DEFEND"
            self.state = "DEFEND"
            self.action = "Defending"
            col.wall_idx = 0
        end
    end,

    defend = function(self, col)
        if not col.wall_bounds then return end
        local pos = self.object:get_pos()
        local b = col.wall_bounds
        
        -- Patrol randomly inside bounds
        if self._timer > 4 and (not self._patrol_target or vector.distance(pos, self._patrol_target) < 2) then
            self._timer = 0
            self._patrol_target = {
                x = math.random(b.min_x, b.max_x),
                y = b.y,
                z = math.random(b.min_z, b.max_z)
            }
        end
        if self._patrol_target then
            local dir = vector.normalize(vector.subtract(self._patrol_target, pos))
            self.object:set_velocity({x=dir.x*1.5, y=self.object:get_velocity().y, z=dir.z*1.5})
            self.object:set_yaw(math.atan2(dir.z, dir.x) + math.pi/2)
        end
        
        -- Attack intruders
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 4)) do
            if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().type ~= "condomino:npc_entity") then
                self.action = "Attacking!"
                obj:punch(self.object, 1, {full_punch_interval=1, damage_groups={fleshy=4}}, nil)
                local dir = vector.normalize(vector.subtract(obj:get_pos(), pos))
                self.object:set_velocity({x=dir.x*3, y=0, z=dir.z*3})
                return
            end
        end
    end,

    calc_wall_bounds = function(self, col)
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
        return {min_x=minx-3, max_x=maxx+3, min_z=minz-3, max_z=maxz+3, y=col.center.y}
    end,

    add_item = function(self, name)
        self.inventory[name] = (self.inventory[name] or 0) + 1
    end,
})

minetest.register_node("condomino:npc", {
    description = "Colony Spawner",
    tiles = {"wool_yellow.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3},
    on_place = function(itemstack, placer, pointed_thing)
        local pos = pointed_thing.above
        if not pos or not minetest.get_node(pos).name:match("air") then return itemstack end
        
        local cid = condomino.get_active_colony() or condomino.create_colony(pos)
        local col = condomino.colonies[cid]
        if #col.members >= 10 then
            minetest.chat_send_player(placer:get_player_name(), "Colony full (10)")
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
            lua.action = "Spawning"
            if role == "LEADER" then
                lua.state = "PLAZA"
                lua.action = "Starting plaza"
            else
                lua.state = "MOVE"
                lua.target = col.mine_pos
                lua.action = "Going to mine"
            end
            itemstack:take_item()
        end
        return itemstack
    end,
})

-- Helper: find active colony
function condomino.get_active_colony()
    for id, c in pairs(condomino.colonies) do
        if c.state ~= "DEFEND" and #c.members < 10 then return id end
    end
    return nil
end
