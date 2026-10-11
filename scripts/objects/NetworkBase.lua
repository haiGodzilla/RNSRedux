--This will manage store related blocks for the Network Controller to see and for things that import/export 
BaseNet = {
    networkController = nil,
    ItemDriveTable = nil,
    FluidDriveTable = nil,
    ItemIOTable = nil,
    ItemIOV2Table = nil,
    FluidIOTable = nil,
    FluidIOV2Table = nil,
    ExternalIOTable = nil,
    NetworkInventoryInterfaceTable = nil,
    WirelessTransmitterTable = nil,
    DetectorTable = nil,
    TransmitterTable = nil,
    ReceiverTable = nil,
    PlayerPorts = nil,
    Contents = nil,
    interfaceCache = nil,
    shouldRefresh = false,
    connectedEntities = nil,
    importDriveCache = nil,
    importExternalCache = nil,
    exportDriveCache = nil,
    exportExternalCache = nil,
    powerDraw = 0
}

function BaseNet:new()
    local t = {}
    local mt = {}
    setmetatable(t, mt)
    mt.__index = BaseNet
    t.PlayerPorts = {}
    t.importDriveCache = {}
    t.importExternalCache = {}
    t.exportDriveCache = {}
    t.exportExternalCache = {}
    t:resetTables()
    UpdateSys.addEntity(t)
    return t
end

function BaseNet:rebuild(object)
    if object == nil then return end
    local mt = {}
    mt.__index = BaseNet
    setmetatable(object, mt)
end

function BaseNet:remove() end

function BaseNet:valid()
    return true
end

function BaseNet:update()
end

function generate_priority_table(array, group)
    for i=1, Constants.Settings.RNS_Max_Priority*2 + 1 do
        if group == "io" then
            array[i] = {
                input = {},
                output = {}
            }
        elseif group == "eo" then
            array[i] = {
                item = {},
                fluid = {}
            }
        else
            array[i] = {}
        end
    end
end

function BaseNet:resetTables()
    self.powerDraw = 0
    self.ItemDriveTable = {}
    generate_priority_table(self.ItemDriveTable)
    self.FluidDriveTable = {}
    generate_priority_table(self.FluidDriveTable)
    self.ItemIOTable = {}
    generate_priority_table(self.ItemIOTable, "io")
    --self.ItemIOV2Table = {}
    --generate_priority_table(self.ItemIOV2Table)
    self.FluidIOTable = {}
    generate_priority_table(self.FluidIOTable, "io")
    --self.FluidIOV2Table = {}
    --generate_priority_table(self.FluidIOV2Table)
    self.ExternalIOTable = {}
    generate_priority_table(self.ExternalIOTable, "eo")
    self.NetworkInventoryInterfaceTable = {}
    self.NetworkInventoryInterfaceTable[1] = {}
    self.WirelessTransmitterTable = {}
    self.WirelessTransmitterTable[1] = {}
    self.DetectorTable = {}
    self.DetectorTable[1] = {
        ["enable/disable"] = {},
        ["connect/disconnect"] = {}
    }
    self.TransmitterTable = {}
    self.TransmitterTable[1] = {}
    self.ReceiverTable = {}
    self.ReceiverTable[1] = {}
    self.connectedEntities = {}
    self.Contents = {
        item = {},
        fluid = {}
    }
    self.interfaceCache = {
        item = {},
        fluid = {}
    }
    self.StoredPartition = {
        itemDrive = {
            storedAmount = 0,
            capacity = 0
        },
        fluidDrive = {
            storedAmount = 0,
            capacity = 0
        },
        itemExternal = {
            storedAmount = 0,
            capacity = 0
        },
        fluidExternal = {
            storedAmount = 0,
            capacity = 0
        }
    }
end

--Refreshes laser connections
function BaseNet:doRefresh(controller)
    self:resetTables()
    self.connectedEntities[controller.entID] = controller
    BaseNet.addConnectables(controller, self.connectedEntities, controller)
    self.shouldRefresh = false
end

function BaseNet.add_transreciever_to_global(obj)
    if valid(obj) == false then return end
    if obj.thisEntity == nil or obj.thisEntity.valid == false then return end
    if obj.type == "transmitter" then
        storage.TransReceiverChannels.transmitters[obj.thisEntity.unit_number] = obj
    elseif obj.type == "receiver" then
        storage.TransReceiverChannels.receivers[obj.thisEntity.unit_number] = obj
    end
end

function BaseNet.remove_transreciever_from_global(obj)
    if valid(obj) == false then return end
    if obj.type == "transmitter" then
        storage.TransReceiverChannels.transmitters[obj.thisEntity.unit_number] = nil
    elseif obj.type == "receiver" then
        storage.TransReceiverChannels.receivers[obj.thisEntity.unit_number] = nil
    end
end

function BaseNet.get_transreciever_from_global(type)
    if type == "transmitter" then
        return storage.TransReceiverChannels.transmitters
    elseif type == "receiver" then
        return storage.TransReceiverChannels.receivers
    end
end

function BaseNet.add_networkcontroller_to_global(obj)
    if valid(obj) == false then return end
    if obj.thisEntity == nil or obj.thisEntity.valid == false then return end
    storage.NetworkControllers[obj.thisEntity.unit_number] = obj
end

function BaseNet.remove_networkcontroller_from_global(obj)
    if valid(obj) == false then return end
    storage.NetworkControllers[obj.thisEntity.unit_number] = nil
end

function BaseNet.addConnectables(source, connections, master)
    if valid(source) == false then return end
    if source.thisEntity == nil and source.thisEntity.valid == false then return end
    if source.createArms == nil then return end
    source:createArms()
    if source.connectedObjs == nil and source.connectedObjs.valid == false then return end
    for _, connected in pairs(source.connectedObjs) do
        for _, con in pairs(connected) do
            if valid(con) == false then goto continue end
            --if con.thisEntity.to_be_deconstructed() == true then goto continue end
            if con.thisEntity == nil and con.thisEntity.valid == false then goto continue end
            if connections[con.entID] ~= nil then goto continue end

            if con.thisEntity.name == Constants.NetworkController.main.name and con.entID ~= master.entID then
                con.thisEntity.order_deconstruction(master.thisEntity.force)
                goto continue
            end

            con.networkController = master
            connections[con.entID] = con
            master.network.powerDraw = master.network.powerDraw + (con.powerUsage or 0)

            if string.match(con.thisEntity.name, "RNS_ItemDrive") ~= nil then
                master.network.ItemDriveTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.entID] = con
                master.network:delta_ItemDrive_Partition(con.storedAmount, con.maxStorage)
                --The store hands out live engine stacks; the network bookkeeping
                --speaks the mod's dialect, so the bridge wraps each one.
                con.store:forEachStack(function(stack)
                    local wrapped = Itemstack:new(stack)
                    if wrapped ~= nil then
                        master.network:increase_tracked_item_count(wrapped.name, wrapped.count)
                        master.network:add_item_to_interface_cache(wrapped)
                    end
                end)
        
            elseif string.match(con.thisEntity.name, "RNS_FluidDrive") ~= nil then
                master.network.FluidDriveTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.entID] = con
                master.network:delta_FluidDrive_Partition(con.storedAmount, con.maxStorage)
                for n, v in pairs(con.fluidArray) do
                    master.network:increase_tracked_fluid_amount(n, v.amount)
                    master.network:add_fluid_to_interface_cache(v)
                end
        
            elseif con.thisEntity.name == Constants.NetworkCables.itemIO.name then
                table.insert(master.network.ItemIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], con.entID)
                --[[if con.processed == true then
                    table.insert(master.network.ItemIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], con.entID)
                else
                    table.insert(master.network.ItemIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], 1, con.entID)
                end]]
            elseif con.thisEntity.name == Constants.NetworkCables.fluidIO.name then
                table.insert(master.network.FluidIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], con.entID)
                --[[if con.processed == true then
                    table.insert(master.network.FluidIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], con.entID)
                else
                    table.insert(master.network.FluidIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.io], 1, con.entID)
                end]]
            elseif con.thisEntity.name == Constants.NetworkCables.externalIO.name then
                master.network.ExternalIOTable[1+Constants.Settings.RNS_Max_Priority-con.priority][con.type][con.entID] = con
                con:init_cache()
                if con.type == "item" then
                    master.network:delta_ItemExternal_Partition(con.storedAmount, con.capacity)
                else
                    master.network:delta_FluidExternal_Partition(con.storedAmount, con.capacity)
                end
                --A pure output bus only receives: EIO:update returns at once for it, so
                --contents booked here would never be corrected. Its capacity above still
                --counts, because the insert paths ask the partition for room.
                if con.cache ~= nil and con.io ~= "output" then
                    for i = 1, #con.cache do
                        local cached = con.cache[i]
                        if cached ~= nil and cached.name ~= "RNS_Empty" then
                            if con.type == "item" then
                                master.network:increase_tracked_item_count(cached.name, cached.count)
                                master.network:add_item_to_interface_cache(cached)
                            else
                                master.network:increase_tracked_fluid_amount(cached.name, cached.amount)
                                master.network:add_fluid_to_interface_cache(cached)
                            end
                        end
                    end
                end
            elseif con.thisEntity.name == Constants.NetworkInventoryInterface.name then
                master.network.NetworkInventoryInterfaceTable[1][con.entID] = con
        
            elseif con.thisEntity.name == Constants.NetworkCables.wirelessTransmitter.name then
                master.network.WirelessTransmitterTable[1][con.entID] = con
        
            elseif con.thisEntity.name == Constants.Detector.name then
                master.network.DetectorTable[1][con.mode][con.entID] = con
        
            elseif con.thisEntity.name == Constants.NetworkTransReceiver.transmitter.name then
                master.network.TransmitterTable[1][con.entID] = con
                
            elseif con.thisEntity.name == Constants.NetworkTransReceiver.receiver.name then
                master.network.ReceiverTable[1][con.entID] = con
            end
            
            BaseNet.addConnectables(con, connections, master)
            ::continue::
        end
    end
