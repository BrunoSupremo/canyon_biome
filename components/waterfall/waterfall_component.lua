local CanyonWaterfall = class()
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local rng = _radiant.math.get_default_rng()

function CanyonWaterfall:post_activate()
	self._world_generated_listener = radiant.events.listen_once(stonehearth.game_creation, 'stonehearth:world_generation_complete', self, self._on_world_generation_complete)
end

function CanyonWaterfall:_on_world_generation_complete()
	local location = radiant.entities.get_world_grid_location(self._entity)
	if location then
		local direction, ending_location = self:find_closest_highground_direction(location)
		if direction then
			self:create_canals(location, ending_location)
			local delayed_function = function ()
				self:dig_drystone_area(location)
				self.stupid_delay:destroy()
				self.stupid_delay = nil
			end
			self.stupid_delay = stonehearth.calendar:set_persistent_timer("teste delay", "30m+10m", delayed_function)
		end
	end
	radiant.entities.destroy_entity(self._entity)
end

function CanyonWaterfall:find_closest_highground_direction(location)
	for i=1,5 do
		if radiant.terrain.get_point_on_terrain(location+Point3(0,0,i*16)).y > 85 then
			local ending_location = radiant.terrain.get_point_on_terrain(location+Point3(0,0,i*16))
			ending_location.y = ending_location.y - 3
			return "north", ending_location
		end
		if radiant.terrain.get_point_on_terrain(location+Point3(i*16,0,0)).y > 85 then
			local ending_location = radiant.terrain.get_point_on_terrain(location+Point3(i*16,0,0))
			ending_location.y = ending_location.y - 3
			return "east", ending_location
		end
		if radiant.terrain.get_point_on_terrain(location+Point3(0,0,-i*16)).y > 85 then
			local ending_location = radiant.terrain.get_point_on_terrain(location+Point3(0,0,-i*16))
			ending_location.y = ending_location.y - 3
			return "south", ending_location
		end
		if radiant.terrain.get_point_on_terrain(location+Point3(-i*16,0,0)).y > 85 then
			local ending_location = radiant.terrain.get_point_on_terrain(location+Point3(-i*16,0,0))
			ending_location.y = ending_location.y - 3
			return "west", ending_location
		end
	end
	return nil
end

function CanyonWaterfall:dig_drystone_area(location)
	location = radiant.terrain.get_point_on_terrain(location)
	local drill_region = Region3(
		Cube3(
			location + Point3(0,-5,0),
			location + Point3(1,0,1)
			)
		)

	local dig_region = radiant.terrain.intersect_region(drill_region)
	radiant.terrain.subtract_region(dig_region)
	-- stonehearth.hydrology:create_water_body_with_region(dig_region, 5)

	radiant.terrain.place_entity_at_exact_location(
		radiant.entities.create_entity("stonehearth:manipulation:dry_stone"),
		location + Point3(0,-5,0), {force_iconic = false} )
	radiant.terrain.place_entity_at_exact_location(
		radiant.entities.create_entity("stonehearth:manipulation:dry_stone"),
		location + Point3(0,-5,0), {force_iconic = false} )
end

function CanyonWaterfall:create_canals(location,ending_location)
	local entities = radiant.terrain.get_entities_at_point(location)
	local water_height = 0
	for _, entity in pairs(entities) do
		local water_component = entity:get_component('stonehearth:water')
		if water_component then
			water_height = math.ceil(water_component:get_height())
			break
		end
	end
	-- min and max locations to sort out the coords, smaller first
	local min_location = Point3(math.min(location.x,ending_location.x), location.y +water_height, math.min(location.z,ending_location.z))
	local max_location = Point3(math.max(location.x,ending_location.x), ending_location.y, math.max(location.z,ending_location.z))

	local region = Region3(Cube3(min_location, max_location):inflated(Point3(1,0,1)))
	local terrain_region = radiant.terrain.intersect_region(region)
	region:subtract_region(terrain_region)
	local surface_region = radiant.terrain.intersect_region(region:translated(Point3(0,-1,0)))
	radiant.terrain.subtract_region( surface_region )

	self:remove_entities_in_the_way(surface_region:inflated(Point3(2,2,2)))

	for cube in surface_region:each_cube() do
		local water_region = Region3(cube)
		stonehearth.hydrology:create_water_body_with_region(water_region, 0.5)
	end

	min_location.y = max_location.y-1
	radiant.terrain.subtract_region( Region3(Cube3(min_location, max_location):inflated(Point3(1,0,1))) )
	radiant.terrain.place_entity_at_exact_location(
		radiant.entities.create_entity("stonehearth:manipulation:wet_stone"),
		ending_location - Point3.unit_y, {force_iconic = false} )
	radiant.terrain.place_entity_at_exact_location(
		radiant.entities.create_entity("stonehearth:manipulation:wet_stone"),
		ending_location - Point3.unit_y, {force_iconic = false} )
end

function CanyonWaterfall:remove_entities_in_the_way(region)
	local intersected_entities = radiant.terrain.get_entities_in_region(region)
	for id, entity in pairs(intersected_entities) do
		if not (entity:get_component('stonehearth:water') or entity == radiant._root_entity) then
			radiant.entities.destroy_entity(entity)
		end
	end
end

return CanyonWaterfall