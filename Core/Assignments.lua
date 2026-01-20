--[[
    QRaidAssignments - Assignment System
    Manages raid assignments linked to triggers
    Includes spell usage, countdown timers, and TTS alerts
]]

---@class QRA
local QRA = QRA
QRA.Assignments = {}

--------------------------------------------------
-- Constants
--------------------------------------------------
QRA.Assignments.AlertTypes = {
    TTS = "TTS",           -- Text-to-speech
    SOUND = "SOUND",       -- Sound file
    SCREEN = "SCREEN",     -- On-screen text
    CHAT = "CHAT",         -- Chat message
}

--------------------------------------------------
-- State Management
--------------------------------------------------
local assignments = {}         -- All configured assignments
local activeCountdowns = {}    -- Currently running countdown timers

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Generate a unique ID for an assignment
---@return string
local function GenerateAssignmentID()
    return string.format("assign_%s_%s", time(), math.random(1000, 9999))
end

--- Format time for display (MM:SS or SS)
---@param seconds number
---@return string
local function FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    return string.format("%d", seconds)
end

--------------------------------------------------
-- Assignment Creation
--------------------------------------------------

--- Create a new assignment
---@param config table Assignment configuration
---@return Assignment Assignment The configured assignment object
function QRA.Assignments.Create(config)
    ---@type Assignment
    local assignment = {
        id = GenerateAssignmentID(),
        enabled = true,
        version = 1,

        -- Trigger link
        triggerId = config.triggerId,
        counterFormula = config.counterFormula or "*",  -- Counter formula (e.g., "1,3,5", ">2,+<6")

        -- Who receives this assignment
        assignTarget = config.assignTarget or "ALL",  -- Target string (e.g., "ALL", "TANK", "HPAL1", "PlayerName")

        -- What to do
        spellId = config.spellId,           -- Spell to use (optional)
        spellName = config.spellName or (config.spellId and C_Spell.GetSpellName(config.spellId)) or nil,
        targetPlayer = config.targetPlayer,  -- Who to target with spell (optional)
        message = config.message,            -- Custom message

        -- Alert settings
        alertType = config.alertType or QRA.Assignments.AlertTypes.TTS,
        countdownTime = config.countdownTime or 5,  -- Seconds before event to alert
        activateIn = config.activateIn,             -- Delay assignment activation (optional)
        soundFile = config.soundFile,               -- Custom sound file path

        -- Metadata
        createdAt = time(),
        lastExecuted = nil,
    }

    return assignment
end

--------------------------------------------------
-- Assignment Management
--------------------------------------------------

--- Add an assignment
---@param assignment Assignment The assignment to add
function QRA.Assignments.Add(assignment)
    if not assignment or not assignment.id then
        QRA.Debug("Assignments: Invalid assignment")
        return
    end

    assignments[assignment.id] = assignment
    QRA.Debug("Assignments: Added", assignment.id)

    -- Save to DB
    QRA.Assignments.SaveToDB()
end

--- Remove an assignment
---@param assignmentId string The assignment ID to remove
function QRA.Assignments.Remove(assignmentId)
    if assignments[assignmentId] then
        assignments[assignmentId] = nil
        QRA.Debug("Assignments: Removed", assignmentId)
        QRA.Assignments.SaveToDB()
    end
end

--- Update an existing assignment
---@param assignmentId string The assignment ID
---@param updates table Fields to update
function QRA.Assignments.Update(assignmentId, updates)
    local assignment = assignments[assignmentId]
    if not assignment then
        QRA.Debug("Assignments: Cannot update, not found", assignmentId)
        return
    end

    for key, value in pairs(updates) do
        if key ~= "id" and key ~= "createdAt" then  -- Don't allow changing ID or creation time
            assignment[key] = value
        end
    end

    QRA.Debug("Assignments: Updated", assignmentId)
    QRA.Assignments.SaveToDB()
end

--- Get an assignment by ID
---@param assignmentId string
---@return table|nil
function QRA.Assignments.Get(assignmentId)
    return assignments[assignmentId]
end

--- Get all assignments
---@return table
function QRA.Assignments.GetAll()
    return assignments
end

--- Get assignments for a specific trigger
---@param triggerId string
---@return Assignment[]
function QRA.Assignments.GetForTrigger(triggerId)
    local result = {}
    for id, assignment in pairs(assignments) do
        if assignment.triggerId == triggerId then
            table.insert(result, assignment)
        end
    end
    return result
end

--- Get assignments for a specific encounter
---@param encounterId number
---@return Assignment[]
function QRA.Assignments.GetAssignmentsByEncounterId(encounterId)
    local result = {}
    for _, assignment in pairs(assignments) do
        local trigger = QRA.Triggers.Get(assignment.triggerId)
        if trigger and trigger.encounterId == encounterId then
            table.insert(result, assignment)
        end
    end
    return result
end

--- Get assignments as an ordered list
---@return Assignment[]
function QRA.Assignments.GetAsList()
    local list = {}
    for id, assignment in pairs(assignments) do
        table.insert(list, assignment)
    end
    -- Sort by creation time
    table.sort(list, function(a, b)
        return (a.createdAt or 0) < (b.createdAt or 0)
    end)
    return list