end

function BaseNet:getTooltips()
    
end

function BaseNet.generateArms(object)
    if object == nil then return end
    if object.thisEntity ~= nil and object.thisEntity.valid and object.thisEntity.to_be_deconstructed() == false then
        local areas = object:getCheckArea()
        object:resetConnection()
        for _, area in pairs(areas) do
            if object.thisEntity.name == Constants.Detector.name and object.disconnects[area.direction] == true and object.newState == true then goto next end
            if object.getDirection ~= nil and area.direction == object:getDirection() then goto next end--Prevent cable connection on the IO port

            local ents = object.thisEntity.surface.find_entities_filtered{area={area.startP, area.endP}}
            for _, ent in pairs(ents) do
                if ent ~= nil and ent.valid == true and ent.to_be_deconstructed() == false then
                    if ent ~= nil and storage.entityTable[ent.unit_number] ~= nil and string.match(ent.name, "RNS_") ~= nil then
                        local obj = storage.entityTable[ent.unit_number]
                        if (string.match(obj.thisEntity.name, "RNS_NetworkCableIO") ~= nil and obj:getConnectionDirection() == area.direction)
                            or (string.match(obj.thisEntity.name, "RNS_NetworkCableRamp") ~= nil and obj:getConnectionDirection() == area.direction)
                            or obj.thisEntity.name == Constants.WirelessGrid.name
                            or (obj.thisEntity.name == Constants.Detector.name and obj:is_disconnection_direction(area.direction) and obj.newState == true) then
                            --Do nothing
                        else
                            --A foreign force must neither tap this network nor kill it by
                            --joining a second controller (B-05). Forces connect only among
                            --themselves.
                            if obj.thisEntity.force == object.thisEntity.force then
                                if obj.color == nil then
                                    object.arms[area.direction] = Util.newRender(rendering.draw_sprite{sprite=Constants.NetworkCables.Cables[object.color].sprites[area.direction].name, target=object.thisEntity, surface=object.thisEntity.surface, render_layer="lower-object-above-shadow"})
                                    object.connectedObjs[area.direction] = {obj}
                                    BaseNet.join_network(object, obj)
                                elseif obj.color ~= "" and obj.color == object.color then
                                    object.arms[area.direction] = Util.newRender(rendering.draw_sprite{sprite=Constants.NetworkCables.Cables[object.color].sprites[area.direction].name, target=object.thisEntity, surface=object.thisEntity.surface, render_layer="lower-object-above-shadow"})
                                    object.connectedObjs[area.direction] = {obj}
                                    BaseNet.join_network(object, obj)
                                end
                            end
                        end
                        break
                    end
                end
            end
            ::next::
        end
    end
end

function BaseNet.update_network_controller(controller, objectID)
    if controller == nil or storage.entityTable[controller.entID] == nil then return end
    if objectID == nil or controller.network.connectedEntities[objectID] ~= nil then
        controller.network.shouldRefresh = true
    end
end

function BaseNet.exists_in_network(controller, objectID)
    if controller == nil or storage.entityTable[controller.entID] == nil then return false end
    --if controller.interactable and controller:interactable() == false then return false end
    return controller.network.connectedEntities[objectID] ~= nil
end

function BaseNet:exists(objectID)
    return self.connectedEntities[objectID] ~= nil
end

function BaseNet.join_network(main, side)
    if side.thisEntity.name == Constants.NetworkController.main.name then
        main.networkController = side
    else
        if BaseNet.exists_in_network(main.networkController, main.entID) then
            side.networkController = main.networkController
        else
            main.networkController = side.networkController
        end
    end
end

function BaseNet.postArms(object)
    local areas = object:getCheckArea()
    for _, area in pairs(areas) do
        --if object.thisEntity.name == Constants.Detector.name and object.disconnects[area.direction] == true and object.newState == true then goto next end
        local ents = object.thisEntity.surface.find_entities_filtered{area={area.startP, area.endP}}
        for _, ent in pairs(ents) do
            if ent ~= nil and ent.valid == true and storage.entityTable[ent.unit_number] ~= nil and string.match(ent.name, "RNS_") ~= nil then
                local obj = storage.entityTable[ent.unit_number]
                --if (string.match(obj.thisEntity.name, "RNS_NetworkCableIO") ~= nil and obj:getConnectionDirection() == area.direction)
                --    or (string.match(obj.thisEntity.name, "RNS_NetworkCableRamp") ~= nil and obj:getConnectionDirection() == area.direction)
                --    or obj.thisEntity.name == Constants.WirelessGrid.name
                --    or (obj.thisEntity.name == Constants.Detector.name and obj:is_disconnection_direction(area.direction) and obj.newState == true) then
                --    --Do nothing
                --else
                    obj:createArms()
                --end
            end
        end
        ::next::
    end
    
    if object.targetEntity then
        object.targetEntity:createArms()
    end
end

--Only the detector is moved here; the buses change mode through a refresh (see their
--interaction handlers).
function BaseNet:transfer_io_mode(obj, type, from, to)
    if type == "detector" then
        if self.DetectorTable[1][from][obj.entID] ~= nil then
            self.DetectorTable[1][from][obj.entID] = nil
            self.DetectorTable[1][to][obj.entID] = obj
        end
        return
    end
end

function BaseNet:increase_tracked_item_count(name, count)
    if name == "" or name == nil then return end
    local storedAmount = self.Contents.item[name] or 0
    self.Contents.item[name] = storedAmount + count
end

function BaseNet:decrease_tracked_item_count(name, count)
    if name == "" or name == nil then return end
    local storedAmount = self.Contents.item[name] or 0
    self.Contents.item[name] = storedAmount - count
    if self.Contents.item[name] <= 0 then self.Contents.item[name] = 0 end
end

function BaseNet:increase_tracked_fluid_amount(name, amount)
    if name == "" or name == nil then return end
    local storedAmount = self.Contents.fluid[name] or 0
    self.Contents.fluid[name] = storedAmount + amount
end

function BaseNet:decrease_tracked_fluid_amount(name, amount)
    if name == "" or name == nil then return end
    local storedAmount = self.Contents.fluid[name] or 0
    self.Contents.fluid[name] = storedAmount - amount
    if self.Contents.fluid[name] <= 0 then self.Contents.fluid[name] = 0 end
end

function BaseNet:has_cache(mode, type, key)
    if type == "drive" then
        return (self[mode.."DriveCache"][key] ~= nil and {true} or {false})[1]
    elseif type == "external" then
        return (self[mode.."ExternalCache"][key] ~= nil and {true} or {false})[1]
    end
    return false
