--ItemStore wraps the script inventory that backs a single drive.
--
--Factorio 2.0 keeps an item's full identity inside a LuaInventory: name, count,
--quality, ammo, durability, tags and spoil state. The original mod serialised
--all of that by hand into storage, which dropped quality, invented ammo and
--durability values and merged stacks that should not have been merged. This
--module hands that job back to the engine.

ItemStore = {}

--The tier labels (4k, 16k, ...) describe item counts at a stack size of 100.
--One slot per 100 nominal items keeps those labels meaningful and stays far
--below the 65535 slot ceiling of LuaInventory::resize.
local ITEMS_PER_SLOT = 100

local methods = {__index = ItemStore}

local function quality_name(stack)
    local quality = stack.quality
    if quality == nil then return "normal" end
    if type(quality) == "string" then return quality end
    return quality.name or "normal"
end

function ItemStore.new(nominalCapacity)
    local store = setmetatable({}, methods)
    store.nominalCapacity = nominalCapacity
    store.slots = math.max(1, math.floor(nominalCapacity / ITEMS_PER_SLOT))
    store.inventory = game.create_inventory(store.slots)
    return store
end

function ItemStore:destroy()
    if self.inventory ~= nil then
        self.inventory.destroy()
    end
    self.inventory = nil
end

--Quality cannot be represented by the network bookkeeping yet. Rejecting such
--stacks is the interim contract: no silent merge, no silent downgrade.
function ItemStore.isStorable(stack)
    if stack == nil or stack.name == nil then return false, "no item" end
    local quality = quality_name(stack)
    if quality ~= "normal" then return false, "quality:" .. quality end
    return true, nil
end

function ItemStore:insert(stack)
    if self.inventory == nil then return 0 end
    return self.inventory.insert(stack)
end

function ItemStore:remove(name, count, quality)
    if self.inventory == nil then return 0 end
    return self.inventory.remove{name = name, count = count, quality = quality}
end

function ItemStore:getCount(name, quality)
    if self.inventory == nil then return 0 end
    return self.inventory.get_item_count{name = name, quality = quality}
end

function ItemStore:getStack(name, quality)
    if self.inventory == nil then return nil end
    return self.inventory.find_item_stack{name = name, quality = quality}
end

function ItemStore:getContents()
    if self.inventory == nil then return {} end
    return self.inventory.get_contents()
end

function ItemStore:getTotalItems()
    if self.inventory == nil then return 0 end
    return self.inventory.get_item_count()
end

function ItemStore:getEmptySlots()
    if self.inventory == nil then return 0 end
    return self.inventory.count_empty_stacks(false, false)
end

function ItemStore:getUsedSlots()
    return self.slots - self:getEmptySlots()
end

function ItemStore:isFull()
    return self:getEmptySlots() <= 0
end
