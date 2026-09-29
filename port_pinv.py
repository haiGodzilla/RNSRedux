import pathlib
p = pathlib.Path("scripts/objects/NetworkInventoryInterface.lua")
s = p.read_text()
N = chr(10)
T = chr(9)
DQ = chr(34)
log = []
a = "--[[function NII:createPlayerInventory"
b = "function NII:createPlayerInventory"
log.append(("unlock head", s.count(a)))
s = s.replace(a, b, 1)
a = "end]]" + N + N + "function NII:createNetworkInventory"
b = "end" + N + N + "function NII:createNetworkInventory"
log.append(("unlock tail", s.count(a)))
s = s.replace(a, b, 1)
a = T*2 + "if item.count <= 0 then goto continue end"
b = T*2 + "if item == nil or item.valid_for_read == false or item.count <= 0 then goto continue end"
log.append(("nil safe item", s.count(a)))
s = s.replace(a, b, 1)
a = T*2 + "Util.item_add_list_into_table(inv, Itemstack:new(item))"
b = T*2 + "local converted = Itemstack:new(item)" + N + T*2 + "if converted ~= nil then Util.item_add_list_into_table(inv, converted) end"
log.append(("nil safe Itemstack", s.count(a)))
s = s.replace(a, b, 1)
a = "vars.NII = {" + N + T*3 + "cache = {"
b = "vars.NII = {" + N + T*3 + "player = {}," + N + T*3 + "cache = {"
log.append(("vars player", s.count(a)))
s = s.replace(a, b, 1)
a = T + "--self:createPlayerInventory(guiTable, RNSPlayer, guiTable.vars.PlayerInventoryTable, textField.text)"
b = T + "self:createPlayerInventory(guiTable, RNSPlayer, guiTable.vars.PlayerInventoryTable, textField.text)"
log.append(("enable update call", s.count(a)))
s = s.replace(a, b, 1)
a = "NII.transfer_from_pinv(RNSPlayer, obj, event.element.tags, count)" + N + T + "return"
b = a + N + T + "elseif string.match(event.element.name, " + DQ + "RNS_NII_PInv" + DQ + ") then" + N + T*2 + "NII.transfer_player_to_network(RNSPlayer, obj, event.element.tags, count)" + N + T*2 + "return"
log.append(("interaction branch", s.count(a)))
s = s.replace(a, b, 1)
anchor = "RNS_NII_Insert, player_inventory_flow"
idx = s.find(anchor)
if idx == -1:
    log.append(("anchor insert button", 0))
else:
    eol = s.find(N, idx)
    block = (N + T*2 + "local playerInvScrollPane = GuiApi.add_scroll_pane(guiTable, " + DQ + "PlayerInventoryScrollPane" + DQ + ", informationFrame, 500, true)" + N
           + T*2 + "playerInvScrollPane.style = Constants.Settings.RNS_Gui.scroll_pane" + N
           + T*2 + "playerInvScrollPane.style.minimal_width = 308" + N
           + T*2 + "playerInvScrollPane.style.vertically_stretchable = true" + N
           + T*2 + "GuiApi.add_table(guiTable, " + DQ + "PlayerInventoryTable" + DQ + ", playerInvScrollPane, 8, true)" + N)
    s = s[:eol] + block + s[eol:]
    log.append(("anchor insert button", 1))
n1 = s.count("game.item_prototypes[")
n2 = s.count("game.fluid_prototypes[")
log.append(("legacy item_prototypes", n1))
log.append(("legacy fluid_prototypes", n2))
s = s.replace("game.item_prototypes[", "prototypes.item[")
s = s.replace("game.fluid_prototypes[", "prototypes.fluid[")
p.write_text(s)
for k, v in log:
    print("  ", k, "=", v)
