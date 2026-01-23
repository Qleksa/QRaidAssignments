--[[
    QRaidAssignments - Counter Formula Parser
    Parses and evaluates counter formulas like "1,3,5", ">2,+<6", "1%3"

    Syntax:
    * = All counters
    5 = Only 5th
    !4 = All except 4th
    1-5 = 1st through 5th
    <3 = Less than 3 (1, 2)
    <=3 = Less than or equal (1, 2, 3)
    >2 = Greater than 2 (3, 4, 5, ...)
    >=2 = Greater than or equal (2, 3, 4, ...)
    1%3 = Loop: 1, 4, 7, 10, ... (every 3rd starting at 1)
    2%4 = Loop: 2, 6, 10, 14, ... (every 4th starting at 2)

    Combining:
    1,3,5 = OR (1st OR 3rd OR 5th)
    >3,+<7 = AND after comma (more than 3 AND less than 7)
]]

---@class QRA
local QRA = select(2, ...)
QRA.CounterFormula = {}

--- Parse a single term
---@param term string
---@return table|nil { type, value, ... }
local function ParseTerm(term)
    term = strtrim(term)

    -- Check for AND prefix
    local isAnd = false
    if term:sub(1, 1) == "+" then
        isAnd = true
        term = strtrim(term:sub(2))
    end

    -- All: "*"
    if term == "*" then
        return { type = "all", isAnd = isAnd }
    end

    -- Loop/Modulo: "1%3" means counter % loopSize == position
    local position, loopSize = term:match("^(%d+)%%(%d+)$")
    if position and loopSize then
        return {
            type = "loop",
            position = tonumber(position),
            loopSize = tonumber(loopSize),
            isAnd = isAnd
        }
    end

    -- Range: "1-5"
    local rangeStart, rangeEnd = term:match("^(%d+)%-(%d+)$")
    if rangeStart and rangeEnd then
        return {
            type = "range",
            min = tonumber(rangeStart),
            max = tonumber(rangeEnd),
            isAnd = isAnd
        }
    end

    -- Not: "!4"
    local notValue = term:match("^!(%d+)$")
    if notValue then
        return { type = "not", value = tonumber(notValue), isAnd = isAnd }
    end

    -- Comparison: ">2", "<=3", etc.
    local op, num = term:match("^([<>]=?)(%d+)$")
    if op and num then
        return {
            type = "comparison",
            op = op,
            value = tonumber(num),
            isAnd = isAnd
        }
    end

    -- Single number: "3"
    local single = term:match("^(%d+)$")
    if single then
        return { type = "single", value = tonumber(single), isAnd = isAnd }
    end

    return nil -- Invalid term
end

--- Check if counter matches a single term
---@param term table Parsed term
---@param counter number
---@return boolean
local function MatchesTerm(term, counter)
    if term.type == "all" then
        return true
    elseif term.type == "single" then
        return counter == term.value
    elseif term.type == "not" then
        return counter ~= term.value
    elseif term.type == "range" then
        return counter >= term.min and counter <= term.max
    elseif term.type == "loop" then
        -- 1%3 means: 1, 4, 7, 10... (position + n*loopSize)
        -- Formula: (counter - position) % loopSize == 0 AND counter >= position
        if counter < term.position then return false end
        return (counter - term.position) % term.loopSize == 0
    elseif term.type == "comparison" then
        if term.op == "<" then return counter < term.value
        elseif term.op == "<=" then return counter <= term.value
        elseif term.op == ">" then return counter > term.value
        elseif term.op == ">=" then return counter >= term.value
        end
    end
    return false
end

--- Check if counter matches formula
---@param formula string|nil The formula string
---@param counter number The current counter value
---@return boolean
function QRA.CounterFormula.Matches(formula, counter)
    -- Must specify formula, blank/nil doesn't match
    if not formula or formula == "" then
        return false
    end

    -- "*" means match all
    if formula == "*" then
        return true
    end

    -- Split by comma
    local segments = { strsplit(",", formula) }
    local terms = {}

    for _, segment in ipairs(segments) do
        local parsed = ParseTerm(segment)
        if parsed then
            table.insert(terms, parsed)
        end
    end

    if #terms == 0 then
        return false -- Invalid formula
    end

    -- Process with AND/OR logic
    -- Start evaluating, group AND chains
    local result = false
    local andChainResult = nil

    for _, term in ipairs(terms) do
        local termMatch = MatchesTerm(term, counter)

        if term.isAnd then
            -- AND with previous result
            if andChainResult == nil then
                andChainResult = termMatch
            else
                andChainResult = andChainResult and termMatch
            end
        else
            -- OR: flush previous AND chain, start new
            if andChainResult ~= nil then
                result = result or andChainResult
            end
            andChainResult = termMatch
        end
    end

    -- Flush final AND chain
    if andChainResult ~= nil then
        result = result or andChainResult
    end

    return result
