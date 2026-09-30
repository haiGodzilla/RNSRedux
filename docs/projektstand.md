# RNSRedux: Projektstand

Einstiegspunkt für die Weiterarbeit. Technischer Plan und Begründungen:
`docs/ups-architektur.md`. Dieses Dokument beantwortet „wo stehen wir, was ist
verifiziert, was ist der nächste Schritt".

Stand: Commit `f94c3f0`, Branch `port/2.0`, Version 2.0.0.
P0 und P1 sind durch, der IO-Bus ist der laufende Posten.

## 1. Projekt

Portierung der Factorio-Mod „Refined Network Storage" (Autor NindyBun, MIT) von
1.1 auf 2.0, plus geplanter Neubau der Item-Speicherschicht.

Eigenständiges Repo `github.com/haiGodzilla/RNSRedux`, **kein GitHub-Fork**
mehr. Er war es zwischenzeitlich; die Entkopplung erfolgte, um versehentliche
Pull Requests in NindyBuns Repo auszuschließen. Der alte Fork
`haiGodzilla/RefinedNetworkStorage` ist verwaist.

Mod-Name intern `RNSRedux`, Titel „Refined Network Storage Redux", Version
2.0.0. Tag `upstream-1.0.43` ist der Nullpunkt.

## 2. Was läuft

Verifiziert, nicht vermutet:

- Data-Stage und Runtime-Stage fehlerfrei
- Netzwerkaufbau; alle drei GUI-Fenster (Item-Drive, Network Inventory
  Interface, IO-Bus)
- Item-Transfer über alle vier Shortcuts (Links, Shift+Links, Rechts,
  Strg+Links)
- Save/Load
- Player-Inventory-Spalte im NII wieder aktiv

Der 1:1-Port ist spielbar.

## 3. Entscheidungen

- Ziel ist 2.0 stable. Umfang des ersten Release: Kabel, Controller, Drives,
  IO-Busse.
- Wireless (inklusive Player-Port und `process_logistic_slots` mit den in 2.0
  entfernten Logistic-Slot-Funktionen) kommt erst mit M5.
- Kein Savegame-Migrationspfad.
- M1 wird direkt umgebaut, kein Zwischenrelease.
- Quality-Items werden am Drive-Eingang geblockt — kein stiller Verlust, keine
  stille Abwertung.
- Der Speicher wächst dynamisch (Chunks statt fester Slotzahl).
- Die Progression ist P0 → P6, siehe `docs/ups-architektur.md` Abschnitt 6.
  Eine offene Umpriorisierung zugunsten des IO-Busses steht in Abschnitt 6a.

## 4. Messungen

### 4.1 Profiler-Overlay richtig lesen

Die Spalten sind **avg/min/max über die letzten 100 Ticks**, nicht min/avg/max.
Das Minimum schließt Nullwerte aus. Intervall mit `/perf-avg-frames <n>`
änderbar.

Fallstrick, der zwei Messrunden gekostet hat: `avg` und `max` decken nicht
dasselbe Fenster ab. Eine Aufnahme zeigte `avg = 0,249 ms` bei
`max = 134,731 ms`. Über 100 Ticks ist das arithmetisch ausgeschlossen — der
Mittelwert müsste mindestens 1,35 ms betragen. Solche Kombinationen nicht
interpretieren, sondern das Fenster vergrößern und erneut messen.

Zweiter Fallstrick: Aus dem Spiel tabben erzeugt Frame-Spikes, die nichts mit
der Mod zu tun haben. Wer während des Messfensters tippt, macht `max`
unbrauchbar. Immer erst ablesen, dann tabben.

### 4.2 Verifizierte Messwerte

Aufbau `20 50` (20 Stationen, 1.000 Drives), Dauerzustand nach Save/Load:

| Größe | Wert |
|---|---|
| `mod-RNSRedux` avg | 0,63–0,81 ms |
| `mod-RNSRedux` min | 0,134 ms |
| `mod-RNSRedux` max | 27–34 ms |
| Tick-Budget | 16,667 ms |

Die Steigerung der `avg` gegenüber einer früheren Aufnahme (0,249 ms) ist kein
Rückschritt, sondern ein Artefakt der Refresh-Entzerrung: Vorher lagen 20
Refreshes in einem Tick, und fünf von sechs 100-Tick-Fenstern enthielten gar
keinen. Jetzt enthält jedes Fenster Spikes. Die Gesamtarbeit ist unverändert.

Ältere Aufnahme: GC im Dauerzustand 0,013 ms, also rund 3 % der Mod-Zeit. Damit
ist das Allokationsargument für P1 entfallen; die früheren 0,252 ms waren ein
Bauartefakt.

### 4.3 Erwartungswerte des Stressaufbaus

| Aufbau | Drives | Kabel | Entities (Mod) | `members` |
|---|---|---|---|---|
| `10 20` | 200 | 420 | 640 | 64 |
| `20 20` | 400 | 840 | 1.280 | 64 |
| `20 50` | 1.000 | 2.040 | 3.080 | 154 |

`members` = Drives + Kabel **pro Station** + 2. Weicht eine Zeile ab, ist der
Aufbau unvollständig und die Stufe unbrauchbar — dann nicht messen, sondern
melden.

Bekannte Einschränkung: `spineLength` hängt an `drivesPerStation`, die Stufen
verdoppeln also Drives und Kabel gleichzeitig. Für die Größenentscheidung reicht
die Summe, für eine Trennung der Anteile bräuchte es einen zweiten Aufbau mit
variabler Kabellänge. Der Aufbau enthält außerdem **keine Busse**, deckt also P1
ab, nicht P5.

## 5. P1 — Netzwerk-Accounting: abgenommen

### 5.1 Der Befund, der den Zuschnitt ändert

Die Zählertabelle aus der Zielarchitektur **existiert bereits im Code**:

- `BaseNet:increase_tracked_item_count` / `decrease_tracked_item_count`
  (`NetworkBase.lua:408–419`) führen `self.Contents.item[name]` inkrementell,
  O(1) pro Buchung.
- `StoredPartition` (`NetworkBase.lua:115–132`) führt Belegung und Kapazität,
  getrennt nach Drive und External, ebenfalls inkrementell: Beitritt
  (`NetworkBase.lua:205`), Einlagern (`1056`), Entnehmen (`889`).

Offen ist nur das Gegenteil: `doRefresh` → `resetTables`
(`NetworkBase.lua:77–133`) wirft `Contents`, `interfaceCache`, `StoredPartition`,
`connectedEntities` und `powerDraw` weg und baut alles neu auf. Der
inkrementelle Pfad existiert, wurde aber alle 600 Ticks überschrieben.

**P1 heißt damit: den Neuaufbau entfernen, nicht die Buchhaltung bauen.** Das ist
deutlich kleiner und risikoärmer als ursprünglich geplant.

### 5.2 Was gebaut ist

Zwei Messwerkzeuge, Commit `26308e5`:

- `/rns-debug` zeigt pro Controller `members`, `tracked` (Summe/Typenzahl),
  `cache` (Cache-Stacks), `drive` und `external` (belegt/Kapazität). Seit
  Commit `61d0a0a` zusätzlich `truth` und `fluidTruth`: was die Mitglieds-Drives
  tatsächlich in ihren Speichertabellen halten, neben dem, was sie über
  `storedAmount` behaupten.
- `/rns-debug-refresh` erzwingt den Vollaufbau sofort.

Beide zusammen sind der Abnahmemaßstab: **vor und nach erzwungenem Refresh
müssen die Werte identisch sein.** Voraussetzung ist ein statisches Netz — der
Stressaufbau ohne IO-Busse und ohne laufende Maschinen erfüllt das. Wenn
zwischendurch Items transferiert werden, ändern sich die Werte legitim und der
Vergleich ist wertlos.

Zwei Beziehungen, die aufgehen sollten: `tracked` = dem tatsächlichen Inhalt der
Mitglieds-Drives, und die `drive`-Kapazität = Summe der `maxStorage` aller
Mitglieds-Drives. Die frühere Annahme `tracked` = `drive` war falsch: `drive`
führt `storedAmount`, also die gebuchte Menge, `tracked` die Stapel selbst. Die
beiden fallen nur zusammen, wenn in jedem Stapel auch die Anzahl steht, die
gebucht wurde.

### 5.3 Umgesetzt: P1 ist eine Auslöser-Frage (Commit `a5add2b`)

Der periodische Vollaufbau ist gestrichen. Er war nie der normale Pfad, sondern
ein Netz auf Verdacht: **jede** Strukturänderung setzt `shouldRefresh` ohnehin.
Nachgeprüft an allen `:remove()`- und `new()`-Funktionen — jede ruft
`BaseNet.update_network_controller` — und an den Ereignis-Registrierungen in
`control.lua`: `on_player_mined_entity`, `on_robot_mined_entity`,
`script_raised_destroy` und `on_entity_died` laufen alle über `Event.removed` →
`obj:remove()`. Bei einer Entfernung ist das Objekt in diesem Moment noch
Mitglied, also greift der Flag-Zweig in `update_network_controller`.

Änderung: `NC.updateTick` steht auf 7200 statt 600. Der Vollaufbau läuft bei
jeder Strukturänderung, zusätzlich als Netz alle zwei Minuten pro Controller.
Im Dauerzustand fällt kein Aufbau mehr an.

