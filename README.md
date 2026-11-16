# Quick Item Search

Press Ctrl+Shift+Space to open search when the chord is free. To change it, open **Options > AddOns > Quick Item Search**, click the hotkey, and press the new shortcut. The addon saves it in WoW's active keybinding set.

Use `/qis` to open search or `/qis linen cloth` to open it with a query. `/itemsearch` is also available.

Search by English item name, numeric ID, or pasted item link. Use Up and Down to browse results, scroll one row at a time with the mouse wheel, or drag the scrollbar on longer lists. Press Enter to activate an arrow-selected result or leave the search field after typing. Out of combat, you can keep using the arrows and Enter after activating a result. Hover for a tooltip, click to inspect, Shift-click to insert a link into open chat, or Ctrl-click to try on supported equipment. Escape closes the search overlay.

With AtlasLoot Classic Forever enabled, search for a boss by name to see its loot. Use `boss:<name>` to prioritize the boss's loot. Items marked **PTR Only** in the bundled client data are filtered out.

Search keywords such as `spell`, `craft`, `gather`, and `train` can go before, after, or between the words of the search. Try `arcanite craft transmute`, `rich mine thorium vein`, or `where can I first train aid 225?`. Use quotes around names that contain a keyword.

Enter an action keyword by itself to browse its results. Try `spell`, `craft`, `enchant`, `train`, `gather`, `pick`, `mine`, `skin`, `usedin`, or `emote`. Matching item names appear in an **Items** section above the action results, and adding a target narrows the lookup. Type `emote wave`, `wave`, or `/wave` to find the emote, then click its row to perform it.

### Spells and recipes

Type `spell thorns`, `thorns spell`, or `spell 467` to search the English class and racial spell index, including spells you haven't learned. When a query is also a gear stat, such as `spell power`, use `spell:power` to look up a spell by name. Hover for the spell tooltip, click to inspect, or Shift-click to link the spell in open chat.

Type `craft arcanite transmute` to see the recipe's Alchemy skill thresholds. Search by recipe name, crafted item name, or recipe spell ID. The four numbers show the starting skill, yellow, green, and gray. A question mark indicates an unknown starting skill. Crafted item rows show their recipe's thresholds, and hovering an item with several recipes lists each recipe.

Use `enchant gloves agil` or `gloves enchant agi` to find glove enchants that grant Agility. `enchant chest agil` also matches chest enchants that grant all primary stats.

Type `stranglekelp usedin`, `what is stranglekelp used in?`, or `usedin 3820` to find indexed recipes that consume the item as a reagent. Click a result to inspect the recipe spell.

### Gathering questions

Ask `what level can I gather Stranglekelp?` or type a partial name such as `gather strangle` or `strangle gather` to see the required profession skill and inspect the item. Use a node name such as `mine rich thor` for one node, or ask about `thorium ore` to see each indexed node's requirement. If multiple names match equally well, their requirements appear alongside the results. The bundled data covers common herbs and ores. Other materials can still appear as item results when their skill requirement is unknown.

Use `herb`, `gather herb`, `pick herbs`, or `harvest herbs` to list indexed herbs. Use `ore`, `gather ore`, `gather veins`, `gather deposits`, or `mine nodes` for mining, and `gather nodes` for both categories. Rows are sorted by required skill and show the orange, yellow, green, and gray thresholds. Gray is the point at which the node stops giving skill-ups. Vein variants have separate rows and link to the ore they yield.

`gather mine` also lists mining nodes. Plain resource searches such as `stranglekelp` show gathering thresholds alongside the item, with extra rows for distinct node variants when applicable.

Use `skin` or `gather skin` to see the highest skinnable mob levels by Skinning skill bracket. Add your exact skill, as in `skin 125`, to see the full eligible level range. Hover over a result for the estimated gray mob range.

When results span categories, each matching category gets its own section. Plain searches lead with matching items, and explicit searches such as `gather stranglekelp` lead with the requested category. Use **Show all items** or **Show all results** to expand a section.

### Trainer lookup

Use `train <profession>` to list training options from the bundled index for all 12 WoW Forever professions. Each row shows an NPC, location, rank, and faction. Hover for requirements and book or quest names. Add your current skill to narrow the list to the rank you need, as in `train blacksmithing 225`, `where to train alchemy 225`, or `train first aid 150`. Trainers who teach several ranks appear once in the full list under their highest rank.

Put `train` before or after the profession. Try `bs train`, `bs train 225`, or `bs 225 train`. Other aliases include `alch`, `blacksmith`, `cook`, `ench`, `eng`, `fa`, `firstaid`, `fish`, `herb`, `lw`, `mine`, `skin`, and `tailor`.

`Trainer` works too, as in `alchemy trainer`, `smithing trainer 225`, or `leather working trainer`.

### Gear search

Use the same search box to combine equipment slots, character levels, and item stats.

