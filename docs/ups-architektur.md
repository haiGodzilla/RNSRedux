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

Herabstufung dieser Zahl: Die ~5.000 Items/s stammen aus einem Rechenmodell auf
Spieldaten, nicht aus einer Messung. Es gibt dazu keine UPS- oder CPU-Messwerte
[1]. Die Größenordnung trägt die Aussage „Kapazität ist nicht der Engpass", sie
ist aber keine belastbare Grundlage für Durchsatzziele. Wer den Zielbereich
festlegen will (1.000–5.000 Items/s pro Netzwerk), braucht dafür eigene Zahlen.

Der Vergleichsmaßstab aus dem eigenen Projekt: Drives mit 4k bis 256k Items,
Item-Bus 15 Items/s im Grundausbau (exakt ein gelbes Band), Fluid-Bus 1.200/s.
Der Originalautor kam so auf 3 Science/s (rund 180 SPM) bei etwa 45 UPS und
nennt WideChests-Interaktion und External Storage Bus als UPS-Fresser [1].

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

Nebeneffekt: Mengenanzeigen können jetzt bis etwa 0,9 s nachlaufen.
`RNS_Gui_Tick` ist die Stellschraube dafür.

Offene Frage zu P0: Changelog 1.0.18 des Originalautors stellt Netzwerk-Grid und
Wireless-Grid ausdrücklich auf „updates every tick instead of 55 ticks" um. Der
auskommentierte Throttle im Code war also der Zustand *davor*, und die Änderung
kann einen Grund gehabt haben, der hier nicht sichtbar ist. Beobachten, ob die
Mengenanzeigen im Grid beim laufenden Betrieb korrekt nachziehen.

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

**i) Alle Controller refreshten im selben Tick.** `NetworkController.lua:103`
prüfte `game.tick % self.updateTick == 0`, damals mit `updateTick = 600`. Der
Tick ist global, nicht entity-bezogen, also machte **jeder** Controller sein
`doRefresh` im selben Tick. Bei 20 Stationen waren das 20 vollständige
Netzaufbauten gleichzeitig, alle 10 Sekunden. Gemessen: 134,731 ms in einem
einzelnen Tick bei 20 Stationen und 1.000 Drives (Tab-Out-Frames ausgenommen).

**Behoben in zwei Schritten.** Zuerst leitete jeder Controller aus seiner
`unit_number` eine feste Phase ab, der Vollaufbau traf damit pro Tick höchstens
einen Controller — das diagnostizierte nur: aus einem 134-ms-Freeze alle 10 s
wurde ein Ruckler alle ~0,5 s. Mit `a5add2b` ist der periodische Aufbau ganz
entfallen. `NC.updateTick` steht auf 7200 statt 600, der Aufbau läuft nur noch
bei einer Strukturänderung sowie als Netz alle zwei Minuten pro Controller. Im
Dauerzustand fällt kein Aufbau mehr an.

Nicht behoben, gleiche Ursache eine Ebene tiefer:
`NetworkController.lua:124–133` prüft fünf globale Tick-Modulo (Detector 3,
ItemIO 4, FluidIO 5, ExternalStorage 5). Bei Tick 20 laufen ItemIO und
ExternalStorage zusammen, bei Tick 60 alle vier. Der Spike ist damit
dauerhaft rund vier- bis fünfmal so hoch wie nötig.

**j) Der IO-Bus pollt echte Container im Takt.** Vermutete Hauptquelle, siehe
Abschnitt 6a. `EIO:update` (`ExternalIO.lua:273–300`) holt pro Durchlauf
`get_inventory(i)`, ruft `sort_and_merge()` darauf und legt für **jeden Slot**
ein `Itemstack:new(...)` an (Zeile 278). Bei `RNS_ExternalStorage_Tick = 5`
sind das zwölf vollständige Container-Scans pro Sekunde und Bus, mit einer
Allokation pro Slot. Zusätzlich fragt `NetworkBase.lua:1066–1069` pro
Insert-Versuch zweimal `get_item_count` und einmal `count_empty_stacks(true,
false)` auf einem echten Inventar ab, und `insert_item_into_external` ruft am
Ende jeder Charge noch `external:update(self)` (Zeile 1101) — ein weiterer
voller Scan innerhalb des Transfers.

Belegt durch den Changelog des Originalautors, der über vier Monate wiederholt
an Kadenz und Vollständigkeitsprüfungen nachgebessert hat, ohne die Struktur
anzufassen: 1.0.3 „improving ups by ~50%", 1.0.18 Grid „every tick instead of
55 ticks", 1.0.25 „network fullness check … doesn't cause a sudden lag spike",
1.0.30 „stop triggering anymore IO buses from working uselesslly", 1.0.39
External Bus von 2 auf 5 Ticks, 1.0.40 „less laggy".

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