Bewusst nicht gebaut: die Austrittssubtraktion aus Abschnitt 3.2 des Plans. Sie
würde nur die Aufbauten sparen, die mit einer Baumaßnahme zusammenfallen — und
in diesem Moment zahlt der Baupfad ohnehin ein Vielfaches davon (Punkt g,
Beitrittskaskade). Dafür müsste jede Austrittsbuchung die Beitrittsbuchung
exakt spiegeln. Ohne messbaren Gewinn ist das nur zusätzliche Fehlerfläche.

### 5.4 Zweiter Abnahmelauf: der Vollaufbau ist deterministisch

Vor dem Transfer-Test in 5.5 noch ein Lauf mit demselben `10 20`-Aufbau, zwei
Dumps 1.337 Ticks auseinander mit `/rns-debug-refresh` dazwischen. Alle drei
Zähler lesen 260000 (`tracked`, `drive` und `truth`), beide Dumps bitgleich.

Damit ist der Vollaufbau deterministisch und stimmt mit dem tatsächlichen Inhalt
der Drives überein. Was dieser Lauf allein **nicht** zeigt: dass der
inkrementelle Pfad zwischen zwei Aufbauten dieselben Werte hält — beide Dumps
kamen aus einem Rebuild, weil der Fill `shouldRefresh` setzt. Das leistet erst
der Transfer in 5.5.

Nachgerechnet: 5×4.000 + 15×16.000 = 260.000 bei 20 Drives zyklisch über vier
Größen. Kapazität 1.700.000 = 5×(4.000 + 16.000 + 64.000 + 256.000).

Zwei Auffälligkeiten aus früheren Läufen lagen im Aufbau, nicht im
Produktivcode:

- Die sieben Netze mit `tracked=0 cache=0 drive=0` waren der Fill, der die
  Netzwerkbuchhaltung nie berührt. Behoben: `StressTest.fill` setzt
  `shouldRefresh` auf jedem berührten Controller.
- Der Widerspruch `drive=420000` statt `260000` kam aus einem Spielstand, dessen
  Netze `tracked=644` bei `drive=644000` lasen — Faktor 1.000, die Signatur des
  Fills vor `bfc0618`, der `count = 1` speicherte und die gebuchte Menge
  mitzählte. **Als Beweisstück verworfen.**

### 5.5 Dritter Lauf: Transfer geprüft — P1 abgenommen

Derselbe `10 20`-Aufbau, drei Dumps. Dazwischen: eine Einlagerung von drei Items
über das NII eines Controllers (NC 27), danach ein erzwungener Vollaufbau.

| Dump | NC 27 |
|---|---|
| A (Tick 7902) | `tracked=260/16 cache=16 drive=260000/1700000 truth=20/260000/260` |
| B nach Einlagerung (10195) | `tracked=263/19 cache=19 drive=260003/1700000 truth=20/260003/263` |
| C nach Vollaufbau (11398) | `tracked=263/19 cache=19 drive=260003/1700000 truth=20/260003/263` |

Die neun übrigen Netze lesen in allen drei Dumps unverändert
`tracked=260/16 drive=260000/1700000 truth=20/260000/260`.

**B = C. Das ist der Abnahmemaßstab aus Abschnitt 6 des Plans, und er ist grün.**
Der inkrementelle Pfad hat die Einlagerung gebucht (A → B: `tracked` +3, `drive`
+3, `truth` behauptet +3, tatsächlicher Inhalt +3, `cache` und Typenzahl je +3),
und der Vollaufbau hat danach exakt dieselben Werte erzeugt.

Nachgerechnet: drei neue Item-Typen mit je einem Item. Deshalb steigen
Typenzahl und Cache um drei, und die Summen um drei. Die neun übrigen Netze
bleiben unberührt — die Buchung landet nur im Netz des benutzten Controllers,
und die Einlagerung bucht in beide Zähler übereinstimmend.

Damit ist die Behauptung aus 5.3 belegt, nicht mehr nur gelesen:

- Der periodische Vollaufbau war verzichtbar (beide Pfade stimmen überein).
- `Contents.item` und `StoredPartition` werden an der Buchungsstelle
  (`NetworkBase.lua:1055`) konsistent geführt.

### 5.6 Der geladene Spielstand ist Datenmüll — kein Codebefund

In diesem Lauf liest `truth` behauptet 260000 gegen tatsächlich 260, also Faktor
1.000: 260 Stapel mit je einem Item gegen 260000 gebuchte Items. Das ist die
Signatur des Fills vor `bfc0618`, der `count = 1` speicherte und in
`storedAmount` die Menge buchte — der geladene Spielstand stammt also aus einem
Aufbau mit der alten Fassung.

Welcher der beiden letzten Läufe welchen Spielstand geladen hat, kann ich aus den
Dumps nicht ableiten: die Controller-`entID`s sind in beiden identisch, weil
derselbe Aufbaubefehl an derselben Position dieselbe Entity-Reihenfolge erzeugt.
Für die Abnahme ist das ohne Belang, und in beiden Läufen stimmt `tracked` mit
`truth` tatsächlich überein.

Zwei Konsequenzen daraus:

- **`tracked` ≠ `drive` ist in einem gesunden Netz kein Widerspruch, sondern
  normal.** `tracked` summiert die Stapel selbst, `drive` führt `storedAmount`.
  Die beiden fallen nur zusammen, wenn in jedem Stapel die Anzahl steht, die
  gebucht wurde — genau das stellt `bfc0618` für den Testaufbau her.
- **Dieser Spielstand taugt nicht zum Spielen.** Er hat 259.740 Phantom-Items
  pro Netz: entnehmen lässt sich nur, was in den Stapeln liegt. Für
  GUI-Prüfungen und für die IO-Bus-Messung ist ein frischer Aufbau zu bauen.

**Empirisch bestätigt im Testlauf:** Entnehmen aus diesem Netz liefert fast
nichts, während Einlagern normal funktioniert. Der Mechanismus steht im Code und
ist nachvollziehbar, nicht gemessen:

- Die Anzeige baut `NII:createNetworkInventory` aus `interfaceCache.item` auf
  (`NetworkInventoryInterface.lua:352`). Der Cache führt die Stapel selbst,
  zusammengeführt je Name — hier also 20 Drives × 1 Item, nicht die 260000, die
  `Contents.item` und `StoredPartition` als Netzbestand führen.
- Beim Ziehen setzt `NII.transfer_from_idinv` die Menge auf
  `min(itemstack.count, count)` (`NetworkInventoryInterface.lua:666`) und ruft
  `extract_item_from_drive`.
- Dort begrenzt `drive:remove_item(master, math.min(storedItem.count,
  transferCapacity), exact)` die Entnahme auf `storedItem.count`, und das ist im
  Stapel 1 (`NetworkBase.lua:885`). Ein 64k-Drive speichert also 1000 Items, gibt
  aber eines her.

Ein frisch eingelagertes Item liegt dagegen mit echtem Zähler im Stapel und
kommt vollständig zurück — genau die Beobachtung aus dem Testlauf. **Kein
Produktivbefund.** Die Entnahme ist auf einem gesunden Aufbau bisher
ungemessen; siehe 5.8.

### 5.7 Austritt geprüft

Ein Drive abgebaut, drei Dumps um den Vorgang herum. NC 27:

| Dump | members | powerDraw | tracked | cache | drive | truth |
|---|---|---|---|---|---|---|
| A (7580) | 64 | 17020 | 260/16 | 16 | 260000/1700000 | 20/260000/260 |
| B (9495) | 63 | 16380 | 244/16 | 16 | 244000/1636000 | 19/244000/244 |
| C (13820, nach `/rns-debug-refresh`) | 63 | 16380 | 244/16 | 16 | 244000/1636000 | 19/244000/244 |

Die neun übrigen Netze bleiben in allen drei Dumps unverändert.

**Der Abbau hat den Rebuild selbst ausgelöst** — das ist der Punkt, der hier
belegt wird, und er lässt sich gegen den Takt abgrenzen. Das Sicherheitsnetz
feuert, wenn `(tick + refreshOffset) % 7200 == 0` mit
`refreshOffset = entID % 7200`. Für die vorliegenden `entID`s (27 bis 3665) liegt
der erste Termin bei `7200 - entID`, also zwischen 3535 und 7173 — vor Dump A.
Der nächste wäre `14400 - entID`, also zwischen 10735 und 14373 — nach Dump B.
**Kein Controller konnte dazwischen am Netz hängen.** Die Änderung in Dump B
stammt folglich aus dem Abbau: `ID:remove()` ruft
`BaseNet.update_network_controller` (`ItemDrives.lua:71`), das Objekt ist zu dem
Zeitpunkt noch Mitglied, der Flag greift.

Die Zahlen gehen auf: entfernt wurde ein 64k-Drive (Kapazität −64000,
`powerDraw` −640, Mitglieder −1), der 16 Typen à 1000 gebucht hatte
(`drive` −16000, `truth` behauptet −16000) und 16 Stapel à einem Item hielt
(`tracked` −16, `truth` tatsächlich −16). Cache bleibt bei 16, weil er je Name
zusammengeführt wird und der entfernte Drive nur Namen beisteuerte, die im Netz
bleiben.

**Was das nicht zeigt:** B = C gilt hier zwangsläufig, weil auch der Austritt
über den Vollaufbau läuft. Eine inkrementelle Austrittsbuchung gibt es bewusst
nicht (5.3). Geprüft ist damit die Behauptung, um die es geht: die Entfernung ist
ein Ereignis und wird gefangen, ohne Takt.

