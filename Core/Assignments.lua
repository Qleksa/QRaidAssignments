--[[
    QRaidAssignments - Assignment System
    Manages raid assignments embedded within triggers
    Includes spell usage, countdown timers, and TTS alerts

    STORAGE MODEL:
    - Assignments are stored inside their parent trigger's `assignments` array
    - Orphaned assignments (whose trigger was deleted) go to QRA.DB.orphanedAssignments
]]

---@class QRA
local QRA = select(2, ...)
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
---@return Assignment The configured assignment object
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

--- Add an assignment to a trigger
---@param triggerId string The trigger ID to add assignment to
---@param assignment Assignment The assignment to add
---@return boolean success
function QRA.Assignments.Add(triggerId, assignment)
    if not assignment or not assignment.id then
        QRA.Debug("Assignments: Invalid assignment")
        return false
    end

    local trigger = QRA.Triggers.Get(triggerId)
    if not trigger then
        QRA.Debug("Assignments: Trigger not found:", triggerId)
        return false
    end

    -- Initialize assignments array if needed
    if not trigger.assignments then
        trigger.assignments = {}
    end

    -- Set the triggerId on the assignment
    assignment.triggerId = triggerId

    -- Add to trigger's assignments
    table.insert(trigger.assignments, assignment)

    -- Save trigger changes
    QRA.Triggers.UpdateTrigger(trigger)

    QRA.Debug("Assignments: Added", assignment.id, "to trigger", triggerId)
    return true
end

--- Remove an assignment from its trigger
---@param triggerId string The trigger ID
---@param assignmentId string The assignment ID to remove
---@return boolean success
function QRA.Assignments.Remove(triggerId, assignmentId)
    local trigger = QRA.Triggers.Get(triggerId)
    if not trigger or not trigger.assignments then
        QRA.Debug("Assignments: Trigger not found or has no assignments:", triggerId)
        return false
    end

    for i, assignment in ipairs(trigger.assignments) do
        if assignment.id == assignmentId then
            table.remove(trigger.assignments, i)
            QRA.Triggers.UpdateTrigger(trigger)
            QRA.Debug("Assignments: Removed", assignmentId, "from trigger", triggerId)
            return true
        end
    end

    QRA.Debug("Assignments: Assignment not found:", assignmentId)
    return false
end

--- Update an existing assignment within a trigger
---@param triggerId string The trigger ID
---@param assignmentId string The assignment ID
---@param updates table Fields to update
---@return boolean success
function QRA.Assignments.Update(triggerId, assignmentId, updates)
    local trigger = QRA.Triggers.Get(triggerId)
    if not trigger or not trigger.assignments then
        QRA.Debug("Assignments: Trigger not found or has no assignments:", triggerId)
        return false
    end

    for _, assignment in ipairs(trigger.assignments) do
        if assignment.id == assignmentId then
            for key, value in pairs(updates) do
                if key ~= "id" and key ~= "createdAt" then
                    assignment[key] = value
                end
            end
            QRA.Triggers.UpdateTrigger(trigger)
            QRA.Debug("Assignments: Updated", assignmentId)
            return true
        end
    end

    QRA.Debug("Assignments: Assignment not found:", assignmentId)
    return false
end

--- Get an assignment by ID (searches all triggers and orphaned)
---@param assignmentId string
---@return Assignment|nil assignment
---@return string|nil triggerId
function QRA.Assignments.Get(assignmentId)
    -- Search in triggers
    for _, trigger in ipairs(QRA.DB.triggers or {}) do
        if trigger.assignments then
            for _, assignment in ipairs(trigger.assignments) do
                if assignment.id == assignmentId then
                    return assignment, trigger.id
                end
            end
        end
    end

    -- Search in orphaned assignments
    for _, assignment in ipairs(QRA.DB.orphanedAssignments or {}) do
        if assignment.id == assignmentId then
            return assignment, nil
        end
    end

    return nil, nil
end

--- Get all assignments for a specific trigger
---@param triggerId string
---@return Assignment[]
function QRA.Assignments.GetForTrigger(triggerId)
    local trigger = QRA.Triggers.Get(triggerId)
    return (trigger and trigger.assignments) or {}
end

--- Get all assignments across all triggers
---@return Assignment[]
function QRA.Assignments.GetAll()
    local all = {}
    for _, trigger in ipairs(QRA.DB.triggers or {}) do
        if trigger.assignments then
            for _, assignment in ipairs(trigger.assignments) do
                table.insert(all, assignment)
            end
        end
    end
    return all
end

--- Get assignments for a specific encounter
---@param encounterId number
---@return Assignment[]
function QRA.Assignments.GetByEncounterId(encounterId)
    local result = {}
    local triggers = QRA.Triggers.GetTriggersByEncounterId(encounterId)
    for _, trigger in ipairs(triggers) do
        if trigger.assignments then
            for _, assignment in ipairs(trigger.assignments) do
                table.insert(result, assignment)
            end
        end
    end
    return result
end

--------------------------------------------------
-- Orphaned Assignment Management
--------------------------------------------------

--- Get all orphaned assignments
---@return OrphanedAssignment[]
function QRA.Assignments.GetOrphaned()
    return QRA.DB.orphanedAssignments or {}
end