**Status: existiert bereits im Code.** `BaseNet:increase_tracked_item_count` und
`decrease_tracked_item_count` (`NetworkBase.lua:408–419`) führen
`self.Contents.item[name]` inkrementell, O(1) pro Buchung. `StoredPartition`
(`NetworkBase.lua:115–132`) führt Belegung und Kapazität getrennt nach Drive und
External, und wird ebenfalls inkrementell bedient: beim Beitritt
(`NetworkBase.lua:205`), beim Einlagern (`1056`), beim Entnehmen (`889`).

Der Plan hat diesen Punkt als „Zähler bauen" geführt. Tatsächlich ist nur das
Gegenteil offen: `doRefresh` → `resetTables` (`NetworkBase.lua:77–133`) wirft
`Contents`, `interfaceCache`, `StoredPartition`, `connectedEntities` und
`powerDraw` weg und baut alles neu auf. Der inkrementelle Pfad existiert, wird
aber alle 600 Ticks überschrieben. **P1 ist damit kleiner und risikoärmer als
geplant: kein Umbau der Buchhaltung, nur ihr Auslöser.**

Noch offen an dieser Stelle: `quality` ist kein Bestandteil des Schlüssels.
`Contents.item` ist nach Item-Namen indiziert, Qualitätsstufen kollabieren also —
genau der Fehler, den M1 behebt. Das gehört zu P2, nicht zu P1.

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

**P1 — Netzwerk-Accounting. Umgesetzt in `a5add2b`, abgenommen am 30.09.2026.**
Die Zählertabelle existiert (3.1), offen war nur ihr Auslöser: der periodische
Vollaufbau. Der ist gestrichen — jeder Beitritt und Austritt setzt
`shouldRefresh` selbst, geprüft an allen `:remove()`- und `new()`-Funktionen
sowie an den Ereignis-Registrierungen in `control.lua`. `NC.updateTick` ist von
600 auf 7200 gestiegen und damit vom Taktgeber zum Sicherheitsnetz geworden.

Nicht gebaut: die Austrittssubtraktion nach 3.2. Sie würde nur Aufbauten
sparen, die mit einer Baumaßnahme zusammenfallen, und kostet dafür eine zweite,
exakt spiegelbildliche Buchhaltung. Ebenfalls nicht gebaut: die rollende
Prüfliste — das Zwei-Minuten-Netz deckt denselben Fall ab, solange die
Controller-Zahl klein bleibt. Bei dreistellig vielen Controllern kippt das,
dann ist die Prüfliste der nächste Schritt.

Abnahmemaßstab: `/rns-debug` liefert vor und nach erzwungenem
`/rns-debug-refresh` identische Werte. Geprüft werden `tracked` (Summe und
Typenzahl), `cache`, `drive` und `external`. **Erfüllt** (Detail in
`docs/projektstand.md` 5.5): Einlagerung von drei Items, `/rns-debug-nc` vorher
und nachher, dazwischen der erzwungene Vollaufbau. Die Dumps sind identisch, der
inkrementelle Pfad und der Rebuild stimmen überein.

Offen und ungemessen bleibt ein Punkt: Save/Load mit einem Transfer dazwischen.
Der **Austritt** ist geprüft (`docs/projektstand.md` 5.7): ein Abbau setzt den
Flag selbst, das Mitglied verschwindet, alle Zähler sinken konsistent — und das
lässt sich gegen das Zwei-Minuten-Netz abgrenzen, weil dessen Termine für die
vorliegenden `entID`s außerhalb des Messfensters liegen. Die **Entnahme** ist
ebenfalls geprüft (`docs/projektstand.md` 5.13), mit dem Zusatz, dass die
Spielerklick-Grenze im Inventar liegt und nicht in der Mod.

Betrifft `NetworkController.lua` (geändert) und `NetworkBase.lua` (unverändert).

**P2 — ItemStore mit Chunks.** Ausbau des begonnenen Moduls um dynamische
Chunks, Item- und Quality-Schlüssel, O(1)-Abfragen. Drives darauf umstellen.
Testbefehl erweitert um Vielfach-Chunks und Save/Load.

Vorbedingung aus der P1-Abnahme: `Itemstack` speichert Stapel als Lua-Tabellen,
und ob ein Feld leer (leere Tabelle) oder gar nicht vorhanden (`nil`) ist,
entscheidet über die Gleichheit — `compare_tags` prüft das zweite Argument per
`type`, bevor es das erste durchläuft (`Itemstack.lua:207–209`). Der echte
Einlagerungspfad erzeugt `nil` (die Kopie über `Util.copy` fällt dort
zusammen), `Itemstack.create_template` erzeugt `{}`. Wer dort `exact=true`
übergibt, muss denselben Weg benutzen wie der Einlagerungspfad. Mit dem
ItemStore verschwindet die Frage, weil Stapel dann von der Engine gehalten
werden.

