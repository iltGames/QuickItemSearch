local _, addon = ...
local sortedSpells

function addon.SearchPlayerSpells(name)
    local id = tonumber(name:match("^%d+$"))
    if id then
        local spell = addon.playerSpells[id]
        if spell then return { { id = id, name = spell, kind = "spell" } }, "Player spells" end
        return {}, "No matching player spells."
    end
    if #name == 1 then return {}, "Enter at least two characters of the spell name." end

    if not sortedSpells then
        sortedSpells = {}
        for spellID, spell in pairs(addon.playerSpells) do
            sortedSpells[#sortedSpells + 1] = { id = spellID, name = spell, key = spell:lower(), kind = "spell" }
        end
        for _, ability in ipairs(addon.petSpells or {}) do
            local spell, rank, trainingLevel, sources = unpack(ability)
            sortedSpells[#sortedSpells + 1] = {
                name = ("%s (Rank %d)"):format(spell, rank),
                key = ("%s %d"):format(spell:lower(), rank),
                kind = "text",
                matchLabel = "Hunter pet",
                petTrainingLevel = trainingLevel,
                tameSources = sources,
            }
        end
        table.sort(sortedSpells, function(left, right)
            if left.key == right.key then return (left.id or 0) < (right.id or 0) end
            return left.key < right.key
        end)
    end

    if name == "" then return sortedSpells end
    local results = addon.FindNamedEntries(sortedSpells, name)
    local ability, rank = name:match("^(.-)%s*%(rank%s+(%d+)%)$")
    if not ability then ability, rank = name:match("^(.-)%s+rank%s+(%d+)$") end
    if ability then
        for _, entry in ipairs(addon.FindNamedEntries(sortedSpells, ability .. " " .. rank)) do
            if entry.tameSources then results[#results + 1] = entry end
        end
    end
    return results, #results > 0 and "Spells" or "No matching spells."
end

function addon.SearchPetSpells(name)
    local results = {}
    for _, entry in ipairs(addon.SearchPlayerSpells(name)) do
        if entry.tameSources then results[#results + 1] = entry end
    end
    return results, #results > 0 and "Hunter pet spells" or "No matching hunter pet spells."
end
