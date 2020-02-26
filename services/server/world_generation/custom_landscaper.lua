local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local SimplexNoise = require 'stonehearth.lib.math.simplex_noise'
local FilterFns = require 'stonehearth.services.server.world_generation.filter.filter_fns'
local WeightedSet = require 'stonehearth.lib.algorithms.weighted_set'
local water_shallow = 'water_1'
local water_deep = 'water_2'
local CustomLandscaper = class()

local Astar = require 'services.server.world_generation.astar'
local noise_height_map --this noise is to mess with the astar to avoid straight line rivers
local regions --.size, .start and .ending
local min_required_region_size = 10
local log = radiant.log.create_logger('CanyonLandscaper')

local ExtraMapOptions = require 'extra_map_options.services.server.world_generation.landscaper'

function CustomLandscaper:mark_water_bodies(elevation_map, feature_map)
	if self._extra_map_options_on then
		ExtraMapOptions.mark_water_bodies(self, elevation_map, feature_map)
	else
		local rng = self._rng
		local biome = self._biome

		noise_height_map = {}
		noise_height_map.width = feature_map.width
		noise_height_map.height = feature_map.height
		for j=1, feature_map.height do
			for i=1, feature_map.width do
				local elevation = elevation_map:get(i, j)
				local terrain_type = biome:get_terrain_type(elevation)

				local offset = (j-1)*feature_map.width+i
				--creates and set the points
				noise_height_map[offset] = {}
				noise_height_map[offset].x = i
				noise_height_map[offset].y = j
				noise_height_map[offset].plains = terrain_type == "plains"
				noise_height_map[offset].noise = rng:get_int(1,100)
			end
		end
		self:canyon_mark_borders()
		self:canyon_create_regions()
		self:canyon_add_rivers(feature_map)
	end
end

function CustomLandscaper:canyon_mark_borders()
	local function neighbors_have_different_elevations(x,y)
		local neighbor_offset = (y-1)*noise_height_map.width+x
		if noise_height_map[neighbor_offset-1] then
			if not noise_height_map[neighbor_offset-1].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset+1] then
			if not noise_height_map[neighbor_offset+1].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset-noise_height_map.width] then
			if not noise_height_map[neighbor_offset-noise_height_map.width].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset+noise_height_map.width] then
			if not noise_height_map[neighbor_offset+noise_height_map.width].plains then
				return true
			end
		end
		return false
	end

	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			noise_height_map[offset].border = neighbors_have_different_elevations(x,y)
		end
	end
end

function CustomLandscaper:canyon_create_regions()
	regions = {}
	local region_index = 1
	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			if not noise_height_map[offset].border and noise_height_map[offset].plains then
				if not noise_height_map[offset].region then
					local region_candidate = self:canyon_flood_fill_region(x,y, region_index)

					if region_candidate.size>min_required_region_size then
						regions[region_index] = region_candidate
						region_index = region_index +1
					end
				end
			end
		end
	end
end

