local log = radiant.log.create_logger('CanyonWaterfall')
local CanyonWaterfall = class()
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local rng = _radiant.math.get_default_rng()

function CanyonWaterfall:post_activate()
	log:error("post_activate")
	self._world_generated_listener = radiant.events.listen_once(stonehearth.game_creation, 'stonehearth:world_generation_complete', self, self._on_world_generation_complete)
end

function CanyonWaterfall:_on_world_generation_complete()
	log:error("_on_world_generation_complete")
	local location = radiant.entities.get_world_grid_location(self._entity)
	if location then
		location = location+Point3(1,0,1)
		self:carve_river(location)
	end
	radiant.entities.destroy_entity(self._entity)
end

function CanyonWaterfall:carve_river(location)
	-- log:error("carve_river")
	local step = 0
	local final_location, direction, dry_stone_offset
	repeat
		step = step +1
		final_location, direction, dry_stone_offset = self:is_terrain(location, step)
	--indent
	until final_location or step>10
	--indent

	if not final_location then
		return nil,nil
	end

	local tunel_cube = Cube3(
		location,
		final_location + Point3(0,2,0)
		)
	if direction == "north" then
		tunel_cube = Cube3(
			final_location,
			location + Point3(0,2,0)
			)
	end
	if direction == "west" then
		tunel_cube = Cube3(
			final_location,
			location + Point3(0,2,0)
			)
	end
	tunel_cube = tunel_cube:inflated(Point3(2, 0, 2))
	self:remove_cube(tunel_cube)

	self:remove_entities_in_the_way(tunel_cube)

	for i=5, 200 do
		if not radiant.terrain.is_terrain(final_location+Point3(0,i,0)) then
			self:add_dry_stone(dry_stone_offset)
			self:add_wet_stone(final_location+Point3(0,i,0),direction)
			return
		end 
	end
end

function CanyonWaterfall:is_terrain(location, step)
	local center_offset = 6
	if radiant.terrain.is_terrain(location + Point3(0, 2, -16*step)) then
		return location+Point3(0, 0, -16*step +center_offset), "north", location+Point3(0, 0, -16)
	end
	if radiant.terrain.is_terrain(location + Point3(16*step, 2, 0)) then
		return location+Point3(16*step -center_offset, 0, 0), "east", location+Point3(16, 0, 0)
	end
	if radiant.terrain.is_terrain(location + Point3(0, 2, 16*step)) then
		return location+Point3(0, 0, 16*step -center_offset), "south", location+Point3(0, 0, 16)
	end
	if radiant.terrain.is_terrain(location + Point3(-16*step, 2, 0)) then
		return location+Point3(-16*step +center_offset, 0, 0), "west", location+Point3(-16, 0, 0)
	end
	return nil,nil,nil
end

function CanyonWaterfall:remove_cube(tunel_cube)
	local cave_region = radiant.terrain.intersect_cube(tunel_cube)
	for cube in cave_region:each_cube() do
		radiant.terrain.subtract_cube(cube)
	end
end

function CanyonWaterfall:remove_entities_in_the_way(cube)
	cube = cube:inflated(Point3(3,3,3))
	local intersected_entities = radiant.terrain.get_entities_in_cube(cube)
	for id, entity in pairs(intersected_entities) do
		if not entity:get_uri()=="canyon_biome:terrain:waterfall" and not entity:get_component('stonehearth:water')  then
			radiant.entities.destroy_entity(entity)
		end
	end
end

function CanyonWaterfall:add_wet_stone(location,direction)
	-- log:error("add_wet_stone")
	local tunel_cube = Cube3(
		location + Point3(0,-7,0),
		location + Point3(1,-4,1)
		)
	self:remove_cube(tunel_cube)
	if direction == "north" then
		tunel_cube = Cube3(
			location + Point3(0,-5,0),
			location + Point3(0,-4,6)
			)
	end
	if direction == "south" then
		tunel_cube = Cube3(
			location + Point3(0,-5,-6),
			location + Point3(0,-4, 0)
			)
	end
	if direction == "west" then
		tunel_cube = Cube3(
			location + Point3(0,-5,0),
			location + Point3(6,-4,0)
			)
	end
	if direction == "east" then
		tunel_cube = Cube3(
			location + Point3(-6,-5,0),
			location + Point3( 0,-4,0)
			)
	end
	tunel_cube = tunel_cube:inflated(Point3(1,0,1))
	self:remove_cube(tunel_cube)
	radiant.terrain.place_entity_at_exact_location(radiant.entities.create_entity("stonehearth:manipulation:wet_stone"), location+Point3(0,-7,0), {force_iconic = false})
	radiant.terrain.place_entity_at_exact_location(radiant.entities.create_entity("stonehearth:manipulation:wet_stone"), location+Point3(0,-7,0), {force_iconic = false})
end

function CanyonWaterfall:add_dry_stone(location)
	-- log:error("add_dry_stone")
	local tunel_cube = Cube3(
		location + Point3(0,-3,0),
		location + Point3(1, 0,1)
		)
	self:remove_cube(tunel_cube)
	tunel_cube = Cube3(
		location + Point3(0,-3,0),
		location + Point3(4,-2,1)
		)
	self:remove_cube(tunel_cube)
	radiant.terrain.place_entity_at_exact_location(radiant.entities.create_entity("stonehearth:manipulation:dry_stone"), location+Point3(3,-3,0), {force_iconic = false})
	radiant.terrain.place_entity_at_exact_location(radiant.entities.create_entity("stonehearth:manipulation:dry_stone"), location+Point3(3,-3,0), {force_iconic = false})
end

return CanyonWaterfall