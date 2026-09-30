ID = {
    thisEntity = nil,
    entID = nil,
    networkController = nil,
    maxStorage = 0,
    powerUsage = 40,
    --The drive's contents. An engine inventory holds the full item identity --
    --quality, ammo, durability, health, tags -- so the mod no longer serialises any
    --of it. storedAmount stays as a tracked mirror of the store's count: the dump
    --compares the two (truth), which is how a bookkeeping divergence is caught.
    store = nil,
    storedAmount = nil,
    connectedObjs = nil,
    cardinals = nil,
    guiFilters = nil,
    filters = nil,
    whitelistBlacklist = "blacklist",
    priority = 0,
    icons = nil
}

function ID:new(object)
    if object == nil then return end
    local t = {}
    local mt = {}
    setmetatable(t, mt)
    mt.__index = ID
    t.thisEntity = object
    t.entID = object.unit_number
    t.maxStorage = Constants.Drives.ItemDrive[string.sub(object.name, 5)].max_size
    t.powerUsage = Constants.Drives.ItemDrive[string.sub(object.name, 5)].powerUsage
    t.whitelistBlacklist = settings.global[Constants.Settings.RNS_StorageDrive_Whitelist].value and "whitelist" or "blacklist"
    t.store = ItemStore.new(t.maxStorage)
    t.storedAmount = 0
    t.filters = {}
    t.icons = {}
    t.guiFilters = {}
    for i=1, 5 do
        t.guiFilters[i] = ""
    end
    t.cardinals = {
        [1] = false, --N
        [2] = false, --E
        [3] = false, --S
        [4] = false, --W
    }
    t.connectedObjs = {
        [1] = {}, --N
        [2] = {}, --E
        [3] = {}, --S
        [4] = {}, --W
    }
    UpdateSys.add_to_entity_table(t)
    t:createArms()
    BaseNet.postArms(t)
    BaseNet.update_network_controller(t.networkController)
    --UpdateSys.addEntity(t)
    return t
end

function ID:rebuild(object)
    if object == nil then return end
    local mt = {}
    mt.__index = ID
    setmetatable(object, mt)
    --storage drops unregistered metatables, so the store's methods are gone after a
    --load until they are restored here.
    ItemStore.rebuild(object.store)
end

function ID:remove()
    --Frees the chunk inventories. Without this the savegame leaks: a script
    --inventory is not freed by dropping the reference.
    if self.store ~= nil then self.store:destroy() end
    UpdateSys.remove_from_entity_table(self)
    BaseNet.postArms(self)
    --[[if self.networkController ~= nil then
        self.networkController.network.ItemDriveTable[Constants.Settings.RNS_Max_Priority+1-self.priority][self.entID] = nil
        self.networkController.network.shouldRefresh = true
    end]]
    BaseNet.update_network_controller(self.networkController, self.entID)
end

function ID:valid()
    return self.thisEntity ~= nil and self.thisEntity.valid == true
end

function ID:interactable()
    return self.thisEntity ~= nil and self.thisEntity.valid and self.thisEntity.to_be_deconstructed() == false
end

function ID:copy_settings(obj)
    self.priority = obj.priority
    self.whitelistBlacklist = obj.whitelistBlacklist
    self.filters = obj.filters
    self.guiFilters = {}
    for i = 1, 5 do
        self.guiFilters[i] = obj.guiFilters[i]
    end
    self:regenerate_icons()
end

function ID:serialize_settings()
    local tags = {}
    tags["priority"] = self.priority
    tags["whitelistBlacklist"] = self.whitelistBlacklist
    tags["filters"] = self.filters
    tags["guiFilters"] = self.guiFilters
    return tags
end

function ID:deserialize_settings(tags)
    self.priority = tags["priority"]
    self.whitelistBlacklist = tags["whitelistBlacklist"]
    self.filters = tags["filters"]
    self.guiFilters = tags["guiFilters"]
    self:regenerate_icons()
