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
slots.rings, slots.trinkets, slots.cloaks, slots.shields = slots.ring, slots.trinket, slots.cloak, slots.shield
slots.helm, slots.helmet, slots.boots, slots.gloves = slots.head, slots.head, slots.feet, slots.hands
slots.belt, slots.bracers, slots.back = slots.waist, slots.wrists, slots.cloak

local oneHanded = { label = "One-handed weapons", [13] = true, [21] = true, [22] = true }
local twoHanded = { label = "Two-handed weapons", [17] = true }
local weaponSlots = {
    ["1h"] = oneHanded, ["one-handed"] = oneHanded,
    ["2h"] = twoHanded, ["two-handed"] = twoHanded,
}

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
stats.ap, stats.rap, stats["mana regen"] = stats["attack power"], stats["ranged attack power"], stats.mp5
stats["spell pen"], stats["armor pen"] = stats["spell penetration"], stats["armor penetration"]
stats["fire res"], stats["frost res"], stats["shadow res"] = stats["fire resistance"], stats["frost resistance"], stats["shadow resistance"]
stats["nature res"], stats["arcane res"], stats["holy res"] = stats["nature resistance"], stats["arcane resistance"], stats["holy resistance"]

local spellPower, healingPower, spellDamage = stats["spell power"], stats["healing power"], stats["spell damage"]
local statPatterns = { "^(%w+ %w+ %w+)(.*)$", "^(%w+ %w+)(.*)$", "^(%w+)(.*)$" }

local function MatchStat(query)
    query = query:gsub("^with%s+", "")
    for _, pattern in ipairs(statPatterns) do
        local alias, tail = query:match(pattern)
        if alias and stats[alias] and (tail == "" or tail:match("^%s")) then
            return stats[alias], tail
        end
    end
end

local function ParseGearQuery(query)
    local filters = {}
    local word, rest
    query = query:gsub("–", "-"):gsub("—", "-"):gsub("%s+", " ")
        :gsub("%f[%a]lvls?%f[%A]", "level"):gsub("%f[%a]lv%f[%A]", "level")
    while query ~= "" do
        query = query:gsub("^for%s+(levels?%s+)", "%1")
        local low, high, suffix = query:match("^from%s+(%d+)%s*%-%s*(%d+)(.*)$")
        if not low then low, high, suffix = query:match("^levels?%s+(%d+)%s*%-%s*(%d+)(.*)$") end
        local hasLevel = filters.level or filters.maxLevel
        if low and not hasLevel then
            filters.minLevel, filters.maxLevel = tonumber(low), tonumber(high)
            query = suffix
        else
            local level
            level, suffix = query:match("^level%s+(%d+)(.*)$")
            if level and not hasLevel then
                filters.level, query = tonumber(level), suffix
            else
                word, rest = query:match("^(%S+)(.*)$")
                local weaponSlot = weaponSlots[word]
                local rarityWord, rarityTail = query:match("^rarity (%S+)(.*)$")
                local rarity = rarities[rarityWord or word]
                local bossSuffix = query:match("^boss%s+drops?%f[%W](.*)$")
                if bossSuffix and not filters.boss then
                    filters.boss, query = true, bossSuffix
                elseif (word == "crafted" or word == "craftable") and not filters.crafted then
                    filters.crafted = true
                    query = query:match("^%a+%s+gear%f[%W](.*)$") or rest
                elseif weaponSlot and not filters.slot then
                    filters.slot = weaponSlot
                    query = rest:match("^ weapons?%f[%W](.*)$") or rest:match("^ weps?%f[%W](.*)$") or rest
                elseif slots[word] and not filters.slot then
                    filters.slot, query = slots[word], rest
                elseif rarity and not filters.rarity then
                    filters.rarity, query = rarity, rarityTail or rest
                elseif bindingTypes[word] and not filters.binding then
                    filters.binding, query = bindingTypes[word], rest
                else
                    local stat, statTail = MatchStat(query)
                    if not stat or filters.stat then return end
                    filters.stat = stat
                    local amount
                    amount, suffix = statTail:match("^%s+around%s+%+?(%d+)(.*)$")
                    if not amount then amount, suffix = statTail:match("^%s+near%s+%+?(%d+)(.*)$") end
                    filters.near = tonumber(amount)
                    query = suffix or statTail
                end
            end
        end
        if query ~= "" and not query:match("^%s") then return end
        query = query:match("^%s*(.*)$")
    end
    if filters.slot or filters.level or filters.maxLevel or filters.boss or filters.crafted
        or filters.rarity or filters.binding or filters.stat then return filters end
