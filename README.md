# Quick Item Search

Press Ctrl+Shift+Space to open search when the chord is free. To change it, open **Options > AddOns > Quick Item Search**, click the hotkey, and press the new shortcut. The addon saves it in WoW's active keybinding set.

Use `/qis` to open search or `/qis linen cloth` to open it with a query. `/itemsearch` is also available.

Click the book icon beside the search box for **Examples**. Use **Target**, **Me**, or **Dungeon** to insert a shortcut, or add a level, boss, stat, crafted, or upgrade filter. The pocket-watch icon opens **History**, which by default keeps the last 10 searches you ran from a menu or slash command, confirmed with Enter, opened a result for, or left in the box when closing the window. Click a query in either menu to run it. Use the search cog or WoW AddOns settings to change the history limit and choose which result categories appear in a broad search. Select **Open AddOn Settings** in the cog popup to jump to the full settings page.

Search by English item name, numeric ID, or pasted item link. Press Enter after typing to run the search and move keyboard navigation to the results out of combat. Use Up and Down to browse results, scroll one row at a time with the mouse wheel, or drag the scrollbar on longer lists. On a selected result, Enter or Right opens the actions menu when available. Use Up and Down to browse the menu, Enter to choose, and Left to return to the results. Enter activates results that have no menu. Hover for a tooltip, click to inspect, Shift-click to insert a link into open chat, or Ctrl-click to try on supported equipment. Escape closes the current menu or the search overlay. Drag the bottom-right corner to resize the overlay. The window width and maximum number of visible rows are saved between sessions.

Right-click a result to follow its related searches. Use **Show item sources** for indexed drops, vendors, and containers, or enter `@sources <item ID>`. Vendors show their known zones and sort by proximity when location data is available. Stranglekelp links to recipes that use it, gathering requirements and known QuestieDB locations, and Herbalism trainers. Item menus also identify quests that require or reward the item. Turn off **Quest reward links** in WoW AddOns settings to show only quests that require it.

Use **Add map pin** on an NPC, mob, vendor, or quest contact with known QuestieDB coordinates. Right-click a quest result to pin its starting location. Choose a zone and coordinates when there are several matches. Each pin replaces the previous Quick Item Search marker or sets WoW's user waypoint when available. Right-click a Quick Item Search marker on the world map to remove it.

With AtlasLoot Classic Forever enabled, search for a boss by name to see its loot. Use `boss:<name>` to prioritize the boss's loot. Items marked **PTR Only** in the bundled client data are filtered out.

Target an NPC and type `@target` or `@t` to see its indexed drops from AtlasLoot and QuestieDB. The results update when you switch targets while that query is open.

Regular name searches can include an **NPCs and Mobs** section. Use `@npc hogger` or `@mob hogger` to search only creatures, then select a match to see its known zones and spawn coordinates. Use `@npc 448` to open a known NPC ID directly. You can hide the automatic section in the search window's cog menu or the addon's WoW settings and still use both shortcuts.

NPC details include a **Loot** section when QuestieDB, AtlasLoot, or Forever Dungeon Journal has indexed drops. The **Sells** section lists items QuestieDB associates with the vendor. Hover an item for its tooltip or click it to inspect. Check the merchant window for prices and current stock.

Click **Loot** or **Sells** to collapse or expand it. Use **NPC Loot** and **Vendor Items** in WoW AddOns settings to control whether those sections appear.

A plain search like `pie` includes matching names under **Quests**. Use `@quest` or `@q` to search only quest names, or use `@quest 86` to open a quest directly. Select a quest to see its zone, start and turn-in contacts, objectives, and indexed item rewards. Hover or click the required and reward items to inspect them. Right-click any required item in the search results to open one of the quests that uses it. Quests in your log also show live objective progress when the game provides it.

Select a quest under **Previous quests** or **Next quests** to open its details. Both lists show the closest links first, with labels for how many steps each quest is from the one you're viewing. Click either heading to collapse or expand the list. Both visibility options are under **Detail view sections** in WoW AddOns settings.

