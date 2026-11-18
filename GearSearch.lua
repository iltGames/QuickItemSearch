local addonName, addon = ...
local settingsKey = addonName .. "Settings"

local function IsLevelOffset(value)
    return type(value) == "number" and value >= 0 and value <= 99 and value % 1 == 0
end

function addon.GetLevelWindow()
    local settings = _G[settingsKey]
    if type(settings) ~= "table" then return 5, 2 end
    return IsLevelOffset(settings.levelsBelow) and settings.levelsBelow or 5,
        IsLevelOffset(settings.levelsAbove) and settings.levelsAbove or 2
end

function addon.SetLevelWindow(below, above)
    if not IsLevelOffset(below) or not IsLevelOffset(above) then return false end
    local settings = _G[settingsKey]
    if type(settings) ~= "table" then
        settings = {}
        _G[settingsKey] = settings
    end
    settings.levelsBelow, settings.levelsAbove = below, above
    return true
end

local slots = {
    head = { label = "Head", [1] = true }, neck = { label = "Neck", [2] = true },
    shoulders = { label = "Shoulders", [3] = true }, chest = { label = "Chest", [5] = true, [20] = true },
    waist = { label = "Waist", [6] = true }, legs = { label = "Legs", [7] = true },
    feet = { label = "Feet", [8] = true }, wrists = { label = "Wrists", [9] = true },
    hands = { label = "Hands", [10] = true }, ring = { label = "Ring", [11] = true },
    trinket = { label = "Trinket", [12] = true }, cloak = { label = "Cloak", [16] = true },
    shield = { label = "Shield", [14] = true },
}
local slotAliases = {
    helm = "head", helms = "head", helmet = "head", helmets = "head", headpiece = "head",
    necklace = "neck", necklaces = "neck", amulet = "neck", pendant = "neck",
    shoulder = "shoulders", shoulderpad = "shoulders", shoulderpads = "shoulders",
    chestpiece = "chest",
    belt = "waist", belts = "waist", waistband = "waist",
    leg = "legs", pant = "legs", pants = "legs", leggings = "legs", trousers = "legs",
    foot = "feet", boot = "feet", boots = "feet",
    wrist = "wrists", bracer = "wrists", bracers = "wrists",
    hand = "hands", glove = "hands", gloves = "hands",
    rings = "ring", trinkets = "trinket", shields = "shield",
    back = "cloak", cape = "cloak", capes = "cloak", cloaks = "cloak",
}
for alias, slot in pairs(slotAliases) do slots[alias] = slots[slot] end

local WEAPON_CLASS, ARMOR_CLASS = 2, 4
local armorTypes = {
    cloth = { "Cloth", 1 }, leather = { "Leather", 2 },
    mail = { "Mail", 3 }, plate = { "Plate", 4 },
}
armorTypes.chainmail = armorTypes.mail

local function MatchesArmorType(id, armorType)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    return classID == ARMOR_CLASS and subclassID == armorType[2]
end

-- Item subclass IDs mapped to the corresponding character skill lines.
local weaponSkills = {
    [0] = 44, [1] = 172, -- Axes
    [2] = 45, [3] = 46, -- Bows and guns
    [4] = 54, [5] = 160, -- Maces
    [6] = 229, [7] = 43, [8] = 55, -- Polearms and swords
    [10] = 136, [13] = 473, [15] = 173, -- Staves, fist weapons, daggers
    [16] = 176, [18] = 226, [19] = 228, [20] = 356, -- Thrown, crossbows, wands, fishing poles
}
local armorSkills = {
    [2] = 414, [3] = 413, [4] = 293, [6] = 433, -- Leather, mail, plate, shields
}

