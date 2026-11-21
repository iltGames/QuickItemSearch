## Quick Item Search 0.4.17

- Clarify the name of the lookup table used to skip duplicate map pins.

## Quick Item Search 0.4.16

- Rename the emote alias loop counter to make its role in reading numbered WoW commands clearer.

## Quick Item Search 0.4.15

- Previous and next quest steps now show your faction and shared quests by default. Faction-specific steps display Alliance or Horde beside the step count. Enable **Show both factions in quest chains** in the search cog or AddOns settings to see both versions.

## Quick Item Search 0.4.14

- Find Heavy Mageweave Bandage, Runecloth Bandage, and Heavy Runecloth Bandage in item search and `craft fa`. Each recipe shows all four First Aid skill-up thresholds.
- Hover over a bandage or its recipe for the faction-specific Artisan First Aid route through Triage. The tooltip identifies the Classic route as unverified for recipe training in WoW Forever.

## Quick Item Search 0.4.13

- Search a profession name such as `First Aid` to see its recipes alongside item and trainer matches. `first aid crafting` also opens a recipe search.
- Quest details show the character's XP reward for quests in the quest log and labeled base XP when only QuestieDB data is available.
- Use the Back arrow or Backspace while navigating results to return to earlier searches. Quest reward items have a right-click action to search for the item.

## Quick Item Search 0.4.12

- Pressing Enter to open a result's actions menu highlights the first option immediately. Press Enter again to choose it.

## Quick Item Search 0.4.11

- Use the search cog for history and automatic result filters. Open the full AddOns settings directly from the cog.
- Expand or collapse quest chains, NPC loot, and vendor inventory in their detail views. Manage their default visibility and quest reward links in AddOns settings.
- Vendors show their known zones and sort by proximity when location data is available. Related result actions and map pins are available wherever supported.
- QuestieDB is now required. Install its Forever build to use Quick Item Search.

## Quick Item Search 0.4.10

- Restore gathering locations that Questie hides from its map display. Iron Deposit searches show the other indexed zones alongside Arathi Highlands.
- Click back into the search window to resume arrow-key navigation from the selected result or highlighted action.

## Quick Item Search 0.4.9

- Open a result's actions with right-click, Enter, or Right Arrow. Long menus scroll by wheel, scrollbar, or arrow keys. Left Arrow returns to the results, and clicking items or section headers moves the selection to that row.
- Follow related recipes, reagents, item sources, quest requirements and rewards, and gathering locations. Vendor results can show their zones and sort by proximity when location data is available.
- Add world map pins for NPCs, vendors, and quest contacts with known coordinates. When a target has multiple locations, choose the zone and coordinates.
- See pet training details and class spell unlock requirements in the actions menu. Item tooltips stay shorter because source, quest, and crafting details are available through related searches.

## Quick Item Search 0.4.8

- Search NPCs and mobs by name or ID with `@npc` or `@mob`. Select a result to see known zones and spawn coordinates, indexed loot, and items the NPC sells when available.
- Use the search cog or WoW AddOns settings to choose which result sections appear and how many searches History keeps.
- Open previous and next quests from quest details. Right-click items to find quests that require or reward them. You can turn off reward links in search options.

## Quick Item Search 0.4.7

- Show which quests require an item in search result tooltips when QuestieDB is enabled.
- Search quest names alongside items, or use `@quest` or `@q` to find quests by name or ID. Quest details show objectives, required items, item rewards, and live progress when available.
- Right-click a required item to open one of its quests.
- Find dungeons in the main search by name or abbreviation, then select a dungeon to open its loot.

## Quick Item Search 0.4.6

- Add `upgrade` to show gear with a higher item level than the equipped piece it could replace. Results show the item level and the increase.
- Exclude an indexed stat with `no`, as in `@me shield upgrade no sp`.
- Align the Examples popup's quick-insert buttons, add an Upgrade button, and show four queries that combine gear filters.

## Quick Item Search 0.4.5

- Use `@d`, `@dung`, or `@inst` for dungeon loot, `@t` for target loot, and `@gear` for your character's gear.
- Chain stat filters in a single gear search. For example, `@me chest stam sp` requires both Stamina and Spell Power. Use `def` for Defense.
- Browse `@me` results by equipment slot. Each slot lists plate first, followed by mail, leather, and cloth.
- Fixed the search window blocking movement keys after the search box lost focus.

## Quick Item Search 0.4.4

- With What's Training enabled, search `warlock 12` or `warrior 10` for spells unlocked at that exact level. Results distinguish trainer spells from quest rewards, with quest sources on hover.
- Browse any class with `spells warlock` or `warlock spell`. Class spell sections work without What's Training; enabling it adds known unlock levels and sources.
- Close the search window with its top-right close button.

## Quick Item Search 0.4.3

- Show a small note at the top of History explaining that only the last 10 searches are shown.

## Quick Item Search 0.4.2

- Browse all hunter pet spell ranks with `petspells`, `@petspells`, `petspell`, or `@petspell`. Add a name and rank to narrow the results, such as `@petspell bite 3`.

## Quick Item Search 0.4.1

- Search `@spell bite` for hunter pet abilities or `@spell bite 3` for a specific rank. Hover a result for the tameable beasts, their zones and wild levels, and the pet level required to train the ability.

## Quick Item Search 0.4.0

- Use `@target` for your current NPC's indexed drops or `@me` for gear around your level that matches your learned proficiencies.
- Use `@dungeon` or `@instance` with a full or partial dungeon name, or a common abbreviation such as `hot` or `brd`. Inside a dungeon or raid, omit the name to search the current instance.
- Dungeon results combine AtlasLoot and Forever Dungeon Journal where available. Loot is grouped by boss and Trash, with known boss levels and the dungeon level range. Results show rare-or-better items and uncommon-or-better recipes.
- Open **History** from the pocket-watch icon to rerun one of your 10 most recent searches. Open **Examples** from the book icon for sample queries and quick-insert buttons with hover tips.
- Use `wep` or `weapons` to find one-handed and two-handed melee weapons in one search.

## Quick Item Search 0.3.2

- Drag the bottom-right corner to set the search window width and the maximum number of visible result rows. The window fits smaller result sets and opens at its compact height when the search is empty.

## Quick Item Search 0.3.0

- Browse mixed results in expandable sections for items, recipes, spells, gathering, trainers, boss loot, and emotes. Items marked PTR Only are hidden.
- Find recipes with `craft`, `make`, and `enchant`. Filter by profession with queries such as `craft belt tailor` or use `stranglekelp usedin` to find recipes by reagent. Recipe and crafted item rows show their skill-up thresholds.
- Use `herb`, `gather ore`, or `mine copper vein` to see orange, yellow, green, and gray gathering thresholds. Search `skin 125` for skinnable mob levels or `bs train` for profession trainer locations.
- Use `spell thorns` to search player spell ranks, or `emote wave` to find and play the Wave emote.
- Hold Up or Down to scroll with acceleration. Press Enter to activate an arrow-selected result, including section controls. Enter releases the search field after typing so you can open chat.
- Use compact gear levels such as `lvl10`, `lv10-20`, or `level20`, alongside filters such as `boe`, `rare`, `agil`, and `hp`.