end

function ID:toggleHoverIcon(hovering)
    for _, i in pairs(self.icons) do
        if i ~= nil and hovering and Util.getRenderAltMode(i) then
            Util.setRenderAltMode(i, false)
        elseif i ~= nil and not hovering and not Util.getRenderAltMode(i) then
            Util.setRenderAltMode(i, true)
        end
    end
end

function ID:regenerate_icons()
    for i, ii in pairs(self.icons) do
        if ii ~= nil then
            Util.destroyRender(ii)
            self.icons[i] = nil
        end
    end
    local i = 0
    for n, _ in pairs(self.filters) do
        i = i + 1
        table.insert(self.icons, Util.newRender(rendering.draw_sprite{
            sprite = "item/"..n,
            target = self.thisEntity,
            surface = self.thisEntity.surface,
            render_layer = "higher-object-under",
            target_offset = Constants.Settings.RNS_DriveSprite_Offset[i],
            only_in_alt_mode = true
        }))
    end
end

function ID:resetCollection()
    self.connectedObjs = {
        [1] = {}, --N
        [2] = {}, --E
        [3] = {}, --S
        [4] = {}, --W
    }
end

function ID:getCheckArea()
    local x = self.thisEntity.position.x
    local y = self.thisEntity.position.y
    return {
        [1] = {direction = 1, startP = {x-1.0, y-2.0}, endP = {x+1.0, y-1.0}}, --North
        [2] = {direction = 2, startP = {x+1.0, y-1.0}, endP = {x+2.0, y+1.0}}, --East
        [4] = {direction = 4, startP = {x-1.0, y+1.0}, endP = {x+1.0, y+2.0}}, --South
        [3] = {direction = 3, startP = {x-2.0, y-1.0}, endP = {x-1.0, y+1.0}}, --West
    }
end

function ID:createArms()
    local areas = self:getCheckArea()
    self:resetCollection()
    for _, area in pairs(areas) do
        local ents = self.thisEntity.surface.find_entities_filtered{area={area.startP, area.endP}}
        for _, ent in pairs(ents) do
            if ent ~= nil and ent.valid == true and ent.to_be_deconstructed() == false and string.match(ent.name, "RNS_") ~= nil and storage.entityTable[ent.unit_number] ~= nil then
                local obj = storage.entityTable[ent.unit_number]
                if (string.match(obj.thisEntity.name, "RNS_NetworkCableIO") ~= nil and obj:getConnectionDirection() == area.direction) or (string.match(obj.thisEntity.name, "RNS_NetworkCableRamp") ~= nil and obj:getConnectionDirection() == area.direction) or obj.thisEntity.name == Constants.WirelessGrid.name then
                    --Do nothing
                else
                    table.insert(self.connectedObjs[area.direction], obj)
                    BaseNet.join_network(self, obj)
                end
            end
        end
    end
end

--Reads a stack out of the store in the mod's own dialect, so the callers that
--compare and transfer keep working unchanged. Itemstack:new is the exact inverse of
--the bridge: it reads name, count, quality, ammo, durability, health, tags and the
--export string off the live engine stack, so nothing is lost in this direction.
--Returns nil when the store holds none of that item.
function ID:getStoredStack(name, quality)
    local live = self.store:getStack(name, quality)
    if live == nil then return nil end
    return Itemstack:new(live)
end

--The engine only ever holds valid prototypes, so the old sweep for item names that
--no longer exist has nothing left to do. Kept because onInit calls it on every
--object of the table.
function ID:validate()
    self.storedAmount = self.store:getTotalItems()
end

function ID:add_or_merge_basic_item(itemstack_data, amount)
    --The store bounds the insert by the remaining capacity itself, and the engine
    --decides how the stack merges -- including ammo and durability, which the old
    --path added with a modulo and thereby invented fill levels.
    local inserted = self.store:insertItemstack(itemstack_data, amount)
    self.storedAmount = self.store:getTotalItems()
    return inserted
