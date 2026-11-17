local function Noop() end

local resizeHandle
local buttons = {}
local searchBox
local methods = {}
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(shown) self.shown = shown end
function methods:SetSize(width, height) self.width, self.height = width, height end
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
function CreateFrame(kind, name)
    local frame = Widget()
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
local x, y = 100, 800
GetCursorPosition = function() return x, y end
QuickItemSearchSettings = {rows = 20}
local addon = {}
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
for _, button in ipairs(buttons) do
    if button.text and button.tooltipText then
        button.scripts.OnEnter(button)
        assert(GameTooltip:IsShown() and GameTooltip:GetText() == button.tooltipText)
        button.scripts.OnLeave(button)
        assert(not GameTooltip:IsShown(), "leaving an insert button must hide its tooltip")
        fieldCount = fieldCount + 1
    end
end
assert(fieldCount == 7, "all seven insert buttons must have hover help")
ClickQuery("linen cloth")
assert(lastQuery == "linen cloth", "clicking a query example must run it immediately")
ClickButton("History")
ClickQuery("linen cloth")
ClickButton("Examples")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnArrowPressed(searchBox, "DOWN")
searchBox.scripts.OnEnterPressed(searchBox)
assert(lastQuery == "@me chest", "keyboard selection must run the highlighted example")
ClickButton("Examples")
ClickQuery("train first aid 150")
assert(lastQuery == "train first aid 150", "the expanded examples must include trainer lookup")
searchBox:SetText("rare")
ClickButton("Examples")
ClickButton("Boss")
assert(searchBox:GetText() == 'rare boss:""' and searchBox.cursor == 11)
assert(lastQuery == "train first aid 150", "quick insertion must avoid explicitly running an unfinished query")
searchBox:SetText("chest")
ClickButton("Examples")
ClickButton("Me")
assert(searchBox:GetText() == "@me chest")
searchBox:SetText("brd")
ClickButton("Examples")
ClickButton("Dungeon")
assert(searchBox:GetText() == "@dungeon brd")
ClickButton("Examples")
ClickButton("Dungeon")
assert(searchBox:GetText() == "@dungeon brd", "clicking a shortcut twice must not duplicate it")
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
assert(QuickItemSearchSettings.history[2] == "train first aid 150")
assert(QuickItemSearchSettings.history[3] == "@me chest" and #QuickItemSearchSettings.history == 3)
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
print("Window sizing regression passed")