### 5.8 Die Entnahme: der Pfad trägt, der Klick erreicht ihn nicht

`NetworkBase.lua:888` ist die zweite Buchungsstelle. Am Phantom-Spielstand ist sie
nicht prüfbar (5.6).

**Erster Lauf auf gesundem Aufbau (Save `truth 20/260000/260000`): der GUI-Klick
bucht nichts.** Zwei Dumps, 4.052 Ticks auseinander, dazwischen mehrere
Klickversuche auch mit den Modifiern — `tracked` bleibt in allen zehn Netzen
exakt auf `260000/16`.

**Zweiter Lauf mit `/rns-debug-extract`: der Transfer trägt und bucht.**

```
rns-debug-extract: iron-plate want=1 can_insert=true emptyStacks=77 insertable=7700 network=20000 player=0
rns-debug-extract: left=0 network 20000-> 19999 player 0->1
rns-debug-extract: iron-plate want=100 ... network=19999 player=1
rns-debug-extract: left=0 network 19999-> 19899 player 1->101
```

`left=0` heißt: alles Gewünschte ist angekommen. `network` sinkt um genau die
Menge, `player` steigt um dieselbe — die Buchung in `Contents.item` läuft also.
`can_insert=true`, `insertable=7700`, `emptyStacks=77`: das Inventar ist weder
voll noch blockiert. **Damit ist die Entnahmebuchung selbst belegt.**

### 5.9 Klick-Spur: der Klick kommt durch, der Fehler sitzt tiefer

Erster Spur-Lauf (Commit `31d2347`), zwei Klicks, beide laufen bis in den Handler:

```
click 'RNS_NII_IDInv_16' button=2 shift=false ctrl=false
nii 'RNS_NII_IDInv_16' count=1 tags=yes id=28 stack=true obj=yes inNetwork=true
click 'RNS_NII_Insert' button=2 shift=false ctrl=false
nii 'RNS_NII_Insert' count=1 tags=yes id=28 stack=false obj=yes inNetwork=true
```

Damit ist die GUI-Verkabelung **ausgeschlossen**: Der Handler läuft, die Tags
sind da, die ID löst auf, `exists_in_network` ist wahr, und die Klickart ergibt
`count=1`. Der stille Ausstieg in Zeile 788 war nicht die Ursache. Der Fehler
sitzt in oder hinter `NII.transfer_from_idinv`.

Die Maustaste ist damit geklärt: `left=2`, `right=4`. `button=2` war die linke,
die Zuordnung im Code ist korrekt — belegt durch die Ausgabe, nicht durch
Annahme.

**Verdacht, aus dem Code gelesen.** Der Transfer sucht einen Drive, dessen
gespeicherter Stapel **exakt** zum übergebenen passt
(`compare_itemstacks(storedItem, exact)` mit `exact=true`,
`NetworkBase.lua:1009`), und kehrt ohne Meldung zurück, wenn er keinen findet.
Diese Prüfung ist der Kandidat; 5.11 legt sie offen.

### 5.10 Zweite Spur: der Aufruf läuft, er bewegt nichts

```
click 'RNS_NII_IDInv_7' button=2 left=2 right=4 shift=false ctrl=false
nii 'RNS_NII_IDInv_7' count=1 tags=yes id=28 stack=true obj=yes inNetwork=true
idinv stack name=advanced-circuit count=15000 modified=nil netBefore=15000
idinv match stored=false storedCount=nil loose=false exact=false
idinv result amount=1 net 15000->15000 player 0->0
```

Drei Befunde:

- **Kein Wurf.** `grep "RNSRedux error"` in `factorio-current.log` findet nichts,
  und die `result`-Zeile ist geschrieben. Der Aufruf ist zurückgekehrt.
  `GUI.on_gui_clicked` läuft über `Util.safeCall` (`utils/Util.lua:13–17`), ein
  Fehler stünde also in der Datei.
- **Der Aufruf bewegt nichts.** `net 15000->15000`, `player 0->0`.
- **Der stille Ausstieg ist die Vergleichsprüfung**, nicht die GUI-Verkabelung.

**Meine `match`-Zeile war wertlos** und darf nicht gelesen werden: Sie prüfte den
*ersten* Drive der Prioritätstabelle, und der hält `advanced-circuit` gar nicht —
daher `stored=false`. Bei 16 Typen zyklisch über vier Größen bekommen nur die 15
größeren Drives diesen Typ; die 15.000 sind 15 × 1.000.

### 5.11 Ursache gefunden: der Fill erzeugt eine Stapelform, die das Spiel nicht herstellt

Die Spur aus 5.10 (Commit `b3b33f3`) nennt beide Seiten im Klartext:

```
idinv stack name=advanced-circuit count=15000 netBefore=15000
idinv probe holdingDrive=true loose=true exact=false
  clicked[count=15000,health=1,modified=false,name=advanced-circuit,type=item]
  stored [count=1000,extras=table(0),health=1,modified=false,name=...,tags=table(0),type=item]
idinv result amount=1 net 15000->15000 player 0->0
```

Und dieselbe Datei liefert das Gegenbeispiel, das die Sache entscheidet:

```
idinv stack name=copper-ore count=100 netBefore=100
idinv probe holdingDrive=true loose=true exact=true
  clicked[count=100,health=1,modified=false,name=copper-ore,type=item]
  stored [count=100,health=1,modified=false,name=copper-ore,type=item]
idinv result amount=1 net 100->99 player 0->1
```

Kupfererz wurde über den echten Pfad eingelagert (Inventar → Insert, dann
entnommen) und geht durch: `loose=true exact=true`, Buchung `net 100->99`,
`player 0->1`. `advanced-circuit` kam aus dem Fill und geht nicht durch.

**Die Ursache, in vier Schritten gelesen:**

1. `Itemstack.create_template` setzt `tags = {}` und `extras = {}` — und danach
   nur noch Zuweisungen, die für gewöhnliche Items `nil` sind
   (`Itemstack.lua:175–176`, `38–114`). Beide Felder bleiben also leere Tabellen.
2. `ID:add_or_merge_basic_item` legt den ersten Stapel **wie übergeben** ab
   (`inv[itemstack_data.name] = itemstack_data`, `ItemDrives.lua:205`). Die leeren
   Tabellen landen damit in den Drives.
3. Der echte Einlagerungspfad legt dagegen eine **Kopie** ab (`inv_item:split(...)`,
   `NetworkBase.lua:1048`), und `split` beginnt mit `self:copy()`
   (`Itemstack.lua:232`). `Util.copy` baut sein Ergebnis **innerhalb** der Schleife
   (`copy = copy or {}` in `Util.lua:122`), eine leere Tabelle wird deshalb zu
   `nil`. Ein echter Stapel trägt weder `tags` noch `extras`.
4. `compare_itemstacks(..., exact=true)` prüft beide Felder, und
   `compare_tags` typprüft das **zweite** Argument, bevor es das erste
   durchläuft (`Itemstack.lua:207–209`). `nil` gegen `{}` ergibt `false` — der
   Transfer findet keinen passenden Drive und kehrt ohne Meldung zurück.

Nachgerechnet: Der Faktor `amountPerType` in `stored[count=1000]` gegen
`clicked[count=15000]` ist bedeutungslos — `count` wird in der Prüfung gar nicht
verglichen. Der einzige Unterschied sind `tags` und `extras`.

**Damit ist es wieder der Aufbau, kein Produktivfehler.** Die Feldliste aus 5.10
hat den falschen Drive geprüft (`stored=false`) und war insofern irreführend.

### 5.12 Was korrigiert ist, und die offene Kante dabei

Commit `b78f3e0`, beide Seiten auf die Form des echten Pfads gebracht:

- `StressTest.fill` kopiert die Vorlage vor dem Ablegen (`template:copy()`), womit
  `Util.copy` die leeren Tabellen genauso zu `nil` macht wie im Spiel.
- `/rns-debug-extract` kopiert seinen Master aus demselben Grund. **Der Befehl
  hatte denselben Fehler in der anderen Richtung:** Sein Master war
  `create_template`-förmig und passte deshalb nur auf gefüllte Drives. Auf einem
  im Spiel befüllten Netz hätte er versagt.

Produktivcode ist unberührt. Die Stellen, die `exact=true` übergeben, bekommen
ihren Master aus einem echten Stapel; die Stellen, die einen Master über
`create_template` bauen (`ItemIOV3.lua:525`, `NetworkBase.lua:1120`,
`RNSPlayer.lua:110/131`), geben `exact=false` — dort wird `tags`/`extras` gar
nicht verglichen. Gelesen, nicht gemessen; jede dieser Stellen ist eine Falle für
den nächsten, der dort `exact=true` setzt.

**Offene Kante, nicht angefasst:** `compare_tags` hält eine leere Tabelle und
`nil` für verschieden. Das ist unsymmetrisch — `compare_tags({}, {a=1})` liefert
`true`, weil die Schleife über das erste Argument läuft. Eine Korrektur daran
ändert die Vergleichssemantik im ganzen Transferpfad und gehört damit nicht in
diese Runde. Vorgemerkt für P3 (Chargentransfer), wo die Vergleiche ohnehin
angefasst werden.

