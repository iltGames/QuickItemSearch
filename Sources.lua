local addonName, addon = ...
local ATLAS_DUNGEONS = "AtlasLootClassic_DungeonsAndRaids"
local storageName = addonName .. "SourceDB"
local atlasDB, atlasItems, atlasBosses, atlasBossDrops, atlasInstances
local instanceAliases = {
    hot = "hallofthanes", rol = "ruinsoflordaeron", cod = "cityofdalaran",
    esw = "excavationsitewetlands", ks = "kroldokstronghold", dc = "drownedcity",
    st = "templeofatalhakkar", vc = "deadmines", wc = "wailingcaverns",
    sfk = "shadowfangkeep", bfd = "blackfathomdeeps", rfk = "razorfenkraul",
    rfd = "razorfendowns", zf = "zulfarrak", brd = "blackrockdepths",
    lbrs = "lowerblackrockspire", ubrs = "upperblackrockspire", strat = "stratholme",
    scholo = "scholomance", sm = "scarletmonastery", dme = "diremauleast",
    dmw = "diremaulwest", dmn = "diremaulnorth",
}

local function Clean(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return nil end
    local clean = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return clean:match("^%s*(.-)%s*$")
end

local function Rate(value)
    if type(value) == "number" and value >= 0 and value <= 100 then return value end
end

local function InstanceKey(name)
    return (name:lower():gsub("^the%s+", ""):gsub("’", ""):gsub("[%p%s]", ""))
end

local function DungeonKey(name)
    local key = InstanceKey(name)
    return key == "sunkentemple" and "templeofatalhakkar" or key
end

local function LevelText(level, high)
    if type(level) == "table" then return LevelText(level[1], level[2]) end
    if type(level) == "string" then
        return level:match("^%d+%+?$") or level:gsub("–", "-"):match("^%d+%s*%-%s*%d+$")
    end
    if type(level) == "number" and level > 0 then
        return type(high) == "number" and high > level and (level .. "–" .. high) or tostring(level)
    end
end

local function InstanceGroup(groups, name, order)
    local key = InstanceKey(name)
    local group = groups[key]
    if not group then
        group = { name = name, order = order, loot = {} }
        groups[key] = group
    end
    group.order = math.min(group.order, order)
    return group
end

local function IsTrashList(name, locales)
    return name:lower():find("trash", 1, true) or (locales
        and (name == Clean(locales["Trash"]) or name == Clean(locales["Trash Mobs"])))
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
    if atlasDB == db then return atlasItems, atlasBosses, atlasBossDrops, atlasInstances end

    local items, bosses, bossDrops, instances = {}, {}, {}, {}
    local dropRates = atlas.Data and atlas.Data.Droprate
    for key, instance in pairs(db) do
        if type(instance) == "table" and type(instance.items) == "table" then
            for bossIndex, boss in pairs(instance.items) do
                if type(bossIndex) == "number" and type(boss) == "table" then
                    local named, zone, name = pcall(itemDB.GetNameData_UNSAFE, itemDB, ATLAS_DUNGEONS, key, bossIndex)
                    zone, name = Clean(zone), Clean(name)
                    if named and name and name ~= "" and zone and zone ~= "" then
                        local zoneKey = DungeonKey(zone)
                        local instanceLoot = instances[zoneKey] or { name = zone, groups = {} }
                        instances[zoneKey] = instanceLoot
                        local range = instance.LevelRange
                        if type(range) == "table" then
                            instanceLoot.level = instanceLoot.level or LevelText(range[2], range[3])
                        end
                        local lootIDs = {}
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
                                            lootIDs[itemID] = true
                                            if not boss.ExtraList then bossDrops[itemID] = true end
                                            local rate = npcID and dropRates and dropRates.GetData and Rate(dropRates:GetData(npcID, itemID))
                                            local rows = items[itemID] or {}
                                            items[itemID] = rows
                                            rows[#rows + 1] = { kind = "drop", id = npcID, name = name, zone = zone, rate = rate }
                                        end
                                    end
                                end
                            end
                        end
                        if next(lootIDs) then
                            local trash = boss.ExtraList and IsTrashList(name, atlas.Locales)
                            if trash or not boss.ExtraList then
                                local groupName = trash and "Trash" or name
                                local order = trash and math.huge or bossIndex
                                local group = InstanceGroup(instanceLoot.groups, groupName, order)
                                if not trash then
                                    group.level = group.level or LevelText(boss.Level)
                                    group.npcID = group.npcID or npcID
                                end
                                for id in pairs(lootIDs) do group.loot[id] = true end
                            end
                            bosses[#bosses + 1] = {
                                name = name, key = name:lower(), loot = lootIDs,
                                npcIDs = type(boss.npcID) == "table" and boss.npcID or (npcID and { npcID }),
                                isEncounter = not boss.ExtraList,
                            }
                        end
                    end
                end
            end
        end
    end
    atlasDB, atlasItems, atlasBosses, atlasBossDrops, atlasInstances = db, items, bosses, bossDrops, instances
    return items, bosses, bossDrops, instances
end

local function FindBossMatches(bosses, query, exactOnly, encountersOnly)
    local exact, partial = {}, {}
    for _, boss in ipairs(bosses) do
        if not encountersOnly or boss.isEncounter then
            if boss.key == query then
                exact[#exact + 1] = boss
            elseif not exactOnly and boss.key:find(query, 1, true) then
                partial[#partial + 1] = boss
            end
        end
    end
    return #exact > 0 and exact or partial
end

function addon.GetBossDropItems(query)
    local ok, _, bosses, bossDrops = pcall(AtlasIndex)
    if not ok or not bossDrops then return nil, "AtlasLoot boss data is unavailable." end
    if not query then return bossDrops end

    local matches = FindBossMatches(bosses, query, false, true)
    if #matches == 0 then return nil, "No matching bosses." end
    local drops = {}
    for _, boss in ipairs(matches) do
        for id in pairs(boss.loot) do drops[id] = true end
    end
    return drops
end

local function LootRows(ids, qualities, journalItems)
    local results = {}
    for id in pairs(ids) do
        if not addon.IsPTRItem(id) then
            local item = journalItems and journalItems[id]
            local name = addon.index[id] or (item and item[2])
            results[#results + 1] = {
                id = id, name = name, key = name and name:lower() or "~", quality = qualities and qualities[id],
            }
        end
    end
    table.sort(results, function(left, right)
        if left.key == right.key then return left.id < right.id end
        return left.key < right.key
    end)
    return results
end

local function InstanceItemQuality(id, journalItem)
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if issecretvalue and issecretvalue(quality) then quality = nil end
    local gear = addon.gear and addon.gear[id]
    if quality == nil and gear then quality = gear[4] end
    if quality == nil and journalItem then quality = journalItem[4] end
    if quality == nil and C_Item.GetItemInfo then quality = select(3, C_Item.GetItemInfo(id)) end
    if type(quality) ~= "number" or (issecretvalue and issecretvalue(quality)) then return end
    if quality >= 3 then return quality end
    if quality ~= 2 then return false end
    local class
    if C_Item.GetItemInfoInstant then class = select(6, C_Item.GetItemInfoInstant(id)) end
    if class == nil and journalItem and type(journalItem[3]) == "string" then
        return (journalItem[3]:match("^Recipe") or journalItem[3] == "Blueprint") and quality or false
    end
    if type(class) ~= "number" or (issecretvalue and issecretvalue(class)) then return end
    return class == 9 and quality or false -- Recipe item class.
end

local function MergeInstance(pair, journal, journalItems)
    local atlas, dungeon = pair.atlas, pair.journal
    if not dungeon then return atlas end
    local instance = { name = pair.name, level = LevelText(dungeon.level) or (atlas and atlas.level), groups = {} }
    local nextOrder = 0
    for _, source in pairs(atlas and atlas.groups or {}) do
        local group = InstanceGroup(instance.groups, source.name, source.order)
        group.level, group.npcID = source.level, source.npcID
        for id in pairs(source.loot) do group.loot[id] = true end
        if source.order < math.huge then nextOrder = math.max(nextOrder, source.order) end
    end
    local levels = journal.BOSS_LEVELS or {}
    for index, boss in ipairs(dungeon.bosses or {}) do
        local name = Clean(boss.name)
        if name and name ~= "" then
            local trash = boss.trash or IsTrashList(name)
            name = trash and "Trash" or name
            local group = instance.groups[InstanceKey(name)]
            if not group and not trash then
                for _, alias in ipairs(boss.aliases or {}) do
                    group = instance.groups[InstanceKey(alias)]
                    if group then break end
                end
                if not group and type(boss.npcID) == "number" then
                    for _, candidate in pairs(instance.groups) do
                        if candidate.npcID == boss.npcID then group = candidate; break end
                    end
                end
            end
            group = group or InstanceGroup(instance.groups, name, trash and math.huge or nextOrder + index)
            if not trash then
                local byDungeon = levels[boss.fdjDungeon or pair.name]
                group.level = LevelText(byDungeon and byDungeon[boss.name]) or LevelText(boss.level) or group.level
            end
            for _, item in ipairs(boss.loot or {}) do
                if type(item[1]) == "number" and item[1] > 0 then
                    group.loot[item[1]] = true
                    journalItems[item[1]] = item
                end
            end
        end
    end
    return instance
end

local function InstanceCatalog()
    local ok, _, _, _, atlasInstancesByName = pcall(AtlasIndex)
    local journal = _G.ForeverDungeonJournal_NS
    local instances = {}
    for instanceKey, instance in pairs(ok and atlasInstancesByName or {}) do
        instances[instanceKey] = { name = instance.name, atlas = instance }
    end
    for name, dungeon in pairs(journal and journal.DB or {}) do
        if type(name) == "string" and type(dungeon) == "table" then
            local instanceKey = DungeonKey(name)
            local pair = instances[instanceKey] or {}
            pair.name, pair.journal = name, dungeon
            instances[instanceKey] = pair
        end
    end
    return instances, journal
end

local function MatchInstances(instances, key)
    if instances[key] then return { instances[key] } end
    local direMaulAlias = key == "dm"
    local matches = {}
    for instanceKey, instance in pairs(instances) do
        if (not direMaulAlias and instanceKey:find(key, 1, true)) or (direMaulAlias
            and (instanceKey:find("deadmines", 1, true) or instanceKey:find("diremaul", 1, true))) then
            matches[#matches + 1] = instance
        end
    end
    table.sort(matches, function(left, right) return left.name < right.name end)
    return matches
end

local function InstanceQueryKey(query)
    local key = DungeonKey(query):gsub("^kroldrok", "kroldok")
    return instanceAliases[key] or key
end

function addon.FindDungeons(query)
    local key = InstanceQueryKey(query)
    if #key < 2 then return {} end
    local instances = InstanceCatalog()
    local rows = {}
    for _, instance in ipairs(MatchInstances(instances, key)) do
        local level = instance.journal and LevelText(instance.journal.level) or (instance.atlas and instance.atlas.level)
        rows[#rows + 1] = { kind = "dungeon", name = instance.name, matchLabel = level and ("Levels " .. level) }
    end
    return rows
end

function addon.SearchInstanceLoot(query)
    if query == "" then
        local name, instanceType = GetInstanceInfo()
        if instanceType ~= "party" and instanceType ~= "raid" then
            return {}, "Enter a dungeon name or use @dungeon inside an instance."
        end
        query = Clean(name) or ""
    end
    local key = InstanceQueryKey(query)
    if #key < 2 then return {}, "Enter at least two characters of the dungeon name." end

    local instances, journal = InstanceCatalog()
    if not next(instances) then return {}, "Dungeon data is unavailable from AtlasLoot or Forever Dungeon Journal." end
    local matches = MatchInstances(instances, key)
    if #matches == 0 then return {}, "No matching dungeons or raids." end
    local journalItems = {}
    for index, pair in ipairs(matches) do matches[index] = MergeInstance(pair, journal, journalItems) end
    local label = #matches == 1 and matches[1].name:gsub("|", "||") or ("%d matching instances"):format(#matches)
    if #matches == 1 and matches[1].level then label = label .. " · Levels " .. matches[1].level end
    local groups, qualities, waiting = {}, {}, {}
    for _, instance in ipairs(matches) do
        local ordered = {}
        for _, group in pairs(instance.groups) do ordered[#ordered + 1] = group end
        table.sort(ordered, function(left, right)
            if left.order == right.order then return left.name < right.name end
            return left.order < right.order
        end)
        for _, group in ipairs(ordered) do
            local title = group.name .. (group.level and (" · Lv " .. group.level) or "")
            local instanceTitle = instance.name .. (instance.level and (" · Levels " .. instance.level) or "")
            groups[#groups + 1] = {
                title = #matches == 1 and title or (instanceTitle .. " · " .. title),
                loot = group.loot,
            }
            for id in pairs(group.loot) do
                if not addon.IsPTRItem(id) and qualities[id] == nil and not waiting[id] then
                    qualities[id] = InstanceItemQuality(id, journalItems[id])
                    if qualities[id] == nil then waiting[id] = true end
                end
            end
        end
    end

    local function BuildResults(status)
        local sections = {}
        for _, group in ipairs(groups) do
            local eligible = {}
            for id in pairs(group.loot) do
                if qualities[id] then eligible[id] = true end
            end
            if next(eligible) then
                sections[#sections + 1] = { title = group.title, rows = LootRows(eligible, qualities, journalItems) }
            end
        end
        local first = table.remove(sections, 1)
        local hint = first and ("Loot from " .. label) or ("No matching loot for " .. label .. ".")
        if status then hint = hint .. " · " .. status end
        if not first then return {}, hint end
        sections.title = first.title
        return first.rows, hint, nil, nil, sections
    end

    if not next(waiting) then return BuildResults() end
    if not C_Item.RequestLoadItemDataByID then return BuildResults("Some item data is unavailable") end
    local rows, hint, _, _, sections = BuildResults("Checking item quality")
    return rows, hint, function(done)
        local timer, attempts = nil, 0
        local function Check()
            for id in pairs(waiting) do
                qualities[id] = InstanceItemQuality(id, journalItems[id])
                if qualities[id] ~= nil then waiting[id] = nil end
            end
            attempts = attempts + 1
            if next(waiting) and attempts < 10 then
                timer = C_Timer.NewTimer(0.15, Check)
            else
                done(BuildResults(next(waiting) and "Some item data is unavailable"))
            end
        end
        for id in pairs(waiting) do pcall(C_Item.RequestLoadItemDataByID, id) end
        timer = C_Timer.NewTimer(0.15, Check)
        return function() timer:Cancel() end
    end, nil, sections
end

function addon.SearchBossLoot(query, exactOnly)
    local ok, _, bosses = pcall(AtlasIndex)
    if not ok or not bosses or #bosses == 0 then return nil, "AtlasLoot boss data is unavailable." end
    local matches = FindBossMatches(bosses, query, exactOnly)
    if #matches == 0 then return nil, "No matching bosses." end
    local loot = {}
    for _, boss in ipairs(matches) do
        for id in pairs(boss.loot) do loot[id] = true end
    end
    local results = LootRows(loot)
    if #matches == 1 then return results, "Drops from " .. matches[1].name end
    return results, ("Drops from %d matching bosses"):format(#matches)
end

local function HasID(ids, wanted)
    for _, id in ipairs(ids or {}) do
        if id == wanted then return true end
    end
    return false
end

function addon.SearchTargetLoot()
    local guid = UnitGUID("target")
    if issecretvalue and issecretvalue(guid) then return {}, "Target details are unavailable." end
    local kind, id
    if guid then kind, id = guid:match("^(%a+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-") end
    if kind ~= "Creature" and kind ~= "Vehicle" then return {}, "Select an NPC to look up its drops." end
    local npcID = tonumber(id)
    local name = Clean(UnitName("target"))
    local targetLabel = name and name ~= "" and name:gsub("|", "||") or ("NPC %d"):format(npcID)
    local title = "Drops from " .. targetLabel
    local loot = {}
    local ok, _, bosses = pcall(AtlasIndex)
    if not ok then bosses = nil end
    local nameKey = name and name:lower()
    for _, boss in ipairs(bosses or {}) do
        if boss.isEncounter and (HasID(boss.npcIDs, npcID) or (not boss.npcIDs and boss.key == nameKey)) then
            for itemID in pairs(boss.loot) do loot[itemID] = true end
        end
    end

    local function Finish()
        local rows = LootRows(loot)
        return rows, #rows > 0 and title or ("No indexed drops for " .. targetLabel .. ".")
    end

    local db = _G.LibQuestieDB
    local items = db and db.Item
    if not (items and items.Get and items.GetAllIds) then
        if not next(loot) then return {}, "No AtlasLoot match. QuestieDB can look up ordinary NPC drops." end
        return Finish()
    end
    local idsOK, ids = pcall(items.GetAllIds)
    if not idsOK or type(ids) ~= "table" or #ids == 0 then return Finish() end

    return LootRows(loot), title .. " · Checking QuestieDB", function(done)
        local timer
        local first = 1
        local function Step()
            local last = math.min(first + 249, #ids)
            for index = first, last do
                local itemID = ids[index]
                local readOK, sources = pcall(items.Get, itemID, "npcDrops")
                if readOK and type(sources) == "table" and HasID(sources, npcID) then
                    loot[itemID] = true
                end
            end
            if last == #ids then
                done(Finish())
            else
                first = last + 1
                timer = C_Timer.NewTimer(0, Step)
            end
        end
        timer = C_Timer.NewTimer(0, Step)
        return function() timer:Cancel() end
    end
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

function addon.GetQuestRewardFilter(query)
    local db = _G.LibQuestieDB
    local getItem = db and db.Item and db.Item.Get
    local getQuest = db and db.Quest and db.Quest.Get
    local backup = _G[storageName]
    local questID = query and tonumber(query:match("^%d+$"))
    if not getItem or (query and not questID and not getQuest) then
        local hasCachedQuests = false
        for _, rows in pairs(backup or {}) do
            for _, row in ipairs(rows) do
                if row.kind == "quest" then hasCachedQuests = true; break end
            end
            if hasCachedQuests then break end
        end
        if not hasCachedQuests then return nil, "QuestieDB quest reward data is unavailable." end
    end

    local titleMatches = {}
    local function Matches(id, name)
        if not query then return true end
        if questID then return id == questID end
        name = Clean(name)
        return name and name:lower():find(query, 1, true) ~= nil
    end

    return function(itemID)
        local ids = getItem and getItem(itemID, "questRewards")
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if titleMatches[id] == nil then
                    local name = query and not questID and getQuest and getQuest(id, "name")
                    titleMatches[id] = Matches(id, name) or false
                end
                if titleMatches[id] then return true end
            end
        end
        for _, row in ipairs(backup and backup[itemID] or {}) do
            if row.kind == "quest" and Matches(row.id, row.name) then return true end
        end
        return false
    end
end

local indexedQuestDB, questRequirements

local function StartQuestRequirementIndex()
    local db = _G.LibQuestieDB
    local questDB = db and db.Quest
    if not questDB or questDB == indexedQuestDB or not questDB.GetAllIds or not questDB.Get
        or not C_Timer or not C_Timer.After then return end

    indexedQuestDB, questRequirements = questDB, nil
    local ids, nextIndex
    local requirements = {}

    local function AddRequirement(itemID, questID)
        if type(itemID) ~= "number" or itemID <= 0 then return end
        local quests = requirements[itemID]
        if not quests then
            quests = {}
            requirements[itemID] = quests
        end
        if quests[#quests] ~= questID then quests[#quests + 1] = questID end
    end

    local function Step()
        if indexedQuestDB ~= questDB then return end
        if not ids then
            ids, nextIndex = questDB.GetAllIds(), 1
            if type(ids) ~= "table" then return end
        end
        local lastIndex = math.min(nextIndex + 99, #ids)
        for i = nextIndex, lastIndex do
            local questID = ids[i]
            local objectives = questDB.Get(questID, "objectives")
            -- QuestieDB stores item objectives in the third objective group.
            for _, objective in ipairs(objectives and objectives[3] or {}) do
                AddRequirement(objective[1], questID)
            end
            for _, objective in ipairs(objectives and objectives[6] or {}) do
                AddRequirement(objective[3], questID)
            end
            for _, itemID in ipairs(questDB.Get(questID, "requiredSourceItems") or {}) do
                AddRequirement(itemID, questID)
            end
        end
        if lastIndex < #ids then
            nextIndex = lastIndex + 1
            C_Timer.After(0, Step)
        else
            questRequirements = requirements
        end
    end

    C_Timer.After(0, Step)
end

StartQuestRequirementIndex()

function addon.GetItemQuestRequirements(itemID)
    StartQuestRequirementIndex()
    local db = _G.LibQuestieDB
    local quests = {}
    if not db or db.Quest ~= indexedQuestDB or not questRequirements then return quests end

    for _, questID in ipairs(questRequirements[itemID] or {}) do
        local name = Clean(db.Quest.Get(questID, "name"))
        if name and name ~= "" then
            quests[#quests + 1] = { id = questID, name = name }
        end
    end
    return quests
end

local function AppendQuestRequirements(tooltip, itemID)
    local quests = addon.GetItemQuestRequirements(itemID)
    if #quests == 0 then return false end
    tooltip:AddLine(" ")
    for i = 1, math.min(6, #quests) do
        tooltip:AddLine("Required for quest: " .. (quests[i].name:gsub("|", "||")), 1, 0.82, 0, true)
    end
    if #quests > 6 then
        tooltip:AddLine("Additional quest requirements omitted.", 0.71, 0.66, 0.57, true)
    end
    return true
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
                break
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
    return AppendQuestRequirements(tooltip, itemID)
end
