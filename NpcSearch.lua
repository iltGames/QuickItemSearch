local _, addon = ...
local npcIndex = {}

local function GetNPCs()
    local db = _G.LibQuestieDB
    local npcs = db and db.Npc
    if npcs and npcs.Get then return npcs end
end

local function AddNPCName(entries, npcs, id)
    local name = npcs.Get(id, "name")
    if type(name) == "string" and name:find("%S") then
        entries[#entries + 1] = {
            kind = "npc", id = id, name = name, key = name:lower():gsub("%s+", " "),
            matchLabel = ("NPC %d"):format(id),
        }
    end
end

function addon.FindNPCNames(query)
    local npcs = GetNPCs()
    if not npcs or not npcs.GetAllIds then return {} end
    query = query:gsub("%s+", " ")
    local index, loadNames = addon.ReadQuestieIndex(npcIndex, npcs, AddNPCName)
    if not loadNames then
        local matches = addon.FindNamedEntries(index, query)
        return matches
    end
    return {}, function(done)
        return loadNames(function(entries) done(addon.FindNamedEntries(entries, query)) end)
    end
end

local function NPCDetails(npcs, id, name)
    local locations = addon.GetEntityLocations(npcs, id)
    for _, location in ipairs(locations) do location.pinTargetName = name end
    local title = ("%s  ·  NPC %d"):format(name:gsub("|", "||"), id)
    if #locations == 0 then title = title .. "\nNo known locations." end
    local showLoot = addon.IsAutomaticSectionEnabled("NPC Loot")
    local showVendors = addon.IsAutomaticSectionEnabled("Vendor Items")
    if not showLoot and not showVendors then return locations, title end

    local function Results(loot, sold, hint, load)
        if #loot == 0 and #sold == 0 then return locations, hint, load end
        local sections = {}
        if #locations > 0 then sections[#sections + 1] = { title = "Locations", rows = locations } end
        if #loot > 0 then sections[#sections + 1] = { title = "Loot", rows = loot, collapsible = true } end
        if #sold > 0 then sections[#sections + 1] = { title = "Sells", rows = sold, collapsible = true } end
        local first = table.remove(sections, 1)
        sections.title, sections.collapsible = first.title, first.collapsible
        return first.rows, hint, load, nil, sections
    end

    local loot, sold, load = addon.FindNPCItems(id, name, showLoot, showVendors)
    if not load then return Results(loot, sold, title) end
    local checking = showLoot and (showVendors and "Checking for loot and vendor items…" or "Checking for loot…")
        or "Checking for vendor items…"
    return Results(loot, sold, title .. "\n" .. checking, function(done)
        return load(function(drops, vendors) done(Results(drops, vendors, title)) end)
    end)
end

function addon.SearchNPCs(query)
    local npcs = GetNPCs()
    if not npcs then return {}, "Enable QuestieDB to search NPCs and mobs." end
    query = query:match('^"%s*(.-)%s*"$') or query
    if query == "" then return {}, "Enter an NPC or mob name or ID." end
    if query:match("^%d+$") then
        local id = tonumber(query)
        local name = id and id > 0 and id <= 2147483647 and npcs.Get(id, "name")
        if type(name) ~= "string" or not name:find("%S") then
            return {}, "No NPC or mob found with that ID."
        end
        return NPCDetails(npcs, id, name)
    end
    if not npcs.GetAllIds then return {}, "Update QuestieDB to search NPCs by name." end

    local function Results(matches)
        return matches, #matches == 0 and "No matching NPCs or mobs." or nil
    end
    local matches, load = addon.FindNPCNames(query)
    if not load then return Results(matches) end
    return {}, "Loading NPC names…", function(done)
        return load(function(found) done(Results(found)) end)
    end
end
