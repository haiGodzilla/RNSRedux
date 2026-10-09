# RNSRedux: Befunde

Tracker für konkrete Fehler und offene Punkte. Technische Begründungen stehen in
`docs/projektstand.md` und `docs/ups-architektur.md`; hier steht **was offen ist und
wie es belegt wird**.

**Wie ein Fund hier hereinkommt.** Andres Mac-Kopie ist nur lesbar, Änderungen laufen
über den Agenten. Also: im Chat melden, der Agent trägt ein. Pro Meldung reichen
fünf Angaben:

1. **Was hast du getan** — der Schritt, nicht die Absicht.
2. **Was hast du erwartet.**
3. **Was ist passiert.**
4. **Wiederholbar?** Immer bei derselben Aktion / einmalig / nach Neuladen weg.
5. **Beleg** — Logzeile, Dump-Wert oder Screenshot-Wert. Bei Zahlen immer den
   Dump, nicht die Anzeige.

**Status-Werte:**

| Status | Bedeutung |
|---|---|
| `offen` | bestätigt oder plausibel, nicht behoben |
| `ungemessen` | Code ist da, Verhalten nicht geprüft |
| `wartet auf Test` | behoben oder gebaut, Test steht aus |
| `behoben` | behoben **und** getestet |
| `kein Fehler` | nachgerechnet oder gemessen, unkritisch |

Stand: Commit `bc4ae48` (09.10.2026), Branch `port/2.0`, Version 2.0.0. Der
Maßnahmen-Stack (B-23 bis B-38) und die Behebung des Reviews (B-42 bis B-53, dazu
B-54) sind committet und statisch geprüft; die erste Runde Spielbetrieb lief am
08.10.2026 (`projektstand.md` §9.2) und fand B-55. Die Reihenfolge ist keine
Priorisierung; die Kritikalität steht unten.

**Kritikalität.** Jeder offene und jeder noch ungetestete Punkt trägt eine der vier
Stufen. Sie steuert die Reihenfolge der Arbeit, nicht den Status.

| Stufe | Bedeutung |
|---|---|
| `kritisch` | Datenverlust, Absturz oder Release-Blocker; vor dem Merge |
| `hoch` | betrifft ein Release-Objekt oder die Buchhaltung spürbar |
| `mittel` | relevant, aber mit Ausweichweg oder auf einen Fall begrenzt |
| `niedrig` | kosmetisch oder Randeffekt |

| ID | Stufe | Kurzbegründung |
|---|---|---|
| B-05 | `hoch` | fremde Force kann ein Netz anzapfen oder stilllegen |
| B-32 | `hoch` | Buchungsfehler im Netz |
| B-43 | `hoch` | Buchhaltung driftet nach einem Reset |
| B-46 | `hoch` | Drive-Priorität aus Blueprint bricht Refresh |
| B-21 | `mittel` | Footprint/Grid, berührt bestehende Saves |
| B-27 | `mittel` | Lücken im Slot-Cache |
| B-29 | `mittel` | Multiplayer, entfernter Spieler |
| B-31 | `mittel` | MP: Debug-Befehle, Desync |
| B-36 | `mittel` | M5-Techs in bestehenden Saves |
| B-40 | `mittel` | Store-Leck/Lifecycle bei Plattform und Klon |
| B-45 | `mittel` | Tick-Allokation im Buspfad |
| B-47 | `mittel` | Item-IO an Generator |
| B-48 | `mittel` | Fluid-Cache nil-Guard |
| B-49 | `mittel` | Munition/Haltbarkeit beim Teil-Export |
| B-57 | `mittel` | nur Maschinen mit mehreren Output-Inventaren |
| B-61 | `mittel` | NII öffnet zusätzlich Charakter-/Containerfenster |
| B-01 | `niedrig` | Anzeige (Hover 0/0); Behebung an B-21 gekoppelt |
| B-02 | `niedrig` | Savegröße/Bauzeit, nicht Ticks |
| B-04 | `niedrig` | Temperaturanzeige im NII |
| B-06 | `niedrig` | Grafik-Tönung |
| B-07 | `niedrig` | offene Messung |
| B-08 | `niedrig` | Allokation im Buspfad |
| B-09 | `niedrig` | gehört zu P4 |
| B-10 | `niedrig` | toter Doku-Verweis |
| B-22 | `niedrig` | Schatten-Skalierung |
| B-33 | `niedrig` | Grafik/Prüfflächen |
| B-34 | `niedrig` | Tech-Icons |
| B-35 | `niedrig` | Rezept-Zutat |
| B-37 | `niedrig` | französische Locale |
| B-38 | `niedrig` | Wartung |
| B-41 | `niedrig` | M5-Umfang |
| B-50 | `niedrig` | Mess-Overrides |
| B-51 | `niedrig` | Changelog-Text |
| B-52 | `niedrig` | doppelte Mechanik |
| B-56 | `niedrig` | IO-Bus am Drill |
| B-60 | `niedrig` | NII-Flackern, reine Anzeige |

Geschlossene Punkte (Abschnitte 3 und 4) führen keine Kritikalität. Wird ein Punkt
geschlossen, fällt er aus dieser Tabelle.

