local addonName, addon = ...
local settingsKey = addonName .. "Settings"
local DEFAULT_ROWS, MIN_ROWS, MAX_ROWS = 8, 3, 20
local SECTION_PREVIEW_ROWS = 3
local ROW_HEIGHT = 30
local RESULTS_TOP = 55
local FOOTER_HEIGHT = 28
local DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH = 560, 430, 1100
local SCROLLBAR_WIDTH = 12
local QUESTION_MARK = 134400
local ARROW_HOLD_DELAY = 0.32
local ARROW_REPEAT_START = 0.16
local ARROW_REPEAT_MIN = 0.045
local ARROW_REPEAT_ACCELERATION = 0.84
local ARROW_DIRECTION = { UP = -1, DOWN = 1 }
local HISTORY_LIMITS = { 0, 5, 10, 20, 50 }
local DEFAULT_HISTORY_LIMIT = 10
local HISTORY_PAGE_SIZE = 10
local RESULT_MENU_VISIBLE_ROWS = 8
local MAX_QUERY_BYTES = 512
local queryExamples = {
    "@me shield upgrade no sp",
    "rings lvl 30-40 with agility near 10",
    'rare boss:"Edwin VanCleef" with stamina',
    "crafted leather gloves lvl 40 with agility",
}
local queryShortcuts = {
    { "Target", "@target", "Show your target's drops." },
    { "Me", "@me", "Find gear for your character." },
    { "Dungeon", "@dungeon", "Find loot by dungeon name." },
}
local queryFields = {
    { "Level", "lvl ", "Add a character level or range." },
    { "Boss", 'boss:""', "Filter drops by boss name.", 1 },
    { "Stat", "with ", "Add a stat, such as agility." },
    { "Crafted", "crafted", "Show only crafted gear." },
    { "Upgrade", "upgrade", "Show gear with a higher item level than your equipped item." },
}
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
local frame, searchBox, summary, message, range, scrollbar
local queryPopup, history
local backButton
local backQueries = {}
-- Live previews can change while typing without adding a Back step.
local navigationQuery = ""
local keyboardHint, resizeHandle
local visibleRows = DEFAULT_ROWS
local resizing, resizePreviewRows
local arrowSelected, resultKeyboardActive, heldResultEnter
local heldArrow, arrowTimer
local SEARCH_KEYS = "Up / Down   Navigate     Enter   Release Focus     Esc   Close"
local RESULT_KEYS = "Up / Down   Browse    Enter / Right   Actions    Esc   Close"
local MENU_KEYS = "Up / Down   Navigate     Enter   Choose     Left / Esc   Back"
local EnableResultKeyboard
local rows, results = {}, {}
local primaryResults, resultSections
local expandedSections
local collapsedDetailSections
local selected = 1
local firstVisible = 1
local syncingScrollbar
local debounce
local settingSearchText
local lastSearchText
local cancelStatSearch
local pending
local hoveredRow
local hoverAwaitingData
local hoverRefresh
local moving
local compactOptions, refreshCompactOptions, refreshAddOnOptions
local addOnSettingsCategory

local function GetSettings()
    local settings = _G[settingsKey]
    if type(settings) ~= "table" then
        settings = {}
        _G[settingsKey] = settings
    end
    return settings
end

local function QuestRewardLinksEnabled()
    return GetSettings().questRewardLinks ~= false
end

local function CanGoBack()
    return #backQueries > 0
        or (navigationQuery ~= (searchBox:GetText() or "") and navigationQuery:find("%S") ~= nil)
end

local function UpdateBackButton()
    if not backButton then return end
    backButton:SetEnabled(CanGoBack())
end

