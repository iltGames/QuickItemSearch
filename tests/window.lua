local function Noop() end

local resizeHandle
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
    if kind == "Button" then resizeHandle = frame end
    if kind == "EditBox" then
        frame.Instructions, frame.Left, frame.Middle, frame.Right = Widget(), Widget(), Widget(), Widget()
    end
    return frame
end

UIParent = Widget()
UIParent:SetSize(1200, 900)
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert
InCombatLockdown = function() return false end
local x, y = 100, 800
GetCursorPosition = function() return x, y end
QuickItemSearchSettings = {rows = 20}
local addon = {}
function addon.Search(query)
    local results = {}
    for i = 1, tonumber(query) or 0 do
        results[i] = {kind = "text", name = "Result " .. i}
    end
    return results, query == "" and "Search hint" or nil
end

assert(loadfile("UI.lua"))("QuickItemSearch", addon)
local toggle = SlashCmdList.QUICKITEMSEARCH
local function ExpectHeight(expected, context)
    local height = QuickItemSearchFrame:GetHeight()
    assert(height == expected, context .. ": expected " .. expected .. ", got " .. height)
end

toggle()
ExpectHeight(101, "open with saved cap and empty query")
toggle("2")
ExpectHeight(143, "two matches")
toggle("50")
ExpectHeight(683, "fifty matches at twenty-row cap")
toggle()
toggle()
ExpectHeight(101, "reopen after fifty matches")

resizeHandle.scripts.OnDragStart()
x = x + 50
resizeHandle.scripts.OnUpdate()
resizeHandle.scripts.OnDragStop()
assert(QuickItemSearchSettings.rows == 20, "width-only drag must retain the cap")
ExpectHeight(101, "width-only drag with empty query")

resizeHandle.scripts.OnDragStart()
y = y - 360
resizeHandle.scripts.OnUpdate()
ExpectHeight(461, "preview twelve rows while dragging")
resizeHandle.scripts.OnDragStop()
ExpectHeight(101, "empty query after releasing resize handle")
assert(QuickItemSearchSettings.rows == 12, "vertical drag must save the new cap")
toggle("50")
ExpectHeight(443, "fifty matches at twelve-row cap")
print("Window sizing regression passed")
