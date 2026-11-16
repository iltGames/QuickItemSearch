local addon = {
    index = { [1] = "Boss Sword", [2] = "Quest Staff", [3] = "Trash Mace", [4] = "Boss Token",
        [10620] = "Thorium Ore", [3819] = "Wintersbite", [2447] = "Peacebloom", [2770] = "Copper Ore",
        [3820] = "Stranglekelp", [3821] = "Goldthorn", [5] = "Herb Pouch",
        [6] = "Wave Wand", [7] = "PTR Test Wand" },
    ptrOnly = { [7] = true },
    gear = { { 17, 25, 32, 3, 1 }, { 17, 25, 0, 3, 1 }, { 17, 25, 0, 3, 1 } },
    playerSpells = { [467] = "Thorns", [468] = "Power", [469] = "Mine", [470] = "Power Word: Shield" },
    recipes = { { 17187, "Transmute: Arcanite", "Alchemy", 275, 12360 },
        { 500, "Spell Thread", "Tailoring", 100 }, { 501, "Kelp Draught", "Alchemy", 75, false, { 3820 } },
        { 502, "Herbal Oil", "Alchemy", 110, false, { 3820, 3821 } },
        { 503, "Kelp Oil", "Alchemy", 110, false, { 3821 } } },
}

for _, file in ipairs({ "GearSearch", "Questions", "Search", "SpellSearch", "EmoteSearch", "RecipeSearch", "Sources" }) do
    assert(loadfile(file .. ".lua"))("QuickItemSearch", addon)
end

