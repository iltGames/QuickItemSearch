# Quick Item Search

Press Ctrl+Shift+Space to open search when the chord is free. To change it, open **Options > AddOns > Quick Item Search**, click the hotkey, and press the new shortcut. The addon saves it in WoW's active keybinding set.

Use `/qis` to open search or `/qis linen cloth` to open it with a query. `/itemsearch` is also available.

Search by English item name, numeric ID, or pasted item link. Use Up and Down to browse results, scroll one row at a time with the mouse wheel, or drag the scrollbar on longer lists. Enter inspects the selected result and releases the search box so you can open chat while the results stay visible. Hover for a tooltip, click to inspect, Shift-click to insert a link into open chat, or Ctrl-click to try on supported equipment. Escape closes the search overlay.

With AtlasLoot Classic Forever enabled, search for a boss by name to see its loot. Use `boss:<name>` to search only for bosses, including when a partial name also matches items.

### Player spells

Type `player spell thorns` or `player spell 467` to search the English class and racial spell index. The index comes from the Forever client and its hotfixes and includes spells your character hasn't learned. Hover for the spell tooltip, press Enter or click to inspect, or Shift-click to link the spell in open chat.

### Gathering questions

Ask `what level can I gather Stranglekelp?` or type a partial name such as `gather strangle` to see the required profession skill and inspect the item. Use a node name such as `mine rich thor` for one node, or ask about `thorium ore` to see each indexed node's requirement. If multiple names match equally well, their requirements appear alongside the results. The bundled data covers common herbs and ores. Other materials can still appear as item results when their skill requirement is unknown.

### Gear search

Use the same search box to combine equipment slots, character levels, and item stats.

| Query | Matches |
| --- | --- |
| `rings from 10-12` | Rings that require level 10, 11, or 12. |
| `rings for lvl 20` | Rings that require level 15–22 with the default range. |
| `rings from 10-12 with agility` | Rings in that level range with positive Agility. |
| `rings with agility around 20` | Rings with +16 to +24 Agility, closest to +20 first. |
| `lvl 10 boss drop agil` | Gear that requires level 5–12 with the default range, grants Agility, and drops from a boss in AtlasLoot Classic Forever. |
| `rings with spell damage around 20` | Rings with +16 to +24 general Spell Damage, including shared Spell Power. |
| `lvl 60 boss drop healing power` | Boss drops in the level window with Healing Power or shared Spell Power. |
| `rings with hit` | Rings with Hit. |
| `lvl 25 2h wep` | Two-handed weapons that require level 20–27 with the default range. |
| `rare lvl 25 2h wep` | Only rare two-handed weapons in the required-level window. |
| `crafted 1h weapon lvl 25` | Crafted one-handed weapons in the required-level window, including main-hand and off-hand weapons. |
| `crafted` | Equipment made by a profession. |
| `crafted gloves lvl 40 with agility` | Crafted gloves with Agility in the required-level window. |

A single level searches five levels below and two above by default. Change these offsets under **Options > AddOns > Quick Item Search**. Enter an explicit range such as `lvl 15-22` to use those bounds.

Filter gear by rarity with `poor`, `common`, `uncommon`, `rare`, `epic`, or `legendary`. Color names such as `green`, `blue`, and `purple` work too.

Use `boe` for Bind on Equip gear or `bop` for Bind on Pickup gear. Combine either with other filters, as in `rare lvl 25 2h wep boe`.

Primary stats accept `agi` or `agil`, `str`, `int`, `spi`, and `sta` or `stam`. Secondary filters include `spell power` (`sp`), `spell damage` (`spell dmg`), `healing power` (`hp`, `healing`), `hit`, `crit`, `haste`, `expertise`, `defense`, `dodge`, `parry`, `block`, `block value`, `attack power` (`ap`), `ranged attack power` (`rap`), `mp5`, `health regen`, `spell pen`, `armor pen`, `resilience`, `bonus armor`, and school resistances such as `fire res`.

`Around` and `near` allow a 20% difference rounded down, with a minimum of two points. The index comes from the Forever client and its hotfixes. The game supplies stat amounts as item data loads. Filters use the indexed item stats. Separate equip effects, procs, and on-use abilities can appear in the tooltip outside that index.

`crafted` (or `craftable`) uses a bundled snapshot of Forever recipe output IDs from Crafting Path, limited to wearable gear and weapons. To refresh it after updating the gear index, run `node scripts/Generate-CraftedIndex.cjs <CraftingPath/Data>`.

Drag the grip at the top of the overlay to move it. Quick Item Search remembers the position across reloads.

The bundled index contains 24,565 names from the English ItemSparse table installed with WoW Forever 1.60.1.70938 and that build's locally received item hotfixes. The game supplies tooltips, item links, and icons. The index can include internal or unobtainable items. Future or server-only items missing from the snapshot can still be queried by ID or link when the game exposes them.

## Installation

Install through [CurseForge](https://www.curseforge.com/wow/addons/quick-item-search), or extract the ZIP from [GitHub Releases](https://github.com/iltGames/QuickItemSearch/releases) into `_forever_/Interface/AddOns`. The ZIP installs into the `QuickItemSearch` folder.

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

Update `CHANGELOG.md`, bump the version in `QuickItemSearch.toc`, and push to `main`. GitHub Actions publishes the matching version tag and ZIP. The CurseForge source packager uses the tagged version and the same changelog. The stable addon folder is named `QuickItemSearch`.

The MIT license covers the addon code. Item names and IDs are game data from Blizzard Entertainment.