Search for a partial name or abbreviation like `zul farrak`, `zf`, or `brd` and click a match under **Dungeons** to open its loot view. Use `@dungeon`, `@instance`, `@d`, `@dung`, or `@inst` to go straight to loot from AtlasLoot and Forever Dungeon Journal. These shortcuts accept the same names and abbreviations. `dm` includes both Deadmines and Dire Maul. Omit the name after a shortcut to look up your current dungeon or raid. Drops are grouped by boss, with a separate Trash section when available. The summary shows the instance level range and boss headings show levels when known. Results show rare-or-better items and uncommon-or-better recipes.

Search keywords such as `spell`, `craft`, `gather`, and `train` can go before, after, or between the words of the search. Try `arcanite craft transmute`, `rich mine thorium vein`, or `where can I first train aid 225?`. Use quotes around names that contain a keyword.

Enter an action keyword by itself to browse its results. Try `spell`, `craft`, `enchant`, `train`, `gather`, `pick`, `mine`, `skin`, `usedin`, or `emote`. Matching item names appear in an **Items** section above the action results, and adding a target narrows the lookup. Type `emote wave`, `wave`, or `/wave` to find the emote, then click its row to perform it.

### Spells and recipes

Type `spell thorns`, `thorns spell`, or `spell 467` to search the English class and racial spell index, including spells you haven't learned. When a query is also a gear stat, such as `spell power`, use `spell:power` to look up a spell by name. Hover for the spell tooltip, click to inspect, or Shift-click to link the spell in open chat.

With **What's Training** installed and enabled, type `warlock 12`, `warrior 10`, or `spell warrior 10` to see player spells unlocked at that exact level, including new ranks. Results show **Trainer** or **Quest**. Open **How to learn** from the spell's actions menu for requirements, areas, and related quests. QuestieDB supplies quest names and links when available. Quest levels are minimum quest requirements. This requires a version of What's Training with the class catalog API. Unlock data is read from that addon at runtime and is never bundled or saved by Quick Item Search.

Use `spells warlock`, `warlock spell`, or either word order with any of the nine classes to browse that class's full spell list in its own section. What's Training adds unlock levels and trainer or quest sources where it has data. Without What's Training, class browsing uses the client-generated spell index. Spells outside the provider's catalog remain visible in the full list.

