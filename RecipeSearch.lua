local _, addon = ...
local recipesByOutput

local allStatsEnchants = { [13626] = true, [13700] = true, [13941] = true, [20025] = true }
local primaryStats = {
    agil = true, agi = true, agility = true,
    str = true, strength = true, sta = true, stam = true, stamina = true,
    int = true, intellect = true, spi = true, spirit = true,
}

local function NameRank(name, target, words, grantsAllStats)
    if name == target then return 3 end
    if name:find(target, 1, true) then return 2 end
    for _, word in ipairs(words) do
        local found
        for token in name:gmatch("%w+") do
            if token:sub(1, #word) == word then
                found = true
                break
            end
        end
        if not found and not (grantsAllStats and primaryStats[word]) then return 0 end
    end
    return 1
end

local function RecipeResult(recipe, rank)
    local id, name, profession, skill = unpack(recipe)
    local label = skill and (profession .. " " .. skill) or (profession .. " (skill unknown)")
    return {
        id = id, name = name, kind = "spell", key = name:lower(), rank = rank, matchLabel = label, skill = skill,
        profession = profession, skillThresholds = recipe[7],
    }
end

function addon.GetItemRecipes(itemID)
    if not recipesByOutput then
        recipesByOutput = {}
        for _, recipe in ipairs(addon.recipes) do
            local output = recipe[5]
            if output then
                local rows = recipesByOutput[output] or {}
                rows[#rows + 1] = RecipeResult(recipe, 3)
                recipesByOutput[output] = rows
            end
        end
    end
    return recipesByOutput[itemID]
end

local function SortRecipeResults(results)
    table.sort(results, function(left, right)
        if left.rank ~= right.rank then return left.rank > right.rank end
        if left.key ~= right.key then return left.key < right.key end
        if left.id ~= right.id then return left.id < right.id end
        return left.matchLabel < right.matchLabel
    end)
end

function addon.FindRecipesUsingItems(items)
    local ids = {}
    for _, item in ipairs(items) do ids[item.id] = true end
    local results = {}
    if not next(ids) then return results end
    for _, recipe in ipairs(addon.recipes) do
        if recipe[6] then
            for _, reagentID in ipairs(recipe[6]) do
                if ids[reagentID] then
                    results[#results + 1] = RecipeResult(recipe, 1)
                    break
                end
            end
        end
    end
    SortRecipeResults(results)
    return results
end

function addon.SearchRecipeUses(target, findItems)
    if target == "" then
        local seen, reagents = {}, {}
        for _, recipe in ipairs(addon.recipes) do
            for _, id in ipairs(recipe[6] or {}) do
                local name = addon.index[id]
                if name and not seen[id] and not addon.IsPTRItem(id) then
                    seen[id] = true
                    reagents[#reagents + 1] = { id = id, name = name, key = name:lower() }
                end
            end
        end
        table.sort(reagents, function(left, right)
            if left.key == right.key then return left.id < right.id end
            return left.key < right.key
        end)
        return reagents
    end
    if #target < 2 then return {}, "Enter a reagent name or item ID." end
    local itemID = tonumber(target:match("^%d+$") or target:match("^item:(%d+)$"))
    local items
    if itemID then
        items = { { id = itemID } }
    else
        local exactCount
        items, exactCount = findItems(target)
        if exactCount > 0 then
            for i = #items, exactCount + 1, -1 do items[i] = nil end
        end
    end
    local results = addon.FindRecipesUsingItems(items)
    if #results == 0 then return results, "No indexed recipes use this reagent." end
    return results, "Recipes using " .. ((itemID and addon.index[itemID] or target):gsub("|", "||"))
end

function addon.SearchRecipes(target, action, literal, requiredProfession)
    local enchantsOnly = action == "enchant"
    local spellID = tonumber(target:match("^%d+$"))
    if not spellID and #target == 1 then
        return {}, "Enter at least two characters of a recipe name or a recipe spell ID."
    end
    local words = {}
    for word in target:gmatch("%w+") do words[#words + 1] = word end
    if #words == 0 and target ~= "" then return {}, "Enter a recipe name or a recipe spell ID." end

    local function Rank(text)
        if not literal then return NameRank(text, target, words) end
        if text == target then return 3 end
        return text:find(target, 1, true) and 2 or 0
    end
    local results = {}
    for _, recipe in ipairs(addon.recipes) do
        local id, name, profession, _, outputID = unpack(recipe)
        if (not enchantsOnly or profession == "Enchanting")
            and (not requiredProfession or profession == requiredProfession) then
            local key = name:lower()
            local rank = spellID and (id == spellID and 3 or 0) or Rank(key)
            if enchantsOnly and not spellID and rank == 0 and allStatsEnchants[id] then
                rank = NameRank(key, target, words, true)
            end
            local outputName = outputID and addon.index[outputID]
            if not spellID and rank < 3 and outputName then rank = math.max(rank, Rank(outputName:lower())) end
            if rank > 0 then results[#results + 1] = RecipeResult(recipe, rank) end
        end
    end
    SortRecipeResults(results)

    if #results == 0 then return results, enchantsOnly and "No matching enchanting recipes." or "No matching recipes." end
    if target == "" then return results end
    if #results == 1 then
        local result = results[1]
        local answer = result.skill and ("Requires " .. result.matchLabel .. ".") or "No recorded skill requirement for this recipe."
        return results, nil, answer
    end
    return results, "Recipes"
end
