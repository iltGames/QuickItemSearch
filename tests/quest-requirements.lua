local addon = {}
local scheduled = {}
C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }

local quests = {
    [101] = { name = "Collect Supplies", objectives = { [3] = { { 11 }, { 11 } } } },
    [102] = { name = "Use Supplies", requiredSourceItems = { 11, 12 }, objectives = { [6] = { { 90, nil, 14 } } } },
    [103] = { name = "Deliver a Message", objectives = { [1] = { { 11 } } } },
    [104] = { name = "Earn Supplies" },
}
LibQuestieDB = {
    Quest = {
        GetAllIds = function() return { 101, 102, 103, 104 } end,
        Get = function(id, field) return quests[id][field] end,
    },
    Item = { Get = function(id, field)
        if id == 11 and field == "questRewards" then return { 104 } end
    end },
}

assert(loadfile("Sources.lua"))("QuickItemSearch", addon)
while #scheduled > 0 do table.remove(scheduled, 1)() end

local requiredFor = addon.GetItemQuestRequirements(11)
assert(#requiredFor == 2 and requiredFor[1].id == 101 and requiredFor[2].id == 102,
    "Quest requirements must deduplicate item objectives and exclude NPC objectives")
local choices = addon.GetItemQuestChoices(11, true)
assert(#choices == 3 and choices[1].name == "Collect Supplies" and choices[2].name == "Use Supplies"
    and choices[3].name == "Earn Supplies", "The context menu should list requirements and rewards")
assert(#addon.GetItemQuestChoices(11, false) == 2, "Disabling quest rewards must preserve requirements")
assert(#addon.GetItemQuestRequirements(13) == 0, "Unrelated items must have no quest menu options")
assert(addon.GetItemQuestRequirements(14)[1].id == 102, "Spell objectives can require an item")

LibQuestieDB = nil
assert(#addon.GetItemQuestChoices(12, true) == 0, "QuestieDB must remain optional")

print("Quest requirement and menu tests passed")
