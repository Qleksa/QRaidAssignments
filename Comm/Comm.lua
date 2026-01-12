---@class QRA
local QRA = QRA

if not QRA.AreLibsOkay() then
    QRA.Print("Required libraries are missing. Q's Raid Assignments cannot function properly.")
    return
end

QRA.Comm = {}

-- Export serialized triggers and assignments
---@param isForAddonChannel? boolean
---@return string
function QRA.Comm.Export(isForAddonChannel)
    QRA.Debug("Comm: Exporting Data")
    local triggers = QRA.Triggers.GetAll()

    if not triggers or #triggers == 0 then
        QRA.Print("Comm: No triggers found to export")
        return ""
    end

    for _, trigger in ipairs(triggers) do
        trigger.assignments = QRA.Assignments.GetForTrigger(trigger.id)
    end
    local exportString = QRA.Serialize(triggers, isForAddonChannel or false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

-- Export serialized triggers and assignments for a specific boss
---@param encounterId number encounter id
---@param isForAddonChannel? boolean
---@return string
function QRA.Comm.ExportBoss(encounterId, isForAddonChannel)
    QRA.Debug("Comm: Exporting Boss Data")
    local triggers = QRA.Triggers.GetTriggersByEncounterId(encounterId)

    if not triggers or #triggers == 0 then
        QRA.Print("Comm: No data found for encounter ID " .. encounterId)
        return ""
    end

    for _, trigger in ipairs(triggers) do
        trigger.assignments = QRA.Assignments.GetForTrigger(trigger.id)
    end

    local exportString = QRA.Serialize(triggers, isForAddonChannel or false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

-- Import serialized triggers and assignments

---@param input string serialized data
---@param isForAddonChannel? boolean
function QRA.Comm.Import(input, isForAddonChannel)
    QRA.Debug("Comm: Importing Data")
    ---@type Trigger[]
    local data = QRA.Deserialize(input, isForAddonChannel or false)

    if data then
        QRA.Debug("Comm: Deserialized Data")
        for _, trigger in ipairs(data) do
            QRA.Triggers.UpsertTrigger(trigger)
            for _, assignment in ipairs(trigger.assignments or {}) do
                local existingAssignments = QRA.Assignments.GetForTrigger(trigger.id)
                local found = false
                for _, existingAssignment in ipairs(existingAssignments) do
                    if existingAssignment.id == assignment.id then
                        found = true
                        break
                    end
                end
                if not found then
                    QRA.Assignments.Add(assignment)
                else
                    QRA.Assignments.Update(assignment.id, assignment)
                end
            end
            QRA.UI.RefreshAll()
        end
    else
        QRA.Print("Comm: Failed to deserialize data")
    end
end

function QRA.Comm.Initialize()
    QRA.Debug("Comm: Module Initialized")
end
