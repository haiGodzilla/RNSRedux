Util = Util or {}

function Util.safeCall(fName, ...)
	-- Dont use pcall() if the game is in Instrument mode --
	if script.active_mods["debugadapter"] then
		fName(...)
		return
	end
	-- Secure call the Function --
	local result, error = pcall(fName, ...)

	-- Check if the Function was correctly executed --
	if result == false then
		-- Display the Error to all Player --
		game.print(error)
		log("RNSRedux error: " .. tostring(error))
		return false
	end
end

Util.OperatorFunctions = {
    [">"] = function (filter, number)
        return (filter > number and {true} or {false})[1]
    end,
    ["<"] = function (filter, number)
        return (filter < number and {true} or {false})[1]
    end,
    ["="] = function (filter, number)
        return (filter == number and {true} or {false})[1]
    end,
    [">="] = function (filter, number)
        return (filter >= number and {true} or {false})[1]
    end,
    ["<="] = function (filter, number)
        return (filter <= number and {true} or {false})[1]
    end,
    ["!="] = function (filter, number)
        return (filter ~= number and {true} or {false})[1]
    end
}

function Util.positions_match(posA, posB)
	if posA == nil or posB == nil then return false end
	return posA.x == posB.x and posA.y == posB.y
end

function Util.distance(startP, endP)
	local xS = startP[1] or startP.x
	local yS = startP[2] or startP.y
	local xE = endP[1] or endP.x
	local yE = endP[2] or endP.y
	return math.sqrt( (xS-xE)^2 + (yS-yE)^2 )
end

function Util.direction(object)
	if object.direction == defines.direction.north then
		return 1
	elseif object.direction == defines.direction.east then
		return 2
	elseif object.direction == defines.direction.south then
		return 3
	elseif object.direction == defines.direction.west then
		return 4
	end
end

function Util.axis(object)
	if object.direction == defines.direction.north or object.direction == defines.direction.south then
		return "y"
	elseif object.direction == defines.direction.east or object.direction == defines.direction.west then
		return "x"
	end
end

function Util.next_non_nil(array)
	array.values = array.values or array
	array.index = array.index or 1
	local value = ""
	local initial = array.index
	repeat
		value = array.values[array.index]
		array.index = (array.index%Util.getTableLength(array.values))+1
	until (value ~= "" and value ~= nil) or initial == array.index
	return value
end

function Util.next(array)
	array.values = array.values or array
	array.index = array.index or 1
	local value = array.values[array.index]
	array.index = (array.index%Util.getTableLength(array.values))+1
	return value
end

function Util.next_index(arrayTable)
	arrayTable.index = (arrayTable.index % arrayTable.max) + 1
end

function Util.getTableLength(array)
	local count = 0
	for _, _ in pairs(array) do
		count = count + 1
	end
	return count
end

function Util.getTableLength_non_nil(array)
	local count = 0
	for _, v in pairs(array) do
		if type(v) == "table" then
			count = count + Util.getTableLength_non_nil(v)
		elseif v ~= nil and v ~= "" then
			count = count + 1
		end
	end
	return count
end

function Util.copy(array)
	local copy = nil
	for k, v in pairs(array) do
		copy = copy or {}
		if type(v) == "table" then
			copy[k] = Util.copy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Util.get_item_name(itemName)
	if prototypes.item[itemName] ~= nil then
		return prototypes.item[itemName].localised_name
	end
end

function Util.get_fluid_name(fluidName)
	if prototypes.fluid[fluidName] ~= nil then
		return prototypes.fluid[fluidName].localised_name
	end
end

function Util.toRNumber(number)
	if number == nil then return 0 end
	local rNumber = number
	local rSuffix = "";
	if number >= 1000000000 then
		rNumber = number/1000000000
		rSuffix = " G"
	elseif number >= 1000000 then
		rNumber = number/1000000
		rSuffix = " M"
	elseif number >= 1000 then
		rNumber = number/1000 
		rSuffix = " k"
	end

	return string.format("%.2f", rNumber):gsub("%.0+$", "") .. rSuffix