An derselben Stelle bleibt eine Beobachtung, die ohne Not nicht korrigiert wird:
`ID:add_or_merge_basic_item` legt den übergebenen Stapel unverändert ab, statt wie
der echte Pfad zu kopieren. Der Fill nutzt das aus; im Produktivpfad ist die
übergebene Form bereits die des echten Pfads, deshalb fällt es dort nicht auf.

### 5.13 Ergebnis und Aufräumen

Letzter Lauf auf frischem Aufbau (Commit `b78f3e0`), zwei Klickarten:

```
click 'RNS_NII_IDInv_7'  count=1   exact=true  →  net 15000->14999  player 0->1
click 'RNS_NII_IDInv_1'  count=-4  exact=true  →  net 20000->12400  player 0->7600
```

Linksklick entnimmt eines, Strg+Linksklick den ganzen Bestand. Die 7600 statt
20000 sind die **richtige** Grenze, nicht ein Fehler: `isPlayer` begrenzt die
Übergabe auf die freie Menge im Inventar (`NetworkBase.lua:961`), und der erste
Werkzeuglauf hatte 77 freie Slots à 100 Eisenplatten gemeldet — nach dem einen
abgezogenen Item sind es 76, also 7600. Exakt.

**P1 ist damit abgeschlossen.** Beide Buchungsrichtungen sind gemessen, Austritt
und Entnahme, und der Vollaufbau reproduziert beide.

Diagnose entfernt, Commit `ab3d4ae`: die Klick-Spur in `Gui.lua` und die drei
Spuren in `transfer_from_idinv` sind weg; `grep` auf `TEMPORARY DIAGNOSTIC` und
`rns-click` liefert nichts mehr. `/rns-debug-extract` bleibt — es ist ein
Werkzeug wie `/rns-debug-refresh`, keine Spur — und gehört in die P6-Aufräumliste.

**Ein echter Fund beim Aufräumen.** `NII.interaction` hatte keinen Zweig für
`RNS_NII_PInv_*`, die Buttons der Spielerinventar-Spalte waren also tot: Das GUI
erzeugt sie (`NetworkInventoryInterface.lua:322/327`), aber niemand liest ihren
Klick. `NII.transfer_player_to_network` stand als **tote Funktion** in der Datei,
und `port_pinv.py:33` zeigt, dass genau dieser Zweig bei der Portierung eingefügt
werden sollte — er ist nicht im Code angekommen. Verdrahtet in `ab3d4ae`, vor dem
`RNS_NII_IDInv`-Zweig. **Ungemessen**, der Zweig ist neu und hat noch keinen
Testlauf.

**Weiterhin offen und ungemessen:** der Sortierschalter `RNS_NII_SortOrder` wird
im Klick-Pfad behandelt, ein `switch` feuert aber `on_gui_element_changed`, und
dort fehlt der `RNS_NII`-Zweig (`Gui.lua:170–215`). Der Schalter sollte damit
wirkungslos sein — gelesen, nicht gemessen.

**Ebenfalls offen:** Save/Load mit einem Transfer dazwischen. Der Wert in
`storage` sollte den Ladezyklus überstehen, weil `DataConvert` für Blueprints
greift und die Objekte sonst unverändert in `storage` liegen — gelesen, nicht
gemessen. Mit P2 (ItemStore) bekommt das ohnehin einen eigenen Test.

## 6. Der IO-Bus (nächster Posten, Messaufbau steht)

Der IO-Bus ist die einzige Kostenquelle, die dauerhaft und vielfach pro Sekunde
anfällt. Der Refresh-Posten im Dauerbetrieb ist seit `a5add2b` entfallen; er
fällt nur noch bei Strukturänderungen an.

**Gemessen, Stand 30.09.2026 (Details in `docs/projektstand.md` 6.2):** 40 Busse
kosten 2,31 ms pro Tick im Mittel und eine Spitze von 20,9 ms bei 16,667 ms
Budget. Ohne Busse liegt die Mod bei 0,221 ms. Damit ist die Frage aus 6a
entschieden — der Buspfad ist der Posten, und zwar um eine Größenordnung.

Belegt durch den Changelog des Originalautors, der über vier Monate wiederholt
an Kadenz und Vollständigkeitsprüfungen nachgebessert hat, ohne die Struktur
anzufassen: 1.0.3 „improving ups by ~50%", 1.0.18 Grid „every tick instead of
55 ticks", 1.0.25 „network fullness check … doesn't cause a sudden lag spike",
1.0.30 „stop triggering anymore IO buses from working uselesslly", 1.0.39
External Bus von 2 auf 5 Ticks, 1.0.40 „less laggy".

Im Code:

- `EIO:update` (`ExternalIO.lua:273–300`) holt pro Durchlauf `get_inventory(i)`,
  ruft `sort_and_merge()` darauf und legt für **jeden Slot** ein
  `Itemstack:new(...)` an (Zeile 278). Bei `RNS_ExternalStorage_Tick = 5` sind
  das zwölf volle Container-Scans pro Sekunde und Bus, mit einer Allokation pro
  Slot.
- `NetworkBase.lua:1066–1069` fragt pro Insert-Versuch zweimal `get_item_count`
  und einmal `count_empty_stacks(true, false)` auf einem echten Inventar ab.
- `insert_item_into_external` ruft am Ende jeder Charge noch
  `external:update(self)` (Zeile 1101) — ein weiterer voller Scan im Transfer.
- `NetworkController.lua:124–133` prüft fünf globale Tick-Modulo (Detector 3,
  ItemIO 4, FluidIO 5, ExternalStorage 5). Bei Tick 20 laufen ItemIO und
  ExternalStorage zusammen, bei Tick 60 alle vier. Der Spike ist damit dauerhaft
  rund vier- bis fünfmal so hoch wie nötig.

Die entscheidungsrelevante Trennung: **Phase verschieben kostet keinen
Durchsatz, Kadenz senken kostet Durchsatz.** `RNS_ItemIO_Tick = 4` entspricht
15 Items/s bei `IIOMultiplier = 1`; eine Senkung auf 16 Ticks viertelt den
Durchsatz, solange eine Charge ein Item groß ist. Das wäre eine
Balance-Änderung, keine Optimierung.

Blocker: Der Stresstest baute keine IO-Busse, der Pfad war also nicht messbar.
**Behoben am 30.09.2026** — siehe 6.1.

### 6.1 Der Stresstest baut jetzt Busse

`/rns-stress-build <stationen> <drivesProStation> [busseProStation]`. Pro Bus drei
Entities an einer Station: ein Stichkabel, der Bus, seine Kiste (die Kiste zählt
nicht zum Netz, das Stichkabel zählt als Kabel). Die Spalten liegen südlich der
Spinne, deren Geometrie unverändert bleibt. Erwartung:
`members = Drives + spineLength + 2 × Busse + 2` — der Befehl gibt den Wert
selbst mit aus, `/rns-stress-status` prüft gegen.

| Aufbau | `members` |
|---|---|
| `10 20` | 64 |
| `10 20 4` | 72 |
| `20 50 10` | 174 |

Abwechselnd Item-IO (exportiert aus dem Netz, Kiste startet leer) und
External-IO (importiert, Kiste mit 4.800 Items vorgefüllt).

**Zwei Einstellungen setzt der Aufbau selbst, sonst tun die Busse nichts** — beide
beim Bau gelesen, nicht vermutet:

- `filters` auf ein Item, das der Fill in die Drives legt. `ItemIOV3:IO` betritt
  den Exportzweig nur bei `filters.max ~= 0` (`ItemIOV3.lua:522`) und baut den
  Master-Stack aus dem Filter (`525`). Ein Bus ohne Filter ist wirkungslos.
- `onlyModified = false` am External-Bus. Der Import überspringt sonst jeden
  unmodifizierten Stapel (`NetworkBase.lua:1187`), und der Aufbau hält nur
  unmodifizierte — der Bus würde den Container lesen und nichts bewegen.

`/rns-stress-status` meldet `buses total= withTarget= inNetwork=`. Ein Bus ohne
Ziel tut nichts, ein Bus ohne Netz bekommt keine Updates. Beides ist der erste
Verdacht, wenn die Messung flach bleibt.

Einschränkung: Die Busspalten müssen in die Spinne passen, deren Länge mit
`drivesPerStation` wächst. Der Befehl kürzt die Buszahl selbst und meldet es.
Busse und Drives lassen sich also nicht unabhängig skalieren.

**Noch nicht gebaut:** der Infinity-Aufbau für die Dauerlast. Die External-Kisten
laufen bei 15 Items/s in gut fünf Minuten leer; für eine Zwei-Minuten-Messung
reicht das, für längere nicht.

### 6.2 Erste Messung: der Buspfad ist der Posten, und zwar deutlich

Zwei Aufnahmen, gleicher Grundaufbau `10 20`, gleiches Fill, einziger Unterschied
der dritte Parameter. Zuordnung aus der Reihenfolge im Testlauf — die Aufnahme
ohne Busse entstand vor dem Befehl `10 20 4`, der zwischen beiden steht.

| Aufbau | mod-RNSRedux avg | min | max | Script update | Update |
|---|---|---|---|---|---|
| `10 20 0` | 0,221 ms | 0,070 | 1,003 | 0,224 | 0,781 |
| `10 20 4` | 2,527 ms | 0,054 | 20,945 | 2,529 | 3,095 |

