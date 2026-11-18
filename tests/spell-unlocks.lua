local addon = { index = {}, playerSpells = { [467] = "Thorns", [686] = "Shadow Bolt", [9999] = "Talent Spell" },
    classSpells = { WARLOCK = {686, 9999}, WARRIOR = {71, 100, 6546, 72} } }
for _, file in ipairs({ "Search", "SpellSearch" }) do
    assert(loadfile(file .. ".lua"))("QuickItemSearch", addon)
end

local rows, hint = addon.Search("warlock 12")
assert(#rows == 0 and hint and hint:find("What's Training", 1, true), "Missing provider should explain how to enable unlock searches")
for _, query in ipairs({ "spells warlock", "warlock spell", "warlock spells", "spell:warlock", "@spells warlock" }) do
    local result, message, _, _, sections = addon.Search(query)
    assert(#result == 2 and sections and sections.title == "Warlock Spells", query .. " should browse a class section without a provider")
    assert(result[1].id == 686 and not result[1].unlockLevel, "Fallback must only show this class's spells without guessed unlock metadata")
    assert(message and message:find("What's Training", 1, true))
end

local ready, callbacks = true, {}
WT_API = {
    GetCatalog = function(token)
        if token == "WARLOCK" then return { { id = 705, name = "Shadow Bolt", subText = "Rank 3", level = 12, kind = "trainer" } } end
        if token ~= "WARRIOR" then return nil end
        return {
            { id = 100, name = ready and "Charge" or nil, subText = "Rank 1", level = 4, kind = "trainer" },
            { id = 6546, name = ready and "Rend" or nil, subText = "Rank 2", level = 10, kind = "trainer" },
            { id = 71, name = "Defensive Stance", level = 10, kind = "quest", quest = {
                { level = 10, races = {1}, areas = {1519}, quests = {1665} },
                { level = 12, races = {2}, areas = {17}, quests = {1498} },
            } },
            { id = 72, name = "Shield Bash", level = 12, kind = "trainer" },
            { id = 999, name = "Pet ability", level = 10, kind = "trainer", petAbility = true },
        }
    end,
    IsClassReady = function() return ready end,
    LoadClass = function() return ready end,
    RegisterCallback = function(owner, event, fn) callbacks[owner] = fn end,
    UnregisterCallback = function(owner) callbacks[owner] = nil end,
}

for _, query in ipairs({ "spells warrior", "warrior spell" }) do
    local result, _, _, _, sections = addon.Search(query)
    assert(#result == 4 and sections.title == "Warrior Spells", "Class browse should include every level")
    local byID = {}
    for _, row in ipairs(result) do byID[row.id] = row end
    assert(byID[71].unlockSource == "Quest" and #byID[71].unlockQuests == 2, "Class browse must preserve all quest variants")
    assert(byID[6546].unlockLevel == 10 and byID[72].unlockLevel == 12)
end
local catalog = addon.Search("warlock spells")
assert(#catalog == 3, "Spells absent from the trainer catalog must remain in the full class list")

local realGetCatalog = WT_API.GetCatalog
for _, class in ipairs({ "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }) do
    WT_API.GetCatalog = function(token)
        assert(token == class:upper(), "Each class name must request its own catalog")
        return { { id = 123, name = class .. " spell", kind = "trainer", level = 8 } }
    end
    for _, query in ipairs({ "spells " .. class, class .. " spell" }) do
        local result, _, _, _, sections = addon.Search(query)
        assert(#result > 0 and sections and sections.title == class:gsub("^%l", string.upper) .. " Spells")
    end
end
WT_API.GetCatalog = realGetCatalog

for _, query in ipairs({ "warrior 10", "spell warrior 10", "@spell warrior 10", "WARRIOR   10" }) do
    rows = addon.Search(query)
    assert(#rows == 2, query .. " should only return player spells at level 10")
    local byID = {}
    for _, row in ipairs(rows) do byID[row.id] = row end
    assert(byID[6546].name:find("Rank 2", 1, true) and byID[6546].matchLabel:find("Trainer", 1, true))
    assert(byID[71].matchLabel:find("Quest", 1, true) and #byID[71].unlockQuests == 1)
    assert(byID[71].unlockQuests[1].quests[1] == 1665, "Only quest variants at the requested level belong in the result")
end
rows = addon.Search("warrior 12")
assert(#rows == 2, "Quest variants with a later unlock must remain searchable")
rows = addon.Search("warlock 12")
assert(#rows == 1 and rows[1].id == 705, "Query must select the requested class")
local questRows = addon.Search("warrior 10")
local questEntry
for _, row in ipairs(questRows) do if row.id == 71 then questEntry = row end end
local lines = {}
local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
LibQuestieDB = { Quest = { Get = function(id, field)
    if id == 1665 and field == "name" then return "Bartleby the Drunk" end
end } }
GetAreaInfo = function(id) if id == 1519 then return "Stormwind City" end end
C_CreatureInfo = { GetRaceInfo = function(id) if id == 1 then return { raceName = "Human" } end end }
local unlockMenu = addon.GetResultRelatedQueries(questEntry)[1]
assert(unlockMenu and unlockMenu.name == "How to learn" and unlockMenu.submenu,
    "Class spell unlock details should have their own menu")
local learnedQuest
for _, choice in ipairs(unlockMenu.submenu) do
    if choice.query == "@quest 1665" then learnedQuest = choice end
end
assert(learnedQuest and learnedQuest.name:find("Bartleby the Drunk", 1, true),
    "The unlock menu should link to the known quest")
addon.AppendSpellUnlockSources(tooltip, questEntry)
local details = table.concat(lines, "\n")
assert(details:find("Bartleby the Drunk", 1, true), "The fallback tooltip should name known unlock quests")
assert(details:find("Stormwind City", 1, true) and details:find("Human", 1, true), "Quest variants should show area and race restrictions")
LibQuestieDB, GetAreaInfo, C_CreatureInfo = nil, nil, nil
lines = {}
addon.AppendSpellUnlockSources(tooltip, questEntry)
details = table.concat(lines, "\n")
assert(details:find("Quest 1665", 1, true) and details:find("Area 1519", 1, true), "Quest sources should remain visible without optional names")
rows = addon.Search("spell thorns")
assert(#rows == 1 and rows[1].id == 467, "Existing spell searches must remain independent")
rows, hint = addon.Search("warrior 0")
assert(#rows == 0 and hint and hint:find("level"), "Invalid levels should have a useful hint")

ready = false
local load
rows, hint, load = addon.Search("warrior 10")
assert(type(load) == "function", "Uncached names should use asynchronous search completion")
local completed
local cancel = load(function(result) completed = result end)
for _, fn in pairs(callbacks) do fn("ClassReady", "WARLOCK") end
assert(not completed, "Other classes finishing must not complete this lookup")
ready = true
for _, fn in pairs(callbacks) do fn("ClassReady", "WARRIOR") end
assert(completed and #completed == 2 and not next(callbacks), "Matching completion should refresh and unregister")
ready = false
local browseSections
rows, hint, load = addon.Search("warrior spells")
load(function(result, _, _, _, sections) completed, browseSections = result, sections end)
ready = true
for _, fn in pairs(callbacks) do fn("ClassReady", "WARRIOR") end
assert(#completed == 4 and browseSections.title == "Warrior Spells", "Async class browsing should retain its section and enriched rows")
ready = false
rows, hint, load = addon.Search("warrior 10")
cancel = load(function() error("Cancelled search completed") end)
local late
for _, fn in pairs(callbacks) do late = fn end
cancel()
late("ClassReady", "WARRIOR")
assert(not next(callbacks), "Cancellation should unregister the callback")

WT_API.LoadClass = function() error("Unavailable") end
rows, hint, load = addon.Search("warrior 10")
local failedHint
load(function(result, message) assert(#result == 0); failedHint = message end)
assert(failedHint and not next(callbacks), "Failed provider loads should report a hint and remove the callback")

WT_API = {}
rows, hint = addon.Search("warrior 10")
assert(#rows == 0 and hint and hint:find("What's Training", 1, true), "Older providers should fail gracefully")
rows = addon.Search("warlock spells")
assert(#rows == 2 and not rows[1].unlockSource, "Older providers should still allow plain class browsing")

-- Check real client-generated class associations, independently of the small
-- provider fixtures above. These spells must not leak into another class.
local index = {}
assert(loadfile("SpellIndex.lua"))("QuickItemSearch", index)
local representative = { WARRIOR = 355, PALADIN = 635, HUNTER = 75, ROGUE = 53,
    PRIEST = 17, SHAMAN = 331, MAGE = 116, WARLOCK = 697, DRUID = 467 }
for token, id in pairs(representative) do
    local found = false
    for _, spellID in ipairs(index.classSpells[token]) do
        assert(index.playerSpells[spellID], "Every class entry must have a spell name")
        if spellID == id then found = true end
        for other, otherID in pairs(representative) do
            assert(other == token or spellID ~= otherID, "Class-only spells must not leak into " .. token)
        end
    end
    assert(found, token .. " must include its representative spell")
end
print("Spell unlock tests passed")