local function TrackSearchQuery(query)
    if query == navigationQuery then return end
    if navigationQuery:find("%S") then
        backQueries[#backQueries + 1] = navigationQuery
    elseif backQueries[#backQueries] == query then
        table.remove(backQueries)
    end
    navigationQuery = query
end

local function CommitTypedQuery()
    TrackSearchQuery(searchBox:GetText() or "")
    UpdateBackButton()
end

local function GetHistoryLimit()
    local limit = GetSettings().historyLimit
    for _, allowed in ipairs(HISTORY_LIMITS) do
        if limit == allowed then return limit end
    end
    return DEFAULT_HISTORY_LIMIT
end

local function GetHistory(settings)
    if type(settings.history) ~= "table" then settings.history = {} end
    return settings.history
end

local function TrimHistory(entries, limit)
    for index = #entries, limit + 1, -1 do entries[index] = nil end
end

local function RememberQuery(query)
    local limit = GetHistoryLimit()
    if limit == 0 then return end
    query = query:match("^%s*(.-)%s*$")
    if query == "" then return end
    for index, previous in ipairs(history) do
        if previous == query then
            table.remove(history, index)
            break
        end
    end
    table.insert(history, 1, query)
    TrimHistory(history, limit)
end

local function ReadItem(id)
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
    return name, link, quality, icon
end

local function FormatSkillThresholds(profession, thresholds)
    return ("%s |cffff9933%s|r / |cffffff00%d|r / |cff40c060%d|r / |cffaaaaaa%d|r"):format(
        profession, thresholds[1] or "?", thresholds[2], thresholds[3], thresholds[4])
end

local function ItemRecipes(id)
    if addon.GetItemRecipes then return addon.GetItemRecipes(id) end
end

local function UpdateRow(row)
    local entry = row.entry
    local name, _, quality, icon
    local detail = entry.matchLabel or entry.id
    if entry.gatheringThresholds then
        detail = FormatSkillThresholds(entry.gatheringProfession, entry.gatheringThresholds)
    elseif entry.skillThresholds then
        detail = FormatSkillThresholds(entry.profession, entry.skillThresholds)
    elseif entry.vendorZone then
        detail = detail .. " · " .. entry.vendorZone:gsub("|", "||")
    elseif not entry.kind then
        local recipes = ItemRecipes(entry.id)
        if recipes and #recipes == 1 and recipes[1].skillThresholds then
            local recipe = recipes[1]
            local skills = FormatSkillThresholds(recipe.profession, recipe.skillThresholds)
            detail = entry.matchLabel and (entry.matchLabel .. "  ·  " .. skills) or skills
        elseif recipes and #recipes > 1 then
            local count = ("%d recipes"):format(#recipes)
            detail = entry.matchLabel and (entry.matchLabel .. "  ·  " .. count) or count
        end
    end
    if entry.kind == "text" then
        icon = entry.tameSources and "Interface\\Icons\\Ability_Hunter_BeastTaming"
            or "Interface\\Icons\\INV_Scroll_03"
    elseif entry.kind == "emote" then
        icon = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"
    elseif entry.kind == "quest" then
        icon = "Interface\\GossipFrame\\AvailableQuestIcon"
    elseif entry.kind == "dungeon" or entry.kind == "npc" or entry.kind == "object" then
        icon = "Interface\\Icons\\INV_Misc_Map_01"
    elseif entry.kind == "spell" then
        icon = C_Spell.GetSpellTexture(entry.id)
        if not entry.matchLabel then
            local rank = C_Spell.GetSpellSubtext(entry.id)
            detail = rank and rank ~= "" and rank or ("Spell %d"):format(entry.id)
        end
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
    local showIcon = not (entry.sectionHeader or entry.toggleSection)
    row.icon:SetShown(showIcon)
    row.iconBorder:SetShown(showIcon)
    local label = entry.nodeName or name or entry.name or ("Item " .. entry.id)
    row.label:SetText((label:gsub("|", "||")))
    row.idLabel:SetText(detail)
    quality = quality or entry.quality
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if not showIcon then
        row.label:SetTextColor(unpack(COLORS.accent))
    elseif color then
        row.label:SetTextColor(color.r, color.g, color.b)
    else
        row.label:SetTextColor(unpack(COLORS.text))
    end
end

local function SetRowSelected(row, isSelected)
    row.selection:SetShown(isSelected)
    row.selectionEdge:SetShown(isSelected)
end

local function ResultsTop()
    return RESULTS_TOP + (summary:IsShown() and summary:GetStringHeight() + 6 or 0)
end

local function ResizePanel()
    local actionHeight = message:IsShown() and 18 or 0
    local heightRows = resizePreviewRows or math.min(visibleRows, #results)
    frame:SetHeight(ResultsTop() + heightRows * ROW_HEIGHT + FOOTER_HEIGHT + actionHeight)
end

local function SetActionMessage(text)
    message:SetText(text)
    message:SetShown(text ~= "")
    ResizePanel()
end

local function RenderResults()
    local canScroll = #results > visibleRows
    local top = ResultsTop()
    for index, row in ipairs(rows) do
        local resultIndex = firstVisible + index - 1
        row.entry = index <= visibleRows and results[resultIndex] or nil
        row.resultIndex = resultIndex
        SetRowSelected(row, row.entry ~= nil and resultIndex == selected)
        if row.entry then
            row:SetPoint("TOPLEFT", 8, -top - (index - 1) * ROW_HEIGHT)
            row:SetWidth(frame:GetWidth() - 16 - (canScroll and SCROLLBAR_WIDTH or 0))
            UpdateRow(row)
            row:Show()
        else
            row:Hide()
        end
    end
    if queryPopup.resultEntry and queryPopup.anchor.entry ~= queryPopup.resultEntry then queryPopup:Hide() end

    local visible = math.min(visibleRows, math.max(0, #results - firstVisible + 1))
    ResizePanel()
    if visible > 0 then
        range:SetFormattedText("%d-%d of %d", firstVisible, firstVisible + visible - 1, #results)
    else
        range:SetText("")
    end

    scrollbar:SetShown(canScroll)
    if canScroll then
        local height = visibleRows * ROW_HEIGHT
        scrollbar:SetHeight(height)
        scrollbar:SetStepsPerPage(visibleRows)
        scrollbar:SetPoint("TOPRIGHT", -8, -top)
        scrollbar:GetThumbTexture():SetHeight(math.max(16, height * visibleRows / #results))
        syncingScrollbar = true
        scrollbar:SetMinMaxValues(1, #results - visibleRows + 1)
        scrollbar:SetValue(firstVisible)
        syncingScrollbar = false
    end
end

local function ShowHover(row)
    local entry = row.entry
    if not entry or entry.sectionHeader or entry.toggleSection then return end
    if entry.kind == "text" or entry.kind == "emote" or entry.kind == "quest"
        or entry.kind == "dungeon" or entry.kind == "npc" or entry.kind == "object" then
        local hint
        if entry.kind == "emote" then
            hint = "Click to perform this emote."
        elseif entry.kind == "quest" then
            hint = "Click to view quest details."
        elseif entry.kind == "dungeon" then
            hint = "Click to view dungeon loot."
        elseif entry.kind == "npc" or entry.kind == "object" then
            hint = "Click to view known locations."
        elseif entry.tameSources then
            hint = "Right-click for training details."
        elseif (entry.pinEntity or (entry.pinTargetName and entry.x)) and #addon.GetResultMapPins(entry) > 0 then
            hint = "Right-click to add a map pin."
        end
        local clippedDetail = row.idLabel:IsTruncated()
        if not (hint or entry.description or row.label:IsTruncated() or clippedDetail) then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine((entry.name:gsub("|", "||")), 1, 1, 1, true)
        if clippedDetail then GameTooltip:AddLine(row.idLabel:GetText(), 0.8, 0.8, 0.8, true) end
        if hint then GameTooltip:AddLine(hint, 0.8, 0.8, 0.8, true) end
        if entry.description then
            GameTooltip:AddLine((entry.description:gsub("|", "||")), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.kind == "spell" then
        local shown = pcall(GameTooltip.SetSpellByID, GameTooltip, entry.id, false, true)
        if not shown or GameTooltip:NumLines() == 0 then
            GameTooltip:AddLine((entry.name:gsub("|", "||")))
            GameTooltip:AddLine(("Spell %d"):format(entry.id), 0.8, 0.8, 0.8)
        end
        if entry.unlockLevel then
            GameTooltip:AddLine("Right-click for training details.", 0.8, 0.8, 0.8, true)
        elseif addon.AppendSpellUnlockSources then
            addon.AppendSpellUnlockSources(GameTooltip, entry)
        end
        if entry.trainingNote then GameTooltip:AddLine(entry.trainingNote, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
        return
    end
    local shown = pcall(GameTooltip.SetItemByID, GameTooltip, entry.id)
    if not shown or GameTooltip:NumLines() == 0 then
        local label = entry.name or ("Item " .. entry.id)
        GameTooltip:AddLine((label:gsub("|", "||")))
        GameTooltip:AddLine("Click to request item details.", 0.8, 0.8, 0.8, true)
    end
    local sources = addon.GetItemSources(entry.id)
    local nodes = addon.GetGatheringNodes and addon.GetGatheringNodes(entry.id)
    local recipes = ItemRecipes(entry.id)
    if recipes and #recipes == 1 and recipes[1].trainingNote then
        GameTooltip:AddLine(recipes[1].trainingNote, 0.8, 0.8, 0.8, true)
    end
    local hasRelated = entry.questReward or recipes
        or (nodes and #nodes > 0)
        or (addon.HasRecipesUsingItem and addon.HasRecipesUsingItem(entry.id))
    if not hasRelated then
        for _, source in ipairs(sources) do
            if source.kind ~= "quest" then
                hasRelated = true
                break
            end
        end
    end
    if hasRelated then
        GameTooltip:AddLine("Right-click for related results.", 0.8, 0.8, 0.8, true)
    elseif #addon.GetItemQuestChoices(entry.id, QuestRewardLinksEnabled(), sources) > 0 then
        GameTooltip:AddLine("Right-click to open a quest.", 0.8, 0.8, 0.8, true)
    end
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

local function StopArrowRepeat()
    if arrowTimer then arrowTimer:Cancel() end
    heldArrow, arrowTimer = nil, nil
end

local function ResetResultKeys()
    StopArrowRepeat()
    arrowSelected = nil
end

local function ReleaseResultKeyboard()
    if resultKeyboardActive then
        frame:SetScript("OnKeyDown", nil)
        frame:SetScript("OnKeyUp", nil)
        frame:EnableKeyboard(false)
    end
    if resultKeyboardActive or arrowSelected then
        keyboardHint:SetText(SEARCH_KEYS)
    end
    ResetResultKeys()
    resultKeyboardActive, heldResultEnter = nil, nil
end

local function CanActivate(entry)
    if not entry then return false end
    if entry.kind ~= "text" or entry.toggleSection or entry.tameSources then return true end
    return entry.relatedQuery or entry.trainerName or entry.pinEntity or (entry.pinTargetName and entry.x)
end

local function IsSectionExpanded(entry)
    if entry.sectionHeader then return not collapsedDetailSections[entry.toggleSection] end
    return expandedSections[entry.toggleSection] == true
end

local function SelectedDetailHeader()
    local entry = results[selected]
    if entry and entry.sectionHeader and entry.toggleSection then return entry end
end

local function RenderSearchSections(selectedSection)
    local function SelectSectionRow()
        firstVisible = math.max(1, firstVisible + #results - selected)
        selected = #results
    end

    local function AppendDetailHeader(title, key)
        local header = { kind = "text", name = title, sectionHeader = true, toggleSection = key or title }
        local expanded = IsSectionExpanded(header)
        header.matchLabel = expanded and "Collapse" or "Expand"
        results[#results + 1] = header
        if selectedSection and selectedSection.sectionHeader and header.toggleSection == selectedSection.toggleSection then
            SelectSectionRow()
        end
        return expanded
    end

    results = primaryResults
    if resultSections then
        results = {}
        local function AppendSection(title, entries, collapsible)
            if collapsible then
                if not AppendDetailHeader(title) then return end
            else
                results[#results + 1] = { kind = "text", name = title, sectionHeader = true }
            end
            local previewCount = #resultSections > 0 and math.min(SECTION_PREVIEW_ROWS, #entries) or #entries
            local expanded = expandedSections[title]
            local visibleCount = expanded and #entries or previewCount
            for i = 1, visibleCount do results[#results + 1] = entries[i] end
            if #entries > previewCount then
                local label = title == "Items" and "items" or "results"
                local text = expanded and ("Show fewer " .. label) or ("Show all %d %s"):format(#entries, label)
                results[#results + 1] = { kind = "text", name = text, toggleSection = title }
                if selectedSection and not selectedSection.sectionHeader and title == selectedSection.toggleSection then
                    SelectSectionRow()
                end
            end
        end
        AppendSection(resultSections.title, primaryResults, resultSections.collapsible)
        for _, section in ipairs(resultSections) do
            AppendSection(section.title, section.rows, section.collapsible)
        end
    elseif addon.IsQuestDetailQuery and addon.IsQuestDetailQuery(searchBox:GetText()) then
        results = {}
        local index = 1
        while index <= #primaryResults do
            local entry = primaryResults[index]
            if entry.collapsible then
                if AppendDetailHeader(entry.name, entry.sectionKey) then
                    for i = index + 1, index + entry.collapsible do results[#results + 1] = primaryResults[i] end
                end
                index = index + entry.collapsible
            else
                results[#results + 1] = entry
            end
            index = index + 1
        end
    end
    selected = math.min(selected, math.max(1, #results))
    firstVisible = math.min(firstVisible, math.max(1, #results - visibleRows + 1))
    RenderResults()
end

local function ShowResults(matches, hint, answerText, sections, preserveSections)
    local selectedHeader = preserveSections and SelectedDetailHeader()
    if resultKeyboardActive then
        ResetResultKeys()
    else
        ReleaseResultKeyboard()
    end
    primaryResults = matches
    if answerText then
        primaryResults = {}
        for line in answerText:gmatch("[^\n]+") do
            primaryResults[#primaryResults + 1] = { kind = "text", name = line }
        end
        for _, entry in ipairs(matches) do
            primaryResults[#primaryResults + 1] = entry
        end
    end
    if not selectedHeader then
        selected, firstVisible = sections and not sections.collapsible and 2 or 1, 1
    end
    resultSections = sections
    if not preserveSections then expandedSections, collapsedDetailSections = {}, {} end
    local summaryText = hint or (#primaryResults == 0 and "No results found." or "")
    summary:SetText(summaryText)
    summary:SetShown(summaryText ~= "")
    message:Hide()
    RenderSearchSections(selectedHeader)
end

local function UpdateQuestDetails(matches, hint)
    local changed = #matches ~= #primaryResults or hint ~= summary:GetText()
    if not changed then
        for i, entry in ipairs(matches) do
            local previous = primaryResults[i]
            if entry.name ~= previous.name or entry.matchLabel ~= previous.matchLabel or entry.id ~= previous.id then
                changed = true
                break
            end
        end
    end
    if not changed then return end
    HideHover()
    primaryResults = matches
    summary:SetText(hint)
    summary:SetShown(hint ~= nil and hint ~= "")
    RenderSearchSections(SelectedDetailHeader())
end

local function SearchNow()
    if debounce then
        debounce:Cancel()
        debounce = nil
    end
    CancelStatSearch()
    HideHover()
    ClearPending()
    local query = searchBox:GetText()
    lastSearchText = query
    if not query:find("%S") then
        ShowResults({}, "")
        return
    end
    local matches, hint, loadStats, answerText, sections = addon.Search(query)
    ShowResults(matches, hint, answerText, sections)
    if loadStats then
        cancelStatSearch = loadStats(function(loadedMatches, loadedHint, _, loadedAnswer, loadedSections)
            cancelStatSearch = nil
            if addon.IsQuestDetailQuery and addon.IsQuestDetailQuery(query) then
                UpdateQuestDetails(loadedMatches, loadedHint)
                return
            end
            ShowResults(loadedMatches, loadedHint, loadedAnswer, loadedSections, true)
        end)
    end
end

local function EnableLinkedResultKeyboard()
    if (#results > 0 or cancelStatSearch or CanGoBack()) and not InCombatLockdown() and not GetCurrentKeyBoardFocus() then
        EnableResultKeyboard()
    end
end

local function DisplaySearchQuery(query)
    settingSearchText = true
    searchBox:SetText(query)
    settingSearchText = nil
    SearchNow()
    UpdateBackButton()
end

local function SetSearchQuery(query)
    TrackSearchQuery(searchBox:GetText() or "")
    TrackSearchQuery(query)
    DisplaySearchQuery(query)
end

local function FollowSearchLink(query)
    searchBox:ClearFocus()
    SetSearchQuery(query)
    EnableLinkedResultKeyboard()
end

local function GoBack()
    CommitTypedQuery()
    local query = table.remove(backQueries)
    if not query then return end
    queryPopup:Hide()
    searchBox:ClearFocus()
    navigationQuery = query
    DisplaySearchQuery(query)
    searchBox:SetCursorPosition(#query)
    EnableLinkedResultKeyboard()
end

local function OpenItem(link, action)
    SetActionMessage("")
    if action == "chat" then
        if not ChatEdit_InsertLink(link) then
            SetActionMessage("Open chat, then Shift-click the item to insert its link.")
        end
    elseif action == "preview" then
        DressUpItemLink(link)
    else
        local itemString = link:match("|H([^|]+)|h")
        if itemString then
            SetItemRef(itemString, link, "LeftButton")
            local itemID = tonumber(itemString:match("^item:(%d+)"))
            if itemID then addon.GetItemSources(itemID) end
        end
    end
end

local function SelectResult(entry)
    local id = entry.id
    ClearPending()
    queryPopup:Hide()
    if entry.toggleSection then
        local title = entry.toggleSection
        local wasExpanded = IsSectionExpanded(entry)
        if entry.sectionHeader then
            collapsedDetailSections[title] = wasExpanded or nil
        else
            expandedSections[title] = not wasExpanded or nil
        end
        RenderSearchSections(wasExpanded and entry or nil)
        return
    end
    if entry.kind == "text" then
        if entry.tameSources then
            local row = rows[selected - firstVisible + 1]
            if row then queryPopup.ShowResultChoices(row) end
        end
        return
    end
    searchBox:ClearFocus()
    RememberQuery(searchBox:GetText())
    if entry.kind == "quest" or entry.kind == "dungeon" or entry.kind == "npc" or entry.kind == "object" then
        local target = entry.kind == "dungeon" and entry.name or id
        FollowSearchLink("@" .. entry.kind .. " " .. target)
        return
    end
    if entry.kind == "emote" then
        SetActionMessage(addon.PerformSearchEmote(entry) and "" or "Emotes are unavailable in this client.")
        return
    end
    if entry.kind == "spell" then
        local link = C_Spell.GetSpellLink(id)
        if not link then
            SetActionMessage("Spell details are unavailable.")
        elseif IsModifiedClick("CHATLINK") then
            if not ChatEdit_InsertLink(link) then
                SetActionMessage("Open chat, then Shift-click the spell to insert its link.")
            end
        else
            SetActionMessage("")
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
            SetActionMessage(("Item %d details are unavailable. Click the item to retry."):format(id))
        end
    end)
    pending = request
    SetActionMessage(("Loading item %d..."):format(id))
    if not pcall(C_Item.RequestLoadItemDataByID, id) and pending == request then
        ClearPending()
        SetActionMessage(("Item %d details are unavailable."):format(id))
    end
end

local function OnItemData(_, event, id, success)
    if not frame:IsShown() then return end
    for _, row in ipairs(rows) do
        if row.entry and row.entry.id == id and not row.entry.kind then
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
            SetActionMessage(("Item %d details are unavailable. Click the item to retry."):format(id))
        end
    end
end

local function RefreshNavigation()
    HideHover()
    ClearPending()
    message:Hide()
    RenderResults()
end

local function MoveSelection(delta)
    if #results == 0 then return end
    local nextSelection = math.max(1, math.min(#results, selected + delta))
    while results[nextSelection] and results[nextSelection].sectionHeader and not results[nextSelection].toggleSection do
        nextSelection = nextSelection + delta
    end
    if not results[nextSelection] then return end
    local actionable = not not CanActivate(results[nextSelection])
    if not resultKeyboardActive and actionable ~= arrowSelected then
        keyboardHint:SetText(actionable and RESULT_KEYS or SEARCH_KEYS)
    end
    arrowSelected = actionable
    if nextSelection == selected then return end
    selected = nextSelection
    if selected < firstVisible then
        firstVisible = selected
    elseif selected >= firstVisible + visibleRows then
        firstVisible = selected - visibleRows + 1
    end
    RefreshNavigation()
    return true
end

local function PressArrow(key)
    if heldArrow == key then return end
    StopArrowRepeat()
    local delta = ARROW_DIRECTION[key]
    if not MoveSelection(delta) or not IsKeyDown then return end

    heldArrow = key
    local interval = ARROW_REPEAT_START
    local function RepeatArrow()
        arrowTimer = nil
        if IsKeyDown(key, true) and MoveSelection(delta) then
            arrowTimer = C_Timer.NewTimer(interval, RepeatArrow)
            interval = math.max(ARROW_REPEAT_MIN, interval * ARROW_REPEAT_ACCELERATION)
        else
            heldArrow = nil
        end
    end
    arrowTimer = C_Timer.NewTimer(ARROW_HOLD_DELAY, RepeatArrow)
end

local function ScrollTo(first)
    local lastStart = math.max(1, #results - visibleRows + 1)
    local nextStart = math.max(1, math.min(lastStart, first))
    if nextStart == firstVisible then return end
    StopArrowRepeat()
    firstVisible = nextStart
    selected = math.max(firstVisible, math.min(selected, firstVisible + visibleRows - 1))
    RefreshNavigation()
end

local function OnMouseWheel(_, direction)
    if direction == 0 then return end
    if debounce then SearchNow() end
    ScrollTo(firstVisible + (direction > 0 and -1 or 1))
end

local function SaveWindowPosition()
    local x, top = frame:GetCenter(), frame:GetTop()
    local parentX, parentTop = UIParent:GetCenter(), UIParent:GetTop()
    if not (x and top and parentX and parentTop) then return end

    local settings = _G[settingsKey]
    settings.x, settings.y = x - parentX, top - parentTop
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", settings.x, settings.y)
end

local function StopMovingWindow()
    if not moving then return end
    moving = false
    frame:StopMovingOrSizing()
    SaveWindowPosition()
end

local function Clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function StopResizingWindow()
    if not resizing then return end
    resizing = false
    resizeHandle:SetScript("OnUpdate", nil)
    local settings = _G[settingsKey]
    settings.width = frame:GetWidth()
    if resizePreviewRows then settings.rows = visibleRows end
    resizePreviewRows = nil
    ResizePanel()
    SaveWindowPosition()
end

local function StartResizingWindow()
    StopMovingWindow()
    ReleaseResultKeyboard()
    HideHover()

    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    local parentLeft, parentTop = UIParent:GetLeft(), UIParent:GetTop()
    if not (left and top and parentLeft and parentTop) then return end

    local startWidth, startRows = frame:GetWidth(), visibleRows
    local displayedRows = math.min(startRows, #results)
    local maxWidth = math.max(MIN_WIDTH, math.min(MAX_WIDTH, UIParent:GetWidth()))
    local maxRows = math.max(MIN_ROWS, math.min(MAX_ROWS,
        math.floor((UIParent:GetHeight() - ResultsTop() - FOOTER_HEIGHT - 18) / ROW_HEIGHT)))
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - parentLeft, top - parentTop)
    resizing = true

    resizeHandle:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local width = Clamp(math.floor(startWidth + (cursorX - x) / scale + 0.5), MIN_WIDTH, maxWidth)
        local rowDelta = math.floor((y - cursorY) / (scale * ROW_HEIGHT) + 0.5)
        local previewRows
        if rowDelta ~= 0 and (displayedRows >= MIN_ROWS or displayedRows + rowDelta >= MIN_ROWS) then
            previewRows = Clamp(displayedRows + rowDelta, MIN_ROWS, maxRows)
        end
        local nextRows = previewRows or startRows
        if width == frame:GetWidth() and nextRows == visibleRows and previewRows == resizePreviewRows then return end

        frame:SetWidth(width)
        visibleRows, resizePreviewRows = nextRows, previewRows
        firstVisible = Clamp(firstVisible, math.max(1, selected - visibleRows + 1),
            math.max(1, #results - visibleRows + 1))
        HideHover()
        RenderResults()
    end)
end

local function HideButtonTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function SetButtonTooltip(button, label)
    button.tooltipText = label
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(label)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideButtonTooltip)
    button:SetScript("OnHide", HideButtonTooltip)
end

local function CreateListScrollbar(parent, onWheel, onValueChanged)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(SCROLLBAR_WIDTH)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", onWheel)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(4)
    track:SetColorTexture(unpack(COLORS.trim))
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(7, 16)
    thumb:SetColorTexture(unpack(COLORS.accent))
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged", onValueChanged)
    slider:Hide()
    return slider
end

local function CreateQueryPopup()
    local rowHeight = 24
    local popupWidth, fieldInset, fieldGap, fieldHeight = 378, 12, 6, 22
    local scrollTo, firstChoice, syncingScroll
    queryPopup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    queryPopup:SetWidth(popupWidth)
    queryPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    queryPopup:SetClampedToScreen(true)
    queryPopup:EnableMouse(true)
    queryPopup:SetBackdrop(frame:GetBackdrop())
    queryPopup:SetBackdropColor(unpack(COLORS.panel))
    queryPopup:SetBackdropBorderColor(unpack(COLORS.border))
    queryPopup:SetScript("OnHide", function(self)
        self.resultEntry, self.showingHistory = nil, nil
        scrollTo = nil
        if resultKeyboardActive then keyboardHint:SetText(RESULT_KEYS) end
    end)
    queryPopup:Hide()

    local function OnPopupMouseWheel(_, direction)
        if scrollTo and direction ~= 0 then scrollTo(firstChoice + (direction > 0 and -1 or 1)) end
    end
    queryPopup:SetScript("OnMouseWheel", OnPopupMouseWheel)
    local popupScrollbar = CreateListScrollbar(queryPopup, OnPopupMouseWheel, function(_, value)
        if scrollTo and not syncingScroll then scrollTo(math.floor(value + 0.5)) end
    end)

    local empty = queryPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 12, -13)
    empty:SetText("No recent searches")

    local popupSummary = queryPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popupSummary:SetPoint("TOPLEFT", 12, -10)
    popupSummary:Hide()

    local popupInstructions = queryPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popupInstructions:SetPoint("TOPLEFT", popupSummary, "BOTTOMLEFT", 0, -4)
    popupInstructions:SetText("Tame a beast below and have it use this ability.")
    popupInstructions:Hide()

    local shortcutsTop = 26
    local filtersTop = shortcutsTop + fieldHeight + fieldGap
    local fieldsHeight = filtersTop + fieldHeight + fieldGap
    local fields = CreateFrame("Frame", nil, queryPopup)
    fields:SetPoint("TOPLEFT", 0, 0)
    fields:SetPoint("TOPRIGHT", 0, 0)
    fields:SetHeight(fieldsHeight)
    fields:Hide()
    local fieldsLabel = fields:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fieldsLabel:SetPoint("TOPLEFT", fieldInset, -8)
    fieldsLabel:SetText("Insert field")
    local function FillQuery(query, cursorOffset)
        if #query > MAX_QUERY_BYTES then return end
        queryPopup:Hide()
        searchBox:SetText(query)
        searchBox:SetFocus()
        searchBox:SetCursorPosition(#query - (cursorOffset or 0))
    end
    local function AddFieldButton(label, description, index, count, top, onClick)
        local width = (popupWidth - 2 * fieldInset - (count - 1) * fieldGap) / count
        local button = CreateFrame("Button", nil, fields, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", fieldInset + (index - 1) * (width + fieldGap), -top)
        button:SetSize(width, fieldHeight)
        button:SetText(label)
        SetButtonTooltip(button, description)
        button:SetScript("OnClick", onClick)
    end
    for index, shortcut in ipairs(queryShortcuts) do
        local token = shortcut[2]
        AddFieldButton(shortcut[1], shortcut[3], index, #queryShortcuts, shortcutsTop, function()
            if token == "@target" then
                FillQuery(token)
                return
            end
            local current = searchBox:GetText():match("^%s*(.-)%s*$")
            local existing, rest = current:match("^(%S+)%s*(.*)$")
            if addon.GetSearchShortcut(existing) then
                current = rest
            end
            FillQuery(token .. " " .. current)
        end)
    end
    for index, field in ipairs(queryFields) do
        AddFieldButton(field[1], field[3], index, #queryFields, filtersTop, function()
            local current = searchBox:GetText():gsub("%s+$", "")
            local prefix = current:find("%S") and current .. " " or ""
            FillQuery(prefix .. field[2], field[4])
        end)
    end

    local buttons = {}
    queryPopup.buttons = buttons
    for index = 1, math.max(HISTORY_PAGE_SIZE + 2, #queryExamples, RESULT_MENU_VISIBLE_ROWS + 1) do
        local button = CreateFrame("Button", nil, queryPopup)
        button:SetHeight(rowHeight)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(unpack(COLORS.hover))
        button:SetHighlightTexture(highlight)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.label:SetPoint("LEFT", 7, 0)
        button.label:SetPoint("RIGHT", -7, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button:SetScript("OnClick", function(self)
            if self.changePage then
                self.changePage()
                return
            end
            if self.action then
                queryPopup:Hide()
                self.action()
                return
            end
            local query = self.query
            if not query then return end
            if queryPopup.resultEntry then RememberQuery(searchBox:GetText()) end
            queryPopup:Hide()
            RememberQuery(query)
            FollowSearchLink(query)
            searchBox:SetCursorPosition(#query)
        end)
        buttons[index] = button
    end

    local function ShowChoices(owner, choices, resultMenu, start, parentChoices)
        if not start and queryPopup:IsShown() and queryPopup.anchor == owner then
            queryPopup:Hide()
            return
        end
        HideHover()
        local displayed = choices
        local isHistory = choices == history
        local historyOff = isHistory and GetHistoryLimit() == 0
        local heading = resultMenu == "quests" and "Open quest" or resultMenu and "Related results" or "Recent searches"
        local unlockMenu = resultMenu == "unlock"
        if parentChoices then heading = unlockMenu and "How to learn" or "Add map pin" end
        local petMenu = resultMenu == "beasts"
        local showInstructions = petMenu and #owner.entry.tameSources > 0
        if petMenu then heading = ("Requires pet level %d to train"):format(owner.entry.petTrainingLevel) end
        local limit = resultMenu and RESULT_MENU_VISIBLE_ROWS or HISTORY_PAGE_SIZE
        local first = start or 1
        local overflow = (resultMenu or isHistory) and #choices > limit
        local canScroll = resultMenu ~= nil and overflow
        if overflow then
            local last = math.min(#choices, first + limit - 1)
            displayed = {}
            if isHistory and first > 1 then
                displayed[#displayed + 1] = { name = "Previous searches", page = first - limit }
            end
            for i = first, last do displayed[#displayed + 1] = choices[i] end
            if isHistory and last < #choices then
                displayed[#displayed + 1] = { name = "Next searches", page = last + 1 }
            end
            heading = ("%s · %d–%d of %d"):format(heading, first, last, #choices)
        end
        if parentChoices then displayed = { { name = "Back", back = true }, unpack(displayed) } end
        local showFields = choices == queryExamples
        fields:SetShown(showFields)
        popupSummary:SetText(heading)
        popupSummary:SetShown(not showFields)
        popupInstructions:SetShown(showInstructions)
        local fieldsOffset = showFields and fieldsHeight or (showInstructions and 38 or 22)
        local choiceHeight = unlockMenu and 48 or petMenu and 34 or rowHeight
        firstChoice = first
        scrollTo = nil
        queryPopup:EnableMouseWheel(canScroll)
        popupScrollbar:SetShown(canScroll)
        if canScroll then
            local lastStart = #choices - limit + 1
            scrollTo = function(value)
                local nextStart = Clamp(value, 1, lastStart)
                if nextStart == firstChoice then return end
                ShowChoices(owner, choices, resultMenu, nextStart, parentChoices)
                return true
            end
            local height = limit * choiceHeight
            local top = -5 - fieldsOffset - (parentChoices and choiceHeight or 0)
            popupScrollbar:SetPoint("TOPRIGHT", -5, top)
            popupScrollbar:SetHeight(height)
            popupScrollbar:SetStepsPerPage(limit)
            popupScrollbar:GetThumbTexture():SetHeight(math.max(16, height * limit / #choices))
            syncingScroll = true
            popupScrollbar:SetMinMaxValues(1, lastStart)
            popupScrollbar:SetValue(first)
            syncingScroll = false
        end

        queryPopup.selected = 0
        queryPopup.count = #displayed
        queryPopup.hasBack = parentChoices ~= nil
        for index, row in ipairs(buttons) do
            row:UnlockHighlight()
            local choice = displayed[index]
            local page = type(choice) == "table" and choice.page
            row.changePage, row.action, row.query = nil, nil, nil
            if choice then
                local top = -5 - fieldsOffset - (index - 1) * choiceHeight
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 5, top)
                row:SetPoint("TOPRIGHT", -5 - (canScroll and SCROLLBAR_WIDTH or 0), top)
                row:SetHeight(choiceHeight)
                row.label:SetWordWrap(petMenu or unlockMenu)
                local display = type(choice) == "table" and choice.name or (choice:match("|H.-|h(.-)|h") or choice)
                row.label:SetText((display:gsub("|", "||")))
                if page then
                    row.changePage = function() ShowChoices(owner, choices, resultMenu, page, parentChoices) end
                elseif resultMenu then
                    if choice.submenu then
                        row.changePage = function()
                            ShowChoices(owner, choice.submenu, choice.submenuType or "locations", 1, choices)
                        end
                    elseif choice.back then
                        row.changePage = function() ShowChoices(owner, parentChoices, "results", 1) end
                    else
                        row.query, row.action = choice.query, choice.action
                    end
                else
                    row.query = choice
                end
            end
            row:SetEnabled(not not (row.changePage or row.action or row.query))
            row:SetShown(choice ~= nil)
        end
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", 12, -13 - fieldsOffset)
        empty:SetText(historyOff and "Search history is off" or "No recent searches")
        empty:SetShown(#displayed == 0)
        queryPopup:SetHeight(10 + fieldsOffset + math.max(1, #displayed) * choiceHeight)
        queryPopup.anchor = owner
        queryPopup.resultEntry = resultMenu and owner.entry or nil
        queryPopup.showingHistory = isHistory
        queryPopup:ClearAllPoints()
        if resultMenu then
            queryPopup:SetPoint("TOPLEFT", owner, "TOPRIGHT", 5, 0)
        else
            queryPopup:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -5)
        end
        queryPopup:Show()
        if resultMenu then
            searchBox:ClearFocus()
            if not InCombatLockdown() then
                EnableResultKeyboard()
                keyboardHint:SetText(MENU_KEYS)
            end
        else
            searchBox:SetFocus()
        end
    end
    function queryPopup.MoveSelection(delta)
        if queryPopup.count == 0 then return end
        local previous = queryPopup.selected
        local nextIndex = Clamp(previous + delta, 1, queryPopup.count)
        local firstRow = queryPopup.hasBack and 2 or 1
        if scrollTo and ((delta > 0 and previous == queryPopup.count) or (delta < 0 and previous == firstRow)) then
            if scrollTo(firstChoice + delta) then nextIndex = previous end
        end
        if buttons[previous] then buttons[previous]:UnlockHighlight() end
        queryPopup.selected = nextIndex
        buttons[nextIndex]:LockHighlight()
    end

    function queryPopup.ActivateChoice()
        local index = queryPopup.selected
        if index == 0 then
            for i = 1, queryPopup.count do
                local button = buttons[i]
                if button.query or button.action or button.changePage then index = i; break end
            end
        end
        if index == 0 then return end
        buttons[index]:Click()
    end

    function queryPopup.ShowResultChoices(owner)
        local entry = owner.entry
        if not entry or entry.sectionHeader or entry.toggleSection then return end
        local choices = addon.GetResultRelatedQueries(entry)
        if entry.questReward then
            table.insert(choices, 1, { name = "Search for this item", query = tostring(entry.id) })
        end
        local locations = addon.GetResultMapPins(entry)
        local pinChoices = {}
        for _, location in ipairs(locations) do
            pinChoices[#pinChoices + 1] = {
                name = location.label,
                action = function()
                    local placed = addon.AddResultMapPin(location)
                    SetActionMessage(placed and ("Map pin added · " .. location.label) or "Unable to add a map pin.")
                end,
            }
        end
        if #pinChoices > 0 then
            local pinPosition = 1
            for index, choice in ipairs(choices) do
                if choice.query and choice.query:match("^@quest ") then pinPosition = index + 1 end
            end
            local pin = { name = "Add map pin" }
            if #pinChoices == 1 then
                pin.action = pinChoices[1].action
            else
                pin.submenu = pinChoices
            end
            table.insert(choices, pinPosition, pin)
        end
        local related = #choices > 0
        if not entry.kind then
            for _, quest in ipairs(addon.GetItemQuestChoices(entry.id, QuestRewardLinksEnabled())) do
                local label = quest.required and quest.reward and "Required and rewarded by"
                    or quest.reward and "Reward from" or "Required for"
                choices[#choices + 1] = { name = label .. ": " .. quest.name, query = "@quest " .. quest.id }
            end
        end
        if #choices > 0 then
            ShowChoices(owner, choices, entry.tameSources and "beasts" or related and "results" or "quests")
            return queryPopup:IsShown()
        else
            queryPopup:Hide()
        end
    end

    local function AddPopupButton(label, icon, right, queries)
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(24, 24)
        button:SetPoint("TOPRIGHT", right, -18)
        button:SetNormalTexture(icon)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        SetButtonTooltip(button, label)
        button:SetScript("OnClick", function(self)
            HideButtonTooltip(self)
            ShowChoices(self, queries)
        end)
    end

    AddPopupButton("History", "Interface\\Icons\\INV_Misc_PocketWatch_01", -40, history)
    AddPopupButton("Examples", "Interface\\Icons\\INV_Misc_Book_09", -11, queryExamples)
end

local function OpenSelectedMenu()
    local row = rows[selected - firstVisible + 1]
    if not row or not queryPopup.ShowResultChoices(row) then return false end
    queryPopup.MoveSelection(1)
    return true
end

local function UseResultArrow(key)
    local entry = results[selected]
    if entry and entry.toggleSection then
        local expand = key == "RIGHT"
        if expand ~= IsSectionExpanded(entry) then
            if GetCurrentKeyBoardFocus() == searchBox then
                searchBox:ClearFocus()
                EnableResultKeyboard()
            end
            SelectResult(entry)
        end
    elseif key == "RIGHT" then
        OpenSelectedMenu()
    end
end

local function OnResultKeyDown(self, key)
    if InCombatLockdown() then
        ReleaseResultKeyboard()
        return
    end
    local navigating = not GetCurrentKeyBoardFocus()
    if navigating and key == "BACKSPACE" and CanGoBack() then
        GoBack()
        self:SetPropagateKeyboardInput(false)
        return
    end
    local arrow = navigating and ARROW_DIRECTION[key]
    if navigating and (key == "ENTER" or key == "NUMPADENTER") then
        self:SetPropagateKeyboardInput(false)
        if heldResultEnter then return end
        StopArrowRepeat()
        heldResultEnter = key
        if queryPopup.resultEntry then
            queryPopup.ActivateChoice()
        else
            local entry = results[selected]
            if CanActivate(entry) and not OpenSelectedMenu() then SelectResult(entry) end
        end
        return
    end
    if navigating and (key == "LEFT" or (key == "ESCAPE" and queryPopup.resultEntry)) then
        self:SetPropagateKeyboardInput(false)
        if queryPopup.resultEntry then
            queryPopup:Hide()
        else
            UseResultArrow(key)
        end
        return
    end
    if navigating and key == "RIGHT" then
        self:SetPropagateKeyboardInput(false)
        if not queryPopup.resultEntry then UseResultArrow(key) end
        return
    end
    if arrow and queryPopup.resultEntry then
        self:SetPropagateKeyboardInput(false)
        queryPopup.MoveSelection(arrow)
        return
    end
    self:SetPropagateKeyboardInput(not arrow)
    if arrow then
        PressArrow(key)
    elseif not navigating and not queryPopup.resultEntry then
        ReleaseResultKeyboard()
    end
end

local function OnResultKeyUp(self, key)
    if key == heldArrow then StopArrowRepeat() end
    if key ~= heldResultEnter then return end
    heldResultEnter = nil
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
end

EnableResultKeyboard = function()
    if resultKeyboardActive then return end
    resultKeyboardActive = true
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", OnResultKeyDown)
    frame:SetScript("OnKeyUp", OnResultKeyUp)
    frame:EnableKeyboard(true)
    keyboardHint:SetText(queryPopup.resultEntry and MENU_KEYS or RESULT_KEYS)
end

local function OnSearchMouseDown()
    if not frame:IsShown() or InCombatLockdown() then return end
    local target = GetMouseFoci()[1]
    while target and target ~= frame and target ~= compactOptions do
        if target == searchBox or (target == queryPopup and not queryPopup.resultEntry) then return end
        target = target:GetParent()
    end
    if GetCurrentKeyBoardFocus() == searchBox then searchBox:ClearFocus() end
    if target ~= frame then
        ReleaseResultKeyboard()
    elseif not GetCurrentKeyBoardFocus() then
        if debounce then SearchNow() end
        EnableLinkedResultKeyboard()
    end
end

local function RefreshSearchPreferences()
    if refreshCompactOptions then refreshCompactOptions() end
    if refreshAddOnOptions then refreshAddOnOptions() end
end

local function CreateSearchPreferences(panel, anchor, margin, includeDetailOptions)
    local historyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    historyLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -margin)
    historyLabel:SetText("Search history length")

    local limitButtons = {}
    local previous
    for _, limit in ipairs(HISTORY_LIMITS) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(42, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", historyLabel, "BOTTOMLEFT", 0, -6)
        end
        button:SetText(limit == 0 and "Off" or tostring(limit))
        button:SetScript("OnClick", function()
            local settings = GetSettings()
            settings.historyLimit = limit
            TrimHistory(GetHistory(settings), limit)
            if queryPopup and queryPopup.showingHistory then queryPopup:Hide() end
            RefreshSearchPreferences()
        end)
        limitButtons[limit], previous = button, button
    end

    local sectionsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionsLabel:SetPoint("TOPLEFT", limitButtons[0], "BOTTOMLEFT", 0, -12)
    sectionsLabel:SetText("Automatic result sections")

    local checks = {}
    local function AddSectionCheckboxes(heading, sections)
        for index, section in ipairs(sections) do
            local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            check:SetSize(24, 24)
            local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
            check:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", column * 122, -4 - row * 24)
            local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", check, "RIGHT", 1, 0)
            label:SetText(section)
            check:SetHitRectInsets(0, -label:GetStringWidth() - 1, 0, 0)
            check:SetScript("OnClick", function(self)
                local settings = GetSettings()
                if type(settings.hiddenSections) ~= "table" then settings.hiddenSections = {} end
                settings.hiddenSections[section] = not self:GetChecked() or nil
                RefreshSearchPreferences()
                if frame and frame:IsShown() then SearchNow() end
            end)
            checks[section] = check
        end
        return -10 - math.ceil(#sections / 2) * 24
    end
    local sectionBottom = AddSectionCheckboxes(sectionsLabel, addon.automaticSections)

    local rewardLinks
    if includeDetailOptions then
        local detailsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        detailsLabel:SetPoint("TOPLEFT", sectionsLabel, "BOTTOMLEFT", 0, sectionBottom)
        detailsLabel:SetText("Detail view sections")
        local detailsBottom = AddSectionCheckboxes(detailsLabel, { "Previous quests", "Next quests", "NPC Loot", "Vendor Items" })

        rewardLinks = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        rewardLinks:SetSize(24, 24)
        rewardLinks:SetPoint("TOPLEFT", detailsLabel, "BOTTOMLEFT", 0, detailsBottom)
        local label = rewardLinks:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", rewardLinks, "RIGHT", 1, 0)
        label:SetText("Quest reward links")
        rewardLinks:SetHitRectInsets(0, -label:GetStringWidth() - 1, 0, 0)
        rewardLinks:SetScript("OnClick", function(self)
            GetSettings().questRewardLinks = not not self:GetChecked()
            if queryPopup and queryPopup.resultEntry then queryPopup:Hide() end
            RefreshSearchPreferences()
        end)
    end

    local function Refresh()
        local current = GetHistoryLimit()
        for limit, button in pairs(limitButtons) do button:SetEnabled(limit ~= current) end
        for section, check in pairs(checks) do check:SetChecked(addon.IsAutomaticSectionEnabled(section)) end
        if rewardLinks then rewardLinks:SetChecked(QuestRewardLinksEnabled()) end
    end
    panel:HookScript("OnShow", Refresh)
    return Refresh
end

local function CreateCompactOptions()
    local width = 272
    local panel = CreateFrame("Frame", "QuickItemSearchOptionsFrame", frame, "BackdropTemplate")
    panel:SetSize(width, 128 + math.ceil(#addon.automaticSections / 2) * 24)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(frame:GetFrameLevel() + 5)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop(frame:GetBackdrop())
    panel:SetBackdropColor(unpack(COLORS.panel))
    panel:SetBackdropBorderColor(unpack(COLORS.border))
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Options")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() panel:Hide() end)
    refreshCompactOptions = CreateSearchPreferences(panel, title, 11)

    if addOnSettingsCategory and Settings.OpenToCategory then
        panel:SetHeight(panel:GetHeight() + 34)
        local settingsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        settingsButton:SetSize(162, 24)
        settingsButton:SetPoint("BOTTOMLEFT", 14, 12)
        settingsButton:SetText("Open AddOn Settings")
        settingsButton:SetScript("OnClick", function()
            panel:Hide()
            searchBox:ClearFocus()
            ReleaseResultKeyboard()
            Settings.OpenToCategory(addOnSettingsCategory:GetID())
        end)
    end

    local button = CreateFrame("Button", nil, frame)
    button:SetSize(16, 16)
    button:SetPoint("TOPRIGHT", -13, 7)
    button:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    SetButtonTooltip(button, "Options")
    button:SetScript("OnClick", function(self)
        HideButtonTooltip(self)
        if panel:IsShown() then
            panel:Hide()
            return
        end
        queryPopup:Hide()
        HideHover()
        local rightSpace = UIParent:GetWidth() - frame:GetRight()
        panel:ClearAllPoints()
        if rightSpace < width + 6 and frame:GetLeft() > rightSpace then
            panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)
        else
            panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
        end
        panel:Show()
    end)
    return panel
end

local function CreateSearchControls()
    searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetHeight(34)
    searchBox:SetPoint("TOPLEFT", 39, -13)
    searchBox:SetPoint("TOPRIGHT", -72, -13)
    searchBox:SetFontObject("GameFontHighlightLarge")
    searchBox:SetTextColor(unpack(COLORS.text))
    searchBox:SetAltArrowKeyMode(false)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxBytes(MAX_QUERY_BYTES)
    searchBox.Instructions:SetText("Search items, quests, NPCs, and dungeons")
    searchBox.Instructions:SetTextColor(unpack(COLORS.mutedText))
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local piece = searchBox[key]
        if piece then piece:SetVertexColor(0.77, 0.69, 0.54) end
    end
    CreateQueryPopup()
    compactOptions = CreateCompactOptions()
    backButton = CreateFrame("Button", nil, frame)
    backButton:SetPoint("TOPLEFT", 8, -18)
    backButton:SetSize(24, 24)
    backButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    backButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    backButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    backButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    SetButtonTooltip(backButton, "Back (Backspace)")
    backButton:SetScript("OnClick", function(self)
        HideButtonTooltip(self)
        GoBack()
    end)
    UpdateBackButton()
    local closeButton = CreateFrame("Button", "QuickItemSearchCloseButton", frame, "UIPanelCloseButton")
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", 6, 7)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    searchBox:HookScript("OnTextChanged", function(self)
        if settingSearchText then return end
        local query = self:GetText()
        -- The client can notify us again after a programmatic search has rendered.
        if query == lastSearchText then return end
        lastSearchText = query
        UpdateBackButton()
        queryPopup:Hide()
        ReleaseResultKeyboard()
        CancelStatSearch()
        if debounce then debounce:Cancel() end
        debounce = C_Timer.NewTimer(0.15, SearchNow)
    end)
    searchBox:SetScript("OnArrowPressed", function(self, key)
        if queryPopup:IsShown() and ARROW_DIRECTION[key] then
            queryPopup.MoveSelection(ARROW_DIRECTION[key])
            return
        end
        if debounce then SearchNow() end
        if key == "RIGHT" and arrowSelected and not InCombatLockdown() then
            UseResultArrow(key)
        elseif ARROW_DIRECTION[key] then
            if key == "DOWN" and #results > 0 and not InCombatLockdown() then
                self:ClearFocus()
                EnableResultKeyboard()
            end
            PressArrow(key)
        end
    end)
    searchBox:HookScript("OnKeyUp", function(_, key)
        if key == heldArrow then StopArrowRepeat() end
    end)
    searchBox:HookScript("OnEditFocusGained", ReleaseResultKeyboard)
    searchBox:HookScript("OnEditFocusLost", function()
        StopArrowRepeat()
        CommitTypedQuery()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        if queryPopup:IsShown() and queryPopup.selected > 0 then
            queryPopup.buttons[queryPopup.selected]:Click()
            return
        end
        queryPopup:Hide()
        RememberQuery(self:GetText())
        CommitTypedQuery()
        if debounce then SearchNow() end
        local entry = arrowSelected and results[selected]
        ReleaseResultKeyboard()
        self:ClearFocus()
        if not InCombatLockdown() then EnableResultKeyboard() end
        if CanActivate(entry) and not OpenSelectedMenu() then SelectResult(entry) end
    end)
    searchBox:SetScript("OnEscapePressed", function()
        if queryPopup:IsShown() then queryPopup:Hide()
        else frame:Hide() end
    end)
end

local function CreateWindow()
    local settings = GetSettings()
    history = GetHistory(settings)
    TrimHistory(history, GetHistoryLimit())
    local savedRows = tonumber(settings.rows)
    visibleRows = savedRows and Clamp(math.floor(savedRows), MIN_ROWS, MAX_ROWS) or DEFAULT_ROWS
    local width = Clamp(tonumber(settings.width) or DEFAULT_WIDTH, MIN_WIDTH,
        math.max(MIN_WIDTH, math.min(MAX_WIDTH, UIParent:GetWidth())))
    frame = CreateFrame("Frame", "QuickItemSearchFrame", UIParent, "BackdropTemplate")
    frame:SetSize(width, RESULTS_TOP + FOOTER_HEIGHT)
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

    CreateSearchControls()

    for index = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHeight(ROW_HEIGHT)
        row:Hide()
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
        row.iconBorder = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
        row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
        row.iconBorder:SetColorTexture(unpack(COLORS.iconBorder))
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.idLabel:SetPoint("RIGHT", -10, 0)
        row.label:SetPoint("RIGHT", row.idLabel, "LEFT", -10, 0)
        row.idLabel:SetTextColor(unpack(COLORS.mutedText))
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            HideHover()
            hoveredRow = self
            hoverAwaitingData = self.entry.id and not self.entry.kind
                and not C_Item.IsItemDataCachedByID(self.entry.id)
            ShowHover(self)
        end)
        row:SetScript("OnLeave", function(self)
            if hoveredRow == self then HideHover() end
        end)
        row:SetScript("OnClick", function(self, button)
            if not self.entry then return end
            if button == "RightButton" then
                if queryPopup.ShowResultChoices(self) then
                    selected = self.resultIndex
                    for _, visible in ipairs(rows) do SetRowSelected(visible, visible == self) end
                end
                return
            end
            ResetResultKeys()
            selected = self.resultIndex
            for _, visible in ipairs(rows) do
                SetRowSelected(visible, visible == self)
            end
            local entry = self.entry
            if entry.sectionHeader then searchBox:ClearFocus() end
            SelectResult(entry)
            if (entry.sectionHeader or not entry.kind)
                and not InCombatLockdown() and not GetCurrentKeyBoardFocus() then
                EnableResultKeyboard()
            end
        end)
        rows[index] = row
    end

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", 14, -RESULTS_TOP)
    summary:SetPoint("TOPRIGHT", -14, -RESULTS_TOP)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(true)
    summary:SetTextColor(unpack(COLORS.text))
    summary:Hide()

    message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    message:SetPoint("BOTTOMLEFT", 14, 30)
    message:SetTextColor(unpack(COLORS.text))
    message:Hide()
    range = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    range:SetPoint("BOTTOMLEFT", 14, 12)
    range:SetTextColor(unpack(COLORS.mutedText))
    keyboardHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keyboardHint:SetPoint("BOTTOMRIGHT", -23, 12)
    keyboardHint:SetPoint("LEFT", range, "RIGHT", 8, 0)
    keyboardHint:SetJustifyH("RIGHT")
    keyboardHint:SetWordWrap(false)
    keyboardHint:SetText(SEARCH_KEYS)
    keyboardHint:SetTextColor(unpack(COLORS.mutedText))
    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT", 8, -1)
    dragHandle:SetPoint("TOPRIGHT", -72, -1)
    dragHandle:SetHeight(12)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        StopResizingWindow()
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

    resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(18, 18)
    resizeHandle:SetPoint("BOTTOMRIGHT", -3, 3)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:RegisterForDrag("LeftButton")
    resizeHandle:SetScript("OnDragStart", StartResizingWindow)
    resizeHandle:SetScript("OnDragStop", StopResizingWindow)

    scrollbar = CreateListScrollbar(frame, OnMouseWheel, function(_, value)
        if not syncingScrollbar then ScrollTo(math.floor(value + 0.5)) end
    end)

    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            ReleaseResultKeyboard()
        elseif event == "GLOBAL_MOUSE_DOWN" then
            OnSearchMouseDown()
        elseif event == "PLAYER_TARGET_CHANGED" then
            local query = searchBox:GetText():match("^%s*(.-)%s*$")
            if self:IsShown() and addon.GetSearchShortcut(query) == "@target" then SearchNow() end
        elseif event == "QUEST_LOG_UPDATE" then
            local query = searchBox:GetText()
            if self:IsShown() and not debounce and not cancelStatSearch
                and addon.IsQuestDetailQuery and addon.IsQuestDetailQuery(query) then
                local matches, hint, load = addon.Search(query)
                if not load then UpdateQuestDetails(matches, hint) end
            end
        else
            OnItemData(self, event, ...)
        end
    end)
    frame:SetScript("OnHide", function()
        queryPopup:Hide()
        compactOptions:Hide()
        RememberQuery(searchBox:GetText())
        CommitTypedQuery()
        StopResizingWindow()
        ReleaseResultKeyboard()
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
    queryPopup:Hide()
    ReleaseResultKeyboard()
    if query then RememberQuery(query) end
    SetSearchQuery(query or "")
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
    return save
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
    local anchor = addon.GetLevelWindow and CreateLevelOptions(panel, status) or status
    refreshAddOnOptions = CreateSearchPreferences(panel, anchor, 22, true)
    addOnSettingsCategory = Settings.RegisterCanvasLayoutCategory(panel, title)
    Settings.RegisterAddOnCategory(addOnSettingsCategory)
end

CreateOptions()