end

--Takes up to amount out of the store and hands back what came out, in the mod's
--dialect. The values are read off the live stack before the removal, because the
--removal is what shrinks it.
--The exact flag is no longer needed: it used to steer split()'s ammo and durability
--arithmetic, and callers now check the match themselves before calling this (see
--BaseNet.transfer_from_network_to_inv). It is kept for the callers' sake.
function ID:remove_item(itemstack_data, amount, exact)
    if itemstack_data == nil or amount == nil or amount <= 0 then return 0, nil end
    local live = self.store:getStack(itemstack_data.name, itemstack_data.quality)
    if live == nil then return 0, nil end

    local out = Itemstack:new(live)
    if out == nil then return 0, nil end

    local removed = self.store:remove(itemstack_data.name, math.min(live.count, amount),
        itemstack_data.quality)
    if removed <= 0 then return 0, nil end

    out.count = removed
    self.storedAmount = self.store:getTotalItems()
    return removed, out
end

--[[function ID:has_item(itemstack_data, getModified)
    local amount = 0
    local list = self.storageArray[itemstack_data.cont.name]
    if list ~= nil and itemstack_data.modified == false then
        if (list.ammo == itemstack_data.cont.ammo or list.durability == itemstack_data.cont.durability) and (list.ammo == prototypes.item[list.name].magazine_size or list.durability == prototypes.item[list.name].durability) then
            amount = amount + list.count
        else
            if getModified == true then
                if (list.ammo == itemstack_data.cont.ammo or list.durability == itemstack_data.cont.durability) and (list.ammo ~= prototypes.item[list.name].magazine_size or list.durability ~= prototypes.item[list.name].durability) then
                    amount = amount + 1
                end
            else
                amount = amount + list.count - 1
            end
        end
    end
    return amount
end]]

function ID:has_room()
    if self:getRemainingStorageSize() > 0 then return true end
    return false
end


function ID:getStorageSize()
    return self.store:getTotalItems()
end

function ID:getRemainingStorageSize()
    return self.store:getRemainingCapacity()
end

--TEMPORARY TRACE, remove once the blueprint path is settled. The drive loses its
--contents on mine and rebuild, and the loss is on one of two halves: what the tag
--receives, or what it gives back. Both are recorded so one run says which.
local function storeTrace(message)
    helpers.write_file("rns-store-trace.txt", message .. "\n", true)
end

function ID:DataConvert_ItemToEntity(tag)
    --Contents come back through the same bridge the transfer path uses. Both shapes
    --are accepted: the list written below, and the name-keyed table from a blueprint
    --made before this change.
    local stored = tag.storage or {}
    local keys = 0
    for k in pairs(stored) do keys = keys + 1 end
    for _, entry in pairs(stored) do
        self.store:insertItemstack(entry)
    end
    self.storedAmount = self.store:getTotalItems()
    storeTrace("ItemToEntity: storageType=" .. type(tag.storage)
        .. " #stored=" .. #stored .. " keys=" .. keys
        .. " inserted=" .. self.store:getTotalItems())
    if tag.filters ~= nil then
        self.filters = tag.filters
        self.guiFilters = tag.guiFilters
    end
    if tag.priority ~= nil then self.priority = tag.priority end
    if tag.whitelistBlacklist ~= nil then self.whitelistBlacklist = tag.whitelistBlacklist end
    self:regenerate_icons()
end

