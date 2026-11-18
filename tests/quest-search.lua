local addon = { index = { [1] = "Meat Pie" } }
assert(loadfile("Search.lua"))("QuickItemSearch", addon)
assert(loadfile("QuestSearch.lua"))("QuickItemSearch", addon)

local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function RunTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

local quests = {
    [86] = {
        name = "Pie for Billy", requiredLevel = 5, zoneOrSort = 12,
        startedBy = { { 247 } }, finishedBy = { { 246 } },
        objectivesText = { "Bring 4 Chunks of Boar Meat to Auntie Bernice Stonefield." },
        objectives = { [3] = { { 769 } } }, requiredSourceItems = { 769, 117 },
    },
    [87] = {
        name = "A Pie for Billy",
        objectives = { { { 247, "Speak to Billy" } }, nil, { { 117, "Bring 2 pieces of jerky" } }, { 72, 3000 } },
    },
    [88] = { name = "Pie for Billy Again" },
}
local items = {
    [117] = { name = "Tough Jerky" },
    [769] = { name = "Chunk of Boar Meat" },
    [789] = { name = "Reward", questRewards = { 86, 86 } },
}
LibQuestieDB = {
    Quest = {
        GetAllIds = function() return { 86, 87, 88 } end,
        Get = function(id, field) return quests[id] and quests[id][field] end,
    },
    Item = {
        GetAllIds = function() return { 117, 769, 789 } end,
        Get = function(id, field) return items[id] and items[id][field] end,
    },
    Npc = { Get = function(id) return id == 247 and "Billy Maclure" or "Auntie Bernice Stonefield" end },
}
GetAreaInfo = function(id) if id == 12 then return "Elwynn Forest" end end
GetFactionInfoByID = function(id) if id == 72 then return "Stormwind" end end

local mixed, _, loadMixed = addon.Search("pie")
assert(mixed[1].name == "Meat Pie" and loadMixed, "Item results should appear while quest names load")
local mixedSections
loadMixed(function(found, _, _, _, sections) mixed, mixedSections = found, sections end)
RunTimers()
assert(mixed[1].name == "Meat Pie" and mixedSections.title == "Items")
assert(mixedSections[1].title == "Quests" and mixedSections[1].rows[1].name == "Pie for Billy")

-- A new provider exercises cancellation while the title index is still loading.
local questDB = LibQuestieDB.Quest
LibQuestieDB.Quest = { Get = questDB.Get, GetAllIds = questDB.GetAllIds }
local rows, message, load = addon.Search(" @QUEST \"pie for billy\" ")
assert(#rows == 0 and load, "The quest title index should load in batches")
local cancel = load(function() error("A cancelled quest search must not replace newer results") end)
cancel()
local _, _, loadLatest = addon.Search("@quest pie for billy")
loadLatest(function(found) rows = found end)
RunTimers()
assert(#rows == 3 and rows[1].id == 86 and rows[2].id == 88 and rows[3].id == 87,
    "Quest search must rank exact, prefix, and substring matches")
assert(rows[1].kind == "quest")
assert(addon.Search("@q pie")[1].kind == "quest", "@q should find quests by title")

rows, message, load = addon.Search("@quest 86")
assert(message:find("Pie for Billy", 1, true) and message:find("Elwynn Forest", 1, true))
local function Find(found, predicate)
    for _, row in ipairs(found) do
        if predicate(row) then return row end
    end
end
local function FindName(name)
    return Find(rows, function(row) return row.name == name end)
end
assert(FindName("Billy Maclure").matchLabel == "Starts quest")
assert(FindName("Auntie Bernice Stonefield").matchLabel == "Turn in")
assert(FindName(quests[86].objectivesText[1]))
assert(FindName("Chunk of Boar Meat").id == 769 and not FindName("Chunk of Boar Meat").kind)
assert(FindName("Tough Jerky").id == 117)
assert(load, "Reward loading must allow the quest details to appear first")
load(function(found) rows = found end)
RunTimers()
assert(FindName("Reward").id == 789 and not FindName("Reward").kind)
local objectiveItems, rewardItems = 0, 0
for _, row in ipairs(rows) do
    if row.id == 769 then objectiveItems = objectiveItems + 1 end
    if row.id == 789 then rewardItems = rewardItems + 1 end
end
assert(objectiveItems == 1 and rewardItems == 1, "Each item should appear once in its group")

C_QuestLog = {
    IsOnQuest = function(id) return id == 86 end,
    GetQuestObjectives = function()
        return {
            { text = "Chunks of Boar Meat collected", numFulfilled = 3, numRequired = 4 },
            { text = "Talk to Billy", finished = true },
        }
    end,
}
rows, _, load = addon.Search("@quest 86")
assert(not load and FindName("Chunks of Boar Meat collected").matchLabel == "3/4")
assert(FindName("Talk to Billy").matchLabel == "Complete")
assert(FindName("Chunk of Boar Meat").id == 769, "Live progress must preserve clickable objective items")
local _, aliasTitle = addon.Search("@q 86")
assert(aliasTitle:find("Pie for Billy", 1, true) and addon.IsQuestDetailQuery("@Q 86"))
assert(#addon.Search("@quest 999999") == 0)
assert(#addon.Search("@quest title with no match") == 0)
rows = addon.Search("@quest 87")
assert(FindName("Speak to Billy"), "Structured objectives are used when the quest has no summary")
assert(FindName("Bring 2 pieces of jerky") and FindName("Stormwind reputation (3000)"))

LibQuestieDB = nil
rows, message = addon.Search("@quest pie")
assert(#rows == 0 and message:find("QuestieDB", 1, true))
print("Quest search, details, item links, and progress passed")
