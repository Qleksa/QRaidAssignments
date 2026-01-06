--[[
    QRaidAssignments - Assignment Target Resolution
    Parses target strings and resolves to player names
    Supports: ALL, roles, classes, specs, and specific players
]]

local QRA = _G.QRA
QRA.AssignTarget = {}

--------------------------------------------------
-- Target Types
--------------------------------------------------
---@enum AssignTargetType
QRA.AssignTarget.Types = {
    ALL = "ALL",           -- Everyone in raid
    ROLE = "ROLE",         -- Tank, Healer, DPS
    CLASS = "CLASS",       -- Any spec of a class (e.g., WARR)
    SPEC = "SPEC",         -- Specific spec (e.g., HPAL)
    PLAYER = "PLAYER",     -- Specific player by name
}

--------------------------------------------------
-- Target Parsing
--------------------------------------------------

--- Parse a target string into its components
--- Examples: "ALL", "TANK", "WARR1", "HPAL2", "Qleksa"
---@param targetStr string
---@return table|nil targetInfo { type, value, index }
function QRA.AssignTarget.Parse(targetStr)
    if not targetStr or targetStr == "" then
        return nil
    end

    local str = strtrim(targetStr)
    local upperStr = str:upper()

    -- Check for "ALL"
    if upperStr == "ALL" then
        return {
            type = QRA.AssignTarget.Types.ALL,
            value = "ALL",
            index = nil,
        }
    end

    -- Check for role
    if QRA.ClassSpecs.IsRoleAbbrev(upperStr) then
        return {
            type = QRA.AssignTarget.Types.ROLE,
            value = upperStr,
            index = nil,  -- All of that role
        }
    end

    -- Check for numbered targets (e.g., WARR1, HPAL2)
    local abbrev, indexStr = str:match("^([A-Za-z]+)(%d+)$")
    if abbrev and indexStr then
        local abbrevUpper = abbrev:upper()
        local index = tonumber(indexStr)

        -- Check if it's a role with index
        if QRA.ClassSpecs.IsRoleAbbrev(abbrevUpper) then
            return {
                type = QRA.AssignTarget.Types.ROLE,
                value = abbrevUpper,
                index = index,
            }
        end

        -- Check if it's a spec
        if QRA.ClassSpecs.IsSpecAbbrev(abbrevUpper) then
            return {
                type = QRA.AssignTarget.Types.SPEC,
                value = abbrevUpper,
                index = index,
            }
        end

        -- Check if it's a class
        if QRA.ClassSpecs.IsClassAbbrev(abbrevUpper) then
            return {
                type = QRA.AssignTarget.Types.CLASS,
                value = abbrevUpper,
                index = index,
            }
        end
    end

    -- Check for spec without index (targets all of that spec)
    if QRA.ClassSpecs.IsSpecAbbrev(upperStr) then
        return {
            type = QRA.AssignTarget.Types.SPEC,
            value = upperStr,
            index = nil,
        }
    end

    -- Check for class without index (targets all of that class)
    if QRA.ClassSpecs.IsClassAbbrev(upperStr) then
        return {
            type = QRA.AssignTarget.Types.CLASS,
            value = upperStr,
            index = nil,
        }
    end

    -- Assume it's a player name
    return {
        type = QRA.AssignTarget.Types.PLAYER,
        value = str,  -- Keep original case for player names
        index = nil,
    }
end

--- Convert target info back to string
---@param targetInfo table
---@return string
function QRA.AssignTarget.ToString(targetInfo)
    if not targetInfo then return "" end

    if targetInfo.index then
        return targetInfo.value .. targetInfo.index
    end

    return targetInfo.value
end

--------------------------------------------------
-- Target Resolution
--------------------------------------------------

--- Resolve a target to player name(s)
---@param targetStr string The target string (e.g., "HPAL1", "TANK", "ALL")
---@param roster table|nil Optional roster to use
---@return table players Array of player data that match
function QRA.AssignTarget.Resolve(targetStr, roster)
    local targetInfo = QRA.AssignTarget.Parse(targetStr)
    if not targetInfo then
        return {}
    end

    roster = roster or QRA.RaidRoster.GetActiveRoster()
    local players = {}

    if targetInfo.type == QRA.AssignTarget.Types.ALL then
        -- Return all players
        for _, player in ipairs(roster) do
            table.insert(players, player)
        end

    elseif targetInfo.type == QRA.AssignTarget.Types.ROLE then
        if targetInfo.index then
            -- Specific Nth player of role
            local player = QRA.RaidRoster.GetNthPlayer(targetInfo.value, targetInfo.index, roster)
            if player then
                table.insert(players, player)
            end
        else
            -- All players of role
            players = QRA.RaidRoster.GetPlayersByRole(targetInfo.value, roster)
        end

    elseif targetInfo.type == QRA.AssignTarget.Types.CLASS then
        if targetInfo.index then
            -- Specific Nth player of class
            local player = QRA.RaidRoster.GetNthPlayer(targetInfo.value, targetInfo.index, roster)
            if player then
                table.insert(players, player)
            end
        else
            -- All players of class
            players = QRA.RaidRoster.GetPlayersByClass(targetInfo.value, roster)
        end

    elseif targetInfo.type == QRA.AssignTarget.Types.SPEC then
        if targetInfo.index then
            -- Specific Nth player of spec
            local player = QRA.RaidRoster.GetNthPlayer(targetInfo.value, targetInfo.index, roster)
            if player then
                table.insert(players, player)
            end
        else
            -- All players of spec
            players = QRA.RaidRoster.GetPlayersBySpec(targetInfo.value, roster)
        end

    elseif targetInfo.type == QRA.AssignTarget.Types.PLAYER then
        -- Specific player by name
        local player = QRA.RaidRoster.GetPlayerByName(targetInfo.value, roster)
        if player then
            table.insert(players, player)
        end
    end

    return players