local function PlayerProficiencyFilter(getSkill)
    local learned, armorRanks = {}, {}
    local function MatchesProficiency(id)
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
        if classID == ARMOR_CLASS and (subclassID == 0 or subclassID == 1) then
            armorRanks[id] = subclassID
            return true -- Miscellaneous armor and cloth.
        end
        local skillID = classID == WEAPON_CLASS and weaponSkills[subclassID]
            or classID == ARMOR_CLASS and armorSkills[subclassID]
        if not skillID then return false end
        if learned[skillID] == nil then
            local skill = getSkill(skillID)
            learned[skillID] = skill and (skill.rank or 0) > 0 or false
        end
        if learned[skillID] then
            armorRanks[id] = classID == ARMOR_CLASS and subclassID <= 4 and subclassID or 0
        end
        return learned[skillID]
    end
    return MatchesProficiency, armorRanks
end

local oneHanded = { label = "One-handed weapons", [13] = true, [21] = true, [22] = true }
local twoHanded = { label = "Two-handed weapons", [17] = true }
local meleeWeapons = { label = "Melee weapons", [13] = true, [17] = true, [21] = true, [22] = true }
local weaponSlots = {
    wep = meleeWeapons, weps = meleeWeapons, weapon = meleeWeapons, weapons = meleeWeapons,
    ["1h"] = oneHanded, ["one-handed"] = oneHanded, onehanded = oneHanded, ["one handed"] = oneHanded,
    ["2h"] = twoHanded, ["two-handed"] = twoHanded, twohanded = twoHanded, ["two handed"] = twoHanded,
}

