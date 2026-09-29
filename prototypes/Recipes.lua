require("prototypes.normalize")

for _, recipe in pairs(Constants.Recipies) do
    local R = {}
    R.type = "recipe"
    R.category = recipe.category
    R.name = recipe.name
    R.energy_required = recipe.craft_time
    R.enabled = recipe.enabled
    R.ingredients = RNS_normalize_ingredients(recipe.ingredients)
    R.results = {{type = "item", name = recipe.name, amount = recipe.count}}
    data:extend{R}
end

log("RNSRedux marker: normalizer=" .. tostring(RNS_normalize_ingredients ~= nil))
