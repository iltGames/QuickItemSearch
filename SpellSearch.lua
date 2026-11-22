local _, addon = ...
local sortedSpells

local classes = {
    warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER", rogue = "ROGUE",
    priest = "PRIEST", shaman = "SHAMAN", mage = "MAGE", warlock = "WARLOCK", druid = "DRUID",
}

local function UnlockRows(catalog, level)
    local rows = {}
    for _, spell in ipairs(catalog) do
        local quests = {}
        for _, variant in ipairs(spell.quest or {}) do
            if not level or variant.level == level then quests[#quests + 1] = variant end
        end
        local source = spell.kind == "quest" and #quests > 0 and "Quest"
            or spell.kind == "trainer" and (not level or spell.level == level) and "Trainer"
        if source and not spell.petAbility and type(spell.id) == "number" then
            local name = spell.name or addon.playerSpells[spell.id] or ("Spell %d"):format(spell.id)
            if spell.subText and spell.subText ~= "" then name = name .. " (" .. spell.subText .. ")" end
            rows[#rows + 1] = {
                id = spell.id, name = name, kind = "spell",
                matchLabel = ("Level %d · %s"):format(level or spell.level, source),
                unlockLevel = level or spell.level, unlockSource = source,
                unlockQuests = source == "Quest" and quests or nil,
                requiredTalentId = spell.requiredTalentId, unlockRaces = spell.races,
                unlockFaction = spell.faction,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return rows
end

local function ClassRows(token, className, catalog)
    local rows, includedSpellIDs = {}, {}
    for _, row in ipairs(UnlockRows(catalog or {})) do
        rows[#rows + 1], includedSpellIDs[row.id] = row, true
    end
    for _, id in ipairs((addon.classSpells or {})[token] or {}) do
        if not includedSpellIDs[id] then
            local name = addon.playerSpells[id] or ("Spell %d"):format(id)
            local rank = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
            if rank and rank ~= "" then name = name .. " (" .. rank .. ")" end
            rows[#rows + 1] = { id = id, name = name, kind = "spell", matchLabel = className }
            includedSpellIDs[id] = true
        end
    end
    table.sort(rows, function(a, b)
        local left, right = a.unlockLevel or math.huge, b.unlockLevel or math.huge
        if left ~= right then return left < right end
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return rows
end

-- Returns nil for ordinary searches. Catalog data stays owned by What's Training;
-- it is neither bundled nor saved in our source backup.
function addon.SearchClassSpellUnlocks(query)
    query = query:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local prefix, suffix
    query, prefix = query:gsub("^@?spells?[%s:]+", "")
    query, suffix = query:gsub("%s+spells?$", "")
    local class, value = query:match("^(%a+)%s+(%d+)$")
    if not class and prefix + suffix > 0 then class = query end
    local token = classes[class]
    if not token then return end
    local level = tonumber(value)
    if level and (level < 1 or level > 60) then return {}, "Enter a spell unlock level from 1 to 60." end
    local className = class:gsub("^%l", string.upper)
    local sectionTitle = not level and (className .. " Spells") or nil
    local function Reply(rows, hint, load) return rows, hint, load, sectionTitle end
    local function Fallback(hint)
        if level then return {}, hint end
        return Reply(ClassRows(token, className), hint)
    end
    local api = _G.WT_API
    if not api then return Fallback("Install and enable What's Training for spell unlock levels and sources.") end
    for _, method in ipairs({ "GetCatalog", "IsClassReady", "LoadClass", "RegisterCallback", "UnregisterCallback" }) do
        if type(api[method]) ~= "function" then
            return Fallback("Update What's Training to a version with the class catalog API for unlock levels and sources.")
        end
    end
    local function Results()
        local ok, catalog = pcall(api.GetCatalog, token)
        if not ok or type(catalog) ~= "table" then
            return Fallback("What's Training has no class catalog available for " .. class .. ".")
        end
        if not level then return ClassRows(token, className, catalog), className .. " spells · What's Training" end
        local rows = UnlockRows(catalog, level)
        local title = ("%s level %d · What's Training"):format(className, level)
        return rows, #rows > 0 and title or ("No spell unlocks at " .. class .. " level " .. level .. ".")
    end
    local ok, catalog = pcall(api.GetCatalog, token)
    if not ok or type(catalog) ~= "table" then return Reply(Results()) end
    if api.IsClassReady(token) then return Reply(Results()) end

    local initial = level and UnlockRows(catalog, level) or ClassRows(token, className, catalog)
    return Reply(initial, "Loading spell names from What's Training…", function(done)
        local owner, active = {}, true
        local function Cancel()
            active = false
            api.UnregisterCallback(owner, "ClassReady")
        end
        local function Finish()
            if not active then return end
            Cancel()
            done(Results())
        end
        api.RegisterCallback(owner, "ClassReady", function(_, loadedClass)
            if loadedClass == token then Finish() end
        end)
        local loaded, ready = pcall(api.LoadClass, token)
        if loaded and ready then
            Finish()
        elseif not loaded then
            Cancel()
            done(Fallback("What's Training could not load this class's spell catalog."))
        end
        return Cancel
    end)
end

local function RaceNames(ids)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(id)
        names[#names + 1] = info and info.raceName or ("Race %d"):format(id)
    end
    return table.concat(names, ", ")
end

function addon.GetSpellUnlockChoices(entry)
    local choices = {}
    if not entry.unlockLevel then return choices end
    local function Add(name, query)
        choices[#choices + 1] = { name = name, query = query }
    end
    if entry.unlockSource == "Trainer" then
        Add(("Learn from a class trainer at level %d."):format(entry.unlockLevel))
    end
    if entry.unlockFaction then Add("Faction: " .. entry.unlockFaction) end
    local allowedRaces = RaceNames(entry.unlockRaces)
    if allowedRaces ~= "" then Add("Races: " .. allowedRaces) end
    if entry.requiredTalentId then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry.requiredTalentId)
        Add("Requires talent: " .. (name or ("Spell %d"):format(entry.requiredTalentId)))
    end
    local db = _G.LibQuestieDB
    local quests = db and db.Quest
    for _, variant in ipairs(entry.unlockQuests or {}) do
        local races = RaceNames(variant.races)
        local requirements = ("Minimum level %d%s"):format(variant.level, races ~= "" and (" · " .. races) or "")
        local areas = {}
        for _, id in ipairs(variant.areas or {}) do
            local name = GetAreaInfo and GetAreaInfo(id)
            areas[#areas + 1] = name or ("Area %d"):format(id)
        end
        if #areas > 0 then requirements = requirements .. " · " .. table.concat(areas, ", ") end
        if not variant.quests or #variant.quests == 0 then Add("Quest unlock\n" .. requirements) end
        for _, id in ipairs(variant.quests or {}) do
            local questName
            if quests and quests.Get then
                local ok, name = pcall(quests.Get, id, "name")
                if ok and type(name) == "string" and name ~= "" then questName = name end
            end
            local label = questName and ("Open quest: " .. questName) or ("Quest %d"):format(id)
            Add(label .. "\n" .. requirements, questName and ("@quest " .. id) or nil)
        end
    end
    return choices
end

function addon.AppendSpellUnlockSources(tooltip, entry)
    for _, choice in ipairs(addon.GetSpellUnlockChoices(entry)) do
        tooltip:AddLine((choice.name:gsub("|", "||")), 0.8, 0.8, 0.8, true)
    end
end

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
