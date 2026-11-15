# leatrix-maps-forever-mirror

**Leatrix Maps+**: a fork of the WoW Forever builds of [Leatrix Maps](https://www.curseforge.com/wow/addons/leatrix-maps), with corrections and additions for Forever. It follows each Leatrix Maps release automatically. Install it with an addon manager that installs GitHub releases (Knapsack, WowUp).

This is an unofficial build. Report problems with the changes here, not to Leatrix. All credit for Leatrix Maps goes to its author.

## What it changes

- **The Tanaris–Riverglades boat for both factions.** Leatrix Maps marks it Horde, which hides it from Alliance players by default. It runs for both factions (checked in game, and [Forever Atlas](https://wowforeveratlas.com/boat-routes-guide) lists it so).
- **No portals between Stormwind and Dalaran.** Neither is in WoW Forever at the moment, but Leatrix Maps shows both.
- **The game's dungeon level ranges**, from its Group Finder via [OpenMap](https://github.com/openmap-world/openmap), for the 12 dungeons where Leatrix Maps' differ (for example Krol'dok Stronghold 40–47, Scarlet Monastery 30–46).
- **Zone level ranges from OpenMap** where Leatrix Maps' differ: Searing Gorge 45–50, and Moonglade 55–60 (Leatrix Maps shows none).
- **Your own markers.** Type `/lmf edit`, open the map and Alt-click a zone to add a zone crossing, spirit healer or dungeon entrance. Drag one of yours to move it, or click it to turn or delete it. They're drawn by Leatrix Maps exactly like its own icons, and saved in `LeaMapsForeverDB` in your `WTF` folder. `/lmf export` shows them as rows to add here for everyone. A marker retires itself once Leatrix Maps has one like it (`/lmf list`, `/lmf purge`).

## How it's built

- `Leatrix_Maps/` is always Leatrix Maps exactly as uploaded to CurseForge. It's mirrored by [wow-addon-mirror-action](https://github.com/austinrr/wow-addon-mirror-action), which also tags each version (`1.60.31`) and releases the original zip.
- `forever/` holds the fork's changes:
  - `Leatrix_Maps_Forever.lua` and `Leatrix_Maps_Editor.lua` load after Leatrix Maps' icon data and correct or add to it. Each correction does nothing once Leatrix Maps makes it itself.
  - `leatrix.patch` holds changes to Leatrix Maps' own code (the zone levels).
- After each mirror run, and whenever `forever/` changes, the workflow runs `forever/release.py`. It builds the mirrored version with the patch and the files above, and releases it as `<version>-plus.<n>` (for example `1.60.31-plus.1`), marked latest. The number goes up when the fork's changes do.

To build it yourself: `python3 forever/build.py [AddOns folder]` (default `dist/`).

## Handling Leatrix Maps updates

### What happens on its own

Every two hours the workflow checks CurseForge. When Leatrix publishes a new version:

1. The mirror action replaces `Leatrix_Maps/` with it, commits, tags it (`1.60.32`) and releases the original zip.
2. `forever/release.py` builds Leatrix Maps+ from it and releases `1.60.32-plus.1` as the latest release.

Knapsack then offers the update as usual. Most updates need nothing more.

### What to check after an update

- **The workflow run**, under Actions: did "Release Leatrix Maps+" succeed? If it failed, see [conflicts](#when-an-update-conflicts) below.
- **Leatrix's changelog** (`Leatrix_Maps/Changelog.txt`, or `git diff <old>..<new> -- Leatrix_Maps/`): did Leatrix fix something the fork fixes, or change its points-of-interest code?
- **In game**, after `knapsack update`: the editor still works (`/lmf edit`, Alt-click to add, drag to move), and the fixes still show (the Riverglades boat for the Alliance, no Stormwind–Dalaran portals).

### When Leatrix catches up with a fix

The fork's changes are meant to shrink as Leatrix improves. When Leatrix makes one of them itself:

- **A correction in `Leatrix_Maps_Forever.lua`** (the boat, the portals, a dungeon's levels) does nothing once Leatrix's data matches, so nothing breaks. Remove it anyway to keep the file honest; its comments say where each one came from.
- **A change in `leatrix.patch`** (the zone levels) usually shows up as a conflict, because Leatrix changed the same line. Resolve it by taking Leatrix's line. If that leaves no changes, `save` writes an empty patch, which the build skips.
- **Your own markers** retire themselves on login once Leatrix has one like them (`/lmf list` shows them, `/lmf purge` forgets them).

If Leatrix's value differs from ours (say it sets Searing Gorge to 44–50), decide which source to trust. The comments and this README name the sources.

### What could break quietly

These parts depend on how Leatrix works inside, so an update can break them without any conflict:

- **The editor** relies on Leatrix's points-of-interest code: the `Leatrix_Maps["Icons"]` table and its row format, pins marked `isLeaMapsPin` that keep their row in `pin.data`, pins redrawn when the map changes, and its click catcher sitting just above the pins. If Leatrix rewrites that code (it did in 1.60.30), test the editor in game.
- **`build.py`** puts the fork's files after `Leatrix_Maps_Icons.lua` in the toc, and adds to its `SavedVariables` and `Version` lines. If Leatrix renames or reorders those, the build stops with a message rather than producing a broken addon.
- **The addon folder** has to stay `Leatrix_Maps`: Leatrix's code loads its textures from that path, and players' settings are saved under it.

### When an update conflicts

The patch applies to most updates as they are. It only conflicts when Leatrix Maps changes the same lines the patch changes, or the line next to them. Then the workflow's "Release Leatrix Maps+" step fails (GitHub emails you), and the last Leatrix Maps+ release is made latest again, so players stay on it rather than getting plain Leatrix Maps.

To fix it, from an up-to-date checkout:

```sh
python3 forever/patch.py apply    # applies the patch with a 3-way merge; conflicts get <<<<<<< markers
# resolve the markers in Leatrix_Maps/ (often by taking upstream's line, if it now does what ours did)
python3 forever/patch.py save     # writes the result to forever/leatrix.patch
python3 forever/patch.py reset    # puts Leatrix_Maps/ back as mirrored
git commit -am "Update the patch for Leatrix Maps <version>" && git push   # releases <version>-plus.1
```

The same steps change Leatrix Maps' code in the first place: `apply`, edit, `save`, `reset`. `python3 forever/patch.py check` says whether the patch applies.
