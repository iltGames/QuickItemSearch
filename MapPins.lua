local _, addon = ...
local cachedZones, mapIDs, mapOverrides
local marker, markerLocation

local function ReadMapIDs(data)
    if type(data) == "table" then return data end
    if type(data) ~= "string" then return {} end
    local chunk = loadstring(data)
    if not chunk then return {} end
    setfenv(chunk, {})
    local ok, ids = pcall(chunk)
    return ok and type(ids) == "table" and ids or {}
end

function addon.GetAreaMapID(db, areaID)
    local support = db and db.Support
    local zoneDB = support and support.Get and support.Get("ZoneDB")
    local zones = zoneDB and zoneDB.private
    if not zones then return end
    if zones ~= cachedZones then
        cachedZones = zones
        mapIDs = ReadMapIDs(zones.areaIdToUiMapId)
        mapOverrides = ReadMapIDs(zones.areaIdToUiMapIdOverride)
    end
    local id = mapOverrides[areaID] or mapIDs[areaID]
    if type(id) == "number" and id > 0 and (not C_Map.GetMapInfo or C_Map.GetMapInfo(id)) then return id end
end

local function CanPlaceNativePin(mapID)
    return C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(mapID))
end

local function MapCanvas()
    local map = WorldMapFrame
    if map and map.GetMapID and map.SetMapID and map.GetCanvas and map.OnMapChanged and hooksecurefunc then
        return map:GetCanvas()
    end
end

local function CanLoadMap()
    return not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn
        and (not InCombatLockdown or not InCombatLockdown())
end

function addon.GetResultMapPins(entry)
    local pins = {}
    if not C_Map then return pins end
    local db = _G.LibQuestieDB
    local seenPinKeys = {}
    local function AddLocation(location, name)
        if not location.x or not location.y or (location.x == 0 and location.y == 0) then return end
        local mapID = addon.GetAreaMapID(db, location.areaID)
        if not mapID or not (CanPlaceNativePin(mapID) or MapCanvas() or CanLoadMap()) then return end
        local key = ("%d:%s:%s"):format(mapID, location.x, location.y)
        if seenPinKeys[key] then return end
        seenPinKeys[key] = true
        pins[#pins + 1] = {
            mapID = mapID, x = location.x / 100, y = location.y / 100, name = name,
            label = ("%s (%.1f, %.1f)"):format(location.name, location.x, location.y),
        }
    end
    local function AddEntity(entityType, id, name)
        local entity = db and db[entityType]
        if not entity or not entity.Get then return end
        for _, location in ipairs(addon.GetEntityLocations(entity, id)) do
            AddLocation(location, name)
        end
    end
    if entry.pinTargetName then
        AddLocation(entry, entry.pinTargetName)
    elseif entry.kind == "npc" then
        AddEntity("Npc", entry.id, entry.name)
    elseif entry.pinEntity then
        AddEntity(entry.pinEntity, entry.pinEntityID, entry.name)
    elseif entry.kind == "quest" then
        local quests = db and db.Quest
        local starters = quests and quests.Get and quests.Get(entry.id, "startedBy")
        for index, entityType in ipairs({ "Npc", "Object" }) do
            for _, id in ipairs(starters and starters[index] or {}) do
                AddEntity(entityType, id, entry.name)
            end
        end
    end
    return pins
end

local function OpenMap(mapID)
    if CanLoadMap() then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    local map = WorldMapFrame
    if not map or not map.SetMapID or (InCombatLockdown and InCombatLockdown()) then return end
    if not map:IsShown() then
        if ShowUIPanel then ShowUIPanel(map) else map:Show() end
    end
    if map:IsShown() then map:SetMapID(mapID) end
end

local function UpdateMarker()
    local location = markerLocation
    if not location or WorldMapFrame:GetMapID() ~= location.mapID then
        marker:Hide()
        return
    end
    local canvas = marker:GetParent()
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * location.x, -canvas:GetHeight() * location.y)
    marker:Show()
end

function addon.AddResultMapPin(location)
    if not C_Map then return false end
    if CanPlaceNativePin(location.mapID) then
        local ok, placed = pcall(function()
            return C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(location.mapID, location.x, location.y))
        end)
        if ok and placed then
            if marker then
                markerLocation = nil
                marker:Hide()
            end
            pcall(OpenMap, location.mapID)
            return true
        end
    end
    if CanLoadMap() then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    local canvas = MapCanvas()
    if not canvas then return false end
    if not marker then
        marker = CreateFrame("Button", nil, canvas)
        marker:SetSize(20, 20)
        marker:SetFrameLevel(canvas:GetFrameLevel() + 50)
        marker:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
        marker:RegisterForClicks("RightButtonUp")
        marker:SetScript("OnClick", function()
            markerLocation = nil
            marker:Hide()
            if GameTooltip:IsOwned(marker) then GameTooltip:Hide() end
        end)
        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine((markerLocation.name:gsub("|", "||")))
            GameTooltip:AddLine(markerLocation.label)
            GameTooltip:AddLine("Right-click to remove", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function() if GameTooltip:IsOwned(marker) then GameTooltip:Hide() end end)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdateMarker)
        WorldMapFrame:HookScript("OnShow", UpdateMarker)
        canvas:HookScript("OnSizeChanged", UpdateMarker)
    end
    markerLocation = location
    pcall(OpenMap, location.mapID)
    UpdateMarker()
    return true
end
