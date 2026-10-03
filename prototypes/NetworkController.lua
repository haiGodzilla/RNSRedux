local controllerI = {}
controllerI.type = "item-with-tags"
controllerI.name = Constants.NetworkController.main.name
controllerI.icon = Constants.NetworkController.main.itemIcon
controllerI.icon_size = 256
controllerI.subgroup = Constants.ItemGroup.Category.subgroup
controllerI.order = "n"
controllerI.stack_size = 10
controllerI.place_result = Constants.NetworkController.main.name
data:extend{controllerI}

--[[
local controllerR = {}
controllerR.type = "recipe"
controllerR.name = Constants.NetworkController.main.name
controllerR.energy_required = 1
controllerR.enabled = true
controllerR.ingredients = {}
controllerR.result = Constants.NetworkController.main.name
controllerR.result_count = 1
data:extend{controllerR}
]]

local cE0 = {}
cE0.type = "electric-energy-interface"
cE0.name = Constants.NetworkController.main.name
cE0.icon = Constants.NetworkController.main.itemIcon
cE0.icon_size = 256
cE0.flags = {"placeable-neutral", "player-creation"}
cE0.minable = {mining_time = 0.2, result = Constants.NetworkController.main.name}
cE0.max_health = 350
cE0.dying_explosion = "medium-explosion"
cE0.corpse = "medium-remnants"
--Three wide and four tall. The artwork measures 3.02 x 4.27 tiles at 192/512
--(tools/png_bbox.py), so the 3 x 3 box left a tile and a quarter uncovered.
cE0.collision_box = {{-1.40, -1.90}, {1.40, 1.90}}
cE0.selection_box = {{-1.5, -2.0}, {1.5, 2.0}}
cE0.open_sound = { filename = "__base__/sound/wooden-chest-open.ogg" }
cE0.close_sound = { filename = "__base__/sound/wooden-chest-close.ogg" }
cE0.vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 }
cE0.energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    buffer_capacity = "0J" --1 Joule is 50 Watts
}
cE0.energy_usage = "0W"
cE0.picture =
    {
        layers =
        {
            {
                filename = Constants.NetworkController.main.entityE,
                priority = "medium",
                size = 512,
                --180/512 instead of 192/512: at 192 the artwork is 4.27 tiles
                --tall and cannot fit four tiles. Shrinking it by 6.25% makes it
                --2.834 x 3.999, which fills the new footprint exactly.
                shift = {0,0.5828},
                scale = 180/512
            },
            {
                filename = Constants.NetworkController.main.entityS,
                priority = "medium",
                draw_as_shadow = true,
                size = 512,
                --Same shift as the body, so its offset from the body is the one
                --it had before. Its own size is B-22.
                shift = {0,0.5828},
                scale = (96 * 3)/512
            }
        }
    }
data:extend{cE0}