## 1. Offen

| ID | Bereich | Befund | Status | Beleg |
|---|---|---|---|---|
| B-01 | Anzeige | Hover über einen platzierten Drive zeigt `Storage: 0/0`, der Klick die richtige Füllung (61 Items im Drive, Screenshot). Die Zeile stammt **nicht** aus der Mod: der einzige Mod-Text mit diesem Wort ist `item-description.RNS_DriveTag_Storage`, und der wird nur am **geminten Item** gesetzt — als Teil einer vierzeiligen Beschreibung mit Filters, Priority und Mode, die im Screenshot alle fehlen. `Storage` und `Last user` kommen im ganzen Repo nicht vor. Angezeigt wird also das Inventar des `container` mit `inventory_size = 0` (7.20), jetzt mit Beleg. **Behebung, jetzt recherchiert:** 2.0 kennt `Prototype::custom_tooltip_fields`, das **ergänzt** Einträge, entfernt aber keine — und die Runtime-Felder (`LuaEntity::set_tooltip_field`) kommen erst mit 2.1. In 2.0 bleibt damit nur ein anderer Entity-Typ (wie die IO-Busse als `assembling-machine` und der Controller als `electric-energy-interface`). Data-Stage, berührt Öffnen, Minen und Blueprint; **Korrektur 08.10.2026:** nicht unabhängig von B-21 — ein Typwechsel des Drive-Prototyps löscht platzierte Drives beim Laden und lässt ihre Store-Inventare verwaist (starke Hypothese: Prototypen sind über Typ und Name identifiziert). B-21 bricht bestehende Saves bereits über die Geometrie; den Bruch nur einmal machen, also B-01 im selben Release wie B-21 entscheiden. Nicht vorziehen. | `offen` | 7.20, Screenshots, API-Doku 2.0.72 |
| B-02 | ItemStore | `CHUNK_INITIAL = 1024` unabhängig von der Größe; ein 4k-Drive braucht 40 Slots, bekommt 1024. Kostet Savegröße und Bauzeit, **nicht Ticks** — `is_full` läuft über den geführten Zähler. | `offen` | 7.15 |
| B-05 | Netzwerk | **Korrigiert:** kein Typfehler — `ForceID` ist in 2.0 `string \| uint8 \| LuaForce` (API 2.0.75). Offen bleibt, dass `order_deconstruction("player")` (`NetworkBase.lua:195`, `NetworkController.lua`, `TransReceiver.lua:127`) die Force fest einträgt, und dass die Konnektivität (`generateArms`, `postArms`, `join_network`) keine Force prüft: eine fremde Force kann ein Netz anzapfen oder per zweitem Controller stilllegen. Fix: `ent.force == self.thisEntity.force` prüfen, Force der Entity übergeben. | `offen` | API 2.0.75, Analyse F-22 |
| B-06 | Grafik | Beide Select-Signale zeigen auf dieselbe Datei, die Tönung geht verloren. Gemessen im Log: `RNS_select_icon_black icon -> __core__/graphics/icons/mip/select-icon.png` und `..._white ->` **dieselbe** Datei — in 2.0 tragen beide `utility-sprites`-Felder denselben Dateinamen, und `data-final-fixes.lua:91–100` übernimmt nur den Namen. Der zweite Teil des alten Eintrags (leerer vertikaler Balken) ließ sich nicht wiederfinden und ist gestrichen. | `offen` | `factorio-current.log`, Andre |
| B-07 | Messung | Eine Zerlegung geht um 0,21 ms nicht auf; die 9 % Mehrkosten aus 6.6 haben keine Ursache. Möglicherweise derselbe Posten. | `offen` | 6.11, 6.12 |
| B-08 | Performance | `filter_externalIO_by_valid_signal` baut bei jedem Aufruf verschachtelte Tabellen neu auf. Läuft seit `10154d6` nur noch auf dem Tick des Busses, die Allokation bleibt. | `offen` | `NetworkBase.lua:1340` |
| B-09 | Performance | `NC:updateExternalStorage` läuft jeden Tick und iteriert alle External-Busse, auch wenn keiner in seiner Phase ist. Bei 40 Bussen billig, bei einigen Tausend nicht. | `offen`, gehört zu P4 | `NetworkController.lua:175` |
| B-10 | Dokumentation | Der Verweis auf die Projektnotiz „Analyse Fabrikdurchsatz" läuft ins Leere — die Notiz liegt nicht im Repo. | `offen` | `ups-architektur.md` Abschnitt 10 |
| B-22 | Grafik | Der Schatten des Drives ist **doppelt so groß wie der Körper**: beide Bilder sind auf 128 Bildpixel pro Feld gemalt (Körper 258 px auf `scale 1/4`, Schatten 255 px auf `scale 1/2`), der Schatten deckt damit 3,98 statt 1,99 Felder. Nicht der Versatz ist falsch, die Skalierung; bei `1/4` läge er mit `shift = {0,0}` mittig unter dem Sockel. Beim Controller ist das Schattenbild zusätzlich am eigenen Rand abgeschnitten (bemalte Fläche endet auf `x = 511`). Probe `5189eea` **zurückgenommen** (`8ee251d`) — sie hatte nur den Versatz geändert. Mit dem neuen Footprint ist der Versatz auf `{1,0.016}` nachgeführt, damit der Abstand zum Körper derselbe bleibt. Kosmetisch, eigener Schritt nach B-21. | `offen` | 9.1 |
| B-40 | Lifecycle | Nicht registriert: `on_space_platform_built_entity`, `on_space_platform_mined_entity` (Drive auf einer Plattform bekommt kein Objekt, Store-Leck beim Abbau). `Event.placed` verwirft Entities mit `last_user == nil` (Skript-Bau anderer Mods). `on_entity_cloned` erzeugt ein leeres Doppelobjekt. | `offen` | Analyse F-26 |
| B-41 | Blueprint | `onBlueprintConfigured` tut nie, was es soll (iteriert die Tag-Tabelle statt index→unit_number); TransReceiver/WirelessGrid serialisieren `connection` als rohe `unit_number`, kopierte Paare verbinden sich mit den Originalen. M5-Umfang. | `offen` | Analyse F-28 |
| B-56 | IO-Bus | **Altbestand aus 1.1, offen.** `RNS_Inventory_Types["mining-drill"]` ist vorhanden (Input `fuel`, Output `burnt_result` + `chest`), `RNS_TypesWithContainer["mining-drill"]` fehlte; `reset_focused_entity` verlangt beides. Ein Testlauf mit ergänztem Gate (`["mining-drill"] = true`) hat den Bus den Drill **trotzdem nicht** anfassen lassen — nur Miner → Kiste → Bus funktioniert. **Nächster Verdacht:** Das Output-Inventar des elektrischen Drills ist über den Index nicht erreichbar (`fuel`/`chest` kollidieren auf Index 1, Burner unscharf); `LuaEntity::get_output_inventory()` ist der saubere Zugang. Der Gate-Eintrag ist wieder entfernt, damit kein ungeprüfter halber Zustand bleibt. Die Item-Beschreibung verspricht „chest or machine". | `offen` | Test, Andre, 09.10.2026; API 2.0.75; `upstream-1.0.43` |
| B-57 | External-Bus | **Rest aus B-39.** `init_cache` und `update` führen **einen** slot-indizierten Cache über alle Output-Inventare. Maschinen mit mehreren Outputs (Steinofen: `burnt_result` + `furnace_result`; Burner-Assembler: Output + `burnt_result`) überschreiben sich darin, sichtbar bleibt nur das zuletzt gelesene. Niedrige Sichtbarkeit, weil `burnt_result` selten gefüllt ist. Fix: ein Cache pro Inventar (größerer Umbau). | `offen` | B-39, Analyse F-15 |
| B-60 | Anzeige/NII | **Bestätigt, Ursache offen.** Im NII verschwinden beim manuellen Hinzufügen eines **neuen Item-Typs** (Holzkiste) bestehende Einträge (Eisenplatten) für einen Sekundenbruchteil; wird die Kiste hinzugefügt und danach per IO-Bus exportiert, dasselbe. Der Stapel kommt identisch zurück, die Buchhaltung ist also vermutlich intakt. `/rns-debug` ist im Fenster nicht ausführbar (zu kurz). `interfaceCache.item` ist name-indiziert; Verdacht: `createNetworkInventory` baut die Button-Liste beim Reorder kurz falsch. Nächster Schritt: ein temporärer Persistenz-Log (Namenssatz + Zähler bei jeder Änderung) statt Momentaufnahme. | `offen` | Test, Andre, 09.10.2026 |
| B-43 | Buchhaltung | **Wieder offen (Test gefallen).** `reset_focused_entity` auf dieselbe Entity bucht per `flush_cache` aus, `inject_cache` sollte wieder einbuchen (Fix mit B-42). Im Spiel fällt der External-Bus nach einem **Moduswechsel** aus: der danach anfahrende Waggon wird nicht ausgeladen, `busTruth=0/0/0` in allen Netzen — der Bus steckt also nicht mehr in den Büchern oder hat keinen Fokus. Genau die Stelle, an der `inject_cache` greifen sollte. | `offen` | Test 2, Andre, 09.10.2026 |
| B-61 | GUI | **Neu.** Beim Öffnen des NII öffnen sich zusätzlich die Vanilla-Fenster (Charakter, persönliche Logistik, Container). `GUI.open_relative_tooltip_gui` setzt `player.opened = player` (Zeile 90), was den Charakterschirm öffnet. Gewünscht ist nur die Mod-Oberfläche, die das Inventar ohnehin zeigt. | `offen` | Test, Andre, 09.10.2026 |

