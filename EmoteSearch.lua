local _, addon = ...
local emotes

local function GetEmotes()
    if emotes then return emotes end

    emotes = {}
    for key, token in pairs(_G) do
        local index = type(key) == "string" and key:match("^EMOTE(%d+)_TOKEN$")
        if index and type(token) == "string" and token ~= "" then
            local prefix = "EMOTE" .. index .. "_CMD"
            local name = _G[prefix .. 1]
            if name and name ~= "" then
                local aliases = { token:lower() }
                local aliasIndex = 1
                while _G[prefix .. aliasIndex] do
                    aliases[#aliases + 1] = _G[prefix .. aliasIndex]:lower():gsub("^/", "")
                    aliasIndex = aliasIndex + 1
                end
                emotes[#emotes + 1] = { kind = "emote", name = name, token = token, aliases = aliases }
            end
        end
    end
    table.sort(emotes, function(left, right)
        if left.name == right.name then return left.token < right.token end
        return left.name < right.name
    end)
    return emotes
end

function addon.SearchEmotes(query)
    query = query:gsub("^/", "")
    if query == "" then return GetEmotes() end
    if #query < 2 then return {} end
    local exact, partial = {}, {}
    for _, entry in ipairs(GetEmotes()) do
        local matched
        for _, alias in ipairs(entry.aliases) do
            if alias == query then
                matched = exact
                break
            elseif alias:find(query, 1, true) then
                matched = partial
            end
        end
        if matched then matched[#matched + 1] = entry end
    end
    for _, entry in ipairs(partial) do exact[#exact + 1] = entry end
    return exact, #exact == 0 and "No matching emotes." or nil
end

function addon.PerformSearchEmote(entry)
    local perform = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
    if not perform then return false end
    -- The client can play an emote even when the call returns a falsey value.
    perform(entry.token)
    return true
end
