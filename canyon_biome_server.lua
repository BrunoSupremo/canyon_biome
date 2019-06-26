canyon_biome = {}
print("Canyon Biome version 19.6.25")

function canyon_biome:_on_biome_set(e)
	if e.biome_uri ~= "canyon_biome:biome:canyon" then
		return
	end
	local custom_height_map_renderer = require('services.server.world_generation.custom_height_map_renderer')
	local height_map_renderer = radiant.mods.require('stonehearth.services.server.world_generation.height_map_renderer')
	radiant.mixin(height_map_renderer, custom_height_map_renderer)

	local custom_micro_map_generator = require('services.server.world_generation.custom_micro_map_generator')
	local micro_map_generator = radiant.mods.require('stonehearth.services.server.world_generation.micro_map_generator')
	radiant.mixin(micro_map_generator, custom_micro_map_generator)

	local custom_landscaper = require('services.server.world_generation.custom_landscaper')
	local landscaper = radiant.mods.require('stonehearth.services.server.world_generation.landscaper')
	radiant.mixin(landscaper, custom_landscaper)
end

radiant.events.listen_once(radiant, 'stonehearth:biome_set', canyon_biome, canyon_biome._on_biome_set)

return canyon_biome