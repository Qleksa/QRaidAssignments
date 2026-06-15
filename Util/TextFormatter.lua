--[[
    QRaidAssignments - Text Formatter
    Handles formatting of text with raid icons and spell icons
]]

---@class QRA
local QRA = select(2, ...)

QRA.TextFormatter = QRA.TextFormatter or {}

local RAID_ICONS = {
    ["star"] = 1,
    ["circle"] = 2,
    ["diamond"] = 3,
    ["triangle"] = 4,
    ["moon"] = 5,
    ["square"] = 6,
    ["cross"] = 7,
    ["skull"] = 8,
}

local function GetRaidIconMarkup(iconNum)
    return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16:16:0:0|t", iconNum)
end

local function GetSpellTextureById(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellId)
        if texture then
            return texture
        end
    end

    if GetSpellTexture then
        return GetSpellTexture(spellId)
    end

    return nil
end

---@param text string
---@return string
function QRA.TextFormatter.Format(text)
    if not text or text == "" then
        return ""
    end

    local formatted = text

    -- Normalize escaped pipes from editor/import sources so WoW markup renders.
    formatted = formatted:gsub("\\124", "|")
    formatted = formatted:gsub("||([cCrR])", "|%1")

    for iconName, iconNum in pairs(RAID_ICONS) do
        formatted = formatted:gsub("{" .. iconName .. "}", GetRaidIconMarkup(iconNum))
    end

    formatted = formatted:gsub("{rt([1-8])}", function(iconNum)
        return GetRaidIconMarkup(tonumber(iconNum) or 1)
    end)

    formatted = formatted:gsub("{spell:(%d+)}", function(spellId)
        local spellIdNum = tonumber(spellId)
        if not spellIdNum then
            return ""
        end

        local spellTexture = GetSpellTextureById(spellIdNum)
        if spellTexture then
            return "|T" .. spellTexture .. ":20:20|t"
        end

        return "{spell:" .. spellId .. "}"
    end)

    return formatted
end