function CustomLandscaper:canyon_flood_fill_region(x,y, region)
	local offset = (y-1)*noise_height_map.width+x
	local openset = {}

	local start = offset
	local ending = offset

	local current
	local index = 1
	local size = 1
	openset[index] = offset
	noise_height_map[offset].checked = true
	while openset[index]~=nil do
		--find the most distant point in this region from that initially chosen
		current = noise_height_map[ openset[index] ]
		noise_height_map[ openset[index] ].region = region

		local offset_left = (current.y-1)*noise_height_map.width+current.x -1
		if current.x>1 and noise_height_map[offset_left].border==false and not noise_height_map[offset_left].checked then
			size = size +1
			openset[size] = offset_left
			noise_height_map[offset_left].checked = true
		end

		local offset_right = (current.y-1)*noise_height_map.width+current.x +1
		if current.x<noise_height_map.width and noise_height_map[offset_right].border==false and not noise_height_map[offset_right].checked then
			size = size +1
			openset[size] = offset_right
			noise_height_map[offset_right].checked = true
		end

		local offset_up = (current.y-2)*noise_height_map.width+current.x
		if current.y>1 and noise_height_map[offset_up].border==false and not noise_height_map[offset_up].checked then
			size = size +1
			openset[size] = offset_up
			noise_height_map[offset_up].checked = true
		end

		local offset_down = (current.y)*noise_height_map.width+current.x
		if current.y<noise_height_map.height and noise_height_map[offset_down].border==false and not noise_height_map[offset_down].checked then
			size = size +1
			openset[size] = offset_down
			noise_height_map[offset_down].checked = true
		end

		index = index +1
	end
	start = openset[size]

	if size > min_required_region_size then
		--reverse the flood to find the oposing most distant point
		local second_openset = {}
		index = 1
		size = 1
		second_openset[index] = start
		noise_height_map[start].second_pass = true
		while second_openset[index]~=nil do
			current = noise_height_map[ second_openset[index] ]

			local offset_left = (current.y-1)*noise_height_map.width+current.x -1
			if current.x>1 and noise_height_map[offset_left].border==false and not noise_height_map[offset_left].second_pass then
				size = size +1
				second_openset[size] = offset_left
				noise_height_map[offset_left].second_pass = true
			end

			local offset_right = (current.y-1)*noise_height_map.width+current.x +1
			if current.x<noise_height_map.width and noise_height_map[offset_right].border==false and not noise_height_map[offset_right].second_pass then
				size = size +1
				second_openset[size] = offset_right
				noise_height_map[offset_right].second_pass = true
			end

			local offset_up = (current.y-2)*noise_height_map.width+current.x
			if current.y>1 and noise_height_map[offset_up].border==false and not noise_height_map[offset_up].second_pass then
				size = size +1
				second_openset[size] = offset_up
				noise_height_map[offset_up].second_pass = true
			end

			local offset_down = (current.y)*noise_height_map.width+current.x
			if current.y<noise_height_map.height and noise_height_map[offset_down].border==false and not noise_height_map[offset_down].second_pass then
				size = size +1
				second_openset[size] = offset_down
				noise_height_map[offset_down].second_pass = true
			end

			index = index +1
		end
		ending = second_openset[size]
	end

	return {size = size, start = start, ending = ending}
end

function CustomLandscaper:canyon_add_rivers(feature_map)

	local function grab_bigest_region()
		local bigest_region = 0
		local current_bigest_size = 0

		for i,v in pairs(regions) do
			if regions[i].size > current_bigest_size then
				bigest_region = i
				current_bigest_size = regions[i].size
			end
		end
		if bigest_region <1 then
			return nil
		end
		return bigest_region
	end

	for i=1,8 do
		local region = grab_bigest_region()
		if not region then break end

		local start = regions[region].start
		local ending = regions[region].ending

		self:canyon_draw_river(noise_height_map[start], noise_height_map[ending], feature_map)
		regions[region] = nil
	end
end

function CustomLandscaper:canyon_draw_river(start,goal,feature_map)
	local path = Astar.path ( start, goal, noise_height_map, true )

	if not path then
		log:error('Error. No valid river path found!')
	else
		for i, node in ipairs ( path ) do
			feature_map:set(node.x, node.y, water_shallow)
		end
	end
end

--- water spawning
function CustomLandscaper:place_features(tile_map, feature_map, place_item)
	if not self._landscape_info.water.spawn_objects then
		return
	end
	local water_1_table = WeightedSet(self._rng)
	for item, weight in pairs(self._landscape_info.water.spawn_objects.water_1) do
		water_1_table:add(item,weight)
	end

	local new_feature
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local feature_name = feature_map:get(i, j)
			if feature_name == "water_1" then
				new_feature = water_1_table:choose_random()
				if new_feature ~= "none" then
					feature_name = new_feature
				end
			end
			self:_place_feature(feature_name, i, j, tile_map, place_item)
		end
	end
end

return CustomLandscaper