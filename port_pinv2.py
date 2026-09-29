import pathlib
p = pathlib.Path("scripts/objects/NetworkInventoryInterface.lua")
s = p.read_text()
N = chr(10)
T = chr(9)
DQ = chr(34)
log = []
key = DQ + "RNS_NII_Insert" + DQ
i = s.find(key)
log.append(("insert button found", i != -1))
already = s.count("PlayerInventoryTable")
log.append(("PlayerInventoryTable refs now", already))
if i != -1 and already < 2:
    eol = s.find(N, i)
    block = (N + T*2 + "local playerInvScrollPane = GuiApi.add_scroll_pane(guiTable, " + DQ + "PlayerInventoryScrollPane" + DQ + ", informationFrame, 500, true)" + N
           + T*2 + "playerInvScrollPane.style = Constants.Settings.RNS_Gui.scroll_pane" + N
           + T*2 + "playerInvScrollPane.style.minimal_width = 308" + N
           + T*2 + "playerInvScrollPane.style.vertically_stretchable = true" + N
           + T*2 + "GuiApi.add_table(guiTable, " + DQ + "PlayerInventoryTable" + DQ + ", playerInvScrollPane, 8, true)" + N)
    s = s[:eol] + block + s[eol:]
    p.write_text(s)
    log.append(("inserted", "yes"))
else:
    log.append(("inserted", "no"))
for k, v in log:
    print("  ", k, "=", v)
