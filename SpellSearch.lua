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
        table.sort(sortedSpells, function(left, right)
            if left.key == right.key then return left.id < right.id end
            return left.key < right.key
        end)
    end

    if name == "" then return sortedSpells end
    local results = addon.FindNamedEntries(sortedSpells, name)
    return results, #results > 0 and "Player spells" or "No matching player spells."
end