-- The gear index uses inventory types, while the equipped item API uses slot IDs.
local equippedSlotByType = {
    [1] = 1, [2] = 2, [3] = 3, [5] = 5, [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10,
    [11] = 11, [12] = 13, [13] = 16, [14] = 17, [15] = 18, [16] = 15, [17] = 16,
    [20] = 5, [21] = 16, [22] = 17, [23] = 17, [25] = 18, [26] = 18, [28] = 18,
}

local function ReadItemLevel(getItemLevel, item)
    local level = getItemLevel(item)
    if type(level) == "number" and not (issecretvalue and issecretvalue(level)) and level > 0 then
        return level
    end
end

local function EquippedItemLevels(getItemLevel)
    local levels, equipped = {}, {}
    local function ReadSlot(slot)
        if equipped[slot] == nil then
            local link = GetInventoryItemLink("player", slot)
            equipped[slot] = link and ReadItemLevel(getItemLevel, link) or false
        end
        return equipped[slot]
    end
    local offHand = GetInventoryItemLink("player", 17)
    local offHandType = offHand and C_Item and C_Item.GetItemInfoInstant
        and select(4, C_Item.GetItemInfoInstant(offHand))
    local secondarySlots = { [11] = 12, [12] = 14 }
    if offHandType == "INVTYPE_WEAPON" or offHandType == "INVTYPE_WEAPONOFFHAND" then
        secondarySlots[13] = 17
    end
    for inventoryType, slot in pairs(equippedSlotByType) do
        local level = ReadSlot(slot)
        local secondarySlot = secondarySlots[inventoryType]
        local otherLevel = secondarySlot and ReadSlot(secondarySlot)
        if level and otherLevel then
            levels[inventoryType] = math.min(level, otherLevel)
        else
            levels[inventoryType] = level or otherLevel
        end
    end
    return levels
end

local otherGear = { label = "Other gear" }
local browseSlots = {
    slots.head, slots.neck, slots.shoulders, slots.cloak, slots.chest, slots.wrists,
    slots.hands, slots.waist, slots.legs, slots.feet, slots.ring, slots.trinket,
    meleeWeapons, slots.shield, { label = "Held in off hand", [23] = true },
    { label = "Ranged weapons", [15] = true, [25] = true, [26] = true },
    { label = "Relic", [28] = true }, { label = "Shirt", [4] = true },
    { label = "Tabard", [19] = true }, otherGear,
}
local browseSlotByType = {}
for _, slot in ipairs(browseSlots) do
    for inventoryType in pairs(slot) do
        if type(inventoryType) == "number" then browseSlotByType[inventoryType] = slot end
    end
end

local function GroupPlayerGear(results, slot, hint)
    if #results == 0 then return results, hint end
    if slot then return results, hint, nil, nil, { title = slot.label } end

    local slotRows = {}
    for _, row in ipairs(results) do
        local group = browseSlotByType[addon.gear[row.id][1]] or otherGear
        local rows = slotRows[group] or {}
        rows[#rows + 1] = row
        slotRows[group] = rows
    end
    local firstRows, sections = nil, {}
    for _, group in ipairs(browseSlots) do
        local rows = slotRows[group]
        if rows then
            if not firstRows then
                firstRows, sections.title = rows, group.label
            else
                sections[#sections + 1] = { title = group.label, rows = rows }
            end
        end
    end
    return firstRows, hint, nil, nil, sections
end

local rarities = {
    poor = { "Poor", 0 }, common = { "Common", 1 }, uncommon = { "Uncommon", 2 },
    rare = { "Rare", 3 }, epic = { "Epic", 4 }, legendary = { "Legendary", 5 },
}
rarities.gray, rarities.grey, rarities.white = rarities.poor, rarities.poor, rarities.common
rarities.green, rarities.blue, rarities.purple, rarities.orange = rarities.uncommon, rarities.rare, rarities.epic, rarities.legendary

local bindingTypes = {
    boe = { "Bind on Equip", 2 },
    bop = { "Bind on Pickup", 1 },
}
local bindingWords = { equip = bindingTypes.boe, pickup = bindingTypes.bop }
local approximate = { around = true, near = true, about = true }

local stats = {
    agility = { "Agility", 1, "AGILITY" },
    strength = { "Strength", 2, "STRENGTH" },
    intellect = { "Intellect", 4, "INTELLECT" },
    spirit = { "Spirit", 8, "SPIRIT" },
    stamina = { "Stamina", 16, "STAMINA" },
    ["spell power"] = { "Spell Power", 32, "SPELL_POWER" },
    ["healing power"] = { "Healing Power", 64, "SPELL_HEALING_DONE" },
    ["spell damage"] = { "Spell Damage", 128, "SPELL_DAMAGE_DONE" },
    hit = { "Hit", 256, "HIT_RATING", "HIT_MELEE_RATING", "HIT_RANGED_RATING", "HIT_SPELL_RATING" },
    crit = { "Crit", 512, "CRIT_RATING", "CRIT_MELEE_RATING", "CRIT_RANGED_RATING", "CRIT_SPELL_RATING" },
    haste = { "Haste", 1024, "HASTE_RATING", "HASTE_MELEE_RATING", "HASTE_RANGED_RATING", "HASTE_SPELL_RATING" },
    expertise = { "Expertise", 2048, "EXPERTISE_RATING" },
    defense = { "Defense", 4096, "DEFENSE_SKILL_RATING" },
    dodge = { "Dodge", 8192, "DODGE_RATING" },
    parry = { "Parry", 16384, "PARRY_RATING" },
    block = { "Block Rating", 32768, "BLOCK_RATING" },
    ["block value"] = { "Block Value", 65536, "BLOCK_VALUE" },
    ["attack power"] = { "Attack Power", 131072, "ATTACK_POWER" },
    ["ranged attack power"] = { "Ranged AP", 262144, "RANGED_ATTACK_POWER" },
    mp5 = { "MP5", 524288, "MANA_REGENERATION" },
    ["spell penetration"] = { "Spell Pen.", 1048576, "SPELL_PENETRATION" },
    ["armor penetration"] = { "Armor Pen.", 2097152, "ARMOR_PENETRATION_RATING" },
    resilience = { "Resilience", 4194304, "RESILIENCE_RATING" },
    ["bonus armor"] = { "Bonus Armor", 8388608, "EXTRA_ARMOR" },
    ["health regen"] = { "Health Regen", 16777216, "HEALTH_REGEN" },
    ["fire resistance"] = { "Fire Res.", 33554432, "FIRE_RESISTANCE" },
    ["frost resistance"] = { "Frost Res.", 67108864, "FROST_RESISTANCE" },
    ["shadow resistance"] = { "Shadow Res.", 134217728, "SHADOW_RESISTANCE" },
    ["nature resistance"] = { "Nature Res.", 268435456, "NATURE_RESISTANCE" },
    ["arcane resistance"] = { "Arcane Res.", 536870912, "ARCANE_RESISTANCE" },
    ["holy resistance"] = { "Holy Res.", 1073741824, "HOLY_RESISTANCE" },
}
stats.agi, stats.str, stats.int, stats.spi, stats.sta = stats.agility, stats.strength, stats.intellect, stats.spirit, stats.stamina
stats.agil, stats.stam = stats.agility, stats.stamina
stats.sp, stats.spellpower = stats["spell power"], stats["spell power"]
stats.hp = stats["healing power"]
stats.spellheal, stats.healing, stats["bonus healing"] = stats["healing power"], stats["healing power"], stats["healing power"]
stats.spelldmg, stats["spell dmg"], stats["bonus damage"] = stats["spell damage"], stats["spell damage"], stats["spell damage"]
stats["hit rating"], stats["hit chance"] = stats.hit, stats.hit
stats["crit rating"], stats["critical strike"], stats["critical strike rating"] = stats.crit, stats.crit, stats.crit
stats["haste rating"], stats["defense rating"], stats["block rating"] = stats.haste, stats.defense, stats.block
stats["crit chance"], stats["critical strike chance"] = stats.crit, stats.crit
stats["dodge rating"], stats["parry rating"], stats["expertise rating"] = stats.dodge, stats.parry, stats.expertise
stats.def, stats.defence, stats["defence rating"] = stats.defense, stats.defense, stats.defense
stats.ap, stats.rap, stats["mana regen"] = stats["attack power"], stats["ranged attack power"], stats.mp5
stats["mana regeneration"], stats["health regeneration"] = stats.mp5, stats["health regen"]
stats["spell pen"], stats["armor pen"] = stats["spell penetration"], stats["armor penetration"]
stats["fire res"], stats["frost res"], stats["shadow res"] = stats["fire resistance"], stats["frost resistance"], stats["shadow resistance"]
stats["nature res"], stats["arcane res"], stats["holy res"] = stats["nature resistance"], stats["arcane resistance"], stats["holy resistance"]

local spellPower, healingPower, spellDamage = stats["spell power"], stats["healing power"], stats["spell damage"]
local statPatterns = { "^(%w+ %w+ %w+)(.*)$", "^(%w+ %w+)(.*)$", "^(%w+)(.*)$" }

local function MatchStat(query)
    for _, pattern in ipairs(statPatterns) do
        local alias, tail = query:match(pattern)
        if alias and stats[alias] and (tail == "" or tail:match("^%s")) then
            return stats[alias], tail
        end
    end
end

local function MatchSource(query, word, rest)
    local kind, value = query:match("^(%a+):%s*(.*)$")
    if kind == "boss" or kind == "quest" then
        local target, tail = value:match('^"([^"]+)"(.*)$')
        if value:sub(1, 1) ~= '"' then target, tail = value:match("^(%S+)(.*)$") end
        if target then return kind, target, tail end
    elseif word == "boss" then
        return word, true, rest:match("^ drops?%f[%W](.*)$") or rest:match("^ loot%f[%W](.*)$") or rest
    elseif word == "quest" then
        return word, true, rest:match("^ rewards?%f[%W](.*)$") or rest
    end
end

local function ParseGearQuery(query)
    local filters = {}
    local word, rest
    query = query:gsub("%s+", " ")
    while query ~= "" do
        local levelQuery = query:gsub("^for%s+", ""):gsub("^lvls?%s*(%d)", "level %1"):gsub("^lv%s*(%d)", "level %1")
        levelQuery = levelQuery:gsub("^(%a+%s*%d+%s*)–", "%1-"):gsub("^(%a+%s*%d+%s*)—", "%1-")
        local low, high, suffix = levelQuery:match("^from%s+(%d+)%s*%-%s*(%d+)(.*)$")
        if not low then low, high, suffix = levelQuery:match("^levels?%s*(%d+)%s*%-%s*(%d+)(.*)$") end
        local hasLevel = filters.level or filters.maxLevel
        if low and not hasLevel then
            filters.minLevel, filters.maxLevel = tonumber(low), tonumber(high)
            query = suffix
        else
            local level
            level, suffix = levelQuery:match("^levels?%s*(%d+)(.*)$")
            if level and not hasLevel then
                filters.level, query = tonumber(level), suffix
            else
                word, rest = query:match("^(%S+)(.*)$")
                local handed, weaponTail = query:match("^(%a+ handed)%f[%W](.*)$")
                local weaponSlot = weaponSlots[handed or word]
                local rarityWord, rarityTail = query:match("^rarity (%S+)(.*)$")
                if not rarityWord then rarityWord, rarityTail = query:match("^quality (%S+)(.*)$") end
                local rarity = rarities[rarityWord or word]
                local bindingWord, bindingTail = query:match("^binds? on (%S+)(.*)$")
                local binding = bindingTypes[word] or bindingWords[bindingWord]
                local source, target, tail = MatchSource(query, word, rest)
                if source and not filters[source] then
                    filters[source], query = target, tail
                elseif word == "upgrade" then
                    filters.upgrade, query = true, rest
                elseif (word == "crafted" or word == "craftable" or word == "handcrafted") and not filters.crafted then
                    filters.crafted = true
                    query = query:match("^%a+%s+gear%f[%W](.*)$") or rest
                elseif weaponSlot and not filters.slot then
                    filters.slot = weaponSlot
                    local tail = weaponTail or rest
                    query = tail:match("^ weapons?%f[%W](.*)$") or tail:match("^ weps?%f[%W](.*)$") or tail
                elseif slots[word] and not filters.slot then
                    filters.slot, query = slots[word], rest
                elseif armorTypes[word] and not filters.armorType then
                    filters.armorType = armorTypes[word]
                    query = rest:match("^ armou?r%f[%W](.*)$") or rest
                elseif rarity and not filters.rarity then
                    filters.rarity, query = rarity, rarityTail or rest
                elseif binding and not filters.binding then
                    filters.binding, query = binding, bindingTail or rest
                elseif word == "no" then
                    local stat, statTail = MatchStat(rest:sub(2))
                    if not stat then return end
                    filters.excludedStats = filters.excludedStats or {}
                    filters.excludedStats[#filters.excludedStats + 1] = stat
                    query = statTail
                else
                    local stat, statTail = MatchStat((query:gsub("^with%s+", "")))
                    if not stat then return end
                    local filter = { stat = stat }
                    filters.stats = filters.stats or {}
                    filters.stats[#filters.stats + 1] = filter
                    local modifier, amount, amountTail = statTail:match("^%s+(%a+)%s+%+?(%d+)(.*)$")
                    if approximate[modifier] then
                        filter.near, query = tonumber(amount), amountTail
                    else
                        query = statTail
                    end
                end
            end
        end
        if query ~= "" and not query:match("^%s") then return end
        query = query:match("^%s*(.*)$")
    end
    if filters.slot or filters.armorType or filters.level or filters.maxLevel or filters.boss or filters.quest or filters.crafted
        or filters.rarity or filters.binding or filters.stats or filters.excludedStats or filters.upgrade then return filters end
end

local function HasStat(flags, stat)
    return math.floor(flags / stat[2]) % 2 == 1
end

local function IncludesSharedSpellPower(stat)
    return stat == healingPower or stat == spellDamage
end

local function MatchesStatFlag(flags, stat)
    return HasStat(flags, stat) or (IncludesSharedSpellPower(stat) and HasStat(flags, spellPower))
end

local function ReadAmount(values, stat)
    for i = 3, #stat do
        local key = "ITEM_MOD_" .. stat[i]
        local amount = values[key .. "_SHORT"] or values[key] or values[_G[key .. "_SHORT"]]
        if type(amount) == "number" and not (issecretvalue and issecretvalue(amount)) and amount > 0 then
            return amount
        end
    end
    return 0
end

local function ReadTooltipSpellStats(id)
    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return 0, 0, 0 end
    local ok, tooltip = pcall(C_TooltipInfo.GetItemByID, id)
    local shared, healing, damage = 0, 0, 0
    for _, line in ipairs(ok and tooltip and tooltip.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
            text = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("^equip:%s*", "")
            local common = text:match("^increases damage and healing done by magical spells and effects by up to (%d+)")
            local heal, dmg = text:match("^increases healing done by up to (%d+) and damage done by up to (%d+)")
            heal = heal or text:match("^increases healing done by spells and effects by up to (%d+)")
            dmg = dmg or text:match("^increases damage done by magical spells and effects by up to (%d+)")
            shared = shared + (tonumber(common) or 0)
            healing = healing + (tonumber(heal) or 0)
            damage = damage + (tonumber(dmg) or 0)
        end
    end
    return shared, healing, damage
end

local function ReadStat(values, stat, id, flags)
    local amount = ReadAmount(values, stat)
    if stat == spellPower or stat == healingPower or stat == spellDamage then
        local shared = HasStat(flags, spellPower) and ReadAmount(values, spellPower) or 0
        if stat ~= spellPower and not HasStat(flags, stat) then amount = 0 end
        if (HasStat(flags, spellPower) and shared == 0) or (stat ~= spellPower and HasStat(flags, stat) and amount == 0) then
            local tooltipShared, tooltipHealing, tooltipDamage = ReadTooltipSpellStats(id)
            if shared == 0 then shared = tooltipShared end
            if amount == 0 then
                if stat == healingPower then amount = tooltipHealing end
                if stat == spellDamage then amount = tooltipDamage end
            end
        end
        if stat == spellPower then return shared end
        return shared + amount
    end
    return amount
end

local function Describe(filters)
    local parts = {}
    if filters.playerGear then parts[#parts + 1] = "My gear" end
    if filters.upgrade then parts[#parts + 1] = "Item level upgrades" end
    if filters.slot then parts[#parts + 1] = filters.slot.label end
    if filters.armorType then parts[#parts + 1] = filters.armorType[1] end
    if filters.rarity then parts[#parts + 1] = filters.rarity[1] end
    if filters.binding then parts[#parts + 1] = filters.binding[1] end
    if filters.maxLevel then
        parts[#parts + 1] = ("Requires level %d-%d"):format(filters.minLevel, filters.maxLevel)
    end
    if filters.boss then
        parts[#parts + 1] = filters.boss == true and "Boss drops" or "Boss: " .. filters.boss:gsub("|", "||")
    end
    if filters.quest then
        parts[#parts + 1] = filters.quest == true and "Quest rewards" or "Quest: " .. filters.quest:gsub("|", "||")
    end
    if filters.crafted then parts[#parts + 1] = "Crafted gear" end
    if filters.profession then parts[#parts + 1] = filters.profession end
    for _, filter in ipairs(filters.stats or {}) do
        parts[#parts + 1] = filter.stat[1] .. (filter.near and (" near +" .. filter.near) or "")
    end
    for _, stat in ipairs(filters.excludedStats or {}) do
        parts[#parts + 1] = "No " .. stat[1]
    end
    return table.concat(parts, " · ")
end

function addon.SearchGear(query, requireCombinedBoss, craftedOnly, profession, playerGear)
    local filters = playerGear and query == "" and {} or ParseGearQuery(query)
    if not filters and playerGear then return {}, "Try my gear chest, my gear rings, or my gear 1h." end
    if not filters then return end
    if requireCombinedBoss and not (filters.slot or filters.armorType or filters.level or filters.maxLevel or filters.quest
        or filters.crafted or filters.rarity or filters.binding or filters.stats or filters.excludedStats
        or filters.upgrade) then return end
    if craftedOnly then filters.crafted = true end
    filters.profession = profession
    local matchesProficiency, armorRanks
    if playerGear then
        local getSkill = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
        if not getSkill or not (C_Item and C_Item.GetItemInfoInstant) then
            return {}, "Character proficiencies are unavailable."
        end
        if filters.level or filters.maxLevel then return {}, "My gear uses your character level." end
        local level = UnitLevel("player")
        if not level or level < 1 then return {}, "Character level is unavailable." end
        filters.playerGear, filters.level = true, level
        matchesProficiency, armorRanks = PlayerProficiencyFilter(getSkill)
    end
    if filters.level then
        if filters.level < 1 or filters.level > 999 then return {}, "Enter a positive character level from 1 to 999." end
        local below, above = addon.GetLevelWindow()
        filters.minLevel = math.max(1, filters.level - below)
        filters.maxLevel = math.min(999, filters.level + above)
    elseif filters.maxLevel and (filters.maxLevel > 999 or filters.minLevel < 1 or filters.minLevel > filters.maxLevel) then
        return {}, "Enter an ascending character-level range, such as 10-12."
    end
    local statFilters = filters.stats or {}
    local excludedStats = filters.excludedStats or {}
    local requiresItemStats = false
    for _, filter in ipairs(statFilters) do
        if filter.near then
            if filter.near < 1 or filter.near > 999999 then return {}, "Enter a positive stat amount." end
            filter.tolerance = math.max(2, math.floor(filter.near / 5))
        end
        local stat = filter.stat
        if stat ~= spellPower and not IncludesSharedSpellPower(stat) then requiresItemStats = true end
    end

    local bossDrops
    if filters.boss then
        local hint
        bossDrops, hint = addon.GetBossDropItems(filters.boss ~= true and filters.boss or nil)
        if not bossDrops then return {}, hint or "AtlasLoot boss data is unavailable." end
    end
    local isQuestReward
    if filters.quest then
        local hint
        isQuestReward, hint = addon.GetQuestRewardFilter(filters.quest ~= true and filters.quest or nil)
        if not isQuestReward then return {}, hint end
    end
    if filters.armorType and not (C_Item and C_Item.GetItemInfoInstant) then return {}, "Armor type data is unavailable." end
    if #statFilters > 0 and not (C_Item and C_Item.GetItemStats) then return {}, "Item stats are unavailable." end

    local getItemLevel, equippedLevels
    if filters.upgrade then
        getItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
        if not getItemLevel or not GetInventoryItemLink then return {}, "Equipped item levels are unavailable." end
        equippedLevels = EquippedItemLevels(getItemLevel)
    end

    local results, uncached = {}, {}
    local function AddMatch(id, gear, matchLabel, distance, itemLevel)
        local name = addon.index[id]
        if not matchLabel and filters.maxLevel then
            matchLabel = ("Requires %d"):format(gear[2])
        end
        if itemLevel then
            local upgradeLabel = ("ilvl %d (+%d)"):format(itemLevel, itemLevel - equippedLevels[gear[1]])
            matchLabel = matchLabel and matchLabel .. " · " .. upgradeLabel or upgradeLabel
        end
        results[#results + 1] = {
            id = id, name = name, key = name:lower(), distance = distance or 0, requiredLevel = gear[2],
            matchLabel = matchLabel, quality = gear[4], armorRank = armorRanks and armorRanks[id],
        }
    end

    local function MatchesStatFlags(flags)
        for _, stat in ipairs(excludedStats) do
            if MatchesStatFlag(flags, stat) then return false end
        end
        for _, filter in ipairs(statFilters) do
            if not MatchesStatFlag(flags, filter.stat) then
                return false
            end
        end
        return true
    end

    local function CheckItemDetails(id, gear)
        local itemLevel
        if getItemLevel then
            itemLevel = gear[6]
            if not itemLevel or itemLevel == 0 then
                itemLevel = ReadItemLevel(getItemLevel, id)
            end
            if not itemLevel then return false end
            if itemLevel <= equippedLevels[gear[1]] then return true end
        end
        if #statFilters == 0 then
            AddMatch(id, gear, nil, nil, itemLevel)
            return true
        end

        local cached = C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id)
        if C_Item.IsItemDataCachedByID and not cached then return false end
        local values = C_Item.GetItemStats("item:" .. id)
        if not values and (not cached or requiresItemStats) then return false end
        values = values or {}
        local labels, distance = {}, 0
        for _, filter in ipairs(statFilters) do
            local amount = ReadStat(values, filter.stat, id, gear[3])
            if amount <= 0 then return true end
            if filter.near then
                local difference = math.abs(amount - filter.near)
                if difference > filter.tolerance then return true end
                distance = distance + difference
            end
            labels[#labels + 1] = ("+%g %s"):format(amount, filter.stat[1])
        end
        AddMatch(id, gear, table.concat(labels, " · "), distance, itemLevel)
        return true
    end

    local description = Describe(filters)
    local function Finish(unavailable)
        table.sort(results, function(left, right)
            if left.armorRank ~= right.armorRank then return left.armorRank > right.armorRank end
            if left.distance ~= right.distance then return left.distance < right.distance end
            if filters.maxLevel and left.requiredLevel ~= right.requiredLevel then
                return left.requiredLevel < right.requiredLevel
            end
            if left.key == right.key then return left.id < right.id end
            return left.key < right.key
        end)
        local hint = (#results == 0 and "No matches · " or "") .. description
        if unavailable == 1 then
            hint = hint .. " · 1 item unavailable"
        elseif unavailable > 1 then
            hint = hint .. (" · %d items unavailable"):format(unavailable)
        end
        if playerGear then return GroupPlayerGear(results, filters.slot, hint) end
        return results, hint
    end

    local function MatchesCraft(id)
        if profession then
            for _, recipe in ipairs(addon.GetItemRecipes(id) or {}) do
                if recipe.profession == profession then return true end
            end
            return false
        end
        return not filters.crafted or addon.crafted[id]
    end

    for id, gear in pairs(addon.gear) do
        local slot, level, flags = gear[1], gear[2], gear[3]
        if not addon.IsPTRItem(id)
            and (not filters.slot or filters.slot[slot])
            and (not equippedLevels or equippedLevels[slot])
            and (not filters.rarity or gear[4] == filters.rarity[2])
            and (not filters.binding or gear[5] == filters.binding[2])
            and (not filters.maxLevel or (level >= filters.minLevel and level <= filters.maxLevel))
            and MatchesCraft(id)
            and (not filters.armorType or MatchesArmorType(id, filters.armorType))
            and (not bossDrops or bossDrops[id])
            and (not isQuestReward or isQuestReward(id))
            and (not matchesProficiency or matchesProficiency(id)) then
            if MatchesStatFlags(flags) and not CheckItemDetails(id, gear) then
                uncached[#uncached + 1] = id
            end
        end
    end
    if #uncached == 0 then return Finish(0) end

    -- Request outstanding items in small batches. Poll away from item/tooltip
    -- callbacks, and let the overlay cancel the work when the query changes.
    local loading = filters.upgrade and "Loading item levels" or "Loading item stats"
    return {}, loading .. " · " .. description, function(done)
        local timer
        local nextItem, unavailable = 1, 0
        local waiting = {}
        local function Step()
            local now = GetTime()
            for id, expires in pairs(waiting) do
                if CheckItemDetails(id, addon.gear[id]) then
                    waiting[id] = nil
                elseif now >= expires then
                    waiting[id] = nil
                    unavailable = unavailable + 1
                end
            end
            if not next(waiting) then
                if nextItem > #uncached then
                    done(Finish(unavailable))
                    return
                end
                local last = math.min(nextItem + 15, #uncached)
                for i = nextItem, last do
                    local id = uncached[i]
                    if not CheckItemDetails(id, addon.gear[id]) then
                        if C_Item and C_Item.RequestLoadItemDataByID and pcall(C_Item.RequestLoadItemDataByID, id) then
                            waiting[id] = now + 1.5
                        else
                            unavailable = unavailable + 1
                        end
                    end
                end
                nextItem = last + 1
            end
            timer = C_Timer.NewTimer(0.1, Step)
        end
        timer = C_Timer.NewTimer(0, Step)
        return function() timer:Cancel() end
    end
end
