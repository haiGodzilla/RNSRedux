# RNSRedux: Performance-Architektur für Großfabriken

Ziel dieses Dokuments: die Mod auch mit hunderten Drives und tausenden IO-Bussen
spielbar halten, ohne dass die UPS einbrechen — auch mit Mods, die Stackgrößen
und Inventare verändern.

## 1. Ausgangslage

Zwei Zahlen bestimmen die Architektur:

Ein 1.000-SPM-Werk bewegt Rohmaterial in der Größenordnung **5.000 Items pro
Sekunde** hinein und mehrere Tausend pro Sekunde intern, speichert aber
gleichzeitig nur **10^5 bis 10^6 Items** — also nur wenige Minuten Durchsatz als
Puffer [1]. Kapazität ist damit nie der Engpass. **Durchsatz und Kosten pro Tick
sind es.** [1]

Der Vergleichsmaßstab aus dem eigenen Projekt: Drives mit 4k bis 256k Items,
Item-Bus 15 Items/s im Grundausbau (exakt ein gelbes Band), Fluid-Bus 1.200/s.
Der Originalautor kam so auf 3 Science/s bei etwa 45 UPS und nennt
WideChests-Interaktion und External Storage Bus als UPS-Fresser [1].

Dazu die Kompatibilitätslage: Stack-Size-Mods ändern die Annahmen. Im heutigen
Code sind alle `stack_size`-Zugriffe zur Laufzeit gelesen, das ist robust. Was
nicht robust ist: eine fest verdrahtete Umrechnung „ein Slot je 100 Items".

## 2. Die Kostenquellen im heutigen Code

**a) GUI-Aktualisierung jeden Tick.** `scripts/gui/Gui.lua:5` prüfte
`game.tick % 1` — immer null, also immer wahr. Der beabsichtigte Throttle
(`RNS_Gui_Tick`, Kommentar direkt daneben) war auskommentiert. Bei geöffnetem
Network Inventory Interface werden so jeden Tick alle Item-Buttons verglichen,
zerstört und neu gebaut. Bei 40 Inventarslots und hundert Item-Typen im Netz
sind das hunderte Button-Operationen pro Tick, pro Spieler. **Behoben in P0.**

**b) Voller Netzaufbau im Takt.** `NetworkController:update` ruft
`network:doRefresh(self)`, sobald `shouldRefresh` gesetzt ist oder alle 600
Ticks. `doRefresh` löscht sämtliche Tabellen und läuft über `addConnectables`
rekursiv durch den gesamten verbundenen Graphen. Für jedes Drive werden dabei
alle Item-Typen einzeln gebucht (`increase_tracked_item_count`,
`add_item_to_interface_cache`). Mit 100 Drives und je einigen hundert Typen sind
das zehntausende Lua-Operationen in einem einzigen Tick. Der Aufwand skaliert
mit der Fabrikgröße, nicht mit dem Spielgeschehen.

**c) Buchhaltung pro Stack statt pro Charge.** `BaseNet:add_item_to_interface_cache`
(`NetworkBase.lua:544`) hängt jeden Stack an eine Liste und durchläuft sie
linear mit `compare_itemstacks`. Das ist O(n) pro Einlagerung und wird bei
vielen Varianten desselben Items quadratisch.

**d) External IO pollt echte Container.** `updateExternalStorage` läuft alle 5
Ticks über alle External IOs und liest je ein reales Inventar. Das ist genau das
Muster, das die Performance-Lehre verbietet: keine Vanilla-Inventare pro Tick
anfassen [1]. WideChests verschärft es, weil das Inventar dort groß ist [1].

**e) Gesamtmengen werden berechnet, nicht geführt.** Anzeigen und Prüfungen
greifen auf `StoredPartition`-Zähler zu, die aber bei jedem `doRefresh` neu
aufgebaut werden. Der Zähler existiert, wird aber nicht inkrementell gepflegt.

**f) Allokationen.** `Itemstack:new` erzeugt pro Item eine Tabelle, `Util.copy`
kopiert tief, `get_contents()` allokiert. Bei jedem Transfer und bei jedem
Refresh. Gemessen ist der Garbage Collector im Dauerzustand bei 0,013 ms, also
rund 3 % der Mod-Zeit — kein bestätigter Dauerposten, aber sichtbar bei
Spitzenlast (21,5 ms Maximum während eines Bauvorgangs).

**g) Beitrittskaskade beim Bau.** Beim Erzeugen einer Entity läuft
`Event.placed` → `BaseNet.postArms` → `find_entities_filtered` auf allen
Nachbarn → deren `createArms` → `join_network`. Jede Entity-Erzeugung stößt
also eine Umgebungssuche und die Neuvernetzung der Nachbarn an. Gemessen:
rund 60 µs pro Entity bei rund 15.000 Entities in einem Tick, insgesamt
**892 ms** für einen einzelnen Tick. Das trifft nicht den Dauerbetrieb, sondern
zwei reale Szenarien: Blueprint einfügen und Baulogistik-Roboter, die ein Netz
hochziehen. Ein Blueprint mit hundert Drives würde über fünf Sekunden
einfrieren. Bisher nicht im Plan, gehört als eigener Posten dazu.

