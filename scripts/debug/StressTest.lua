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

local SPINE_START = 2       -- first cable offset east of the controller
local DRIVE_FIRST = 2       -- first cable index that carries a drive
local STATION_MARGIN = 40   -- gap between two stations' cable spines
local PLAYER_CLEARANCE = 20 -- tiles between the player and the first controller
local BUS_SPACING = 2       -- columns between two bus stubs on the same spine
local BUS_FILL = 4800       -- one steel chest of a 100-stack item

--Dosed drain on the external containers. In the build as it stands the containers
--never change, so the cheap skip in EIO:update fires on every sweep -- the best
--case for it. A machine drawing from a container makes the total move, and the
--skip then fires less often. The rate here is exact, which the real thing never is,
--and it is given per container so it does not shift when the bus count changes.
local drainRate = 0         -- items per second per container
local drainRemainder = 0
local drainTaken = 0
local drainIndex = 0

--Filtered against the active prototypes, so mod sets that drop one simply
--contribute fewer types.
local FILL_ITEMS = {
    "iron-plate", "copper-plate", "steel-plate", "iron-gear-wheel",
    "copper-cable", "electronic-circuit", "advanced-circuit",
    "processing-unit", "plastic-bar", "sulfur", "battery",
    "engine-unit", "electric-engine-unit", "low-density-structure",
    "rocket-fuel", "explosive-cannon-shell",
}

