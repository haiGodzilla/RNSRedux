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
| `behoben` | behoben **und** gemessen |
| `kein Fehler` | nachgerechnet oder gemessen, unkritisch |

Stand: Commit `ca5e457`. Die Reihenfolge ist keine Priorisierung.

## 1. Offen

| ID | Bereich | Befund | Status | Beleg |
|---|---|---|---|---|
| B-01 | Anzeige | Hover über einen platzierten Drive zeigt `0/0`, der Klick die richtige Füllung. Ursache: Der Drive ist ein `container` mit `inventory_size = 0`, und Factorio zeigt beim Hover das Inventar — das die Mod nie benutzt. | `offen` | `docs/projektstand.md` 7.20 |
| B-02 | ItemStore | `CHUNK_INITIAL = 1024` unabhängig von der Größe; ein 4k-Drive braucht 40 Slots, bekommt 1024. Kostet Savegröße und Bauzeit, **nicht Ticks**. | `offen` | 7.15 |
| B-03 | Netzwerk | `NetworkBase.addConnectables` Zeilen 183/186/191: drei Prüfungen mit `and` statt `or`. Crash statt sauberer Abbruch; Zeile 186 prüft `.valid` auf einer Tabelle ohne das Feld. | `offen` | Abschnitt 9 |
| B-04 | Fluide | `Util.fluid_add_list_into_table`: Temperaturmischung falsch gewichtet, `v.amount` wird vor der Gewichtung erhöht. | `offen` | Abschnitt 9 |
| B-05 | Controller | `NC:createArms` übergibt einen String an `order_deconstruction("player")`; 2.0 erwartet eine ForceID. Ob das still fehlschlägt, ist ungeprüft. | `offen` | Abschnitt 9 |
| B-06 | Grafik | Beide Select-Icons zeigen auf dieselbe Datei (Tint geht verloren), ein leerer vertikaler Balken in der Items-Spalte. | `offen` | Abschnitt 9 |
| B-07 | Messung | Eine Zerlegung geht um 0,21 ms nicht auf; die 9 % Mehrkosten aus 6.6 haben keine Ursache. Möglicherweise derselbe Posten. | `offen` | 6.11, 6.12 |
| B-08 | Performance | `filter_externalIO_by_valid_signal` baut bei jedem Aufruf verschachtelte Tabellen neu auf. Läuft seit `10154d6` nur noch auf dem Tick des Busses, die Allokation bleibt. | `offen` | Abschnitt 9 |
| B-09 | Performance | `NC:updateExternalStorage` läuft jeden Tick und iteriert alle External-Busse, auch wenn keiner in seiner Phase ist. Bei 40 Bussen billig, bei einigen Tausend nicht. | `offen`, gehört zu P4 | Abschnitt 9 |
| B-10 | Dokumentation | Der Verweis auf die Projektnotiz „Analyse Fabrikdurchsatz" läuft ins Leere — die Notiz liegt nicht im Repo. | `offen` | Abschnitt 9 |
| B-18 | Texte | Item-Beschreibungen waren leer oder wiederholten den Namen. **Zwei Ursachen, beide gefunden:** (1) Schlüssel passten nicht auf die Prototyp-Namen — das Netz-Item heißt `RNS_NetworkInventoryInterface` (`constants.lua:900`), die Locale führte `RNS_NetworkInventoryBlock`; beim Controller, Wireless Transmitter und den drei IO-Bussen dasselbe Muster. Genau diese hatten **gar keine** Beschreibung. (2) Die vorhandenen Texte wiederholten den Namen („Red Cable"). **Behoben:** beide Schlüsselformen eingetragen und alle 36 Einträge durch echte Texte ersetzt, mit dem Zusammenspiel (Kabel verbinden, Controller definiert, Drives speichern, Busse tauschen, Transmitter/Receiver spannt das Netz über die Distanz). Fluid-Drive sagte „items" statt „fluid". Ramp-Items hatten `order = "a"` wie die Kabel → jetzt `"b"`. | `wartet auf Test` | `locale/en/config.cfg`, `prototypes/NetworkCable.lua` |
| B-19 | Kollision | Die 1×1-Netzteile blockieren den Charakter. Kabel haben `collision_box` und **keine `collision_mask`**, also kollidierten sie mit der Standard-Maske inklusive Spieler. **Behoben:** Kabel, Underground-Kabel und die drei IO-Busse übernehmen die Maske des Belts — gemessen: `{water_tile, floor, transport_belt, object, meltable}`, **ohne `player`**. Die Schreibweise `{layers = {...}}` ist im eigenen Repo belegt (`others.lua:186`). Kein Regress: für RNS-Objekte existierte nie eine Maske. | `wartet auf Test` | `data.lua`, `prototypes/NetworkCable*.lua` |
| B-20 | Kabel | Underground-Kabel: kein Sprite am Cursor, platziert unsichtbar. **Meine Blatt-Hypothese war falsch** — `NetworkCableRedRamps.png` ist 2048×512, die x-Adressierung passt. **Neue Ursache:** Der Prototyp setzt ein **Top-Level `animation`**, aber eine `assembling-machine` liest `graphics_set.animation` — so machen es die drei IO-Busse im selben Repo, und die API führt `graphics_set` als Feld dieses Typs, ein Top-Level-`animation` nicht. Ohne Grafik ist die Vorschau leer und das platzierte Teil unsichtbar. **Behoben** durch Einrücken unter `graphics_set`. | `wartet auf Test` | `prototypes/NetworkCable.lua:122–159` |

## 2. Gebaut, aber ungemessen

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-11 | NII | Der Handler-Zweig für `RNS_NII_PInv_*` ist verdrahtet, aber nie mit einem Klick geprüft. | `ungemessen` | 5.13 |
| B-12 | NII | Der Sortierschalter `RNS_NII_SortOrder` ist im Klick-Pfad behandelt, feuert aber `on_gui_element_changed` — dort fehlt der `RNS_NII`-Zweig. Vermutlich wirkungslos. | `ungemessen` | 5.13 |

## 3. Nachgerechnet, unkritisch

| ID | Bereich | Punkt | Status | Beleg |
|---|---|---|---|---|
| B-13 | Netzwerk | `add`/`remove_item_from_interface_cache` sind lineare Scans, aber die Liste hat **einen Eintrag pro Item-Typ** — der Aufteilungszweig greift nur einmal, weil der Rest ein volles Magazin bekommt. Bestätigt durch `cache=16` bei 16 Typen. | `kein Fehler` | 8.3 |

## 4. Behoben

| ID | Bereich | Punkt | Beleg |
|---|---|---|---|
| B-14 | Speicherschicht | Drive hielt seinen Inhalt als handserialisierte Lua-Tabelle; Munition und Haltbarkeit per Modulo addiert, Qualität kollabierte. Ersetzt durch Engine-Inventare. | P2, 7.21 |
| B-15 | Platzierung | Ein fremder Entity-Tag setzte `filters` auf `nil`, `regenerate_icons` warf, und `Control.placed` zerstörte den Drive. Jetzt werden alle Felder geprüft. | `535a6d9`, 7.18 |
| B-16 | Platzierung | `on_built_entity` hat in 2.0 kein `stack`-Feld — der Lesepfad war seit der Portierung tot. Ein **per Roboter** gebauter Drive behielt seinen Inhalt, ein von Hand gebauter nicht. Jetzt wird `consumed_items` zusätzlich gelesen. | `8d0a0f8`, 7.17 |
| B-17 | Transfer | P2 ersetzte einen Hash-Zugriff durch eine Engine-Suche über die Chunks, pro Drive und pro Item, im Normalfall erfolglos. Der Index antwortet jetzt zuerst. | `55dccb0`, 8.2 |

## 5. Vor dem Release zu erledigen

- Alle Debug-Befehle entfernen und die `port_*.py`-Skripte: `/rns-debug`,
  `/rns-debug-nc`, `/rns-debug-refresh`, `/rns-debug-extract`, `/rns-store-test`,
  `/rns-store-reset`, `/rns-bus-skip`, `/rns-bus-scan`, `/rns-stress-*`, das
  StressTest-Modul, dazu alle Schreibzugriffe nach `script-output`
  (`rns-debug-nc.txt`, `rns-debug.txt`).
- Der Mod-Eintrag führt `RNS_ExternalBus_FastScan` in `settings`-Nähe, gehört aber
  nicht in die Spielereinstellungen.
- P6 laut Plan.