end

function BaseNet:get_cache(mode, type, key)
    if type == "drive" then
        return self[mode.."DriveCache"][key]
    elseif type == "external" then
        return self[mode.."ExternalCache"][key]
    end
    return nil
end

function BaseNet:put_cache(mode, type, key, obj)
    if type == "drive" then
        self[mode.."DriveCache"][key] = obj
    elseif type == "external" then
        self[mode.."ExternalCache"][key] = obj
    end
end

function BaseNet:remove_cache(mode, type, key)
    if type == "drive" then
        self[mode.."DriveCache"][key] = nil
    elseif type == "external" then
        self[mode.."ExternalCache"][key] = nil
    end
end

function BaseNet:is_full()
    return self:is_ItemDrivePartitions_Full() and self:is_FluidDrivePartitions_Full() and self:is_ItemExternalPartitions_Full() and self:is_FluidExternalPartitions_Full()
end

function BaseNet:is_empty()
    return self:is_ItemDrivePartitions_Empty() and self:is_FluidDrivePartitions_Empty() and self:is_ItemExternalPartitions_Empty() and self:is_FluidExternalPartitions_Empty()
end

function BaseNet:is_ItemDrivePartitions_Full()
    local id = self.StoredPartition.itemDrive
    return id.storedAmount >= id.capacity
end

function BaseNet:is_FluidDrivePartitions_Full()
    local fd = self.StoredPartition.fluidDrive
    return fd.storedAmount >= fd.capacity
end

function BaseNet:is_ItemExternalPartitions_Full()
    local ie = self.StoredPartition.itemExternal
    return ie.storedAmount >= ie.capacity
end

function BaseNet:is_FluidExternalPartitions_Full()
    local fe = self.StoredPartition.fluidExternal
    return fe.storedAmount >= fe.capacity
end

function BaseNet:is_ItemDrivePartitions_Empty()
    return self.StoredPartition.itemDrive.storedAmount <= 0
end

function BaseNet:is_FluidDrivePartitions_Empty()
    return self.StoredPartition.fluidDrive.storedAmount <= 0
end

function BaseNet:is_ItemExternalPartitions_Empty()
    return self.StoredPartition.itemExternal.storedAmount <= 0
end

function BaseNet:is_FluidExternalPartitions_Empty()
    return self.StoredPartition.fluidExternal.storedAmount <= 0
end

function BaseNet:delta_ItemDrive_Partition(storedAmount, capacity)
    local id = self.StoredPartition.itemDrive
    id.storedAmount = id.storedAmount + storedAmount
    id.capacity = id.capacity + capacity
    if id.storedAmount <= 0 then id.storedAmount = 0 end
    if id.capacity <= 0 then id.capacity = 0 end
end

function BaseNet:delta_FluidDrive_Partition(storedAmount, capacity)
    local fd = self.StoredPartition.fluidDrive
    fd.storedAmount = fd.storedAmount + storedAmount
    fd.capacity = fd.capacity + capacity
    if fd.storedAmount <= 0 then fd.storedAmount = 0 end
    if fd.capacity <= 0 then fd.capacity = 0 end
end

function BaseNet:delta_ItemExternal_Partition(storedAmount, capacity)
    local ie = self.StoredPartition.itemExternal
    ie.storedAmount = ie.storedAmount + storedAmount
    ie.capacity = ie.capacity + capacity
    if ie.storedAmount <= 0 then ie.storedAmount = 0 end
    if ie.capacity <= 0 then ie.capacity = 0 end
end

function BaseNet:delta_FluidExternal_Partition(storedAmount, capacity)
    local fe = self.StoredPartition.fluidExternal
    fe.storedAmount = fe.storedAmount + storedAmount
    fe.capacity = fe.capacity + capacity
    if fe.storedAmount <= 0 then fe.storedAmount = 0 end
    if fe.capacity <= 0 then fe.capacity = 0 end
end
-----------------------------------------------------------------------------------------------Inserting and Extracting things for the Interfaces to load faster---------------------------------------------------------------------------------------------------------------------------
function BaseNet:add_item_to_interface_cache(itemstack)
    if itemstack == nil then return end
    self.interfaceCache.item[itemstack.name] = self.interfaceCache.item[itemstack.name] or {}
    Util.item_add_list_into_table(self.interfaceCache.item[itemstack.name], itemstack)
end

function BaseNet:remove_item_from_interface_cache(itemstack)
    if itemstack == nil or self.interfaceCache.item[itemstack.name] == nil then return end
    --What is still to be taken out. Each entry used to be split by the full count again,
    --so spreading a removal over two entries took out more than was removed.
    local remaining = itemstack.count
    for i, item in pairs(self.interfaceCache.item[itemstack.name]) do
        local data = Itemstack:reload(item)
        if data:compare_itemstacks(itemstack, true) == true then
            --split answers nil when an exact match would leave a stack of one that
            --differs from the master; that entry is skipped, not dereferenced.
            local split = data:split(itemstack, remaining, true)
            if split ~= nil then
                remaining = remaining - split.count
                if data.count <= 0 then
                    self.interfaceCache.item[itemstack.name][i] = nil
                end
                if remaining <= 0 then return end
            end
        end
    end
end

function BaseNet:add_fluid_to_interface_cache(fluid)
    if fluid == nil then return end
    self.interfaceCache.fluid[fluid.name] = self.interfaceCache.fluid[fluid.name] or {}
    Util.fluid_add_list_into_table(self.interfaceCache.fluid[fluid.name], fluid)
end

function BaseNet:remove_fluid_from_interface_cache(fluidstack)
    --A fluid the network never booked has no list; pairs(nil) threw (B-48).
    if fluidstack == nil or self.interfaceCache.fluid[fluidstack.name] == nil then return end
    for i, fluid in pairs(self.interfaceCache.fluid[fluidstack.name]) do
        fluid.amount = fluid.amount - fluidstack.amount
        if fluid.amount <= 0 then
            self.interfaceCache.fluid[fluidstack.name][i] = nil
            return
        end
    end
end
-----------------------------------------------------------------------------------------------Extracting Fluids from the Network---------------------------------------------------------------------------------------------------------------------------
function BaseNet:extract_fluid_from_drive(to_tank, drive, filter, transportCapacity, fluid_box)
    local fluid = to_tank.thisEntity.fluidbox[fluid_box.index]
    local storedFluidAmount = (fluid ~= nil and fluid.amount or 0)
    local storedFluidTemperature = (fluid ~= nil and fluid.temperature or 0)

    local max_capacity = to_tank.thisEntity.fluidbox.get_capacity(fluid_box.index)

    local takeAmount = math.min(math.min(max_capacity - storedFluidAmount, transportCapacity), drive.fluidArray[filter].amount)
    --A full target takes nothing, and the mix below would divide 0 by 0.
    if takeAmount <= 0 then return transportCapacity end
    transportCapacity = transportCapacity - takeAmount <= 0 and 0 or transportCapacity - takeAmount

    local takeTemperature = drive.fluidArray[filter].temperature
    drive:remove_fluid(filter, takeAmount)
    self:decrease_tracked_fluid_amount(filter, takeAmount)
    self:delta_FluidDrive_Partition(-takeAmount, 0)
    self:remove_fluid_from_interface_cache({name=filter, amount=takeAmount, temperature=takeTemperature})

    local a0 = storedFluidAmount
    local t0 = storedFluidTemperature
    local a1 = takeAmount
    local t1 = takeTemperature
    storedFluidAmount = a0 + a1
    storedFluidTemperature = (a0*t0 + a1*t1) / (a0 + a1)
    to_tank.thisEntity.fluidbox[fluid_box.index] = {
        name = filter,
        amount = storedFluidAmount,
        temperature = storedFluidTemperature
    }
    return transportCapacity
end

