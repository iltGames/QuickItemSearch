local function Noop() end

local resizeHandle
local buttons, checkboxes = {}, {}
local addonOptions
Settings = {
    RegisterCanvasLayoutCategory = function(panel) addonOptions = panel; return {} end,
    RegisterAddOnCategory = Noop,
}
GetBindingKey = Noop
GetBindingAction = Noop
local searchBox
local methods = {}
function methods:SetScript(name, callback)
    self.scripts[name] = callback
    if callback and (name == "OnKeyDown" or name == "OnKeyUp") then
        self.keyboardEnabled = true
    end
end
function methods:EnableKeyboard(enabled) self.keyboardEnabled = enabled end
function methods:SetPropagateKeyboardInput(propagate) self.propagateKeyboard = propagate end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
function methods:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:GetFrameLevel() return 1 end
function methods:GetStringWidth() return #self.text * 6 end
function methods:GetRight() return 560 end
function methods:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = previous and function(...)
        previous(...)
        callback(...)
    end or callback
end
function methods:GetChecked() return self.checked end
function methods:SetChecked(checked) self.checked = checked end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(shown) self.shown = shown end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetPoint(point, x, y)
    if point == "TOPLEFT" and type(x) == "number" then self.left, self.top = x, y end
    if point == "TOPRIGHT" and type(x) == "number" then self.rightX, self.rightY = x, y end
end
function methods:SetHeight(height) self.height = height end
function methods:SetWidth(width) self.width = width end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetStringHeight() return 12 end
function methods:GetEffectiveScale() return 1 end
function methods:GetLeft() return 0 end
function methods:GetTop() return 900 end
function methods:GetCenter() return 500 end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetNormalTexture(texture) self.normalTexture = texture end
function methods:SetCursorPosition(position) self.cursor = position end
function methods:Click() self.scripts.OnClick(self) end
function methods:SetThumbTexture(thumb) self.thumb = thumb end
function methods:GetThumbTexture() return self.thumb end

local function Widget()
    return setmetatable({scripts = {}, shown = true}, {
        __index = function(_, key) return methods[key] or (key:match("^[A-Z]") and Noop or nil) end,
    })
