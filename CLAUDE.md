# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Factorio mod: "Refined Network Storage Redux" (`RNSRedux`, version 2.0.0). It is a port of NindyBun's *Refined Network Storage* (MIT) from Factorio 1.1 to 2.0, and it rebuilds the item storage layer on engine script inventories. Upstream baseline: tag `upstream-1.0.43`. Working branch: `port/2.0`. Remote: `github.com/haiGodzilla/RNSRedux`. This is a standalone repo, not a GitHub fork, so never open PRs against NindyBun's repo.

## Read these first

The project is run from three German-language docs. Code comments and commit messages are in English.

- `docs/projektstand.md` is the entry point. It covers current state, verified measurements, decisions, and the next step. Section numbers like "7.20" or "6.8" in code comments and commits refer to this doc.
- `docs/ups-architektur.md` is the performance architecture and the milestone plan **P0–P6**. P0–P3 are done. P5 (external IO) is largely done — two of the three measures, measured at 2.5% of the tick budget. P4 (scheduler) and P6 (cleanup) are open.
- `docs/bugtracker.md` is the single source for findings (`B-01`…). Its status values are `offen`, `ungemessen`, `wartet auf Test`, `behoben`, and `kein Fehler`. When a finding changes, update the tracker and the summary in `projektstand.md` §10 together.

The tracker header and `projektstand.md` carry a "Stand: Commit `<hash>`" line. Commits titled "docs: fill in the commit hash" keep that line current.

## Workflow constraints (from `projektstand.md` §11)

- **Single Mac, but one local copy.** Development and Factorio now run on the same machine. The agent edits this repository directly; the separate read-only tester checkout and its `git pull --ff-only` are gone. Factorio still reads a **copy** in its mod directory, so after every change the repo must be mirrored there with the local `rnssync` fish function and the save reloaded — otherwise the old code keeps running (this cost the B-55 fix one test round). The agent applies changes autonomously and asks only when a decision is needed; **commits and pushes happen after agreeing with the user**.
- **Restart requirements:**
  - Changes in the control stage (`control.lua`, `scripts/`, `utils/Util.lua`) only need a save reload.
  - Changes in the data stage (`data*.lua`, `prototypes/`, `settings.lua`, `utils/constants.lua`) need a full game restart.
  - Factorio must exit cleanly, or `factorio-current.log` is stale.
- There is no build step and no automated test suite. Verification happens in the game: log lines prefixed `RNSRedux`, the debug commands below, and the F4 profiler. Outside the game, `tools/static-check/` parses every file, checks globals per stage, and cross-checks `defines.*` and engine method names against the 2.0 API (see Tooling).
- House rules:
  - Read before changing. Never take line numbers from memory.
  - Re-read every replaced spot.
  - Make the smallest change that holds.
  - Never claim a fix works unless it was measured or tested in the game. "Fixed, untested" is its own status.
  - Don't wrap setters in `pcall` to hide wrong assumptions.
- Host names, paths, and credentials of the build environment must not go into the repo. It is pushed to GitHub.

## In-game debug/measurement commands

All are defined in `control.lua` through `debugCommand(...)`. In multiplayer only admins can run them, and the handler runs under `safeCall`. The `rns-stress-*` commands delegate to `scripts/debug/StressTest.lua`. Runtime switches set by commands live in `storage` (`storage.debugOverrides`, `storage.stressTest`) and never in `Constants`, because a joining client reads `Constants` from the file and would desync. They survive save/load: run `/rns-debug-reset` before a measurement. The `/rns-debug-nc` header marks overrides.

- `/rns-debug` dumps per-controller `members`, `tracked`, `cache`, `drive`, `external`, `truth` (drives / claimed count / actual contents), `fluidTruth`, and `busTruth`. A `truth` mismatch means the bookkeeping has diverged. `/rns-debug-refresh` forces a full rebuild, and the two dumps must match. `/rns-debug-nc` dumps only the controller counters. `/rns-debug-extract` extracts without the GUI.
- `/rns-stress-build <stations> <drivesPerStation> [busesPerStation] [mixed|item|external] [both|input|output]`, `/rns-stress-fill`, `/rns-stress-drain`, `/rns-stress-status`, `/rns-stress-clear`, `/rns-stress-purge`. Expected entity counts per setup are in `projektstand.md` §4.3. The measurement method is in `ups-architektur.md` §9: save, return to the menu, load, then compare `mod-RNSRedux` in the profiler with `/perf-avg-frames 600`. The columns are avg/min/max.
- `/rns-bus-skip`, `/rns-bus-scan`, `/rns-store-test`, and `/rns-store-reset` are probes from earlier milestones.
- All of these, the `port_*.py` scripts, and `tools/png_bbox.py` are slated for removal before release (`bugtracker.md` §5).