function BaseNet:extract_fluid_from_external(to_tank, external, filter, transportCapacity, fluid_box)
    local fluid = to_tank.thisEntity.fluidbox[fluid_box.index]
    local storedFluidAmount = (fluid ~= nil and fluid.amount or 0)
    local storedFluidTemperature = (fluid ~= nil and fluid.temperature or 0)

    local max_capacity = to_tank.thisEntity.fluidbox.get_capacity(fluid_box.index)

    --The caller decided from the bus's cache, which can be a few ticks old: the source
    --may be empty by now, or hold another fluid.
    local sourceBox = external.focusedEntity.thisEntity.fluidbox
    local sourceIndex = external.focusedEntity.fluid_box.index
    local source = sourceBox[sourceIndex]
    if source == nil or source.name ~= filter then
        external:update(self)
        return transportCapacity
    end

    local takeAmount = math.min(math.min(max_capacity - storedFluidAmount, transportCapacity), source.amount)
    if takeAmount <= 0 then return transportCapacity end
    transportCapacity = transportCapacity - takeAmount <= 0 and 0 or transportCapacity - takeAmount

    local takeTemperature = source.temperature

    if takeAmount == source.amount then
        sourceBox[sourceIndex] = nil
    else
        sourceBox[sourceIndex] = {
            name = filter,
            amount = source.amount - takeAmount,
            temperature = takeTemperature
        }
    end

    --self:decrease_fluid_amount(filter, takeAmount)

    local a0 = storedFluidAmount
    local t0 = storedFluidTemperature
    local a1 = takeAmount
    local t1 = takeTemperature

    storedFluidAmount = a0 + a1
    storedFluidTemperature = (a0*t0 + a1*t1) / (a0 + a1)


    to_tank.thisEntity.fluidbox[fluid_box.index] = {
        name = filter,
        amount = storedFluidAmount,
        temperature = storedFluidTemperature
    }
    
    external:update(self)
    return transportCapacity
end

function BaseNet.transfer_from_network_to_tank(network, to_tank, transportCapacity, filter)
    local fluid_box = to_tank.fluid_box
    --local networkAmount = network.Contents.fluid[filter]
    --if networkAmount <= 0 then return 0 end
    if fluid_box.filter ~= "" and fluid_box.filter ~= filter then return 0 end
    --An unlocked target can still hold another fluid; writing `filter` over it would
    --relabel all of it.
    local present = to_tank.thisEntity.fluidbox[fluid_box.index]
    if present ~= nil and present.name ~= filter then return 0 end

    if network:has_cache("export", "drive", filter) then
        local drive = storage.entityTable[network:get_cache("export", "drive", filter)]
        if drive == nil or drive.valid == false or network:exists(drive.entID) == false then
            network:remove_cache("export", "drive", filter)
        else
            if drive:interactable() and drive.fluidArray[filter] and drive.fluidArray[filter].amount > 0 then
                transportCapacity = network:extract_fluid_from_drive(to_tank, drive, filter, transportCapacity, fluid_box)
                if transportCapacity <= 0 then return 0 end
            else
                network:remove_cache("export", "drive", filter)
            end
        end
    end

    if network:has_cache("export", "external", filter) then
        local external = storage.entityTable[network:get_cache("export", "external", filter)]
        if external == nil or external.valid == false or network:exists(external.entID) == false then
            network:remove_cache("export", "external", filter)
        else
            if external:interactable() and external:target_interactable() and external.type == "fluid" and string.match(external.io, "input") ~= nil and string.match(external.focusedEntity.fluid_box.flow, "output") ~= nil
            and external.cache[1] and external.cache[1].name == filter and external.cache[1].amount > 0 then
                transportCapacity = network:extract_fluid_from_external(to_tank, external, filter, transportCapacity, fluid_box)
                if transportCapacity <= 0 then return 0 end
            else
                network:remove_cache("export", "external", filter)
            end
        end
    end

    for p = 1, Constants.Settings.RNS_Max_Priority*2 + 1 do
        local priorityF = network.FluidDriveTable[p]
        local priorityE = network.ExternalIOTable[p].fluid
        local b = 0
        for _, drive in pairs(priorityF) do
            if network:is_FluidDrivePartitions_Empty() then b = b + 1 break end
            if drive:interactable() and drive.fluidArray[filter] and drive.fluidArray[filter].amount > 0 then
                transportCapacity = network:extract_fluid_from_drive(to_tank, drive, filter, transportCapacity, fluid_box)
                if transportCapacity <= 0 then
                    network:put_cache("export", "drive", filter, drive.thisEntity.unit_number)
                    return 0
                end
            end
        end

        for _, external in pairs(priorityE) do
            if network:is_FluidExternalPartitions_Empty() then b = b + 1 break end
            if external:interactable() and external:target_interactable() and external.type == "fluid" and string.match(external.io, "input") ~= nil and string.match(external.focusedEntity.fluid_box.flow, "output") ~= nil
            and external.cache[1] and external.cache[1].name == filter and external.cache[1].amount > 0 then
                transportCapacity = network:extract_fluid_from_external(to_tank, external, filter, transportCapacity, fluid_box)
                if transportCapacity <= 0 then
                    network:put_cache("export", "external", filter, external.thisEntity.unit_number)
                    return 0
                end
            end
        end
        if b == 2 then return transportCapacity end
    end

    return transportCapacity
end
-------------------------------------------------------------------------------------------------------Inserting Fluids into the Network-------------------------------------------------------------------------------------------------------------------
--The source tank as it is now. The caller reads the fluidbox once and then offers it to
--several drives and externals in a row; fluidbox[i] is a copy, so working from that copy
--booked the same fluid again on every call. nil when the tank no longer holds `name`.
local function liveSourceFluid(from_tank, fluid_box, name)
    local live = from_tank.thisEntity.fluidbox[fluid_box.index]
    if live == nil or live.name ~= name or live.amount <= 0 then return nil end
    return live
end

local function takeFromSource(from_tank, fluid_box, live, amount)
    if live.amount - amount <= 0 then
        from_tank.thisEntity.fluidbox[fluid_box.index] = nil
    else
        from_tank.thisEntity.fluidbox[fluid_box.index] = {
            name = live.name,
            amount = live.amount - amount,
            temperature = live.temperature
        }
    end
end

function BaseNet:insert_fluid_into_drive(drive, fluid, transportCapacity, from_tank, fluid_box)
    local live = liveSourceFluid(from_tank, fluid_box, fluid.name)
    if live == nil then return transportCapacity end
    local insertedAmount = drive:insert_fluid(live.name, math.min(transportCapacity, live.amount), live.temperature)
    if insertedAmount <= 0 then return transportCapacity end
    transportCapacity = transportCapacity - insertedAmount <= 0 and 0 or transportCapacity - insertedAmount
    takeFromSource(from_tank, fluid_box, live, insertedAmount)

    self:increase_tracked_fluid_amount(live.name, insertedAmount)
    self:delta_FluidDrive_Partition(insertedAmount, 0)
    self:add_fluid_to_interface_cache({name=live.name, amount=insertedAmount, temperature=live.temperature})
    return transportCapacity
end

function BaseNet:insert_fluid_into_external(external, transportCapacity, fluid_box, fluid, from_tank)
    local live = liveSourceFluid(from_tank, fluid_box, fluid.name)
    if live == nil then return transportCapacity end

    local e_fluid_box = external.focusedEntity.fluid_box
    local target = external.focusedEntity.thisEntity.fluidbox
    local e_fluid = target[e_fluid_box.index]
    --Never relabel what the target already holds, and respect its fluid lock.
    if e_fluid ~= nil and e_fluid.name ~= live.name then return transportCapacity end
    if e_fluid == nil and e_fluid_box.filter ~= "" and e_fluid_box.filter ~= live.name then return transportCapacity end

    local e_storedFluidAmount = e_fluid ~= nil and e_fluid.amount or 0
    local e_storedFluidTemperature = e_fluid ~= nil and e_fluid.temperature or live.temperature
    --Bounded by the room in the target, by the bus, and by what the source holds.
    local insertedAmount = math.min(target.get_capacity(e_fluid_box.index) - e_storedFluidAmount, transportCapacity, live.amount)
    if insertedAmount <= 0 then return transportCapacity end
    transportCapacity = transportCapacity - insertedAmount <= 0 and 0 or transportCapacity - insertedAmount

    target[e_fluid_box.index] = {
        name = live.name,
        amount = e_storedFluidAmount + insertedAmount,
        temperature = (e_storedFluidAmount * e_storedFluidTemperature + insertedAmount * live.temperature) / (e_storedFluidAmount + insertedAmount)
    }
    takeFromSource(from_tank, fluid_box, live, insertedAmount)

    external:update(self)
    return transportCapacity