**h) Renderkosten der Sprite-Kette.** Gemessen: `Script render preparation`
6,8 ms im Mittel, also rund 41 % des Frame Cycle. Das ist keine
Simulationszeit — die `draw_sprite`-Objekte für Kabel, Arme und Drive-Icons
werden clientseitig aufbereitet. Bei rund 10.000 Kabeln mit je zwei bis drei
Objekten sind das zehntausende Renderobjekte. Für UPS unerheblich, für die
Bildrate nicht. Ebenfalls neu im Plan.

## 3. Zielarchitektur

### 3.1 Das Netzwerk ist die Rechnungseinheit, nicht das Drive

Pro Netzwerk genau eine Zählertabelle:

```lua
network.totals["iron-plate|normal"] = 12345
network.totalItems = 12345
network.capacity   = 64000
```

Jedes Drive führt dieselbe Struktur über seinen eigenen Bestand. Beim Beitritt
werden die Drive-Zahlen addiert, beim Austritt subtrahiert. Damit sind
Gesamtmenge, Füllstand und Kapazität O(1) statt O(Drives × Item-Typen).

Das ersetzt Punkt (e) und macht Punkt (b) weitgehend überflüssig.

### 3.2 Mitgliedschaft ist ein Ereignis, kein Scan

Ein Drive tritt bei, wenn er gebaut oder verbunden wird; es tritt aus bei Abbau,
Zerstörung oder Trennung. Alle diese Ereignisse existieren bereits als
Event-Handler im Code. Der periodische Vollaufbau entfällt aus dem Hot Path.

Als Sicherheitsnetz bleibt eine **Prüfliste** erhalten: nicht mehr ein
Komplettaufbau alle 600 Ticks, sondern eine Warteschlange, die pro Tick eine
feste Anzahl von Entities nachprüft und im Kreis läuft. Damit ist der
Tick-Preis konstant, egal wie groß die Fabrik ist.

### 3.3 Immer Chargen, nie Einzelitems

Übertragen wird immer eine Stack-Tabelle in einem Aufruf, nicht Item für Item.
Ein Maschineninventar wird in einem `insert`/`remove` mit mehreren Stacks
bedient. Die Item-Buchhaltung wird einmal pro Charge gebucht, nicht einmal pro
Stack.

Unverifiziert: ob `LuaInventory::insert` ein Array von Stack-Definitionen
annimmt, oder nur eine. Wird in P2 mit dem Store-Test geklärt.

### 3.4 Arbeit über Ticks verteilen

Jede Entity bekommt beim Bau einen festen Zeitschlitz. Bei `N` Slots
verarbeitet ein Tick nur `1/N` aller Entities. Bei tausend Bussen und acht
Slots sind das 125 statt 1000 pro Tick — bei gleichem Durchsatz, weil pro Lauf
entsprechend mehr Items bewegt werden.

Der bestehende Ansatz (jede Bus-Art hat einen eigenen Tick-Modulo, alle
gleichzeitig) erzeugt Lastspitzen. Zeitschlitze glätten sie.

### 3.5 Dirty Flags statt Scans

Ein Wert wird neu berechnet, wenn er sich geändert hat — nicht, weil ein Timer
abgelaufen ist. Anzeigen lesen zwischengespeicherte Aggregate und werden nur bei
Änderung neu gebaut.

### 3.6 External IO vom Polling lösen

Drei Maßnahmen, in dieser Reihenfolge:

1. **Gezielter Zugriff statt Inventarlesen.** `get_item_count(name)` für die
   gefilterten Items statt `get_contents()` über das ganze Inventar.
2. **Deutlich niedrigere Kadenz.** 5 Ticks sind zu schnell für echte Container;
   der Durchsatz des Busses bleibt über größere Chargen erhalten.
3. **Nur bei Bedarf.** Der Bus fasst den Container nur an, wenn die Netzseite
   etwas will oder abgibt — nicht, wenn beide Seiten unverändert sind.

## 4. Dynamisches Wachstum

Kapazität bleibt eine **Item-Zahl** (4k, 16k, 64k, 256k). Slots sind nur
physischer Puffer. Das ist die entscheidende Trennung: Mit Stackgröße 1 wären
256k Items sonst 256.000 Slots, und die Umrechnung „Slot je 100 Items" bricht
unter einer Stack-Size-Mod sofort.

Der Speicher eines Drives besteht aus **Chunks**:

- Ein Chunk ist ein Script-Inventar, angelegt über `game.create_inventory`.
- Der erste Chunk ist klein (Vorgabe 1.024 Slots) und wird bei Bedarf
  verdoppelt, bis höchstens 65.535 Slots (Obergrenze von `resize`).