Search `@spell bite` for hunter pet ability ranks or `@spell bite 3` for a specific rank. Click or right-click a **Hunter pet** result to see the required pet level and the beasts that teach the ability, with their wild levels and zones. Select a beast to look up its locations. Taming data comes from [Petopia Forever](https://www.wow-petopia.com/forever/abilities.php).

Use `petspells` or `@petspells` to browse all hunter pet abilities. The singular forms `petspell` and `@petspell` work too. Add a name and optional rank to filter, such as `@petspell bite 3`.

Type `craft arcanite transmute` to see the recipe's Alchemy skill thresholds. Search by recipe name, crafted item name, or recipe spell ID. The four numbers show the starting skill, yellow, green, and gray. A question mark indicates an unknown starting skill. On a crafted item, **Show how to craft this** lists its recipes and their thresholds.

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

Use `wep`, `weps`, `weapon`, or `weapons` for both one-handed and two-handed melee weapons. Add `1h` or `2h` to narrow the search, or use `@me wep` to apply your character's level and proficiencies.

Try `@me`, `@gear`, or `my gear` to find gear around your character's current level. The search uses your configured level offsets and learned armor and weapon proficiencies. Results are grouped by equipment slot, with plate, mail, leather, then cloth within each slot. Type a slot to show only that section, such as `@me helm`, `@me chest`, or `@me legs`. Check item tooltips for individual requirements such as class, faction, or reputation.

Use the same search box to combine equipment slots, character levels, and item stats. Space-separated stats must all be present. Add `near` or `around` after a stat to filter its amount. When you specify several amounts, results are ranked by the sum of their differences from those amounts, within each armor type for character gear.

Put `no` before a stat or its abbreviation to exclude gear with that indexed stat. Both `@me shield upgrade no sp` and `@me no sp shield upgrade` find shield upgrades without Spell Power. Repeat `no` for each stat you want to exclude, as in `shield no sp no intellect`.

Add `upgrade` or click **Upgrade** in **Examples** to compare gear's base item level with the actual item level of the equipped piece it could replace. For rings, trinkets, and one-handed weapons you can replace in either hand, the comparison uses the lower equipped item level. A slot needs an equipped item to compare against. Try `@me chest upgrade` or `rings upgrade lvl 40`. Results show the item's level and the increase.

| Query | Matches |
| --- | --- |
| `rings from 10-12` | Rings that require level 10, 11, or 12. |
| `rings for lvl 20` | Rings that require level 15–22 with the default range. |
| `rings from 10-12 with agility` | Rings in that level range with positive Agility. |
| `rings with agility around 20` | Rings with +16 to +24 Agility, closest to +20 first. |
| `@me chest stam sp` | Chest gear for your character with both Stamina and Spell Power. |
| `chest stamina near 10 spell power near 20` | Chest gear close to both +10 Stamina and +20 Spell Power. |
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

Primary stats accept `agi` or `agil`, `str`, `int`, `spi`, and `sta` or `stam`. Secondary filters include `spell power` (`sp`), `spell damage` (`spell dmg`), `healing power` (`hp`, `healing`), `hit`, `crit`, `haste`, `expertise`, `defense` (`def`), `dodge`, `parry`, `block`, `block value`, `attack power` (`ap`), `ranged attack power` (`rap`), `mp5`, `health regen`, `spell pen`, `armor pen`, `resilience`, `bonus armor`, and school resistances such as `fire res`.

`Around`, `near`, and `about` allow a 20% difference rounded down, with a minimum of two points. The index comes from the Forever client and its hotfixes. The game supplies stat amounts as item data loads. Filters use the indexed item stats. Separate equip effects, procs, and on-use abilities can appear in the tooltip outside that index.

`crafted`, `craftable`, and `handcrafted` use a bundled snapshot of Forever recipe output IDs from Crafting Path, limited to wearable gear and weapons. To refresh it after updating the gear index, run `node scripts/Generate-CraftedIndex.cjs <CraftingPath/Data>`.

Filter armor with `cloth`, `leather`, `mail` (or `chainmail`), or `plate`. You can include the word `armor` or `armour`, as in `lv10-20 pants leather armor`. Use `make` or `craft` with gear filters to look up the crafted items themselves. A recipe name such as `make arcanite transmute` still opens recipe search.

Drag the grip at the top of the overlay to move it. Quick Item Search remembers the position across reloads.

The bundled index contains 24,565 names from the English ItemSparse table installed with WoW Forever 1.60.1.70938 and that build's locally received item hotfixes. The game supplies tooltips, item links, and icons. The index can include internal or unobtainable items. Future or server-only items missing from the snapshot can still be queried by ID or link when the game exposes them.

## Installation

Install through [CurseForge](https://www.curseforge.com/wow/addons/quick-item-search), or extract the ZIP from [GitHub Releases](https://github.com/iltGames/QuickItemSearch/releases) into `_forever_/Interface/AddOns`. The ZIP installs into the `QuickItemSearch` folder.

[QuestieDB](https://www.curseforge.com/wow/addons/questiedb) is required. Use its Forever build and enable it for the characters that use Quick Item Search. If WoW reports a missing dependency even though QuestieDB is installed, check that its folder contains `QuestieDB_Camelot.toc`. The [QuestieDB GitHub releases](https://github.com/Questie/QuestieDB/releases) offer Forever builds with this compatibility file.

### Sources and drop rates

Quick Item Search uses [AtlasLoot Classic Forever](https://www.curseforge.com/wow/addons/atlasloot-forever) for dungeon and raid loot and [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) for NPCs, containers, vendors, and quest rewards. When Questie also provides a rate for a drop, Quick Item Search can use it where AtlasLoot has no rate.

The addon includes its own item index. Quick Item Search saves source details as you inspect results and uses that local backup when a provider has no matching entry or is unavailable. On a fresh install, sources appear as they are loaded from an installed provider. Rates only appear when a provider supplies one.

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

