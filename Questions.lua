local _, addon = ...

-- Minimum skill for common Forever herbs and ore nodes. References:
-- https://theforevertavern.com/professions/herbalism
-- https://wowforeverclasses.com/articles/mining-leveling-guide-wow-forever
local herbs = {
    [765] = 1, [785] = 50, [2447] = 1, [2449] = 15, [2450] = 70, [2453] = 100,
    [3355] = 115, [3356] = 125, [3357] = 150, [3358] = 185, [3369] = 120, [3818] = 160,
    [3819] = 195, [3820] = 85, [3821] = 170, [4625] = 205, [8831] = 210, [8836] = 220,
    [8838] = 230, [8839] = 235, [8845] = 245, [8846] = 250, [13463] = 270, [13464] = 260,
    [13465] = 280, [13466] = 285, [13467] = 290, [13468] = 300,
}
local ores = {
    [2770] = { { "Copper Vein", 1 } },
    [2771] = { { "Tin Vein", 65 } },
    [2772] = { { "Iron Deposit", 125 } },
    [2775] = { { "Silver Vein", 75 } },
    [2776] = { { "Gold Vein", 155 } },
    [3858] = { { "Mithril Deposit", 175 } },
    [7911] = { { "Truesilver Deposit", 230 } },
    [10620] = { { "Small Thorium Vein", 245 }, { "Rich Thorium Vein", 275 } },
    [11370] = { { "Dark Iron Deposit", 230 } },
}

local function GatheringRow(id, name, profession, skill, nodeName)
    -- https://warcraft.wiki.gg/wiki/Forever_herbalism_techniques
    -- https://warcraft.wiki.gg/wiki/Forever_mining_techniques
    local baseline = skill == 1 and 0 or skill
    local greenOffset = profession == "Mining" and 50 or 65
    return {
        id = id, name = name, nodeName = nodeName, skill = skill, gatheringProfession = profession,
        matchLabel = ("%s %d"):format(profession, skill),
        gatheringThresholds = { skill, baseline + 25, baseline + greenOffset, baseline + 100 },
    }
end

local function NameRank(name, target)
    if not name then return 0 end
    local key = name:lower()
    if key == target then return 3 end
    if #target < 2 then return 0 end
    local start = key:find(target, 1, true)
    if start == 1 then return 2 end
    return start and 1 or 0
end