**40 Busse kosten 2,31 ms pro Tick im Mittel und eine Spitze von 20,9 ms.** Das
Tick-Budget ist 16,667 ms. Ohne Busse ist die Mod 1,3 % des Ticks, mit Bussen
15 %, und die Spitze liegt über dem Budget. `mod-RNSRedux` und `Script update`
sind praktisch deckungsgleich — die Script-Zeit ist die Mod.

Zur Größenordnung pro Bus, als Rechnung mit Vorbehalt: 20 Item-Busse laufen auf
einem von vier Ticks, 20 External-Busse auf einem von fünf, also 5 + 4 = 9
Busläufe pro Tick im Mittel. 2,31 ms / 9 ergibt rund **256 µs für einen
Buslauf**. Das ist mehr als die gesamte Mod ohne Busse pro Tick kostet.

Was die Aufnahme **nicht** hergibt und deshalb offen bleibt:

- Ob beide Läufe gleich lange standen und ob der Bus-Lauf gefüllt war. Nur die
  `mod-RNSRedux`-Zeile ist ein sauberer Vergleich; Render- und GUI-Werte
  unterscheiden sich zwischen den Aufnahmen (Render preparation 0,587 gegen
  0,338), also war der Kamerazustand nicht identisch.
- Ob die Spitze am Kollisionstakt hängt. Erwartet ja: bei Tick 20 laufen ItemIO
  (4) und ExternalStorage (5) zusammen. Der Phasen-Offset in 6.3 beseitigt
  genau das und ist damit zugleich der Test der Annahme — fällt `max` unter das
  Budget, während `avg` gleich bleibt, war die Spitze die Bündelung.
- Wo die 2,3 ms im Mittel herkommen. Aus dem Code gelesen, nicht gemessen:
  `EIO:update` scannt jeden Slot des Containers mit `Itemstack:new`
  (`ExternalIO.lua:278`), `insert_item_into_external` ruft am Ende **jeder**
  Charge noch einmal `external:update` (`NetworkBase.lua:1101`), und
  `NetworkBase.lua:1066–1069` fragt pro Insert-Versuch zweimal `get_item_count`
  und einmal `count_empty_stacks` ab. Dazu `remove_item_from_interface_cache`
  als linearer Scan pro Entnahme (Plan-Punkt c, gehört zu P3).

### 6.3 Phasen-Offset umgesetzt (Commit `beb263c`)

Jeder Bus läuft weiterhin alle vier (Item) bzw. fünf (External) Ticks, aber auf
einer eigenen Phase aus seiner `unit_number`. Damit feuert nicht mehr das ganze
Spiel im selben Tick. Zwei Details, die die Änderung nicht trivial machen:

- **Der External-Bus kann die Prüfung nicht selbst tragen.**
  `insert_item_into_external` und `extract_item_from_external` rufen
  `EIO:update` mitten im Transfer (`NetworkBase.lua:1101`, `652`) — diese Aufrufe
  müssen ungephaset bleiben, sonst ist der Cache direkt nach dem Schreiben des
  Containers veraltet. Deshalb der Parameter `periodic`: nur der Sweep wird
  gephaset.
- **Das Tick-Gate im Controller muss weg.** Bliebe
  `game.tick % RNS_ItemIO_Tick == 0` stehen, liefe ein Bus mit einer `entID`, die
  nicht durch 4 teilbar ist, **nie**.

Der Sweep ist damit O(Busse) pro Tick statt O(Busse) alle vier Ticks, und
`filter_externalIO_by_valid_signal` läuft jeden Tick statt jeden fünften. Beides
ist billig gegen einen Container-Scan. **Bei einigen Tausend Bussen braucht der
Sweep trotzdem eine Warteschlange** — das ist P4.

Nicht mitgemacht: die Fluid-Busse und der Detektor behalten ihre globalen Ticks.
Der Offset senkt außerdem nur die Spitze, nicht den Mittelwert.

### 6.4 Erste Offset-Messung: Spitze weg, Mittelwert gestiegen

Derselbe `10 20 4`-Stand, zwei Minuten, `/perf-avg-frames 600`:

| Aufnahme | `mod-RNSRedux` avg | min | max | `Update` avg | `Frame cycle` max |
|---|---|---|---|---|---|
| gebündelt (6.2) | 2,527 | 0,054 | 20,945 | 3,095 | 23,045 |
| gephaset (6.3) | 2,878 | 1,776 | 13,990 | 3,447 | 17,208 |

**Die Bündelung war die Ursache der Spitze — bestätigt.** `max` fällt von 20,945
auf 13,990 ms, unter das Budget von 16,667. `Frame cycle` überschreitet es nur
noch um 0,5 ms statt um 6,4.

**Aber der Mittelwert ist um 0,35 ms gestiegen, und der Boden von 0,054 auf
1,776 ms.** Das ist eine Verschlechterung, die ich eingebaut habe, und sie ist
größer als der Gewinn: Die Mod kostet jetzt **jeden** Tick rund 1,8 ms, vorher
fast nichts mit gelegentlichen Spitzen. Der Boden ist die interessantere Zahl,
weil der Mittelwert Spitzen verwischt und der Boden zeigt, was dauerhaft anliegt.

**Die Ursache stand im eigenen Kommentar.** `NC:updateExternalStorage` lief ab
6.3 jeden Tick und rief `filter_externalIO_by_valid_signal` — und das ruft
`signal_valid` **und** `check_focused_entity` auf jedem Bus
(`NetworkBase.lua:1340–1355`). `check_focused_entity` validiert die Inventare des
Containers. Fünffache Häufigkeit bei gleicher Arbeit pro Aufruf: Der Bus selbst
wurde gephaset, seine Vorprüfungen nicht.

### 6.5 Behoben (Commit `10154d6`)

Das Phasentor sitzt jetzt **vor** den teuren Prüfungen statt nur vor dem Update.
`EIO:is_periodic_tick()` wird zuerst gefragt; ein Bus in der falschen Phase kostet
einen Modulo und sonst nichts. `signal_valid` und `check_focused_entity` laufen
nur noch auf dem eigenen Tick des Busses — also mit der Häufigkeit von vor der
Entzerrung.

Erwartung: `avg` zurück auf rund 2,4–2,5 ms, `min` fällt deutlich (aber nicht auf
0,054 zurück, weil die Arbeit jetzt echt verteilt ist), `max` bleibt unter dem
Budget. Das Ergebnis steht in 6.6.

### 6.6 Zweite Offset-Messung: das Phasentor greift

Derselbe `10 20 4`-Stand, nach `10154d6`:

| Aufnahme | avg | min | max | `Frame cycle` max |
|---|---|---|---|---|
| ohne Busse (6.2) | 0,221 | 0,070 | 1,003 | — |
| gebündelt (6.2) | 2,527 | 0,054 | 20,945 | 23,045 |
| Phasentor vor dem Update (6.4) | 2,878 | 1,776 | 13,990 | 17,208 |
| Phasentor vor den Prüfungen (6.6) | 2,756 | 2,095 | **7,974** | — |

**`max` fällt auf 7,97 ms, weniger als die Hälfte des Budgets.** Die Ursache der
Spitze war die Bündelung, und der Vorprüfungs-Overhead war der Rest — beides
bestätigt. `Frame cycle` liegt damit wieder im Takt.

**Der Boden steigt weiter, auf 2,095 ms — und das ist der Beweis, dass die
Verteilung funktioniert.** Ohne Busse liegt der Boden bei 0,070; mit gephaseten
Bussen kann er nicht dorthin zurück, weil jetzt in **jedem** Tick rund neun
Busläufe stattfinden. Boden und Mittelwert rücken zusammen (2,095 zu 2,756, also
76 %), die Arbeit ist also nahezu gleichmäßig verteilt. Vorher war der Boden
0,054 bei einem Mittel von 2,527 — dieselbe Arbeit, nur in wenige Ticks gepackt.

**Offen bleibt der Mittelwert.** Er liegt mit 2,756 über den 2,527 des
gebündelten Laufs, also 9 % höher. Zwei Erklärungen sind möglich und ich kann
sie mit dieser Aufnahme nicht trennen: der Sweep läuft jetzt jeden Tick über alle
Busse (billig, aber nicht gratis), oder es ist Messrauschen. Ein Lauf gegen den
unveränderten Bestand wäre der Test — dafür müsste der Offset abschaltbar sein,
was er nicht ist. **Ich buche die 9 % als ungeklärt, nicht als Kosten.**

Was sicher ist: **die Spitze war das Problem, und sie ist weg.** Ob 40 Busse
2,5 ms kosten, ist unabhängig davon, wie die 2,5 ms über die Ticks verteilt sind.

### 6.7 Die Kontaktkosten, Verdacht im Code

Nach Abzug der Grundlast (0,221 ms) bleiben **rund 2,5 ms für 40 Busse**, also
6,3 % des Budgets — dauerhaft, in jedem Tick. Das skaliert linear: 400 Busse wären
über dem Budget.

Der Verdacht steht im Code, und alle drei Punkte sind dieselbe Sorte Zugriff:

- `EIO:update` läuft bei **jedem** Buslauf über **jeden** Slot des Containers und
  legt dafür ein `Itemstack:new(...)` an (`ExternalIO.lua:291`) — bei 48 Slots
  also 48 Allokationen pro Buslauf. Dazu `Itemstack:new` mit `t.extras = {}`, also
  zwei Tabellen pro Slot.