end

function BaseNet.transfer_from_tank_to_network(network, from_tank, transportCapacity)
    local fluid_box = from_tank.fluid_box
    local fluid = from_tank.thisEntity.fluidbox[fluid_box.index]
    if fluid == nil then return transportCapacity end

    if network:has_cache("import", "drive", fluid.name) then
        local drive = storage.entityTable[network:get_cache("import", "drive", fluid.name)]
        if drive == nil or drive.valid == false or network:exists(drive.entID) == false then
            network:remove_cache("import", "drive", fluid.name)
        else
            if drive:interactable() and Util.filter_accepts_fluid(drive.filters, drive.whitelistBlacklist, fluid.name) and drive:getRemainingStorageSize() > 0 then
                transportCapacity = network:insert_fluid_into_drive(drive, fluid, transportCapacity, from_tank, fluid_box)
                if transportCapacity <= 0 then return 0 end
            else
                network:remove_cache("import", "drive", fluid.name)
            end
        end
    end
    
    if network:has_cache("import", "external", fluid.name) then
        local external = storage.entityTable[network:get_cache("import", "external", fluid.name)]
        if external == nil or external.valid == false or network:exists(external.entID) == false then
            network:remove_cache("import", "external", fluid.name)
        else
            if external.type == "fluid" and string.match(external.io, "output") ~= nil and string.match(external.focusedEntity.fluid_box.flow, "input")
            and external:interactable() and external:target_interactable() and Util.filter_accepts_fluid(external.filters.fluid, external.whitelistBlacklist, fluid.name) then
                local e_fluid_box = external.focusedEntity.fluid_box
                local e_fluid = external.focusedEntity.thisEntity.fluidbox[e_fluid_box.index]
                if e_fluid == nil and e_fluid_box.filter ~= "" and e_fluid_box.filter ~= fluid.name then
                    network:remove_cache("import", "external", fluid.name)
                elseif e_fluid ~= nil and e_fluid.name ~= fluid.name then
                    network:remove_cache("import", "external", fluid.name)
                end
                transportCapacity = network:insert_fluid_into_external(external, transportCapacity, fluid_box, fluid, from_tank)
                if transportCapacity <= 0 then return 0 end
            else
                network:remove_cache("import", "external", fluid.name)
            end
        end
    end
    for p = 1, Constants.Settings.RNS_Max_Priority*2 + 1 do
        local priorityF = network.FluidDriveTable[p]
        local priorityE = network.ExternalIOTable[p].fluid
        local b = 0
        for _, drive in pairs(priorityF) do
            if network:is_FluidDrivePartitions_Full() then b = b + 1 break end
            if drive:interactable() and Util.filter_accepts_fluid(drive.filters, drive.whitelistBlacklist, fluid.name) and drive:getRemainingStorageSize() > 0 then
                transportCapacity = network:insert_fluid_into_drive(drive, fluid, transportCapacity,  from_tank, fluid_box)
                if transportCapacity <= 0 then
                    network:put_cache("import", "drive", fluid.name, drive.thisEntity.unit_number)
                    return 0
                end
            end
        end

        for _, external in pairs(priorityE) do
            if network:is_FluidExternalPartitions_Full() then b = b + 1 break end
            if external.type == "fluid" and string.match(external.io, "output") ~= nil and string.match(external.focusedEntity.fluid_box.flow, "input")
            and external:interactable() and external:target_interactable() and Util.filter_accepts_fluid(external.filters.fluid, external.whitelistBlacklist, fluid.name) then
                local e_fluid_box = external.focusedEntity.fluid_box
                local e_fluid = external.focusedEntity.thisEntity.fluidbox[e_fluid_box.index]
                --[[if e_fluid == nil and e_fluid_box.filter ~= "" and e_fluid_box.filter ~= fluid.name then
                    network:remove_cache("import", "external", fluid.name)
                elseif e_fluid ~= nil and e_fluid.name ~= fluid.name then
                    network:remove_cache("import", "external", fluid.name)
                end]]
                transportCapacity = network:insert_fluid_into_external(external, transportCapacity, fluid_box, fluid, from_tank)
                if transportCapacity <= 0 then
                    network:put_cache("import", "external", fluid.name, external.thisEntity.unit_number)
                    return 0
                end
            end
        end
        if b == 2 then return transportCapacity end
    end

    return transportCapacity
end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function BaseNet.inventory_is_sortable(inv)
    return BaseNet.entity_is_sortable(inv.entity_owner)
end

function BaseNet.entity_is_sortable(ent)
    if ent ~= nil and ent.prototype.type == "lab" then return false end
    return true
end
-------------------------------------------------------------------------------------------------Extracting Items from the Network-------------------------------------------------------------------------------------------------------------------------
function BaseNet:extract_item_from_drive(drive, inv, itemstack_master, storedItem, transferCapacity, exact)
    --Take out only what the target can hold. The put-back below returns the rest as a
    --copy of the first stack, which spreads that stack's ammo or durability over the
    --whole rest (B-49); bounding first keeps that path for the cases the engine's
    --estimate gets wrong (durability, filtered slots).
    --A 0 from the estimate is not trusted: the caller has already asked can_insert, and
    --for durability items the estimate can be wrong, which would stall them for good.
    local wanted = math.min(storedItem.count, transferCapacity)
    local room = inv.get_insertable_count({name = itemstack_master.name, quality = ItemStore.qualityOf(itemstack_master.quality)})
    if room > 0 then wanted = math.min(wanted, room) end
    if wanted <= 0 then return transferCapacity end
    local removedAmount, stack = drive:remove_item(itemstack_master, wanted, exact)
    if stack == nil or removedAmount <= 0 then return transferCapacity end
    --The target can take less than was removed: only the player path bounds the
    --capacity by free room, and can_insert promises a single item. Whatever did not go
    --in returns to the drive, which just freed that room; only what left it is booked.
    local inserted = inv.insert(stack)
    if inserted < removedAmount then
        local rest = stack:copy()
        rest.count = removedAmount - inserted
        local returned = drive:add_or_merge_basic_item(rest, rest.count)
        --Not expected, since the room was freed a moment ago; logged, not hidden.
        if returned < rest.count then
            log("RNSRedux: " .. (rest.count - returned) .. " x " .. rest.name .. " could not return to drive " .. tostring(drive.entID))
        end
    end
    if inserted <= 0 then return transferCapacity end
    transferCapacity = transferCapacity - inserted
    stack.count = inserted
    self:decrease_tracked_item_count(itemstack_master.name, inserted)
    self:delta_ItemDrive_Partition(-inserted, 0)
    self:remove_item_from_interface_cache(stack)
    return transferCapacity
end

function BaseNet:extract_item_from_external(external, inv, transferCapacity, itemstack_master, supportModified, exact)
    for i = 1, external.focusedEntity.inventory.output.max do
        if transferCapacity <= 0 then break end
        local einv = external.focusedEntity.thisEntity.get_inventory(external.focusedEntity.inventory.output.values[external.focusedEntity.inventory.output.index])
        if BaseNet.inventory_is_sortable(einv) then einv.sort_and_merge() end
        local _, o = einv.find_item_stack(itemstack_master.name)
        --Not in this inventory: try the next one. A break here ended the search at the
        --first output inventory of a roboport, silo or burner machine.
        if o == nil then goto nextInventory end
        for j = o, #einv do
            local storedAmount = einv.get_item_count(itemstack_master.name) or 0
            if storedAmount <= 0 or transferCapacity <= 0 then break end
            local item = einv[j]
            if item == nil then break end
            if item.valid_for_read == false or item.count <= 0 then break end
            local inv_item = Itemstack:new(item)
            if inv_item == nil then goto next end
            if supportModified == false and inv_item.modified then goto next end
            if itemstack_master:compare_itemstacks(inv_item, exact) then
                local extractSize = math.min(math.min(transferCapacity, storedAmount), inv_item.count)
                local splitStack = inv_item:split(itemstack_master, extractSize, exact)
                if splitStack == nil then goto next end
                if splitStack.modified == false or splitStack.health ~= 1.0 then
                    local inserted = inv.insert(splitStack)
                    --What the target did not take stays in the container.
                    inv_item.count = inv_item.count + (splitStack.count - inserted)
                    --Nothing went in: leave the live stack alone (see insert_item_into_external).
                    if inserted <= 0 then goto next end
                    transferCapacity = transferCapacity - inserted
                    item.count = inv_item.count
                    if item.count > 0 then
                        if inv_item.ammo ~= nil then item.ammo = inv_item.ammo end
                        if inv_item.durability ~= nil then item.durability = inv_item.durability end
                    end
                    --self:decrease_item_count(splitStack.name, splitStack.count)
                else
                    local slot, index = inv.find_empty_stack(splitStack.name)
                    if slot ~= nil then
                        if item.count > 1 then
                            local removeAmount = inv[index].set_stack(item) and splitStack.count or 0
                            item.count = item.count - splitStack.count
                            inv[index].count = inv[index].count - inv_item.count
                            transferCapacity = transferCapacity - removeAmount
                        else
                            local removeAmount = inv[index].transfer_stack(item) and item.count or 0
                            transferCapacity = transferCapacity - removeAmount
                        end
                        --self:decrease_item_count(item.name, removeAmount)
                    end
                end
            end
            ::next::
        end
        ::nextInventory::
        Util.next_index(external.focusedEntity.inventory.output)
    end
    external:update(self)
    return transferCapacity