**P3 — Chargentransfer.** Alle Transferpfade auf Stack-Tabellen umstellen,
Buchhaltung pro Charge. Betrifft die zehn Aufrufstellen in `NetworkBase` und
`NetworkInventoryInterface`.

**P4 — Scheduler.** Zeitschlitze für Drives und Busse.

**P5 — External IO.** Gezielter Zugriff, niedrigere Kadenz, Bedarfssteuerung.
Siehe 6a zur Reihenfolge.

**P6 — Aufräumen.** `Itemstack.lua` entfernen, tote Kommentarblöcke, Debug-
Befehle (`/rns-debug`, `/rns-debug-nc`, `/rns-debug-refresh`,
`/rns-debug-extract`, `rns-store-test`), `port_*.py`,
`data-final-fixes`-Ersatzlogik prüfen.

### 6a Priorisierung nach P1

P1 ist durch. Der IO-Bus ist damit der nächste Posten: Er ist die einzige
Kostenquelle, die dauerhaft und vielfach pro Sekunde anfällt, während der
Refresh-Posten mit `a5add2b` auf Strukturänderungen zusammengeschrumpft ist.
Die Frage lautet nicht mehr „IO-Bus vor P1?", sondern „Phasen-Offset vor
Kontaktkosten?".

Entscheidungsrelevante Trennung:

- **Phase verschieben kostet keinen Durchsatz.** Jeder Bus läuft weiterhin alle
  vier Ticks, nur verteilt. Verhalten unverändert.
- **Kadenz senken kostet Durchsatz.** `RNS_ItemIO_Tick = 4` entspricht 15
  Items/s bei `IIOMultiplier = 1`. Eine Senkung auf 16 Ticks viertelt den
  Durchsatz, solange eine Charge ein Item groß ist. Das ist eine
  Balance-Änderung, keine Optimierung.

Vor jeder Änderung an diesem Pfad fehlt die Messung: Der Stresstest baute keine
IO-Busse, also war der Pfad nicht messbar. **Behoben:** Der Aufbau baut jetzt
Busse, siehe Messverfahren in Abschnitt 9. Damit ist der Blocker weg und die
Reihenfolge entscheidbar.

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
  Nachtrag: Es steht bereits im Hot Path der External-IO (`NetworkBase.lua:1068`),
  einmal pro Insert-Versuch. Der Posten ist damit nicht mehr hypothetisch.
- Wie weit die Bus-Durchsätze für den Zielmaßstab reichen. 15 Items/s im
  Grundausbau sind ein gelbes Band; für mehrere Tausend Items pro Sekunde
  braucht es viele Busse oder höhere Ausbaustufen. Das ist eine
  Balance-Entscheidung, keine technische.
- Ob der IO-Pfad oder der Refresh-Pfad in einem realistischen Save mehr kostet.
  Der Stresstest baut seit dem 30.09.2026 Busse, die Frage ist damit messbar
  geworden; die Messung selbst steht noch aus.
- Ob `Contents.item` an allen Aufrufstellen vollständig gebucht wird. Gelesen
  sind vier Stellen; den Beweis soll die Differenzprüfung in Abschnitt 9
  liefern, nicht eine Zählung im Quelltext.

## 9. Messverfahren

Kein Fortschritt ohne Messung. Vorgehen:

