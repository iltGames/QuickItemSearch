local _, addon = ...

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

function addon.Search(input)
    local query = input:match("^%s*(.-)%s*$")
    local id = ParseID(query)
    if id then
        return { { id = id, name = addon.index[id] } }
    end
    local bossQuery = query:lower():match("^boss:%s*(.*)$")
    if bossQuery then
        if #bossQuery < 2 then return {}, "Enter at least two characters of the boss name." end
        local loot, hint = addon.SearchBossLoot(bossQuery)
        return loot or {}, hint
    end
    if #query < 2 then
        return {}, "Enter an item or boss name, item ID, or item link."
    end
    if query:match("^%d+$") or query:match("^item:") or query:find("|H", 1, true) then
        return {}, "Enter a valid item ID or item link."
    end

    local entries = addon.sortedEntries
    if not entries then
        entries = {}
        for itemID, name in pairs(addon.index) do
            entries[#entries + 1] = { id = itemID, name = name, key = name:lower() }
        end
        table.sort(entries, function(left, right)
            if left.key == right.key then
                return left.id < right.id
            end
            return left.key < right.key
        end)
        addon.sortedEntries = entries
    end

    query = query:lower()
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
    for _, group in ipairs({ prefixes, matches }) do
        for _, entry in ipairs(group) do
            results[#results + 1] = entry
        end
    end
    if addon.SearchBossLoot then
        local loot, hint = addon.SearchBossLoot(query, #results > 0)
        if loot then return loot, hint end
    end
    return results
end