end

local function HasStat(flags, stat)
    return math.floor(flags / stat[2]) % 2 == 1
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
    if filters.slot then parts[#parts + 1] = filters.slot.label end
    if filters.rarity then parts[#parts + 1] = filters.rarity[1] end
    if filters.binding then parts[#parts + 1] = filters.binding[1] end
    if filters.maxLevel then
        parts[#parts + 1] = ("Requires level %d-%d"):format(filters.minLevel, filters.maxLevel)
    end
    if filters.boss then parts[#parts + 1] = "Boss drops" end
    if filters.crafted then parts[#parts + 1] = "Crafted gear" end
    if filters.stat then
        parts[#parts + 1] = filters.stat[1] .. (filters.near and (" near +" .. filters.near) or "")
    end
    return table.concat(parts, " · ")
end

function addon.SearchGear(query)
    local filters = ParseGearQuery(query)
    if not filters then return end
    if filters.level then
        if filters.level < 1 or filters.level > 999 then return {}, "Enter a positive character level from 1 to 999." end
        local below, above = addon.GetLevelWindow()
        filters.minLevel = math.max(1, filters.level - below)
        filters.maxLevel = math.min(999, filters.level + above)
    elseif filters.maxLevel and (filters.maxLevel > 999 or filters.minLevel < 1 or filters.minLevel > filters.maxLevel) then
        return {}, "Enter an ascending character-level range, such as 10-12."
    end
    if filters.near and (filters.near < 1 or filters.near > 999999) then
        return {}, "Enter a positive stat amount."
    end

    local bossDrops
    if filters.boss then
        bossDrops = addon.GetBossDropItems()
        if not bossDrops then return {}, "AtlasLoot boss data is unavailable." end
    end
    if filters.stat and not C_Item.GetItemStats then return {}, "Item stats are unavailable." end

    local stat = filters.stat
    local includesShared = stat == healingPower or stat == spellDamage
    local isSpellStat = includesShared or stat == spellPower
    local results, uncached = {}, {}
    local tolerance = filters.near and math.max(2, math.floor(filters.near / 5))
    local function AddMatch(id, gear, amount)
        local distance = filters.near and math.abs(amount - filters.near) or 0
        if tolerance and distance > tolerance then return end
        local name = addon.index[id]
        local matchLabel
        if amount then
            matchLabel = ("+%g %s"):format(amount, stat[1])
        elseif filters.maxLevel then
            matchLabel = ("Requires %d"):format(gear[2])
        end
        results[#results + 1] = {
            id = id, name = name, key = name:lower(), distance = distance, requiredLevel = gear[2],
            matchLabel = matchLabel, quality = gear[4],
        }
    end

    local function CheckStat(id, gear)
        local cached = C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id)
        if C_Item.IsItemDataCachedByID and not cached then return false end
        local values = C_Item.GetItemStats("item:" .. id)
        if not values and not (cached and isSpellStat) then return false end
        local amount = ReadStat(values or {}, stat, id, gear[3])
        if amount > 0 then AddMatch(id, gear, amount) end
        return true
    end

    local description = Describe(filters)
    local function Finish(unavailable)
        table.sort(results, function(left, right)
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
        return results, hint
    end

    for id, gear in pairs(addon.gear) do
        local slot, level, flags = gear[1], gear[2], gear[3]
        if (not filters.slot or filters.slot[slot])
            and (not filters.rarity or gear[4] == filters.rarity[2])
            and (not filters.binding or gear[5] == filters.binding[2])
            and (not filters.maxLevel or (level >= filters.minLevel and level <= filters.maxLevel))
            and (not filters.crafted or addon.crafted[id])
            and (not bossDrops or bossDrops[id]) then
            if not stat then
                AddMatch(id, gear)
            elseif (HasStat(flags, stat) or (includesShared and HasStat(flags, spellPower))) and not CheckStat(id, gear) then
                uncached[#uncached + 1] = id
            end
        end
    end
    if #uncached == 0 then return Finish(0) end

    -- Request outstanding items in small batches. Poll away from item/tooltip
    -- callbacks, and let the overlay cancel the work when the query changes.
    return {}, "Loading item stats · " .. description, function(done)
        local timer
        local nextItem, unavailable = 1, 0
        local waiting = {}
        local function Step()
            local now = GetTime()
            for id, expires in pairs(waiting) do
                if CheckStat(id, addon.gear[id]) then
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
                    if not CheckStat(id, addon.gear[id]) then
                        if C_Item.RequestLoadItemDataByID and pcall(C_Item.RequestLoadItemDataByID, id) then
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
