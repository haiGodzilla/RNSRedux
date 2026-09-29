if storage.allowMigration == false then return end
storage.TransReceiverChannels = storage.TransReceiverChannels or {transmitters = {}, receivers = {}}
storage.NetworkControllers = storage.NetworkControllers or {}

for id, obj in pairs(storage.entityTable) do
    if obj.type and obj.receiver then
        obj.receiver = nil
        if obj.type == "transmitter" then
            storage.TransReceiverChannels.transmitters[id] = obj
        elseif obj.type == "receiver" then
            storage.TransReceiverChannels.receivers[id] = obj
        end
    end
    if obj.network then
        storage.NetworkControllers[id] = obj
    end
end