local function place(surface, force, player, name, position, record, direction)
    local entity = surface.create_entity{
        name = name,
        position = position,
        force = force,
        direction = direction,
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

--A freshly built bus does nothing on its own, and each of the two kinds fails
--differently:
--  * Item IO in export mode runs only when filters.max is non-zero
--    (ItemIOV3.lua:522), and it builds its master stack from the filter list
--    (ItemIOV3.lua:525). Without a filter the bus is inert; with an index of 0 it
--    would index a nil master. So a filter is not optional here.
--  * External IO skips every unmodified stack by default (onlyModified,
--    ExternalIO.lua:24, applied in NetworkBase.lua:1187). A stress network holds
--    unmodified items, so the bus would read the container and transfer nothing.
local function configureItemBus(obj, itemName)
    obj.guiFilters[1] = itemName
    obj.filters = {
        index = 1,
        max = 1,
        values = {[1] = itemName, [itemName] = true}
    }
end

local function configureExternalBus(obj)
    obj.onlyModified = false
end

--Finds the containers to draw from: every external bus reads one, and that is the
--container whose changing total defeats the cheap skip.
--Discovered at setDrain time rather than taken from the build record, because a
--save built before this tool existed carries no such record -- and a drain that
--silently does nothing reads as "the rate has no effect", which is exactly the
--wrong conclusion and exactly what happened on the first attempt.
local function discoverDrainTargets()
    local targets = {}
    local itemName = nil
    for _, obj in pairs(storage.entityTable or {}) do
        local name = nil
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            name = obj.thisEntity.name
        end
        if name == Constants.NetworkCables.externalIO.name and obj.focusedEntity ~= nil then
            local container = obj.focusedEntity.thisEntity
            if container ~= nil and container.valid == true then
                targets[#targets + 1] = container
                if itemName == nil and obj.focusedEntity.inventory.output.values[1] ~= nil then
                    local inv = container.get_inventory(obj.focusedEntity.inventory.output.values[1])
                    if inv ~= nil then
                        for _, stack in pairs(inv.get_contents()) do
                            itemName = stack.name
                            break
                        end
                    end
                end
            end
        end
    end
    return targets, itemName
end

--Sets the drain rate, finds the containers and zeroes the bus skip counters, so
--before and after are compared over the same window instead of as a difference of
--monotonic totals.
function StressTest.setDrain(ratePerContainer)
    drainRate = math.max(0, ratePerContainer or 0)
    drainRemainder = 0
    drainTaken = 0
    drainIndex = 0

    local targets, itemName = discoverDrainTargets()
    storage.stressTest = storage.stressTest or {}
    storage.stressTest.drainChests = targets
    storage.stressTest.busItem = itemName

    local zeroed = 0
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.skippedSweeps ~= nil then
            obj.skippedSweeps = 0
            obj.readSweeps = 0
            zeroed = zeroed + 1
        end
    end

    return string.format("drain=%.2f items/s per container, found=%d containers, item=%s, skip counters zeroed on %d buses",
        drainRate, #targets, tostring(itemName), zeroed)
end

--Takes the drained items out of the containers. Called from the mod's own tick.
function StressTest.tick()
    if drainRate <= 0 then return end

    local state = storage.stressTest or {}
    local targets = state.drainChests or {}
    local count = #targets
    local itemName = state.busItem
    if count == 0 or itemName == nil then return end

    drainRemainder = drainRemainder + (drainRate * count) / 60
    local take = math.floor(drainRemainder)
    if take <= 0 then return end
    drainRemainder = drainRemainder - take

    for _ = 1, take do
        drainIndex = drainIndex % count + 1
        local chest = targets[drainIndex]
        if chest ~= nil and chest.valid == true then
            local inv = chest.get_inventory(defines.inventory.chest)
            --No pcall on purpose: a drain that silently does nothing would read as
            --"the rate has no effect" and send the next step the wrong way.
            drainTaken = drainTaken + inv.remove{name = itemName, count = 1}
        end
    end
end

function StressTest.drainStatus()
    local state = storage.stressTest or {}
    local rate = drainRate
    return string.format("drain=%.2f items/s per container, containers=%d, removed=%d, item=%s",
        rate, #(state.drainChests or {}), drainTaken, tostring(state.busItem))
end

function StressTest.build(stationCount, drivesPerStation, busesPerStation, busKind)
    local player = game.player
    if player == nil then return "no player" end
    local surface = player.surface
    local force = player.force

    local record = {}
    local powerSources = {}
    local chests = {}
    local stats = {controllers = 0, drives = 0, cables = 0, grids = 0, power = 0,
        buses = 0, itemBuses = 0, externalBuses = 0, filledChests = 0,
        busUnregistered = 0, failed = 0}
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

    --The footprint grows with the number of drives, so the spacing has to as
    --well. A fixed gap let two cable spines overlap in an earlier version, and
    --touching networks make each controller mark the other for deconstruction,
    --which stops its refresh before it ever fills its member list.
    local spineLength = DRIVE_FIRST + drivesPerStation * 2
    local spacing = SPINE_START + spineLength + STATION_MARGIN

    --Bus columns have to fit next to the spine, and the spine grows with the
    --drive count, so the two are linked. That is a limitation of this fixture,
    --not of the mod: bus count and drive count cannot be varied independently.
    --A stub sits at spine index 3 + (b-1)*BUS_SPACING, and the last one has to
    --stay inside the spine, or the bus would have nothing to connect to.
    local maxBuses = math.floor((spineLength - 4) / BUS_SPACING) + 1
    local buses = math.min(busesPerStation or 0, maxBuses)
    if (busesPerStation or 0) > buses then
        notes[#notes + 1] = "bus count reduced to " .. buses .. " of " .. busesPerStation
            .. ": only " .. maxBuses .. " columns fit at " .. drivesPerStation .. " drives per station"
    end

    --Which kind of bus to build. The two sides cost differently and the plan
    --scopes them as separate milestones, so a measurement that mixes them cannot
    --say which one to attack. "mixed" is the original behaviour.
    local kind = busKind or "mixed"
    if kind ~= "mixed" and kind ~= "item" and kind ~= "external" then
        notes[#notes + 1] = "unknown bus kind '" .. kind .. "', using mixed"
        kind = "mixed"
    end

    --The item the buses move. It has to be one the fill also puts into the drives,
    --otherwise the export side has nothing to push out.
    local busItem = nil
    for _, candidate in pairs(FILL_ITEMS) do
        if prototypes.item[candidate] ~= nil then busItem = candidate break end
    end
    if buses > 0 and busItem == nil then
        notes[#notes + 1] = "no fill item available for the buses"
        buses = 0
    end

    for station = 1, stationCount do
        local cx = baseX + (station - 1) * spacing
        local cy = baseY

        --Power. The substation touches the controller's west side, so the
        --controller sits well inside the 18x18 supply area. The interface
        --produces with power_production alone; LuaEntity has no readable mode
        --property, so nothing else is set here.
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

        --Bus columns hang off the south side of the spine, so the geometry above
        --stays untouched. Per column: a stub cable, the bus facing south, and its
        --target one tile further south. The port points away from the spine, and
        --BaseNet.generateArms skips exactly the port direction, so the network
        --side stays free to connect.
        for b = 1, buses do
            local bx = cx + SPINE_START + 1 + (b - 1) * BUS_SPACING

            if place(surface, force, player, cableName, {bx, cy + 1}, record) ~= nil then
                stats.cables = stats.cables + 1
            else
                stats.failed = stats.failed + 1
            end

            --Alternating kinds in the default build, so both directions run in the
            --same save: the item bus pushes out of the network, the external bus
            --pulls its container into the network. A single kind can be forced to
            --separate the two costs.
            local isExternal = (kind == "external") or (kind == "mixed" and b % 2 == 0)
            local busName = isExternal and Constants.NetworkCables.externalIO.name
                or Constants.NetworkCables.itemIO.name
            local bus = place(surface, force, player, busName, {bx, cy + 2}, record, defines.direction.south)
            if bus == nil then
                stats.failed = stats.failed + 1
            else
                stats.buses = stats.buses + 1
                local obj = storage.entityTable[bus.unit_number]
                if obj == nil then
                    stats.busUnregistered = stats.busUnregistered + 1
                elseif isExternal then
                    configureExternalBus(obj)
                    stats.externalBuses = stats.externalBuses + 1
                else
                    configureItemBus(obj, busItem)
                    stats.itemBuses = stats.itemBuses + 1
                end
            end

            --The container. The external bus reads it, so it holds something; the
            --item bus writes into it, so it starts empty.
            local chest = place(surface, force, player, "steel-chest", {bx, cy + 3}, nil)
            if chest == nil then
                stats.failed = stats.failed + 1
            else
                chests[#chests + 1] = chest
                if isExternal then
                    chest.get_inventory(defines.inventory.chest).insert{name = busItem, count = BUS_FILL}
                    stats.filledChests = stats.filledChests + 1
                end
            end
        end
    end

    if stats.busUnregistered > 0 then
        notes[#notes + 1] = stats.busUnregistered .. " buses were not registered by the mod"
    end

    --Appended across builds, so a later build does not forget the earlier
    --entities and leave them in the world.
    storage.stressTest = storage.stressTest or {}
    local allEntities = storage.stressTest.entities or {}
    for _, unit in pairs(record) do allEntities[#allEntities + 1] = unit end
    storage.stressTest.entities = allEntities

    local allPower = storage.stressTest.powerSources or {}
    for _, entity in pairs(powerSources) do allPower[#allPower + 1] = entity end
    storage.stressTest.powerSources = allPower

    local allChests = storage.stressTest.chests or {}
    for _, entity in pairs(chests) do allChests[#allChests + 1] = entity end
    storage.stressTest.chests = allChests

    --Did the mod actually pick the entities up? Anything missing means the
    --placement handler rejected or destroyed it.
    local registered = 0
    for _, unit in pairs(record) do
        if (storage.entityTable or {})[unit] ~= nil then
            registered = registered + 1
        end
    end

    local summary = string.format(
        "stations=%d controllers=%d drives=%d cables=%d grids=%d power=%d buses=%d(%s) itemBuses=%d externalBuses=%d filledChests=%d failed=%d registered=%d",
        stationCount, stats.controllers, stats.drives, stats.cables, stats.grids,
        stats.power, stats.buses, kind, stats.itemBuses, stats.externalBuses,
        stats.filledChests, stats.failed, registered)
    if #notes > 0 then
        summary = summary .. "\n" .. table.concat(notes, "\n")
    end
    --Read this against the members column of /rns-stress-status. Anything else
    --means part of the build did not join the network, and the stage is unusable.
    local expectedMembers = drivesPerStation + spineLength + 2 * buses + 2
    summary = summary .. "\nexpected members per controller: " .. expectedMembers
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
                local room = obj:getRemainingStorageSize()
                if room <= 0 then break end
                local name = available[t]
                local template = Itemstack.create_template(name)
                if template ~= nil then
                    --Two things this stack has to get right.
                    --Its count: add_or_merge_basic_item stores the first stack as
                    --given but adds `amount` to storedAmount, so a placeholder
                    --count of 1 makes the drive claim a full load while holding a
                    --single item.
                    --Its shape: the real insert path stores a copy, and Util.copy
                    --collapses an empty table to nil, so an inserted stack carries
                    --neither tags nor extras. create_template leaves both as empty
                    --tables, and driving on that shape yields drives the game never
                    --produces. Extraction by clicking the network display then fails
                    --silently, because the exact comparison reaches
                    --compare_tags(nil, {}) and that is false.
                    local chunk = math.min(amountPerType, room)
                    template = template:copy()
                    template.count = chunk
                    added = added + obj:add_or_merge_basic_item(template, chunk)
                end
            end
        end
    end

    --The fill writes straight into the drives' own tables, so the network
    --bookkeeping never sees any of it. Ask the affected controllers for one
    --rebuild, otherwise the first controller dump after a fill reports empty
    --counters and the acceptance comparison measures the fixture, not the code.
    local requested = 0
    local flagged = {}
    for _, obj in pairs(storage.entityTable or {}) do
        local controller = obj.networkController
        if controller ~= nil and controller.entID ~= nil and controller.network ~= nil
            and flagged[controller.entID] == nil then
            flagged[controller.entID] = true
            controller.network.shouldRefresh = true
            requested = requested + 1
        end
    end

    return string.format("drives=%d typesEach=%d amountEach=%d inserted=%d rebuildRequested=%d",
        drives, types, amountPerType, added, requested)
end

--The buses are only useful if they found a target and joined a network. Both are
--set up by code and both can fail silently: a bus with no target does nothing,
--and a bus that never joined a network gets no update.
local BUS_NAMES = {
    [Constants.NetworkCables.itemIO.name] = true,
    [Constants.NetworkCables.fluidIO.name] = true,
    [Constants.NetworkCables.externalIO.name] = true,
}

--Verification: what the network actually sees, including power state.
function StressTest.status()
    local lines = {}

    local busTotal, busWithTarget, busInNetwork = 0, 0, 0
    for _, obj in pairs(storage.entityTable or {}) do
        local name = nil
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            name = obj.thisEntity.name
        end
        if name ~= nil and BUS_NAMES[name] == true and obj.focusedEntity ~= nil then
            busTotal = busTotal + 1
            if obj.focusedEntity.thisEntity ~= nil and obj.focusedEntity.thisEntity.valid == true then
                busWithTarget = busWithTarget + 1
            end
            if obj.networkController ~= nil
                and BaseNet.exists_in_network(obj.networkController, obj.entID) then
                busInNetwork = busInNetwork + 1
            end
        end
    end
    if busTotal > 0 then
        lines[#lines + 1] = string.format("buses total=%d withTarget=%d inNetwork=%d",
            busTotal, busWithTarget, busInNetwork)
    end

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
            --A controller marked for deconstruction skips its whole refresh, so
            --this is the first thing to check when members stays at zero.
            lines[#lines + 1] = string.format("NC %d members=%d powerDraw=%s energy=%.0f buffer=%.0f stable=%s deconstructed=%s",
                obj.entID, members, tostring(obj.network.powerDraw),
                obj.thisEntity.energy or 0,
                obj.thisEntity.electric_buffer_size or 0,
                tostring(obj.stable),
                tostring(obj.thisEntity.to_be_deconstructed()))
        end
    end

    if #lines == 0 then return "nothing to report" end
    return table.concat(lines, "\n")
end

--Removes every mod entity that is marked for deconstruction. Broken stress
--builds end up in that state: when two cable spines overlap, each controller
--marks the other for deconstruction, so those builds are dead weight that
--rns-stress-clear cannot reach (they predate the build record).
--Bookkeeping entries are dropped directly instead of through obj:remove(),
--because that would rebuild the arms of every neighbour, which is needlessly
--expensive for thousands of entities at once. Stale references elsewhere are
--handled by the existing valid() checks.
function StressTest.purge()
    local dead = {}
    for unit, obj in pairs(storage.entityTable or {}) do
        --The entity table also holds player objects, whose thisEntity is a
        --LuaPlayer. Factorio raises on any unknown key access, so a plain
        --nil check cannot tell the two apart; pcall is the reliable test.
        local ok, flagged = pcall(function()
            return obj.thisEntity ~= nil
                and obj.thisEntity.valid == true
                and obj.thisEntity.to_be_deconstructed() == true
        end)
        if ok and flagged then
            dead[#dead + 1] = unit
        end
    end

    local removed = 0
    for _, unit in pairs(dead) do
        local obj = storage.entityTable[unit]
        if obj ~= nil then
            if obj.thisEntity ~= nil and obj.thisEntity.valid == true then
                obj.thisEntity.destroy()
                removed = removed + 1
            end
            storage.entityTable[unit] = nil
            storage.updateTable[unit] = nil
            storage.NetworkControllers[unit] = nil
        end
    end

    return "purged " .. removed .. " entities marked for deconstruction"
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

    --Same for the bus containers.
    for _, chest in pairs((storage.stressTest and storage.stressTest.chests) or {}) do
        if chest ~= nil and chest.valid == true then
            chest.destroy()
            removed = removed + 1
        end
    end

    if storage.stressTest ~= nil then
        storage.stressTest.entities = {}
        storage.stressTest.powerSources = {}
        storage.stressTest.chests = {}
    end
    return "removed " .. removed .. " entities"
end
