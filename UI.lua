local addonName, addon = ...
local settingsKey = addonName .. "Settings"
local VISIBLE_ROWS = 8
local ROW_HEIGHT = 30
local WIDTH = 560
local SCROLLBAR_WIDTH = 12
local QUESTION_MARK = 134400
local COLORS = {
    panel = { 0.073, 0.066, 0.057, 0.98 },
    border = { 0.38, 0.30, 0.19, 1 },
    inset = { 0.12, 0.106, 0.086, 1 },
    trim = { 0.25, 0.20, 0.135, 1 },
    iconBorder = { 0.045, 0.040, 0.033, 1 },
    selection = { 0.22, 0.163, 0.083, 1 },
    accent = { 0.86, 0.66, 0.35, 1 },
    hover = { 0.84, 0.67, 0.43, 0.11 },
    text = { 0.95, 0.91, 0.83 },
    mutedText = { 0.71, 0.66, 0.57 },
}
local frame, searchBox, answer, message, range, scrollbar
local rows, results = {}, {}
local searchHint
local selected = 1
local firstVisible = 1
local syncingScrollbar
local debounce
local cancelStatSearch
local pending
local hoveredRow
local hoverAwaitingData
local hoverRefresh
local moving

local function ReadItem(id)
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
    return name, link, quality, icon
end

local function UpdateRow(row)
    local entry = row.entry
    local name, _, quality, icon
    local detail = entry.matchLabel or entry.id
    if entry.kind == "spell" then
        icon = C_Spell.GetSpellTexture(entry.id)
        local rank = C_Spell.GetSpellSubtext(entry.id)
        detail = rank and rank ~= "" and rank or ("Spell %d"):format(entry.id)
    else
        if C_Item.IsItemDataCachedByID(entry.id) then
            name, _, quality, icon = ReadItem(entry.id)
        end
        if not icon then
            local _, _, _, _, instantIcon = C_Item.GetItemInfoInstant(entry.id)
            icon = instantIcon
        end
    end
    row.icon:SetTexture(icon or QUESTION_MARK)
    local label = name or entry.name or ("Item " .. entry.id)
    row.label:SetText((label:gsub("|", "||")))
    row.idLabel:SetText(detail)
    quality = quality or entry.quality
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if color then
        row.label:SetTextColor(color.r, color.g, color.b)
    else
        row.label:SetTextColor(unpack(COLORS.text))
    end
end

local function SetRowSelected(row, isSelected)
    row.selection:SetShown(isSelected)
    row.selectionEdge:SetShown(isSelected)
end