## 2. Behoben, Test steht aus

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-21 | Grafik | Drive und Controller sind jetzt **2 × 3** bzw. **3 × 4** Felder groß (vorher 2 × 2 und 3 × 3), Kollision 1,8 × 2,8 bzw. 2,8 × 3,8. Gemessen mit `tools/png_bbox.py`: Kunst 2,016 × 2,836 bzw. 2,834 × 3,999 Felder, jeweils mit der Unterkante auf der Unterkante des Footprints. Drive unverändert `scale = 1/4` mit `shift = {0,0.21875}`; Controller `scale = 180/512` statt `192/512` (6,25 % kleiner, sonst passt seine 4,27 Felder hohe Kunst nicht in vier) mit `shift = {0,0.5828}`. **Ungemessen:** ob die acht Drive-Bilder (vier Item-, vier Fluid-Stufe) dieselbe Unterkante im Canvas tragen — die Werte stammen von `ItemDrive4E.png`. **Und ungemessen:** beide Entities wechseln die Gitterlage in y, siehe 9.1. | `wartet auf Test` | 9.1 |
| B-04 | Fluide | `Util.fluid_add_list_into_table` gewichtete die alte Temperatur mit der neuen Gesamtmenge (`v.amount` wurde vorher erhöht): 100@15 + 100@165 ergab 65 statt 90. Jetzt mit den Mengen vor dem Zusammenführen, Default-Temperatur abgesichert. Nur Anzeige (NII). | `wartet auf Test` | Analyse |
| B-27 | Lifecycle | `EIO:validate` (läuft bei jedem `on_configuration_changed`) löschte die `RNS_Empty`-Platzhalter, weil sie kein Prototyp sind — Löcher im Slot-Cache, Folgefehler im Sweep. Jetzt übersprungen; Items mit entferntem Prototyp werden zum Platzhalter statt `nil`. | `wartet auf Test` | Test: Mod hinzufügen/entfernen, External-Bus an Kiste mit Lücken beobachten |
| B-29 | Spieler | `RNSP:valid()` lieferte immer `true`; ein entfernter Spieler warf in jedem Tick, der Fehlerzweig in `updates.lua` las den Namen außerhalb von `safeCall` und brach die Schleife für alle Controller ab. Spieler-Objekte standen unter der Spielernummer in `entityTable`/`updateTable` (Schlüsselraum der `unit_number`). Jetzt: echtes `valid()`, `on_player_removed`, Schlüssel `"player-<index>"`, nicht mehr in `entityTable`; Altbestand wird in `onInit`/`on_configuration_changed` umgeschrieben. | `wartet auf Test` | Test (MP): Spieler offline, `game.remove_offline_players()` — Netze laufen weiter |
| B-31 | Multiplayer | Debug-/Stress-Befehle ohne Admin-Prüfung (Plündern, Items erzeugen, Entities löschen, Einfrieren per Drain-Rate). Zustand außerhalb von `storage` (StressTest-Drain, `Constants`-Überschreibungen der Bus-Befehle) desynchronisiert beitretende Clients. Jetzt: `debugCommand` (Admin im MP, `safeCall`), Zustand in `storage.stressTest`/`storage.debugOverrides`, Obergrenzen, `write_file` nur für den Auslöser. | `wartet auf Test` | Test (MP): Nicht-Admin `/rns-stress-fill 1 1` — keine Wirkung |
| B-32 | Netzwerk | Kleine Buchungsfehler: `remove_item_from_interface_cache` entfernte über zwei Einträge zu viel; `table.remove`/`insert` in `pairs` übersprang Busse und ließ andere doppelt laufen (jetzt `runBusList`); Prioritätswechsel griffen erst nach Refresh (`.valid == true` auf einer Methode) — jetzt Refresh; `network:exists_in_network` war immer `false`; IO-Moduswechsel konnte Busse doppelt eintragen. | `wartet auf Test` | `/rns-debug` gegen `/rns-debug-refresh` |
| B-33 | Grafik | Folgen von B-21: Prüfflächen von Drive und Controller (`getCheckArea`) passten noch zu 2 × 2/3 × 3 und überlappten die eigene Kollisionsbox; Filter-Icons des Drives (+0,48828 Felder) und Status-Overlay des Controllers (Shift `{0,0.5828}`, `scale 270/512`) waren nicht mitgewandert; Controller jetzt `not-rotatable`. | `wartet auf Test` | Test auf Kopie: Kabel an alle Seiten, Optik der Overlays, Drehen |
| B-34 | Grafik | Tech-Icons mit `icons`: 2.0 liest das oberste `icon_size` nur zusammen mit `icon`, der Layer fiel auf 64 zurück (Bilder sind 512 px). Jetzt `icon_size` pro Layer. | `wartet auf Test` | Test: Tech-Baum, Bonus-Techs |
| B-35 | Rezepte | Fluid-Drives verlangten `empty-barrel`, das in 2.0 vermutlich `barrel` heißt — der Ersatz durch Stahl griff dann immer. Jetzt `barrel`, abgesichert durch einen Ersatzeintrag. Die Umbenennung ist nicht gegen eine Installation geprüft. | `wartet auf Test` | Logzeile `barrel -> steel-plate` darf **nicht** erscheinen |
| B-36 | Umfang | Wireless, Player Port, Transmitter/Receiver und Detector waren erforschbar, obwohl M5. Techs jetzt `enabled = false` (`deferredToM5` in `prototypes/Technologies.lua`), Reichweiten-Boni mit. Der Player Port nutzt jetzt `get_requester_point().filters` statt der entfernten Slot-API. **Einschränkung (Review 08.10.2026):** `LuaTechnology.enabled` ist Laufzeitzustand pro Force (API 2.0.75) und wird im Save geführt; in **bestehenden** Saves bleiben die M5-Techs daher vermutlich erforschbar, nicht nur bereits erforschte. Fix: in `on_configuration_changed` die nicht erforschten M5-Techs pro Force auf `enabled = false` setzen. Zusätzlicher Testfall: alter Save. Nachtrag: in `onInit`/`on_configuration_changed` werden nicht erforschte M5-Techs pro Force gesperrt und vorher aus der Forschungs-Warteschlange genommen (`LuaForce.research_queue`, API 2.0.75); die Liste liegt jetzt in `Constants.DeferredToM5` (beide Stages). Ob 2.0 eine bereits laufende Forschung beim Neuschreiben der Warteschlange sauber abbricht, ist nur im Spiel prüfbar. | `wartet auf Test` | Test: neues Spiel, Tech-Baum|
| B-37 | Texte | Französisch: 32 fehlende Schlüssel ergänzt (u. a. die drei IO-Busse, Controller, Fehlermeldungen, zwei Setting-Beschreibungen). | `wartet auf Test` | `locale.py`: fr fehlt 0 |
| B-38 | Wartung | Upstream-Migrationen 1.0.x gelöscht: Laut Entscheidung kein Migrationspfad, und sie griffen auf `entry.storageArray` zu, das es seit P2 nicht mehr gibt. | `wartet auf Test` | Mod zu bestehendem Save hinzufügen, Log prüfen |
| B-45 | Performance | **Regression aus dem Stack.** `runBusList` (`NetworkController.lua`) legt pro Prioritätsliste und Aufruf zwei Tabellen an und liest `settings.global` — auch für leere Listen, 11 Prioritäten × Item-Listen jeden Tick, Fluid alle 5 Ticks; im Aufbau `20 50` grob 1.000 Tabellen und 500 Engine-Aufrufe pro Tick, HEAD: 0. Dazu `EIO.fastScanEnabled()` einmal **pro Slot** im inneren Sweep (`ExternalIO.lua`, Funktionsaufruf plus `storage`-Lookup im gemessen teuersten Pfad). Fix: `if list[1] == nil then return list end`, Liste nur neu bauen, wenn sich etwas bewegt hat, Round-Robin einmal pro `NC:update` lesen; `fastScanEnabled()`/`rescanPeriod()` einmal vor der Schleife. Danach 4.2 neu messen. **Vor dem Merge beheben.** **Umgesetzt:** `runBusList` gibt leere oder unveränderte Listen ohne Allokation zurück, Round-Robin einmal pro Aufruf; `fastScanEnabled()` einmal pro Sweep. | `wartet auf Test` | Review 08.10.2026|
| B-46 | Blueprint | `ID:deserialize_settings`/`FD:deserialize_settings` übernehmen `priority` und `whitelistBlacklist` ungeprüft (`ItemDrives.lua:119-120`, `FluidDrives.lua:119-120`); eine Priorität außerhalb ±5 indiziert eine nicht vorhandene Tabelle in `addConnectables` (`NetworkBase.lua:204/217`) und bricht jeden Refresh des Netzes ab. Gleiche Fehlerklasse wie B-30, aber beim wichtigsten Release-Objekt. Filter-Namen nur typgeprüft (unbekannter Name → Sprite `item/<name>`, ob das wirft: Hypothese). Fix: `Util.tagPriority`/`tagChoice`/`tagPrototypeName`. **Umgesetzt:** Priorität, Modus und Filter der Drives über `Util.tag*`, `filters` aus den geprüften `guiFilters` neu gebaut. | `wartet auf Test` | Review 08.10.2026 (api-contract); im GUI nur −5…5 einstellbar, ein 99er-Wert entsteht nur per Hand im Blueprint-String |
| B-47 | Item-Bus | `IIO3:reset_focused_entity` indiziert `RNS_Inventory_Types[nearest.type]` ohne den Guard aus B-28 (`ItemIOV3.lua` ~608): ein Item-IO vor einem Generator wirft weiterhin. Fix: derselbe Guard. **Umgesetzt:** derselbe Guard im Item-IO. | `wartet auf Test` | Review 08.10.2026|
| B-48 | Fluide | `remove_fluid_from_interface_cache` ruft `pairs` auf `interfaceCache.fluid[name]` ohne nil-Guard (die Item-Variante hat ihn seit B-32). Erreichbar über `flush_cache` und den Delta-Pfad in `EIO:update` für ein Fluid, das nie gebucht wurde (z. B. nach B-43). Fix: Guard wie bei Items. **Umgesetzt:** nil-Guard. | `wartet auf Test` | Review 08.10.2026|
| B-49 | Items | Beim Teil-Insert legt `extract_item_from_drive` den Rest als Kopie des **ersten** Stapels zurück; dessen Munition/Haltbarkeit gilt dann für den ganzen Rest (9 volle + 1 angebrochenes Magazin → nach Teil-Export 8 volle + 2 angebrochene). Kein Itemverlust mehr, aber Munition/Haltbarkeit nicht erhalten. Fix: vor dem Entnehmen `inv.get_insertable_count` (API 2.0.75) begrenzen und den Rücklauf ganz vermeiden. **Umgesetzt:** Entnahme vorab auf `get_insertable_count` begrenzt, wenn die Schätzung > 0 ist; der Rücklauf bleibt als Absicherung für ungenaue Schätzungen. | `wartet auf Test` | Review 08.10.2026|
| B-50 | Messung | `storage.debugOverrides` und `storage.stressTest` überleben jetzt Save/Load (gewollt, gegen Desync) — aber nichts setzt sie zurück, `rescanPeriod` steht in keinem Dump-Kopf, und `ups-architektur.md` §9 sagte das Gegenteil (korrigiert). Ein vergessenes `/rns-bus-skip 1` oder eine laufende Drain-Rate verfälscht spätere Läufe und landet im echten Save. Fix: alle Overrides im Kopf von `/rns-debug-nc`, Reset-Befehl, in `on_configuration_changed` leeren. **Umgesetzt:** Dump-Kopf zeigt `rescan` und `(OVERRIDE)`, neuer Befehl `/rns-debug-reset`, Leeren in `onInit`. | `wartet auf Test` | Review 08.10.2026|
| B-51 | Prozess | `changelog.txt` 2.0.0 führt die Stack-Fixes als erledigte Bugfixes, obwohl alle `wartet auf Test` sind (Hausregel: kein Erfolg ohne Messung); „not researchable yet“ gilt für bestehende Saves nicht (B-36); `Date:` fehlt. Fix: Bugfix-Zeilen erst nach dem Test übernehmen, bis dahin als ungetestet kennzeichnen. **Umgesetzt:** `Info`-Zeile im Changelog kennzeichnet die Bugfixes als ungetestet. | `wartet auf Test` | Review 08.10.2026|
| B-52 | Wartung | Doppelte Mechanismen nach dem Stack: `transfer_io_mode` fügt vor dem Refresh von Hand ein (`ItemIOV3.lua`, `FluidIO.lua`; `obj.processed and nil or 1` ergibt immer 1), und der Typwechsel des External-Busses bucht per `flush_cache` aus, unmittelbar bevor `resetTables` alles neu baut. Totes bzw. doppeltes Werk, das eigene Fehlerpfade mitbringt (B-48). Fix: die Handbuchung entfernen, nur Refresh. **Umgesetzt:** `transfer_io_mode` nur noch für den Detector, IO-Moduswechsel der Item-/Fluid-Busse nur per Refresh. **Korrektur nach dem zweiten Review:** Typ- und Moduswechsel des External-Busses sowie Paste buchen wieder sofort aus (mit altem Typ/Modus) bzw. beim Moduswechsel sofort ein — der Refresh allein ließ ein Fenster, in dem ein Reset Inhalte eines Output-Busses ausbuchte, die nie gebucht waren. `EIO:validate` zieht für Items einen Slot statt der Stückzahl ab (Bedeutung von `storedAmount` seit `init_cache`-Korrektur). | `wartet auf Test` | Review 08.10.2026|
## 3. Nachgerechnet, unkritisch

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-12 | NII | Der Sortierschalter ist **nicht** wirkungslos. `GUI.on_gui_clicked` leitet jedes `RNS_NII*`-Element an `NII.interaction` (`Gui.lua:147–150`), und dort steht der `SortOrder`-Zweig (`NetworkInventoryInterface.lua:754`). Der fehlende Zweig in `on_gui_element_changed` war nur der zweite Weg dorthin. Gemessen: Andre sortiert um, in beide Richtungen. | `kein Fehler` | `Gui.lua:147`, Andre |
| B-13 | Netzwerk | `add`/`remove_item_from_interface_cache` sind lineare Scans, aber die Liste hat **einen Eintrag pro Item-Typ** — der Aufteilungszweig greift nur einmal, weil der Rest ein volles Magazin bekommt. Bestätigt durch `cache=16` bei 16 Typen. | `kein Fehler` | 8.3 |
| B-03 | Netzwerk | `addConnectables` Zeilen 183/186/191 prüfen mit `and` statt `or`, sind aber **unerreichbar**: `valid(source)`/`valid(con)` prüfen davor schon `thisEntity ~= nil and .valid`, und `connectedObjs` setzt jede Klasse in `createArms`. Kein Absturzpfad; Code unverändert. | `kein Fehler` | nachgelesen 08.10.2026 |
| B-53 | 2.0-API | Behauptung aus dem Code-Review: `LuaLogisticSection.set_slot` werfe bei einem Signal, das schon in einem anderen Slot steht, und `Util.setCombinatorSignal` zerstöre dann den platzierten Bus. **Widerlegt:** laut API 2.0.75 gibt `set_slot` in diesem Fall den vorhandenen Index zurück und setzt nichts (`classes.d.ts`, `set_slot` @returns). Das Icon erscheint nur einmal; kein Fehlerpfad. | `kein Fehler` | API 2.0.75 |