- `inv.sort_and_merge()` über den ganzen Container, bei jedem Buslauf
  (`ExternalIO.lua:289`; weitere Stellen `223`, `NetworkBase.lua:952`).
- `NetworkBase.lua:1066–1069` fragt pro Insert-Versuch zweimal `get_item_count`
  und einmal `count_empty_stacks` ab.

Welche der beiden Busarten das trägt, war offen — der Aufbau baute bisher nur
gemischt. 6.8 beantwortet es.

### 6.8 Gemessen: die External-Seite trägt 82 % der Buskosten

| Aufbau | avg | min | max | Buskosten gegen 0,221 |
|---|---|---|---|---|
| ohne Busse | 0,221 | 0,070 | 1,003 | — |
| `4 item` (40 Item-Busse) | 1,125 | 0,593 | 7,052 | **0,90 ms** |
| `4 external` (40 External-Busse) | 4,322 | 3,511 | 10,686 | **4,10 ms** |
| `4 mixed` (20 + 20) | 2,756 | 2,095 | 7,974 | 2,54 ms |

**Die External-Seite ist 4,5-mal so teuer wie die Item-Seite**, bei gleicher
Busanzahl. Pro Buslauf: **513 µs external gegen 90 µs item** (40 Busse auf einem
von fünf bzw. einem von vier Ticks). 40 External-Busse kosten 4,10 ms, also 25 %
des Tick-Budgets — und das skaliert linear: 160 Busse wären über dem Budget.

**Die Zuordnung prüft sich selbst.** 20 Item-Busse (halbe Menge → 0,45 ms) plus
20 External-Busse (2,05 ms) ergeben 2,50 ms, gemessen wurden im gemischten Aufbau
2,54 ms. Abweichung 1,3 %. Die drei Messungen passen also zusammen, und damit
trägt die Trennung.

**Konsequenz für die Reihenfolge: P5 vor P4.** Der Plan führt beide als getrennte
Meilensteine, und nach dieser Messung ist die External-Seite der Posten. Der
Scheduler bleibt richtig, greift aber am kleineren Anteil.

Zur Einordnung des Fixtures: In `mixed` ziehen die Item-Busse aus den Kisten der
External-Busse, in `external` gibt es keinen Abnehmer, also bewegt sich dort
nichts. **Für die Bewertung einer Ersparnis ist `mixed` der ehrliche Aufbau**, in
`external` würde jede Einsparung am ruhenden Container zu groß erscheinen.

### 6.9 Erster P5-Eingriff: der Container wird nur noch bei Änderung gelesen

Commit `0db27d7`. Der External-Bus stellt eine billige Frage — die Gesamtzahl der
Items im Container — und läuft nur dann über die Slots, wenn die Antwort eine
andere ist. Der Durchlauf besteht aus einem Zugriff pro Slot plus einem
`sort_and_merge` über den ganzen Container; daraus bestehen die 513 µs.

Zwei Randbedingungen, im Code gelesen und nicht vermutet:

- **Das Tor sitzt hinter den Schutzprüfungen.** Die Wächter davor
  (`focusedEntity` ungültig, kein Inventar) räumen den Cache ab, `init_cache`
  danach baut ihn. Beide hinterlassen `cache == nil`, und `nil` heißt lesen.
- **Ein Vollaufbau wird erzwungen**, alle `RNS_ExternalStorage_Rescan` (20)
  Sweeps. Sonst bliebe ein Container unbemerkt, dessen Gesamtzahl gleich bleibt,
  während der Inhalt umgeschichtet wird.

**Was das ändert und was nicht:** Der Bus transferiert nichts anders, er liest nur
seltener. Die Menge, die ein Sweep sieht, ist dieselbe.

**Das Risiko ist die Buchhaltung**, nicht der Durchsatz: der Cache speist
`Contents.item` und `StoredPartition` des Netzes. Bleibt er zu lange stehen,
laufen die Zähler auseinander.

**Und der P1-Abnahmetest fängt das nicht.** `NetworkBase.addConnectables` ruft für
jeden External-Bus `init_cache()`, und `init_cache` kehrt zurück, wenn schon ein
Cache da ist (`ExternalIO.lua:217`) — der Vollaufbau baut die Zähler also **aus
dem Cache** und fasst den Container nicht an. Ein Cache, der nicht mehr liest,
sähe in zwei Dumps identisch aus. Deshalb hat der Dump eine neue Spalte
(Commit `3f7d80b`):

```
busTruth=<Busse>/<was der Cache behauptet>/<was im Container steht>
```

Das ist die Größe, die die Änderung überleben muss. `external=` und `busTruth`
mittlere Zahl müssen zusammenpassen; die dritte ist die Wahrheit im Container.
Hinzu kommt `busSkips=<übersprungen>/<gesamt>` — dieses Paar zählt, wie oft die
Abkürzung greift, und **geht selbst auf**, siehe 6.11.

**Der Gewinn hängt daran, wie oft sich der Container ändert**, und der Messaufbau
ist dabei der Bestfall (siehe 6.10). Wenn die Zahl nicht deutlich fällt, ist der
nächste Schritt Plan-Punkt (j) in voller Länge: der Slot-Durchlauf selbst, also
`Itemstack:new` pro Slot und das `sort_and_merge` — das braucht aber eine andere
Vergleichsgrundlage als den Slot-Index und ist damit der größere Umbau.

### 6.10 Messung: der Zähler bestätigt den Mechanismus

Gemischter Aufbau `10 20 4`, zwei Minuten, `/perf-avg-frames 600`:

| Aufnahme | avg | min | max |
|---|---|---|---|
| vor der Abkürzung (6.6) | 2,756 | 2,095 | 7,974 |
| nach der Abkürzung | **1,088** | 0,207 | 10,786 |

**Die Buchhaltung hält, und die Zahlen schließen sich gegenseitig auf.** Zwei
Dumps, dazwischen der erzwungene Refresh:

```
# vorher   tracked=260542/16 drive=250942/1700000 external=96/96 truth=20/250942/250942 busTruth=2/9600/9600
# nachher  tracked=260000/16 drive=250400/1700000 external=96/96 truth=20/250400/250400 busTruth=2/9600/9600
```

Vier unabhängige Proben stimmen überein:

- **`tracked` = `drive` + External.** 250400 + 9600 = 260000, und 250942 + 9600 =
  260542. Die 9600 aus `busTruth` sind genau der External-Anteil in `tracked`. Das
  schließt den Kreis: der Cache speist `Contents.item` mit dem richtigen Wert.
- **`truth` behauptet = tatsächlich** (250400/250400): die Drives sind in sich
  konsistent.
- **`busTruth` Cache = Container** (9600/9600): der Cache stimmt mit dem Container
  überein.
- **`external=96/96`** sind die belegten Slots der beiden Item-External-Busse
  (2 × 48, voll), und 96 × 100 Items = 9600. Passt zu `busTruth`.

Die 542 Items, um die `tracked` zwischen den Dumps fällt, sind **legitime Arbeit**,
kein Fehler: die Item-Busse haben während der Messung exportiert (2 Busse × rund
271 Items in 1.109 Ticks, bei einem Item pro vier Ticks). Dass `drive` um
denselben Betrag fällt und `external` sich nicht rührt, ist genau das erwartete
Bild: Quelle sind die Drives, die External-Container waren voll und wurden nicht
angefasst.

### 6.11 Der Zähler belegt die Ursache, der Kontrolllauf war untauglich

Vier Dumps aus einem Lauf, 16.573 Ticks Abstand zwischen erstem und letztem:

| Dump | Tick | `busSkips` | Anteil |
|---|---|---|---|
| 1 | 3.328 | 382/402 … 384/404 | 95,0 % |
| 2 | 9.364 | 2.676/2.818 | 95,0 % |
| 3 | 12.634 | 3.920/4.126 | 95,0 % |
| 4 | 19.901 | 6.680/7.032 … 6.682/7.034 | 95,0 % |

**Die Zählung geht exakt auf.** Zwei External-Busse pro Netz, jeder auf einem von
fünf Ticks, über 16.573 Ticks: erwartet 16.573 × 2/5 = **6.630** Sweeps, gezählt
6.630 (7.032 − 402). Kein Doppelzählen, keine Lücke.

**Und die 5 % sind der Sicherheitsabruf.** Nicht übersprungen wurden 6.630 − 6.298
= **332**, und 6.630/20 = 331,5 — genau der erzwungene Volllauf alle
`RNS_ExternalStorage_Rescan` (20) Sweeps. Die Container dieses Aufbaus ändern sich
also **nie**: jeder volle Lesevorgang ist das Netz, nicht eine Änderung.

**Damit ist die Zuordnung aus 6.10 belegt** — nicht durch den Kontrolllauf,
sondern durch die Zählung: die Abkürzung greift bei 95 % der Sweeps, und
0,05 × 4,10 ms = 0,21 ms erwartete External-Restkosten. Der Kontrolllauf aus der
letzten Runde (Commit `4424050` voraus) war **untauglich**, nicht widerlegend: alle
vier Dumps zeigen wachsende Zähler, der Zustand `Rescan = 1` kommt in der Ausgabe
nicht vor. Entweder wurde der Wert nicht gesetzt oder er kam nicht an.

**Zwei Konsequenzen:**

- **Die Zählung ist der bessere Beweis als der A/B-Lauf.** Sie ist monoton und
  selbstprüfend: Sweep-Zahl und Sicherheitsabruf-Anteil gehen beide exakt auf. Ein
  Kontrolllauf, dessen Eingriff man nicht verifizieren kann, wäre schwächer gewesen
  — auch wenn er funktioniert hätte.