- Ist ein Chunk voll und die Item-Kapazität noch nicht erreicht, kommt ein
  weiterer Chunk dazu. Die Gesamtzahl der Slots überschreitet nie die
  Item-Kapazität, weil mehr ohnehin nicht hineinpasst.
- Eine Lua-Zuordnung `item|quality -> chunk_index` hält fest, wo ein Item liegt.
  Einfügen geht in den Chunk, der das Item schon hat, sonst in den ersten mit
  freiem Slot, sonst in einen neuen. Ein Ausbau des Index ist damit O(1).

Damit gilt: Ein Drive mit Platten braucht einen Chunk, ein Drive mit Werkzeugen
wächst bis zur Kapazitätsgrenze, und nichts ist fest verdrahtet.

Beim Abbau eines Drives werden alle Chunks über `LuaInventory::destroy()`
freigegeben — sonst leckt das Savegame.

## 5. Item-Identität

In 2.0 ist der Schlüssel `name` plus `quality`. Beide gehören in die
Zählertabelle und in den Chunk-Index. Damit ist der Qualitätsverlust, der die
alte Handserialisierung auszeichnet, strukturell ausgeschlossen: Zwei
Qualitätsstufen sind zwei Einträge.

Stacks mit weiteren Zusatzdaten (Tags, Munition, Haltbarkeit, Blueprints)
landen im Chunk und werden von der Engine verwaltet; die Zählertabelle führt sie
über `name|quality` mit. Für die Anzeige zählt die Menge, für die Rückgabe die
Engine.

## 6. Meilensteine

**P0 — GUI-Throttle.** Eine Zeile, bereits umgesetzt. Größter Einzelposten, kein
Risiko.

**P1 — Netzwerk-Accounting.** Zählertabelle pro Netzwerk, inkrementeller
Beitritt/Austritt, `doRefresh` aus dem Hot Path, Prüfliste statt Vollaufbau.
Betrifft `NetworkBase.lua` und `NetworkController.lua`. Danach muss `/rns-debug`
dieselben Mitgliedszahlen zeigen wie vorher.

**P2 — ItemStore mit Chunks.** Ausbau des begonnenen Moduls um dynamische
Chunks, Item- und Quality-Schlüssel, O(1)-Abfragen. Drives darauf umstellen.
Testbefehl erweitert um Vielfach-Chunks und Save/Load.

**P3 — Chargentransfer.** Alle Transferpfade auf Stack-Tabellen umstellen,
Buchhaltung pro Charge. Betrifft die zehn Aufrufstellen in `NetworkBase` und
`NetworkInventoryInterface`.

**P4 — Scheduler.** Zeitschlitze für Drives und Busse.

**P5 — External IO.** Gezielter Zugriff, niedrigere Kadenz, Bedarfssteuerung.

**P6 — Aufräumen.** `Itemstack.lua` entfernen, tote Kommentarblöcke, Debug-
Befehle, `port_*.py`, `data-final-fixes`-Ersatzlogik prüfen.

## 7. Gestrichen

Die ursprünglich angedachten „zwei Speicherpfade" (Lua-Tabelle für zustandslose
Items, Script-Inventar für den Rest) entfallen. Die Analyse zeigt, dass große
Inventare kein nennenswerter Faktor sind [1] — die Begründung für die
Verdopplung war damit weg.

Ebenso gestrichen: die Slot-Umrechnung „1 Slot je 100 Items".

## 8. Unverifiziert und offen

- Ob `LuaInventory::insert` ein Stack-Array annimmt (P2).
- Ob Script-Inventar-Referenzen in `storage` den Ladezyklus überstehen (P2, Test).
- Ob `count_empty_stacks` auf einem 65.535-Slot-Inventar teuer ist (P2, Messung).
- Wie weit die Bus-Durchsätze für den Zielmaßstab reichen. 15 Items/s im
  Grundausbau sind ein gelbes Band; für mehrere Tausend Items pro Sekunde
  braucht es viele Busse oder höhere Ausbaustufen. Das ist eine
  Balance-Entscheidung, keine technische.

## 9. Messverfahren

Kein Fortschritt ohne Messung. Vorgehen:

1. Stress-Savegame: 50 Drives, 200 Busse, Dauerbetrieb.
2. Vor und nach jedem Meilenstein `debugadapter` oder das eingebaute Profiler-
   Overlay, dazu das Log der Tick-Zeiten.
3. `/rns-debug` erweitert um Mitgliedszahlen und Zählerstände als
   Konsistenzprüfung.

## 10. Quellen

[1] Interne Projektnotiz „Analyse Fabrikdurchsatz" (September 2026): Durchsatz-
und Speichergrößen für 1.000 SPM, Vergleichsmaßstab der Mod-eigenen Drives und
Busse, Aussagen des Originalautors zu UPS-Fressern, sowie die
Performance-Lehre (keine Vanilla-Inventare pro Tick, dirty flags, Arbeit über
Ticks verteilen).
