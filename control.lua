GUI = GUI or {}
Event = Event or {}
UpdateSys = UpdateSys or {}
Migrate = Migrate or {}

Constants = require("utils.constants")
require("utils.Util")
require("scripts.Events")
require("scripts.Functions")
require("scripts.updates")
require("scripts.gui.Gui")
require("scripts.gui.GuiApi")
require("scripts.objects.WirelessGrid")
require("scripts.objects.WirelessTransmitter")
require("scripts.objects.TransReceiver")
require("scripts.objects.Detector")
require("scripts.objects.NetworkBase")
require("scripts.objects.NetworkController")
require("scripts.objects.RNSPlayer")
require("scripts.objects.NetworkCables")
require("scripts.objects.NetworkCableUnderground")
require("scripts.objects.ItemStore")
require("scripts.objects.Itemstack")
require("scripts.debug.StressTest")
require("scripts.objects.ItemIOV3")
require("scripts.objects.FluidIO")
require("scripts.objects.ExternalIO")
require("scripts.objects.ItemDrives")
require("scripts.objects.FluidDrives")
require("scripts.objects.NetworkInventoryInterface")
require("scripts.migration.migrate")

--When the mod is added in a save
function onInit()
    local freeplay = remote.interfaces["freeplay"]
    --[[if freeplay then  -- Disable freeplay popup-message
        if freeplay["set_skip_intro"] then remote.call("freeplay", "set_skip_intro", true) end
        if freeplay["set_disable_crashsite"] then remote.call("freeplay", "set_disable_crashsite", true) end
    end]]
	storage.allowMigration = ( next(storage) ~= nil )
    storage.migrations = storage.migrations or {}

	storage.entityTable = storage.entityTable or {}
    storage.updateTable = storage.updateTable or {}
    storage.IIOMultiplier = storage.IIOMultiplier or 1
    storage.FIOMultiplier = storage.FIOMultiplier or 1
    storage.WTRangeMultiplier = storage.WTRangeMultiplier or 1
    storage.TransReceiverChannels = storage.TransReceiverChannels or {transmitters = {}, receivers = {}}
    storage.NetworkControllers = storage.NetworkControllers or {}
    
    createObjectTables()

    for _, obj in pairs(storage.objectTables) do
		if obj.tableName and obj.tag then
			if _G[obj.tag] ~= nil then
                if _G[obj.tag].validate then
                    for _, entry in pairs(storage[obj.tableName]) do
                        entry:validate()
                    end
                end
                if obj.tag == "NC" then
                    for _, entry in pairs(storage[obj.tableName]) do
                        entry.network.shouldRefresh = true
                    end
                end
			end
		end
	end

    if storage.playerTable == nil then storage.playerTable = {} end
	for _, player in pairs(game.players) do
		Event.initPlayer({player_index = player.index})
	end

    Migrate.setup()
end

--When the mod loads up in a save
function onLoad()
    for _, obj in pairs(storage.objectTables) do
		if obj.tableName ~= nil and obj.tag ~= nil and _G[obj.tag] ~= nil then
			for _, entry in pairs(storage[obj.tableName] or {}) do
				_G[obj.tag]:rebuild(entry)
			end
		end
    end
    --for id, obj in pairs(storage.tempInventoryTable) do
    --    if not obj.itemstack.valid or obj.itemstack == nil then
    --        storage.tempInventoryTable[id] = nil
    --    end
    --end
end

--When a player is created
function initPlayer(event)
    if Util.safeCall(Event.initPlayer, event) == true then
		if event.player_index ~= nil and game.players[event.player_index] ~= nil and game.players[event.player_index].name ~= nil then
			game.print({"gui-description.RNS_initAPlayer_PlayerInitFailed", game.players[event.player_index].name})
		else
			game.print({"gui-description.RNS_initAPlayer_PlayerInitFailed", {"gui-description.RNS_Unknown"}})
		end
	end
end

function onTick(event)
    Util.safeCall(Event.tick, event)
end

--[[function pipette(event)
	if Util.safeCall(Event.pipette, event) == false then
        game.print({"gui-description.RNS_pipette_failed"})
        local entity = event.created_entity or event.entity or event.destination
        if entity ~= nil and entity.valid == true then
            entity.destroy()
        end
    end
end]]

function placed(event)
    if Util.safeCall(Event.placed, event) == false then
        game.print({"gui-description.RNS_placed_failed"})
        local entity = event.created_entity or event.entity or event.destination
        if entity ~= nil and entity.valid == true then
            entity.destroy()
        end
    end
end