end

function BaseNet.transfer_from_network_to_inv(network, to_inv, itemstack_master, transferCapacity, supportModified, exact, isPlayer)
    --local storedAmount = network.Contents.item[itemstack_master.name] or 0
    --if storedAmount <= 0 then return 0 end
    --transferCapacity = math.min(transferCapacity, storedAmount)

    for i = 1, to_inv.inventory.input.max do
        local inv = to_inv.thisEntity.get_inventory(to_inv.inventory.input.values[to_inv.inventory.input.index])
        if BaseNet.inventory_is_sortable(inv) then inv.sort_and_merge() end

        local stacks = math.ceil(inv.get_item_count(itemstack_master.name) / prototypes.item[itemstack_master.name].stack_size)
        local lastStackFillableAmount = prototypes.item[itemstack_master.name].stack_size*stacks - inv.get_item_count(itemstack_master.name)
        local emptyStacks = inv.count_empty_stacks(true, false)
        local emptyStacksFillableAmount = prototypes.item[itemstack_master.name].stack_size*emptyStacks + lastStackFillableAmount
        
        if inv.can_insert(itemstack_master.name) == false then goto fin end

        if isPlayer then transferCapacity = math.min(transferCapacity, emptyStacksFillableAmount) end
        if transferCapacity <= 0 then goto fin end

        if network:has_cache("export", "drive", itemstack_master.name) and itemstack_master.modified == false then
            local drive = storage.entityTable[network:get_cache("export", "drive", itemstack_master.name)]
            --ID:rebuild(drive)
            if drive == nil or drive.valid == false or network:exists(drive.entID) == false then
                network:remove_cache("export", "drive", itemstack_master.name)
            else
                local storedItem = drive:getStoredStack(itemstack_master.name, itemstack_master.quality)
                if drive:interactable() and storedItem ~= nil and itemstack_master:compare_itemstacks(storedItem, exact) then
                    transferCapacity = network:extract_item_from_drive(drive, inv, itemstack_master, storedItem, transferCapacity, exact)
                    if transferCapacity <= 0 then goto fin end
                else
                    network:remove_cache("export", "drive", itemstack_master.name)
                end
            end
        end

        if network:has_cache("export", "external", itemstack_master.name) then
            local external = storage.entityTable[network:get_cache("export", "external", itemstack_master.name)]
            if external == nil or external.valid == false or network:exists(external.entID) == false then
                network:remove_cache("export", "external", itemstack_master.name)
            else
                if external:interactable() and external:target_interactable() and string.match(external.io, "input") ~= nil and external.type == "item" 
                and external.focusedEntity.inventory.output.max ~= 0 and network:exists(external.entID) then
                    --local storedAmount = external.focusedEntity.thisEntity.get_item_count(itemstack_master.name)
                    --if storedAmount <= 0 then goto next end
                    transferCapacity = network:extract_item_from_external(external, inv, transferCapacity, itemstack_master, supportModified, exact)
                    if transferCapacity <= 0 then goto fin end
                else
                    network:remove_cache("export", "external", itemstack_master.name)
                end
            end
        end

        for p = 1, Constants.Settings.RNS_Max_Priority*2 + 1 do
            local priorityD = network.ItemDriveTable[p]
            local priorityE = network.ExternalIOTable[p].item
            local b = 0

            if itemstack_master.modified == false then
                for _, drive in pairs(priorityD) do
                    if network:is_ItemDrivePartitions_Empty() then b = b + 1 break end
                    local storedItem = drive:getStoredStack(itemstack_master.name, itemstack_master.quality)
                    if drive:interactable() and storedItem ~= nil and itemstack_master:compare_itemstacks(storedItem, exact) then
                        transferCapacity = network:extract_item_from_drive(drive, inv, itemstack_master, storedItem, transferCapacity, exact)
                        if transferCapacity <= 0 then
                            network:put_cache("export", "drive", itemstack_master.name, drive.thisEntity.unit_number)
                            goto fin
                        end
                    end
                end
            end

            for _, external in pairs(priorityE) do
                if network:is_ItemExternalPartitions_Empty() then b = b + 1 break end
                if external:interactable() and external:target_interactable() and string.match(external.io, "input") ~= nil and external.type == "item" 
                and external.focusedEntity.inventory.output.max ~= 0 then
                    --local storedAmount = external.focusedEntity.thisEntity.get_item_count(itemstack_master.name)
                    --if storedAmount <= 0 then goto next end
                    transferCapacity = network:extract_item_from_external(external, inv, transferCapacity, itemstack_master, supportModified, exact)
                    if transferCapacity <= 0 then
                        network:put_cache("export", "external", itemstack_master.name, external.thisEntity.unit_number)
                        goto fin
                    end
                end
            end

            if b == 2 then return transferCapacity end

            if transferCapacity <= 0 then goto fin end
        end
        ::fin::
        Util.next_index(to_inv.inventory.input)
        if transferCapacity <= 0 then break end
    end

    return transferCapacity
end

----------------------------------------------------------------------------------------------Importing Items into the Network----------------------------------------------------------------------------------------------------------------------------
function BaseNet:insert_item_into_drive(item, inv_item, drive, transferCapacity, itemstack_master, remainingStorage, exact)
    --The drive input rejects quality items, which is the documented policy: no silent
    --downgrade and no silent merge. The check has to sit here rather than deeper,
    --because the split below is what shrinks the source stack -- rejecting after it
    --would destroy the item instead of leaving it where it was.
    --Returning the capacity untouched means the caller simply moves on to the next
    --drive or the next item, so nothing is lost and nothing loops.
    if not ItemStore.isStorable(inv_item) then return transferCapacity end

    local extractSize = math.min(math.min(transferCapacity, inv_item.count), remainingStorage)
    local splitStack = inv_item:split(itemstack_master, extractSize, exact)
    if splitStack == nil then return transferCapacity end
    local inserted = drive:add_or_merge_basic_item(splitStack, extractSize)
    --The source keeps what the drive did not take, and the books carry only what went
    --in. Before, the source was cut by the full split and the counters booked it too.
    if inserted < splitStack.count then
        inv_item.count = inv_item.count + (splitStack.count - inserted)
        splitStack.count = inserted
    end
    --The live stack in `item` has not been touched yet, so nothing to undo.
    if inserted <= 0 then return transferCapacity end
    transferCapacity = transferCapacity - inserted
    item.count = inv_item.count
    if item.count > 0 then
        if inv_item.ammo ~= nil then item.ammo = inv_item.ammo end
        if inv_item.durability ~= nil then item.durability = inv_item.durability end
    end
    self:increase_tracked_item_count(splitStack.name, splitStack.count)
    self:delta_ItemDrive_Partition(splitStack.count, 0)
    self:add_item_to_interface_cache(splitStack)
    return transferCapacity
end

