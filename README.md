# leatrix-maps-forever-mirror

**Leatrix Maps+**: the WoW Forever builds of [Leatrix Maps](https://www.curseforge.com/wow/addons/leatrix-maps), with a few additions for Forever that Leatrix Maps doesn't have yet. Install it with an addon manager that installs GitHub releases (Knapsack, WowUp).

This is an unofficial build. Report problems with the additions here, not to Leatrix. All credit for Leatrix Maps goes to its author.

## What it adds

- **The Tanaris–Riverglades boat for both factions.** Leatrix Maps marks it Horde, which hides it from Alliance players by default. [OpenMap](https://github.com/openmap-world/openmap)'s data and [Forever Atlas](https://wowforeveratlas.com/boat-routes-guide) both list it for both factions.
- **Your own markers.** Type `/lmf edit`, open the map and Alt-click a zone to add a zone crossing, spirit healer or dungeon entrance. Drag one of yours to move it, or click it to turn or delete it. They're drawn by Leatrix Maps exactly like its own icons, and saved in `LeaMapsForeverDB` in your `WTF` folder. `/lmf export` shows them as rows to add here for everyone. A marker retires itself once Leatrix Maps has one like it (`/lmf list`, `/lmf purge`).

Each addition is skipped automatically when Leatrix Maps catches up.

## How it's built

- `Leatrix_Maps/` is Leatrix Maps exactly as uploaded to CurseForge. It's mirrored by [wow-addon-mirror-action](https://github.com/austinrr/wow-addon-mirror-action), which also tags each version (`1.60.31`) and releases the original zip.
- `forever/` holds the additions (`Leatrix_Maps_Forever.lua`, `Leatrix_Maps_Editor.lua`), which load after Leatrix Maps' icon data and add to it.
- After each mirror run, and whenever `forever/` changes, the workflow runs `forever/release.py`. It builds the mirrored version with the additions and releases it as `<version>-plus.<n>` (for example `1.60.31-plus.1`), marked latest. The number goes up when the additions change.

To build it yourself: `python3 forever/build.py [AddOns folder]` (default `dist/`).
