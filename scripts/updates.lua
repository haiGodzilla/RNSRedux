require("scripts.Functions")
--Adds object to the update system
function UpdateSys.addEntity(obj)
    if valid(obj) == false then return end
    if storage.updateTable == nil then storage.updateTable = {} end
    
    if obj ~= nil and getmetatable(obj) ~= nil then
        if obj:valid() ~= true then
            obj:remove()
        elseif obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            storage.updateTable[obj.entID] = obj
        end
    end
end
--[[
function UpdateSys.addItem(obj)
    if valid(obj) == false then return end
    if storage.itemTable == nil then storage.itemTable = {} end
    
    if obj ~= nil and getmetatable(obj) ~= nil then
        if obj:valid() ~= true then
            obj:remove()
        elseif obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            storage.itemTable[obj.entID] = obj
        end
    end
end
]]
function UpdateSys.remove(obj)
    if obj.entID ~= nil then
        storage.updateTable[obj.entID] = nil
    end
end

--[[
function UpdateSys.removeItem(obj)
    if obj.entID ~= nil then
        storage.itemTable[obj.entID] = nil
    end
end
]]

function UpdateSys.update(event)
    for _, obj in pairs(storage.updateTable) do
        if valid(obj) == true and obj.update ~= nil then
            if Util.safeCall(obj.update, obj, event) == false then
                game.print({"gui-description.RNS_UpdateSysEntity_Failed", obj.thisEntity.name})
            end
        end
    end
    --[[
    for _, obj in pairs(storage.itemTable) do
        if valid(obj) == true and obj.update ~= nil then
            if Util.safeCall(obj.update, obj, event) == false then
                game.print({"gui-description.UpdateSysItem_Failed", obj.thisEntity.name})
            end
        end
    end
    ]]
end

function UpdateSys.add_to_entity_table(obj)
    if valid(obj) == false then return end
    if storage.entityTable == nil then storage.entityTable = {} end
    
    if obj ~= nil and getmetatable(obj) ~= nil then
        if obj:valid() ~= true then
            obj:remove()
        elseif obj.thisEntity ~= nil and obj.thisEntity.valid == true then
            storage.entityTable[obj.entID] = obj
        end
    end
end

function UpdateSys.remove_from_entity_table(obj)
    if obj.entID ~= nil then
        storage.entityTable[obj.entID] = nil
    end
end