function BaseNet:insert_item_into_external(external, item, inv_item, itemstack_master, transferCapacity, exact)
    for k = 1, external.focusedEntity.inventory.input.max do
        if transferCapacity <= 0 then break end
        local ext_inv = external.focusedEntity.thisEntity.get_inventory(external.focusedEntity.inventory.input.values[external.focusedEntity.inventory.input.index])
        if ext_inv.can_insert(inv_item.name) then
            local stacks = math.ceil(ext_inv.get_item_count(itemstack_master.name) / prototypes.item[itemstack_master.name].stack_size)
            local lastStackFillableAmount = prototypes.item[itemstack_master.name].stack_size*stacks - ext_inv.get_item_count(itemstack_master.name)
            local emptyStacks = ext_inv.count_empty_stacks(true, false)
            local emptyStacksFillableAmount = prototypes.item[itemstack_master.name].stack_size*emptyStacks + lastStackFillableAmount

            local extractSize = math.min(math.min(transferCapacity, inv_item.count), emptyStacksFillableAmount)
            local splitStack = inv_item:split(itemstack_master, extractSize, exact)
            if splitStack == nil then goto nextInventory end

            if splitStack.modified == false or splitStack.health ~= 1.0 then
                local inserted = ext_inv.insert(splitStack)
                --What the container did not take stays in the source stack.
                inv_item.count = inv_item.count + (splitStack.count - inserted)
                --Nothing went in: leave the live stack alone. split reset the copy's ammo
                --and durability to full, and writing them back would refill it.
                if inserted <= 0 then goto nextInventory end
                transferCapacity = transferCapacity - inserted
                item.count = inv_item.count
                if item.count > 0 then
                    if inv_item.ammo ~= nil then item.ammo = inv_item.ammo end
                    if inv_item.durability ~= nil then item.durability = inv_item.durability end
                end
                --self:increase_item_count(splitStack.name, splitStack.count)
            else
                local slot, index = ext_inv.find_empty_stack(inv_item.name)
                if slot ~= nil then
                    if item.count > 1 then
                        local insertAmount = ext_inv[index].set_stack(item) and splitStack.count or 0
                        item.count = item.count - splitStack.count
                        ext_inv[index].count = ext_inv[index].count - inv_item.count
                        transferCapacity = transferCapacity - insertAmount
                    else
                        local insertAmount = ext_inv[index].transfer_stack(item) and item.count or 0
                        transferCapacity = transferCapacity - insertAmount
                    end
                    
                    --self:increase_item_count(item.name, insertAmount)
                end
            end
        end
        ::nextInventory::
        Util.next_index(external.focusedEntity.inventory.input)
    end
    external:update(self)
    return transferCapacity
end

function BaseNet.transfer_from_inv_to_network(network, from_inv, itemstack_master, filters, whitelistBlacklist, transferCapacity, supportModified, exact)
    for i = 1, from_inv.inventory.output.max do
        local inv = from_inv.thisEntity.get_inventory(from_inv.inventory.output.values[from_inv.inventory.output.index])
        if BaseNet.inventory_is_sortable(inv) then inv.sort_and_merge() end
        local o = 1
        if itemstack_master ~= nil then
            local _, oo = inv.find_item_stack(itemstack_master.name)
            if oo ~= nil then o = oo else goto fin end
        end
        for j = o, #inv do
            if transferCapacity <= 0 or inv.is_empty() then goto fin end
            if itemstack_master ~= nil and inv.get_item_count(itemstack_master.name) == 0 then goto fin end
            local item = inv[j]
            if item == nil then goto next end
            if item.valid_for_read == false or item.count <= 0 then goto next end
            local master = itemstack_master or Itemstack.create_template(item.name)

            if Util.filter_accepts_item(filters, whitelistBlacklist, item.name) then
                local inv_item = Itemstack:new(item)
                if inv_item == nil then goto next end
                if supportModified == false and inv_item.modified == true then goto next end
                if inv_item.modified == true and network:is_ItemExternalPartitions_Full() then goto next end

                if network:has_cache("import", "drive", inv_item.name) and inv_item.modified == false then
                    local drive = storage.entityTable[network:get_cache("import", "drive", inv_item.name)]
                    if drive == nil or drive.valid == false or network:exists(drive.entID) == false then
                        network:remove_cache("import", "drive", inv_item.name)
                    else
                        local remainingStorage = drive:getRemainingStorageSize()
                        if drive:interactable() and Util.filter_accepts_item(drive.filters, drive.whitelistBlacklist, inv_item.name) and remainingStorage > 0
                        and master:compare_itemstacks(inv_item, exact) then
                            transferCapacity = network:insert_item_into_drive(item, inv_item, drive, transferCapacity, master, remainingStorage, exact)
                            if transferCapacity <= 0 then goto fin end
                            if inv_item.count <= 0 then goto next end
                        else
                            network:remove_cache("import", "drive", item.name)
                        end
                    end
                end
                if network:has_cache("import", "external", item.name) then
                    local external = storage.entityTable[network:get_cache("import", "external", inv_item.name)]
                    if external == nil or external.valid == false or network:exists(external.entID) == false then
                        network:remove_cache("import", "external", inv_item.name)
                    else
                        if external:interactable() and external:target_interactable() and string.match(external.io, "output") ~= nil and external.type == "item"
                        and Util.filter_accepts_item(external.filters.item, external.whitelistBlacklist, inv_item.name) and external.focusedEntity.inventory.input.max ~= 0
                        and master:compare_itemstacks(inv_item, exact) then
                            if external.onlyModified and inv_item.modified == false then goto next end
                            transferCapacity = network:insert_item_into_external(external, item, inv_item, master, transferCapacity, exact)
                            if transferCapacity <= 0 then goto fin end
                            if inv_item.count <= 0 then goto next end
                        else
                            network:remove_cache("import", "external", inv_item.name)
                        end
                    end
                end
                for p = 1, Constants.Settings.RNS_Max_Priority*2 + 1 do
                    local priorityD = network.ItemDriveTable[p]
                    local priorityE = network.ExternalIOTable[p].item
                    local b = 0
                    if inv_item.modified == true and network:is_ItemExternalPartitions_Full() then goto fin end
                    if inv_item.modified == false then
                        for _, drive in pairs(priorityD) do
                            if network:is_ItemDrivePartitions_Full() then b = b + 1 break end
                            local remainingStorage = drive:getRemainingStorageSize()
                            if drive:interactable() and Util.filter_accepts_item(drive.filters, drive.whitelistBlacklist, item.name) and remainingStorage > 0
                            and master:compare_itemstacks(inv_item, exact) then
                                transferCapacity = network:insert_item_into_drive(item, inv_item, drive, transferCapacity, master, remainingStorage, exact)
                                if transferCapacity <= 0 then
                                    network:put_cache("import", "drive", master.name, drive.thisEntity.unit_number)
                                    goto fin
                                end
                                if inv_item.count <= 0 then goto next end
                            end
                        end
                    end

                    for _, external in pairs(priorityE) do
                        if network:is_ItemExternalPartitions_Full() then b = b + 1 break end
                        if external:interactable() and external:target_interactable() and string.match(external.io, "output") ~= nil and external.type == "item"
                        and Util.filter_accepts_item(external.filters.item, external.whitelistBlacklist, inv_item.name) and external.focusedEntity.inventory.input.max ~= 0
                        and master:compare_itemstacks(inv_item, exact) then
                            if external.onlyModified and inv_item.modified == false then goto next end
                            transferCapacity = network:insert_item_into_external(external, item, inv_item, master, transferCapacity, exact)
                            if transferCapacity <= 0 then
                                network:put_cache("import", "external", master.name, external.thisEntity.unit_number)
                                goto fin
                            end
                            if inv_item.count <= 0 then goto next end
                        end
                    end

                    if b == 2 then return transferCapacity end
                end
            end
            ::next::
        end
        ::fin::
        Util.next_index(from_inv.inventory.output)
        if transferCapacity <= 0 then break end
    end
    return transferCapacity
end

