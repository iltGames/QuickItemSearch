local addonName, addon = ...
local ATLAS_DUNGEONS = "AtlasLootClassic_DungeonsAndRaids"
local storageName = addonName .. "SourceDB"
local atlasDB, atlasItems

local function Clean(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return nil end
    local clean = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return clean:match("^%s*(.-)%s*$")
end

local function Rate(value)
    if type(value) == "number" and value >= 0 and value <= 100 then return value end
end

local function AtlasIndex()
    local atlas = _G.AtlasLoot
    local itemDB = atlas and atlas.ItemDB
    if not itemDB or not itemDB.Get or not itemDB.GetItemTable or not itemDB.GetNameData_UNSAFE then return end
    local db = itemDB:Get(ATLAS_DUNGEONS)
    if not db and C_AddOns and C_AddOns.LoadAddOn and not InCombatLockdown() then
        C_AddOns.LoadAddOn(ATLAS_DUNGEONS)
        db = itemDB:Get(ATLAS_DUNGEONS)
    end
    if type(db) ~= "table" then return end
    if atlasDB == db then return atlasItems end

    local items = {}
    local dropRates = atlas.Data and atlas.Data.Droprate
    for key, instance in pairs(db) do
        if type(instance) == "table" and type(instance.items) == "table" then
            for bossIndex, boss in pairs(instance.items) do
                if type(bossIndex) == "number" and type(boss) == "table" then
                    local named, zone, name = pcall(itemDB.GetNameData_UNSAFE, itemDB, ATLAS_DUNGEONS, key, bossIndex)
                    zone, name = Clean(zone), Clean(name)
                    if named and name and name ~= "" and zone and zone ~= "" then
                        local npcID = boss.npcID
                        if type(npcID) == "table" then npcID = #npcID == 1 and npcID[1] or nil end
                        if type(npcID) ~= "number" then npcID = nil end
                        for difficulty in pairs(boss) do
                            if type(difficulty) == "number" then
                                local ok, loot, layout = pcall(itemDB.GetItemTable, itemDB, ATLAS_DUNGEONS, key, bossIndex, difficulty)
                                if ok and type(loot) == "table" and (not layout or layout[1] == "Item") then
                                    for _, slot in ipairs(loot) do
                                        local itemID = type(slot) == "table" and slot[2]
                                        if type(itemID) == "number" and itemID > 0 then
                                            local rate = npcID and dropRates and dropRates.GetData and Rate(dropRates:GetData(npcID, itemID))
                                            local rows = items[itemID] or {}
                                            items[itemID] = rows
                                            rows[#rows + 1] = { kind = "drop", id = npcID, name = name, zone = zone, rate = rate }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    atlasDB, atlasItems = db, items
    return items
end

local QUESTIE_FIELDS = {
    { field = "npcDrops", entity = "Npc", kind = "drop" },
    { field = "objectDrops", entity = "Object", kind = "object" },
    { field = "itemDrops", entity = "Item", kind = "container" },
    { field = "vendors", entity = "Npc", kind = "vendor" },
    { field = "questRewards", entity = "Quest", kind = "quest" },
}

local function QuestieSources(itemID)
    local db = _G.LibQuestieDB
    if not db or not db.Item or not db.Item.Get then return end
    local rates
    if _G.QuestieLoader and QuestieLoader.ImportModule then
        local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, "DropDB")
        if ok then rates = module end
    end

    local rows = {}
    for _, field in ipairs(QUESTIE_FIELDS) do
        local entity = db[field.entity]
        local ids = db.Item.Get(itemID, field.field)
        if entity and entity.Get and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local name = Clean(entity.Get(id, "name"))
                if name and name ~= "" then
                    local rate
                    if field.kind == "drop" and rates and rates.GetItemDroprate then
                        local observation = rates.GetItemDroprate(itemID, id)
                        rate = Rate(type(observation) == "table" and observation[1] or observation)
                    end
                    rows[#rows + 1] = { kind = field.kind, id = id, name = name, rate = rate }
                end
            end
        end
    end
    return rows
end

local function SameSource(left, right)
    if left.kind ~= right.kind or (left.zone and right.zone and left.zone ~= right.zone) then return false end
    if left.id and right.id then return left.id == right.id end
    return left.name == right.name
end

local function AddRows(result, rows)
    for _, row in ipairs(rows or {}) do
        local match
        for _, existing in ipairs(result) do
            if SameSource(row, existing) then
                match = existing
                break
            end
        end
        if match then
            match.rate = match.rate or row.rate
            match.zone = match.zone or row.zone
            match.id = match.id or row.id
        else
            result[#result + 1] = { kind = row.kind, id = row.id, name = row.name, zone = row.zone, rate = row.rate }
        end
    end
end

function addon.GetItemSources(itemID)
    local ok, atlas = pcall(AtlasIndex)
    local questieOK, questie = pcall(QuestieSources, itemID)
    local result = {}
    AddRows(result, ok and atlas and atlas[itemID])
    AddRows(result, questieOK and questie)
    local hasLiveSources = #result > 0

    local backup = _G[storageName]
    if type(backup) ~= "table" then
        backup = {}
        _G[storageName] = backup
    end
    AddRows(result, backup[itemID])
    if hasLiveSources then backup[itemID] = result end
    return result
end

local LABELS = { drop = "Drops from", object = "Found in", container = "Found in", vendor = "Sold by", quest = "Quest reward" }

local function AtlasLineAlreadyShown(tooltip, source)
    if not source.zone or not tooltip.GetName or not tooltip.NumLines then return false end
    local frameName = tooltip:GetName()
    if not frameName then return false end
    for i = 1, tooltip:NumLines() do
        local line = _G[frameName .. "TextLeft" .. i]
        local text = line and Clean(line:GetText())
        if text and text:find(source.zone, 1, true) and text:find(source.name, 1, true) then
            if not source.rate or text:find("%", 1, true) then return true end
        end
    end
    return false
end

function addon.AppendItemSources(tooltip, itemID)
    if not itemID or not tooltip or not tooltip.AddLine then return end
    local added = 0
    for _, source in ipairs(addon.GetItemSources(itemID)) do
        if not AtlasLineAlreadyShown(tooltip, source) then
            if added == 6 then
                tooltip:AddLine("Additional sources omitted.", 0.71, 0.66, 0.57, true)
                return
            end
            if added == 0 then
                tooltip:AddLine(" ")
                tooltip:AddLine("Sources", 0.86, 0.66, 0.35)
            end
            local location = source.name .. (source.zone and ("  -  " .. source.zone) or "")
            local label = LABELS[source.kind]
            local rate = source.rate and ("  (" .. ("%.2f"):format(source.rate):gsub("0+$", ""):gsub("%.$", "") .. "%)") or ""
            tooltip:AddLine(label .. ": " .. (location:gsub("|", "||")) .. rate, 0.95, 0.91, 0.83, true)
            added = added + 1
        end
    end
end
