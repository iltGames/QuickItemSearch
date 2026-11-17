local function Noop() end

local resizeHandle
local buttons = {}
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
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(shown) self.shown = shown end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetPoint(point, x, y)
    if point == "TOPLEFT" and type(x) == "number" then self.left, self.top = x, y end
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
    assert(query == "@quest 86")
    return {
        { kind = "text", name = "Collect meat", matchLabel = questProgress },
        { id = 769, name = "Chunk of Boar Meat" },
    }, "Pie for Billy"
end
C_Item = {
    IsItemDataCachedByID = function(id)
        assert(id == 769, "Quest rows must not request item data for a quest ID")
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
local quest = assert(Result(function(entry) return entry.kind == "quest" end))
quest.scripts.OnEnter(quest)
quest:Click()
assert(searchBox:GetText() == "@quest 86", "Clicking a quest should open its detail query")
questProgress = "3/4"
window.scripts.OnEvent(window, "QUEST_LOG_UPDATE")
assert(Result(function(entry) return entry.matchLabel == "3/4" end), "Open quest details should refresh progress")
Result(function(entry) return entry.id == 769 end):Click()
assert(openedItem == "item:769", "Clicking an objective item should use the normal inspect action")

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
assert(Result(function(entry) return entry.id == 769 end))

function addon.GetItemQuestRequirements(id)
    assert(id == 769)
    return { { id = 86, name = "Pie for Billy" }, { id = 88, name = "Another Pie Quest" } }
end
function addon.Search(query)
    if query == "boar meat" then return { { id = 769, name = "Chunk of Boar Meat" } } end
    assert(query == "@quest 88", "The selected menu entry must open the corresponding quest")
    return {}, "Another Pie Quest"
end
toggle("boar meat")
local ingredient = assert(Result(function(entry) return entry.id == 769 end))
openedItem = nil
ingredient.scripts.OnClick(ingredient, "RightButton")
assert(not openedItem, "Right-click must leave the item inspection action to left-click")
ClickQuery("@quest 88")
assert(searchBox:GetText() == "@quest 88")
addon.GetItemQuestRequirements = function() return {} end
toggle("boar meat")
ingredient.scripts.OnClick(ingredient, "RightButton")
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

print("Window sizing regression passed")