local function matches(query, ...)
    local results, hint, _, answer = addon.Search(query)
    local expected = { ... }
    assert(#results == #expected, query .. " returned " .. #results .. " results")
    for i, id in ipairs(expected) do assert(results[i].id == id, query .. " returned the wrong result") end
    return results[1], hint, answer
end

C_Item = { GetItemStats = function() return { ITEM_MOD_SPELL_POWER_SHORT = 5 } end }
EMOTE19_TOKEN, EMOTE19_CMD1, EMOTE19_CMD2 = "WAVE", "/wave", "/greet"
local function section(query, title)
    local rows, _, _, _, sections = addon.Search(query)
    if sections and sections.title == title then return rows end
    for _, entry in ipairs(sections or {}) do
        if entry.title == title then return entry.rows end
    end
end
assert(section("herb", "Gathering") and section("herb", "Gathering")[1].id == 2447,
    "herb should list gathering nodes alongside items")
assert(section("herb", "Items")[1].id == 5 and section("herb", "Recipes")[1].id == 502)
assert(section("gather herb", "Items")[1].id == 5)
assert(section("thorns", "Spells")[1].id == 467)
assert(section("wave", "Items")[1].id == 6 and section("wave", "Emotes")[1].token == "WAVE")
assert(section("emote greet", "Emotes")[1].name == "/wave")
local yawn = { token = "YAWN" }
local performed = {}
C_ChatInfo = { PerformEmote = function(token)
    performed[#performed + 1] = token
    return false
end }
assert(addon.PerformSearchEmote(yawn), "A dispatched emote should let the client report its outcome")
assert(#performed == 1 and performed[1] == "YAWN")
C_ChatInfo = nil
matches("ptr test wand")
matches("item:7")
assert(matches("spell thorns", 467).kind == "spell")
matches("thorns spell", 467)
matches("spell 467", 467)
matches("spell power", 1)
matches("spell:power", 468, 470)
matches("spell mine", 469)
matches("power spell word: shield", 470)
matches('spell "power word: shield"', 470)
local _, _, craftAnswer = matches("craft arcanite transmute", 17187)
assert(craftAnswer == "Requires Alchemy 275.")
matches("transmute arcan craft", 17187)
matches("arcanite craft transmute", 17187)
matches("craft spell thread", 500)
matches('"spell thread" craft', 500)
matches("craft 17187", 17187)
matches("make arcanite transmute", 17187)
matches("how to make arcanite transmute", 17187)
matches("stranglekelp usedin", 502, 501)
matches("usedin strangle", 502, 501)
matches("stranglekelp used in", 502, 501)
matches("usedin 3820", 502, 501)
matches("arcanite make transmute", 17187)
matches("arcanite transmute make", 17187)
matches("how do I make arcanite transmute?", 17187)
local _, _, gatherAnswer = matches("wintersb gather", 3819)
assert(gatherAnswer == "Requires Herbalism 195.")
local _, _, oreAnswer = matches("what level can I rich mine thorium vein?", 10620)
assert(oreAnswer and oreAnswer:find("Mining 275", 1, true))

for _, query in ipairs({ "gather herb", "herbs gather", "pick herbs", "gather herbalism", "harvest herbs" }) do
    local rows = addon.Search(query)
    assert(#rows == 4 and rows[1].id == 2447 and rows[1].matchLabel == "Herbalism 1", query)
    assert(table.concat(rows[1].gatheringThresholds, "/") == "1/25/65/100", query)
    assert(rows[2].id == 3820 and table.concat(rows[2].gatheringThresholds, "/") == "85/110/150/185", query)
    assert(rows[4].id == 3819 and rows[4].matchLabel == "Herbalism 195", query)
end
for _, query in ipairs({ "gather ore", "ores mine", "mine nodes", "gather mining", "gather mine", "mine gather",
    "gather veins", "gather deposits" }) do
    local rows = addon.Search(query)
    assert(#rows == 3 and rows[1].nodeName == "Copper Vein" and rows[1].matchLabel == "Mining 1", query)
    assert(table.concat(rows[1].gatheringThresholds, "/") == "1/25/50/100", query)
    assert(rows[2].id == 10620 and rows[2].nodeName == "Small Thorium Vein" and rows[2].matchLabel == "Mining 245")
    assert(rows[3].id == 10620 and rows[3].nodeName == "Rich Thorium Vein" and rows[3].matchLabel == "Mining 275")
end
assert(#addon.Search("gather nodes") == 7)
assert(table.concat(addon.Search("mine copper vein")[1].gatheringThresholds, "/") == "1/25/50/100")

for _, query in ipairs({ "skin", "gather skin", "gather skinning", "skin gather" }) do
    local rows = addon.Search(query)
    assert(#rows == 13 and rows[1].matchLabel == "Skinning 1-24" and rows[1].name == "Max mob level 10-12", query)
    assert(rows[13].matchLabel == "Skinning 300" and rows[13].name == "Max mob level 60", query)
end
for _, query in ipairs({ "skin 125", "125 skin", "gather skin 125" }) do
    local rows = addon.Search(query)
    assert(#rows == 1 and rows[1].kind == "text" and rows[1].name == "Mob levels 1-25", query)
end
assert(addon.Search("skin 99")[1].name == "Mob levels 1-19")
assert(addon.Search("skin 100")[1].name == "Mob levels 1-20")

local herb = matches("stranglekelp", 3820)
assert(table.concat(herb.gatheringThresholds, "/") == "85/110/150/185")
assert(matches("3820", 3820).gatheringProfession == "Herbalism")
local thorium = addon.Search("thorium ore")
assert(#thorium == 3 and thorium[1].name == "Thorium Ore")
assert(thorium[2].nodeName == "Small Thorium Vein" and thorium[2].gatheringThresholds[1] == 245)
assert(thorium[3].nodeName == "Rich Thorium Vein" and thorium[3].gatheringThresholds[1] == 275)

addon.index[700] = "Rugged Skin"
addon.index[701] = "Stranglekelp Seed"
addon.index[702] = "Spellstone"
addon.sortedEntries = nil
local spellItems, _, _, _, spellSections = addon.Search("spell")
assert(#spellItems == 1 and spellItems[1].id == 702 and spellSections.title == "Items")
assert(spellSections[1].title == "Spells" and #spellSections[1].rows == 4)
for _, alias in ipairs({ "craft", "make" }) do
    local recipes, _, _, _, sections = addon.Search(alias)
    assert(#recipes == 5 and sections.title == "Recipes", alias)
end
local nodes, _, _, _, nodeSections = addon.Search("gather")
assert(#nodes == 7 and nodeSections.title == "Gathering")
assert(#addon.Search("pick") == 4 and #addon.Search("mine") == 3 and #addon.Search("harvest") == 7)
local trainers, _, _, _, trainerSections = addon.Search("trainer")
assert(#trainers > 12 and trainerSections.title == "Trainers")
assert(trainers[1].matchLabel:find("Alchemy", 1, true))
local reagents, _, _, _, reagentSections = addon.Search("used in")
assert(#reagents == 2 and reagents[1].name == "Goldthorn" and reagentSections.title == "Reagents")
local skinItems, _, _, _, skinSections = addon.Search("skin")
assert(skinItems[1].id == 700 and skinSections.title == "Items")
assert(skinSections[1].title == "Skinning" and #skinSections[1].rows == 13)
local kelpRecipes = section("stranglekelp", "Recipes")
assert(section("stranglekelp", "Items")[1].id == 3820 and section("stranglekelp", "Gathering")[1].id == 3820)
assert(#kelpRecipes == 2 and kelpRecipes[1].id == 502)
local gatheringRows, _, _, gatheringAnswer, gatheringSections = addon.Search("gather stranglekelp")
assert(gatheringRows[1].id == 3820 and gatheringAnswer == "Requires Herbalism 85.")
assert(gatheringSections.title == "Gathering" and gatheringSections[1].title == "Items")
assert(#gatheringSections[1].rows == 1 and gatheringSections[1].rows[1].id == 701)
assert(gatheringSections[2].title == "Recipes" and #gatheringSections[2].rows == 2)

for _, level in ipairs({ 10, 12, 16, 219, 220 }) do
    addon.index[level] = "Test Ring " .. level
    addon.gear[level] = { 11, level, 0, 2, 2 }
end
addon.sortedEntries = nil
matches("lvl10", 10, 12)
matches("lv10", 10, 12)
matches("level10 rings", 10, 12)
matches("rings for lvl10", 10, 12)
matches("lvl10-16", 10, 12, 16)
matches("rings lv10-16", 10, 12, 16)
matches("rings level10–16", 10, 12, 16)
matches("rings level10-219", 10, 12, 16, 219)
local _, invalidRange = matches("lvl16-10")
assert(invalidRange and invalidRange:find("ascending", 1, true))

local armorClasses = { [601] = 3, [602] = 2, [603] = 3, [604] = 3, [605] = 3, [606] = 3 }
for id in pairs(armorClasses) do
    addon.index[id] = "Test Belt " .. id
    addon.gear[id] = { id == 605 and 10 or 6, 40, id == 604 and 0 or 1, 2, 2 }
end
addon.crafted = { [601] = true, [602] = true, [604] = true, [605] = true, [606] = true }
addon.sortedEntries = nil
C_Item.GetItemInfoInstant = function(id)
    return id, nil, nil, nil, nil, id == 606 and 2 or 4, armorClasses[id]
end
C_Item.GetItemStats = function()
    return { ITEM_MOD_SPELL_POWER_SHORT = 5, ITEM_MOD_AGILITY_SHORT = 7 }
end
assert(matches("make belt agil mail", 601).matchLabel == "+7 Agility")
matches("mail belt craft agil", 601)
matches("belt agil mail make lvl40", 601)
matches("crafted belt agil leather", 602)
matches("belt agil mail", 601, 603)
matches("belts with agility chainmail", 601, 603)
matches("belts agility about 7 chainmail", 601, 603)
matches("handcrafted belts binds on equip", 601, 602, 604, 606)
matches("2h bind on pickup", 1, 2, 3)
matches("two handed weps", 1, 2, 3)
matches("twohanded weapons", 1, 2, 3)
matches("two-handed quality rare", 1, 2, 3)
matches("2h spell dmg", 1)
C_Item.IsItemDataCachedByID = function() return false end
local loading, _, loadCraftedStats = addon.Search("make belt agil mail")
assert(#loading == 0 and type(loadCraftedStats) == "function")
C_Item.IsItemDataCachedByID = nil

for _, item in ipairs({ { 607, 15, 2 }, { 608, 21, 2 }, { 609, 15, 3 } }) do
    local id, level, armorType = unpack(item)
    addon.index[id] = "Test Leg Armor " .. id
    addon.gear[id] = { 7, level, 0, 2, 2 }
    armorClasses[id] = armorType
end
addon.sortedEntries = nil
matches("lv10-20 legs leather", 607)
for _, alias in ipairs({ "pant", "pants", "leggings", "trousers" }) do
    matches("lv10-20 " .. alias .. " leather", 607)
end
matches("level10-20 leg leather armor", 607)

local allTrainers = addon.Search("train alchemy")
assert(#allTrainers == 10, "train alchemy should list all indexed trainers")
assert(#addon.Search("alchemy trainer") == #allTrainers)
for index, rank in pairs({ [1] = "Apprentice", [3] = "Journeyman", [6] = "Expert", [8] = "Artisan" }) do
    assert(allTrainers[index].kind == "text" and allTrainers[index].matchLabel:find(rank, 1, true))
end
local artisanTrainers = addon.Search("Where to train Alchemy 225?")
assert(#artisanTrainers == 3)
assert(artisanTrainers[1].description:find("Requires Alchemy 200 and character level 35", 1, true))
assert(artisanTrainers[1].name == "Kylanna Windwhisper - Feathermoon Stronghold, Feralas")
assert(artisanTrainers[2].name == "Rogvar - Stonard, Swamp of Sorrows")
assert(artisanTrainers[3].name == "Master Mycologist Shurome - Emerald Sanctuary, Felwood")
local expertTrainers = addon.Search("where can i train alchemy 150")
assert(#expertTrainers == 2 and expertTrainers[1].name:find("Ainethil", 1, true))
local _, _, unsupported = matches("where to train inscription 225")
assert(unsupported and unsupported:find("No verified", 1, true))
local _, _, outOfRange = matches("where to train alchemy 301")
assert(outOfRange and outOfRange:find("0–300", 1, true))

local artisanSources = {
    blacksmithing = "Brikk Keencraft", enchanting = "Annora", engineering = "Buzzek Bracketswing",
    herbalism = "Tannysa", leatherworking = "Drakk Stonehand", mining = "Geofram Bouldertoe",
    skinning = "Maris Granger", tailoring = "Timothy Worthington",
    cooking = "Dirge Quikcleave", ["first aid"] = "Doctor Gustaf VanHowzen", fishing = "Nat Pagle",
}
for profession, trainer in pairs(artisanSources) do
    local all = addon.Search("train " .. profession)
    assert(#all > 0, "Missing trainer list for " .. profession)
    for _, skill in ipairs({ 0, 75, 150, 225 }) do
        local rows = addon.Search("train " .. profession .. " " .. skill)
        assert(#rows > 0 and rows[1].kind == "text", "Missing rank for " .. profession .. " at " .. skill)
        if skill == 225 then
            assert(rows[1].name:find(trainer, 1, true), "Wrong Artisan trainer for " .. profession)
        end
    end
end
local cookingBook = addon.Search("train cooking 150")[1]
assert(cookingBook.name:find("Book: Shandrina", 1, true))
assert(cookingBook.description:find("Expert Cookbook", 1, true))
local triage = addon.Search("train first aid 225")[1]
assert(triage.name:find("Quest:", 1, true) and triage.description:find("Triage", 1, true))
assert(triage.description:find("First Aid 225 and character level 35", 1, true))

local professionAliases = {
    alchemy = { "alch" },
    blacksmithing = { "blacksmith", "BS", "smithing" },
    cooking = { "cook" },
    enchanting = { "ench", "enchant" },
    engineering = { "eng", "engi" },
    ["first aid"] = { "FA", "firstaid", "first-aid" },
    fishing = { "fish" },
    herbalism = { "herb", "herbs" },
    leatherworking = { "LW", "leatherwork", "leather working" },
    mining = { "mine" },
    skinning = { "skin" },
    tailoring = { "tailor" },
}
for profession, aliases in pairs(professionAliases) do
    for _, suffix in ipairs({ "", " 225" }) do
        local expected = addon.Search("train " .. profession .. suffix)
        for _, alias in ipairs(aliases) do
            for _, query in ipairs({
                "Where can I train " .. alias .. suffix .. "?",
                alias .. " train" .. suffix,
                alias .. suffix .. " train",
            }) do
                local results = addon.Search(query)
                assert(#results == #expected, "Missing trainer results for " .. query)
                for index, row in ipairs(results) do
                    assert(row.name == expected[index].name and row.description == expected[index].description)
                end
            end
        end
    end
end
addon.index[5] = "Toy Train"
addon.index[6] = "Dark Iron Mine Key"
addon.sortedEntries = nil
matches("toy train", 5)
matches("dark iron mine key", 6)
matches('"dark iron mine"', 6)
assert(#addon.Search("Where can I first train aid 225?") == 2)
assert(#addon.Search('"first aid" train 225') == 2)
assert(#addon.Search("where can i bs train 225?") == #addon.Search("train bs 225"))
local mining = addon.Search("train mining")
local seen = {}
for _, row in ipairs(mining) do
    assert(not seen[row.name], "All-rank lookup repeats a trainer")
    seen[row.name] = true
end

local encounters = {
    { name = "Test Boss", [1] = { { 1, 1 }, { 2, 4 }, { 3, 7 } } },
    { name = "Trash", ExtraList = true, [1] = { { 1, 3 } } },
}
local atlas = { Dungeon = { items = encounters } }
AtlasLoot = { ItemDB = {
    Get = function() return atlas end,
    GetNameData_UNSAFE = function(_, _, _, boss) return "Dungeon", encounters[boss].name end,
    GetItemTable = function(_, _, _, boss, difficulty) return encounters[boss][difficulty], { "Item" } end,
} }
LibQuestieDB = {
    Item = { Get = function(id, field) if id == 2 and field == "questRewards" then return { 123 } end end },
    Quest = { Get = function(id) if id == 123 then return "Test Quest" end end },
}

matches("rare boss", 1)
matches("rare boss loot", 1)
matches('boss:"Test Boss" rare', 1)
matches('2h rare boss:"Test Boss"', 1)
matches("rare boss:test", 1)
matches("rare boss:trash")
matches("boss:Test Boss", 1, 4)
matches("2h quest", 2)
matches('quest:"Test Quest" rare', 2)
matches("rare quest:123", 2)
matches("boss quest")
matches("Quest Staff", 2)
assert(addon.GetItemSources(2)[1].name == "Test Quest")
LibQuestieDB = nil
matches('rare quest:"Test Quest"', 2)
QuickItemSearchSourceDB = nil
local _, unavailable = matches("quest rewards")
assert(unavailable:find("QuestieDB", 1, true))

local bundled = {}
for _, file in ipairs({ "ItemIndex", "PtrItemIndex", "SpellIndex", "RecipeIndex", "Questions", "Search", "SpellSearch",
    "EmoteSearch", "RecipeSearch" }) do
    assert(loadfile(file .. ".lua"))("QuickItemSearch", bundled)
end
assert(bundled.IsPTRItem(273608) and bundled.IsPTRItem(273610) and not bundled.IsPTRItem(241195))
assert(#bundled.Search("273608") == 0)
local arcanist = bundled.Search("grand arcanist")
assert(#arcanist > 0)
for _, row in ipairs(arcanist) do assert(not bundled.IsPTRItem(row.id)) end
assert(bundled.Search("harvest fish")[1].id == 19996)
assert(bundled.Search("harvest clo")[1].id == 4771)
assert(#bundled.Search("thorns spell") >= 6)
local recipes, _, _, answer = bundled.Search("craft arcanite transmute")
assert(#recipes == 1 and recipes[1].id == 17187 and recipes[1].matchLabel == "Alchemy 275")
assert(answer == "Requires Alchemy 275.")
assert(table.concat(recipes[1].skillThresholds, "/") == "275/275/282/290")
assert(bundled.GetItemRecipes(12360)[1].id == 17187)
assert(table.concat(bundled.GetItemRecipes(2840)[1].skillThresholds, "/") == "1/25/47/70")
assert(#bundled.GetItemRecipes(18258) == 2)
for _, recipe in ipairs(bundled.recipes) do
    local thresholds = recipe[7]
    assert(#thresholds == 4 and thresholds[1] == recipe[4] and thresholds[2] <= thresholds[3]
        and thresholds[3] <= thresholds[4], "Invalid skill thresholds for " .. recipe[2])
end
assert(bundled.Search("craft arcanite bar")[1].id == 17187)
local sharedRecipe = bundled.Search("craft 461692")
assert(#sharedRecipe == 2 and sharedRecipe[1].matchLabel == "Leatherworking 275"
    and sharedRecipe[2].matchLabel == "Tailoring 275")

local stranglekelpUses = bundled.Search("what is stranglekelp used in?")
local usesByID = {}
for _, row in ipairs(stranglekelpUses) do
    assert(row.kind == "spell")
    usesByID[row.id] = true
end
assert(usesByID[3173] and usesByID[6624] and not usesByID[17187] and not usesByID[426607])
local enchants, _, _, _, enchantSections = bundled.Search("enchant")
local enchantRows = enchantSections.title == "Items" and enchantSections[1].rows or enchants
assert(#enchantRows > 100)
for _, row in ipairs(enchantRows) do assert(row.matchLabel:find("Enchanting", 1, true)) end

local function checkEnchants(query, ...)
    local expected = {}
    for _, id in ipairs({ ... }) do expected[id] = true end
    local rows = bundled.Search(query)
    for _, row in ipairs(rows) do
        assert(expected[row.id] and row.kind == "spell" and row.matchLabel:find("Enchanting", 1, true), query)
        expected[row.id] = nil
    end
    assert(not next(expected), "Missing enchant results for " .. query)
end
checkEnchants("enchant gloves agil", 13815, 20012, 25080)
checkEnchants("gloves enchant agi", 13815, 20012, 25080)
checkEnchants("chest agil enchant", 13626, 13700, 13941, 20025)
checkEnchants("enchant chest agility", 13626, 13700, 13941, 20025)
checkEnchants("enchant 13815", 13815)
checkEnchants("enchant 17187")

for _, file in ipairs({ "GearIndex", "CraftedIndex", "GearSearch" }) do
    assert(loadfile(file .. ".lua"))("QuickItemSearch", bundled)
end
for _, query in ipairs({ "craft belt tailor", "tailoring belt craft", "make tailor belts" }) do
    local rows, hint = bundled.Search(query)
    assert(#rows > 0 and hint:find("Tailoring", 1, true), query)
    local foundLinenBelt
    for _, row in ipairs(rows) do
        assert(bundled.gear[row.id][1] == 6, query)
        local tailored
        for _, recipe in ipairs(bundled.GetItemRecipes(row.id) or {}) do
            if recipe.profession == "Tailoring" then tailored = true end
        end
        assert(tailored, row.name .. " has no Tailoring recipe")
        if row.id == 7026 then foundLinenBelt = true end
    end
    assert(foundLinenBelt, query .. " did not find Linen Belt")
end
assert(bundled.Search("craft arcanite transmute alch")[1].id == 17187)
local gloveEnchants = bundled.Search("craft gloves enchanting")
assert(#gloveEnchants > 0, "Crafting with Enchanting should find glove recipes")
for _, row in ipairs(gloveEnchants) do assert(row.profession == "Enchanting") end
print("Search keyword order, gear and source filters, and recipe requirements passed.")
