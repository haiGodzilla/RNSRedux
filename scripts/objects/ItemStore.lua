--ItemStore wraps the script inventories that back a single drive.
--
--Factorio 2.0 keeps an item's full identity inside a LuaInventory: name, count,
--quality, ammo, durability, tags and spoil state. The original mod serialised all
--of that by hand into storage, which dropped quality, invented ammo and durability
--values and merged stacks that should not have been merged. This module hands that
--job back to the engine.
--
--Capacity is an item count, not a slot count. Slots are only the physical buffer,
--and they grow with the store: the active chunk doubles up to the engine's limit,
--then a further chunk joins. Nothing is tied to a stack size, so a mod that
--changes stack sizes cannot break the arithmetic.

ItemStore = {}

local methods = {__index = ItemStore}

--LuaInventory::resize tops out at 65535 slots. Starting far below that keeps a
--drive which holds only a handful of item types cheap, and costs nothing when it
--grows.
local CHUNK_INITIAL = 1024
local CHUNK_MAX = 65535

--Item identity in 2.0 is name plus quality, so both go into the key. Two quality
--levels are two entries -- which is exactly what the old hand serialisation lost.
function ItemStore.key(name, quality)
    return name .. "|" .. (quality or "normal")
end

--quality arrives as a string, as a LuaQualityPrototype, or not at all, depending
--on where the stack came from.
function ItemStore.qualityOf(value)
    if value == nil then return "normal" end
    if type(value) == "string" then return value end
    return value.name or "normal"
end

--The most slots a chunk may hold. More slots than items can never be useful: at a
--stack size of 1 the two are equal, and above that the items need fewer slots.
local function chunkLimit(store)
    return math.min(CHUNK_MAX, store.nominalCapacity)
end

local function newChunk(store)
    return game.create_inventory(math.min(CHUNK_INITIAL, chunkLimit(store)))
end

function ItemStore.new(nominalCapacity)
    local store = setmetatable({}, methods)
    store.nominalCapacity = math.max(1, nominalCapacity or 1)
    store.chunks = {}
    --item|quality -> chunk index, so one item is not scattered over several chunks.
    store.index = {}
    store.used = 0
    store.chunks[1] = newChunk(store)
    return store
end

--Reconstructor for onLoad. storage drops unregistered metatables, so a store that
--came back from a save is a plain table whose methods are gone until this runs.
--The drive that owns the store calls this from its own rebuild.
function ItemStore.rebuild(object)
    if object == nil then return end
    setmetatable(object, methods)
end

