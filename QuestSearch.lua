local _, addon = ...
local questIndex, rewardIndex = {}, {}

local function Read(entity, id, field)
    if not entity or not entity.Get then return end
    local ok, value = pcall(entity.Get, id, field)
    if ok then return value end
end

local function Text(value)
    if issecretvalue and issecretvalue(value) then return end
    if type(value) == "string" and value:find("%S") then return value end
end

local function Unquote(query)
    query = query:match("^%s*(.-)%s*$")
    return query:match('^"%s*(.-)%s*"$') or query
end

function addon.IsQuestDetailQuery(query)
    local shortcut, target = query:match("^%s*(@%a+)%s+(.+)$")
    return addon.GetSearchShortcut(shortcut) == "@quest" and Unquote(target):match("^%d+$") ~= nil
end

local function AddQuestTitle(entries, quests, id)
    local name = Text(Read(quests, id, "name"))
    if name then
        entries[#entries + 1] = { kind = "quest", id = id, name = name, key = name:lower(),
            matchLabel = ("Quest %d"):format(id) }
    end
end

local function QuestPrerequisites(quests, id)
    local single = Read(quests, id, "preQuestSingle")
    if single then return single, false end
    return Read(quests, id, "preQuestGroup"), true
end

local function ReadQuestLinks(quests, id, link)
    local prerequisites, grouped = QuestPrerequisites(quests, id)
    for _, prerequisite in ipairs(prerequisites or {}) do
        -- Negative group entries still require that quest, but skip its alternatives.
        link(grouped and math.abs(prerequisite) or prerequisite, id)
    end
    link(id, Read(quests, id, "nextQuestInChain"))
    link(id, Read(quests, id, "breadcrumbForQuestId"))
    for _, questID in ipairs(Read(quests, id, "childQuests") or {}) do link(id, questID) end
end