end

--------------------------------------------------
-- Countdown Management
--------------------------------------------------

--- Start a countdown for an assignment
---@param assignment table The assignment
---@param eventData table|nil Event data from trigger
local function StartCountdown(assignment, eventData)
    if assignment.countdownTime <= 0 then
        -- Execute immediately
        QRA.Assignments.ExecuteAlert(assignment, eventData)
        return
    end

    local countdownId = assignment.id .. "_" .. GetTime()
    local remaining = assignment.countdownTime

    -- Store countdown info
    activeCountdowns[countdownId] = {
        assignment = assignment,
        remaining = remaining,
        startTime = GetTime(),
    }

    -- Create countdown ticker
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        remaining = remaining - 1

        if remaining <= 0 then
            QRA.Assignments.ExecuteAlert(assignment, eventData)
            activeCountdowns[countdownId] = nil
            ticker:Cancel()
        end
    end, assignment.countdownTime)

    activeCountdowns[countdownId].ticker = ticker

    -- Initial notification
    -- QRA.Debug("Assignments: Starting countdown for", assignment.id, "for", assignment.countdownTime, "seconds")
    QRA.Notifications.ShowCountdown(assignment, assignment.countdownTime)
end

--- Cancel all active countdowns
function QRA.Assignments.CancelAllCountdowns()
    for id, countdown in pairs(activeCountdowns) do
        if countdown.ticker then
            countdown.ticker:Cancel()
        end
    end
    wipe(activeCountdowns)
end

--------------------------------------------------
-- Assignment Execution
--------------------------------------------------

--- Execute assignments for a specific trigger
---@param triggerId string The trigger that fired
---@param eventData table|nil Data from the triggering event
---@param counter number The current counter value
function QRA.Assignments.ExecuteForTrigger(triggerId, eventData, counter)
    local triggerAssignments = QRA.Assignments.GetForTrigger(triggerId)

    for _, assignment in ipairs(triggerAssignments) do
        if assignment.enabled then
            -- Check if this counter matches assignment's formula
            if QRA.CounterFormula.Matches(assignment.counterFormula, counter) then
                -- Check if current player is a target for this assignment
                local assignTarget = assignment.assignTarget or "ALL"
                local isTarget = QRA.AssignTarget.IsCurrentPlayerTarget(assignTarget)

                if isTarget then
                    QRA.Debug("Assignments: Executing", assignment.id, "for trigger", triggerId, "counter", counter, "target", assignTarget)
                    
                    -- Check if we should delay the assignment activation
                    if assignment.activateIn and assignment.activateIn > 0 then
                        QRA.Debug("Assignments: Delaying assignment activation by", assignment.activateIn, "seconds")
                        QRA.DelayedInvoke(assignment.activateIn, function()
                            StartCountdown(assignment, eventData)
                        end)
                    else
                        -- Execute immediately
                        StartCountdown(assignment, eventData)
                    end
                else
                    QRA.Debug("Assignments: Skipping", assignment.id, "- current player not in target", assignTarget)
                end
            end
        end
    end
end

--- Execute the alert for an assignment
---@param assignment table The assignment
---@param eventData table|nil Event data
function QRA.Assignments.ExecuteAlert(assignment, eventData)
    QRA.Debug("Assignments: Executing alert for assignment", assignment)
    assignment.lastExecuted = time()

    -- Build the alert message
    local message = assignment.message
    if not message and assignment.spellName then
        message = string.format("Use %s", assignment.spellName)
    end
    message = message or "Assignment triggered!"

    -- Append target if specified
    if assignment.targetPlayer then
        message = string.format("%s on %s", message, assignment.targetPlayer)
    end

    -- Execute based on alert type
    QRA.Notifications.Notify(assignment.alertType, message, assignment.soundFile)

    -- Also show on screen for most alert types
    -- if assignment.alertType ~= QRA.Assignments.AlertTypes.SCREEN then
    --     QRA.Notifications.ShowOnScreen(message, 3)  -- Brief on-screen display
    -- end

    QRA.Debug("Assignments: Alert executed -", message)
end

--------------------------------------------------
-- Persistence
--------------------------------------------------

--- Save assignments to the database
function QRA.Assignments.SaveToDB()
    if not QRA.DB then return end
    QRA.DB.assignments = {}

    for id, assignment in pairs(assignments) do
        QRA.DB.assignments[id] = assignment
    end

    QRA.Debug("Assignments: Saved to DB")
end

--- Load assignments from the database
function QRA.Assignments.LoadFromDB()
    if not QRA.DB or not QRA.DB.assignments then return end

    wipe(assignments)
    for id, assignment in pairs(QRA.DB.assignments) do
        assignments[id] = assignment
    end

    QRA.Debug("Assignments: Loaded", QRA.TableCount(assignments), "from DB")
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Assignments.Initialize()
    QRA.Assignments.LoadFromDB()
    QRA.Debug("Assignments: Module initialized")
end