| Query | Matches |
| --- | --- |
| `rings from 10-12` | Rings that require level 10, 11, or 12. |
| `rings for lvl 20` | Rings that require level 15–22 with the default range. |
| `rings from 10-12 with agility` | Rings in that level range with positive Agility. |
| `rings with agility around 20` | Rings with +16 to +24 Agility, closest to +20 first. |
| `lvl 10 boss drop agil` | Gear that requires level 5–12 with the default range, grants Agility, and drops from a boss in AtlasLoot Classic Forever. |
| `rare boss:"Edwin VanCleef"` | Rare gear from a named boss in AtlasLoot Classic Forever. |
| `2h quest` | Two-handed weapons awarded by quests in QuestieDB or the local source backup. |
| `rare quest:"Test of Lore"` | Rare gear awarded by quests with the given title. |
| `rings with spell damage around 20` | Rings with +16 to +24 general Spell Damage, including shared Spell Power. |
| `lvl 60 boss drop healing power` | Boss drops in the level window with Healing Power or shared Spell Power. |
| `rings with hit` | Rings with Hit. |
| `lvl 25 2h wep` | Two-handed weapons that require level 20–27 with the default range. |
| `rare lvl 25 2h wep` | Only rare two-handed weapons in the required-level window. |
| `crafted 1h weapon lvl 25` | Crafted one-handed weapons in the required-level window, including main-hand and off-hand weapons. |
| `crafted` | Equipment made by a profession. |
| `crafted gloves lvl 40 with agility` | Crafted gloves with Agility in the required-level window. |
| `make belt agil mail` | Crafted mail belts that grant Agility. |
| `craft belt tailor` | Belts made with Tailoring. Use a profession name or alias with `craft` or `make`. |
| `lv10-20 pants leather` | Leather leg armor that requires level 10-20. |

A single level searches five levels below and two above by default. Change these offsets under **Options > AddOns > Quick Item Search**. Enter an explicit range such as `lvl 15-22` to use those bounds. The space is optional after `level`, `lvl`, or `lv`, so `lvl10`, `lv10`, and `level10-219` also work.

Filter gear by rarity with `poor`, `common`, `uncommon`, `rare`, `epic`, or `legendary`. Color names such as `green`, `blue`, and `purple` work too. You can use `rare`, `rarity rare`, or `quality rare`.

Use `boe` or `bind on equip` for Bind on Equip gear and `bop` or `bind on pickup` for Bind on Pickup gear. Combine either with other filters, as in `rare lvl25 two handed weapon bind on equip`. Common slot aliases include `necklace`, `amulet`, `shoulderpad`, `chestpiece`, `belts`, `bracer`, `glove`, and `cape`.

Use `boss`, `boss loot`, or `quest` before or after other filters. Add a name with `boss:<name>` or `quest:<title>`. Put quotes around quest titles and boss names with spaces when using gear filters, as shown above. Quest IDs work too, as in `quest:123 rare`. A standalone `boss:<name>` shows the boss's full loot table and accepts an unquoted name.

Primary stats accept `agi` or `agil`, `str`, `int`, `spi`, and `sta` or `stam`. Secondary filters include `spell power` (`sp`), `spell damage` (`spell dmg`), `healing power` (`hp`, `healing`), `hit`, `crit`, `haste`, `expertise`, `defense`, `dodge`, `parry`, `block`, `block value`, `attack power` (`ap`), `ranged attack power` (`rap`), `mp5`, `health regen`, `spell pen`, `armor pen`, `resilience`, `bonus armor`, and school resistances such as `fire res`.

`Around`, `near`, and `about` allow a 20% difference rounded down, with a minimum of two points. The index comes from the Forever client and its hotfixes. The game supplies stat amounts as item data loads. Filters use the indexed item stats. Separate equip effects, procs, and on-use abilities can appear in the tooltip outside that index.

`crafted`, `craftable`, and `handcrafted` use a bundled snapshot of Forever recipe output IDs from Crafting Path, limited to wearable gear and weapons. To refresh it after updating the gear index, run `node scripts/Generate-CraftedIndex.cjs <CraftingPath/Data>`.

Filter armor with `cloth`, `leather`, `mail` (or `chainmail`), or `plate`. You can include the word `armor` or `armour`, as in `lv10-20 pants leather armor`. Use `make` or `craft` with gear filters to look up the crafted items themselves. A recipe name such as `make arcanite transmute` still opens recipe search.

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

Run `lua tests/search.lua` from the repository root with Lua 5.1 to verify the parser and source filters. Refresh the recipe index with `node scripts/Generate-RecipeIndex.cjs <CraftingPath/Data>`.

## Releases

Update `CHANGELOG.md`, bump the version in `QuickItemSearch.toc`, and push to `main`. GitHub Actions publishes the matching version tag and ZIP. The CurseForge source packager uses the tagged version and the same changelog. The stable addon folder is named `QuickItemSearch`.

The MIT license covers the addon code. Item names and IDs are game data from Blizzard Entertainment.

