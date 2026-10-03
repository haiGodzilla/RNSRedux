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

Stand: Commit `7268718`. Die Reihenfolge ist keine Priorisierung.

## 1. Offen

| ID | Bereich | Befund | Status | Beleg |
|---|---|---|---|---|
| B-01 | Anzeige | Hover über einen platzierten Drive zeigt `Storage: 0/0`, der Klick die richtige Füllung (61 Items im Drive, Screenshot). Die Zeile stammt **nicht** aus der Mod: der einzige Mod-Text mit diesem Wort ist `item-description.RNS_DriveTag_Storage`, und der wird nur am **geminten Item** gesetzt — als Teil einer vierzeiligen Beschreibung mit Filters, Priority und Mode, die im Screenshot alle fehlen. `Storage` und `Last user` kommen im ganzen Repo nicht vor. Angezeigt wird also das Inventar des `container` mit `inventory_size = 0` (7.20), jetzt mit Beleg. **Behebung, jetzt recherchiert:** 2.0 kennt `Prototype::custom_tooltip_fields`, das **ergänzt** Einträge, entfernt aber keine — und die Runtime-Felder (`LuaEntity::set_tooltip_field`) kommen erst mit 2.1. In 2.0 bleibt damit nur ein anderer Entity-Typ (wie die IO-Busse als `assembling-machine` und der Controller als `electric-energy-interface`). Data-Stage, berührt Öffnen, Minen und Blueprint; jetzt unabhängig von B-21 entscheidbar, weil der Footprint dort schon geändert ist. | `offen` | 7.20, Screenshots, API-Doku 2.0.72 |
| B-02 | ItemStore | `CHUNK_INITIAL = 1024` unabhängig von der Größe; ein 4k-Drive braucht 40 Slots, bekommt 1024. Kostet Savegröße und Bauzeit, **nicht Ticks** — `is_full` läuft über den geführten Zähler. | `offen` | 7.15 |
| B-03 | Netzwerk | `NetworkBase.addConnectables` Zeilen 183/186/191: drei Prüfungen mit `and` statt `or`. Crash statt sauberer Abbruch; Zeile 186 prüft `.valid` auf einer Tabelle ohne das Feld. | `offen` | 1:1-Port, ungeprüft |
| B-04 | Fluide | `Util.fluid_add_list_into_table`: Temperaturmischung falsch gewichtet, `v.amount` wird vor der Gewichtung erhöht. | `offen` | 1:1-Port, ungeprüft |
| B-05 | Controller | `NC:createArms` übergibt einen String an `order_deconstruction("player")`; 2.0 erwartet eine ForceID. Ob das still fehlschlägt, ist ungeprüft. | `offen` | 1:1-Port, ungeprüft |
| B-06 | Grafik | Beide Select-Signale zeigen auf dieselbe Datei, die Tönung geht verloren. Gemessen im Log: `RNS_select_icon_black icon -> __core__/graphics/icons/mip/select-icon.png` und `..._white ->` **dieselbe** Datei — in 2.0 tragen beide `utility-sprites`-Felder denselben Dateinamen, und `data-final-fixes.lua:91–100` übernimmt nur den Namen. Der zweite Teil des alten Eintrags (leerer vertikaler Balken) ließ sich nicht wiederfinden und ist gestrichen. | `offen` | `factorio-current.log`, Andre |
| B-07 | Messung | Eine Zerlegung geht um 0,21 ms nicht auf; die 9 % Mehrkosten aus 6.6 haben keine Ursache. Möglicherweise derselbe Posten. | `offen` | 6.11, 6.12 |
| B-08 | Performance | `filter_externalIO_by_valid_signal` baut bei jedem Aufruf verschachtelte Tabellen neu auf. Läuft seit `10154d6` nur noch auf dem Tick des Busses, die Allokation bleibt. | `offen` | `NetworkBase.lua:1340` |
| B-09 | Performance | `NC:updateExternalStorage` läuft jeden Tick und iteriert alle External-Busse, auch wenn keiner in seiner Phase ist. Bei 40 Bussen billig, bei einigen Tausend nicht. | `offen`, gehört zu P4 | `NetworkController.lua:175` |
| B-10 | Dokumentation | Der Verweis auf die Projektnotiz „Analyse Fabrikdurchsatz" läuft ins Leere — die Notiz liegt nicht im Repo. | `offen` | `ups-architektur.md` Abschnitt 10 |
| B-22 | Grafik | Der Schatten des Drives ist **doppelt so groß wie der Körper**: beide Bilder sind auf 128 Bildpixel pro Feld gemalt (Körper 258 px auf `scale 1/4`, Schatten 255 px auf `scale 1/2`), der Schatten deckt damit 3,98 statt 1,99 Felder. Nicht der Versatz ist falsch, die Skalierung; bei `1/4` läge er mit `shift = {0,0}` mittig unter dem Sockel. Beim Controller ist das Schattenbild zusätzlich am eigenen Rand abgeschnitten (bemalte Fläche endet auf `x = 511`). Probe `5189eea` **zurückgenommen** (`8ee251d`) — sie hatte nur den Versatz geändert. Mit dem neuen Footprint ist der Versatz auf `{1,0.016}` nachgeführt, damit der Abstand zum Körper derselbe bleibt. Kosmetisch, eigener Schritt nach B-21. | `offen` | 9.1 |

