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
        nextQuestInChain = 84, childQuests = { 84, 89, 86, 999999 }, breadcrumbForQuestId = 90,
    },
    [84] = { name = "Back to Billy", preQuestSingle = { 86 } },
    [87] = {
        name = "A Pie for Billy",
        objectives = { { { 247, "Speak to Billy" } }, nil, { { 117, "Bring 2 pieces of jerky" } }, { 72, 3000 } },
    },
    [88] = { name = "Pie for Billy Again" },
    [89] = { name = "Send a Letter" },
    [90] = { name = "Visit the Farm" },
    [91] = { name = "Check In", preQuestGroup = { -86, 84 } },
    [92] = { name = "One More Favor", preQuestSingle = { 86 } },
    [93] = { name = "Bring the Reply", preQuestSingle = { 89 }, childQuests = { 95 } },
    [95] = { name = "Read the Reply", childQuests = { 93 } },
}
local items = {
    [117] = { name = "Tough Jerky" },
    [769] = { name = "Chunk of Boar Meat" },
    [789] = { name = "Reward", questRewards = { 86, 86 } },
}
LibQuestieDB = {
    Quest = {
        GetAllIds = function() return { 84, 86, 87, 88, 89, 90, 91, 92, 93, 95 } end,
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

QuickItemSearchSettings = { hiddenSections = { Quests = true } }
local hiddenRows, _, hiddenLoad = addon.Search("pie")
assert(hiddenRows[1].name == "Meat Pie" and not hiddenLoad, "Hidden quests should skip the automatic quest lookup")
loadMixed = nil
local _, _, _, _, hiddenSections = addon.Search("pie")
assert(not hiddenSections, "Hidden quests should stay out of regular searches")
assert(addon.Search("@quest pie for billy")[1].id == 86, "A direct quest search should still find quests")
QuickItemSearchSettings = nil

-- A new provider exercises cancellation while the title index is still loading.
local questDB = LibQuestieDB.Quest
LibQuestieDB.Quest = { Get = questDB.Get, GetAllIds = questDB.GetAllIds }
local rows, message, load = addon.Search(" @QUEST \"pie for billy\" ")
assert(#rows == 0 and load, "The quest title index should load in batches")
local cancel = load(function() error("A cancelled quest search must not replace newer results") end)
cancel()
local _, _, loadDelayed = addon.Search("pie")
assert(loadDelayed, "Automatic quest search should be pending")
local delayedRows, delayedSections
loadDelayed(function(found, _, _, _, sections) delayedRows, delayedSections = found, sections end)
QuickItemSearchSettings = { hiddenSections = { Quests = true } }
local _, _, loadLatest = addon.Search("@quest pie for billy")
loadLatest(function(found) rows = found end)
RunTimers()
assert(#rows == 3 and rows[1].id == 86 and rows[2].id == 88 and rows[3].id == 87,
    "Quest search must rank exact, prefix, and substring matches")
assert(delayedRows[1].name == "Meat Pie" and not delayedSections,
    "Quests that finish loading after being disabled must stay hidden")
QuickItemSearchSettings = nil
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
assert(FindName("Billy Maclure").pinEntity == "Npc" and FindName("Billy Maclure").pinEntityID == 247)
assert(FindName("Auntie Bernice Stonefield").matchLabel == "Turn in")
assert(FindName("Auntie Bernice Stonefield").pinEntityID == 246)
assert(FindName(quests[86].objectivesText[1]))
assert(FindName("Chunk of Boar Meat").id == 769 and not FindName("Chunk of Boar Meat").kind)
assert(FindName("Tough Jerky").id == 117)
assert(load, "Reward loading must allow the quest details to appear first")
load(function(found) rows = found end)
RunTimers()
assert(FindName("Reward").id == 789 and not FindName("Reward").kind)
assert(FindName("Reward").questReward and not FindName("Tough Jerky").questReward,
    "Only reward rows should offer a search for the reward item")
assert(FindName("Next quests").sectionHeader and FindName("Next quests").collapsible == 7)
for _, name in ipairs({ "Back to Billy", "Send a Letter", "Visit the Farm", "Check In", "One More Favor" }) do
    assert(FindName(name).kind == "quest", "Follow-up should be clickable: " .. name)
end
local followUps = {}
for _, row in ipairs(rows) do if row.kind == "quest" then followUps[#followUps + 1] = row end end
assert(#followUps == 7, "Include later quests while skipping duplicate, missing and circular links")
assert(followUps[6].id == 93 and followUps[6].matchLabel == "2 steps ahead")
assert(followUps[7].id == 95 and followUps[7].matchLabel == "3 steps ahead")
QuickItemSearchSettings = { hiddenSections = { ["Next quests"] = true } }
rows = addon.Search("@quest 86")
assert(not FindName("Next quests") and not FindName("Back to Billy"))
assert(FindName("Chunk of Boar Meat"), "Hiding follow-ups must keep the quest details open")
QuickItemSearchSettings = nil
rows = addon.Search("@quest 86")
local objectiveItems, rewardItems = 0, 0
for _, row in ipairs(rows) do
    if row.id == 769 then objectiveItems = objectiveItems + 1 end
    if row.id == 789 then rewardItems = rewardItems + 1 end
end
assert(objectiveItems == 1 and rewardItems == 1, "Each item should appear once in its group")
assert(not FindName("Previous quest"), "A quest without a prerequisite must omit the section")
rows = addon.Search("@quest 84")
assert(FindName("Previous quest").collapsible == 1 and FindName("Previous quest").sectionKey == "Previous quests")
assert(FindName("Pie for Billy").kind == "quest")
rows = addon.Search("@quest 91")
assert(FindName("Previous quests").sectionHeader)
assert(FindName("Pie for Billy").id == 86 and FindName("Back to Billy").id == 84)
rows = addon.Search("@quest 89")
assert(FindName("Pie for Billy").matchLabel == "1 step back", "Explicit follow-ups should link in both directions")
rows = addon.Search("@quest 95")
local previousQuests = {}
for _, row in ipairs(rows) do
    if row.name == "Next quests" then break end
    if row.kind == "quest" then previousQuests[#previousQuests + 1] = row end
end
assert(#previousQuests == 3 and previousQuests[1].id == 93 and previousQuests[2].id == 89
    and previousQuests[3].id == 86 and previousQuests[3].matchLabel == "3 steps back")
QuickItemSearchSettings = { hiddenSections = { ["Previous quests"] = true } }
rows = addon.Search("@quest 84")
assert(not FindName("Previous quest") and not FindName("Pie for Billy"))
QuickItemSearchSettings = nil

C_QuestLog = {
    IsOnQuest = function(id) return id == 86 end,
    GetQuestObjectives = function()
        return {
            { text = "Chunks of Boar Meat collected", numFulfilled = 3, numRequired = 4 },
            { text = "Talk to Billy", finished = true },
        }
    end,
}
local liveXP = 450
GetQuestLogRewardXP = function(id)
    if id == 86 then return liveXP end
    return 0
end
LibQuestieDB.Support = { Get = function(module)
    if module == "QuestXP" then return { db = { [86] = { 6, 350 }, [87] = { 7, 480 } } } end
end }
local function QuestTitle(id)
    local _, title = addon.Search("@quest " .. id)
    return title
end
assert(QuestTitle(86):find("450 XP", 1, true), "Quest details should use the character's live XP reward")
assert(QuestTitle(87):find("480 base XP", 1, true), "Unaccepted quests should show labeled base XP")
assert(not QuestTitle(88):find("XP", 1, true), "Unknown XP should be omitted")
liveXP = 0
assert(QuestTitle(86):find("0 XP", 1, true), "A live zero reward should take precedence over base XP")
liveXP = nil
assert(QuestTitle(86):find("350 base XP", 1, true), "Missing live XP should fall back to indexed XP")
QuickItemSearchSettings = { hiddenSections = { ["Quest XP"] = true } }
assert(QuestTitle(86):find("350 base XP", 1, true), "Old settings should not hide quest XP")
QuickItemSearchSettings = nil
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

QuickItemSearchSettings = { hiddenSections = { ["Next quests"] = true } }
LibQuestieDB.Quest = { Get = questDB.Get, GetAllIds = questDB.GetAllIds }
rows, _, load = addon.Search("@quest 95")
assert(load, "Previous quests should build the chain even with Next quests turned off")
load(function(found) rows = found end)
RunTimers()
assert(FindName("Pie for Billy").matchLabel == "3 steps back" and not FindName("Next quests"))
QuickItemSearchSettings = nil

LibQuestieDB = nil
rows, message = addon.Search("@quest pie")
assert(#rows == 0 and message:find("QuestieDB", 1, true))
print("Quest search, details, item links, and progress passed")
