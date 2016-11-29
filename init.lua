--[[
Goals:

####1. make a simple entity that randomly goes around the world, 
####2. turning into the node it walks on
####3. make entity drop node it's camo'd as on death!
####4. randomly make node turn into mob when mined
####5. Attack players in area
####5.a Follow players

]]--

minetest.register_entity("node_shifter:base", {
    hp_max = 20,
    physical = true,
    --collide_with_objects = false,
    collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
    visual = "wielditem",
    visual_size = {x=0.665, y=0.665},
    textures={"air"},
    nodename = "",
    makes_footstep_sound = false,
    yaw = 0,
    --
	timer = 0,
	timer_expire = 0,
	last_pos = {},
	update = false,
	attack_timer = 0,
    -- how the entity decides what to do
    behavior = 0, --0 = stand, 1 = walk randomly, 2 = attack
    set_behavior = function(self)
    	if self.timer > self.timer_expire then
			self.behavior = math.random(0,1)
			self.timer = 0
			self.timer_expire = math.random(1,5) + math.random()
			self.yaw = (math.pi*2)*math.random()
			self.object:setyaw(self.yaw)
			
			--debug = 1
			--self.behavior = 1
		end
    end,
    round = function(what, precision)
	   return math.floor(what*math.pow(10,precision)+0.5) / math.pow(10,precision)
	end,
    -- how the entity carries out behaviors
    act_out_behavior = function(self,dtime)
		if self.behavior == 0 then
			local y 
			if self.object:getvelocity().y > 0 then
				y = -1
			else
				y = self.object:getvelocity().y
			end
			self.object:setvelocity({x=0,y=y,z=0})
			
		elseif self.behavior == 1 then
			local pos = self.object:getpos()
			local x = self.round(self.object:getvelocity().x, 1)
			local z = self.round(self.object:getvelocity().z, 1)
			
			local goal_x = self.round(math.sin(self.yaw) * -1, 1)
			local goal_z = self.round(math.cos(self.yaw), 1)
			
			
			local goal_y
			
			if (x == 0 and goal_x ~= 0) or (z == 0 and goal_z ~= 0) and self.object:getvelocity().y <= 0 and minetest.get_node({x=pos.x,y=pos.y-0.5,z=pos.z}).name ~= "air" then
				goal_y = 3
			else
				goal_y = -1
			end
			
			self.object:setvelocity({x=goal_x,y=goal_y,z=goal_z})
		end
		
		
		for _,object in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 7)) do
			if object:is_player() then
				local pos = self.object:getpos()
				self.attack_timer = self.attack_timer + dtime
								
				self.behavior = 2
				
				local pos1 = self.object:getpos()
				local pos2 = object:getpos()
				local vec = {}

				vec.y = pos2.y - pos1.y
				vec.x = pos1.x - pos2.x
				vec.z = pos1.z - pos2.z
				
				self.yaw = math.atan(vec.z/vec.x)+math.pi/2
				
				
				if pos1.x > pos2.x then
					self.yaw = self.yaw+math.pi
				end
				
				local x = self.round(self.object:getvelocity().x, 2)
				local z = self.round(self.object:getvelocity().z, 2)
				
				local goal_x = self.round(math.sin(self.yaw) * -1, 2)*-3
				local goal_z = self.round(math.cos(self.yaw), 2)*-3
					
				
				local goal_y
			
				if (x == 0 and goal_x ~= 0) or (z == 0 and goal_z ~= 0) and self.object:getvelocity().y <= 0 and minetest.get_node({x=pos.x,y=pos.y-0.5,z=pos.z}).name ~= "air" then
					goal_y = 3
				else
					goal_y = -1
				end
				
				self.object:setvelocity({x=goal_x,y=goal_y,z=goal_z})
				
				self.object:setyaw(self.yaw)
				
				if self.attack_timer >= 3 then
					for _,player in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 2)) do
						if player:is_player() then
							player:punch(self.object, 1.0,  {
								full_punch_interval=1.0,
								damage_groups = {fleshy=1}
							}, vec)
						end
					end
					self.attack_timer = 0
					
				end
				for _,player in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 2)) do
					if player:is_player() then
						self.object:setvelocity({x=0,y=-1,z=0})
					end
				end
			end
		end
    end,   
    --
    camo = function(self,dtime)
		if self.nodename == nil then
			self.nodename = "default:dirt_with_grass"
		end
		self.texture = ItemStack(self.nodename):get_name()
		self.nodename = self.nodename
		self.object:set_properties({textures={self.texture}})
    end,
    --
	node_inside = function(self,dtime)
		local pos = self.object:getpos()
		local oldpos = self.last_pos
		
		local x = math.floor(pos.x + 0.5)
		local y = math.floor(pos.y + 0.5)
		local z = math.floor(pos.z + 0.5)
		
		if x ~= oldpos.x or y ~= oldpos.y or z ~= oldpos.z then
		
			local node = minetest.get_node({x=x,y=y-1,z=z}).name
			
			if node ~= "air" then
				self.nodename = node
				self.camo(self,dtime)
			end
		end
		
		self.last_pos = {x=x,y=y,z=z}
	end,
    --
    on_activate = function(self,dtime)
		self.object:setacceleration({x=0,y=-9.81,z=0})
		self.timer_expire = math.random(1,5) + math.random()
		
		self.camo(self,dtime)
    end,
    
    on_step = function(self,dtime)
		self.timer = self.timer + dtime
		self.set_behavior(self)
		
		self.act_out_behavior(self,dtime)
		
		
		self.node_inside(self,dtime)
    end,
    on_punch = function(self,dtime)
		local hp = self.object:get_hp()
		if hp <= 0 then
			minetest.add_item(self.object:getpos(), self.nodename)
		end
    end,
})


minetest.register_on_dignode(function(pos, oldnode, digger)
	if math.random() > 0.95 then
		local entity = minetest.add_entity(pos, "node_shifter:base")
		entity:get_luaentity().nodename = oldnode.name
	end
end)







if minetest.setting_get("log_mods") then
	minetest.log("action", "Node Shifter Loaded!")
end
