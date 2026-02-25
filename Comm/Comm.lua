---@class QRA
local QRA = select(2, ...)

if not QRA.AreLibsOkay() then
    return
end

QRA.Comm = {}

local COMM_PREFIX = "QRA_COMM"

local function RegisterComm()
    QRA.RegisterComm(COMM_PREFIX, function (data, sender, channel)
        QRA.Debug("Comm: Received data from", sender, "on channel", channel)
        QRA.Comm.ImportDesirialized(data, true)
    end)
end

local function CopyTriggersAndAssignments(triggers)
    local copiedData = {}
    for _, trigger in ipairs(triggers) do
        local copiedTrigger = QRA.DeepCopy(trigger)
        table.insert(copiedData, copiedTrigger)
    end
    return copiedData
end

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

    local exportData = CopyTriggersAndAssignments(triggers)
    local exportString = QRA.Serialize(exportData, isForAddonChannel or false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

-- Export trigger
---@param triggerId string trigger id
---@param isForAddonChannel? boolean
---@return string
function QRA.Comm.ExportTrigger(triggerId, isForAddonChannel)
    QRA.Debug("Comm: Exporting Trigger Data")

    local trigger = QRA.Triggers.Get(triggerId)
    if not trigger then
        QRA.Print("Comm: No trigger found with ID " .. triggerId)
        return ""
    end

    local exportData = QRA.DeepCopy(trigger)
    local exportString = QRA.Serialize({exportData}, isForAddonChannel or false)
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

    local exportData = CopyTriggersAndAssignments(triggers)
    local exportString = QRA.Serialize(exportData, isForAddonChannel or false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

local function ImportData(input, isSerialized, isForAddonChannel)
    QRA.Debug("Comm: Importing Data")
    ---@type Trigger[]
    local data = isSerialized and QRA.Deserialize(input, isForAddonChannel or false) or input

    -- need a way to distunguish between full raid import, single trigger import, and boss import
    if data then
        QRA.Debug("Comm: Deserialized Data", data)
        for _, trigger in ipairs(data) do
            local existingTrigger = QRA.Triggers.Get(trigger.id)

            if existingTrigger then
                local existingAssignmentsById = {}
                for _, existingAssignment in ipairs(existingTrigger.assignments or {}) do
                    existingAssignmentsById[existingAssignment.id] = existingAssignment
                end


                for _, assignment in ipairs(trigger.assignments or {}) do
                    if existingAssignmentsById[assignment.id] then
                        -- Update existing assignment
                        for i, existing in ipairs(existingTrigger.assignments) do
                            if existing.id == assignment.id then
                                existingTrigger.assignments[i] = assignment
                                break
                            end
                        end
                    else
                        -- Add new assignment
                        if not existingTrigger.assignments then
                            existingTrigger.assignments = {}
                        end
                        table.insert(existingTrigger.assignments, assignment)
                    end
                end

                -- Update trigger with merged assignments
                QRA.Triggers.UpdateTrigger(existingTrigger)
            else
                -- New trigger - upsert directly (assignments already embedded)
                QRA.Triggers.UpsertTrigger(trigger)
            end
        end
        QRA.UI.RefreshAll()
    else
        QRA.Print("Comm: Failed to deserialize data")
    end
end

-- Import serialized triggers and assignments
---@param input string serialized data
---@param isForAddonChannel? boolean defaults to false
function QRA.Comm.Import(input, isForAddonChannel)
    ImportData(input, true, isForAddonChannel)
end

-- Import deserialized triggers and assignments
---@param input string deserialized data
---@param isForAddonChannel? boolean defaults to false
function QRA.Comm.ImportDesirialized(input, isForAddonChannel)
    ImportData(input, false, isForAddonChannel)
end

-- Send data to raid group
---@param data string serialized data to send
function QRA.Comm.SendToRaid(data)
    QRA.Debug("Comm: Sending Data to Raid")
    if not IsInRaid() then
        QRA.Print("You must be in a raid group to send data.")
        return
    end

    local canSend = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    if not canSend then
        QRA.Print("You must be the raid leader or an assistant to send data.")
        return
    end

    QRA.SendCommMessage(COMM_PREFIX, data, "BULK", function (callbackArg, sentBytes, totalBytes, didSend)
        QRA.Debug("Comm: Sent", sentBytes, "of", totalBytes, "bytes")
        if didSend and sentBytes == totalBytes then
            QRA.Print("Comm: Data successfully sent to raid.")
        else
            if not didSend then
                QRA.Print("Comm: Failed to send data to raid (transmission aborted).")
            elseif sentBytes ~= totalBytes then
                QRA.Print("Comm: Failed to send all data to raid (only sent " .. sentBytes .. " of " .. totalBytes .. " bytes).")
            end
        end
    end, nil, true)
end

function QRA.Comm.Initialize()
    RegisterComm()

    QRA.Debug("Comm: Module Initialized")
end
