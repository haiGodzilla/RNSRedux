--Stress test builder for UPS measurement.
--
--Builds a large RNS network with one command so we can measure before and after
--each performance milestone. Nothing here runs unless a player calls it.
--
--Two prerequisites have to be met or the mod ignores script-created entities:
--  1. LuaSurface::create_entity does not raise a built event unless
--     raise_built is set. We raise script_raised_built ourselves instead,
--     because the event has to fire *after* step 2.
--  2. Event.placed bails out when entity.last_user is nil, which is the case
--     for anything created by script. So last_user is assigned first.
--
--Geometry notes, taken from the connection code:
--  * the controller is 3x3 and checks a one tile wide strip on each side
--  * cables are 1x1 with the same four strip check
--  * collision boxes are smaller than their footprint (drive 1.8, cable 0.89),
--    so adjacent entities genuinely overlap the strips
--  * a 2x2 drive needs an integer centre, a 1x1 or 3x3 an integer plus 0.5
--  * the substation covers 18x18 tiles

StressTest = {}

local SPACING = 140         -- tiles between station origins
local SPINE_START = 2       -- first cable offset east of the controller
local DRIVE_FIRST = 2       -- first cable index that carries a drive
local PLAYER_CLEARANCE = 20 -- tiles between the player and the first controller

--Filtered against the active prototypes, so mod sets that drop one simply
--contribute fewer types.
local FILL_ITEMS = {
    "iron-plate", "copper-plate", "steel-plate", "iron-gear-wheel",
    "copper-cable", "electronic-circuit", "advanced-circuit",
    "processing-unit", "plastic-bar", "sulfur", "battery",
    "engine-unit", "electric-engine-unit", "low-density-structure",
    "rocket-fuel", "explosive-cannon-shell",
}

local function place(surface, force, player, name, position, record)
    local entity = surface.create_entity{
        name = name,
        position = position,
        force = force,
    }
    if entity == nil then return nil end

    --Satisfy the precondition in Event.placed before announcing the build.
    pcall(function() entity.last_user = player end)
    script.raise_script_built{entity = entity}

    if record ~= nil then
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
    local powerSources = {}
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
        --interface switches mode explicitly: it starts as a consumer, and
        --power_production alone does nothing.
        local substation = place(surface, force, player, "substation", {cx - 4, cy}, record)
        if substation ~= nil then
            stats.power = stats.power + 1
            powerSources[#powerSources + 1] = substation
        else
            stats.failed = stats.failed + 1
        end

        local source = place(surface, force, player, "electric-energy-interface", {cx - 4, cy + 4}, record)
        if source ~= nil then
            stats.power = stats.power + 1
            --power_production alone is sufficient; the interface does not need
            --its mode switched, and LuaEntity has no readable mode property.
            source.power_production = 1000000000
            source.power_usage = 0
            powerSources[#powerSources + 1] = source
        else
            stats.failed = stats.failed + 1
        end

        if place(surface, force, player, Constants.NetworkController.main.name, {cx, cy}, record) ~= nil then
            stats.controllers = stats.controllers + 1
        else
            stats.failed = stats.failed + 1
        end

        if place(surface, force, player, Constants.NetworkInventoryInterface.name, {cx, cy + 2}, record) ~= nil then
            stats.grids = stats.grids + 1
        else
            stats.failed = stats.failed + 1
        end

        local spineLength = DRIVE_FIRST + drivesPerStation * 2
        for i = 0, spineLength - 1 do
            if place(surface, force, player, cableName, {cx + SPINE_START + i, cy}, record) ~= nil then
                stats.cables = stats.cables + 1
            else
                stats.failed = stats.failed + 1
            end
        end

        for k = 0, drivesPerStation - 1 do
            local i = DRIVE_FIRST + k * 2
            local name = driveNames[(k % #driveNames) + 1]
            if place(surface, force, player, name, {cx + SPINE_START + i - 0.5, cy - 1.5}, record) ~= nil then
                stats.drives = stats.drives + 1
            else
                stats.failed = stats.failed + 1
            end
        end
    end

    storage.stressTest = storage.stressTest or {}
    storage.stressTest.entities = record
    storage.stressTest.powerSources = powerSources

    --Did the mod actually pick the entities up? Anything missing means the
    --placement handler rejected or destroyed it.
    local registered = 0
    for _, unit in pairs(record) do
        if (storage.entityTable or {})[unit] ~= nil then
            registered = registered + 1
        end
    end

    local summary = string.format(
        "stations=%d controllers=%d drives=%d cables=%d grids=%d power=%d failed=%d registered=%d",
        stationCount, stats.controllers, stats.drives, stats.cables, stats.grids,
        stats.power, stats.failed, registered)
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

--Verification: what the network actually sees, including power state.
function StressTest.status()
    local lines = {}

    for _, source in pairs((storage.stressTest and storage.stressTest.powerSources) or {}) do
        if source ~= nil and source.valid == true and source.type == "electric-energy-interface" then
            lines[#lines + 1] = string.format("power production=%.0f consumption=%.0f",
                source.power_production or 0,
                source.power_usage or 0)
        end
    end

    for _, obj in pairs(storage.entityTable or {}) do
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true
            and obj.thisEntity.name == Constants.NetworkController.main.name then
            local members = 0
            for _ in pairs(obj.network.connectedEntities or {}) do members = members + 1 end
            lines[#lines + 1] = string.format("NC %d members=%d powerDraw=%s energy=%.0f buffer=%.0f stable=%s",
                obj.entID, members, tostring(obj.network.powerDraw),
                obj.thisEntity.energy or 0,
                obj.thisEntity.electric_buffer_size or 0,
                tostring(obj.stable))
        end
    end

    if #lines == 0 then return "nothing to report" end
    return table.concat(lines, "\n")
end

function StressTest.clear()
    local record = (storage.stressTest and storage.stressTest.entities) or {}
    local wanted = {}
    for _, unit in pairs(record) do
        wanted[unit] = true
    end

    --The mod's own removal runs first, so its bookkeeping stays consistent.
    --Destroying the entity alone would leave stale objects behind, because
    --LuaEntity::destroy does not raise the event the mod listens for while the
    --entity is still valid.
    local removed = 0
    for unit in pairs(wanted) do
        local obj = (storage.entityTable or {})[unit]
        if obj ~= nil and obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            if obj.remove ~= nil then pcall(function() obj:remove() end) end
            if obj.thisEntity.valid == true then obj.thisEntity.destroy() end
            removed = removed + 1
        end
    end

    --Vanilla power entities are not in the mod's table, so they are held by
    --reference instead of by unit number.
    for _, source in pairs((storage.stressTest and storage.stressTest.powerSources) or {}) do
        if source ~= nil and source.valid == true then
            source.destroy()
            removed = removed + 1
        end
    end

    if storage.stressTest ~= nil then
        storage.stressTest.entities = {}
        storage.stressTest.powerSources = {}
    end
    return "removed " .. removed .. " entities"
end
