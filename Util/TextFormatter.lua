--[[
    QRaidAssignments - Text Formatter
    Handles formatting of text with raid icons and spell icons
]]

---@class QRA
local QRA = select(2, ...)

QRA.TextFormatter = {}

-- Raid Target Icon mapping
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

---@param text string The text to format
---@return string formattedText The formatted text with WoW texture markup
function QRA.TextFormatter.Format(text)
    if not text or text == "" then
        return ""
    end

    local formatted = text

    -- Replace named raid icons with {rt#} syntax
    for iconName, iconNum in pairs(RAID_ICONS) do
        formatted = formatted:gsub("{" .. iconName .. "}", "{rt" .. iconNum .. "}")
    end

    -- Replace spell icons {spell:12345} with texture markup
    formatted = formatted:gsub("{spell:(%d+)}", function(spellId)
        local spellIdNum = tonumber(spellId)
        if not spellIdNum then return "" end

        local spellTexture = C_Spell.GetSpellTexture(spellIdNum)
        if spellTexture then
            return "|T" .. spellTexture .. ":16:16|t"
        end
        return ""
    end)

    return formatted
end

--- Test the formatter with sample text
function QRA.TextFormatter.Test()
    local testText = "Tank {skull} - Use {spell:871} - Healer {cross}"
    local formatted = QRA.TextFormatter.Format(testText)
    QRA.Print("Original:", testText)
    QRA.Print("Formatted:", formatted)
end
