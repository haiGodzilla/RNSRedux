--Stress test builder for UPS measurement.
--
--Builds a large RNS network with one command so we can measure before and after
--each performance milestone. Nothing here runs unless a player calls it.
--
--Geometry notes, taken from the connection code:
--  * the controller is 3x3 and checks a one tile wide strip on each side
--  * cables and IO buses are 1x1 with the same four strip check
--  * collision boxes are smaller than their tile footprint (drive 1.8, cable
--    0.89, grid block 0.8), so adjacent entities genuinely overlap the strips
--  * a 2x2 drive needs an integer centre, a 1x1 or 3x3 an integer plus 0.5

StressTest = {}

local SPACING = 140        -- tiles between station origins
local SPINE_START = 2      -- first cable offset east of the controller
local DRIVE_FIRST = 2      -- first cable index that carries a drive

--Items used to load the drives. Filtered against the active prototypes, so
--mod sets that remove one simply contribute fewer types.
local FILL_ITEMS = {
    "iron-plate", "copper-plate", "steel-plate", "iron-gear-wheel",
    "copper-cable", "electronic-circuit", "advanced-circuit",
    "processing-unit", "plastic-bar", "sulfur", "battery",
    "engine-unit", "electric-engine-unit", "low-density-structure",
    "rocket-fuel", "explosive-cannon-shell",
}

local function place(surface, force, name, position, record)
    local entity = surface.create_entity{
        name = name,
        position = position,
        force = force,
    }
    if entity ~= nil and record ~= nil then
        record[#record + 1] = entity.unit_number
    end
    return entity
end

function StressTest.build(stationCount, drivesPerStation)
    local player = game.player
    if player == nil then return "no player" end
    local surface = player.surface
    local force = player.force

    local record = {}
    local stats = {controllers = 0, drives = 0, cables = 0, grids = 0, power = 0}

    local baseX = math.floor(player.position.x) + 0.5
    local baseY = math.floor(player.position.y) + 0.5

    local driveNames = {}
    for _, drive in pairs(Constants.Drives.ItemDrive) do
        driveNames[#driveNames + 1] = drive.name
    end
    local cableName = Constants.NetworkCables.Cables.RED.cable.name

    for station = 1, stationCount do
        local cx = baseX + (station - 1) * SPACING
        local cy = baseY

        --Power. Only the controller needs electricity; drives have none and the
        --buses use a void energy source.
        if place(surface, force, "substation", {cx - 6, cy + 6}, record) then
            stats.power = stats.power + 1
        end
        local source = place(surface, force, "electric-energy-interface", {cx - 6, cy + 10}, record)
        if source ~= nil then
            source.power_production = 1000000000
            source.power_usage = 0
            stats.power = stats.power + 1
        end

        if place(surface, force, Constants.NetworkController.main.name, {cx, cy}, record) then
            stats.controllers = stats.controllers + 1
        end

        if place(surface, force, Constants.NetworkInventoryInterface.name, {cx, cy + 2}, record) then
            stats.grids = stats.grids + 1
        end

        local spineLength = DRIVE_FIRST + drivesPerStation * 2
        for i = 0, spineLength - 1 do
            if place(surface, force, cableName, {cx + SPINE_START + i, cy}, record) then
                stats.cables = stats.cables + 1
            end
        end

        for k = 0, drivesPerStation - 1 do
            local i = DRIVE_FIRST + k * 2
            local name = driveNames[(k % #driveNames) + 1]
            if place(surface, force, name, {cx + SPINE_START + i - 0.5, cy - 1.5}, record) then
                stats.drives = stats.drives + 1
            end
        end
    end

    storage.stressTest = storage.stressTest or {}
    storage.stressTest.entities = record

    return string.format(
        "stations=%d controllers=%d drives=%d cables=%d grids=%d power=%d",
        stationCount, stats.controllers, stats.drives, stats.cables, stats.grids, stats.power)
end

function StressTest.fill(typesPerDrive, amountPerType)
    if typesPerDrive == nil or amountPerType == nil then
        return "usage: typesPerDrive amountPerType"
    end

    local available = {}
    for _, name in pairs(FILL_ITEMS) do
        if prototypes.item[name] ~= nil then
            available[#available + 1] = name
        end
    end
    if #available == 0 then return "no fill items available" end

    local drives = 0
    local added = 0
    local types = math.min(typesPerDrive, #available)

    for _, obj in pairs(storage.entityTable or {}) do
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true
            and string.match(obj.thisEntity.name, "RNS_ItemDrive") ~= nil
            and obj.add_or_merge_basic_item ~= nil then

            drives = drives + 1
            for t = 1, types do
                if obj:getRemainingStorageSize() <= 0 then break end
                local name = available[t]
                local template = Itemstack.create_template(name)
                if template ~= nil then
                    added = added + obj:add_or_merge_basic_item(template, amountPerType)
                end
            end
        end
    end

    return string.format("drives=%d typesEach=%d amountEach=%d inserted=%d", drives, types, amountPerType, added)
end

function StressTest.clear()
    local record = (storage.stressTest and storage.stressTest.entities) or {}
    local wanted = {}
    for _, unit in pairs(record) do
        wanted[unit] = true
    end

    --Resolved through the mod's own object table. get_entity_by_unit_number
    --would need the "get-by-unit-number" prototype flag, which these entities
    --do not carry.
    local removed = 0
    for unit in pairs(wanted) do
        local obj = (storage.entityTable or {})[unit]
        if obj ~= nil and obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            obj.thisEntity.destroy()
            removed = removed + 1
        end
    end

    if storage.stressTest ~= nil then
        storage.stressTest.entities = {}
    end
    return "removed " .. removed .. " of " .. #record .. " recorded entities"
end