function ID:DataConvert_EntityToItem(tag)
    local tags = {}
    local description = {"", tag.prototype.localised_description}

    --The one path that still serialises, and it has to: an item tag holds basic data
    --only, so an engine inventory cannot be written into one. Without this a mined or
    --blueprinted drive would lose its contents.
    local stored = {}
    local yielded = 0
    self.store:forEachStack(function(stack)
        stored[#stored + 1] = Itemstack:new(stack)
        yielded = yielded + 1
    end)
    tags.storage = stored
    storeTrace("EntityToItem: used=" .. self.store:getTotalItems()
        .. " yielded=" .. yielded .. " stored=" .. #stored
        .. " first=" .. tostring(stored[1] ~= nil and stored[1].name or "nil"))
    Util.add_list_into_table(description, {{"item-description.RNS_DriveTag_Storage", self:getStorageSize(), self.maxStorage}})

    tags.filters = self.filters
    tags.guiFilters = self.guiFilters
    local filterString = "{"
    local i = 1
    local ind = Util.getTableLength(self.filters)
    for n, _ in pairs(self.filters) do
        filterString = filterString .. "[color=yellow]" .. n .. "[/color]" .. (i < ind and ", " or "")
        i = i + 1
    end
    filterString = filterString .. "}"
    Util.add_list_into_table(description, {{"item-description.RNS_DriveTag_Filters", filterString}})

    tags.priority = self.priority
    Util.add_list_into_table(description, {{"item-description.RNS_DriveTag_Priority", self.priority}})

    tags.whitelistBlacklist = self.whitelistBlacklist
    Util.add_list_into_table(description, {{"item-description.RNS_DriveTag_WhitelistBlacklist", self.whitelistBlacklist}})

    tag.set_tag(Constants.Settings.RNS_Tag, tags)
    tag.custom_description = description
end

function ID:getTooltips(guiTable, mainFrame, justCreated)
    if justCreated == true then
        guiTable.vars.Gui_Title.caption = {"gui-description.RNS_ItemDrive_Title"}
        
        local infoFrame = GuiApi.add_frame(guiTable, "InformationFrame", mainFrame, "vertical", true)
		infoFrame.style = Constants.Settings.RNS_Gui.frame_1
		infoFrame.style.vertically_stretchable = true
		infoFrame.style.minimal_width = 200
		infoFrame.style.left_margin = 3
		infoFrame.style.left_padding = 3
		infoFrame.style.right_padding = 3
		GuiApi.add_subtitle(guiTable, "", infoFrame, {"gui-description.RNS_Information"})
     
        GuiApi.add_label(guiTable, "Capacity", infoFrame, {"gui-description.RNS_ItemDrive_Capacity", self:getStorageSize(), self.maxStorage}, Constants.Settings.RNS_Gui.orange, nil, true)
        GuiApi.add_progress_bar(guiTable, "CapacityBar", infoFrame, "", self:getStorageSize() .. "/" .. self.maxStorage, true, nil, self:getStorageSize()/self.maxStorage, 200, 25)
    
        local filtersFrame = GuiApi.add_frame(guiTable, "FiltersFrame", mainFrame, "vertical", true)
		filtersFrame.style = Constants.Settings.RNS_Gui.frame_1
		filtersFrame.style.vertically_stretchable = true
		filtersFrame.style.left_padding = 3
		filtersFrame.style.right_padding = 3
		filtersFrame.style.right_margin = 3
		filtersFrame.style.width = 100

        GuiApi.add_subtitle(guiTable, "", filtersFrame, {"gui-description.RNS_Filter"})

        local filterFlow = GuiApi.add_flow(guiTable, "", filtersFrame, "vertical")
        filterFlow.style.horizontal_align = "center"
        --local filterTable = GuiApi.add_table(guiTable, "", filtersFrame, 1, false)
        guiTable.vars.filters = {}
        for i=1, 5 do
            local filter = GuiApi.add_filter(guiTable, "RNS_ItemDrive_Filter_"..i, filterFlow, "", true, "item", 40, {ID=self.thisEntity.unit_number, index=i})
            guiTable.vars.filters[i] = filter
            if self.guiFilters[i] ~= "" then
                filter.elem_value = self.guiFilters[i]
            end
        end

        local settingsFrame = GuiApi.add_frame(guiTable, "SettingsFrame", mainFrame, "vertical", true)
		settingsFrame.style = Constants.Settings.RNS_Gui.frame_1
		settingsFrame.style.vertically_stretchable = true
		settingsFrame.style.left_padding = 3
		settingsFrame.style.right_padding = 3
		settingsFrame.style.right_margin = 3
		settingsFrame.style.minimal_width = 200

        GuiApi.add_subtitle(guiTable, "", settingsFrame, {"gui-description.RNS_Setting"})

        local priorityFlow = GuiApi.add_flow(guiTable, "", settingsFrame, "horizontal", false)
        GuiApi.add_label(guiTable, "", priorityFlow, {"gui-description.RNS_Priority"}, Constants.Settings.RNS_Gui.white)
        local priorityDD = GuiApi.add_dropdown(guiTable, "RNS_ItemDrive_Priority", priorityFlow, Constants.Settings.RNS_Priorities, ((#Constants.Settings.RNS_Priorities+1)/2)-self.priority, false, "", {ID=self.thisEntity.unit_number})
        priorityDD.style.minimal_width = 100

        GuiApi.add_line(guiTable, "", settingsFrame, "horizontal")

        local state = "left"
        if self.whitelistBlacklist == "blacklist" then state = "right" end
        GuiApi.add_switch(guiTable, "RNS_ItemDrive_WhitelistBlacklist", settingsFrame, {"gui-description.RNS_Whitelist"}, {"gui-description.RNS_Blacklist"}, "", "", state, false, {ID=self.thisEntity.unit_number})

    end

    for i=1, 5 do
        if self.guiFilters[i] ~= "" then
            guiTable.vars.filters[i].elem_value = self.guiFilters[i]
        end
    end

    local capacity = guiTable.vars.Capacity
    local capacityBar = guiTable.vars.CapacityBar

    capacity.caption = {"gui-description.RNS_ItemDrive_Capacity", self:getStorageSize(), self.maxStorage}
    capacityBar.tooltip = self:getStorageSize() .. "/" .. self.maxStorage
    capacityBar.value = self:getStorageSize()/self.maxStorage
end

function ID.interaction(event, RNSPlayer)
    local guiTable = RNSPlayer.GUI[Constants.Settings.RNS_Gui.tooltip]

    if string.match(event.element.name, "RNS_ItemDrive_Priority") then
        local id = event.element.tags.ID
		local io = storage.entityTable[id]
		if io == nil then return end
        local priority = Constants.Settings.RNS_Priorities[event.element.selected_index]
        if priority ~= io.priority then
            io.priority = priority
            local oldP = 1+Constants.Settings.RNS_Max_Priority-io.priority
            io.priority = priority
            if io.networkController ~= nil and io.networkController.valid == true then
                io.networkController.network.ItemDriveTable[oldP][io.entID] = nil
                io.networkController.network.ItemDriveTable[1+Constants.Settings.RNS_Max_Priority-priority][io.entID] = io
            end
        end
		return
    elseif string.match(event.element.name, "RNS_ItemDrive_Filter") then
        local id = event.element.tags.ID
		local io = storage.entityTable[id]
		if io == nil then return end
        if event.element.elem_value ~= nil then
            io.guiFilters[event.element.tags.index] = event.element.elem_value
        else
            io.guiFilters[event.element.tags.index] = ""
        end

        io.filters = {}
        for i = 1, 5 do
            local filter = guiTable.vars.filters[i]
            if filter ~= nil and filter.elem_value ~= nil then
                io.filters[filter.elem_value] = true
            end
        end
        io:regenerate_icons()
		return
    elseif string.match(event.element.name, "RNS_ItemDrive_WhitelistBlacklist") then
        local id = event.element.tags.ID
		local io = storage.entityTable[id]
		if io == nil then return end
        io.whitelistBlacklist = event.element.switch_state == "left" and "whitelist" or "blacklist"
		return
    end
end