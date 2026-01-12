---@class QRA
local QRA = QRA

---@type AbstractFramework
local AF = _G.AbstractFramework

if not QRA.AreLibsOkay() then
    QRA.Print("Required libraries are missing. QRaidAssignments cannot function properly.")
    return
end

QRA.Comm = {}

function QRA.Comm.Export()
    QRA.Debug("Comm: Exporting Data")
    -- Export all triggers and assignments
end

---@param encounterId number encounter id
---@return string|nil exportString string or nil if no data
function QRA.Comm.ExportBoss(encounterId)
    QRA.Debug("Comm: Exporting Boss Data")
    local triggers = QRA.Triggers.GetTriggersByEncounterId(encounterId)

    if not triggers or #triggers == 0 then
        QRA.Print("Comm: No data found for encounter ID " .. encounterId)
        return nil
    end

    for _, trigger in ipairs(triggers) do
        trigger.assignments = QRA.Assignments.GetForTrigger(trigger.id)
    end

    local exportString = AF.Serialize(triggers, false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

function QRA.Comm.Import(input)
    QRA.Debug("Comm: Importing Data")
    ---@type Trigger[]
    local data = AF.Deserialize(input, false)
    if data then
        QRA.Debug("Comm: Deserialized Data")
        -- Handle imported data
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
        QRA.Print("Comm: Import Successful")
    else
        QRA.Print("Comm: Failed to deserialize data")
    end
end

function QRA.Comm.Initialize()
    QRA.Debug("Comm: Module Initialized")
end
