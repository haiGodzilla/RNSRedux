for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCableI = {}
    networkCableI.type = "item"
    networkCableI.name = color.cable.name
    networkCableI.icon = color.cable.itemIcon
    networkCableI.icon_size = 512
    networkCableI.subgroup = Constants.ItemGroup.Category.Cable_subgroup
    networkCableI.order = "a"
    networkCableI.stack_size = 200
    networkCableI.place_result = color.cable.name
    data:extend{networkCableI}
end

--[[
for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCableR = {}
    networkCableR.type = "recipe"
    networkCableR.name = color.cable.name
    networkCableR.energy_required = 1
    networkCableR.enabled = true
    networkCableR.ingredients = {}
    networkCableR.result = color.cable.name
    networkCableR.result_count = 10
    data:extend{networkCableR}
end
]]

for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCable_E = {}
    networkCable_E.type = "container"
    networkCable_E.name = color.cable.name
    networkCable_E.icon = color.cable.itemIcon
    networkCable_E.icon_size = 512
    networkCable_E.inventory_size = 0
    networkCable_E.flags = {"placeable-neutral", "player-creation"}
    networkCable_E.minable = {mining_time = 0.2, result = color.cable.name}
    networkCable_E.fast_replaceable_group = Constants.Settings.RNS_FR_Cable
    networkCable_E.max_health = 250
    networkCable_E.dying_explosion = "medium-explosion"
    networkCable_E.corpse = "small-remnants"
    networkCable_E.collision_box = {{-0.40, -0.40}, {0.49, 0.40}}
    --Walkable, so the character passes over a cable instead of walking around it.
    networkCable_E.collision_mask = RNS_WalkableCollisionMask
    networkCable_E.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
    networkCable_E.open_sound = { filename = "__base__/sound/wooden-chest-open.ogg" }
    networkCable_E.close_sound = { filename = "__base__/sound/wooden-chest-close.ogg" }
    networkCable_E.vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 }
    networkCable_E.ghost_tint = {g=1, b=1, a=0.3}
    networkCable_E.picture =
        {
            layers =
            {
                {
                    filename =color.cable.entityE,
                    priority = "medium",
                    width = 512,
                    height = 512,
                    shift = {0,0},
                    scale = 1/16
                },
                {
                    filename = Constants.MOD_ID .. "/graphics/Cables/NetworkCableDot_S.png",
                    priority = "medium",
                    width = 512,
                    height = 512,
                    shift = {0,0},
                    draw_as_shadow = true,
                    scale = 1/16
                }
            }
        }
    data:extend{networkCable_E}
end

for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCableI = {}
    networkCableI.type = "item"
    networkCableI.name = color.underground.name
    networkCableI.icon = color.underground.itemIcon
    networkCableI.icon_size = 512
    networkCableI.subgroup = Constants.ItemGroup.Category.Cable_subgroup
    --"b", so the ramp sorts after the straight cable. Both were "a", which made the
    --inventory order depend on which prototype happened to be registered first.
    networkCableI.order = "b"
    networkCableI.stack_size = 100
    networkCableI.place_result = color.underground.name
    data:extend{networkCableI}
end

--[[
for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCableR = {}
    networkCableR.type = "recipe"
    networkCableR.name = color.underground.name
    networkCableR.energy_required = 1
    networkCableR.enabled = true
    networkCableR.ingredients = {}
    networkCableR.result = color.underground.name
    networkCableR.result_count = 10
    data:extend{networkCableR}
end
]]

for _, color in pairs(Constants.NetworkCables.Cables) do
    local networkCable_E = {}
    networkCable_E.type = "assembling-machine"
    networkCable_E.name = color.underground.name
    networkCable_E.icon = color.underground.itemIcon
    networkCable_E.icon_size = 512
    networkCable_E.localised_description = {"entity-description.RNS_NetworkCableRamp", tostring(Constants.Settings.RNS_CableUnderground_Reach+1)}
    networkCable_E.flags = {"placeable-neutral", "player-creation"}
    networkCable_E.collision_box = {{-0.40, -0.40}, {0.40, 0.40}}
    --Walkable, like the cable it belongs to.
    networkCable_E.collision_mask = RNS_WalkableCollisionMask
    networkCable_E.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
    networkCable_E.fast_replaceable_group = Constants.Settings.RNS_FR_Cable
    networkCable_E.max_health = 350
    networkCable_E.dying_explosion = "medium-explosion"
    networkCable_E.corpse = "small-remnants"
    networkCable_E.open_sound = { filename = "__base__/sound/wooden-chest-open.ogg" }
    networkCable_E.close_sound = { filename = "__base__/sound/wooden-chest-close.ogg" }
    networkCable_E.vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 }
    networkCable_E.minable = {mining_time = 0.2, result = color.underground.name}
    --An assembling machine draws from graphics_set.animation. The three IO buses in
    --this mod use that field, and the API lists graphics_set for this prototype type;
    --a top-level animation is not among its properties. Without it the entity has no
    --graphics, so the cursor preview is empty and the placed piece is invisible.
    networkCable_E.graphics_set =
        {
            animation = {
                north = {
                    layers = {
                        {
                            filename = color.underground.entityE,
                            priority = "medium",
                            size = 512,
                            scale = 1/16,
                            x=0
                        },
                        {
                            filename = color.underground.entityS,
                            priority = "medium",
                            size = 512,
                            draw_as_shadow = true,
                            scale = 1/16,
                            x=0
                        }
                    }
                }
            }
        }
    local rampAnimation = networkCable_E.graphics_set.animation
    rampAnimation.east = table.deepcopy(rampAnimation.north)
    rampAnimation.east.layers[1].x = 512
    rampAnimation.east.layers[2].x = 512
    rampAnimation.south = table.deepcopy(rampAnimation.north)
    rampAnimation.south.layers[1].x = 512*2
    rampAnimation.south.layers[2].x = 512*2
    rampAnimation.west = table.deepcopy(rampAnimation.north)
    rampAnimation.west.layers[1].x = 512*3
    rampAnimation.west.layers[2].x = 512*3
    networkCable_E.crafting_categories = {"RNS-Nothing"}
    networkCable_E.crafting_speed = 1
    networkCable_E.energy_source =
    {
        type = "void",
    }
    networkCable_E.energy_usage = "1J"
    networkCable_E.fluid_boxes = {
        {
            volume = 100,
            pipe_connections = {
                {flow_direction = "input-output", direction = defines.direction.north, position = {0, -0.4}, hide_connection_info = true}
            },
            production_type = "output"
        }
    }
    data:extend{networkCable_E}
end