## Tooling

- `cd tools/static-check && npm install && npm run check` runs the static checks without a Lua runtime. It covers Lua 5.2 syntax (including the goto scope rules), undefined or implicit globals per stage (settings/data/control), and `defines.*` paths plus engine dot-calls against `typed-factorio` 3.36.0 (= Factorio 2.0.75). It reports `set_signal`-style 1.1 leftovers, which 2.0 no longer has. Run it after every change. A clean run proves nothing about runtime behaviour.
- `python3 tools/png_bbox.py <file.png> [canvas_px_per_tile] [--brief]` prints the painted bounding box of a sprite in pixels and tiles. Use it to size `collision_box`/`selection_box`/`shift`/`scale` against the real artwork. In-game, one tile is `32 / scale` canvas pixels.
- `python3 port_locale_check.py` lists locale keys used in Lua but missing from `locale/*/*.cfg`.
- The other `port_*.py` files are one-shot 1.1→2.0 codemods that have **already been applied**. Don't re-run them. They document which API renames were made (`global`→`storage`, `game.item_prototypes`→`prototypes.item`, `get_contents()` array shape, `rendering.draw_*` returning objects, wire connectors, and so on).

## Architecture

### Data stage

- `data.lua` defines `RNS_WalkableCollisionMask`, a copy of the belt's collision mask that the 1×1 network pieces use so the character can walk over them. It then requires `prototypes/*.lua`, then shortcuts, item groups, fonts, and GUI styles.
- `utils/constants.lua` is huge and shared by **both** stages. It holds every entity, item, and sprite name, graphics paths, sizes, tick rates, and recipe ingredients. Prototype files read their definitions from it, and runtime code looks names up in it.
- All mod prototype names start with `RNS_`. Code relies on that prefix: `string.sub(name, 5)` indexes `Constants.Drives.ItemDrive`, and connectivity matches `"RNS_"`.
- `data-final-fixes.lua` scrubs `RNS_*` recipe ingredients and results that Space Age or quality deleted, substituting where it can and logging the rest. It also fixes the select-icon signals by reading paths from `utility-sprites`.
- Some entity types are chosen for 2.0 behavior, not semantics:
  - The IO buses and the underground cable (ramp) are `assembling-machine`, so their sprites must sit under `graphics_set`. A top-level `animation` is ignored. The plain cables are `container`.
  - The controller is an `electric-energy-interface`.
  - Drives are a `container` with `inventory_size = 0`. This is why hovering shows "0/0" (B-01).

### Control stage

- **Globals and `require` order.** `control.lua` requires everything into global tables. Each entity kind is a class in `scripts/objects/` stored in a global with a short tag: `NC` controller, `ID`/`FD` item/fluid drive, `IIO3`/`FIO`/`EIO` item/fluid/external IO bus, `NCbl`/`NCug` cable/underground, `NII` network inventory interface, `DT`, `WT`, `WG`, `TR`, and `RNSP` player. Shared modules are `BaseNet` (`NetworkBase.lua`), `UpdateSys` (`scripts/updates.lua`), `Event` (`scripts/Events.lua`), `GUI`/`GuiApi`, `Util`, and `ItemStore`.
- **Object registry.** `scripts/Functions.lua:createObjectTables()` maps each entity prototype name to `{tableName, tag}` in `storage.objectTables`. `Event.placed` looks up the tag, calls `_G[tag]:new(entity)`, and stores the object in `storage[tableName][unit_number]`. All objects are also in `storage.entityTable[unit_number]`, which is how connectivity and removal find them.
- **Object lifecycle contract.** Every class implements:
  - `new(entity)`
  - `rebuild(obj)`, which restores the metatable in `on_load` because `storage` drops metatables. Nested objects must be rebuilt too, e.g. `ID:rebuild` calls `ItemStore.rebuild`.
  - `remove()`
  - `valid()`
  - optionally `update()`, `createArms()`/`getCheckArea()`, `DataConvert_ItemToEntity`/`DataConvert_EntityToItem` (contents carried in an `item-with-tags` when mined or placed), `serialize_settings`/`deserialize_settings` (blueprint tags), and `getTooltips`/`interaction` (GUI).