- **Die 95 % sind der Bestfall.** Die Container sind statisch, die Abkürzung greift
  deshalb fast immer. In einer echten Anlage entnehmen Maschinen, die Gesamtzahl
  ändert sich, und es wird öfter gelesen. **Wie viel übrig bleibt, sagt dieser
  Aufbau nicht.**

**Und eine Zerlegung, die nicht aufgeht.** Mein früherer Schluss „External-Seite
von 4,10 auf 0,19 ms" rechnet 0,90 (Item, aus 6.8) + 0,19 = 1,09 und trifft die
gemessenen 1,088. Nach der Zählung müssten es aber 0,45 (20 statt 40 Item-Busse)
+ 0,21 = 0,66 ms sein. Gemessen sind 0,87 ms Buskosten (1,088 − 0,221). **Die
Differenz von 0,21 ms ist unerklärt.** Ich buche sie als offen; die Größenordnung
des Gewinns (2,756 → 1,088) steht davon unberührt, die feine Aufteilung nicht.

**Die verifizierbare Umschaltung gibt es jetzt als Befehl** (Commit `f94c3f0`):

```
/rns-bus-skip 1     -- Abkürzung aus
/rns-bus-skip 20    -- Abkürzung an (Vorgabe)
```

Der Befehl setzt den Wert **und liest ihn zurück**, und er nullt die Zähler der
Busse, damit zwei Läufe über dasselbe Fenster vergleichbar sind. Das ist die
fehlende Prüfung: Ein Konsolen-Ausdruck auf `Constants.Settings` wurde nie belegt.
**Für die Zuordnung ist er nicht mehr nötig** — die Zählung trägt sie. Er bleibt
als Werkzeug für den Fall, dass ein späterer Eingriff wieder eine Umschaltung
braucht.

### 6.12 Der Lastregler — und der erste Lauf, der nichts gemessen hat

Die Praxis-Frage aus 6.11 lässt sich **nicht** mit dem bisherigen Aufbau beantworten:
Dessen Container ändern sich nie, der Bus liest also nie etwas Neues. Und ein
echter Verbraucher (Inserter, Maschine) hätte eine ungenaue Rate. Deshalb ein
dosierter Abfluss mit exakter Rate:

```
/rns-stress-drain <itemsProSekundeProContainer>   -- 0 schaltet ab
/rns-stress-drain-status
```

Der Befehl setzt die Rate, **nullt die Zähler** der Busse — damit ist
`busSkips=` danach eine Fenstermessung — und entnimmt dann jeden Tick so viele
Items aus den Containern, dass die Rate pro Container stimmt. Round-Robin, damit
die Verteilung gleichmäßig ist. Der Tick-Handler steht in `control.lua` und kehrt
sofort zurück, solange die Rate 0 ist; **er überlebt ein Save/Load, die Rate
nicht** — die ist eine lokale Variable der Datei. Der Befehl muss nach dem Laden
erneut laufen.

**Der erste Lauf hat nichts gemessen, und der Grund lag bei mir.** Fenster über
5.882 Ticks:

| Größe | Wert |
|---|---|
| Ticks | 5.882 |
| Erwartete Sweeps (2 Busse × 5.882 / 5) | 2.352 |
| Gezählt | **2.352** (2.620 − 268) |
| Nicht übersprungen | **116** |
| Erzwungene Vollläufe (2.352 / 20) | **117,6** |

Nicht übersprungen (116) ≤ erzwungen (117,6): **es gab praktisch keinen einzigen
Treffer.** Das ist exakt der Fall `r = 0` — und derselbe Wert wie im Lauf ohne
jeden Abfluss (95 % Überspringungen).

**Die Ursache: Der Regler war nicht scharf.** Die Container-Liste wurde in
`StressTest.build` festgehalten, und der gemessene Spielstand stammt aus der Zeit
**vor** diesem Code. Ohne Liste kehrte `tick` an seiner Schutzprüfung um. Der
Abfluss lief nie.

**Behoben (Commit `552e783`):** Die Liste wird jetzt in `setDrain` **gesucht** —
die Entity-Tabelle nach External-Bussen durchgehen, deren fokussierte Container
nehmen und das Item aus dem ersten Container lesen. Das funktioniert auf jedem
Spielstand, auch einem, der mit einer älteren Fassung dieser Datei gebaut wurde.
Der Build schreibt die Liste nicht mehr, es gibt also nur eine Quelle.

**Der Fehlermodus ist es, der zählt:** Ein Werkzeug, das still nichts tut, liefert
eine Messung, die wie ein sauberer Null-Effekt aussieht. Das ist in dieser Sitzung
**das zweite Mal**, dass ein stiller Nichts-Tun als Befund durchgegangen wäre —
beim ersten Mal war es die Konsolenzuweisung von `Rescan`. Deshalb meldet der
Befehl jetzt selbst, wie viele Container er gefunden hat und welches Item er
entnimmt.

**Die erwartete Kurve.** Der Bus liest `RNS_ExternalStorage_Tick` = 5, also `L` = 12
mal pro Sekunde. Ändert sich die Gesamtzahl mit Rate `r` pro Container:

```
Trefferquote = 1 - exp(-r / L)
```

| `r` pro Container | Treffer | Übersprungen |
|---|---|---|
| 0 | 0 % | 95 % |
| 0,5 Items/s | 4 % | 91 % |
| 1 Items/s | 8 % | 87 % |
| 4 Items/s | 28 % | 67 % |
| 8,3 Items/s | 50 % | 45 % |
| 12 Items/s | 63 % | 32 % |

**Die Kipprate liegt bei `L` × ln 2 ≈ 8,3 Items/s pro Container.**

Das ist eine Rechnung, keine Messung. Der Lauf in 6.13 prüft sie.

### 6.13 Der Abfluss läuft — und der Container füllt sich nach

Zweiter Lauf, Regler auf 1 Item/s pro Container, 20 Container. Fenster 6.917 →
13.983, also 7.066 Ticks:

| Größe | Wert |
|---|---|
| Erwartete Sweeps (2 × 7.066 / 5) | 2.826 |
| Gezählt | **2.826** (4.424 − 1.598) |
| Nicht übersprungen | **236** |
| Erzwungene Vollläufe (2.826 / 20) | 141 |
| **Treffer** | **95** |
| **Trefferquote** | **3,4 %** |

**Erwartet waren 8,3 %** (`1 - exp(-1/12)`). Gemessen 3,4 %, also 40 % der
Rechnung. Aber das ist nicht die interessanteste Zahl dieses Laufs.

**Die Buchhaltung schließt exakt.** `tracked` fällt um 4.800, und:

```
drives 254.964 → 250.400      −4.564
Container 9.466 → 9.230         −236
                             ─────────
                              −4.800
```

Die zwei Zahlen addieren sich auf die dritte. Und `external` geht von 96 auf 94
**Slots** — 2 Slots à 100 Items plus 36 aus einem dritten ergeben 236. Der Abfluss
entnimmt also aus dem jeweils ersten passenden Stapel und leert Slots der Reihe
nach. Das passt auf den Item genau.

**Und jetzt der Befund: Der Container hat längst nicht so viel verloren, wie der
Abfluss entnommen hat.** Beim Statusaufruf kurz nach dem Start stand `removed=667`.
Die Container waren zu diesem Zeitpunkt von 9.600 auf höchstens 9.466 gefallen,
hatten also rund **134** verloren. **Mindestens 533 Items sind zurückgeflossen.**

**Der Verdacht aus 6.13 ist damit bestätigt, nicht mehr nur ein Verdacht.** Der
External-Bus steht auf `io = "input/output"` (`ExternalIO.lua:18`) — er liest den
Container **und schreibt in ihn**. In diesem Aufbau ist er der einzige Verbraucher
*und* der einzige Lieferant, und er liefert schneller nach, als der Abfluss
entnimmt (bis zu 1 Item pro eigenem Tick = 12/s gegen 1/s Abfluss). Der Container
steht deshalb praktisch voll, seine Gesamtzahl ändert sich selten, und die
Abkürzung greift seltener als das reine Abflussmodell sagt.

**Warum das kein Messfehler, sondern ein Aufbaumerkmal ist:** Der Aufbau misst
einen External-Bus, der sich selbst versorgt. In einer echten Anlage sind
Verbraucher und Lieferant **verschiedene** Dinge mit verschiedenen Raten. Die
3,4 % gelten also für diesen Sonderfall, nicht für die Praxis. **Die Kurve aus 6.13
bleibt gültig** — sie gilt für einen Container, dessen Gesamtzahl sich mit `r`
ändert, und genau das stellt der Abfluss nur dann her, wenn niemand nachfüllt.

**Zwei Nebenbeobachtungen:**

- **`busTruth` Cache ≠ Container** ist jetzt **korrekt**: In einem Dump stand
  `9468/9467`. Mit einem Abfluss läuft der Cache dem Container um bis zu eine
  Entnahmerate × Lesetakt hinterher. Meine frühere Aussage „Cache = Container" gilt
  nur, solange nichts von außen am Container zieht.