end

function Util.add_list_into_table(tab, list)
	for _, i in pairs(list) do
		table.insert(tab, i)
	end
end

function Util.item_add_list_into_table(tab, list)
	list = Itemstack:reload(list)
	list = list:copy()
	for _, v in pairs(tab) do
		--The cached entries come back from a save without their metatable; onLoad does not
		--rebuild them. The removal path reloads its entries too.
		v = Itemstack:reload(v)
		if v:compare_itemstacks(list, true, true) then
			v.count = v.count + list.count
			return
		end
	end
	if list.ammo ~= nil and list.count > 1 and list.ammo ~= prototypes.item[list.name].magazine_size then
		Util.item_add_list_into_table(tab, list:split(list, 1, true))
		if list.count > 0 then
			Util.item_add_list_into_table(tab, list)
		end
		return
	end
	if list.durability ~= nil and list.count > 1 and list.durability ~= Util.getMaxDurability(list.name) then
		Util.item_add_list_into_table(tab, list:split(list, 1, true))
		if list.count > 0 then
			Util.item_add_list_into_table(tab, list)
		end
		return
	end
	table.insert(tab, list)
end

function Util.fluid_add_list_into_table(tab, list)
	list = {
		name = list.name,
		amount = list.amount,
		temperature = list.temperature
	}
	for _, v in pairs(tab) do
		if v.name == list.name then
			--Weighted by the amounts before the merge; the amount used to be raised first,
			--which weighted the old temperature by the new total.
			local default = prototypes.fluid[list.name].default_temperature
			local total = v.amount + list.amount
			if total > 0 then
				v.temperature = ((v.temperature or default) * v.amount + (list.temperature or default) * list.amount) / total
			end
			v.amount = total
			return
		end
	end
	table.insert(tab, list)
end

function Util.filter_accepts_item(filter, mode, itemname)
	if filter == nil then return true end
	if mode == "whitelist" then
		return (filter[itemname] ~= nil and {true} or {false})[1]
	elseif mode == "blacklist" then
		return (filter[itemname] ~= nil and {false} or {true})[1]
	end

	return false
end

function Util.filter_accepts_fluid(filter, mode, fluidname)
	if filter == nil then return true end
	if mode == "whitelist" then
		return (filter[fluidname] ~= nil and {true} or {false})[1]
	elseif mode == "blacklist" then
		return (filter[fluidname] ~= nil and {false} or {true})[1]
	end

	return false
end

function Util.sigfig_d(number, range)
	local n = tostring(number)
	return tonumber(string.find(n, "%.") and string.sub(n, 1, string.find(n, "%.")+range) or n)
end


local function merge(array, s, e, direction)
	local l = s
	local lt = math.floor((s+e)/2)
	local r = lt+1
	local temp = Util.copy(array)

	for i = s, e do
		if r > e or ((direction == "HL" and (array[l].count or array[l].amount) >= (array[r].count or array[r].amount)) or (direction == "LH" and (array[l].count or array[l].amount) <= (array[r].count or array[r].amount))) and l <= lt then
			temp[i] = array[l]
			l = l + 1
		else
			temp[i] = array[r]
			r = r + 1
		end
	end

	for i = s, e do
		array[i] = temp[i]
	end
end

function Util.merge_sort(array, s, e, direction)
	local s = s or 1
	local e = e or #array
	if s >= e then return array end
	local m = math.floor((s+e)/2)
	Util.merge_sort(array, s, m, direction)
	Util.merge_sort(array, m+1, e, direction)
	merge(array, s, e, direction)
end

function Util.signal_to_rich_text(signal)
	if signal and signal.name then
	  if signal.type == "item" then
		return "[img=item."..signal.name.."]"
	  elseif signal.type == "fluid" then
		return "[img=fluid."..signal.name.."]"
	  elseif signal.type == "virtual" then
		return "[img=virtual-signal."..signal.name.."]"
	  end
	end
	return ""
 end