- **Error handling.** Event handlers in `control.lua` wrap their `Event.*` call in `Util.safeCall`, which `pcall`s, prints, and logs. If placing an object fails, the entity is destroyed. Under `debugadapter`, `pcall` is skipped.
- **Connectivity ("arms").** `new()` calls `createArms()`, which uses `BaseNet.generateArms` to scan the four neighbouring areas with `find_entities_filtered`, draw connector sprites, and `join_network`. Both `new()` and `remove()` call `BaseNet.postArms`, which tells neighbours to redo their arms. Cable colours only connect to the same colour. IO ports don't connect on their IO face.
- **Network accounting.** `BaseNet` hangs off a controller (`NC.network`). It holds per-priority drive/IO tables, tracked item/fluid counters, and import/export caches. Membership changes set `network.shouldRefresh` through `BaseNet.update_network_controller`, and the controller then runs `doRefresh`. The periodic refresh (`NC.updateTick = 7200`) is only a safety net, phase-offset by `entID`. Keep that invariant: anything that joins or leaves a network must trigger `update_network_controller`.
- **Tick loop.** `on_tick` → `Event.tick` → `UpdateSys.update` iterates `storage.updateTable`, which holds controllers, players, wireless transmitters and grids, but not drives. Each `NC:update` handles power and stability, then sweeps IO buses every tick. **Each bus decides whether this is its phase tick**, which spreads cost across ticks. A shared `game.tick % N` blew the tick budget. Detectors, fluid IO, and wireless run on `Constants.Settings.*_Tick` modulos. `GUI.update()` refreshes open GUIs.
- **Item storage (`ItemStore.lua`, P2).** A drive's contents live in `game.create_inventory` script inventories ("chunks"), so the engine keeps full item identity: quality, ammo, durability, spoil, and tags. The key is `name|quality`. Capacity is an item count, not slots. A chunk doubles up to 65535 slots, then another chunk joins. `store.index` maps keys to chunks for O(1) lookups. Script inventories must be freed with `store:destroy()` in `remove()`, or they leak into the save. `storedAmount` on the drive is a tracked mirror that the `truth` check compares against.
- **Itemstack.** `Itemstack.lua` is the legacy hand-serialized item representation. It is still used on transfer paths and is slated for removal in P6.
- **Render objects.** `rendering.draw_*` returns a `LuaRenderObject` in 2.0. Always wrap it in `Util.newRender(...)` so only the numeric id is stored, and use `Util.destroyRender`/`Util.setRenderAltMode` to act on it.
- **Circuit network.** Read through `Util.getCombinatorNetwork/Signal/Signals`, which query the red and the green connector explicitly (`get_signal(signal, red, green)` is the 2.0 form of `get_merged_signal`). Write constant-combinator signals only through `Util.setCombinatorSignal(combinator, index, nil | {signal=…, count=…})`. 2.0 removed `set_signal`, and signals live in logistic sections.
- **Booking rule.** A transfer books only the amount that actually moved: the return value of `insert`, `insert_fluid` or `add_or_merge_basic_item`. It does not book the amount requested or split off. Whatever the target refused goes back to the source. The fluid insert paths re-read the source fluidbox, because `fluidbox[i]` is a copy.
- **Priority or mode changes** call `BaseNet.update_network_controller` and let the refresh re-file the object. Don't move entries between the priority tables by hand. The item/fluid IO lists hold entIDs, while `ExternalIOTable[p][type]` holds objects.
- **Refresh invariant.** A refresh (`doRefresh`) costs O(network). Only build or removal events and player actions may trigger it. Simulation events such as vehicles arriving at a bus, sweeps or transfers must not (`docs/ups-architektur.md` 6b). Every incremental un-booking needs a mirror-image booking: `EIO:flush_cache` and `EIO:inject_cache` are such a pair, and `reset_focused_entity` uses both.
- **Blueprint and entity tags are untrusted.** The `deserialize_settings` of the drives, the item, fluid and external buses, the detector and the wireless transmitter read fields through `Util.tagChoice/tagNumber/tagPriority/tagBoolean/tagPrototypeName/tagSignal/tagEnabler`. These keep the value `new()` set unless the tag value is valid. TransReceiver/WirelessGrid (M5, B-41) still take some fields raw. A throw during placement makes `placed` remove the half-built object and destroy the entity.
- **Players** are keyed `"player-<index>"` in `updateTable` and are not in `entityTable`, whose keys are unit numbers.

### Scope decisions

- The first release covers cables, the controller, drives, and IO buses. Wireless, the player port, the transmitter/receiver and the detector come later (M5). Their technologies are listed in `Constants.DeferredToM5` (`utils/constants.lua`). The data stage disables them for new games, and `onInit` disables the unresearched ones per force in existing saves. The prototypes stay.
- There is no version-to-version migration path, and the upstream `migrations/` folder was removed. `onInit`, which also runs on `on_configuration_changed`, only normalises keys (`RNSP.migrateKeys`).
- Quality items are blocked at the drive entrance on purpose, so they are never silently lost or downgraded.