--- Move assignments to orphaned when their trigger is deleted
---@param triggerId string The trigger ID being deleted
---@param assignments Assignment[] The assignments to orphan
function QRA.Assignments.OrphanAssignments(triggerId, assignments)
    if not assignments or #assignments == 0 then return end

    if not QRA.DB.orphanedAssignments then
        QRA.DB.orphanedAssignments = {}
    end

    for _, assignment in ipairs(assignments) do
        ---@type OrphanedAssignment
        local orphaned = QRA.DeepCopy(assignment)
        orphaned.orphanedAt = time()
        orphaned.previousTriggerId = triggerId
        orphaned.triggerId = nil
        table.insert(QRA.DB.orphanedAssignments, orphaned)
    end

    QRA.Debug("Assignments: Orphaned", #assignments, "assignments from trigger", triggerId)
end

--- Adopt an orphaned assignment into a trigger
---@param assignmentId string The orphaned assignment ID
---@param triggerId string The trigger to adopt into
---@return boolean success
function QRA.Assignments.AdoptOrphan(assignmentId, triggerId)
    local orphaned = QRA.DB.orphanedAssignments or {}

    for i, assignment in ipairs(orphaned) do
        if assignment.id == assignmentId then
            -- Remove from orphaned list
            table.remove(orphaned, i)

            -- Clean up orphan metadata
            assignment.orphanedAt = nil
            assignment.previousTriggerId = nil
            assignment.triggerId = triggerId

            -- Add to trigger
            local trigger = QRA.Triggers.Get(triggerId)
            if trigger then
                if not trigger.assignments then
                    trigger.assignments = {}
                end
                table.insert(trigger.assignments, assignment)
                QRA.Triggers.UpdateTrigger(trigger)
                QRA.Debug("Assignments: Adopted orphan", assignmentId, "into trigger", triggerId)
                return true
            end
        end
    end

    return false
end

--- Delete an orphaned assignment permanently
---@param assignmentId string
---@return boolean success
function QRA.Assignments.DeleteOrphan(assignmentId)
    local orphaned = QRA.DB.orphanedAssignments or {}

    for i, assignment in ipairs(orphaned) do
        if assignment.id == assignmentId then
            table.remove(orphaned, i)
            QRA.Debug("Assignments: Deleted orphan", assignmentId)
            return true
        end
    end

    return false
end

--- Update an orphaned assignment
---@param assignmentId string
---@param updates table Fields to update
---@return boolean success
function QRA.Assignments.UpdateOrphan(assignmentId, updates)
    local orphaned = QRA.DB.orphanedAssignments or {}

    for _, assignment in ipairs(orphaned) do
        if assignment.id == assignmentId then
            for key, value in pairs(updates) do
                if key ~= "id" and key ~= "createdAt" and key ~= "orphanedAt" then
                    assignment[key] = value
                end
            end
            QRA.Debug("Assignments: Updated orphan", assignmentId)
            return true
        end
    end

    return false
end

--------------------------------------------------
-- Countdown Management
--------------------------------------------------

--- Start a countdown for an assignment
---@param assignment table The assignment
---@param eventData table|nil Event data from trigger
local function StartCountdown(assignment, eventData)
    if assignment.countdownTime == 0 then
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

    if QRA.Notifications and QRA.Notifications.CancelAllCountdowns then
        QRA.Notifications.CancelAllCountdowns()
    end
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

    QRA.Debug("Assignments: Found assignments", triggerAssignments)

    for _, assignment in ipairs(triggerAssignments) do
        if assignment.enabled then
            -- Check if this counter matches assignment's formula
            if QRA.CounterFormula.Matches(assignment.counterFormula, counter) then
                -- Check if current player is a target for this assignment
                local assignTarget = assignment.assignTarget or "ALL"
                local isTarget = QRA.AssignTarget.IsCurrentPlayerTarget(assignTarget)

                if isTarget then
                    -- QRA.Debug("Assignments: Executing", assignment.id, "for trigger", triggerId, "counter", counter, "target", assignTarget)

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
    assignment.lastExecuted = time()

    local message = assignment.message
    if message == "" and assignment.spellName then
        message = string.format("Use %s", assignment.spellName)
        if assignment.targetPlayer and assignment.targetPlayer ~= "" then
            message = message .. " on " .. assignment.targetPlayer
        end
    end
    message = message or "Assignment triggered!"

    QRA.Debug("Assignments: Alert executed -", message)
    QRA.Logger.Log("Executing Assignment Alert[" .. assignment.alertType .. "]: " .. message)
    QRA.Notifications.Notify(assignment.alertType, message, assignment.soundFile)
end

--------------------------------------------------
-- Persistence (No longer needed - assignments save with triggers)
--------------------------------------------------

--- SaveToDB is now a no-op since assignments are embedded in triggers
function QRA.Assignments.SaveToDB()
    -- Assignments are now saved as part of triggers
    -- This function kept for backward compatibility
    QRA.Debug("Assignments: SaveToDB called (no-op, embedded in triggers)")
end

--- LoadFromDB is now a no-op since assignments load with triggers
function QRA.Assignments.LoadFromDB()
    -- Assignments are now loaded as part of triggers
    -- This function kept for backward compatibility
    QRA.Debug("Assignments: LoadFromDB called (no-op, embedded in triggers)")
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Assignments.Initialize()
    -- Ensure orphanedAssignments exists
    if not QRA.DB.orphanedAssignments then
        QRA.DB.orphanedAssignments = {}
    end

    QRA.Debug("Assignments: Module initialized")
end
