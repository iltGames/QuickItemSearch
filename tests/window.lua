local function Noop() end

local resizeHandle
local buttons, checkboxes, sliders = {}, {}, {}
local addonOptions, openedSettingsCategory
Settings = {
    RegisterCanvasLayoutCategory = function(panel)
        addonOptions = panel
        return { GetID = function() return 123 end }
    end,
    RegisterAddOnCategory = Noop,
    OpenToCategory = function(id) openedSettingsCategory = id end,
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
function methods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
function methods:SetPropagateKeyboardInput(propagate) self.propagateKeyboard = propagate end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
function methods:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:LockHighlight() self.highlighted = true end
function methods:UnlockHighlight() self.highlighted = false end
function methods:GetFrameLevel() return 1 end
function methods:GetParent() return self.parent end
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
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end

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
    if kind == "Slider" then sliders[#sliders + 1] = frame end
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
assert(loadfile("MapPins.lua"))("QuickItemSearch", addon)
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
local petRow
for _, button in ipairs(buttons) do
    if button.entry and button.entry.tameSources then petRow = button; break end
end
petRow.scripts.OnEnter(petRow)
assert(GameTooltip:IsShown() and #tooltipLines == 2 and tooltipLines[2] == "Right-click for training details.",
    "Pet training information should move out of the tooltip")
petRow.scripts.OnClick(petRow, "RightButton")
local sourceWithoutQuestie
for _, button in ipairs(buttons) do
    if button.label and button.label:GetText() == "Deepmoss Creeper - lvl 16-17 (Stonetalon Mountains)"
        and button:IsShown() and button.parent:IsShown() then
        sourceWithoutQuestie = button
    end
end
assert(sourceWithoutQuestie and not sourceWithoutQuestie.enabled and not sourceWithoutQuestie.query,
    "The menu must still show the beast's level and zone without QuestieDB")
QuickItemSearchSettings.resultContextMenus = false
toggle("@spell bite 3")
petRow.scripts.OnClick(petRow, "RightButton")
assert(sourceWithoutQuestie:IsShown() and sourceWithoutQuestie.parent:IsShown(),
    "Old context menu settings should not hide pet training details")
LibQuestieDB = { Npc = { Get = Noop, GetAllIds = function() return {} end } }
toggle("@spell bite 3")
petRow.scripts.OnClick(petRow, "RightButton")
for _, button in ipairs(buttons) do
    if button.query == "@npc Deepmoss Creeper" and button:IsShown() and button.parent:IsShown() then
        assert(button.label:GetText() == "Find Deepmoss Creeper - lvl 16-17 (Stonetalon Mountains)")
    end
end
ClickQuery("@npc Deepmoss Creeper")
assert(searchBox:GetText() == "@npc Deepmoss Creeper", "The label should retain the exact beast lookup")
LibQuestieDB = nil
toggle("@spell bite 3")

local window = QuickItemSearchFrame
local function ClickWindowArea(target)
    GetMouseFoci = function() return { target } end
    if window.events.GLOBAL_MOUSE_DOWN then window.scripts.OnEvent(window, "GLOBAL_MOUSE_DOWN", "LeftButton") end
end
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

local lastEmote, finishDelayedSearch
function addon.Search(query)
    local matches = {
        {kind = "emote", name = "Wave"},
        {kind = "emote", name = "Bow"},
    }
    if query == "emote delayed" then
        return matches, nil, function(done)
            finishDelayedSearch = done
            return Noop
        end
    end
    return matches
end
function addon.PerformSearchEmote(entry)
    lastEmote = entry.name
    return true
end
toggle("emote")
local previousTimer, cancelledDebounce = C_Timer, false
C_Timer = { NewTimer = function()
    return { Cancel = function() cancelledDebounce = true end }
end }
searchBox:SetText("emote delayed")
searchBox.scripts.OnTextChanged(searchBox)
searchBox.scripts.OnEnterPressed(searchBox)
C_Timer = previousTimer
assert(not GetCurrentKeyBoardFocus() and window.keyboardEnabled,
    "Confirming a search with Enter should transfer the arrows from the edit box to the results")
assert(cancelledDebounce and finishDelayedSearch, "Enter should run a pending query before handing off keyboard focus")
finishDelayedSearch({ { kind = "emote", name = "Wave" }, { kind = "emote", name = "Bow" } })
assert(not PressWindowKey("DOWN"), "A late search update should keep result navigation active")
assert(not PressWindowKey("ENTER"))
window.scripts.OnKeyUp(window, "ENTER")
assert(lastEmote == "Bow", "The arrows should still select the next result after the update")
toggle("emote")
assert(GetCurrentKeyBoardFocus() == searchBox)
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
assert(not GetCurrentKeyBoardFocus() and window.keyboardEnabled,
    "Down in the search box should hand keyboard navigation over to the results")
assert(not PressWindowKey("ENTER"))
window.scripts.OnKeyUp(window, "ENTER")
assert(lastEmote == "Bow", "The first Down should move to the next result before handing off")
for _, key in ipairs({ "LEFT", "RIGHT", "RIGHT", "LEFT" }) do
    assert(not PressWindowKey(key) and window.keyboardEnabled,
        key .. " should keep navigation active on a result without context actions")
end
assert(not PressWindowKey("UP"), "result navigation must consume the Up key")
assert(not PressWindowKey("ENTER"), "result navigation must consume Enter")
window.scripts.OnKeyUp(window, "ENTER")
assert(lastEmote == "Wave", "keyboard navigation must be able to activate another result")
ClickWindowArea(UIParent)
assert(PressWindowKey("DOWN"), "Clicking away should release arrow keys to the game")
ClickWindowArea(window)
assert(not PressWindowKey("DOWN"), "Clicking back should restore arrow navigation")
assert(not PressWindowKey("ENTER"))
window.scripts.OnKeyUp(window, "ENTER")
assert(lastEmote == "Bow", "Arrow navigation should resume from the previous result")
assert(PressWindowKey("W") and not window.keyboardEnabled,
    "movement must pass through and end result navigation")

local questProgress = "1/4"
local morePrerequisites
function addon.IsQuestDetailQuery(query) return query == "@quest 86" or query == "@quest 84" end
function addon.Search(query)
    if query == "@quest pie" then
        return { { kind = "quest", id = 86, name = "Pie for Billy" } }
    end
    if query == "@quest 84" then
        local previousQuests = {
            { kind = "text", name = morePrerequisites and "Previous quests" or "Previous quest",
                sectionHeader = true, collapsible = morePrerequisites and 2 or 1, sectionKey = "Previous quests" },
            { kind = "quest", id = 86, name = "Pie for Billy" },
        }
        if morePrerequisites then
            previousQuests[#previousQuests + 1] = { kind = "quest", id = 85, name = "An Earlier Quest" }
        end
        return previousQuests, "Back to Billy"
    end
    assert(query == "@quest 86")
    local detailRows = {
        { kind = "text", name = "Collect meat", matchLabel = questProgress },
        { id = 769, name = "Chunk of Boar Meat" },
        { kind = "text", name = "Next quests", sectionHeader = true, collapsible = 1 },
        { kind = "quest", id = 84, name = "Back to Billy" },
    }
    if questProgress == "3/4" then
        table.insert(detailRows, 2, { kind = "text", name = "Reward details loaded" })
    end
    return detailRows, "Pie for Billy"
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
do
    local search = addon.Search
    local extra = { kind = "text", name = "Fourth match" }
    function addon.Search()
        return {
            { kind = "text", name = "First match" },
            { kind = "text", name = "Second match" },
            { kind = "text", name = "Third match" },
            extra,
        }, nil, nil, nil, { title = "Matches", { title = "Other", rows = { { kind = "text", name = "Other match" } } } }
    end
    local function ExtraMatch() return Result(function(entry) return entry == extra end) end
    toggle("section preview")
    assert(not ExtraMatch())
    searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
    assert(not PressWindowKey("DOWN") and not PressWindowKey("DOWN"))
    assert(not PressWindowKey("RIGHT") and ExtraMatch(), "Right should expand the selected Show all results row")
    assert(not PressWindowKey("RIGHT") and ExtraMatch(), "Right again on the newly revealed row should keep navigation active")
    assert(not PressWindowKey("DOWN"))
    assert(not PressWindowKey("LEFT") and not ExtraMatch(), "Left should collapse the selected Show fewer results row")
    assert(not PressWindowKey("RIGHT") and ExtraMatch(), "The section should reopen without refocusing the window")
    toggle("section preview")
    local header = assert(Result(function(entry) return entry.sectionHeader and entry.name == "Other" end))
    local firstMatch = assert(Result(function(entry) return entry.name == "Other match" end))
    header:Click()
    assert(header.selection:IsShown() and header.selectionEdge:IsShown() and not GetCurrentKeyBoardFocus(),
        "Clicking a section header should move the highlight and leave the search box")
    assert(not PressWindowKey("DOWN") and firstMatch.selection:IsShown() and not header.selection:IsShown(),
        "Down should move from the clicked header into that section")
    addon.Search = search
end
toggle("@quest pie")
assert(GetCurrentKeyBoardFocus() == searchBox, "Opening search should focus the query input")
local quest = assert(Result(function(entry) return entry.kind == "quest" end))
quest.scripts.OnEnter(quest)
quest:Click()
assert(searchBox:GetText() == "@quest 86", "Clicking a quest should open its detail query")
assert(not GetCurrentKeyBoardFocus() and PressWindowKey("W"), "Opening quest details must release typing focus")
local nextQuests = assert(Result(function(entry) return entry.toggleSection == "Next quests" end))
nextQuests:Click()
assert(not Result(function(entry) return entry.id == 84 end), "A quest chain should collapse even with one link")
questProgress = "3/4"
window.scripts.OnEvent(window, "QUEST_LOG_UPDATE")
assert(Result(function(entry) return entry.matchLabel == "3/4" end), "Open quest details should refresh progress")
assert(not Result(function(entry) return entry.id == 84 end), "Progress updates should preserve collapsed chains")
nextQuests = assert(Result(function(entry) return entry.toggleSection == "Next quests" end))
assert(nextQuests.selection:IsShown(), "Inserting quest details should keep the chain toggle selected")
assert(not PressWindowKey("RIGHT"), "Right should expand the selected quest chain")
assert(Result(function(entry) return entry.id == 84 end))
searchBox:SetFocus()
local objectiveItem = assert(Result(function(entry) return entry.id == 769 end))
objectiveItem:Click()
assert(openedItem == "item:769", "Clicking an objective item should use the normal inspect action")
assert(not GetCurrentKeyBoardFocus() and objectiveItem.selection:IsShown() and window.keyboardEnabled,
    "Clicking an item should give the selected result keyboard navigation")
assert(not PressWindowKey("DOWN"), "Arrow navigation should continue from a clicked item")
local followUp = assert(Result(function(entry) return entry.kind == "quest" and entry.id == 84 end))
assert(nextQuests.selection:IsShown(), "Down should select the quest chain toggle")
assert(not PressWindowKey("DOWN") and followUp.selection:IsShown(), "Down should move into the open chain")
assert(not PressWindowKey("UP") and nextQuests.selection:IsShown(), "Up should return to the chain toggle")
assert(not PressWindowKey("UP") and objectiveItem.selection:IsShown(), "Up should return to the clicked row")
Result(function(entry) return entry.kind == "quest" and entry.id == 84 end):Click()
assert(searchBox:GetText() == "@quest 84", "Clicking a follow-up should open its quest details")
assert(not GetCurrentKeyBoardFocus() and PressWindowKey("W"), "Following a quest link must leave movement keys free")
assert(Result(function(entry) return entry.name == "Previous quest" end)):Click()
morePrerequisites = true
window.scripts.OnEvent(window, "QUEST_LOG_UPDATE")
assert(not Result(function(entry) return entry.id == 86 end),
    "A collapsed chain should stay collapsed when more prerequisites are found")
assert(Result(function(entry) return entry.name == "Previous quests" end)):Click()
Result(function(entry) return entry.kind == "quest" and entry.id == 86 end):Click()
assert(searchBox:GetText() == "@quest 86", "Clicking a prerequisite should open its quest details")

do
    local questSearch = addon.Search
    local finishNPC
    local loot = { kind = "text", name = "Indexed drop" }
    local sold = { kind = "text", name = "Vendor supply" }
    function addon.Search()
        return { loot }, nil, function(done) finishNPC = done end, nil, { title = "Loot", collapsible = true }
    end
    toggle("@npc 448")
    local lootHeader = assert(Result(function(entry) return entry.toggleSection == "Loot" end))
    assert(Result(function(entry) return entry == loot end), "NPC loot should start expanded")
    lootHeader:Click()
    assert(not Result(function(entry) return entry == loot end))
    local lastStock = { kind = "text", name = "Fourth vendor item" }
    finishNPC({ { kind = "text", name = "Known location" } }, nil, nil, nil, {
        title = "Locations", { title = "Loot", rows = { loot }, collapsible = true }, {
            title = "Sells", collapsible = true,
            rows = { sold, { kind = "text", name = "Second vendor item" },
                { kind = "text", name = "Third vendor item" }, lastStock },
        },
    })
    assert(not Result(function(entry) return entry == loot end), "NPC loading should preserve collapsed loot")
    lootHeader = assert(Result(function(entry) return entry.toggleSection == "Loot" end))
    assert(lootHeader.selection:IsShown(), "Inserting NPC details should keep the loot toggle selected")
    assert(Result(function(entry) return entry == sold end), "Newly loaded items should start expanded")
    assert(not Result(function(entry) return entry == lastStock end), "Open NPC sections should still preview long lists")
    assert(Result(function(entry) return entry.toggleSection == "Sells" and not entry.sectionHeader end)):Click()
    assert(Result(function(entry) return entry == lastStock end), "Show all should reveal the full stock list")
    local sellsHeader = assert(Result(function(entry) return entry.toggleSection == "Sells" and entry.sectionHeader end))
    sellsHeader:Click()
    assert(not Result(function(entry) return entry == sold end), "Vendor stock should collapse independently")
    sellsHeader:Click()
    assert(Result(function(entry) return entry == lastStock end), "Reopening stock should retain the full list selection")
    sellsHeader:Click()
    lootHeader:Click()
    assert(Result(function(entry) return entry == loot end), "Clicking the loot header should show its rows again")
    addon.Search = questSearch
end

toggle("@quest pie")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
assert(not PressWindowKey("ENTER"))
window.scripts.OnKeyUp(window, "ENTER")
assert(searchBox:GetText() == "@quest pie" and not GetCurrentKeyBoardFocus(),
    "Enter should open the selected quest's context menu before taking its default action")
local function IsPopupQueryHighlighted(query)
    for _, button in ipairs(buttons) do
        if button.query == query and button:IsShown() and button.parent:IsShown() and button.highlighted then return true end
    end
    return false
end
assert(IsPopupQueryHighlighted("@quest 86"), "Enter on a selected result should highlight the top menu choice")
assert(not PressWindowKey("LEFT"), "Left should return from the context menu to the results")
for _ = 1, 3 do
    assert(not PressWindowKey("LEFT") and window.keyboardEnabled, "Repeated Left should keep the results focused")
end
assert(not PressWindowKey("RIGHT"), "Right should reopen the selected result's context menu")
assert(IsPopupQueryHighlighted("@quest 86"), "Right should highlight the top choice on opening the menu")
ClickWindowArea(UIParent)
assert(PressWindowKey("DOWN"), "Clicking away should release keyboard navigation in the context menu")
ClickWindowArea(window)
assert(IsPopupQueryHighlighted("@quest 86"), "Refocusing should preserve the open context and its selection")
assert(not PressWindowKey("DOWN"), "Down should navigate the open context menu")
assert(not PressWindowKey("ENTER"))
window.scripts.OnKeyUp(window, "ENTER")
assert(searchBox:GetText() == "@quest 86" and GetCurrentKeyBoardFocus() == searchBox,
    "Keyboard activation should still allow keyboard navigation into the quest details")
toggle("@quest pie")
searchBox.scripts.OnArrowPressed(searchBox, "UP")
searchBox.scripts.OnArrowPressed(searchBox, "RIGHT")
assert(searchBox:GetText() == "@quest pie" and not GetCurrentKeyBoardFocus(),
    "Right should open the context menu directly from keyboard result selection")
assert(IsPopupQueryHighlighted("@quest 86"), "Right from the search box should highlight the top choice too")
assert(not PressWindowKey("LEFT"), "Left should close the menu and keep the current search")
toggle("@quest pie")
searchBox.scripts.OnArrowPressed(searchBox, "UP")
searchBox.scripts.OnEnterPressed(searchBox)
assert(IsPopupQueryHighlighted("@quest 86"), "Enter from the search box should highlight the top menu choice")
assert(not PressWindowKey("LEFT"), "Left should close the menu opened from the search box")
local objective = { kind = "text", name = "Collect 4 Chunks of Boar Meat", matchLabel = "1/4" }
function addon.Search() return { objective } end
toggle("objective")
local objectiveRow = assert(Result(function(entry) return entry == objective end))
tooltipLines = {}
objectiveRow.scripts.OnEnter(objectiveRow)
assert(#tooltipLines == 0, "An unclipped objective should not repeat its title on hover")
function objectiveRow.label:IsTruncated() return true end
objectiveRow.scripts.OnEnter(objectiveRow)
assert(#tooltipLines == 1 and tooltipLines[1] == objective.name, "Hover should reveal clipped objective text")
objectiveRow.label.IsTruncated = nil

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
assert(#tooltipLines == 1, "Hover should show a short hint in place of the item source list")
reward.scripts.OnClick(reward, "RightButton")
ClickQuery("@quest 87")
assert(searchBox:GetText() == "@quest 87", "A reward item should link to its quest")

toggle("boar meat")
tooltipLines = {}
ingredient.scripts.OnEnter(ingredient)
assert(#tooltipLines == 1 and tooltipLines[1] == "Right-click to open a quest.",
    "Quest requirements should be listed in the menu and stay out of the tooltip")
ItemRefTooltip = Widget()
function ItemRefTooltip:GetItem() return "Chunk of Boar Meat", "|Hitem:769|h[Chunk of Boar Meat]|h" end
function ItemRefTooltip:AddLine() error("The inspected item tooltip must use the game's own details") end
ingredient:Click()
assert(openedItem == "item:769", "Clicking an item must still open its native inspection tooltip")
ItemRefTooltip = nil
openedItem = nil
ingredient.scripts.OnClick(ingredient, "RightButton")
local matches = {}
for _, button in ipairs(buttons) do
    if button.query and button:IsShown() and button.parent:IsShown() then
        matches[button.query] = (matches[button.query] or 0) + 1
        if button.query == "@quest 86" then assert(button.label:GetText() == "Required and rewarded by: Pie for Billy") end
        if button.query == "@quest 87" then assert(button.label:GetText() == "Reward from: Reward Quest") end
        if button.query == "@quest 88" then assert(button.label:GetText() == "Required for: Another Pie Quest") end
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
local function VisiblePopupQuery(query)
    for _, button in ipairs(buttons) do
        if button.query == query and button:IsShown() and button.parent:IsShown() then return button end
    end
end
local firstQuest = assert(VisiblePopupQuery("@quest 78"))
local questPopup = firstQuest.parent
local function PopupScrollbar(popup)
    for _, slider in ipairs(sliders) do
        if slider.parent == popup then return slider end
    end
end
local questScrollbar = assert(PopupScrollbar(questPopup), "Long context menus must have a scrollbar")
assert(questScrollbar:IsShown() and questScrollbar.value == 1)
assert(questScrollbar.minimum == 1 and questScrollbar.maximum == 4, "The thumb range should match the hidden rows")
for _, button in ipairs(buttons) do
    if button.parent == questPopup and button:IsShown() then
        assert(button.query, "A quest menu should contain choices without pagination buttons")
    end
end
questPopup.scripts.OnMouseWheel(questPopup, -1)
assert(questScrollbar.value == 2 and not VisiblePopupQuery("@quest 78") and VisiblePopupQuery("@quest 86"),
    "The mouse wheel should advance the popup one row")
questScrollbar:SetValue(4)
assert(VisiblePopupQuery("@quest 88"), "Dragging the thumb to the end should expose the last choice")
questScrollbar.scripts.OnMouseWheel(questScrollbar, 1)
assert(questScrollbar.value == 3 and not VisiblePopupQuery("@quest 88"), "The wheel should work over the scrollbar")
ingredient.scripts.OnClick(ingredient, "RightButton")
ingredient.scripts.OnClick(ingredient, "RightButton")
assert(questScrollbar.value == 1 and VisiblePopupQuery("@quest 78"), "Reopening should reset the scroll position")
for _ = 1, 11 do assert(not PressWindowKey("DOWN")) end
assert(questScrollbar.value == 4 and VisiblePopupQuery("@quest 88"),
    "Keyboard navigation should scroll through the end of the menu")
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
FindButton("Open AddOn Settings", compact):Click()
assert(openedSettingsCategory == 123, "The popup should open the registered addon settings category")
assert(not compact:IsShown() and window:IsShown(), "Opening settings should close only the options popup")
optionsButton:Click()
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

local function PreferenceCheckbox(panel, label)
    for _, check in ipairs(checkboxes) do
        if check.parent == panel and check.label and check.label:GetText() == label then return check end
    end
end
local settingsRewards = assert(PreferenceCheckbox(addonOptions, "Quest reward links"))
assert(settingsRewards:GetChecked(), "Quest reward links should be on by default")
assert(not PreferenceCheckbox(compact, "Quest reward links"), "Quest reward links belong in AddOns settings")
local reloaded = {}
assert(loadfile("Search.lua"))("QuickItemSearch", reloaded)
for _, section in ipairs({ "Next quests", "Previous quests", "NPC Loot", "Vendor Items" }) do
    local check = assert(PreferenceCheckbox(addonOptions, section))
    assert(check:GetChecked() and not PreferenceCheckbox(compact, section),
        "Detail preferences should default to visible and appear only in AddOns settings")
    check:SetChecked(false)
    check:Click()
    assert(not reloaded.IsAutomaticSectionEnabled(section), "Detail preferences should use the saved section settings")
end

local compactNPCs = SectionCheckbox(compact, "NPCs and Mobs")
local settingsNPCs = SectionCheckbox(addonOptions, "NPCs and Mobs")
assert(compactNPCs:GetChecked() and settingsNPCs:GetChecked(), "NPC results should be automatic by default")
settingsNPCs:SetChecked(false)
settingsNPCs:Click()
assert(not compactNPCs:GetChecked() and not reloaded.IsAutomaticSectionEnabled("NPCs and Mobs"),
    "NPC visibility should sync across menus and persist across reloads")
do
    local search = addon.Search
    function addon.Search(query)
        if query ~= "@sources 1" then return search(query) end
        return { { kind = "npc", id = 10, name = "Merchant", matchLabel = "Vendor", vendorZone = "Elwynn Forest" } }
    end
    QuickItemSearchSettings.vendorZones = false
    toggle("@sources 1")
    local merchant = assert(Result(function(entry) return entry.name == "Merchant" end))
    assert(merchant.label:GetText() == "Merchant" and merchant.idLabel:GetText() == "Vendor · Elwynn Forest",
        "Show the vendor zone even when old settings disabled it")
    addon.Search = search
end

for _, label in ipairs({ "Nearest vendors first", "Vendor zones", "Result context menus", "Map pin actions" }) do
    assert(not PreferenceCheckbox(compact, label) and not PreferenceCheckbox(addonOptions, label),
        "Always-on behavior should not have a checkbox: " .. label)
end

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

settingsRewards:SetChecked(false)
settingsRewards:Click()
addon.GetItemQuestRequirements = function() return {} end
assert(loadfile("UI.lua"))("QuickItemSearch", addon)
addonOptions:Hide()
addonOptions:Show()
local reloadedRewards = assert(PreferenceCheckbox(addonOptions, "Quest reward links"))
assert(not reloadedRewards:GetChecked(), "Disabled quest reward links should persist after reload")
for _, section in ipairs({ "Next quests", "Previous quests", "NPC Loot", "Vendor Items" }) do
    assert(not assert(PreferenceCheckbox(addonOptions, section)):GetChecked(), "Detail visibility should persist after reload")
end
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

addon.index = { [3820] = "Stranglekelp" }
addon.recipes = { { 501, "Kelp Draught", "Alchemy", 75, false, { 3820 } } }
C_Item.IsItemDataCachedByID = function(id)
    assert(id == 3820, "Opening related recipes must keep spell IDs out of the item cache")
    return false
end
C_Spell = { GetSpellTexture = Noop }
assert(loadfile("RecipeSearch.lua"))("QuickItemSearch", addon)
assert(loadfile("Questions.lua"))("QuickItemSearch", addon)
function addon.Search(query)
    if query == "kelp" then return { { id = 3820, name = "Stranglekelp" } } end
    if query == "usedin 3820" then return addon.FindRecipesUsingItems({ { id = 3820 } }) end
    return {}
end
local reloadToggle = SlashCmdList.QUICKITEMSEARCH
reloadToggle("kelp")
local kelp = assert(Result(function(entry) return entry.id == 3820 end))
kelp.scripts.OnClick(kelp, "RightButton")
ClickQuery("usedin 3820")
assert(Result(function(entry) return entry.id == 501 end), "The reagent menu must open recipes despite old settings")

local placed
local mobSpawns = { [12] = { { 26.25, 87 }, { 32, 75 } }, [40] = { { 12, 30 } } }
for i = 1, 8 do mobSpawns[12][#mobSpawns[12] + 1] = { 32 + i, 75 } end
C_Map = {
    GetAreaInfo = function(id) return id == 12 and "Elwynn Forest" or "Westfall" end,
    CanSetUserWaypointOnMap = function(id) return id == 1429 end,
    SetUserWaypoint = function(point) placed = point; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(...) return { ... } end }
LibQuestieDB = {
    Support = { Get = function()
        return { private = { areaIdToUiMapId = "return { [12] = 1429, [40] = 0 }" } }
    end },
    Npc = { Get = function(id, field)
        if field == "name" then return "River Wolf" end
        if field == "spawns" then return mobSpawns end
    end },
    Quest = { Get = function(_, field)
        if field == "startedBy" then return { { 448 } } end
    end },
}
QuickItemSearchSettings.mapPinActions = false
function addon.Search(query)
    if query == "mob" then return { { kind = "npc", id = 448, name = "River Wolf" } } end
    if query == "quest" then return { { kind = "quest", id = 99, name = "Find the River Wolf" } } end
    if query == "gather" then return { { kind = "text", name = "Elwynn Forest", areaID = 12, matchLabel = "32.0, 75.0" } } end
    return {}
end
local function PopupChoice(label)
    for _, button in ipairs(buttons) do
        if button.label and button:IsShown() and button.parent:IsShown() and button.label:GetText() == label then
            return button
        end
    end
end
reloadToggle = SlashCmdList.QUICKITEMSEARCH
reloadToggle("mob")
local mob = assert(Result(function(entry) return entry.kind == "npc" end))
mob.scripts.OnClick(mob, "RightButton")
local pinAction = assert(PopupChoice("Add map pin"), "NPC results with coordinates must offer a map pin")
local pinScrollbar = assert(PopupScrollbar(pinAction.parent))
assert(not pinScrollbar:IsShown(), "A short context menu should hide the scrollbar")
pinAction:Click()
assert(not placed, "An NPC with several spawns needs a location selection")
assert(not PopupChoice("Westfall (12.0, 30.0)"), "Suppressed map IDs must be excluded from the picker")
assert(pinScrollbar:IsShown())
pinScrollbar:SetValue(pinScrollbar.maximum)
assert(PopupChoice("Elwynn Forest (40.0, 75.0)"), "The final map-pin location should be reachable by scrolling")
assert(PopupChoice("Back")):Click()
assert(PopupChoice("View NPC details") and not pinScrollbar:IsShown(), "Back should restore the short parent menu")
assert(PopupChoice("Add map pin")):Click()
assert(PopupChoice("Elwynn Forest (26.2, 87.0)")):Click()
assert(placed and placed[1] == 1429 and placed[2] == 0.2625 and placed[3] == 0.87,
    "The pin must use the mapped UI map ID and preserve unrounded coordinates")
assert(searchBox:GetText() == "mob", "Placing a pin must not replace the current search")
reloadToggle("quest")
local startQuest = assert(Result(function(entry) return entry.kind == "quest" and entry.id == 99 end))
startQuest.scripts.OnClick(startQuest, "RightButton")
assert(PopupChoice("Add map pin") and PopupChoice("Open quest"),
    "Old settings should not hide the quest's starter pin or other actions")
SlashCmdList.QUICKITEMSEARCH("gather")
local node = assert(Result(function(entry) return entry.kind == "text" and entry.areaID == 12 end))
node.scripts.OnClick(node, "RightButton")
assert(not PopupChoice("Add map pin"), "Gathering location rows must stay outside the pin menu")

local canvas = Widget()
canvas:SetSize(1000, 800)
WorldMapFrame = Widget()
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:SetMapID(id)
    self.mapID = id
    self:OnMapChanged()
end
function hooksecurefunc(object, method, after)
    local before = object[method]
    object[method] = function(self, ...)
        before(self, ...)
        after(self, ...)
    end
end
C_Map.SetUserWaypoint = function() return false end
local location = { kind = "text", name = "Elwynn Forest", areaID = 12, x = 32, y = 75, pinTargetName = "River Wolf" }
function addon.Search() return { location } end
SlashCmdList.QUICKITEMSEARCH("wolf coordinates")
local coordinateRow = assert(Result(function(entry) return entry == location end))
coordinateRow.scripts.OnClick(coordinateRow, "RightButton")
assert(PopupChoice("Add map pin")):Click()
local mapMarker = buttons[#buttons]
assert(WorldMapFrame:GetMapID() == 1429 and mapMarker.parent == canvas and mapMarker:IsShown(),
    "A rejected native waypoint must display a marker on the selected map")
WorldMapFrame:SetMapID(1436)
assert(not mapMarker:IsShown(), "A marker must not leak onto a different map")
WorldMapFrame:SetMapID(1429)
assert(mapMarker:IsShown(), "Returning to the pin's map must restore the marker")
mapMarker.scripts.OnClick(mapMarker, "RightButton")
assert(not mapMarker:IsShown(), "Right-click must remove the fallback map marker")

assert(loadfile("SpellSearch.lua"))("QuickItemSearch", addon)
LibQuestieDB.Quest.Get = function(_, field) if field == "name" then return "Find the River Wolf" end end
local spellUnlock = {
    kind = "spell", id = 501, name = "Kelp Draught", matchLabel = "Level 10 · Quest",
    unlockLevel = 10, unlockSource = "Quest", unlockQuests = { { level = 10, quests = { 99 } } },
}
function addon.Search() return { spellUnlock } end
SlashCmdList.QUICKITEMSEARCH("spell unlock")
local unlockRow = assert(Result(function(entry) return entry == spellUnlock end))
tooltipLines = {}
unlockRow.scripts.OnEnter(unlockRow)
assert(#tooltipLines == 1 and tooltipLines[1] == "Right-click for training details.",
    "Spell hover should leave the unlock breakdown to the context menu")
unlockRow.scripts.OnClick(unlockRow, "RightButton")
assert(PopupChoice("How to learn")):Click()
local learnQuest = PopupChoice("Open quest: Find the River Wolf\nMinimum level 10")
assert(learnQuest and learnQuest.query == "@quest 99", "The unlock submenu must keep requirements with the linked quest")
local liveWindow = QuickItemSearchFrame
assert(liveWindow.scripts.OnKeyDown)
liveWindow.scripts.OnKeyDown(liveWindow, "LEFT")
assert(not PopupChoice("Back") and not PopupChoice("How to learn"),
    "Left should close the entire context menu from a submenu")

print("Window sizing and search options passed")