## 2. Behoben, Test steht aus

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-21 | Grafik | Drive und Controller sind jetzt **2 × 3** bzw. **3 × 4** Felder groß (vorher 2 × 2 und 3 × 3), Kollision 1,8 × 2,8 bzw. 2,8 × 3,8. Gemessen mit `tools/png_bbox.py`: Kunst 2,016 × 2,836 bzw. 2,834 × 3,999 Felder, jeweils mit der Unterkante auf der Unterkante des Footprints. Drive unverändert `scale = 1/4` mit `shift = {0,0.21875}`; Controller `scale = 180/512` statt `192/512` (6,25 % kleiner, sonst passt seine 4,27 Felder hohe Kunst nicht in vier) mit `shift = {0,0.5828}`. **Ungemessen:** ob die acht Drive-Bilder (vier Item-, vier Fluid-Stufe) dieselbe Unterkante im Canvas tragen — die Werte stammen von `ItemDrive4E.png`. **Und ungemessen:** beide Entities wechseln die Gitterlage in y, siehe 9.1. | `wartet auf Test` | 9.1 |

## 3. Nachgerechnet, unkritisch

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-12 | NII | Der Sortierschalter ist **nicht** wirkungslos. `GUI.on_gui_clicked` leitet jedes `RNS_NII*`-Element an `NII.interaction` (`Gui.lua:147–150`), und dort steht der `SortOrder`-Zweig (`NetworkInventoryInterface.lua:754`). Der fehlende Zweig in `on_gui_element_changed` war nur der zweite Weg dorthin. Gemessen: Andre sortiert um, in beide Richtungen. | `kein Fehler` | `Gui.lua:147`, Andre |
| B-13 | Netzwerk | `add`/`remove_item_from_interface_cache` sind lineare Scans, aber die Liste hat **einen Eintrag pro Item-Typ** — der Aufteilungszweig greift nur einmal, weil der Rest ein volles Magazin bekommt. Bestätigt durch `cache=16` bei 16 Typen. | `kein Fehler` | 8.3 |

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

## 5. Vor dem Release zu erledigen

- Alle Debug-Befehle entfernen und die `port_*.py`-Skripte: `/rns-debug`,
  `/rns-debug-nc`, `/rns-debug-refresh`, `/rns-debug-extract`, `/rns-store-test`,
  `/rns-store-reset`, `/rns-bus-skip`, `/rns-bus-scan`, `/rns-stress-*`, das
  StressTest-Modul, dazu alle Schreibzugriffe nach `script-output`
  (`rns-debug-nc.txt`, `rns-debug.txt`).
- Der Mod-Eintrag führt `RNS_ExternalBus_FastScan` in `settings`-Nähe, gehört aber
  nicht in die Spielereinstellungen.
- `tools/png_bbox.py` (Messwerkzeug, nicht Teil der Mod).
- P6 laut Plan.