**Vor jeder Messung.** Der Aufbau muss aus dem Messfenster sein: nach
`/rns-stress-build` speichern, ins Hauptmenü, laden. Wer im Fenster tabbt,
verfälscht die Frame-Werte und damit `max`. Sichtprüfung statt Blindmessung:
Gerade die Zuordnung eines Spikes zu einer Codeursache gelingt über das Auge
schneller („ruckelt es alle 10 Sekunden?") als über einen Mittelwert.

**Profiler-Overlay.** `F4` → `show-time-usage`, `show-entity-time-usage`.
Spalten sind **avg/min/max über die letzten 100 Ticks**, nicht min/avg/max. Das
Minimum schließt Nullwerte aus. Intervall mit `/perf-avg-frames <n>` änderbar.

Fallstrick: `avg` und `max` decken nicht dasselbe Fenster ab. Ein `avg` von
0,249 ms bei `max` von 134,731 ms über 100 Ticks ist arithmetisch unmöglich —
gemessen wurde es trotzdem. Solche Kombinationen nicht interpretieren, sondern
das Fenster vergrößern (`/perf-avg-frames 600`) und erneut messen.

**Deterministische Messung statt Overlay.** Für einzelne Refresh-Kosten ist das
Overlay das falsche Instrument: Bei 20 Controller-Refreshes pro 600 Ticks liegt
selten mehr als einer im 100-Tick-Fenster. Stattdessen direkt messen, etwa mit
`game.create_profiler`, oder deterministisch zählen (Summe `#storageArray` über
alle Drives).

**Konsistenzprüfung.** `/rns-debug` zeigt pro Controller `members`, `tracked`
(Summe/Typenzahl), `cache`, `drive` und `external`. `/rns-debug-refresh`
erzwingt den Vollaufbau. Beide Dumps müssen identisch sein — das ist der
Abnahmemaßstab für P1.

**Stressaufbau.** `/rns-stress-build <stationen> <drivesProStation> [busseProStation]`,
dann
`/rns-stress-fill <typenProDrive> <mengeProTyp>`, `/rns-stress-status`,
`/rns-stress-clear`, `/rns-stress-purge`. Verifizierte Erwartungswerte:

| Aufbau | Drives | Kabel | Entities (Mod) | `members` |
|---|---|---|---|---|
| `10 20` | 200 | 420 | 640 | 64 |
| `20 20` | 400 | 840 | 1.280 | 64 |
| `20 50` | 1.000 | 2.040 | 3.080 | 154 |

`members` = Drives + Kabel **pro Station** + 2. Weicht eine Zeile ab, ist der
Aufbau unvollständig und die Stufe unbrauchbar.

**Busse (dritter Parameter).** Pro Bus drei Entities an einer Station: ein
Stichkabel, der Bus, seine Kiste. Sie liegen südlich der Spinne, deren Geometrie
unberührt bleibt. Erwartung: `members = Drives + spineLength + 2 × Busse + 2`;
`/rns-stress-build` gibt den Wert selbst aus.

| Aufbau | `members` |
|---|---|
| `10 20` | 64 |
| `10 20 4` | 72 |
| `20 50 10` | 174 |

Abwechselnd Item-IO (exportiert, Kiste leer) und External-IO (importiert, Kiste
mit 4.800 Items vorgefüllt). Zwei Einstellungen setzt der Aufbau selbst, weil die
Busse sonst nichts tun: `filters` auf ein Item, das der Fill auch in die Drives
legt (`ItemIOV3:IO` betritt den Exportzweig nur bei `filters.max ~= 0`,
`ItemIOV3.lua:522`), und `onlyModified = false` am External-Bus (der Import
überspringt sonst jeden unmodifizierten Stapel, `NetworkBase.lua:1187`).
`/rns-stress-status` meldet zusätzlich `buses total= withTarget= inNetwork=` — ein
Bus ohne Ziel tut nichts, ein Bus ohne Netz bekommt keine Updates.

Einschränkung des Aufbaus: `spineLength` hängt an `drivesPerStation`, die Stufen
verdoppeln also Drives und Kabel gleichzeitig, und die Busspalten müssen in die
Spinne passen. Der Befehl kürzt die Buszahl bei Bedarf selbst und meldet es.
Drives und Busse lassen sich damit nicht unabhängig skalieren; für die Frage
„was kostet der Bus" reicht das, für eine Trennung bräuchte es einen zweiten
Aufbau.

## 10. Quellen

[1] Projektnotiz „Analyse Fabrikdurchsatz" (September 2026): Durchsatz- und
Speichergrößen für 1.000 SPM, Vergleichsmaßstab der Mod-eigenen Drives und
Busse, Aussagen des Originalautors zu UPS-Fressern, sowie die Performance-Lehre
(keine Vanilla-Inventare pro Tick, dirty flags, Arbeit über Ticks verteilen).

**Die Notiz liegt nicht im Repo.** Dieser Verweis läuft ins Leere, solange sie
nicht unter `docs/analyse-fabrikdurchsatz.md` abgelegt ist. Bis dahin sind die
mit [1] belegten Aussagen in diesem Dokument nicht nachprüfbar. Die Notiz
zitiert außerdem selbst Quellen mit [1] bis [5], was mit der Nummerierung hier
kollidiert — beim Ablegen umnummerieren.

Auszüge aus der Notiz, die hier verwendet werden und aus dem Gedächtnis des
Autors dieser Zeilen stammen, nicht aus dem Repo-Inhalt: das Kostenmodell
(bezahlt wird pro Transfer und pro Entity-Interaktion pro Tick, nicht pro
gespeichertem Item), der Zielbereich 1.000–5.000 Items/s pro Netzwerk, die
Aussage „Durchsatz vor Kapazität" mit dem Rechenbeispiel, dass ein 256k-Drive
bei 15 Items/s erst nach etwa 4,75 h voll ist, und die Forderung nach einem
Zähler pro (Item, Quality) pro Netzwerk.
