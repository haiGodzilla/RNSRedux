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

    game.print("rns-debug-extract: left=" .. tostring(left)
        .. " network " .. networkBefore .. "->" .. (network.Contents.item[name] or 0)
        .. " player " .. playerBefore .. "->" .. inventory.get_item_count(name))
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
    --The chat scrolls away and cannot be piped out of the game, so the same dump
    --goes to script-output/rns-debug-nc.txt as well. Appended with the tick as a
    --header: the acceptance check compares two consecutive runs of this command.
    game.print("rns-debug-nc: appended to script-output/rns-debug-nc.txt")
    helpers.write_file("rns-debug-nc.txt", "\n# tick " .. game.tick .. "\n" .. text .. "\n", true)
end)

--Debug command for M1: exercises ItemStore against a scratch inventory, without
--touching drives or the network.
commands.add_command("rns-store-test", "RNSRedux: exercise ItemStore against a scratch inventory", function()
    local lines = {}
    local store = ItemStore.new(4000)
    table.insert(lines, "slots=" .. store.slots)

    local first = store:insert{name = "iron-plate", count = 10}
    table.insert(lines, "insert 10 normal -> " .. first)

    local storable, why = ItemStore.isStorable{name = "iron-plate", count = 3, quality = "legendary"}
    table.insert(lines, "legendary storable=" .. tostring(storable) .. " (" .. tostring(why) .. ")")

    local second = store:insert{name = "iron-plate", count = 250}
    table.insert(lines, "insert 250 normal -> " .. second)
    table.insert(lines, "count=" .. store:getCount("iron-plate")
        .. " slots=" .. store:getUsedSlots() .. "/" .. store.slots
        .. " total=" .. store:getTotalItems()
        .. " contents=" .. #store:getContents())

    local removed = store:remove("iron-plate", 100)
    table.insert(lines, "remove 100 -> " .. removed .. " left=" .. store:getCount("iron-plate"))

    store:destroy()
    table.insert(lines, "after destroy count=" .. store:getCount("iron-plate"))

    game.print(table.concat(lines, "\n"))
end)

--Stress test commands for UPS measurement.
commands.add_command("rns-stress-build", "RNSRedux: build a stress network. <stations> <drivesPerStation>",
    function(data)
        local a, b = string.match(data.parameter or "", "(%d+)%s+(%d+)")
        game.print(StressTest.build(tonumber(a) or 5, tonumber(b) or 10))
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