end
methods.CreateTexture = Widget
methods.CreateFontString = Widget
function methods:GetName() return self.name end
function CreateFrame(kind, name, parent)
    local frame = Widget()
    frame.parent = parent
    if name then _G[name], frame.name = frame, name end
    if kind == "Button" then
        resizeHandle = frame
        buttons[#buttons + 1] = frame
    end
    if kind == "CheckButton" then
        checkboxes[#checkboxes + 1] = frame
        function frame:CreateFontString()
            self.label = Widget()
            return self.label
        end
    end
    if kind == "EditBox" then
        searchBox = frame
        frame.Instructions, frame.Left, frame.Middle, frame.Right = Widget(), Widget(), Widget(), Widget()
    end
    return frame
end

UIParent = Widget()
UIParent:SetSize(1200, 900)
GameTooltip = Widget()
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:IsOwned(owner) return self.owner == owner end
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert
InCombatLockdown = function() return false end
GetCurrentKeyBoardFocus = function() return searchBox and searchBox.focused and searchBox or nil end
local x, y = 100, 800
GetCursorPosition = function() return x, y end
QuickItemSearchSettings = {rows = 20}
local addon = {}
assert(loadfile("Search.lua"))("QuickItemSearch", addon)
assert(loadfile("Sources.lua"))("QuickItemSearch", addon)
local lastQuery
function addon.Search(query)
    lastQuery = query
    local results = {}
    for i = 1, tonumber(query) or 0 do
        results[i] = {kind = "text", name = "Result " .. i}
    end
    return results
end

assert(loadfile("UI.lua"))("QuickItemSearch", addon)
local toggle = SlashCmdList.QUICKITEMSEARCH
local function ExpectHeight(expected, context)
    local height = QuickItemSearchFrame:GetHeight()
    assert(height == expected, context .. ": expected " .. expected .. ", got " .. height)
end

toggle()
ExpectHeight(83, "examples must stay out of the main results")
assert(QuickItemSearchCloseButton, "the search window needs a close button")
QuickItemSearchCloseButton:Click()
assert(not QuickItemSearchFrame:IsShown(), "the close button must hide the search window")
toggle()
local function ClickButton(label)
    for _, button in ipairs(buttons) do
        if button.text == label or button.tooltipText == label then
            if not button.text then
                assert(button.normalTexture and not button.text and button:GetWidth() == 24)
            end
            button.scripts.OnClick(button)
            return
        end
    end
    error("Button missing: " .. label)
end
local function ClickQuery(query)
    for _, button in ipairs(buttons) do
        if button.query == query and button:IsShown() then
            button.scripts.OnClick(button)
            return
        end
    end
    error("Popup query missing: " .. query)
end
ClickButton("Examples")
ExpectHeight(83, "opening the examples popup must preserve the main panel height")
local fieldCount = 0
local fieldRows = {}
local exampleCount = 0
for _, button in ipairs(buttons) do
    if button.text and button.tooltipText then
        button.scripts.OnEnter(button)
        assert(GameTooltip:IsShown() and GameTooltip:GetText() == button.tooltipText)
        button.scripts.OnLeave(button)
        assert(not GameTooltip:IsShown(), "leaving an insert button must hide its tooltip")
        fieldCount = fieldCount + 1
        local row = fieldRows[button.top] or {}
        row[#row + 1] = button
        fieldRows[button.top] = row
    end
    if button.query and button:IsShown() then exampleCount = exampleCount + 1 end
end
assert(fieldCount == 8, "all eight insert buttons must have hover help")
for _, row in pairs(fieldRows) do
    local first, last = row[1], row[#row]
    local popupWidth = first.parent.parent:GetWidth()
    assert(first.left == popupWidth - last.left - last:GetWidth(), "insert rows must have equal side margins")
    for i = 2, #row do
        assert(row[i].left - row[i - 1].left - row[i - 1]:GetWidth() >= 6, "insert buttons need visible gaps")
    end
end
assert(exampleCount == 4, "the Examples popup must display exactly four queries")
local upgradeExample = "@me shield upgrade no sp"
local ringExample = "rings lvl 30-40 with agility near 10"
local craftedExample = "crafted leather gloves lvl 40 with agility"
ClickQuery(upgradeExample)
assert(lastQuery == upgradeExample, "clicking a query example must run it immediately")
ClickButton("History")
ClickQuery(upgradeExample)
ClickButton("Examples")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnEnterPressed(searchBox)
assert(lastQuery == ringExample, "keyboard selection must run the highlighted example")
ClickButton("Examples")
ClickQuery(craftedExample)
assert(lastQuery == craftedExample, "the examples must include a crafted gear query")
searchBox:SetText("rare")
ClickButton("Examples")
ClickButton("Boss")
assert(searchBox:GetText() == 'rare boss:""' and searchBox.cursor == 11)
assert(lastQuery == craftedExample, "quick insertion must avoid explicitly running an unfinished query")
searchBox:SetText("chest")
ClickButton("Examples")
ClickButton("Me")
assert(searchBox:GetText() == "@me chest")
ClickButton("Examples")
ClickButton("Upgrade")
assert(searchBox:GetText() == "@me chest upgrade")
searchBox:SetText("brd")
ClickButton("Examples")
ClickButton("Dungeon")
assert(searchBox:GetText() == "@dungeon brd")
ClickButton("Examples")
ClickButton("Dungeon")
assert(searchBox:GetText() == "@dungeon brd", "clicking a shortcut twice must not duplicate it")
searchBox:SetText("@D brd")
ClickButton("Examples")
ClickButton("Dungeon")
assert(searchBox:GetText() == "@dungeon brd", "the Dungeon button must replace an alias")
searchBox:SetText(" @T ")
lastQuery = nil
QuickItemSearchFrame.scripts.OnEvent(QuickItemSearchFrame, "PLAYER_TARGET_CHANGED")
assert(lastQuery and lastQuery:match("@T"), "target changes must refresh the target alias")
ClickButton("Examples")
for _, button in ipairs(buttons) do
    assert(button.text ~= "Quest" and button.query ~= 'quest:"Test of Lore"')
end
ClickButton("Target")
assert(searchBox:GetText() == "@target")
ClickButton("History")
searchBox.scripts.OnEscapePressed()
assert(QuickItemSearchFrame:IsShown(), "Escape must dismiss the popup before the search window")
searchBox:SetText("  linen cloth  ")
searchBox.scripts.OnEnterPressed(searchBox)
assert(QuickItemSearchSettings.history[1] == "linen cloth")
assert(QuickItemSearchSettings.history[2] == craftedExample)
assert(QuickItemSearchSettings.history[3] == ringExample)
assert(QuickItemSearchSettings.history[4] == upgradeExample and #QuickItemSearchSettings.history == 4)
toggle("2")
ExpectHeight(143, "two matches")
toggle("50")
ExpectHeight(683, "fifty matches at twenty-row cap")
toggle()
toggle()
ExpectHeight(83, "reopen with an empty search after fifty matches")

resizeHandle.scripts.OnDragStart()
x = x + 50
resizeHandle.scripts.OnUpdate()
resizeHandle.scripts.OnDragStop()
assert(QuickItemSearchSettings.rows == 20, "width-only drag must retain the cap")
ExpectHeight(83, "width-only drag with an empty search")

resizeHandle.scripts.OnDragStart()
y = y - 360
resizeHandle.scripts.OnUpdate()
ExpectHeight(443, "preview twelve rows while dragging")
resizeHandle.scripts.OnDragStop()
ExpectHeight(83, "empty search after releasing resize handle")
assert(QuickItemSearchSettings.rows == 12, "vertical drag must save the new cap")
toggle("50")
ExpectHeight(443, "fifty matches at twelve-row cap")
toggle("@target")
lastQuery = nil
QuickItemSearchFrame.scripts.OnEvent(QuickItemSearchFrame, "PLAYER_TARGET_CHANGED")
assert(lastQuery == "@target", "target changes must refresh an open target lookup")
for index = 1, 12 do toggle(tostring(index)) end
lastQuery = nil
QuickItemSearchFrame.scripts.OnEvent(QuickItemSearchFrame, "PLAYER_TARGET_CHANGED")
assert(lastQuery == nil, "target changes must leave other searches alone")
assert(#QuickItemSearchSettings.history == 10)
assert(QuickItemSearchSettings.history[1] == "12" and QuickItemSearchSettings.history[10] == "3")
ClickButton("History")
ClickQuery("3")
assert(lastQuery == "3", "the tenth history entry must be available in the popup")
local tooltipLines = {}
function GameTooltip:AddLine(line) tooltipLines[#tooltipLines + 1] = line end
function addon.Search()
    return { {
        kind = "text",
        name = "Bite (Rank 3)",
        petTrainingLevel = 16,
        tameSources = { { "Deepmoss Creeper", "Stonetalon Mountains", "16-17" } },
    } }
end
toggle("@spell bite 3")
for _, button in ipairs(buttons) do
    if button.entry and button.entry.tameSources then button.scripts.OnEnter(button) end
end
assert(GameTooltip:IsShown() and tooltipLines[2] == "Requires pet level 16 to train.")
assert(tooltipLines[4] == "Deepmoss Creeper - Stonetalon Mountains (Level 16-17)")

local window = QuickItemSearchFrame
local function PressWindowKey(key)
    assert(window:IsShown() and not GetCurrentKeyBoardFocus())
    if not window.keyboardEnabled then return true end
    if window.scripts.OnKeyDown then window.scripts.OnKeyDown(window, key) end
    return window.propagateKeyboard == true
end

InCombatLockdown = function() return true end
searchBox.scripts.OnEnterPressed(searchBox)
assert(PressWindowKey("W"), "an unfocused search must pass movement keys through in combat")
assert(not window.keyboardEnabled, "the idle search window must leave game bindings alone")
InCombatLockdown = function() return false end

local lastEmote
function addon.Search()
    return {
        {kind = "emote", name = "Wave"},
        {kind = "emote", name = "Bow"},
    }
end
function addon.PerformSearchEmote(entry)
    lastEmote = entry.name
    return true
end
toggle("emote")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnEnterPressed(searchBox)
assert(lastEmote == "Bow", "Enter must activate the selected search result")
assert(not PressWindowKey("UP"), "result navigation must consume the Up key")
assert(not PressWindowKey("ENTER"), "result navigation must consume Enter")
window.scripts.OnKeyUp(window, "ENTER")
assert(lastEmote == "Wave", "keyboard navigation must be able to activate another result")
assert(PressWindowKey("W") and not window.keyboardEnabled,
    "movement must pass through and end result navigation")

local questProgress = "1/4"
function addon.IsQuestDetailQuery(query) return query == "@quest 86" end
function addon.Search(query)
    if query == "@quest pie" then
        return { { kind = "quest", id = 86, name = "Pie for Billy" } }
    end
    if query == "@quest 84" then
        return {
            { kind = "text", name = "Previous quest", sectionHeader = true },
            { kind = "quest", id = 86, name = "Pie for Billy" },
        }, "Back to Billy"
    end
    assert(query == "@quest 86")
    return {
        { kind = "text", name = "Collect meat", matchLabel = questProgress },
        { id = 769, name = "Chunk of Boar Meat" },
        { kind = "text", name = "Next quests", sectionHeader = true },
        { kind = "quest", id = 84, name = "Back to Billy" },
    }, "Pie for Billy"
end
C_Item = {
    IsItemDataCachedByID = function(id)
        assert(id == 769 or id == 789, "Quest rows must not request item data for a quest ID")
        return true
    end,
    GetItemInfo = function() return "Chunk of Boar Meat", "|Hitem:769|h[Chunk of Boar Meat]|h" end,
    GetItemInfoInstant = function() return 769, nil, nil, nil, 133970 end,
}
IsModifiedClick = function() return false end
local openedItem
SetItemRef = function(link) openedItem = link end
local function Result(predicate)
    for _, button in ipairs(buttons) do
        if button.entry and predicate(button.entry) then return button end
    end
end
toggle("@quest pie")
assert(GetCurrentKeyBoardFocus() == searchBox, "Opening search should focus the query input")
local quest = assert(Result(function(entry) return entry.kind == "quest" end))
quest.scripts.OnEnter(quest)
quest:Click()
assert(searchBox:GetText() == "@quest 86", "Clicking a quest should open its detail query")
assert(not GetCurrentKeyBoardFocus() and PressWindowKey("W"), "Opening quest details must release typing focus")
questProgress = "3/4"
window.scripts.OnEvent(window, "QUEST_LOG_UPDATE")
assert(Result(function(entry) return entry.matchLabel == "3/4" end), "Open quest details should refresh progress")
searchBox:SetFocus()
Result(function(entry) return entry.id == 769 end):Click()
assert(openedItem == "item:769", "Clicking an objective item should use the normal inspect action")
assert(not GetCurrentKeyBoardFocus(), "Opening an item should release typing focus")
Result(function(entry) return entry.kind == "quest" and entry.id == 84 end):Click()
assert(searchBox:GetText() == "@quest 84", "Clicking a follow-up should open its quest details")
assert(not GetCurrentKeyBoardFocus() and PressWindowKey("W"), "Following a quest link must leave movement keys free")
Result(function(entry) return entry.kind == "quest" and entry.id == 86 end):Click()
assert(searchBox:GetText() == "@quest 86", "Clicking a prerequisite should open its quest details")

toggle("@quest pie")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnEnterPressed(searchBox)
assert(searchBox:GetText() == "@quest 86" and GetCurrentKeyBoardFocus() == searchBox,
    "Keyboard activation should still allow keyboard navigation into the quest details")

function addon.Search(query)
    if query == "zul farrak" then
        return { { kind = "dungeon", name = "Zul'Farrak" } }, nil, nil, nil, { title = "Dungeons" }
    end
    assert(query == "@dungeon Zul'Farrak")
    return { { id = 769, name = "Chunk of Boar Meat" } }, "Loot from Zul'Farrak"
end
toggle("zul farrak")
local dungeon = assert(Result(function(entry) return entry.kind == "dungeon" end))
dungeon.scripts.OnEnter(dungeon)
dungeon:Click()
assert(searchBox:GetText() == "@dungeon Zul'Farrak", "Clicking a dungeon should run its loot query")
assert(not GetCurrentKeyBoardFocus(), "Opening dungeon loot must release typing focus")
assert(Result(function(entry) return entry.id == 769 end))

function addon.Search(query)
    if query == "hogger" then
        return { { kind = "npc", id = 448, name = "Hogger" } }, nil, nil, nil, { title = "NPCs and Mobs" }
    end
    assert(query == "@npc 448")
    local locations = { { kind = "text", name = "Elwynn Forest", matchLabel = "26.0, 87.0" } }
    return locations, nil, nil, nil, {
        title = "Locations", { title = "Loot", rows = { { id = 769, name = "Chunk of Boar Meat" } } },
    }
end
toggle("hogger")
local npc = assert(Result(function(entry) return entry.kind == "npc" end))
npc.scripts.OnEnter(npc)
npc:Click()
assert(searchBox:GetText() == "@npc 448", "Clicking an NPC should open its location details")
assert(Result(function(entry) return entry.name == "Elwynn Forest" and entry.matchLabel == "26.0, 87.0" end))
assert(Result(function(entry) return entry.sectionHeader and entry.name == "Loot" end))
openedItem = nil
Result(function(entry) return entry.id == 769 end):Click()
assert(openedItem == "item:769", "NPC loot should use the normal item inspection action")

function addon.GetItemQuestRequirements(id)
    if id ~= 769 then return {} end
    return { { id = 86, name = "Pie for Billy" }, { id = 88, name = "Another Pie Quest" } }
end
LibQuestieDB = {
    Item = { Get = function(id, field)
        if field == "questRewards" then
            if id == 789 then return { 87 } end
            if id == 769 then return { 86, 87 } end
        end
    end },
    Quest = { Get = function(id, field)
        if field == "name" then return ({ [86] = "Pie for Billy", [87] = "Reward Quest" })[id] end
    end },
}
function addon.Search(query)
    if query == "boar meat" then return { { id = 769, name = "Chunk of Boar Meat" } } end
    if query == "reward" then return { { id = 789, name = "Reward" } } end
    if query == "@quest 87" then return {}, "Reward Quest" end
    assert(query == "@quest 88", "The selected menu entry must open the corresponding quest")
    return {}, "Another Pie Quest"
end
toggle("boar meat")
local ingredient = assert(Result(function(entry) return entry.id == 769 end))
openedItem = nil
ingredient.scripts.OnClick(ingredient, "RightButton")
assert(not openedItem, "Right-click must leave the item inspection action to left-click")
assert(not GetCurrentKeyBoardFocus(), "Opening an item quest menu should release typing focus")
ClickQuery("@quest 88")
assert(searchBox:GetText() == "@quest 88")
assert(not GetCurrentKeyBoardFocus(), "Choosing a quest from a menu must leave the search bar unfocused")
toggle("reward")
local reward = assert(Result(function(entry) return entry.id == 789 end))
function GameTooltip:NumLines() return 1 end
tooltipLines = {}
reward.scripts.OnEnter(reward)
assert(tooltipLines[#tooltipLines] == "Right-click to open a quest.", "Reward items should advertise the quest menu")
reward.scripts.OnClick(reward, "RightButton")
ClickQuery("@quest 87")
assert(searchBox:GetText() == "@quest 87", "A reward item should link to its quest")

toggle("boar meat")
ingredient.scripts.OnClick(ingredient, "RightButton")
local matches = {}
for _, button in ipairs(buttons) do
    if button.query and button:IsShown() and button.parent:IsShown() then
        matches[button.query] = (matches[button.query] or 0) + 1
    end
end
assert(matches["@quest 86"] == 1 and matches["@quest 87"] == 1 and matches["@quest 88"] == 1,
    "Items with both quest relationships should show each quest once")
LibQuestieDB = nil
addon.GetItemQuestRequirements = function() return {} end
toggle("boar meat")
local unrelated = assert(Result(function(entry) return entry.id == 769 end))
QuickItemSearchSourceDB[769] = nil
unrelated.scripts.OnClick(unrelated, "RightButton")
assert(searchBox:GetText() == "boar meat" and not openedItem, "Unrelated items should keep their current search")

function addon.GetItemQuestRequirements()
    local quests = {}
    for id = 78, 88 do quests[#quests + 1] = { id = id, name = "Quest " .. id } end
    return quests
end
ingredient.scripts.OnClick(ingredient, "RightButton")
local nextPage
for _, button in ipairs(buttons) do
    if button.label and button.label:GetText() == "Next quests" and button:IsShown() and button.parent:IsShown() then
        nextPage = button
        break
    end
end
assert(nextPage, "Long quest lists must offer a second page")
nextPage:Click()
ClickQuery("@quest 88")
assert(searchBox:GetText() == "@quest 88")

local function FindButton(text, parent)
    for _, button in ipairs(buttons) do
        if button.text == text and (not parent or button.parent == parent) then return button end
    end
    error("Missing button: " .. text)
end

local function SectionCheckbox(parent, section)
    local index = 0
    for _, box in ipairs(checkboxes) do
        if box.parent == parent then
            index = index + 1
            if addon.automaticSections[index] == section then return box end
        end
    end
    error("Missing section checkbox: " .. section)
end

local visibleSearches = 0
function addon.Search(query)
    visibleSearches = visibleSearches + 1
    return {}
end

local optionsButton
for _, button in ipairs(buttons) do
    if button.parent == window and button.tooltipText == "Options" then optionsButton = button end
end
assert(optionsButton and optionsButton.normalTexture == "Interface\\Buttons\\UI-OptionsButton" and not optionsButton.text,
    "Options should use a cog icon with a tooltip")
local closeButton = QuickItemSearchCloseButton
assert(closeButton:GetWidth() == 16 and optionsButton:GetWidth() == 16, "Corner controls should be small")
assert(closeButton.rightX > 0 and closeButton.rightY > 0 and closeButton.rightY == optionsButton.rightY
    and optionsButton.rightX < closeButton.rightX,
    "The cog and close button should overhang the top-right edge")
optionsButton:Click()
local compact = assert(QuickItemSearchOptionsFrame, "Options must open a compact window")
assert(compact:IsShown())
local compactQuests = SectionCheckbox(compact, "Quests")
assert(compactQuests:GetChecked())
local before = visibleSearches
compactQuests:SetChecked(false)
compactQuests:Click()
assert(not addon.IsAutomaticSectionEnabled("Quests") and visibleSearches == before + 1,
    "Changing a section should immediately refresh the open search")
addonOptions:Show()
local settingsQuests = SectionCheckbox(addonOptions, "Quests")
assert(not settingsQuests:GetChecked(), "Both options surfaces should show the saved preference")
settingsQuests:SetChecked(true)
settingsQuests:Click()
assert(compactQuests:GetChecked(), "The open compact window should reflect AddOns settings changes")

local function RewardCheckbox(panel)
    for _, check in ipairs(checkboxes) do
        if check.parent == panel and check.label and check.label:GetText() == "Quest reward links" then return check end
    end
    error("Missing quest reward preference")
end
local compactRewards = RewardCheckbox(compact)
local settingsRewards = RewardCheckbox(addonOptions)
assert(compactRewards:GetChecked() and settingsRewards:GetChecked(), "Quest reward links should be on by default")

local compactFollowUps = SectionCheckbox(compact, "Next quests")
local settingsFollowUps = SectionCheckbox(addonOptions, "Next quests")
assert(compactFollowUps:GetChecked() and settingsFollowUps:GetChecked(), "Next quests should be on by default")
settingsFollowUps:SetChecked(false)
settingsFollowUps:Click()
assert(not compactFollowUps:GetChecked() and QuickItemSearchSettings.hiddenSections["Next quests"] == true)
local reloaded = {}
assert(loadfile("Search.lua"))("QuickItemSearch", reloaded)
assert(not reloaded.IsAutomaticSectionEnabled("Next quests"), "Follow-up visibility should persist after reload")
local compactPrerequisites = SectionCheckbox(compact, "Previous quests")
local settingsPrerequisites = SectionCheckbox(addonOptions, "Previous quests")
assert(compactPrerequisites:GetChecked() and settingsPrerequisites:GetChecked())
compactPrerequisites:SetChecked(false)
compactPrerequisites:Click()
assert(not settingsPrerequisites:GetChecked() and not reloaded.IsAutomaticSectionEnabled("Previous quests"))

local compactNPCs = SectionCheckbox(compact, "NPCs and Mobs")
local settingsNPCs = SectionCheckbox(addonOptions, "NPCs and Mobs")
assert(compactNPCs:GetChecked() and settingsNPCs:GetChecked(), "NPC results should be automatic by default")
settingsNPCs:SetChecked(false)
settingsNPCs:Click()
assert(not compactNPCs:GetChecked() and not reloaded.IsAutomaticSectionEnabled("NPCs and Mobs"),
    "NPC visibility should sync across menus and persist across reloads")
local compactLoot = SectionCheckbox(compact, "NPC Loot")
local settingsLoot = SectionCheckbox(addonOptions, "NPC Loot")
assert(compactLoot:GetChecked() and settingsLoot:GetChecked(), "NPC loot should be on by default")
compactLoot:SetChecked(false)
compactLoot:Click()
assert(not settingsLoot:GetChecked() and not reloaded.IsAutomaticSectionEnabled("NPC Loot"),
    "NPC loot visibility should sync across menus and persist across reloads")
local compactVendors = SectionCheckbox(compact, "Vendor Items")
local settingsVendors = SectionCheckbox(addonOptions, "Vendor Items")
assert(compactVendors:GetChecked() and settingsVendors:GetChecked(), "Vendor items should be on by default")
settingsVendors:SetChecked(false)
settingsVendors:Click()
assert(not compactVendors:GetChecked() and not reloaded.IsAutomaticSectionEnabled("Vendor Items"),
    "Vendor inventory visibility should sync across menus and persist across reloads")

FindButton("50", compact):Click()
for i = 1, 55 do toggle("search " .. i) end
assert(#QuickItemSearchSettings.history == 50 and QuickItemSearchSettings.history[50] == "search 6")
ClickButton("History")
for page = 1, 4 do
    local nextHistory
    for _, button in ipairs(buttons) do
        if button.label and button.label:GetText() == "Next searches" and button:IsShown() then
            nextHistory = button
            break
        end
    end
    assert(nextHistory, "All retained history should be reachable")
    nextHistory:Click()
end
ClickQuery("search 6")
assert(searchBox:GetText() == "search 6")

FindButton("5", addonOptions):Click()
assert(FindButton("5", compact).enabled == false)
assert(#QuickItemSearchSettings.history == 5 and QuickItemSearchSettings.history[1] == "search 6")
FindButton("Off", compact):Click()
toggle("ignored")
assert(#QuickItemSearchSettings.history == 0)
FindButton("10", compact):Click()
toggle("recorded")
assert(QuickItemSearchSettings.history[1] == "recorded")
window:Hide()
assert(not compact:IsShown(), "Options must close with the search window")

compactRewards:SetChecked(false)
compactRewards:Click()
assert(not settingsRewards:GetChecked(), "The reward setting should sync across both menus")
addon.GetItemQuestRequirements = function() return {} end
assert(loadfile("UI.lua"))("QuickItemSearch", addon)
addonOptions:Hide()
addonOptions:Show()
local reloadedRewards = RewardCheckbox(addonOptions)
assert(not reloadedRewards:GetChecked(), "Disabled quest reward links should persist after reload")
function addon.Search(query)
    if query == "reward" then return { { id = 789, name = "Reward" } } end
    assert(query == "@quest 87" or query == "@quest 88")
    return {}
end
SlashCmdList.QUICKITEMSEARCH("reward")
reward = assert(Result(function(entry) return entry.id == 789 end))
tooltipLines = {}
reward.scripts.OnEnter(reward)
assert(tooltipLines[#tooltipLines] ~= "Right-click to open a quest.", "Disabled reward links should omit the menu hint")
reward.scripts.OnClick(reward, "RightButton")
for _, button in ipairs(buttons) do
    assert(button.query ~= "@quest 87" or not button:IsShown() or not button.parent:IsShown(),
        "Turning off quest reward links should hide reward-only quests")
end
addon.GetItemQuestRequirements = function() return { { id = 88, name = "Required Quest" } } end
reward.scripts.OnClick(reward, "RightButton")
ClickQuery("@quest 88")
assert(searchBox:GetText() == "@quest 88", "Turning off reward links should preserve required quest links")
addon.GetItemQuestRequirements = function() return {} end
reloadedRewards:SetChecked(true)
reloadedRewards:Click()
SlashCmdList.QUICKITEMSEARCH("reward")
reward.scripts.OnClick(reward, "RightButton")
ClickQuery("@quest 87")
assert(searchBox:GetText() == "@quest 87", "Re-enabling links should restore cached reward quests")

print("Window sizing and search options passed")
