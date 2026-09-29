for _, recipe in pairs(Constants.Recipies) do
    local R = {}
    R.type = "recipe"
    R.category = recipe.category
    R.name = recipe.name
    R.energy_required = recipe.craft_time
    R.enabled = recipe.enabled
    R.ingredients = recipe.ingredients
    R.results = {{type = "item", name = recipe.name, amount = recipe.count}}
    data:extend{R}
end
