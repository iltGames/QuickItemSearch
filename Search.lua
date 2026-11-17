local _, addon = ...

function addon.IsPTRItem(id)
    return addon.ptrOnly and addon.ptrOnly[id]
end

local function ParseID(query)
    local value = query:match("^%d+$")
        or query:match("^item:(%d+)$")
        or query:match("^item:(%d+):")
        or query:match("|Hitem:(%d+)[:|]")
    local id = tonumber(value)
    if id and id > 0 and id <= 2147483647 then
        return id
    end
end

local function FindItems(query)
    if query == "" then return {}, 0 end
    local entries = addon.sortedEntries
    if not entries then
        entries = {}
        for itemID, name in pairs(addon.index) do
            if not addon.IsPTRItem(itemID) then
                entries[#entries + 1] = { id = itemID, name = name, key = name:lower() }
            end
        end
        table.sort(entries, function(left, right)
            if left.key == right.key then
                return left.id < right.id
            end
            return left.key < right.key
        end)
        addon.sortedEntries = entries
    end

    return addon.FindNamedEntries(entries, query)
end

function addon.FindNamedEntries(entries, query)
    local results, prefixes, matches = {}, {}, {}
    for _, entry in ipairs(entries) do
        local start = entry.key:find(query, 1, true)
        if entry.key == query then
            results[#results + 1] = entry
        elseif start == 1 then
            prefixes[#prefixes + 1] = entry
        elseif start then
            matches[#matches + 1] = entry
        end
    end
    local exactCount = #results
    for _, group in ipairs({ prefixes, matches }) do
        for _, entry in ipairs(group) do
            results[#results + 1] = entry
        end
    end
    return results, exactCount
end

local questionPrefixes = {
    "where can i ", "where do i ", "where to ", "how do i ", "how to ", "what is ",
    "what level can i ", "at what level can i ", "what skill do i need to ",
}

local actions = {
    spell = "SearchPlayerSpells", spells = "SearchPlayerSpells",
    emote = "SearchEmotes", emotes = "SearchEmotes",
    craft = "SearchRecipes", make = "SearchRecipes", enchant = "SearchRecipes", usedin = "SearchRecipeUses",
    train = "SearchTraining", trainer = "SearchTraining",
    gather = "SearchGathering", harvest = "SearchGathering", pick = "SearchGathering", mine = "SearchGathering",
    skin = "SearchSkinning", skinning = "SearchSkinning",
}
local browseTitles = {
    SearchPlayerSpells = "Spells", SearchRecipes = "Recipes", SearchRecipeUses = "Reagents",
    SearchTraining = "Trainers", SearchGathering = "Gathering", SearchSkinning = "Skinning",
    SearchEmotes = "Emotes",
}

local function Trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function FindActions(query, exactItem)
    query = Trim(query:gsub("%s+", " "):gsub("[%?%.!]+$", ""))
    for _, prefix in ipairs(questionPrefixes) do
        if query:sub(1, #prefix) == prefix then
            query = query:sub(#prefix + 1)
            break
        end
    end

    local matches = {}
    local position = 1
    while true do
        local first = query:find('[^%s:]', position)
        if not first then break end
        if query:sub(first, first) == '"' then
            local closing = query:find('"', first + 1, true)
            if not closing then break end
            position = closing + 1
        else
            local _, last = query:find('[^%s:"]+', first)
            local word = query:sub(first, last)
            if word == "used" then
                local _, length = query:sub(last + 1):find("^ in%f[%W]")
                if length then word, last = "usedin", last + length end
            end
            if actions[word] and (first == 1 or not exactItem) then
                local before = Trim(query:sub(1, first - 1))
                local after = query:sub(last + 1):gsub("^[%s:]+", "")
                local target = Trim(before .. " " .. after)
                target = target:match('^"([^"]*)"$') or target
                matches[#matches + 1] = { word = word, target = target, leading = first == 1 }
            end
            position = last + 1
        end
    end
    return matches
end

local function RelatedRecipes(query, items, relevantCount)
    if not addon.SearchRecipes then return end
    local reagents, recipes, seen = {}, {}, {}
    for i = 1, math.min(relevantCount, #items) do
        reagents[#reagents + 1] = items[i]
    end
    local function Append(rows)
        for _, row in ipairs(rows) do
            local key = row.id .. ":" .. row.matchLabel
            if not seen[key] then
                seen[key] = true
                recipes[#recipes + 1] = row
            end
        end
    end
    for _, item in ipairs(reagents) do Append(addon.GetItemRecipes(item.id) or {}) end
    Append(addon.FindRecipesUsingItems(reagents))
    if query ~= "" then Append(addon.SearchRecipes(query, nil, true)) end
    return recipes
end

local function ItemRows(items)
    return addon.AddItemGatheringDetails and addon.AddItemGatheringDetails(items) or items
end

local function SectionResults(query, items, exactCount, primary, title, hint, answer, itemsFirst)
    local sections, seen = {}, {}
    local function Add(sectionTitle, rows)
        if not seen[sectionTitle] and rows and #rows > 0 then
            seen[sectionTitle] = true
            sections[#sections + 1] = { title = sectionTitle, rows = rows }
        end
    end

    if not itemsFirst then Add(title, primary) end
    local gathering = title == "Gathering" and primary
        or (addon.FindGatheringSection and addon.FindGatheringSection(query))
    if title == "Gathering" or title == "Reagents" then
        local listed, related = {}, {}
        for _, row in ipairs(primary) do listed[row.id] = true end
        for _, item in ipairs(items) do
            if not listed[item.id] then related[#related + 1] = item end
        end
        Add("Items", ItemRows(related))
    else
        Add("Items", ItemRows(items))
    end
    if itemsFirst then Add(title, primary) end
    if query ~= "" and not tonumber(query) then
        Add("Gathering", gathering)
        if not seen.Spells and addon.SearchPlayerSpells then Add("Spells", addon.SearchPlayerSpells(query)) end
        if not (seen.Recipes or seen.Enchanting) then
            local useNodes = gathering and gathering[1] and gathering[1].answer
            Add("Recipes", RelatedRecipes(query, useNodes and gathering or items,
                useNodes and #gathering or exactCount))
        end
        if not seen.Emotes and addon.SearchEmotes then Add("Emotes", addon.SearchEmotes(query)) end
        if not seen.Trainers and addon.SearchTraining then Add("Trainers", addon.SearchTraining(query, false)) end
        if not seen["Boss Drops"] and addon.SearchBossLoot then Add("Boss Drops", addon.SearchBossLoot(query)) end
    elseif not primary then
        Add("Recipes", RelatedRecipes("", items, exactCount))
    end

    local first = table.remove(sections, 1)
    if not first then return primary or {}, hint, nil, answer end
    if first.title == "Items" and #sections == 0 then return first.rows, hint, nil, answer end
    sections.title = first.title
    return first.rows, hint, nil, answer, sections
end

local function GearResults(query, gear, hint, loadStats)
    local rows, _, _, _, sections = SectionResults(query, {}, 0, gear, "Items", hint)
    if not loadStats then return rows, hint, nil, nil, sections end
    return rows, hint, function(done)
        return loadStats(function(loaded, loadedHint)
            done(SectionResults(query, {}, 0, loaded, "Items", loadedHint))
        end)
    end, nil, sections
end

local function SearchByAction(query, itemMatches, exactCount)
    local matches = FindActions(query, exactCount > 0)
    -- A recognized profession can itself be an action word, as in "mine train" or "enchant train".
    if addon.SearchTraining then
        for _, match in ipairs(matches) do
            if actions[match.word] == "SearchTraining" and not match.leading and match.target ~= "" then
                local rows, answer = addon.SearchTraining(match.target, false)
                if rows then
                    local items, count = FindItems(match.target)
                    return SectionResults(match.target, items, count, rows, "Trainers", nil, answer)
                end
            end
        end
    end
    for _, match in ipairs(matches) do
        local method = actions[match.word]
        local search = addon[method]
        if search then
            local rows, hint, answer
            if method == "SearchTraining" then
                rows, answer = search(match.target, match.leading and match.word == "train")
            elseif method == "SearchGathering" then
                rows, answer, hint = search(match.word, match.target, FindItems)
            elseif method == "SearchRecipeUses" then
                rows, hint = search(match.target, FindItems)
            else
                local target, profession = match.target
                local gear, gearHint, loadStats
                if match.word == "make" or match.word == "craft" then
                    target, profession = addon.ExtractCraftProfession(target)
                    if addon.SearchGear then
                        gear, gearHint, loadStats = addon.SearchGear(target, false, true, profession)
                        if gear and (#gear > 0 or loadStats or not profession) then
                            return GearResults(match.target, gear, gearHint, loadStats)
                        end
                    end
                end
                rows, hint, answer = search(target, match.word, nil, profession)
                if gear and #rows == 0 then return GearResults(match.target, gear, gearHint) end
            end
            if rows then
                local title = browseTitles[method]
                if match.word == "enchant" then title = "Enchanting" end
                if method == "SearchGathering" then
                    if match.target:match("^skin[%s%d]*$") or match.target:match("^skinning[%s%d]*$") then
                        title = "Skinning"
                    elseif answer and not (rows[1] and rows[1].answer) then
                        hint, answer = answer, nil
                        if hint == "No verified gathering requirement for this search." then title = "Items" end
                    end
                end
                local target = match.target
                if target == "" then
                    return SectionResults(query, itemMatches, exactCount, rows, title,
                        #itemMatches == 0 and hint or nil, nil, true)
                end
                local items, count = FindItems(target)
                return SectionResults(target ~= "" and target or query, items, count, rows, title, hint, answer)
            end
        end
    end
end

function addon.Search(input)
    local query = input:match("^%s*(.-)%s*$")
    local lowerQuery = query:lower()
    local shortcut, instanceQuery = lowerQuery:match("^(@%a+)%s+(.*)$")
    shortcut = shortcut or lowerQuery
    if shortcut == "@spell" or shortcut == "@spells" then
        local target = instanceQuery or ""
        return addon.SearchPlayerSpells(target:match('^"(.*)"$') or target)
    end
    local id = ParseID(query)
    if id then
        if addon.IsPTRItem(id) then return {}, "This item is marked PTR Only." end
        return SectionResults("", { { id = id, name = addon.index[id] } }, 1)
    end
    local bossQuery = lowerQuery:match("^boss:%s*(.*)$")
    if bossQuery then
        if bossQuery:sub(1, 1) ~= '"' and bossQuery:find("%s") then
            local loot, hint = addon.SearchBossLoot(bossQuery, true)
            if loot then
                local items, count = FindItems(bossQuery)
                return SectionResults(bossQuery, items, count, loot, "Boss Drops", hint)
            end
        end
        if addon.SearchGear then
            local gear, hint, loadStats = addon.SearchGear(lowerQuery, true)
            if gear then return GearResults(lowerQuery, gear, hint, loadStats) end
        end
        bossQuery = bossQuery:match('^"(.*)"$') or bossQuery
        if #bossQuery < 2 then return {}, "Enter at least two characters of the boss name." end
        local loot, hint = addon.SearchBossLoot(bossQuery)
        local items, count = FindItems(bossQuery)
        return SectionResults(bossQuery, items, count, loot or {}, "Boss Drops", hint)
    end
    if #query < 2 then
        return {}, "Enter an item or boss name, item ID, or item link."
    end
    if query:match("^%d+$") or query:match("^item:") or query:find("|H", 1, true) then
        return {}, "Enter a valid item ID or item link."
    end

    query = lowerQuery
    local subject = query:match('^"([^"]+)"$') or query
    local results, exactCount = FindItems(subject)
    if exactCount == 0 and addon.SearchGear then
        local gear, hint, loadStats = addon.SearchGear(query)
        if gear then return GearResults(subject, gear, hint, loadStats) end
    end
    local rows, hint, loadStats, answer, sections = SearchByAction(query, results, exactCount)
    if rows then return rows, hint, loadStats, answer, sections end
    return SectionResults(subject, results, exactCount)
end