function Util.serialize_inventory(inventory)
	local i = nil
	for ii = 1, #inventory do
		i = i or {}
		i[ii] = Itemstack:new(inventory[ii])
	end
	return i
end

function Util.deserialize_inventory(inventory, data)
	for i = 1, #inventory do
		inventory[i].set_stack(data[i])
	end
end
-- Factorio 2.0: rendering.draw_* returns a LuaRenderObject, not a numeric id.
-- Only the id is stored, because LuaObjects do not reliably survive save/load.
function Util.newRender(obj)
    if obj == nil then return nil end
    return obj.id
end

function Util.destroyRender(id)
    if id == nil then return end
    local obj = rendering.get_object_by_id(id)
    if obj then obj.destroy() end
end

function Util.setRenderAltMode(id, only_alt_mode)
    if id == nil then return end
    local obj = rendering.get_object_by_id(id)
    if obj then obj.only_in_alt_mode = only_alt_mode end
end

function Util.getRenderAltMode(id)
    if id == nil then return nil end
    local obj = rendering.get_object_by_id(id)
    if obj then return obj.only_in_alt_mode end
    return nil
end

-- Factorio 2.0: wire connectors replaced circuit connector ids, and a single
-- connector now carries both red and green wires. The enum member is looked up
-- from the entity itself so a wrong guess cannot break the mod.
--Red and green are separate connectors, and the reads below take both. The previous
--version cached one connector per prototype name -- whichever wire the first combinator
--asked about happened to carry -- so a bus wired only with the other colour saw no
--network, and the cache lived outside storage, where a joining client started empty.
local RED = defines.wire_connector_id.circuit_red
local GREEN = defines.wire_connector_id.circuit_green

function Util.getCombinatorNetwork(combinator)
    if combinator == nil or combinator.valid == false then return nil end
    return combinator.get_circuit_network(RED) or combinator.get_circuit_network(GREEN)
end

--The sum over both wires, as get_merged_signal gave it in 1.1.
function Util.getCombinatorSignal(combinator, signal)
    if combinator == nil or combinator.valid == false then return 0 end
    return combinator.get_signal(signal, RED, GREEN)
end

function Util.getCombinatorSignals(combinator)
    if combinator == nil or combinator.valid == false then return nil end
    return combinator.get_signals(RED, GREEN)
end

--Factorio 2.0 removed set_signal from constant combinators; their signals live in
--logistic sections now. Takes the arguments set_signal took: a slot index and either
--nil (clear the slot) or {signal = SignalID, count = n}. set_slot refuses a signal that
--another slot of the section already holds, which for the icon slots only means the
--icon shows once.
--The quality has to be explicit: a signal without one reads as the "any quality"
--filter, and LuaLogisticSection.set_slot rejects that whenever min is non-zero
--("Can't specify non zero request with non trivial item filter condition"). Every
--caller here passes a plain item, fluid or virtual signal with no quality, so it
--defaults to normal. Normal is also valid for fluids and virtual signals, which have
--no quality of their own.
function Util.setCombinatorSignal(combinator, index, entry)
    if combinator == nil or combinator.valid == false then return end
    local behavior = combinator.get_or_create_control_behavior()
    if behavior == nil then return end
    local section = behavior.get_section(1) or behavior.add_section()
    if section == nil then return end
    local signal = entry ~= nil and entry.signal or nil
    if signal == nil or signal.name == nil or signal.name == "" then
        section.clear_slot(index)
        return
    end
    section.set_slot(index, {
        value = {type = signal.type or "item", name = signal.name, quality = signal.quality or "normal"},
        min = entry.count or 1
    })
end

