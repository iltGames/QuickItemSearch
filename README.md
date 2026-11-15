# Quick Item Search

Press Ctrl+Shift+Space to open search when the chord is free. To change it, open **Options > AddOns > Quick Item Search**, click the hotkey, and press the new shortcut. The addon saves it in WoW's active keybinding set.

Use `/qis` to open search or `/qis linen cloth` to open it with a query. `/itemsearch` is also available.

Search by English item name, numeric ID, or pasted item link. Use Up and Down to browse results, Enter to open the native item tooltip, and Escape to close the search overlay. You can also hover for a tooltip, click to inspect, Shift-click to insert a link into open chat, or Ctrl-click to try on supported equipment.

With AtlasLoot Classic Forever enabled, search for a boss by name to see its loot. Use `boss:<name>` to search only for bosses, including when a partial name also matches items.

Drag the grip at the top of the overlay to move it. Quick Item Search remembers the position across reloads.

The bundled index contains 24,565 names from the English ItemSparse table installed with WoW Forever 1.60.1.70938 and that build's locally received item hotfixes. The game supplies tooltips, item links, and icons. The index can include internal or unobtainable items. Future or server-only items missing from the snapshot can still be queried by ID or link when the game exposes them.

## Installation

Install through CurseForge once the project is available, or extract the ZIP from [GitHub Releases](https://github.com/iltGames/QuickItemSearch/releases) into `_forever_/Interface/AddOns`. The ZIP installs into the `QuickItemSearch` folder.

### Sources and drop rates

Quick Item Search uses [AtlasLoot Classic Forever](https://www.curseforge.com/wow/addons/atlasloot-forever) for dungeon and raid loot and [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) for NPCs, containers, vendors, and quest rewards. When Questie also provides a rate for a drop, Quick Item Search can use it where AtlasLoot has no rate.

The bundled index works on its own. Quick Item Search saves source details as you inspect results and uses that local backup when a provider has no matching entry or is unavailable. On a fresh install, sources appear as they are loaded from an installed provider. Rates only appear when a provider supplies one.

## Development

Edit the repository files and install the development copy with PowerShell:

```powershell
./scripts/Install-Dev.ps1 -AddOnsPath 'C:/Blizzard Games/World of Warcraft/_forever_/Interface/AddOns'
```

This installs **Quick Item Search (Dev)** in `AddOns/QuickItemSearchDev` with its own keybinding and `/qisdev` command. Enable either the dev or stable addon for the character you test with. Restart WoW to detect the dev addon the first time, then use `/reload` for subsequent edits.

## Releases

Bump the version in `QuickItemSearch.toc` and push to `main`. GitHub Actions packages the addon and publishes the matching version tag and ZIP. CurseForge's source packager uses the same repository and tagged versions. The package metadata keeps the stable folder named `QuickItemSearch`.

The MIT license covers the addon code. Item names and IDs are game data from Blizzard Entertainment.