- **Die Typenzahl stieg von 16 auf 17**, und `cache` von 16 auf 17. Die Zählung
  wächst nur, weil ein Schlüssel bei 0 stehen bleibt; sie kann nicht sagen, ob ein
  Container einen Typ aufgenommen hat, den der Fill nie hineingelegt hat. Der Dump
  hat deshalb jetzt `busTypes` (Commit `8a3f0de`) — die tatsächlich im Container
  liegenden Typen, aus dem Inventar gelesen.

### 6.14 Der Werkzeugmangel, der den Lauf fast unlesbar gemacht hat

Die 134 gegen 667 konnte ich nur deshalb ausrechnen, weil ich **eine** frühe
Statusausgabe hatte. Über das Messfenster selbst gab es **keine** Angabe zur
entnommenen Menge: `removed` wurde einmal gedruckt und nie wieder.

**Das ist dieselbe Sorte Fehler wie bei der `Rescan`-Zuweisung:** ein Messgerät,
dessen Ablesung nicht mit der Messung reist. Ich habe den Zähler gebaut und ihn
nicht in den Dump gelegt — mit dem Ergebnis, dass ich beim Auswerten nicht sagen
konnte, ob der Regler durchlief oder ob der Container nachgefüllt wurde. Die
Antwort stand in den Daten, aber nur, weil ein einzelner früher Wert übrig war.

**Behoben (Commit `8a3f0de`):** Der Dump-Kopf trägt jetzt den Abflussstand, also
liefert jeder Dump die entnommene Menge mit. Zwei Dumps ergeben die Differenz
direkt.

### 6.15 Weg A: die Rückkopplung ausschalten (Commit `fd76491`)

Der Aufbau konnte die Trefferquote nicht gegen die Kurve prüfen, weil der Bus
seinen eigenen Container nachfüllt. Behebbar über die Richtung: Der fünfte
Parameter von `/rns-stress-build` setzt sie:

```
/rns-stress-build 10 20 4 external input
```

`input` sperrt den Schreibpfad — der Insert-Zweig in
`BaseNet.transfer_from_inv_to_network` verlangt die Zeichenkette `"output"` in
`external.io` — und lässt den Lesepfad offen. Der Container läuft dann nur leer.

**Was dieser Aufbau dann tut:** Das Netz zieht aus den Containern, und die 20
Item-Busse tragen das Gezogene in ihre eigenen Kisten. Damit ist der Fluss
vollständig und einseitig: External-Kiste → Netz → Item-Kiste.

**Und genau daraus folgt eine Einschränkung, die den Lauf betrifft.** Die
Gesamtzahl der External-Container ändert sich jetzt aus **zwei** Quellen: aus dem,
was das Netz zieht, und aus dem Abfluss. Die Rate ist damit **nicht mehr die, die
der Abfluss gesetzt hat**. Die Trefferquote ist deshalb gegen die **aus dem Dump
gemessene** Rate zu prüfen, nicht gegen die eingestellte:

```
gemessene Rate = (busTruth zu Beginn − busTruth am Ende) / Fensterdauer
Trefferquote   = (gesamt − übersprungen − gesamt/20) / gesamt
```

Beide Zahlen stehen im Dump (`busTruth` und `busSkips`), der Abflussstand steht im
Kopf der Datei — die Prüfung ist also aus zwei Dumps allein möglich, ohne
Zusatzannahme.

**Was der Lauf klärt:** ob die Kurve aus 6.12 für einen einseitig leerlaufenden
Container stimmt. **Was er nicht klärt:** ob ein Bus in einer echten Anlage so
beschaltet ist. `both` ist der Vorgabewert der Mod, `input` eine bewusste Wahl des
Spielers.

### 6.16 Was Weg A klären kann, und was nicht

Er liefert die Trefferquote für einen Container, aus dem nur gezogen wird. **Ob ein
Bus in einer echten Anlage so beschaltet ist, klärt er nicht** — `both` ist der
Vorgabewert der Mod, `input` eine Wahl des Spielers. Beide Fälle sind real, und
welcher häufiger vorkommt, kann ich nicht abschätzen.

Für den nächsten echten Eingriff ist die Folgerung davon unabhängig:
**P5-Punkt 1, der Slot-Durchlauf, hilft bei jeder Änderungsrate** — die Abkürzung
nur bei Containern, deren Gesamtzahl sich zwischen zwei Lesungen wirklich ändert.
Sie ist damit die Ergänzung für den Fall „Container ändert sich selten", nicht die
Lösung.

## 7. Offene technische Schulden

Aus dem 1:1-Port bekannt, bewusst nicht angefasst:

- `NetworkBase.addConnectables`, Zeilen 183/186/191: drei Prüfungen mit `and`
  statt `or` (`if x == nil and x.valid == false`). Crash statt sauberer Abbruch
  im Fehlerfall. Zeile 186 prüft `.valid` auf einer Tabelle ohne dieses Feld.
- `Util.fluid_add_list_into_table`: Temperaturmischung falsch gewichtet,
  `v.amount` wird vor der Gewichtung erhöht.
- `ItemDrives.add_or_merge_basic_item`: Munition und Haltbarkeit werden per
  Modulo addiert — halbvolle Magazine werden zu einem Eintrag mit erfundener
  Füllmenge.
- `NC:createArms` übergibt einen String an `order_deconstruction("player")`, in
  2.0 erwartet die Signatur eine ForceID. Ob das still fehlschlägt, ist nicht
  geprüft.
- Beide Select-Icons zeigen auf dieselbe Datei (Tint geht verloren), ein leerer
  vertikaler Balken in der Items-Spalte.
- `RNSPlayer.process_logistic_slots` nutzt entfernte Logistic-Slot-Funktionen,
  gehört zu M5.
- `remove_item_from_interface_cache` (`NetworkBase.lua:550–564`) ist ein
  linearer Scan pro Entnahme. Das ist Plan-Punkt (c) und gehört zu P3.
- Der Verweis auf die Projektnotiz „Analyse Fabrikdurchsatz" in
  `docs/ups-architektur.md` läuft ins Leere: **die Notiz liegt nicht im Repo.**
- `filter_externalIO_by_valid_signal` (`NetworkBase.lua:1340–1355`) baut bei
  jedem Aufruf verschachtelte Tabellen neu auf und ruft `check_focused_entity`
  auf jedem Bus. Seit `10154d6` läuft es nur noch auf dem Tick des jeweiligen
  Busses, aber die Allokation bleibt. Kandidat für P5, wenn der Name nicht mehr
  gebraucht wird — die Prüflogik sitzt jetzt in `updateExternalStorage`.
- `NC:updateExternalStorage` läuft jetzt jeden Tick und iteriert dabei alle
  External-Busse, auch wenn keiner in seiner Phase ist. Bei 40 Bussen ist das
  billig, bei einigen Tausend nicht. Zusammen mit dem Item-Sweep derselbe
  Posten, den P4 mit Zeitschlitzen lösen soll.

## 8. Arbeitsweise

Ein Fehler pro Runde ist normal. Manche Umgebungen brechen beim ersten Problem
ab und zeigen nur eines. Deshalb: die tragfähige Korrektur liefern, statt alles
Vermutete gleichzeitig zu adressieren.

Regeln, die sich in dieser Sitzung als notwendig erwiesen haben:

1. **Lesen vor Ändern.** Zeilennummern und Dateiinhalte nie aus dem Gedächtnis.
2. **Verifizieren vor Auslieferung.** Nach jedem Ersatz die Stelle nachlesen.
   Eine Änderung, die nicht nachgelesen wurde, ist eine offene Flanke.
3. **`repo_replace` mit `expected` statt Regex.** Verweigert die Änderung, wenn
   der Suchstring nicht genau so oft vorkommt. Anker einzeilig wählen: Mehrzeilige
   Suchstrings scheitern an Zeilenumbrüchen.
4. **Kleinster tragfähiger Eingriff.** Gezielter Ersatz mit Ankerzeilen.
5. **Debug-Code gegen fremde Typen braucht Guards.** Die Entity-Tabelle enthält
   auch Player-Objekte, deren `thisEntity` ein `LuaPlayer` ist — jeder
   Key-Zugriff darauf wirft. Controller über `obj.network` identifizieren, nicht
   über `thisEntity`.
6. **`pcall` beim Setzen maskiert falsche Annahmen**, statt sie zu melden.
7. **Kein Erfolg behaupten, der nicht gemessen wurde.**

Fünf Fehlschläge in eigenen Patch-Skripten gingen auf fehlende Verifikation
zurück, keiner auf fehlendes Wissen.

### Sync und Test

Codeänderungen laufen ausschließlich über die `repo_*`-Werkzeuge. Das Repo auf
dem Rechner des Testernutzers ist eine **Nur-Lese-Kopie**; Handarbeit dort
bricht den `--ff-only`-Pull.

Ablauf nach jeder Änderung: commit, push, dann auf der Testseite
`git pull --ff-only` und `rsync` ins Mod-Verzeichnis (zusammengefasst in der
fish-Funktion `rnssync`). Kein Symlink — Factorio folgt Symlinks auf macOS
nicht.

- Reload des Spielstands genügt für Control-Stage-Änderungen (`scripts/`).
- Programmneustart nötig bei Data-Stage-Änderungen (`prototypes/`, `data.lua`).
- Factorio muss exit-clean beendet werden, sonst liest man den alten Log.

Hostnamen, Pfade und Zugangsdaten der Build-Umgebung stehen bewusst **nicht** in
diesem Repo — es wird nach GitHub gepusht.