local function AddDirection(index, from, to)
    local links = index[from]
    if not links then
        links = {}
        index[from] = links
    end
    links[#links + 1] = to
end

local function IndexQuestLinks(catalog, quests, id)
    ReadQuestLinks(quests, id, function(previousID, nextID)
        if type(previousID) ~= "number" or previousID <= 0 or type(nextID) ~= "number"
            or nextID <= 0 or previousID == nextID then return end
        AddDirection(catalog.followUps, previousID, nextID)
        AddDirection(catalog.prerequisites, nextID, previousID)
    end)
end

local function AddQuestRecord(catalog, quests, id)
    if not catalog.titles then catalog.titles, catalog.followUps, catalog.prerequisites = {}, {}, {} end
    AddQuestTitle(catalog.titles, quests, id)
    IndexQuestLinks(catalog, quests, id)
end

local function AddItemRewards(rewards, items, id)
    local quests = Read(items, id, "questRewards")
    if type(quests) ~= "table" then return end
    for _, questID in ipairs(quests) do
        local entries = rewards[questID]
        if not entries then
            entries = {}
            rewards[questID] = entries
        end
        if entries[#entries] ~= id then entries[#entries + 1] = id end
    end
end

local function ItemRow(db, id)
    return { id = id, name = Text(Read(db.Item, id, "name")) or (addon.index and addon.index[id]) }
end

local function AddQuestContacts(rows, db, groups, label)
    if type(groups) ~= "table" then return end
    for group, entity in ipairs({ "Npc", "Object", "Item" }) do
        for _, id in ipairs(groups[group] or {}) do
            local contactName = group ~= 3 and Text(Read(db[entity], id, "name"))
            local row = group == 3 and ItemRow(db, id)
                or { kind = "text", name = contactName or (entity .. " " .. id) }
            if group == 1 and contactName then
                row.relatedQuery, row.relatedLabel = "@npc " .. id, "View NPC details"
            elseif group == 2 and contactName then
                row.relatedQuery, row.relatedLabel = "@object " .. id, "Show object locations"
            end
            if group ~= 3 then row.pinEntity, row.pinEntityID = entity, id end
            row.matchLabel = label
            rows[#rows + 1] = row
        end
    end
end

local function IsOnQuest(id)
    local log = C_QuestLog
    if not log or not log.IsOnQuest then return end
    local ok, onQuest = pcall(log.IsOnQuest, id)
    return ok and (not issecretvalue or not issecretvalue(onQuest)) and onQuest
end

local function LiveObjectives(id)
    if not IsOnQuest(id) or not C_QuestLog.GetQuestObjectives then return end
    local readOK, objectives = pcall(C_QuestLog.GetQuestObjectives, id)
    if not readOK or (issecretvalue and issecretvalue(objectives)) or type(objectives) ~= "table" then return end

    local rows = {}
    for _, objective in ipairs(objectives) do
        if not issecretvalue or not issecretvalue(objective) then
            local label = Text(objective.text)
            if label then
                local current, total = objective.numFulfilled, objective.numRequired
                local counters = not issecretvalue or not (issecretvalue(current) or issecretvalue(total))
                local progress = counters and type(current) == "number" and type(total) == "number" and total > 0
                    and ("%d/%d"):format(current, total) or nil
                local finished = objective.finished
                if not progress and (not issecretvalue or not issecretvalue(finished)) and finished == true then
                    progress = "Complete"
                end
                rows[#rows + 1] = { kind = "text", name = label, matchLabel = progress }
            end
        end
    end
    if #rows > 0 then return rows end
end

local function AddQuestObjectives(rows, db, id, data)
    local objectives = LiveObjectives(id) or {}
    local function Add(text)
        if Text(text) then objectives[#objectives + 1] = { kind = "text", name = text:gsub("%s+", " ") } end
    end
    if #objectives == 0 then
        for _, description in ipairs(Read(db.Quest, id, "objectivesText") or {}) do Add(description) end
    end
    if #objectives == 0 then
        for _, objective in ipairs(data[1] or {}) do
            Add(Text(objective[2]) or Read(db.Npc, objective[1], "name"))
        end
        for _, objective in ipairs(data[2] or {}) do
            Add(Text(objective[2]) or Read(db.Object, objective[1], "name"))
        end
        for _, objective in ipairs(data[3] or {}) do Add(objective[2]) end
        local reputation = data[4]
        if reputation and reputation[1] > 0 then
            local id, amount = reputation[1], reputation[2]
            local faction = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(id)
            local name = (faction and Text(faction.name)) or (GetFactionInfoByID and Text(GetFactionInfoByID(id)))
                or ("Faction %d"):format(id)
            Add(("%s reputation (%s)"):format(name, amount))
        end
        for _, objective in ipairs(data[5] or {}) do
            Add(Text(objective[3]) or Read(db.Npc, objective[2], "name"))
        end
        for _, objective in ipairs(data[6] or {}) do
            Add(Text(objective[2]) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(objective[1])))
        end
        local trigger = Read(db.Quest, id, "triggerEnd")
        Add(trigger and trigger[1])
    end
    if #objectives > 0 then
        rows[#rows + 1] = { kind = "text", name = "Objectives", sectionHeader = true }
        for _, row in ipairs(objectives) do rows[#rows + 1] = row end
    end
end

local function AddQuestItems(rows, db, title, itemIDs, isReward)
    if #itemIDs == 0 then return end
    rows[#rows + 1] = { kind = "text", name = title, sectionHeader = true }
    local seen = {}
    for _, itemID in ipairs(itemIDs) do
        if itemID > 0 and not seen[itemID] then
            seen[itemID] = true
            local row = ItemRow(db, itemID)
            row.questReward = isReward
            rows[#rows + 1] = row
        end
    end
end

local function AddQuestChain(rows, quests, id, links, title, direction)
    local entries, queue, steps = {}, { id }, { [id] = 0 }
    local first = 1
    while first <= #queue do
        local questID = queue[first]
        local distance = steps[questID] + 1
        for _, linkedID in ipairs(links[questID] or {}) do
            if steps[linkedID] == nil then
                steps[linkedID] = distance
                queue[#queue + 1] = linkedID
                local index = #entries + 1
                AddQuestTitle(entries, quests, linkedID)
                if entries[index] then
                    entries[index].matchLabel = ("%d %s %s"):format(distance, distance == 1 and "step" or "steps", direction)
                end
            end
        end
        first = first + 1
    end
    if #entries == 0 then return end
    local name = title == "Previous quests" and #entries == 1 and "Previous quest" or title
    rows[#rows + 1] = {
        kind = "text", name = name, sectionHeader = true, collapsible = #entries, sectionKey = title,
    }
    for _, entry in ipairs(entries) do rows[#rows + 1] = entry end
end

local function AddQuestChains(rows, quests, id, catalog)
    local showPrevious = addon.IsAutomaticSectionEnabled("Previous quests")
    local showNext = addon.IsAutomaticSectionEnabled("Next quests")
    if not showPrevious and not showNext then return end
    if not catalog or not catalog.followUps then
        catalog = { followUps = {}, prerequisites = {} }
        IndexQuestLinks(catalog, quests, id)
    end
    if showPrevious then AddQuestChain(rows, quests, id, catalog.prerequisites, "Previous quests", "back") end
    if showNext then AddQuestChain(rows, quests, id, catalog.followUps, "Next quests", "ahead") end
end

local function QuestXPLabel(db, id)
    if GetQuestLogRewardXP and IsOnQuest(id) then
        local ok, xp = pcall(GetQuestLogRewardXP, id)
        if ok and (not issecretvalue or not issecretvalue(xp)) and type(xp) == "number" and xp >= 0 then
            return ("%d XP"):format(xp)
        end
    end
    local support = db.Support and db.Support.Get and db.Support.Get("QuestXP")
    local entry = support and support.db and support.db[id]
    local xp = entry and entry[2]
    if type(xp) == "number" and xp > 0 then return ("%d base XP"):format(xp) end
end

local function QuestDetails(db, id, name)
    local parts = { name }
    local zone = Read(db.Quest, id, "zoneOrSort")
    local zoneName = type(zone) == "number" and zone > 0 and GetAreaInfo and Text(GetAreaInfo(zone))
    if zoneName then parts[#parts + 1] = zoneName end
    local requiredLevel = Read(db.Quest, id, "requiredLevel")
    if type(requiredLevel) == "number" and requiredLevel > 0 then
        parts[#parts + 1] = ("Requires level %d"):format(requiredLevel)
    end
    parts[#parts + 1] = QuestXPLabel(db, id)
    local title = (table.concat(parts, "  ·  "):gsub("|", "||"))
    local catalog, loadCatalog
    if addon.IsAutomaticSectionEnabled("Next quests") or addon.IsAutomaticSectionEnabled("Previous quests") then
        catalog, loadCatalog = addon.ReadQuestieIndex(questIndex, db.Quest, AddQuestRecord)
    end

    local function Rows(rewards)
        local rows = {}
        AddQuestContacts(rows, db, Read(db.Quest, id, "startedBy"), "Starts quest")
        AddQuestContacts(rows, db, Read(db.Quest, id, "finishedBy"), "Turn in")
        local objectives = Read(db.Quest, id, "objectives") or {}
        AddQuestObjectives(rows, db, id, objectives)
        local required = {}
        for _, objective in ipairs(objectives[3] or {}) do required[#required + 1] = objective[1] end
        for _, itemID in ipairs(Read(db.Quest, id, "requiredSourceItems") or {}) do required[#required + 1] = itemID end
        for _, objective in ipairs(objectives[6] or {}) do
            if objective[3] and objective[3] > 0 then required[#required + 1] = objective[3] end
        end
        AddQuestItems(rows, db, "Required items", required)
        AddQuestItems(rows, db, "Reward items", rewards and rewards[id] or {}, true)
        AddQuestChains(rows, db.Quest, id, catalog)
        return rows
    end

    local rewards, loadRewards = addon.ReadQuestieIndex(rewardIndex, db.Item, AddItemRewards)
    if not loadRewards and not loadCatalog then return Rows(rewards), title end
    local loading = (loadRewards and loadCatalog and "Loading quest details…")
        or (loadRewards and "Loading reward items…") or "Loading quest chain…"
    return Rows(rewards), title .. "\n" .. loading, function(done)
        local waitingForRewards, waitingForCatalog = loadRewards ~= nil, loadCatalog ~= nil
        local cancelRewards, cancelCatalog
        local function Finish()
            if not waitingForRewards and not waitingForCatalog then done(Rows(rewards), title) end
        end
        if loadRewards then
            cancelRewards = loadRewards(function(index)
                rewards, waitingForRewards = index, false
                Finish()
            end)
        end
        if loadCatalog then
            cancelCatalog = loadCatalog(function(index)
                catalog, waitingForCatalog = index, false
                Finish()
            end)
        end
        return function()
            if cancelRewards then cancelRewards() end
            if cancelCatalog then cancelCatalog() end
        end
    end
end

function addon.FindQuestTitles(query)
    local db = _G.LibQuestieDB
    local quests = db and db.Quest
    if not quests or not quests.Get or not quests.GetAllIds then return {} end
    query = query:gsub("%s+", " ")
    local index, load = addon.ReadQuestieIndex(questIndex, quests, AddQuestRecord)
    if not load then
        local matches = addon.FindNamedEntries(index.titles or {}, query)
        return matches
    end
    return {}, function(done)
        return load(function(catalog) done(addon.FindNamedEntries(catalog.titles or {}, query)) end)
    end
end

function addon.SearchQuests(query)
    local db = _G.LibQuestieDB
    local quests = db and db.Quest
    if not quests or not quests.Get then return {}, "Enable QuestieDB to search quests." end
    query = Unquote(query):gsub("%s+", " ")
    if query == "" then return {}, "Enter a quest name or ID." end
    if query:match("^%d+$") then
        local id = tonumber(query)
        local name = id and id > 0 and id <= 2147483647 and Text(Read(quests, id, "name"))
        if not name then return {}, "No quest found with that ID." end
        return QuestDetails(db, id, name)
    end
    if not quests.GetAllIds then return {}, "Update QuestieDB to search by quest name." end

    local function Results(matches)
        return matches, #matches == 0 and "No quests found." or nil
    end
    local matches, load = addon.FindQuestTitles(query)
    if not load then return Results(matches) end
    return {}, "Loading quest names…", function(done)
        return load(function(found) done(Results(found)) end)
    end
end