--Makes room for at least one more item. The active chunk doubles before another
--joins: resizing one inventory is cheaper than owning several, and it keeps a
--drive's items together. The last chunk is the one that grows.
local function grow(store)
    local last = store.chunks[#store.chunks]
    local slots = #last
    local limit = chunkLimit(store)
    if slots < limit then
        last.resize(math.min(slots * 2, limit))
        return true
    end
    store.chunks[#store.chunks + 1] = newChunk(store)
    return true
end

--First chunk that still has an empty slot, or nil.
local function chunkWithRoom(store)
    for i = 1, #store.chunks do
        if not store.chunks[i].is_full() then return i end
    end
    return nil
end

--Builds the engine's stack definition from a stack the mod holds as an Itemstack.
--ItemStackDefinition carries name, count, quality, health, durability, ammo and
--tags, so a stack's identity travels -- which is the whole point of P2, and the
--reason the mod's hand serialisation can go away.
--Two things it does not carry: blueprint data and equipment grids. Those live in
--Itemstack.extras and have no field here; they are restored separately through
--LuaItemStack::import_stack (see insertItemstack).
function ItemStore.definitionFrom(itemstack)
    if itemstack == nil or itemstack.name == nil then return nil end
    local definition = {
        name = itemstack.name,
        count = itemstack.count,
        quality = ItemStore.qualityOf(itemstack.quality),
    }
    if itemstack.health ~= nil then definition.health = itemstack.health end
    if itemstack.durability ~= nil then definition.durability = itemstack.durability end
    if itemstack.ammo ~= nil then definition.ammo = itemstack.ammo end
    --Only the real tags. Itemstack.extras is the mod's own bag for blueprint data
    --and grids, and the engine's tags field is a different thing entirely.
    if itemstack.tags ~= nil and next(itemstack.tags) ~= nil then
        definition.tags = itemstack.tags
    end
    return definition
end

--Inserts a stack the mod holds as an Itemstack. Returns how many items went in.
--An item that carries an export string -- blueprint, blueprint book, deconstruction
--or upgrade planner, item-with-tags -- cannot be rebuilt from a definition alone,
--so it is inserted as a plain item and then filled from its export string.
function ItemStore:insertItemstack(itemstack, amount)
    local definition = ItemStore.definitionFrom(itemstack)
    if definition == nil then return 0 end
    if amount ~= nil and amount < definition.count then definition.count = amount end

    local inserted = self:insert(definition)
    if inserted <= 0 then return 0 end

    local data = itemstack.stack_export_string
    if data ~= nil and data ~= "" then
        local stack = self:getStack(definition.name, definition.quality)
        if stack ~= nil then stack.import_stack(data) end
    end
    return inserted
end

--Yields every occupied slot as a LuaItemStack, so callers that speak the mod's
--Itemstack dialect can rebuild one with Itemstack:new(stack) and lose nothing:
--that constructor reads ammo, durability, health and the export string itself.
--The slot indices come along for callers that need to replace a single slot.
function ItemStore:forEachStack(callback)
    for i = 1, #self.chunks do
        local chunk = self.chunks[i]
        for j = 1, #chunk do
            local stack = chunk[j]
            if stack.valid_for_read == true and stack.count > 0 then
                callback(stack, i, j)
            end
        end
    end
end

--Releases every chunk. Without this the savegame leaks: a script inventory is not
--freed by dropping the reference.
function ItemStore:destroy()
    for _, chunk in pairs(self.chunks or {}) do
        if chunk.valid == true then chunk.destroy() end
    end
    self.chunks = {}
    self.index = {}
    self.used = 0
end

--Whether the drive accepts this stack at all. This is policy, not capability: the
--store can hold quality, the network bookkeeping cannot yet. Rejecting is the
--interim contract -- no silent merge, no silent downgrade.
function ItemStore.isStorable(stack)
    if stack == nil or stack.name == nil then return false, "no item" end
    local quality = ItemStore.qualityOf(stack.quality)
    if quality ~= "normal" then return false, "quality:" .. quality end
    return true, nil
end

--The inventory decides how to store and merge a stack from its ammo, durability,
--health and tags -- not from the count alone. Handing it a reduced
--{name, count, quality} table silently turns a partial magazine into a full one,
--which is exactly what the first bridge probe measured: four rounds in, ten back.
local function requestFrom(stack, count)
    local request = {name = stack.name, count = count, quality = stack.quality}
    if stack.health ~= nil then request.health = stack.health end
    if stack.durability ~= nil then request.durability = stack.durability end
    if stack.ammo ~= nil then request.ammo = stack.ammo end
    if stack.tags ~= nil then request.tags = stack.tags end
    return request
end

--Inserts up to stack.count, bounded by the nominal capacity, and returns how many
--went in. The chunk already holding this item is tried first; only if that leaves
--something over does the store look for another chunk or grow.
function ItemStore:insert(stack)
    if stack == nil or stack.name == nil then return 0 end
    local wanted = stack.count or 1
    if wanted <= 0 then return 0 end

    local room = self.nominalCapacity - self.used
    if room <= 0 then return 0 end
    if wanted > room then wanted = room end

    local request = requestFrom(stack, wanted)
    local key = ItemStore.key(stack.name, ItemStore.qualityOf(stack.quality))
    local inserted = 0

    local preferred = self.index[key]
    if preferred ~= nil then
        inserted = self.chunks[preferred].insert(request)
    end

    while inserted < wanted do
        local chunkIndex = chunkWithRoom(self)
        if chunkIndex == nil then
            grow(self)
            chunkIndex = chunkWithRoom(self)
            if chunkIndex == nil then break end
        end
        request.count = wanted - inserted
        local added = self.chunks[chunkIndex].insert(request)
        --A chunk that reports room but takes nothing would make this loop forever:
        --the item is refused for a reason the store cannot see (prototype filters,
        --for instance).
        if added <= 0 then break end
        inserted = inserted + added
        self.index[key] = chunkIndex
    end

    self.used = self.used + inserted
    return inserted
end

--Takes up to count out of the store and returns how many came out. A quality of
--nil means normal.
function ItemStore:remove(name, count, quality)
    if name == nil or count == nil or count <= 0 then return 0 end
    --Normalised, so that a nil quality and an explicit "normal" reach the same
    --stack -- the engine merges them anyway, and getCount below has to agree.
    local wanted = ItemStore.qualityOf(quality)
    local removed = 0
    for i = 1, #self.chunks do
        if removed >= count then break end
        local taken = self.chunks[i].remove{name = name, count = count - removed, quality = wanted}
        removed = removed + taken
    end
    self.used = math.max(0, self.used - removed)
    if removed > 0 and self:getCount(name, wanted) <= 0 then
        self.index[ItemStore.key(name, wanted)] = nil
    end
    return removed
end

--The quality is named explicitly rather than left out: whether a bare name matches
--every quality level is exactly the question the store probe answers, and this way
--the store does not depend on the answer.
function ItemStore:getCount(name, quality)
    if name == nil then return 0 end
    local total = 0
    for i = 1, #self.chunks do
        total = total + self.chunks[i].get_item_count{
            name = name,
            quality = ItemStore.qualityOf(quality)
        }
    end
    return total
end

--The stack as the engine holds it, so callers get ammo, durability and tags back
--without the mod having stored them itself.
function ItemStore:getStack(name, quality)
    if name == nil then return nil end
    local found = nil
    for i = 1, #self.chunks do
        found = self.chunks[i].find_item_stack{
            name = name,
            quality = ItemStore.qualityOf(quality)
        }
        if found ~= nil then return found end
    end
    return nil
end

function ItemStore:getContents()
    local contents = {}
    for i = 1, #self.chunks do
        for _, stack in pairs(self.chunks[i].get_contents()) do
            contents[#contents + 1] = stack
        end
    end
    return contents
end

--Tracked rather than counted: the inventory would answer this in O(slots) and the
--capacity check runs on every insert.
function ItemStore:getTotalItems()
    return self.used
end

function ItemStore:getRemainingCapacity()
    return math.max(0, self.nominalCapacity - self.used)
end

function ItemStore:getEmptySlots()
    local total = 0
    for i = 1, #self.chunks do
        total = total + self.chunks[i].count_empty_stacks(false, false)
    end
    return total
end

function ItemStore:getUsedSlots()
    local total = 0
    for i = 1, #self.chunks do
        total = total + #self.chunks[i]
    end
    return total - self:getEmptySlots()
end

function ItemStore:isFull()
    return self.used >= self.nominalCapacity
end
