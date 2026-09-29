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
--  * the substation covers 18x18 tiles and reaches 18 tiles of wire

StressTest = {}

local SPACING = 140        -- tiles between station origins
local SPINE_START = 2      -- first cable offset east of the controller
local DRIVE_FIRST = 2      -- first cable index that carries a drive
local PLAYER_CLEARANCE = 20 -- tiles between the player and the first controller

--Items used to load the drives. Filtered against the active prototypes, so mod
--sets that remove one simply contribute fewer types.
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
    local stats = {controllers = 0, drives = 0, cables = 0, grids = 0, power = 0, failed = 0}
    local notes = {}

    if surface.name ~= "nauvis" then
        notes[#notes + 1] = "surface is '" .. surface.name .. "', not nauvis"
    end

    --Offset east so the build never traps the player.
    local baseX = math.floor(player.position.x) + PLAYER_CLEARANCE + 0.5
    local baseY = math.floor(player.position.y) + 0.5

    local driveNames = {}
    for _, drive in pairs(Constants.Drives.ItemDrive) do
        driveNames[#driveNames + 1] = drive.name
    end
    local cableName = Constants.NetworkCables.Cables.RED.cable.name

    for station = 1, stationCount do
        local cx = baseX + (station - 1) * SPACING
        local cy = baseY

        --Power. The substation touches the controller's west side, so the
        --controller sits well inside the 18x18 supply area. The energy
        --interface has to switch mode explicitly: it defaults to a consumer,
        --and setting power_production alone produces nothing.
        if place(surface, force, "substation", {cx - 4, cy}, record) ~= nil then
            stats.power = stats.power + 1
        else
            stats.failed = stats.failed + 1
        end

        local source = place(surface, force, "electric-energy-interface", {cx - 4, cy + 4}, record)
        if source ~= nil then
            stats.power = stats.power + 1
            local ok = pcall(function() source.electric_interface_mode = "primary_output" end)
            source.power_production = 1000000000
            source.power_usage = 0
            notes[#notes + 1] = "station " .. station .. " source mode set=" .. tostring(ok)
        else
            stats.failed = stats.failed + 1
        end

        if place(surface, force, Constants.NetworkController.main.name, {cx, cy}, record) ~= nil then
            stats.controllers = stats.controllers + 1
        else
            stats.failed = stats.failed + 1
        end

        if place(surface, force, Constants.NetworkInventoryInterface.name, {cx, cy + 2}, record) ~= nil then
            stats.grids = stats.grids + 1
        else
            stats.failed = stats.failed + 1
        end

        local spineLength = DRIVE_FIRST + drivesPerStation * 2
        for i = 0, spineLength - 1 do
            if place(surface, force, cableName, {cx + SPINE_START + i, cy}, record) ~= nil then
                stats.cables = stats.cables + 1
            else
                stats.failed = stats.failed + 1
            end
        end

        for k = 0, drivesPerStation - 1 do
            local i = DRIVE_FIRST + k * 2
            local name = driveNames[(k % #driveNames) + 1]
            if place(surface, force, name, {cx + SPINE_START + i - 0.5, cy - 1.5}, record) ~= nil then
                stats.drives = stats.drives + 1
            else
                stats.failed = stats.failed + 1
            end
        end
    end

    storage.stressTest = storage.stressTest or {}
    storage.stressTest.entities = record

    local summary = string.format(
        "stations=%d controllers=%d drives=%d cables=%d grids=%d power=%d failed=%d",
        stationCount, stats.controllers, stats.drives, stats.cables, stats.grids, stats.power, stats.failed)
    if #notes > 0 then
        summary = summary .. "\n" .. table.concat(notes, "\n")
    end
    summary = summary .. "\nwait 2 seconds, then run /rns-stress-status"
    return summary
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

--Verification: what the network actually sees, including whether the
--controller has energy.
function StressTest.status()
    local lines = {}
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true
            and obj.thisEntity.name == Constants.NetworkController.main.name then
            local members = 0
            for _ in pairs(obj.network.connectedEntities or {}) do members = members + 1 end
            lines[#lines + 1] = string.format("NC %d members=%d powerDraw=%s energy=%.0f stable=%s",
                obj.entID, members, tostring(obj.network.powerDraw),
                obj.thisEntity.energy or 0, tostring(obj.stable))
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or "no controllers found"
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