end

--- Get the maximum counter a formula will match (nil if infinite)
---@param formula string|nil
---@return number|nil
function QRA.CounterFormula.GetMaxCounter(formula)
    if not formula or formula == "" or formula == "*" then
        return nil -- Infinite or invalid
    end

    local segments = { strsplit(",", formula) }
    local max = 0
    local hasInfinite = false

    for _, segment in ipairs(segments) do
        local parsed = ParseTerm(segment)
        if parsed then
            if parsed.type == "all" then
                hasInfinite = true
            elseif parsed.type == "single" then
                max = math.max(max, parsed.value)
            elseif parsed.type == "not" then
                hasInfinite = true -- !4 matches 1,2,3,5,6,7...
            elseif parsed.type == "range" then
                max = math.max(max, parsed.max)
            elseif parsed.type == "loop" then
                hasInfinite = true -- Loops are infinite
            elseif parsed.type == "comparison" then
                if parsed.op == ">" or parsed.op == ">=" then
                    hasInfinite = true
                elseif parsed.op == "<" then
                    max = math.max(max, parsed.value - 1)
                elseif parsed.op == "<=" then
                    max = math.max(max, parsed.value)
                end
            end
        end
    end

    if hasInfinite then
        return nil
    end

    return max > 0 and max or nil
end

--- Validate formula syntax
---@param formula string
---@return boolean isValid, string|nil errorMessage
function QRA.CounterFormula.Validate(formula)
    -- Blank is invalid - must specify
    if not formula or formula == "" then
        return false, "Counter formula is required"
    end

    -- "*" is valid
    if formula == "*" then
        return true
    end

    local segments = { strsplit(",", formula) }
    local hasValidTerm = false

    for i, segment in ipairs(segments) do
        local parsed = ParseTerm(segment)
        if not parsed then
            return false, "Invalid term: " .. segment
        end

        -- Validate range
        if parsed.type == "range" and parsed.min > parsed.max then
            return false, "Invalid range: " .. segment
        end

        -- Validate loop
        if parsed.type == "loop" then
            if parsed.loopSize <= 0 then
                return false, "Loop size must be positive: " .. segment
            end
            if parsed.position <= 0 then
                return false, "Loop position must be positive: " .. segment
            end
            if parsed.position > parsed.loopSize then
                return false, "Loop position cannot exceed loop size: " .. segment
            end
        end

        -- First term cannot be AND
        if i == 1 and parsed.isAnd then
            return false, "First term cannot start with '+'"
        end

        hasValidTerm = true
    end

    return hasValidTerm, nil
end

--- Check if assignment formula can ever match trigger formula
---@param triggerFormula string
---@param assignmentFormula string
---@return boolean canMatch, string|nil warning
function QRA.CounterFormula.CanMatch(triggerFormula, assignmentFormula)
    -- Validate both first
    local triggerValid = QRA.CounterFormula.Validate(triggerFormula)
    local assignmentValid = QRA.CounterFormula.Validate(assignmentFormula)

    if not triggerValid or not assignmentValid then
        return false, "Invalid formula"
    end

    -- If either is "*", they can match
    if triggerFormula == "*" or assignmentFormula == "*" then
        return true
    end

    -- Test first 100 counters for overlap
    local triggerMax = QRA.CounterFormula.GetMaxCounter(triggerFormula) or 100
    local testMax = math.min(triggerMax, 100)

    for i = 1, testMax do
        if QRA.CounterFormula.Matches(triggerFormula, i) and
           QRA.CounterFormula.Matches(assignmentFormula, i) then
            return true
        end
    end

    return false, "Assignment will never fire (no overlap with trigger)"
end

--- Get tips table for UI
---@return table Array of tip strings
function QRA.CounterFormula.GetTips()
    return {
        "|cff00ff00Counter Formula Syntax|r",
        " ",
        "|cffffd100Basic:|r",
        "  |cff00ff00*|r = All counters",
        "  |cff00ff005|r = Only 5th",
        "  |cff00ff00!4|r = All except 4th",
        "  |cff00ff001-5|r = 1st through 5th",
        " ",
        "|cffffd100Comparisons:|r",
        "  |cff00ff00>3|r = More than 3 (4, 5, 6, ...)",
        "  |cff00ff00<=2|r = Up to 2 (1, 2)",
        " ",
        "|cffffd100Loops:|r",
        "  |cff00ff001%3|r = 1, 4, 7, 10, ...",
        "  |cff00ff002%4|r = 2, 6, 10, 14, ...",
        " ",
        "|cffffd100Combining:|r",
        "  |cff00ff001,3,5|r = 1 OR 3 OR 5",
        "  |cff00ff00>3,+<7|r = More than 3 AND less than 7",
    }
end
