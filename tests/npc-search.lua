local addon = { index = { [1] = "River Wolf Pelt", [2] = "Wolf Claw", [8] = "Vendor Bread" },
    ptrOnly = { [3] = true } }
assert(loadfile("Search.lua"))("QuickItemSearch", addon)
assert(loadfile("Sources.lua"))("QuickItemSearch", addon)
assert(loadfile("NpcSearch.lua"))("QuickItemSearch", addon)

local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
function C_Timer.NewTimer(delay, callback)
    local cancelled
    C_Timer.After(delay, function() if not cancelled then callback() end end)
    return { Cancel = function() cancelled = true end }
end
local function RunTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

local npcs = {
    [10] = { name = "River Wolf", spawns = { [12] = { { 52.5, 40 }, { 52.5, 40, 1 }, { 65, 42 } },
        [40] = { { -1, -1 } } } },
    [20] = { name = "River Wolf Pup", zoneID = 12 },
    [30] = { name = "Old River Wolf", waypoints = { [12] = { { { 1, 2 }, { 3, 4 } } } } },
    [40] = { name = "No Location" },
}
local function Entity(records, ids)
    return {
        GetAllIds = function() return ids end,
        Get = function(id, field) return records[id] and records[id][field] end,
    }
end
LibQuestieDB = {
    Npc = Entity(npcs, { 20, 30, 10, 40 }),
    Quest = Entity({ [99] = { name = "Find the River Wolf" } }, { 99 }),
}
C_Map = { GetAreaInfo = function(id) return ({ [12] = "Elwynn Forest", [40] = "Westfall" })[id] end }
assert(loadfile("QuestSearch.lua"))("QuickItemSearch", addon)
local function FindSection(sections, title)
    for _, section in ipairs(sections or {}) do
        if section.title == title then return section.rows end
    end
end

local rows, hint = addon.Search("@mob 10")
assert(hint and hint:find("River Wolf", 1, true), "A mob ID should open its location details")
assert(#rows == 3 and rows[1].name == "Elwynn Forest" and rows[1].matchLabel == "52.5, 40.0")
assert(rows[2].name == "Elwynn Forest" and rows[2].matchLabel == "65.0, 42.0")
assert(rows[3].name == "Westfall" and not rows[3].matchLabel, "A placeholder should show only its zone")
assert(addon.Search("@npc 20")[1].name == "Elwynn Forest")
assert(addon.Search("@npc 30")[1].name == "Elwynn Forest")
local _, missing = addon.Search("@npc 40")
assert(missing:find("No known locations.", 1, true))
assert(select(2, addon.Search("@npc 999")) == "No NPC or mob found with that ID.")

LibQuestieDB.Item = Entity({
    [1] = { npcDrops = { 10, 10 }, vendors = { 10 } }, [2] = { npcDrops = { 10 } },
    [3] = { npcDrops = { 10 }, vendors = { 10 } }, [4] = { npcDrops = { 20, 40 } },
    [8] = { vendors = { 10, 10 } }, [9] = { vendors = { 20 } },
}, { 1, 2, 3, 4, 8, 9 })
ForeverDungeonJournal_NS = { DB = { TestDungeon = { bosses = {
    { npcID = 10, name = "River Wolf", loot = { { 1 }, { 5, "Journal Trinket", "Trinket", 3 } } },
    { npcID = 20, name = "River Wolf", loot = { { 6 } } },
    { npcID = 10, name = "Trash Drops", trash = true, loot = { { 7 } } },
} } } }
local _, _, loadLoot, _, immediateSections = addon.Search("@npc 10")
assert(loadLoot, "NPC details should load QuestieDB drops")
assert(#FindSection(immediateSections, "Loot") == 2, "Journal loot should appear during the lookup")
local loot, locations, sold
loadLoot(function(found, _, _, _, sections)
    assert(sections.title == "Locations")
    locations, loot = found, FindSection(sections, "Loot")
    sold = FindSection(sections, "Sells")
end)
RunTimers()
assert(#locations == 3 and #loot == 3, "Merge and deduplicate drops while keeping all locations")
assert(loot[1].id == 5 and loot[1].name == "Journal Trinket" and loot[1].quality == 3)
assert(loot[2].id == 1 and loot[3].id == 2 and not loot[2].kind, "Drops should be ordinary item rows")
assert(sold and #sold == 2 and sold[1].id == 1 and sold[2].id == 8 and not sold[2].kind,
    "Show distinct items sold by the selected NPC as ordinary item rows")
local _, _, loadWithoutLocations = addon.Search("@npc 40")
loadWithoutLocations(function(found, title, _, _, sections)
    assert(#found == 1 and found[1].id == 4 and sections.title == "Loot")
    assert(title:find("No known locations.", 1, true))
end)
local _, _, loadNoLoot = addon.Search("@npc 30")
loadNoLoot(function(found, _, _, _, sections)
    assert(#found == 1 and not sections, "Skip the loot section when there are no known drops")
end)
RunTimers()
QuickItemSearchSettings = { hiddenSections = { ["NPC Loot"] = true } }
local _, _, vendorsOnly = addon.Search("@npc 10")
assert(vendorsOnly, "Disabling loot must leave vendor inventory available")
vendorsOnly(function(_, _, _, _, sections)
    assert(not FindSection(sections, "Loot") and #FindSection(sections, "Sells") == 2)
end)
RunTimers()
QuickItemSearchSettings.hiddenSections["Vendor Items"] = true
local onlyLocations, _, skippedLoot, _, hiddenLoot = addon.Search("@npc 10")
assert(#onlyLocations == 3 and not skippedLoot and not hiddenLoot, "Both toggles off should skip the item lookup")
QuickItemSearchSettings.hiddenSections["NPC Loot"] = nil
local _, _, lootOnly = addon.Search("@npc 10")
lootOnly(function(_, _, _, _, sections)
    assert(#FindSection(sections, "Loot") == 3 and not FindSection(sections, "Sells"))
end)
RunTimers()
QuickItemSearchSettings, ForeverDungeonJournal_NS, LibQuestieDB.Item = nil, nil, nil

local _, _, cancelled = addon.Search('@NPC "river wolf"')
local cancel = cancelled(function() error("Cancelled NPC search delivered results") end)
cancel()
local initial, _, load = addon.Search("river wolf")
assert(initial[1].name == "River Wolf Pelt" and load, "Show items while creature and quest names load")
local sections
load(function(_, _, _, _, found) sections = found end)
RunTimers()
assert(FindSection(sections, "Quests")[1].id == 99, "Loading NPCs should preserve quest matches")
local creatures = FindSection(sections, "NPCs and Mobs")
assert(#creatures == 3 and creatures[1].id == 10 and creatures[2].id == 20 and creatures[3].id == 30)
assert(creatures[1].kind == "npc")

QuickItemSearchSettings = { hiddenSections = { ["NPCs and Mobs"] = true } }
local _, _, _, _, hiddenSections = addon.Search("river wolf")
assert(not FindSection(hiddenSections, "NPCs and Mobs"))
assert(addon.Search("@npc river wolf")[1].id == 10, "Direct searches work with automatic matches disabled")
LibQuestieDB = nil
assert(select(2, addon.Search("@npc river wolf")):find("QuestieDB", 1, true))
print("NPC search tests passed")
