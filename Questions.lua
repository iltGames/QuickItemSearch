local _, addon = ...

-- Minimum skill for common Forever herbs and ore nodes. References:
-- https://theforevertavern.com/professions/herbalism
-- https://wowforeverclasses.com/articles/mining-leveling-guide-wow-forever
local herbs = {
    [765] = 1, [785] = 50, [2447] = 1, [2449] = 15, [2450] = 70, [2453] = 100,
    [3355] = 115, [3356] = 125, [3357] = 150, [3358] = 185, [3369] = 120, [3818] = 160,
    [3819] = 195, [3820] = 85, [3821] = 170, [4625] = 205, [8831] = 210, [8836] = 220,
    [8838] = 230, [8839] = 235, [8845] = 245, [8846] = 250, [13463] = 270, [13464] = 260,
    [13465] = 280, [13466] = 285, [13467] = 290, [13468] = 300,
}
local ores = {
    [2770] = { { "Copper Vein", 1 } },
    [2771] = { { "Tin Vein", 65 } },
    [2772] = { { "Iron Deposit", 125 } },
    [2775] = { { "Silver Vein", 75 } },
    [2776] = { { "Gold Vein", 155 } },
    [3858] = { { "Mithril Deposit", 175 } },
    [7911] = { { "Truesilver Deposit", 230 } },
    [10620] = { { "Small Thorium Vein", 245 }, { "Rich Thorium Vein", 275 } },
    [11370] = { { "Dark Iron Deposit", 230 } },
}

local function NameRank(name, target)
    if not name then return 0 end
    local key = name:lower()
    if key == target then return 3 end
    if #target < 2 then return 0 end
    local start = key:find(target, 1, true)
    if start == 1 then return 2 end
    return start and 1 or 0
end

local function FindGatheringMatches(action, target)
    local bestRank, matches = 0, {}
    local function AddMatch(rank, id, name, answer, label)
        if rank < bestRank then return end
        if rank > bestRank then bestRank, matches = rank, {} end
        matches[#matches + 1] = { id = id, name = name, answer = answer, matchLabel = label }
    end

    if action ~= "mine" then
        for id, skill in pairs(herbs) do
            local name = addon.index[id]
            local rank = NameRank(name, target)
            if rank > 0 then
                local label = ("Herbalism %d"):format(skill)
                AddMatch(rank, id, name, "Requires " .. label .. ".", label)
            end
        end
    end
    if action ~= "pick" then
        for id, nodes in pairs(ores) do
            local name = addon.index[id]
            local itemRank = NameRank(name, target)
            local ranks, rank = {}, itemRank
            for index, node in ipairs(nodes) do
                ranks[index] = NameRank(node[1], target)
                rank = math.max(rank, ranks[index])
            end
            if name and rank > 0 and rank >= bestRank then
                local lines, skills = {}, {}
                for index, node in ipairs(nodes) do
                    if itemRank == rank or ranks[index] == rank then
                        lines[#lines + 1] = ("%s requires Mining %d."):format(node[1], node[2])
                        skills[#skills + 1] = tostring(node[2])
                    end
                end
                AddMatch(rank, id, name, table.concat(lines, "\n"), "Mining " .. table.concat(skills, "/"))
            end
        end
    end
    return matches
end

local function AnswerGathering(query, findItems)
    local action, target = query:match("^what level can i (%a+) (.+)$")
    if not action then action, target = query:match("^what skill do i need to (%a+) (.+)$") end
    if not action then action, target = query:match("^(%a+) (.+)$") end
    if action ~= "gather" and action ~= "pick" and action ~= "mine" then return end

    target = target:gsub('^"(.*)"$', "%1")
    local matches = FindGatheringMatches(action, target)
    if #matches == 1 then
        local match = matches[1]
        return { { id = match.id, name = match.name } }, match.answer
    elseif #matches > 1 then
        table.sort(matches, function(left, right)
            local leftName, rightName = left.name:lower(), right.name:lower()
            if leftName == rightName then return left.id < right.id end
            return leftName < rightName
        end)
        return matches, "Multiple gathering matches. Keep typing to narrow the results."
    end
    return findItems(target), "No verified gathering requirement for this search."
end

-- A handler returns item rows and an answer when it recognizes the question.
-- It returns nil to let the next handler or the normal search take over.
local handlers = { AnswerGathering }

function addon.AnswerQuestion(query, findItems)
    local normalized = query:lower():gsub("%s+", " "):gsub("[%?%.!]+$", ""):gsub("%s+$", "")
    for _, handler in ipairs(handlers) do
        local results, answer = handler(normalized, findItems)
        if results then return results, answer end
    end
end
