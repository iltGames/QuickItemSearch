local addon = {}
local scheduled = {}
C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }

local quests = {
    [101] = { name = "Collect Supplies", objectives = { [3] = { { 11 }, { 11 } } } },
    [102] = { name = "Use Supplies", requiredSourceItems = { 11, 12 } },
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

local function TooltipLines(itemID)
    local lines = {}
    addon.AppendItemSources({ AddLine = function(_, line) lines[#lines + 1] = line end }, itemID)
    return table.concat(lines, "\n")
end

local tooltip = TooltipLines(11)
assert(tooltip:find("Required for quest: Collect Supplies", 1, true), "Item objectives must appear in the tooltip")
assert(tooltip:find("Required for quest: Use Supplies", 1, true), "Required quest items must appear in the tooltip")
assert(tooltip:find("Quest reward: Earn Supplies", 1, true), "Quest rewards must retain their own label")
assert(not tooltip:find("Deliver a Message", 1, true), "NPC objectives must not match item IDs")
local _, count = tooltip:gsub("Collect Supplies", "")
assert(count == 1, "Multiple objectives for the same quest must produce a single line")
assert(TooltipLines(13) == "", "Unrelated items must omit quest requirements")

LibQuestieDB = nil
assert(TooltipLines(12) == "", "QuestieDB must remain optional")

print("Quest requirement tooltip tests passed")