function BaseNet.transfer_from_cursor_to_network(network, item, transferCapacity)
    local inv_item = Itemstack:new(item)
    if inv_item == nil then return transferCapacity end
    local master = inv_item:copy()
    for i = 1, 1 do
        if network:has_cache("import", "drive", inv_item.name) and inv_item.modified == false then
            local drive = storage.entityTable[network:get_cache("import", "drive", inv_item.name)]
            if drive == nil or drive.valid == false or network:exists(drive.entID) == false then
                network:remove_cache("import", "drive", inv_item.name)
            else
                local remainingStorage = drive:getRemainingStorageSize()
                if drive:interactable() and Util.filter_accepts_item(drive.filters, drive.whitelistBlacklist, inv_item.name) and remainingStorage > 0
                and master:compare_itemstacks(inv_item) then
                    transferCapacity = network:insert_item_into_drive(item, inv_item, drive, transferCapacity, master, remainingStorage)
                    if transferCapacity <= 0 then return 0 end
                    if inv_item.count <= 0 then goto fin end
                else
                    network:remove_cache("import", "drive", item.name)
                end
            end
        end
        if network:has_cache("import", "external", item.name) then
            local external = storage.entityTable[network:get_cache("import", "external", inv_item.name)]
            if external == nil or external.valid == false or network:exists(external.entID) == false then
                network:remove_cache("import", "external", inv_item.name)
            else
                if external:interactable() and external:target_interactable() and string.match(external.io, "output") ~= nil and external.type == "item"
                and Util.filter_accepts_item(external.filters.item, external.whitelistBlacklist, inv_item.name) and external.focusedEntity.inventory.input.max ~= 0
                and master:compare_itemstacks(inv_item) then
                    if external.onlyModified and inv_item.modified == false then goto pass end
                    transferCapacity = network:insert_item_into_external(external, item, inv_item, master, transferCapacity)
                    if transferCapacity <= 0 then return 0 end
                    if inv_item.count <= 0 then goto fin end
                else
                    network:remove_cache("import", "external", inv_item.name)
                end
            end
        end
        ::pass::
        for p = 1, Constants.Settings.RNS_Max_Priority*2 + 1 do
            local priorityD = network.ItemDriveTable[p]
            local priorityE = network.ExternalIOTable[p].item
            local b = 0
            if inv_item.modified == true and network:is_ItemExternalPartitions_Full() then goto fin end
            if inv_item.modified == false then
                for _, drive in pairs(priorityD) do
                    if network:is_ItemDrivePartitions_Full() then b = b + 1 break end
                    local remainingStorage = drive:getRemainingStorageSize()
                    if drive:interactable() and Util.filter_accepts_item(drive.filters, drive.whitelistBlacklist, item.name) and remainingStorage > 0
                    and master:compare_itemstacks(inv_item) then
                        transferCapacity = network:insert_item_into_drive(item, inv_item, drive, transferCapacity, master, remainingStorage)
                        if transferCapacity <= 0 then
                            network:put_cache("import", "drive", master.name, drive.thisEntity.unit_number)
                            return 0
                        end
                        if inv_item.count <= 0 then goto fin end
                    end
                end
            end

            for _, external in pairs(priorityE) do
                if network:is_ItemExternalPartitions_Full() then b = b + 1 break end
                if external:interactable() and external:target_interactable() and string.match(external.io, "output") ~= nil and external.type == "item"
                and Util.filter_accepts_item(external.filters.item, external.whitelistBlacklist, inv_item.name) and external.focusedEntity.inventory.input.max ~= 0
                and master:compare_itemstacks(inv_item) then
                    if external.onlyModified and inv_item.modified == false then goto next end
                    transferCapacity = network:insert_item_into_external(external, item, inv_item, master, transferCapacity)
                    if transferCapacity <= 0 then
                        network:put_cache("import", "external", master.name, external.thisEntity.unit_number)
                        return 0
                    end
                    if inv_item.count <= 0 then goto fin end
                end
                ::next::
            end
            if b == 2 then return transferCapacity end
        end
        ::fin::
    end
    return transferCapacity
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function BaseNet.getOperableObjects(array, group)
    local objs = {}
    for p, priority in pairs(array) do
        if group == "io" then
            objs[p] = {
                input = {},
                output = {}
            }
            for mode, io in pairs(priority) do
                for _, o in pairs(io) do
                    o = storage.entityTable[o]
                    if o.thisEntity.valid and o.thisEntity.to_be_deconstructed() == false then
                        objs[p][mode][o.entID] = o
                    end
                end
            end
        elseif group == "eo" then
            objs[p] = {
                item = {},
                fluid = {}
            }
            for mode, io in pairs(priority) do
                for _, o in pairs(io) do
                    if o.thisEntity.valid and o.thisEntity.to_be_deconstructed() == false then
                        objs[p][mode][o.entID] = o
                    end
                end
            end
        elseif group == "dt" then
            objs[p] = {}
            for mode, io in pairs(priority) do
                for _, o in pairs(io) do
                    if o.thisEntity.valid and o.thisEntity.to_be_deconstructed() == false then
                        objs[p][o.entID] = o
                    end
                end
            end
        else
            objs[p] = {}
            for _, o in pairs(priority) do
                if o.thisEntity.valid and o.thisEntity.to_be_deconstructed() == false then
                    objs[p][o.entID] = o
                end
            end
        end
    end
    return objs
end

function BaseNet:filter_externalIO_by_valid_signal()
    local objs = {}
    for p, priority in pairs(self.ExternalIOTable) do
        objs[p] = {}
        for m, mode in pairs(priority) do
            objs[p][m] = {}
            for _, o in pairs(mode) do
                if o:signal_valid() == true then
                    o:check_focused_entity()
                    objs[p][m][o.entID] = o
                end
            end
        end
    end
    return objs
end

--Used for the External Bus
function BaseNet.filter_by_mode(mode, array)
    local objs = {}
    for p, priority in pairs(array) do
        objs[p] = {}
        for _, m in pairs(priority) do
            for _, o in pairs(m) do
                if string.match(o.io, mode) ~= nil then
                    objs[p][o.entID] = o
                end
            end
        end
    end
    return objs
end

--Used for the External Bus
function BaseNet.filter_by_type(type, array)
    local objs = {}
    for p, priority in pairs(array) do
        objs[p] = {}
        for _, o in pairs(priority[type]) do
            objs[p][o.entID] = o
        end
    end
    return objs
end

--Used for the Drives
function BaseNet.filter_by_name(name, array)
    local objs = {}
    for p, priority in pairs(array) do
        objs[p] = {}
        for _, o in pairs(priority) do
            if name == o.thisEntity.name then
                objs[p][o.entID] = o
            end
        end
    end
    return objs
end

function BaseNet:get_item_storage_size()
    local m = 0
    local t = 0
    for _, priority in pairs(self.getOperableObjects(self.ItemDriveTable)) do
        for _, drive in pairs(priority) do
            m = m + drive.maxStorage
            t = t + drive:getStorageSize()
        end
    end
    return t, m
end

function BaseNet.get_table_length_in_priority(array, hasIOGroup, getNil)
    local count = 0
    for _, p in pairs(array) do
        if hasIOGroup then
            for _, io in pairs(p) do
                count = count + (getNil and {Util.getTableLength_non_nil(io)} or {Util.getTableLength(io)})[1]
            end
        else
            count = count + (getNil and {Util.getTableLength_non_nil(p)} or {Util.getTableLength(p)})[1]
        end
    end
    return count
end

function BaseNet.get_powerusage(array, hasIOGroup)
    local power = 0
    for _, p in pairs(array) do
        if hasIOGroup then
            for _, io in pairs(p) do
                for _, o in pairs(io) do
                    power = power + o.powerUsage
                end
            end
        else
            for _, o in pairs(p) do
                power = power + o.powerUsage
            end
        end
        
    end
    return power
end

--Get total powerusage of connected objects
function BaseNet:getTotalObjects()
    --[[return  BaseNet.get_powerusage(BaseNet.getOperableObjects(self.ItemDriveTable)) + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.FluidDriveTable))
            + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.ItemIOTable, "io"), true)*storage.IIOMultiplier + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.FluidIOTable, "io"), true)*storage.FIOMultiplier
            + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.ExternalIOTable, "eo"), true) + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.NetworkInventoryInterfaceTable))
            + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.WirelessTransmitterTable))*storage.WTRangeMultiplier + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.DetectorTable))
            + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.TransmitterTable)) + BaseNet.get_powerusage(BaseNet.getOperableObjects(self.ReceiverTable))]]
    return self.powerDraw
end