local function RenderResults()
    local answerHeight = answer:IsShown() and answer:GetStringHeight() + 8 or 0
    local canScroll = #results > VISIBLE_ROWS
    for index, row in ipairs(rows) do
        local resultIndex = firstVisible + index - 1
        row.entry = results[resultIndex]
        row.resultIndex = resultIndex
        SetRowSelected(row, row.entry ~= nil and resultIndex == selected)
        if row.entry then
            row:SetPoint("TOPLEFT", 8, -55 - answerHeight - (index - 1) * ROW_HEIGHT)
            row:SetWidth(WIDTH - 16 - (canScroll and SCROLLBAR_WIDTH or 0))
            UpdateRow(row)
            row:Show()
        else
            row:Hide()
        end
    end

    local visible = math.min(VISIBLE_ROWS, math.max(0, #results - firstVisible + 1))
    frame:SetHeight(101 + answerHeight + visible * ROW_HEIGHT)
    if visible > 0 then
        range:SetFormattedText("%d-%d of %d", firstVisible, firstVisible + visible - 1, #results)
    else
        range:SetText("")
    end

    scrollbar:SetShown(canScroll)
    if canScroll then
        local height = VISIBLE_ROWS * ROW_HEIGHT
        scrollbar:SetPoint("TOPRIGHT", -8, -55 - answerHeight)
        scrollbar:GetThumbTexture():SetHeight(math.max(16, height * VISIBLE_ROWS / #results))
        syncingScrollbar = true
        scrollbar:SetMinMaxValues(1, #results - VISIBLE_ROWS + 1)
        scrollbar:SetValue(firstVisible)
        syncingScrollbar = false
    end
end

local function ShowHover(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.kind == "spell" then
        local shown = pcall(GameTooltip.SetSpellByID, GameTooltip, entry.id, false, true)
        if not shown or GameTooltip:NumLines() == 0 then
            GameTooltip:AddLine((entry.name:gsub("|", "||")))
            GameTooltip:AddLine(("Spell %d"):format(entry.id), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
        return
    end
    local shown = pcall(GameTooltip.SetItemByID, GameTooltip, entry.id)
    if not shown or GameTooltip:NumLines() == 0 then
        local label = entry.name or ("Item " .. entry.id)
        GameTooltip:AddLine((label:gsub("|", "||")))
        GameTooltip:AddLine("Click to request item details.", 0.8, 0.8, 0.8, true)
    end
    addon.AppendItemSources(GameTooltip, entry.id)
    GameTooltip:Show()
end

local function HideHover()
    local row = hoveredRow
    hoveredRow, hoverAwaitingData = nil, false
    if hoverRefresh then
        hoverRefresh:Cancel()
        hoverRefresh = nil
    end
    if row and GameTooltip:IsOwned(row) then
        GameTooltip:Hide()
    end
end

local function QueueHoverRefresh(row, id)
    if hoveredRow ~= row or not hoverAwaitingData or not C_Item.IsItemDataCachedByID(id) then return end
    -- Native tooltip hooks can deliver item events synchronously during SetItemByID.
    -- Consume the pending refresh before deferring it so a rebuild cannot queue itself.
    hoverAwaitingData = false
    local entry = row.entry
    local refresh
    refresh = C_Timer.NewTimer(0, function()
        if hoverRefresh ~= refresh then return end
        hoverRefresh = nil
        if frame:IsShown() and hoveredRow == row and row.entry == entry and GameTooltip:IsOwned(row) then
            ShowHover(row)
        end
    end)
    hoverRefresh = refresh
end

local function ClearPending()
    if pending then
        pending.timer:Cancel()
        pending = nil
    end
end

local function CancelStatSearch()
    if cancelStatSearch then
        cancelStatSearch()
        cancelStatSearch = nil
    end
end

local function ShowResults(matches, hint, answerText)
    results = matches
    selected, firstVisible = 1, 1
    answer:SetText(answerText or "")
    answer:SetShown(answerText ~= nil)
    searchHint = hint or (not answerText and #results == 0 and "No items found." or "")
    message:SetText(searchHint)
    RenderResults()
end

local function SearchNow()
    if debounce then
        debounce:Cancel()
        debounce = nil
    end
    CancelStatSearch()
    HideHover()
    ClearPending()
    local matches, hint, loadStats, answerText = addon.Search(searchBox:GetText())
    ShowResults(matches, hint, answerText)
    if loadStats then
        cancelStatSearch = loadStats(function(loadedMatches, loadedHint)
            cancelStatSearch = nil
            ShowResults(loadedMatches, loadedHint)
        end)
    end
end

local function OpenItem(link, action)
    message:SetText(searchHint)
    if action == "chat" then
        if not ChatEdit_InsertLink(link) then
            message:SetText("Open chat, then Shift-click the item to insert its link.")
        end
    elseif action == "preview" then
        DressUpItemLink(link)
    else
        local itemString = link:match("|H([^|]+)|h")
        if itemString then
            SetItemRef(itemString, link, "LeftButton")
            if ItemRefTooltip and ItemRefTooltip:IsShown() then
                local _, shownLink = ItemRefTooltip:GetItem()
                local itemID = tonumber(itemString:match("^item:(%d+)"))
                if shownLink and tonumber(shownLink:match("|Hitem:(%d+)")) == itemID then
                    addon.AppendItemSources(ItemRefTooltip, itemID)
                    ItemRefTooltip:Show()
                end
            end
        end
    end
end

local function SelectResult(row)
    local entry = row.entry
    local id = entry.id
    ClearPending()
    if entry.kind == "spell" then
        local link = C_Spell.GetSpellLink(id)
        if not link then
            message:SetText("Spell details are unavailable.")
        elseif IsModifiedClick("CHATLINK") then
            if not ChatEdit_InsertLink(link) then
                message:SetText("Open chat, then Shift-click the spell to insert its link.")
            end
        else
            message:SetText(searchHint)
            SetItemRef("spell:" .. id, link, "LeftButton")
        end
        return
    end
    local action = IsModifiedClick("CHATLINK") and "chat"
        or IsModifiedClick("DRESSUP") and "preview"
        or "inspect"
    if C_Item.IsItemDataCachedByID(id) then
        local _, link = ReadItem(id)
        if link then
            OpenItem(link, action)
            return
        end
    end

    local request = { id = id, action = action }
    request.timer = C_Timer.NewTimer(5, function()
        if pending == request then
            pending = nil
            message:SetFormattedText("Item %d details are unavailable. Click the item to retry.", id)
        end
    end)
    pending = request
    message:SetFormattedText("Loading item %d...", id)
    if not pcall(C_Item.RequestLoadItemDataByID, id) and pending == request then
        ClearPending()
        message:SetFormattedText("Item %d details are unavailable.", id)
    end
end

local function OnItemData(_, event, id, success)
    if not frame:IsShown() then return end
    for _, row in ipairs(rows) do
        if row.entry and row.entry.kind ~= "spell" and row.entry.id == id then
            if success then
                UpdateRow(row)
                QueueHoverRefresh(row, id)
            end
            break
        end
    end

    if pending and pending.id == id then
        local _, link
        if C_Item.IsItemDataCachedByID(id) then
            _, link = ReadItem(id)
        end
        if link then
            local action = pending.action
            ClearPending()
            OpenItem(link, action)
        elseif not success and event == "ITEM_DATA_LOAD_RESULT" then
            ClearPending()
            message:SetFormattedText("Item %d details are unavailable. Click the item to retry.", id)
        end
    end
end

local function RefreshNavigation()
    HideHover()
    ClearPending()
    message:SetText(searchHint)
    RenderResults()
end

local function MoveSelection(delta)
    if #results == 0 then return end
    local nextSelection = math.max(1, math.min(#results, selected + delta))
    if nextSelection == selected then return end
    selected = nextSelection
    if selected < firstVisible then
        firstVisible = selected
    elseif selected >= firstVisible + VISIBLE_ROWS then
        firstVisible = selected - VISIBLE_ROWS + 1
    end
    RefreshNavigation()
end

local function ScrollTo(first)
    local lastStart = math.max(1, #results - VISIBLE_ROWS + 1)
    local nextStart = math.max(1, math.min(lastStart, first))
    if nextStart == firstVisible then return end
    firstVisible = nextStart
    selected = math.max(firstVisible, math.min(selected, firstVisible + VISIBLE_ROWS - 1))
    RefreshNavigation()
end

local function OnMouseWheel(_, direction)
    if direction == 0 then return end
    if debounce then SearchNow() end
    ScrollTo(firstVisible + (direction > 0 and -1 or 1))
end

local function StopMovingWindow()
    if not moving then return end
    moving = false
    frame:StopMovingOrSizing()
    local x, top = frame:GetCenter(), frame:GetTop()
    local parentX, parentTop = UIParent:GetCenter(), UIParent:GetTop()
    if not (x and top and parentX and parentTop) then return end

    local settings = _G[settingsKey]
    settings.x, settings.y = x - parentX, top - parentTop
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", settings.x, settings.y)
end

local function CreateWindow()
    local settings = _G[settingsKey]
    if type(settings) ~= "table" then
        settings = {}
        _G[settingsKey] = settings
    end
    frame = CreateFrame("Frame", "QuickItemSearchFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 101)
    frame:SetPoint("TOP", UIParent, "TOP", tonumber(settings.x) or 0, tonumber(settings.y) or -130)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(COLORS.panel))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:SetScript("OnMouseWheel", OnMouseWheel)
    tinsert(UISpecialFrames, frame:GetName())

    local header = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    header:SetColorTexture(unpack(COLORS.inset))
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(52)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(COLORS.trim))
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 8, -53)
    divider:SetPoint("TOPRIGHT", -8, -53)

    searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetSize(WIDTH - 48, 34)
    searchBox:SetPoint("TOPLEFT", 24, -13)
    searchBox:SetFontObject("GameFontHighlightLarge")
    searchBox:SetTextColor(unpack(COLORS.text))
    searchBox:SetAltArrowKeyMode(false)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxBytes(512)
    searchBox.Instructions:SetText("Search items, gear, bosses, or ask a question")
    searchBox.Instructions:SetTextColor(unpack(COLORS.mutedText))
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local piece = searchBox[key]
        if piece then piece:SetVertexColor(0.77, 0.69, 0.54) end
    end
    searchBox:HookScript("OnTextChanged", function()
        CancelStatSearch()
        if debounce then debounce:Cancel() end
        debounce = C_Timer.NewTimer(0.15, SearchNow)
    end)
    searchBox:SetScript("OnArrowPressed", function(_, key)
        if debounce then SearchNow() end
        if key == "UP" then
            MoveSelection(-1)
        elseif key == "DOWN" then
            MoveSelection(1)
        end
    end)
    searchBox:SetScript("OnEnterPressed", function()
        searchBox:ClearFocus()
        if debounce then SearchNow() end
        if results[selected] then
            SelectResult(rows[selected - firstVisible + 1])
        end
    end)
    searchBox:SetScript("OnEscapePressed", function() frame:Hide() end)

    answer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    answer:SetPoint("TOPLEFT", 14, -55)
    answer:SetWidth(WIDTH - 28)
    answer:SetJustifyH("LEFT")
    answer:SetWordWrap(true)
    answer:SetTextColor(unpack(COLORS.accent))
    answer:Hide()

    for index = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(WIDTH - 16, ROW_HEIGHT)
        row.selection = row:CreateTexture(nil, "BACKGROUND")
        row.selection:SetAllPoints()
        row.selection:SetColorTexture(unpack(COLORS.selection))
        row.selectionEdge = row:CreateTexture(nil, "ARTWORK")
        row.selectionEdge:SetPoint("TOPLEFT", 0, -2)
        row.selectionEdge:SetPoint("BOTTOMLEFT", 0, 2)
        row.selectionEdge:SetWidth(2)
        row.selectionEdge:SetColorTexture(unpack(COLORS.accent))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(COLORS.hover))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local iconBorder = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
        iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
        iconBorder:SetColorTexture(unpack(COLORS.iconBorder))
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetPoint("RIGHT", -112, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.idLabel:SetPoint("RIGHT", -10, 0)
        row.idLabel:SetTextColor(unpack(COLORS.mutedText))
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            HideHover()
            hoveredRow = self
            hoverAwaitingData = self.entry.kind ~= "spell" and not C_Item.IsItemDataCachedByID(self.entry.id)
            ShowHover(self)
        end)
        row:SetScript("OnLeave", function(self)
            if hoveredRow == self then HideHover() end
        end)
        row:SetScript("OnClick", function(self)
            selected = self.resultIndex
            for _, visible in ipairs(rows) do
                SetRowSelected(visible, visible == self)
            end
            SelectResult(self)
        end)
        rows[index] = row
    end

    message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    message:SetPoint("BOTTOMLEFT", 14, 30)
    message:SetTextColor(unpack(COLORS.text))
    range = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    range:SetPoint("BOTTOMLEFT", 14, 12)
    range:SetTextColor(unpack(COLORS.mutedText))
    local keyboardHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keyboardHint:SetPoint("BOTTOMRIGHT", -14, 12)
    keyboardHint:SetText("Up / Down   Navigate     Enter   Inspect     Esc   Close")
    keyboardHint:SetTextColor(unpack(COLORS.mutedText))
    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT", 8, -1)
    dragHandle:SetPoint("TOPRIGHT", -8, -1)
    dragHandle:SetHeight(12)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        HideHover()
        frame:StartMoving()
        frame:SetUserPlaced(false)
        moving = true
    end)
    dragHandle:SetScript("OnDragStop", StopMovingWindow)

    local grip = dragHandle:CreateTexture(nil, "ARTWORK")
    grip:SetSize(28, 2)
    grip:SetPoint("CENTER")
    grip:SetColorTexture(unpack(COLORS.accent))

    scrollbar = CreateFrame("Slider", nil, frame)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(SCROLLBAR_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
    scrollbar:SetValueStep(1)
    scrollbar:SetObeyStepOnDrag(true)
    scrollbar:SetStepsPerPage(VISIBLE_ROWS)
    scrollbar:EnableMouse(true)
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", OnMouseWheel)
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(4)
    track:SetColorTexture(unpack(COLORS.trim))
    local thumb = scrollbar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(7, 16)
    thumb:SetColorTexture(unpack(COLORS.accent))
    scrollbar:SetThumbTexture(thumb)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if not syncingScrollbar then ScrollTo(math.floor(value + 0.5)) end
    end)
    scrollbar:Hide()

    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", OnItemData)
    frame:SetScript("OnHide", function()
        CancelStatSearch()
        StopMovingWindow()
        searchBox:ClearFocus()
        HideHover()
        ClearPending()
        if debounce then
            debounce:Cancel()
            debounce = nil
        end
    end)
end

local function Toggle(query)
    if not frame then
        CreateWindow()
    elseif frame:IsShown() and (not query or query == "") then
        frame:Hide()
        return
    end
    frame:Show()
    searchBox:SetText(query or "")
    SearchNow()
    searchBox:SetFocus()
    searchBox:HighlightText()
end

function QuickItemSearch_Toggle()
    Toggle()
end

SLASH_QUICKITEMSEARCH1 = "/qis"
SLASH_QUICKITEMSEARCH2 = "/itemsearch"
SlashCmdList.QUICKITEMSEARCH = Toggle

BINDING_NAME_QUICKITEMSEARCH_TOGGLE = "Open Item Search"
local bindingOwner = CreateFrame("Frame")
local bindingCommand = "QUICKITEMSEARCH_TOGGLE"
local defaultKey = "CTRL-SHIFT-SPACE"
local updatingBinding = false

local function UpdateBinding()
    if updatingBinding or InCombatLockdown() then return end
    updatingBinding = true
    ClearOverrideBindings(bindingOwner)
    local action = GetBindingAction(defaultKey, true)
    if not GetBindingKey(bindingCommand) and (not action or action == "") then
        SetOverrideBinding(bindingOwner, false, defaultKey, bindingCommand)
    end
    updatingBinding = false
end

bindingOwner:RegisterEvent("PLAYER_LOGIN")
bindingOwner:RegisterEvent("UPDATE_BINDINGS")
bindingOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
bindingOwner:SetScript("OnEvent", UpdateBinding)

local MODIFIERS = {
    LALT = true, RALT = true, LCTRL = true, RCTRL = true,
    LSHIFT = true, RSHIFT = true, LMETA = true, RMETA = true,
}

local function CreateLevelOptions(panel, anchor)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -26)
    title:SetText("Single-level gear search")

    local function OffsetField(text, previous)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -16)
        label:SetText(text)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetPoint("LEFT", label, "LEFT", 130, 0)
        input:SetSize(48, 24)
        input:SetAutoFocus(false)
        input:SetNumeric(true)
        input:SetMaxLetters(2)
        return input, label
    end

    local below, belowLabel = OffsetField("Levels below", title)
    local above, aboveLabel = OffsetField("Levels above", belowLabel)
    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetPoint("TOPLEFT", aboveLabel, "BOTTOMLEFT", 0, -16)
    save:SetSize(110, 24)
    save:SetText("Save Range")
    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("LEFT", save, "RIGHT", 8, 0)

    local function Save()
        if addon.SetLevelWindow(tonumber(below:GetText()), tonumber(above:GetText())) then
            below:ClearFocus()
            above:ClearFocus()
            status:SetText("Level range saved.")
        else
            status:SetText("Enter a number from 0 to 99 in both fields.")
        end
    end
    save:SetScript("OnClick", Save)
    below:SetScript("OnEnterPressed", Save)
    above:SetScript("OnEnterPressed", Save)

    panel:HookScript("OnShow", function()
        local savedBelow, savedAbove = addon.GetLevelWindow()
        below:SetText(tostring(savedBelow))
        above:SetText(tostring(savedAbove))
        status:SetText("")
    end)
end

local function CreateOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local title = "Quick Item Search"
    local panel = CreateFrame("Frame")
    panel:Hide()

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(title)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -28)
    label:SetText("Open Item Search")

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetPoint("LEFT", label, "RIGHT", 20, 0)
    button:SetSize(180, 26)

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -18)
    local capturing, pendingKey, pendingBinding

    local function Refresh()
        if capturing then return end
        local key = GetBindingKey(bindingCommand)
        if not key and GetBindingAction(defaultKey, true) == bindingCommand then key = defaultKey end
        button:SetText(key and GetBindingText(key, "KEY_") or "Not Bound")
    end

    local function Finish(message)
        capturing, pendingKey, pendingBinding = false, nil, nil
        button:EnableKeyboard(false)
        status:SetText(message or "")
        Refresh()
    end

    button:SetScript("OnClick", function()
        if InCombatLockdown() then
            Finish("You can change the hotkey after combat.")
        elseif capturing then
            Finish()
        else
            capturing = true
            button:EnableKeyboard(true)
            button:SetPropagateKeyboardInput(false)
            button:SetText("Press a key...")
            status:SetText("Press Esc to cancel.")
        end
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if not capturing then return end
        if key == "ESCAPE" then Finish() return end
        if pendingKey or MODIFIERS[key] then return end

        pendingKey = key
        pendingBinding = (IsAltKeyDown() and "ALT-" or "")
            .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    end)
    button:SetScript("OnKeyUp", function(_, key)
        if not capturing or key ~= pendingKey then return end
        if InCombatLockdown() then Finish("You can change the hotkey after combat.") return end

        local combo = pendingBinding
        local action = GetBindingAction(combo, true)
        if action and action ~= "" and action ~= bindingCommand then
            Finish(GetBindingText(combo, "KEY_") .. " is already assigned.")
            return
        end

        local previous = GetBindingKey(bindingCommand)
        local wasBound = GetBindingAction(combo) == bindingCommand
        if not wasBound and not SetBinding(combo, bindingCommand) then
            Finish("Could not assign that hotkey.")
            return
        end
        if previous and previous ~= combo and not SetBinding(previous) then
            if not wasBound then SetBinding(combo) end
            Finish("Could not replace the previous hotkey.")
            return
        end
        SaveBindings(GetCurrentBindingSet())
        UpdateBinding()
        Finish("Hotkey saved.")
    end)
    button:EnableKeyboard(false)

    panel:SetScript("OnShow", Refresh)
    panel:SetScript("OnHide", function() Finish() end)
    panel:RegisterEvent("UPDATE_BINDINGS")
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" and capturing then
            Finish("You can change the hotkey after combat.")
        else
            Refresh()
        end
    end)
    if addon.GetLevelWindow then CreateLevelOptions(panel, status) end
    local category = Settings.RegisterCanvasLayoutCategory(panel, title)
    Settings.RegisterAddOnCategory(category)
end

CreateOptions()
