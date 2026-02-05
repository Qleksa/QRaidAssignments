--[[
    QRaidAssignments - Assignment Display
    Shows a preview of assignments for the current boss zone
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

QRA.AssignmentDisplay = {}

local displayFrame = nil
local currentEncounterId = nil
local MOVER_GROUP = "QRA Movers"
local LINE_HEIGHT = 20
local MAX_VISIBLE_LINES = 15

--- Update display frame position from saved settings
local function UpdateDisplayPosition(point, x, y)
    if not QRA.Settings.assignmentDisplay then
        QRA.Settings.assignmentDisplay = { position = {} }
    end
    QRA.Settings.assignmentDisplay.position.point = point
    QRA.Settings.assignmentDisplay.position.xOfs = x
    QRA.Settings.assignmentDisplay.position.yOfs = y

    if displayFrame then
        displayFrame:ClearAllPoints()
        AF.SetPoint(displayFrame, point, QRA.UIParent, x, y)
    end
end

--- Build sorted list of assignments for an encounter
---@param encounterId number
---@return table assignments Array of assignment info tables
local function BuildAssignmentList(encounterId)
    local result = {}
    local triggers = QRA.Triggers.GetTriggersByEncounterId(encounterId)

    if not triggers or #triggers == 0 then
        return result
    end

    -- Get current raid roster for target resolution
    local roster = QRA.RaidRoster.GetActiveRoster()

    for _, trigger in ipairs(triggers) do
        -- Skip disabled triggers
        if trigger.enabled ~= false then
            local triggerName = trigger.name or ""

            -- Use trigger details as fallback if no name
            if triggerName == "" then
                if trigger.type == "TIMER" and trigger.time then
                    triggerName = trigger.time .. "s Timer"
                elseif trigger.spellName then
                    triggerName = trigger.spellName
                elseif trigger.spellId then
                    triggerName = "Spell " .. trigger.spellId
                else
                    triggerName = "Trigger"
                end
            end

            -- Get timer value for sorting (0 if not a timer)
            local sortTime = 0
            if trigger.type == "TIMER" and trigger.time then
                sortTime = trigger.time
            end

            -- Process assignments
            if trigger.assignments and #trigger.assignments > 0 then
                for _, assignment in ipairs(trigger.assignments) do
                    -- Skip disabled assignments
                    if assignment.enabled ~= false then
                        -- Resolve target to player names
                        local targetNames = QRA.AssignTarget.ResolveToNames(assignment.assignTarget, roster)
                        local targetDisplay = table.concat(targetNames, ", ")

                        -- Fallback to target string if no resolution
                        if targetDisplay == "" then
                            targetDisplay = assignment.assignTarget
                        end

                        -- Build assignment info
                        local info = {
                            triggerName = triggerName,
                            spellId = assignment.spellId,
                            target = targetDisplay,
                            activateIn = assignment.activateIn,
                            sortTime = sortTime,
                            sortOrder = (trigger.type == "TIMER") and 0 or 1,
                        }

                        table.insert(result, info)
                    end
                end
            end
        end
    end

    -- Sort: Timer triggers first (by time), then others
    table.sort(result, function(a, b)
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        if a.sortTime ~= b.sortTime then
            return a.sortTime < b.sortTime
        end
        return a.triggerName < b.triggerName
    end)

    return result
end

--- Create the display frame
local function CreateDisplayFrame()
    if displayFrame then
        return displayFrame
    end

    displayFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_AssignmentDisplay",
        "Assignments",
        350,
        300
    )

    -- Apply saved position
    local pos = QRA.Settings.assignmentDisplay.position
    displayFrame:ClearAllPoints()
    AF.SetPoint(displayFrame, pos.point or "CENTER", QRA.UIParent, pos.xOfs or 0, pos.yOfs or 0)
    displayFrame:SetFrameStrata("MEDIUM")
    displayFrame:Hide()

    -- Content area with scroll
    local scrollFrame = CreateFrame("ScrollFrame", nil, displayFrame, "UIPanelScrollFrameTemplate")
    AF.SetPoint(scrollFrame, "TOPLEFT", displayFrame, 10, -35)
    AF.SetPoint(scrollFrame, "BOTTOMRIGHT", displayFrame, -30, 10)
    displayFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(300, 1000)
    scrollFrame:SetScrollChild(scrollChild)
    displayFrame.scrollChild = scrollChild

    -- Add to UISpecialFrames for ESC key handling
    table.insert(UISpecialFrames, displayFrame:GetName())

    -- Create mover
    AF.CreateMover(displayFrame, MOVER_GROUP, "Assignment Display", UpdateDisplayPosition)

    return displayFrame
end

--- Refresh the assignment display
local function RefreshDisplay()
    if not displayFrame or not displayFrame:IsShown() or not currentEncounterId then
        return
    end

    local assignments = BuildAssignmentList(currentEncounterId)

    -- Clear existing lines
    if displayFrame.lines then
        for _, line in ipairs(displayFrame.lines) do
            line:Hide()
            line:SetParent(nil)
        end
    end
    displayFrame.lines = {}

    local yOffset = -5
    local scrollChild = displayFrame.scrollChild

    -- Create lines for each assignment
    for i, info in ipairs(assignments) do
        local line = CreateFrame("Frame", nil, scrollChild)
        AF.SetPoint(line, "TOPLEFT", scrollChild, 5, yOffset)
        AF.SetWidth(line, 300)
        AF.SetHeight(line, LINE_HEIGHT)

        local xOffset = 0

        -- Spell icon (if available)
        if info.spellId then
            local icon = line:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            AF.SetPoint(icon, "LEFT", line, xOffset, 0)

            local spellTexture = C_Spell.GetSpellTexture(info.spellId)
            if spellTexture then
                icon:SetTexture(spellTexture)
            else
                icon:SetTexture(134400)  -- Default icon
            end

            xOffset = xOffset + 20
        end

        -- Trigger name
        local triggerText = AF.CreateFontString(line, info.triggerName .. ":", "softlime")
        AF.SetPoint(triggerText, "LEFT", line, xOffset, 0)
        triggerText:SetJustifyH("LEFT")

        -- Assignment details (on next line)
        yOffset = yOffset - LINE_HEIGHT
        local detailLine = CreateFrame("Frame", nil, scrollChild)
        AF.SetPoint(detailLine, "TOPLEFT", scrollChild, 15, yOffset)
        AF.SetWidth(detailLine, 290)
        AF.SetHeight(detailLine, LINE_HEIGHT)

        local detailText = info.target
        if info.activateIn and info.activateIn > 0 then
            detailText = detailText .. " (in " .. info.activateIn .. "s)"
        end

        local detail = AF.CreateFontString(detailLine, detailText, "white")
        AF.SetPoint(detail, "LEFT", detailLine, 0, 0)
        detail:SetJustifyH("LEFT")
        detail:SetWordWrap(true)

        table.insert(displayFrame.lines, line)
        table.insert(displayFrame.lines, detailLine)

        yOffset = yOffset - LINE_HEIGHT - 3
    end

    -- Show message if no assignments
    if #assignments == 0 then
        local noAssignmentsText = AF.CreateFontString(scrollChild, "No assignments for this encounter", "gray")
        AF.SetPoint(noAssignmentsText, "TOP", scrollChild, 0, -20)
        table.insert(displayFrame.lines, noAssignmentsText)
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.abs(yOffset) + 50)
end

--- Show assignment display for a specific encounter
---@param encounterId number
---@param bossName? string Optional boss name for title
function QRA.AssignmentDisplay.ShowForEncounter(encounterId, bossName)
    if not QRA.Settings.assignmentDisplay.enabled then
        return
    end

    if not displayFrame then
        CreateDisplayFrame()
    end

    currentEncounterId = encounterId

    -- Update title
    local title = bossName and ("Assignments - " .. bossName) or "Assignments"
    displayFrame:SetTitle(title)

    RefreshDisplay()
    displayFrame:Show()
end

--- Hide assignment display
function QRA.AssignmentDisplay.Hide()
    if displayFrame then
        displayFrame:Hide()
        currentEncounterId = nil
    end
end

--- Check if display is visible
---@return boolean
function QRA.AssignmentDisplay.IsVisible()
    return displayFrame ~= nil and displayFrame:IsShown()
end

--- Refresh the current display (called when data changes)
function QRA.AssignmentDisplay.Refresh()
    RefreshDisplay()
end

--- Initialize assignment display module
function QRA.AssignmentDisplay.Initialize()
    QRA.Debug("AssignmentDisplay: Module Initialized")
end