-- Factorio 2.0 removed LuaItemPrototype::durability. Tool durability is a
-- method now and only exists on tool items, so every read has to be guarded.
-- Reading the old field throws instead of returning nil.
function Util.getMaxDurability(itemName)
    local prototype = prototypes.item[itemName]
    if prototype == nil or prototype.type ~= "tool" then return nil end
    return prototype.get_durability()
end

--Blueprint and entity tags are input from outside the mod: a blueprint string can be
--edited by hand, other mods tag entities, and an old blueprint can carry values this
--version no longer understands. Each reader returns `current` -- the value new() set --
--unless the tag value is valid, so a bad tag leaves a working default instead of nil.
--A throw while placing destroys the entity (Control.placed), and a bad priority or
--colour broke every later refresh of the network.
function Util.tagNumber(value, current, min, max)
    if type(value) ~= "number" or value ~= value then return current end
    if (min ~= nil and value < min) or (max ~= nil and value > max) then return current end
    return value
end

function Util.tagPriority(value, current)
    local max = Constants.Settings.RNS_Max_Priority
    local priority = Util.tagNumber(value, current, -max, max)
    if priority ~= math.floor(priority) then return current end
    return priority
end

function Util.tagBoolean(value, current)
    if type(value) ~= "boolean" then return current end
    return value
end

--choices is a table keyed by the allowed values.
function Util.tagChoice(value, current, choices)
    if type(value) ~= "string" or choices[value] == nil then return current end
    return value
end

--Every SignalIDType 2.0 knows, mapped to its prototype group.
local signalPrototypes = {
    item = function() return prototypes.item end,
    fluid = function() return prototypes.fluid end,
    virtual = function() return prototypes.virtual_signal end,
    entity = function() return prototypes.entity end,
    recipe = function() return prototypes.recipe end,
    quality = function() return prototypes.quality end,
    ["space-location"] = function() return prototypes.space_location end,
    ["asteroid-chunk"] = function() return prototypes.asteroid_chunk end,
}

--A prototype name, or "" for no filter. A name whose prototype no longer exists counts
--as no filter.
function Util.tagPrototypeName(value, kind)
    if type(value) ~= "string" or value == "" then return "" end
    local group = signalPrototypes[kind]
    if group == nil or group()[value] == nil then return "" end
    return value
end

--A SignalID {type, name, quality}, or nil. The type of an item signal reads back as
--nil (SignalID docs), and that is how the GUI stores it, so nil means item.
function Util.tagSignal(value)
    if type(value) ~= "table" or type(value.name) ~= "string" then return nil end
    if value.type ~= nil and type(value.type) ~= "string" then return nil end
    if Util.tagPrototypeName(value.name, value.type or "item") == "" then return nil end
    local quality = nil
    if type(value.quality) == "string" and prototypes.quality[value.quality] ~= nil then quality = value.quality end
    return {type = value.type, name = value.name, quality = quality}
end

--The enabler table the buses and the detector share. noFilter is what the owner uses
--for an empty filter: nil on the buses, "" on the detector.
function Util.tagEnabler(value, current, noFilter)
    if type(value) ~= "table" then return current end
    local filter = Util.tagSignal(value.filter)
    return {
        operator = Util.tagChoice(value.operator, current.operator, Constants.Settings.RNS_Operators),
        number = Util.tagNumber(value.number, current.number),
        filter = filter ~= nil and filter or noFilter,
        numberOutput = Util.tagNumber(value.numberOutput, current.numberOutput),
    }
end

Util.TagChoices = {
    whitelistBlacklist = {whitelist = true, blacklist = true},
    busIO = {input = true, output = true},
    circuitCondition1 = {["none"] = true, ["enable/disable"] = true, ["filter"] = true},
}

--{state, filter} of the item and fluid buses.
function Util.tagCircuitCondition2(value, current)
    if type(value) ~= "table" then return current end
    return {
        state = Util.tagBoolean(value.state, current.state),
        filter = Util.tagSignal(value.filter),
    }
end