## 4. Behoben und getestet

| ID | Bereich | Punkt | Beleg |
|---|---|---|---|
| B-11 | NII | Handler-Zweig für `RNS_NII_PInv_*`, die Spielerinventar-Spalte. Gemessen: zwei Dumps um einen Links- und einen Strg-Linksklick, `tracked` 11/4 → 61/5, `truth` behauptet = tatsächlich in beiden. | 5.13, Andre |
| B-18 | Texte | Beschreibungen waren leer oder wiederholten den Namen. Zwei Ursachen: (1) Schlüssel passten nicht auf die Prototyp-Namen — das Netz-Item heißt `RNS_NetworkInventoryInterface` (`constants.lua:900`), die Locale führte `RNS_NetworkInventoryBlock`; dasselbe Muster beim Controller, Wireless Transmitter und den drei IO-Bussen. (2) Die vorhandenen Texte wiederholten den Namen. Behoben: beide Schlüsselformen eingetragen, alle Einträge durch echte Texte ersetzt, Ramp-Items von `order = "a"` auf `"b"`. **Im Spiel angelesen, funktioniert.** Nachtrag `fba2235`: zusätzlich fehlten zwei **entity**-seitige Schlüssel — die Controller-Entity wiederholte den Namen, die Entity des Netz-Knotens hatte gar keine Beschreibung (die Locale führte nur die Altform `..._Block`). Mitgetestet. | `fba2235`, Andre |
| B-14 | Speicherschicht | Drive hielt seinen Inhalt als handserialisierte Lua-Tabelle; Munition und Haltbarkeit per Modulo addiert, Qualität kollabierte. Ersetzt durch Engine-Inventare. | P2, 7.21 |
| B-15 | Platzierung | Ein fremder Entity-Tag setzte `filters` auf `nil`, `regenerate_icons` warf, und `Control.placed` zerstörte den Drive. Jetzt werden alle Felder geprüft. | `535a6d9`, 7.18 |
| B-16 | Platzierung | `on_built_entity` hat in 2.0 kein `stack`-Feld — der Lesepfad war seit der Portierung tot. Ein **per Roboter** gebauter Drive behielt seinen Inhalt, ein von Hand gebauter nicht. Jetzt wird `consumed_items` zusätzlich gelesen. | `8d0a0f8`, 7.17 |
| B-17 | Transfer | P2 ersetzte einen Hash-Zugriff durch eine Engine-Suche über die Chunks, pro Drive und pro Item, im Normalfall erfolglos. Der Index antwortet jetzt zuerst. | `55dccb0`, 8.2 |
| B-19 | Kollision | Die 1×1-Netzteile blockierten den Charakter, weil für RNS-Objekte nie eine `collision_mask` definiert war. Jetzt übernehmen Kabel, Underground-Kabel und die drei IO-Busse die Belt-Maske — gemessen `{water_tile, floor, transport_belt, object, meltable}`, ohne `player`. Getestet: Kabel und Underground-Kabel begehbar, Kiste lässt sich nicht darauf setzen. Die IO-Busse sind nicht einzeln nachgeprüft, benutzen aber dieselbe Maske. | `b697f36` |
| B-20 | Kabel | Underground-Kabel hatte kein Sprite, weil der Prototyp ein Top-Level `animation` setzte, den eine `assembling-machine` nicht liest. Unter `graphics_set` eingerückt. Getestet: Vorschau und Platzierung korrekt. | `b697f36` |
| B-55 | GUI | Filterauswahl an jedem IO-Bus (Item, Fluid, External) und am Detector setzte den Kombinator-Slot mit `min` ≠ 0, aber ohne Qualität; die Engine wertete das als „any quality" und warf `Can't specify non zero request with non trivial item filter condition`, das GUI schloss sich mit „Failed to update GUI". Ursache war `Util.setCombinatorSignal` aus dem Stack; behoben mit `quality = signal.quality or "normal"`. | `ec55cf6`, Andre, 09.10.2026: Filter gesetzt, Items fließen |
| B-39 | External-Bus | `init_cache`, die Zählschleife und `update` lasen `get_inventory(i)` (Position in der Liste) statt `get_inventory(values[i])` (Inventar-ID). An Kisten folgenlos, an **elektrischen** Öfen/Assemblern war Index 1 kein Inventar → `nil` → Wurf in `NC:update`, der auch Item-IO und die übrigen Busse des Netzes abriss. Jetzt `get_inventory(values[i])` mit nil-Prüfung an allen drei Lesestellen. Getestet: External-Bus an einer elektrischen Maschine, Log ohne `RNSRedux error`, übrige Netze laufen. Der Cache pro Inventar bleibt als B-57 offen. | Sofort-Fix im Stack, Andre, 09.10.2026 |
| B-23 | Fluide | Import buchte die Tankmenge pro Drive (Duplikation); External-Insert und Export begrenzten die Quelle nicht bzw. etikettierten/überschrieben fremdes Fluid. Jetzt: Quelle live gelesen, Menge = min(Platz, Bus, Quelle), fremdes Fluid und Fluid-Sperre respektiert. **Gemessen:** Tank 25.000 (Offshore-Pumpe → Rohr → Tank) → Fluid-Drive 25.000, keine Duplikation, kein Verlust. Die Export-/Fremdfluid-Unterseite ist nicht separat gemessen. | `faf01e6`-Umfeld, Andre, 09.10.2026 |
| B-58 | Fluid-Bus | `FIO:IO` stieg ohne Busfilter still aus und verlangte beim Input zusätzlich `self.filter == fluid.name`; ein Fluid-Bus an einem gefüllten Tank tat damit nichts. Jetzt ist der Ausstieg auf `output` beschränkt, und der Input importiert bei leerem Filter jedes Fluid aus dem Tank (`self.filter == "" or self.filter == fluid.name`). Output bleibt filterpflichtig. **Gemessen:** Import ohne Filter läuft. | `faf01e6`, Andre, 09.10.2026 |
| B-42 | Performance | `EIO:reset_focused_entity` löste bei jedem neuen Ziel einen vollen Refresh aus; da Lokomotiven und Waggons als Container zählen, kostete jeder Zug am External-Bus O(Netz). Jetzt bucht `EIO:inject_cache` inkrementell (Spiegelbild von `flush_cache`), kein Refresh bei Simulationsereignissen. | Andre, 09.10.2026: Zug am Bus, kein `max`-Ausschlag |
| B-44 | Buchhaltung | Settings-Paste setzte `io`/`type`/`priority`/`color` direkt, ohne Cache-Ausgleich; jetzt leert `onSettingsPasted` den External-Cache, kopiert, baut die Arme neu und löst den Refresh aus. | Andre, 09.10.2026: Paste überträgt alle Eigenschaften |
| B-54 | Blueprint | `copy_settings` teilte die Enabler-Tabelle zwischen Bussen (eine GUI-Änderung wirkte auf alle); jetzt Kopien (`Util.tagEnabler`, Array-Kopie). | Andre, 09.10.2026: Paste überträgt alle Eigenschaften |
| B-59 | Anzeige | Fluid-Drive-UI zeigte den Rohwert mit allen Nachkommastellen; jetzt `math.floor` an Label, Fortschrittsbalken-Text, Tooltip und Item-Beschreibung, Buchhaltung unverändert. | Andre, 09.10.2026: ganze Zahlen |
| B-24 | Items | Teil-Insert konnte Items verlieren (`extract_item_from_drive` ignorierte das `insert`-Ergebnis; Chunk ohne freien Slot nahm keinen neuen Typ an). Jetzt geht der Rest zurück, gebucht wird die eingefügte Menge. | Andre, 09.10.2026: Kiste mit 99/100 + Bonus, Summe stabil |
| B-25 | 2.0-API | `set_signal` fehlt in 2.0; jeder IO-Bus aus einem Blueprint wurde beim Platzieren zerstört. Jetzt `Util.setCombinatorSignal` über `get_section(1).set_slot`; Schaltkreis liest Rot und Grün getrennt. | Andre, 09.10.2026: Blueprint mit Filter baut korrekt |
| B-26 | Laden | Nach dem Laden fehlte den `interfaceCache`-Einträgen die Metatable; Einlagern eines vorhandenen Items warf bis zum Refresh. Jetzt Reload vor dem Vergleich. | Andre, 09.10.2026: Speichern/Laden, Insert ohne Fehler |
| B-28 | External-Bus | Moduswechsel rief nicht existierende Methoden; Output-Busse buchten Phantombestand; ein neuer Container blieb unsichtbar. Jetzt Refresh bei Modus-/Containerwechsel, Output bucht nur Kapazität. | Andre, 09.10.2026: Moduswechsel, `/rns-debug` = Refresh |
| B-30 | Blueprint | Tags von Bussen/Detector ungeprüft; ein kaputter Blueprint brach jeden Refresh ab. Jetzt `Util.tag*` mit Defaults, Fehlerpfad räumt auf. | Andre, 09.10.2026: Blueprint/Paste mit Filter, kein Fehler |

## 5. Vor dem Release zu erledigen

- Alle Debug-Befehle entfernen und die `port_*.py`-Skripte: `/rns-debug`,
  `/rns-debug-nc`, `/rns-debug-refresh`, `/rns-debug-extract`, `/rns-store-test`,
  `/rns-store-reset`, `/rns-bus-skip`, `/rns-bus-scan`, `/rns-stress-*`, das
  StressTest-Modul, dazu alle Schreibzugriffe nach `script-output`
  (`rns-debug-nc.txt`, `rns-debug.txt`).
  Bis dahin sind sie im Multiplayer admin-only (B-31).
- Der Mod-Eintrag führt `RNS_ExternalBus_FastScan` in `settings`-Nähe, gehört aber
  nicht in die Spielereinstellungen.
- `tools/png_bbox.py` und `tools/static-check/` (Messwerkzeuge, nicht Teil der Mod).
- P6 laut Plan.