local function FindGatheringMatches(action, target)
    local bestRank, matches = 0, {}
    local function AddMatch(rank, entry, answer)
        if rank < bestRank then return end
        if rank > bestRank then bestRank, matches = rank, {} end
        entry.answer = answer
        matches[#matches + 1] = entry
    end

    if action ~= "mine" then
        for id, skill in pairs(herbs) do
            local name = addon.index[id]
            local rank = NameRank(name, target)
            if rank > 0 then
                local entry = GatheringRow(id, name, "Herbalism", skill)
                AddMatch(rank, entry, "Requires " .. entry.matchLabel .. ".")
            end
        end
    end
    if action ~= "pick" then
        for id, nodes in pairs(ores) do
            local name = addon.index[id]
            local itemRank = NameRank(name, target)
            local ranks, rank = {}, itemRank
            for index, node in ipairs(nodes) do
                ranks[index] = NameRank(node[1], target)
                rank = math.max(rank, ranks[index])
            end
            if name and rank > 0 and rank >= bestRank then
                local lines, skills, matchedNode = {}, {}
                for index, node in ipairs(nodes) do
                    if itemRank == rank or ranks[index] == rank then
                        lines[#lines + 1] = ("%s requires Mining %d."):format(node[1], node[2])
                        skills[#skills + 1] = tostring(node[2])
                        matchedNode = node
                    end
                end
                local entry = #skills == 1 and GatheringRow(id, name, "Mining", matchedNode[2], matchedNode[1])
                    or { id = id, name = name, matchLabel = "Mining " .. table.concat(skills, "/") }
                AddMatch(rank, entry, table.concat(lines, "\n"))
            end
        end
    end
    return matches
end

local gatheringCategories = {
    herb = "herbs", herbs = "herbs", herbalism = "herbs",
    ore = "ores", ores = "ores", mine = "ores", mining = "ores",
    vein = "ores", veins = "ores", deposit = "ores", deposits = "ores",
    node = "all", nodes = "all",
}

local function ListGatheringNodes(action, category)
    local results = {}
    if action ~= "mine" and category ~= "ores" then
        for id, skill in pairs(herbs) do
            local name = addon.index[id]
            if name then
                results[#results + 1] = GatheringRow(id, name, "Herbalism", skill)
            end
        end
    end
    if action ~= "pick" and category ~= "herbs" then
        for id, nodes in pairs(ores) do
            local name = addon.index[id]
            if name then
                for _, node in ipairs(nodes) do
                    local nodeName, skill = unpack(node)
                    results[#results + 1] = GatheringRow(id, name, "Mining", skill, nodeName)
                end
            end
        end
    end
    table.sort(results, function(left, right)
        if left.skill ~= right.skill then return left.skill < right.skill end
        local leftName, rightName = left.nodeName or left.name, right.nodeName or right.name
        if leftName == rightName then return left.id < right.id end
        return leftName < rightName
    end)
    return results
end

function addon.FindGatheringSection(query)
    if query == "" then return end
    local category = gatheringCategories[query]
    if category then return ListGatheringNodes("gather", category) end
    local matches = FindGatheringMatches("gather", query)
    table.sort(matches, function(left, right)
        if left.name == right.name then return left.id < right.id end
        return left.name:lower() < right.name:lower()
    end)
    return matches
end

function addon.AddItemGatheringDetails(items)
    local results = {}
    for _, item in ipairs(items) do
        local skill, nodes = herbs[item.id], ores[item.id]
        if skill then
            results[#results + 1] = GatheringRow(item.id, item.name, "Herbalism", skill)
        elseif nodes and #nodes == 1 then
            results[#results + 1] = GatheringRow(item.id, item.name, "Mining", nodes[1][2])
        else
            results[#results + 1] = item
            for _, node in ipairs(nodes or {}) do
                results[#results + 1] = GatheringRow(item.id, item.name, "Mining", node[2], node[1])
            end
        end
    end
    return results
end

local function MaxSkinningMobLevel(skill)
    -- https://www.wow-professions.com/forever/skinning-leveling-guide
    if skill < 100 then return 10 + math.floor(skill / 10) end
    return math.floor(skill / 5)
end

local function NumberRange(first, last)
    if first == last then return tostring(first) end
    return ("%d-%d"):format(first, last)
end

local function SkinningGrayRange(skill)
    -- Approximate from the gathering skill-up curve, using the existing mob-level thresholds.
    if skill < 100 then return "No gray mobs estimated at this skill." end
    return ("Estimated gray mobs (no skill-ups): levels 1-%d."):format(MaxSkinningMobLevel(skill - 100))
end

function addon.SearchSkinning(target)
    local skill = tonumber(target:match("^%d+$"))
    if skill then
        if skill < 1 or skill > 300 then return {}, "Enter a Skinning skill from 1 to 300." end
        return { { kind = "text", name = "Mob levels 1-" .. MaxSkinningMobLevel(skill),
            matchLabel = "Skinning " .. skill, description = SkinningGrayRange(skill) } }
    end
    if target ~= "" then return end

    local results = {}
    for start = 0, 300, 25 do
        local first, last = math.max(1, start), math.min(300, start + 24)
        results[#results + 1] = {
            kind = "text",
            name = "Max mob level " .. NumberRange(MaxSkinningMobLevel(first), MaxSkinningMobLevel(last)),
            matchLabel = "Skinning " .. NumberRange(first, last),
            description = ("At skill %d: %s"):format(last, SkinningGrayRange(last)),
        }
    end
    return results, "Highest skinnable mob level at each skill"
end

function addon.SearchGathering(action, target, findItems)
    if target == "" then return ListGatheringNodes(action, "all") end
    if action == "mine" and (target == "gather" or target == "harvest") then
        return ListGatheringNodes(action, "ores")
    end
    local skinningTarget = target:match("^skin (%d+)$") or target:match("^skinning (%d+)$")
    if target == "skin" or target == "skinning" or skinningTarget then
        local rows, hint = addon.SearchSkinning(skinningTarget or "")
        return rows, nil, hint
    end
    local category = gatheringCategories[target]
    if category then return ListGatheringNodes(action, category) end
    local matches = FindGatheringMatches(action, target)
    if #matches == 1 then
        local match = matches[1]
        return matches, match.answer
    elseif #matches > 1 then
        table.sort(matches, function(left, right)
            local leftName, rightName = left.name:lower(), right.name:lower()
            if leftName == rightName then return left.id < right.id end
            return leftName < rightName
        end)
        return matches, "Multiple gathering matches. Keep typing to narrow the results."
    end
    -- Harvest is also the first word of several ordinary item names.
    if action == "harvest" then return end
    return findItems(target), "No verified gathering requirement for this search."
end

-- Selected trainer locations for WoW Forever:
-- https://theforeverguides.com/professions/crafting-trainers/
-- https://www.icy-veins.com/wow-forever/ (profession guides)
-- A row holds faction, NPC, location, and optional book or quest instructions.
local training = {
    alchemy = {
        name = "Alchemy",
        trainers = {
            {
                { "Alliance", "Tel'Athir", "Mage Quarter, Stormwind City" },
                { "Horde", "Whuut", "The Drag, Orgrimmar" },
            },
            {
                { "Alliance", "Tally Berryfizz", "Tinker Town, Ironforge" },
                { "Horde", "Bena Winterhoof", "Middle Rise, Thunder Bluff" },
                { "Both", "Jaxin Chong", "Booty Bay, Stranglethorn Vale" },
            },
            {
                { "Alliance", "Ainethil", "Craftsmen's Terrace, Darnassus" },
                { "Horde", "Doctor Herbert Halsey", "The Apothecarium, Undercity" },
            },
            {
                { "Alliance", "Kylanna Windwhisper", "Feathermoon Stronghold, Feralas" },
                { "Horde", "Rogvar", "Stonard, Swamp of Sorrows" },
                { "Both", "Master Mycologist Shurome", "Emerald Sanctuary, Felwood" },
            },
        },
    },
    blacksmithing = {
        name = "Blacksmithing",
        trainers = {
            {
                { "Alliance", "Dane Lindgren", "Dwarven District, Stormwind City" },
                { "Horde", "Ug'thok", "Valley of Honor, Orgrimmar" },
            },
            {
                { "Alliance", "Therum Deepforge", "Dwarven District, Stormwind City" },
                { "Horde", "Snarl", "Valley of Honor, Orgrimmar" },
            },
            {
                { "Alliance", "Bengus Deepforge", "Great Forge, Ironforge" },
                { "Horde", "Saru Steelfury", "Valley of Honor, Orgrimmar" },
            },
            { { "Both", "Brikk Keencraft", "Booty Bay, Stranglethorn Vale" } },
        },
    },
    enchanting = {
        name = "Enchanting",
        trainers = {
            {
                { "Alliance", "Betty Quin", "Mage Quarter, Stormwind City" },
                { "Horde", "Jhag", "The Drag, Orgrimmar" },
            },
            {
                { "Alliance", "Lucan Cordell", "Mage Quarter, Stormwind City" },
                { "Horde", "Godan", "The Drag, Orgrimmar" },
            },
            {
                { "Alliance", "Kitta Firewind", "Tower of Azora, Elwynn Forest" },
                { "Horde", "Hgarth", "Sun Rock Retreat, Stonetalon Mountains" },
            },
            { { "Both", "Annora", "Inside Uldaman, Badlands" } },
        },
    },
    engineering = {
        name = "Engineering",
        trainers = {
            {
                { "Alliance", "Jemma Quikswitch", "Tinker Town, Ironforge" },
                { "Horde", "Thund", "Valley of Honor, Orgrimmar" },
            },
            {
                { "Alliance", "Trixie Quikswitch", "Tinker Town, Ironforge" },
                { "Horde", "Nogg", "Valley of Honor, Orgrimmar" },
            },
            {
                { "Alliance", "Springspindle Fizzlegear", "Tinker Town, Ironforge" },
                { "Horde", "Roxxik", "Valley of Honor, Orgrimmar" },
            },
            { { "Both", "Buzzek Bracketswing", "Gadgetzan, Tanaris" } },
        },
    },
    herbalism = {
        name = "Herbalism", sharedTrainerRank = 4, skillOnly = true,
        trainers = {
            [1] = {
                { "Alliance", "Nancy Songflower", "Northshire, Elwynn Forest" },
                { "Horde", "Zor'la", "Valley of Trials, Durotar" },
            },
            [4] = {
                { "Alliance", "Tannysa", "Mage Quarter, Stormwind City" },
                { "Horde", "Jandi", "The Drag, Orgrimmar" },
                { "Both", "Flora Silverwind", "Booty Bay, Stranglethorn Vale" },
            },
        },
    },
    leatherworking = {
        name = "Leatherworking",
        trainers = {
            {
                { "Alliance", "Randal Worth", "Old Town, Stormwind City" },
                { "Horde", "Kamari", "The Drag, Orgrimmar" },
            },
            {
                { "Alliance", "Simon Tanner", "Old Town, Stormwind City" },
                { "Horde", "Karolek", "The Drag, Orgrimmar" },
            },
            {
                { "Alliance", "Telonis", "Craftsmen's Terrace, Darnassus" },
                { "Horde", "Una", "Thunder Bluff" },
            },
            {
                { "Alliance", "Drakk Stonehand", "Aerie Peak, The Hinterlands" },
                { "Horde", "Hahrana Ironhide", "Camp Mojache, Feralas" },
            },
        },
    },
    mining = {
        name = "Mining", sharedTrainerRank = 4, skillOnly = true,
        trainers = {
            [1] = {
                { "Alliance", "Kelsey Fargo", "Northshire, Elwynn Forest" },
                { "Horde", "Norzsh", "Valley of Trials, Durotar" },
            },
            [4] = {
                { "Alliance", "Geofram Bouldertoe", "Great Forge, Ironforge" },
                { "Horde", "Makaru", "Valley of Honor, Orgrimmar" },
                { "Both", "Pikkle", "Gadgetzan, Tanaris" },
            },
        },
    },
    skinning = {
        name = "Skinning", sharedTrainerRank = 4, skillOnly = true,
        trainers = {
            [1] = {
                { "Alliance", "Riley Peltskinner", "Northshire, Elwynn Forest" },
                { "Horde", "Kagil", "Valley of Trials, Durotar" },
            },
            [4] = {
                { "Alliance", "Maris Granger", "Old Town, Stormwind City" },
                { "Horde", "Thuwd", "The Drag, Orgrimmar" },
                { "Both", "Ishlee Breezewhisper", "Valanaar, Zephras Isle" },
            },
        },
    },
    tailoring = {
        name = "Tailoring",
        trainers = {
            {
                { "Alliance", "Lawrence Schneider", "Mage Quarter, Stormwind City" },
                { "Horde", "Victor Ward", "Magic Quarter, Undercity" },
            },
            {
                { "Alliance", "Sellandus", "Mage Quarter, Stormwind City" },
                { "Horde", "Rhiannon Davis", "Magic Quarter, Undercity" },
            },
            {
                { "Alliance", "Georgio Bolero", "Mage Quarter, Stormwind City" },
                { "Horde", "Josef Gregorian", "Magic Quarter, Undercity" },
            },
            {
                { "Alliance", "Timothy Worthington", "Theramore Isle, Dustwallow Marsh" },
                { "Horde", "Daryl Stack", "Tarren Mill, Hillsbrad Foothills" },
            },
        },
    },
    cooking = {
        name = "Cooking", sharedTrainerRank = 2, artisanSkill = 225,
        trainers = {
            [2] = {
                { "Alliance", "Stephen Ryback", "Old Town, Stormwind City" },
                { "Horde", "Zamja", "The Drag, Orgrimmar" },
            },
            [3] = {
                { "Alliance", "Shandrina", "Silverwind Refuge, Ashenvale", "Buy the Expert Cookbook." },
                { "Horde", "Wulan", "Shadowprey Village, Desolace", "Buy the Expert Cookbook." },
            },
            [4] = { { "Both", "Dirge Quikcleave", "Gadgetzan inn, Tanaris", "Complete Clamlette Surprise." } },
        },
    },
    ["first aid"] = {
        name = "First Aid", sharedTrainerRank = 2, artisanSkill = 225,
        trainers = {
            [2] = {
                { "Alliance", "Shaina Fuller", "Cathedral of Light, Stormwind City" },
                { "Horde", "Arnok", "Valley of Spirits, Orgrimmar" },
            },
            [3] = {
                { "Alliance", "Deneb Walker", "Stromgarde Keep, Arathi Highlands", "Buy Expert First Aid - Under Wraps." },
                { "Horde", "Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh", "Buy Expert First Aid - Under Wraps." },
            },
            [4] = {
                { "Alliance", "Doctor Gustaf VanHowzen", "Theramore Isle, Dustwallow Marsh", "Complete Triage." },
                { "Horde", "Doctor Gregory Victor", "Hammerfall, Arathi Highlands", "Complete Triage." },
            },
        },
    },
    fishing = {
        name = "Fishing", sharedTrainerRank = 2, artisanSkill = 225,
        trainers = {
            [2] = {
                { "Alliance", "Arnold Leland", "Trade District canals, Stormwind City" },
                { "Horde", "Lumak", "Valley of Honor, Orgrimmar" },
                { "Both", "Myizz Luckycatch", "Booty Bay, Stranglethorn Vale" },
            },
            [3] = {
                { "Both", "Old Man Heming", "Booty Bay, Stranglethorn Vale", "Buy Expert Fishing - The Bass and You." },
            },
            [4] = {
                { "Both", "Nat Pagle", "Southwest of Theramore Isle, Dustwallow Marsh", "Complete Nat Pagle, Angler Extreme." },
            },
        },
    },
}

local professionAliases = {
    alc = "alchemy", alch = "alchemy", alchemist = "alchemy",
    blacksmith = "blacksmithing", bs = "blacksmithing", smith = "blacksmithing", smithing = "blacksmithing",
    cook = "cooking",
    ench = "enchanting", enchant = "enchanting", enchanter = "enchanting",
    eng = "engineering", engi = "engineering", engineer = "engineering",
    fa = "first aid", firstaid = "first aid", ["first-aid"] = "first aid",
    fish = "fishing",
    herb = "herbalism", herbs = "herbalism", herbalist = "herbalism",
    leather = "leatherworking", leatherwork = "leatherworking", leatherworker = "leatherworking",
    ["leather working"] = "leatherworking", lw = "leatherworking",
    mine = "mining", miner = "mining",
    skin = "skinning", skinner = "skinning",
    tailor = "tailoring",
}

function addon.ExtractCraftProfession(target)
    -- Keep armor terms and quoted recipe names available to the search.
    local searchable = " " .. target:gsub('"[^"]*"', function(quoted)
        return string.rep("~", #quoted)
    end) .. " "
    local name, first, last
    local function Check(alias, profession)
        local start, stop = searchable:find(" " .. alias .. " ", 1, true)
        if start and (not first or stop - start > last - first
            or (stop - start == last - first and start < first)) then
            name, first, last = profession, start, stop
        end
    end
    for profession in pairs(training) do Check(profession, profession) end
    for alias, profession in pairs(professionAliases) do
        if alias ~= "leather" and alias ~= "enchant" then Check(alias, profession) end
    end
    if name then
        local remaining = target:sub(1, first - 1) .. " " .. target:sub(last)
        return remaining:gsub("%s+", " "):match("^%s*(.-)%s*$"), training[name].name
    end
    return target
end

local trainingRanks = {
    { name = "Apprentice", cap = 75 },
    { name = "Journeyman", cap = 150, skill = 50, level = 10 },
    { name = "Expert", cap = 225, skill = 125, level = 20 },
    { name = "Artisan", cap = 300, skill = 200, level = 35 },
}

local function TrainingRows(profession, currentSkill, includeProfession)
    local finalRank = trainingRanks[#trainingRanks]
    if currentSkill and currentSkill > finalRank.cap then
        return {}, ("Enter a %s skill from 0–%d."):format(profession.name, finalRank.cap)
    end
    local results = {}
    for index, rank in ipairs(trainingRanks) do
        if not currentSkill or currentSkill < rank.cap or rank == finalRank then
            local trainers = profession.trainers[index]
            if currentSkill and not trainers then trainers = profession.trainers[profession.sharedTrainerRank] end
            local title = ("%s %s (up to %d)"):format(rank.name, profession.name, rank.cap)
            if rank.skill then
                local requiredSkill = rank == finalRank and profession.artisanSkill or rank.skill
                local requirement = ("\nRequires %s %d"):format(profession.name, requiredSkill)
                if not profession.skillOnly then
                    requirement = requirement .. (" and character level %d"):format(rank.level)
                end
                title = title .. requirement .. "."
            end
            if not currentSkill and index == profession.sharedTrainerRank then
                title = title .. "\nThis trainer also teaches earlier ranks."
            end
            for _, trainer in ipairs(trainers or {}) do
                local faction, npc, location, instruction = unpack(trainer)
                local prefix = instruction and (rank == finalRank and "Quest: " or "Book: ") or ""
                results[#results + 1] = {
                    kind = "text",
                    name = prefix .. npc .. " - " .. location,
                    matchLabel = ("%s%s %d / %s"):format(
                        includeProfession and (profession.name .. " ") or "", rank.name, rank.cap, faction),
                    description = instruction and (title .. "\n" .. instruction) or title,
                }
            end
            if currentSkill then break end
        end
    end
    return results
end

function addon.SearchTraining(target, leading)
    if target == "" then
        local professions = {}
        for name in pairs(training) do professions[#professions + 1] = name end
        table.sort(professions)
        local results = {}
        for _, name in ipairs(professions) do
            for _, row in ipairs(TrainingRows(training[name], nil, true)) do
                results[#results + 1] = row
            end
        end
        return results
    end

    local name, skill = target:match("^([%a %-]+) (%d+)$")
    if not name then name, skill = target:match('^"([%a %-]+)" (%d+)$') end
    name = name or target:match("^([%a %-]+)$")
    if not name then
        if leading then return {}, "Try train alchemy or train alchemy 225." end
        return
    end
    local profession = training[professionAliases[name] or name]
    if not profession then
        if leading then return {}, "No verified trainer locations for this profession." end
        return
    end
    return TrainingRows(profession, tonumber(skill))
end
