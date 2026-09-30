# RNSRedux: Projektstand

Einstiegspunkt für die Weiterarbeit. Technischer Plan und Begründungen:
`docs/ups-architektur.md`. Dieses Dokument beantwortet „wo stehen wir, was ist
verifiziert, was ist der nächste Schritt".

Stand: Commit `e6d6740`, Branch `port/2.0`, Version 2.0.0.

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

## 5. Aktueller Fokus: P1

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

### 5.7 Offene Randpfade

Der Abnahmemaßstab aus Abschnitt 6 des Plans ist erfüllt. Zwei Randpfade der
Änderung `a5add2b` haben noch keine Messung; beide sind billig zu prüfen und
gehören zusammen in einen Lauf:

1. **Austritt.** Dass ein Abbau `shouldRefresh` setzt und der Rebuild das
   Mitglied entfernt. Das ist der Teil von P1, der vorher durch den Takt gedeckt
   war und es nicht mehr ist. Prüfung: `/rns-debug-nc`, einen Drive abbauen
   (`/rns-debug-nc` → `members` muss um eins fallen), dann
   `/rns-debug-refresh` und erneut `members`.
2. **Entnahme** (`NetworkBase.lua:888`). Beide Richtungen buchen getrennt; ein
   Fehler in einer Richtung bleibt sonst unsichtbar. Prüfung wie oben, Items aus
   dem NII zurück ins Inventar.

Nicht geprüft und bewusst offen: Save/Load mit einem Transfer dazwischen. Der
Wert in `storage` übersteht den Ladezyklus, weil `DataConvert` für Blueprints
greift und die Objekte ansonsten unverändert in `storage` liegen — aber das ist
gelesen, nicht gemessen.

Danach ist der IO-Bus der nächste Posten (Abschnitt 6, offene Reihenfolge in
`docs/ups-architektur.md` Abschnitt 6a).

## 6. Der IO-Bus (vermuteter Hauptposten)

Der IO-Bus ist die einzige Kostenquelle, die dauerhaft und vielfach pro Sekunde
anfällt. Der Refresh-Posten im Dauerbetrieb ist seit `a5add2b` entfallen; er
fällt nur noch bei Strukturänderungen an.

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

Blocker: Der Stresstest baut keine IO-Busse, der Pfad ist also nicht messbar.
Vor jedem Umbau steht die Erweiterung des Stresstests.

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