function rotated(event)
    Util.safeCall(Event.rotated, event)
end
function changed_selection(event)
    Util.safeCall(Event.changed_selection, event)
end

function removed(event)
    Util.safeCall(Event.removed, event)
end

function onGuiOpened(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    Util.safeCall(GUI.on_gui_opened, event)
end

function onGuiClosed(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    Util.safeCall(GUI.on_gui_closed, event)
end

function onGuiClicked(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    if Util.safeCall(GUI.on_gui_clicked, event) == false then
		getPlayer(event.player_index).print({"gui-description.RNS_update_gui_failed"})
		Util.safeCall(Event.clear_gui, event)
	end
end

function onGuiElemChanged(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    if event.element == nil or event.element.valid == false then return end
	if Util.safeCall(GUI.on_gui_element_changed, event) == false then
		getPlayer(event.player_index).print({"gui-description.RNS_update_gui_failed"})
		Util.safeCall(Event.clear_gui, event)
	end
end

function onBlueprintSetup(event)
	Util.safeCall(Event.onBlueprintSetup, event)
end

function onBlueprintConfigured(event)
	Util.safeCall(Event.onBlueprintConfigured, event)
end

function onSettingsPasted(event)
    Util.safeCall(Event.onSettingsPasted, event)
end

function finished_research(event)
    Util.safeCall(Event.finished_research, event)
end

function reversed_research(event)
    Util.safeCall(Event.reversed_research, event)
end

function on_marked_for_deconstruction(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    Util.safeCall(Event.on_marked_for_deconstruction, event)
end

function on_cancelled_deconstruction(event)
    --if event.element.get_mod() ~= Constants.MOD_ID then return end
    Util.safeCall(Event.on_cancelled_deconstruction, event)
end

script.on_init(onInit)
script.on_configuration_changed(onInit)
script.on_load(onLoad)

script.on_event(defines.events.on_cutscene_cancelled, initPlayer)
script.on_event(defines.events.on_player_created, initPlayer)
script.on_event(defines.events.on_player_joined_game, initPlayer)
script.on_event(defines.events.on_tick, onTick)

script.on_event(defines.events.on_research_finished, finished_research)
script.on_event(defines.events.on_research_reversed, reversed_research)

script.on_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
script.on_event(defines.events.on_cancelled_deconstruction, on_cancelled_deconstruction)

script.on_event(defines.events.on_built_entity, placed)
script.on_event(defines.events.on_player_built_tile, placed)
script.on_event(defines.events.script_raised_built, placed)
script.on_event(defines.events.script_raised_revive, placed)
script.on_event(defines.events.on_robot_built_entity, placed)
script.on_event(defines.events.on_robot_built_tile, placed)

script.on_event(defines.events.on_entity_cloned, placed)

script.on_event(defines.events.on_player_mined_entity, removed)
script.on_event(defines.events.on_player_mined_tile, removed)
script.on_event(defines.events.on_robot_mined_entity, removed)
script.on_event(defines.events.on_robot_mined_tile, removed)
script.on_event(defines.events.script_raised_destroy, removed)
script.on_event(defines.events.on_entity_died, removed)

script.on_event(defines.events.on_player_rotated_entity , rotated)
script.on_event(defines.events.on_selected_entity_changed, changed_selection)

script.on_event(defines.events.on_lua_shortcut, function(event)
    local player = getPlayer(event.player_index)
    if event.prototype_name == Constants.Settings.RNS_Player_Port_Shortcut then
        player.set_shortcut_toggled(Constants.Settings.RNS_Player_Port_Shortcut, not player.is_shortcut_toggled(Constants.Settings.RNS_Player_Port_Shortcut))
    end
end)

script.on_event(defines.events.on_gui_opened, onGuiOpened)
script.on_event(defines.events.on_gui_closed, onGuiClosed)
script.on_event(defines.events.on_gui_click, onGuiClicked)

script.on_event(defines.events.on_gui_elem_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_checked_state_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_selection_state_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_text_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_switch_state_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_selected_tab_changed, onGuiElemChanged)
script.on_event(defines.events.on_gui_value_changed, onGuiElemChanged)

script.on_event(defines.events.on_player_setup_blueprint, onBlueprintSetup)
script.on_event(defines.events.on_player_configured_blueprint, onBlueprintConfigured)
script.on_event(defines.events.on_entity_settings_pasted, onSettingsPasted)

--What the member drives actually hold, read from their own storage tables, next
--to what they claim through storedAmount. The two are maintained by different
--code paths, and a network-level comparison is meaningless while they disagree:
--a difference here means the drives are already inconsistent on their own.
local function driveTotals(network)
    local drives, claimed, actual = 0, 0, 0
    local fluidClaimed, fluidActual = 0, 0
    for _, obj in pairs(network.connectedEntities or {}) do
        if obj.storageArray ~= nil then
            drives = drives + 1
            claimed = claimed + (obj.storedAmount or 0)
            for _, stack in pairs(obj.storageArray) do
                actual = actual + (stack.count or 0)
            end
        elseif obj.fluidArray ~= nil then
            fluidClaimed = fluidClaimed + (obj.storedAmount or 0)
            for _, fluid in pairs(obj.fluidArray) do
                fluidActual = fluidActual + (fluid.amount or 0)
            end
        end
    end
    return drives, claimed, actual, fluidClaimed, fluidActual
end

--What the external buses cache next to what their containers actually hold. The
--controller rebuild reads the cache, not the container (NetworkBase.addConnectables
--calls init_cache, which keeps an existing cache), so a stale cache looks
--self-consistent in any two dumps. This is the only place the two are compared.
local function externalTotals(network)
    local buses, cached, actual = 0, 0, 0
    local skipped, read = 0, 0
    --Distinct item types actually in the containers. The network's tracked type
    --count only ever grows (a key that reaches zero stays), so it cannot tell
    --whether a container picked up a type the fill never put there. This can.
    local actualTypes = {}
    for _, obj in pairs(network.connectedEntities or {}) do
        if obj.cache ~= nil and obj.type == "item" then
            buses = buses + 1
            skipped = skipped + (obj.skippedSweeps or 0)
            read = read + (obj.readSweeps or 0)
            for i = 1, #obj.cache do
                local entry = obj.cache[i]
                if entry ~= nil and entry.name ~= "RNS_Empty" then
                    cached = cached + (entry.count or 0)
                end
            end
            local focused = obj.focusedEntity ~= nil and obj.focusedEntity.thisEntity or nil
            if focused ~= nil and focused.valid == true then
                for _, invIndex in pairs(obj.focusedEntity.inventory.output.values or {}) do
                    local inv = focused.get_inventory(invIndex)
                    if inv ~= nil then
                        actual = actual + inv.get_item_count()
                        for _, stack in pairs(inv.get_contents()) do
                            if stack.count > 0 then actualTypes[stack.name] = true end
                        end
                    end
                end
            end
        end
    end
    local typeCount = 0
    for _ in pairs(actualTypes) do typeCount = typeCount + 1 end
    return buses, cached, actual, skipped, read, typeCount
end

--Reports the fast-scan mode and the per-bus counters, summed over the base. The
--counters are monotonic, so two dumps are read as a difference; toggling the mode
--zeroes them so a run is measured over one window.
local function busScanStatus()
    local hits, full = 0, 0
    for _, obj in pairs(storage.entityTable or {}) do
        hits = hits + (obj.fastScanHits or 0)
        full = full + (obj.fastScanFull or 0)
    end
    return string.format("busScan=%s hits=%d full=%d",
        tostring(Constants.Settings.RNS_ExternalBus_FastScan), hits, full)
end

--Builds the counter dump for a single network controller. Shared by /rns-debug
--and /rns-debug-nc, so the two can never drift apart.
local function controllerCounterLine(obj)
    local network = obj.network
    local members = 0
    for _ in pairs(network.connectedEntities or {}) do members = members + 1 end

    --Sum and key count are reported separately: a growing key count with a flat
    --sum means zero entries pile up instead of dropping out.
    local trackedItems = 0
    local trackedTypes = 0
    for _, count in pairs(network.Contents.item or {}) do
        trackedItems = trackedItems + count
        trackedTypes = trackedTypes + 1
    end

    local cachedStacks = 0
    for _, list in pairs(network.interfaceCache.item or {}) do
        cachedStacks = cachedStacks + #list
    end

    local partition = network.StoredPartition or {}
    local drive = partition.itemDrive or {}
    local external = partition.itemExternal or {}
    local driveCount, driveClaimed, driveActual, fluidClaimed, fluidActual = driveTotals(network)
    local busCount, busCached, busActual, busSkipped, busRead, busTypes = externalTotals(network)

    return "NC " .. obj.entID
        .. " members=" .. members
        .. " shouldRefresh=" .. tostring(network.shouldRefresh)
        .. " powerDraw=" .. tostring(network.powerDraw)
        .. " tracked=" .. trackedItems .. "/" .. trackedTypes
        .. " cache=" .. cachedStacks
        .. " drive=" .. tostring(drive.storedAmount) .. "/" .. tostring(drive.capacity)
        .. " external=" .. tostring(external.storedAmount) .. "/" .. tostring(external.capacity)
        .. " truth=" .. driveCount .. "/" .. driveClaimed .. "/" .. driveActual
        .. " fluidTruth=" .. fluidClaimed .. "/" .. fluidActual
        .. " busTruth=" .. busCount .. "/" .. busCached .. "/" .. busActual
        .. " busTypes=" .. busTypes
        .. " busSkips=" .. busSkipped .. "/" .. (busSkipped + busRead)
end

--Debug command: dumps the network bookkeeping from inside the mod.
--The console runs in its own storage and cannot see ours; this can.
commands.add_command("rns-debug", "RNSRedux: dump network and interface state", function()
    local lines = {}
    local total = 0
    for _ in pairs(storage.entityTable or {}) do total = total + 1 end
    table.insert(lines, "entityTable entries: " .. total)

    for _, obj in pairs(storage.entityTable or {}) do
        if obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            local name = obj.thisEntity.name
            if name == Constants.NetworkController.main.name then
                table.insert(lines, controllerCounterLine(obj))
            elseif name == Constants.NetworkInventoryInterface.name then
                local hasController = obj.networkController ~= nil
                local inNetwork = false
                if hasController then
                    inNetwork = BaseNet.exists_in_network(obj.networkController, obj.entID)
                end
                table.insert(lines, "NII " .. obj.entID
                    .. " ctrl=" .. tostring(hasController)
                    .. " inNetwork=" .. tostring(inNetwork))
            elseif string.match(name, "RNS_ItemDrive") ~= nil or string.match(name, "RNS_FluidDrive") ~= nil then
                table.insert(lines, "Drive " .. obj.entID
                    .. " ctrl=" .. tostring(obj.networkController ~= nil)
                    .. " stored=" .. tostring(obj.storedAmount))
            end
        end
    end

    for _, player in pairs(game.players) do
        local inv = player.get_main_inventory()
        local filled = 0
        local slots = -1
        if inv ~= nil then
            slots = #inv
            for i = 1, slots do
                local stack = inv[i]
                if stack ~= nil and stack.valid_for_read and stack.count > 0 then
                    filled = filled + 1
                end
            end
        end
        table.insert(lines, "player " .. player.name .. " slots=" .. slots .. " filled=" .. filled)
    end

    game.print(table.concat(lines, "\n"))
end)

--Debug command: forces the periodic full rebuild on every network right now.
--Run /rns-debug, then this, then /rns-debug again. Both dumps have to match,
--because the rebuild restores exactly the state the incremental bookkeeping
--maintains. The comparison only holds while nothing is being transferred, so
--use a filled network without running machines. The controller is identified
--by its network reference, not by thisEntity: that field can hold a LuaPlayer,
--whose key lookups raise.
commands.add_command("rns-debug-refresh", "RNSRedux: force a network rebuild on every controller", function()
    local rebuilt = 0
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.network ~= nil then
            obj.network:doRefresh(obj)
            rebuilt = rebuilt + 1
        end
    end
    game.print("rns-debug-refresh: rebuilt " .. rebuilt .. " controllers")
end)

--Debug command: pulls items out of a network without going through the GUI. The
--GUI path runs through NII.interaction, whose element tags and click modifiers
--cannot be inspected from outside; this calls the transfer itself, so a silent
--stop there is distinguishable from a click that never arrived.
--It also prints the three values that decide whether the transfer does anything
--at all: can_insert, the free slots and the free amount for that item. Those are
--where the code stops without a message.
--Usage: /rns-debug-extract [item] [count] -- defaults to the first tracked item
--and a count of 1.
commands.add_command("rns-debug-extract", "RNSRedux: extract items from a network without the GUI", function(event)
    local player = game.players[event.player_index]
    if player == nil then return end

    local controller = nil
    for _, candidate in pairs(storage.NetworkControllers or {}) do
        if candidate.network ~= nil then controller = candidate break end
    end
    if controller == nil then
        game.print("rns-debug-extract: no controller")
        return
    end
    local network = controller.network

    local name, countText = string.match(event.parameter or "", "^(%S+)%s*(%d*)$")
    local count = tonumber(countText) or 1
    if name == nil then
        for trackedName in pairs(network.Contents.item or {}) do name = trackedName break end
    end
    if name == nil then
        game.print("rns-debug-extract: network tracks nothing")
        return
    end

    local inventory = player.get_inventory(defines.inventory.character_main)
    local master = Itemstack.create_template(name)
    if master == nil then
        game.print("rns-debug-extract: no prototype for '" .. name .. "'")
        return
    end
    --Use the shape the real insert path stores. create_template leaves tags and
    --extras as empty tables, an inserted stack carries neither, and the exact
    --comparison treats an empty table and nil as different. Without this the
    --command only matches drives filled by the stress build -- which have the same
    --unnatural shape -- and fails on a network filled by playing.
    master = master:copy()
    master.count = count

    local networkBefore = network.Contents.item[name] or 0
    local playerBefore = inventory.get_item_count(name)

    --Deliberately no pcall: if one of these raises, the exception is the finding.
    game.print("rns-debug-extract: " .. name .. " want=" .. count
        .. " can_insert=" .. tostring(inventory.can_insert(name))
        .. " emptyStacks=" .. inventory.count_empty_stacks(true, false)
        .. " insertable=" .. inventory.get_insertable_count(name)
        .. " network=" .. networkBefore .. " player=" .. playerBefore)

    local wrapper = {
        thisEntity = player,
        inventory = {input = {index = 1, max = 1, values = {defines.inventory.character_main}}}
    }
    local left = BaseNet.transfer_from_network_to_inv(network, wrapper, master, count, true, true, true)

    local driveCount, driveClaimed, driveActual = driveTotals(network)
    game.print("rns-debug-extract: left=" .. tostring(left)
        .. " network " .. networkBefore .. "->" .. (network.Contents.item[name] or 0)
        .. " player " .. playerBefore .. "->" .. inventory.get_item_count(name)
        .. " drive=" .. tostring(network.StoredPartition.itemDrive.storedAmount)
        .. " truth=" .. driveCount .. "/" .. driveClaimed .. "/" .. driveActual)
end)

--Debug command: the same controller counters without the per-entity noise. Two
--runs of this fit on one screen, which a full /rns-debug dump does not.
commands.add_command("rns-debug-nc", "RNSRedux: dump only the controller counters", function()
    local entries = {}
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.network ~= nil then
            entries[#entries + 1] = {id = obj.entID, text = controllerCounterLine(obj)}
        end
    end
    if #entries == 0 then
        game.print("rns-debug-nc: no controllers")
        return
    end

    table.sort(entries, function(a, b) return a.id < b.id end)
    local lines = {}
    for _, entry in pairs(entries) do
        lines[#lines + 1] = entry.text
    end
    local text = table.concat(lines, "\n")
    game.print(text)
    --The drain total goes into the header, so every dump carries the one number the
    --next run needs to tell "the drain ran and the container refilled" from "the
    --drain stopped". Comparing two dumps by hand was the gap that made the previous
    --run unreadable: removed was printed once, early, and never again.
    game.print("rns-debug-nc: appended to script-output/rns-debug-nc.txt")
    helpers.write_file("rns-debug-nc.txt", "\n# tick " .. game.tick .. " | " .. StressTest.drainStatus() .. " | " .. busScanStatus() .. "\n" .. text .. "\n", true)
end)

--Debug command for P2: what a store written to storage survives and what it does
--not. Two phases, driven by a marker: the first call builds the stores, then the
--save and load happen, the second call inspects what came back.
--
--Three questions from the plan's open list are answered here:
--  * does a LuaInventory reference in storage survive save/load (docs say LuaObject
--    references are storable, this is the check)
--  * what happens to the store's metatable (storage drops unregistered metatables,
--    so the methods are expected to be gone until rebuild puts them back)
--  * does a container holding several chunk inventories hold them all afterwards
--The quality question is answered empirically too: the store is handed a legendary
--stack without passing isStorable, to see whether the engine keeps the distinction.
--A stack array handed to insert is attempted, since ItemStackIdentification's union
--has no array member and the plan hoped otherwise.
commands.add_command("rns-store-test", "RNSRedux: P2 store probe. First call builds, second call after a save/load inspects", function()
    local lines = {}

    if storage.storeProbe == nil then
        ------------------------------ phase 1: build
        --Capacity 4000 items. The chunk limit is min(65535, capacity), so a single
        --chunk covers any capacity up to 65535 items at a stack size of 100. A
        --second store chunk only becomes reachable with a small stack size, which
        --this fixture does not have -- so the multi-chunk case is probed with two
        --standalone inventories instead.
        local store = ItemStore.new(4000)
        store:insert{name = "iron-plate", count = 50}
        store:insert{name = "copper-plate", count = 7}

        --The array question on a throwaway inventory, so the store's counters stay
        --clean. pcall so the API message becomes data rather than an error.
        local probeInv = game.create_inventory(10)
        local arrayOk, arrayResult = pcall(function()
            return probeInv.insert{{name = "coal", count = 5}, {name = "stone", count = 5}}
        end)
        local arrayCoal = probeInv.get_item_count("coal")
        local arrayStone = probeInv.get_item_count("stone")
        probeInv.destroy()

        --The bridge: does a stack's identity survive the store? A partial magazine
        --is the clearest case -- a count alone cannot tell you it is partial, so if
        --the number of rounds comes back, the definition carried it.
        local magazineInv = game.create_inventory(2)
        magazineInv.insert{name = "firearm-magazine", count = 1}
        local live = magazineInv[1]
        live.ammo = 4
        --Every hop is recorded. The first run reported only the stored value, so a
        --failure could have been anywhere between the inventory and the store.
        local wrapped = Itemstack:new(live)
        local bridgeLiveAmmo = magazineInv[1].ammo
        local bridgeWrappedAmmo = (wrapped ~= nil) and wrapped.ammo or -1
        local bridgeDefinition = ItemStore.definitionFrom(wrapped)
        local bridgeDefinitionAmmo = (bridgeDefinition ~= nil) and bridgeDefinition.ammo or -1
        local bridgeAccepted = store:insertItemstack(wrapped)
        local bridgeBack = store:getStack("firearm-magazine", "normal")
        local bridgeAmmo = (bridgeBack ~= nil) and bridgeBack.ammo or -1
        magazineInv.destroy()

        --The quality question needs both qualities of the same item in one
        --inventory, and it has to survive the save. The first attempt put the
        --legendary stack in a throwaway inventory and destroyed it, so phase 2 could
        --not say whether quality survives -- and with only one quality present, a
        --count of zero on both forms was ambiguous.
        local chunkC = game.create_inventory(64)
        chunkC.insert{name = "iron-plate", count = 4, quality = "normal"}
        local legendaryAccepted = chunkC.insert{name = "iron-plate", count = 9, quality = "legendary"}

        --Two standalone inventories, distinguishable by content, for the multi
        --inventory save/load case.
        local chunkA = game.create_inventory(512)
        local chunkB = game.create_inventory(512)
        chunkA.insert{name = "steel-plate", count = 30}
        chunkB.insert{name = "plastic-bar", count = 20}

        storage.storeProbe = {
            store = store,
            chunkA = chunkA,
            chunkB = chunkB,
            chunkC = chunkC,
            legendaryAccepted = legendaryAccepted,
            arrayOk = tostring(arrayOk),
            arrayResult = tostring(arrayResult),
            arrayCoal = arrayCoal,
            arrayStone = arrayStone,
            beforeBare = chunkC.get_item_count("iron-plate"),
            beforeNormal = chunkC.get_item_count{name = "iron-plate", quality = "normal"},
            beforeLegendary = chunkC.get_item_count{name = "iron-plate", quality = "legendary"},
            bridgeAccepted = bridgeAccepted,
            bridgeAmmo = bridgeAmmo,
            bridgeLiveAmmo = bridgeLiveAmmo,
            bridgeWrappedAmmo = bridgeWrappedAmmo,
            bridgeDefinitionAmmo = bridgeDefinitionAmmo,
        }

        table.insert(lines, "phase 1: built")
        table.insert(lines, "chunks=" .. #store.chunks
            .. " first slots=" .. #store.chunks[1]
            .. " capacity=" .. store.nominalCapacity
            .. " iron=" .. store:getCount("iron-plate")
            .. " copper=" .. store:getCount("copper-plate")
            .. " used=" .. store:getTotalItems())
        table.insert(lines, "array insert ok=" .. tostring(arrayOk) .. " result=" .. tostring(arrayResult)
            .. " coal=" .. arrayCoal .. " stone=" .. arrayStone)
        table.insert(lines, "quality: legendary insert accepted=" .. tostring(legendaryAccepted)
            .. " bare=" .. chunkC.get_item_count("iron-plate")
            .. " normal=" .. chunkC.get_item_count{name = "iron-plate", quality = "normal"}
            .. " legendary=" .. chunkC.get_item_count{name = "iron-plate", quality = "legendary"}
            .. " (4 normal + 9 legendary inserted)")
        table.insert(lines, "bridge: partial magazine inserted=" .. bridgeAccepted
            .. " ammo along the way: inventory=" .. bridgeLiveAmmo
            .. " Itemstack=" .. bridgeWrappedAmmo
            .. " definition=" .. bridgeDefinitionAmmo
            .. " stored=" .. bridgeAmmo
            .. " (placed: 4 rounds in one magazine, full is 10)")
        table.insert(lines, "chunkA steel=" .. chunkA.get_item_count("steel-plate")
            .. " chunkB plastic=" .. chunkB.get_item_count("plastic-bar"))
        table.insert(lines, "NOW SAVE, RETURN TO MENU, LOAD, THEN RUN /rns-store-test AGAIN")
    else
        ------------------------------ phase 2: inspect after load
        local probe = storage.storeProbe
        local store = probe.store

        table.insert(lines, "phase 2: after load")
        table.insert(lines, "store table present=" .. tostring(store ~= nil))
        --The metatable is the question. storage drops unregistered metatables, so
        --this is expected to be false and is what makes a rebuild necessary.
        table.insert(lines, "store.insert is a function=" .. tostring(type(store.insert) == "function"))

        local first = store.chunks ~= nil and store.chunks[1] or nil
        table.insert(lines, "chunk count=" .. tostring(store.chunks ~= nil and #store.chunks or -1)
            .. " first present=" .. tostring(first ~= nil)
            .. " valid=" .. tostring(first ~= nil and first.valid == true))
        if first ~= nil and first.valid == true then
            table.insert(lines, "store contents iron=" .. first.get_item_count("iron-plate")
                .. " copper=" .. first.get_item_count("copper-plate"))
            table.insert(lines, "coal=" .. first.get_item_count("coal")
                .. " stone=" .. first.get_item_count("stone"))
        end

        --The quality answer, and the one that matters for P2: two qualities were
        --placed before the save, so both counts here are meaningful.
        local chunkC = probe.chunkC
        table.insert(lines, "chunkC present=" .. tostring(chunkC ~= nil)
            .. " valid=" .. tostring(chunkC ~= nil and chunkC.valid == true))
        if chunkC ~= nil and chunkC.valid == true then
            table.insert(lines, "quality after load: bare=" .. chunkC.get_item_count("iron-plate")
                .. " normal=" .. chunkC.get_item_count{name = "iron-plate", quality = "normal"}
                .. " legendary=" .. chunkC.get_item_count{name = "iron-plate", quality = "legendary"}
                .. " (placed: " .. probe.beforeBare .. "/" .. probe.beforeNormal .. "/" .. probe.beforeLegendary .. ")")
        end

        for _, name in pairs{"chunkA", "chunkB"} do
            local chunk = probe[name]
            table.insert(lines, name .. " present=" .. tostring(chunk ~= nil)
                .. " valid=" .. tostring(chunk ~= nil and chunk.valid == true)
                .. " steel=" .. tostring(chunk ~= nil and chunk.valid and chunk.get_item_count("steel-plate") or -1)
                .. " plastic=" .. tostring(chunk ~= nil and chunk.valid and chunk.get_item_count("plastic-bar") or -1))
        end

        --The cure for the metatable, applied by hand first so the fix is proven
        --before it goes into the drive's rebuild.
        ItemStore.rebuild(store)
        table.insert(lines, "after ItemStore.rebuild, store.insert is a function="
            .. tostring(type(store.insert) == "function"))
        if type(store.insert) == "function" then
            table.insert(lines, "getCount via method=" .. store:getCount("iron-plate")
                .. " used=" .. store:getTotalItems())

            --Does a stack's identity survive a save/load too? Same question as in
            --phase 1, one cycle later.
            local magazine = store:getStack("firearm-magazine", "normal")
            table.insert(lines, "bridge after load: magazine present=" .. tostring(magazine ~= nil)
                .. " ammo=" .. tostring(magazine ~= nil and magazine.ammo or -1)
                .. " (stored before the save: " .. tostring(probe.bridgeAmmo) .. ")")

            --The out-bridge: every occupied slot as a live stack, which is what the
            --display and the network bookkeeping will read.
            local occupied = 0
            store:forEachStack(function() occupied = occupied + 1 end)
            table.insert(lines, "forEachStack occupied=" .. occupied
                .. " used=" .. store:getTotalItems())
        end

        table.insert(lines, "run /rns-store-reset to start over")
    end

    game.print(table.concat(lines, "\n"))
end)

commands.add_command("rns-store-reset", "RNSRedux: drop the P2 store probe and its inventories", function()
    local probe = storage.storeProbe
    if probe ~= nil then
        if probe.store ~= nil then probe.store:destroy() end
        for _, key in pairs{"chunkA", "chunkB", "chunkC"} do
            local chunk = probe[key]
            if chunk ~= nil and chunk.valid == true then chunk.destroy() end
        end
        storage.storeProbe = nil
        game.print("rns-store-reset: probe and inventories dropped")
    else
        game.print("rns-store-reset: nothing to drop")
    end
end)

--Debug command: sets the external bus rescan period and reads it back. The first
--control run set Constants.Settings.RNS_ExternalStorage_Rescan from the console
--and nothing checked that the assignment arrived, so that run could not refute
--anything. This does the same and reports the value it reads afterwards, which is
--the check that was missing.
--A period of 1 disables the skip: the guard tests rescanCounter < period, and that
--is false after the first increment.
--It also zeroes the skip counters, so before and after can be compared over the
--same window instead of as a difference of monotonic totals.
commands.add_command("rns-bus-skip", "RNSRedux: set the external bus rescan period. <n>, 1 disables the skip", function(event)
    local n = tonumber(event.parameter or "")
    if n == nil or n < 1 then
        game.print("rns-bus-skip: usage /rns-bus-skip <n> with n >= 1")
        return
    end
    local previous = Constants.Settings.RNS_ExternalStorage_Rescan
    Constants.Settings.RNS_ExternalStorage_Rescan = n

    local zeroed = 0
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.skippedSweeps ~= nil then
            obj.skippedSweeps = 0
            obj.readSweeps = 0
            zeroed = zeroed + 1
        end
    end

    game.print("rns-bus-skip: period " .. tostring(previous) .. " -> "
        .. tostring(Constants.Settings.RNS_ExternalStorage_Rescan)
        .. ", counters zeroed on " .. zeroed .. " buses")
end)

commands.add_command("rns-bus-scan", "RNSRedux: toggle the external bus fast scan. <on|off>", function(event)
    local want = string.lower(event.parameter or "")
    if want ~= "on" and want ~= "off" then
        game.print("rns-bus-scan: usage /rns-bus-scan on|off")
        return
    end
    local previous = Constants.Settings.RNS_ExternalBus_FastScan
    Constants.Settings.RNS_ExternalBus_FastScan = (want == "on")

    local zeroed = 0
    for _, obj in pairs(storage.entityTable or {}) do
        if obj.fastScanHits ~= nil or obj.fastScanFull ~= nil then
            obj.fastScanHits = 0
            obj.fastScanFull = 0
            zeroed = zeroed + 1
        end
    end

    game.print("rns-bus-scan: " .. tostring(previous) .. " -> "
        .. tostring(Constants.Settings.RNS_ExternalBus_FastScan)
        .. ", counters zeroed on " .. zeroed .. " buses")
end)

--Registering the tick handler here means it survives a save/load, which a
--registration made from the command would not. The handler returns immediately
--while the drain is off.
script.on_nth_tick(1, StressTest.tick)

commands.add_command("rns-stress-drain", "RNSRedux: drain the external containers at a fixed rate. <itemsPerSecondPerContainer>, 0 stops it",
    function(data)
        local rate = tonumber(data.parameter or "") or 0
        game.print(StressTest.setDrain(rate))
    end)

commands.add_command("rns-stress-drain-status", "RNSRedux: report the drain rate and how much it has removed",
    function()
        game.print(StressTest.drainStatus())
    end)

--Stress test commands for UPS measurement.
commands.add_command("rns-stress-build", "RNSRedux: build a stress network. <stations> <drivesPerStation> [busesPerStation] [mixed|item|external] [both|input|output]",
    function(data)
        local a, b, c, d, e = string.match(data.parameter or "", "(%d+)%s+(%d+)%s*(%d*)%s*(%a*)%s*(%a*)")
        game.print(StressTest.build(tonumber(a) or 5, tonumber(b) or 10, tonumber(c) or 0, d, e))
    end)

commands.add_command("rns-stress-fill", "RNSRedux: load drives with items. <typesPerDrive> <amountPerType>",
    function(data)
        local a, b = string.match(data.parameter or "", "(%d+)%s+(%d+)")
        game.print(StressTest.fill(tonumber(a) or 10, tonumber(b) or 200))
    end)

commands.add_command("rns-stress-clear", "RNSRedux: remove everything the stress builder created",
    function()
        game.print(StressTest.clear())
    end)

commands.add_command("rns-stress-status", "RNSRedux: report controller members and power state",
    function()
        game.print(StressTest.status())
    end)

commands.add_command("rns-stress-purge", "RNSRedux: remove every mod entity marked for deconstruction",
    function()
        game.print(StressTest.purge())
    end)