end

--- Resolve target and return player names only
---@param targetStr string
---@param roster table|nil
---@return table names Array of player names
function QRA.AssignTarget.ResolveToNames(targetStr, roster)
    local players = QRA.AssignTarget.Resolve(targetStr, roster)
    local names = {}

    for _, player in ipairs(players) do
        table.insert(names, player.name)
    end

    return names
end

--- Check if current player is a target
---@param targetStr string
---@param roster table|nil
---@return boolean
function QRA.AssignTarget.IsCurrentPlayerTarget(targetStr, roster)
    local names = QRA.AssignTarget.ResolveToNames(targetStr, roster)
    local playerName = UnitName("player")

    for _, name in ipairs(names) do
        if name == playerName then
            return true
        end
    end

    return false
end

--------------------------------------------------
-- Display Helpers
--------------------------------------------------

--- Get a display-friendly version of a target string
--- Shows resolved names in parentheses when available
---@param targetStr string
---@param showResolved boolean|nil Whether to show resolved names
---@return string displayText
function QRA.AssignTarget.GetDisplayText(targetStr, showResolved)
    local targetInfo = QRA.AssignTarget.Parse(targetStr)
    if not targetInfo then
        return targetStr or ""
    end

    local displayText = QRA.AssignTarget.ToString(targetInfo)

    -- Add type-specific formatting
    if targetInfo.type == QRA.AssignTarget.Types.ALL then
        displayText = "All"
    elseif targetInfo.type == QRA.AssignTarget.Types.ROLE then
        local roleData = QRA.ClassSpecs.Roles[targetInfo.value]
        if roleData then
            displayText = roleData.name
            if targetInfo.index then
                displayText = displayText .. " #" .. targetInfo.index
            end
        end
    elseif targetInfo.type == QRA.AssignTarget.Types.CLASS then
        local classData = QRA.ClassSpecs.GetClassByAbbrev(targetInfo.value)
        if classData then
            displayText = classData.name
            if targetInfo.index then
                displayText = displayText .. " #" .. targetInfo.index
            end
        end
    elseif targetInfo.type == QRA.AssignTarget.Types.SPEC then
        local specData = QRA.ClassSpecs.GetSpecByAbbrev(targetInfo.value)
        if specData then
            displayText = specData.name
            if targetInfo.index then
                displayText = displayText .. " #" .. targetInfo.index
            end
        end
    end

    -- Optionally show resolved player names
    if showResolved then
        local names = QRA.AssignTarget.ResolveToNames(targetStr)
        if #names > 0 then
            if #names <= 3 then
                displayText = displayText .. " (" .. table.concat(names, ", ") .. ")"
            else
                displayText = displayText .. " (" .. #names .. " players)"
            end
        else
            displayText = displayText .. " (no match)"
        end
    end

    return displayText
end

--- Get colored display text
---@param targetStr string
---@param showResolved boolean|nil
---@return string coloredText
function QRA.AssignTarget.GetColoredDisplayText(targetStr, showResolved)
    local AF = _G.AbstractFramework
    local targetInfo = QRA.AssignTarget.Parse(targetStr)

    if not targetInfo then
        return targetStr or ""
    end

    local text = QRA.AssignTarget.GetDisplayText(targetStr, showResolved)

    -- Color based on type
    if targetInfo.type == QRA.AssignTarget.Types.ALL then
        return AF.WrapTextInColor(text, "accent")
    elseif targetInfo.type == QRA.AssignTarget.Types.ROLE then
        if targetInfo.value == "TANK" then
            return AF.WrapTextInColor(text, "skyblue")
        elseif targetInfo.value == "HEALER" then
            return AF.WrapTextInColor(text, "lime")
        else
            return AF.WrapTextInColor(text, "red")
        end
    elseif targetInfo.type == QRA.AssignTarget.Types.CLASS or targetInfo.type == QRA.AssignTarget.Types.SPEC then
        -- Use class color
        local classFile
        if targetInfo.type == QRA.AssignTarget.Types.CLASS then
            _, classFile = QRA.ClassSpecs.GetClassByAbbrev(targetInfo.value)
        else
            _, _, classFile = QRA.ClassSpecs.GetSpecByAbbrev(targetInfo.value)
        end

        if classFile then
            local r, g, b = QRA.ClassSpecs.GetClassColor(classFile)
            return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
        end
    end

    return text
end

--------------------------------------------------
-- Validation
--------------------------------------------------

--- Validate a target string
---@param targetStr string
---@return boolean isValid
---@return string|nil errorMsg
function QRA.AssignTarget.Validate(targetStr)
    if not targetStr or targetStr == "" then
        return false, "Target cannot be empty"
    end

    local targetInfo = QRA.AssignTarget.Parse(targetStr)

    if not targetInfo then
        return false, "Invalid target format"
    end

    -- All parsed targets are technically valid
    -- (player names can be anything)
    return true, nil
end

-- QRA.Debug("AssignTarget: Module loaded")
