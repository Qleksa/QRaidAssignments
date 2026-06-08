---@class QRA
local QRA = select(2, ...)

if not QRA.AreLibsOkay() then
    return
end

QRA.Comm = {}

local COMM_PREFIX = "QRA_COMM"
local PLAN_EXPORT_SCHEMA = 2

---@class QRA_CommPlanPayload
---@field schema number
---@field type string
---@field planName string
---@field instanceName string
---@field selectedVersion number
---@field exportedAt integer
---@field triggers Trigger[]
---@field notes table<number, table>

local function RegisterComm()
    QRA.RegisterComm(COMM_PREFIX, function (data, sender, channel)
        QRA.Debug("Comm: Received data from", sender, "on channel", channel)

        if type(data) == "table" and data.type then
            if data.type == "NOTE" then
                QRA.Comm.HandleIncomingNote(data.data, sender)
                return
            elseif data.type == "NOTES" then
                QRA.Comm.HandleIncomingNotes(data.data, sender)
                return
            end
        end

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

---@param data any
---@return boolean
local function IsPlanPayload(data)
    return type(data) == "table"
        and data.type == "plan"
        and type(data.planName) == "string"
        and type(data.triggers) == "table"
end

---@param plan Plan
---@param version number
---@return QRA_CommPlanPayload
local function BuildPlanPayload(plan, version)
    local triggers = QRA.Plans.GetTriggersForVersion(plan.id, version)
    local notes = QRA.Notes and QRA.Notes.GetAllRaw and QRA.DeepCopy(QRA.Notes.GetAllRaw()) or {}
    return {
        schema = PLAN_EXPORT_SCHEMA,
        type = "plan",
        planName = plan.name,
        instanceName = plan.instanceName,
        selectedVersion = version,
        exportedAt = time(),
        triggers = CopyTriggersAndAssignments(triggers),
        notes = notes,
    }
end

---@param payload QRA_CommPlanPayload
local function ImportPlanPayload(payload)
    local incomingName = payload.planName and strtrim(payload.planName) or ""
    local instanceName = payload.instanceName and strtrim(payload.instanceName) or QRA.L["All Instances"]

    if incomingName == "" then
        incomingName = QRA.Plans.GetDefaultPlanName(instanceName)
    end

    if incomingName == "Personal" then
        incomingName = incomingName .. " (Shared)"
    end

    local importedPlan, importedVersion = QRA.Plans.ImportReplaceActiveVersion(incomingName, instanceName, payload.triggers or {}, "import")

    if payload.notes and QRA.Notes and QRA.Notes.ReplaceAll then
        QRA.Notes.ReplaceAll(payload.notes)
    end

    if QRA.UI and QRA.UI.SetPlanSelection and importedPlan then
        QRA.UI.SetPlanSelection(importedPlan.id, importedVersion)
    end
end

-- Export serialized triggers and assignments
---@param isForAddonChannel? boolean
---@return string
function QRA.Comm.Export(isForAddonChannel)
    QRA.Debug("Comm: Exporting selected plan")
    local plan = QRA.Plans.GetSelectedPlan()
    if not plan then
        QRA.Print("Comm: No selected plan found to export")
        return ""
    end

    local version = QRA.Plans.GetSelectedVersion()
    local payload = BuildPlanPayload(plan, version)

    local exportString = QRA.Serialize(payload, isForAddonChannel or false)
    QRA.Debug("Comm: Export String Generated")
    return exportString
end

--- Export active shared plan for raid transmission
---@param isForAddonChannel? boolean
---@return string
function QRA.Comm.ExportActiveSharedPlan(isForAddonChannel)
    local plan = QRA.Plans.GetActivePlan() or QRA.Plans.GetSelectedPlan()
    if not plan then
        QRA.Print("Comm: No shared plan found to export")
        return ""
    end

    if plan.isPersonal then
        QRA.Print("Comm: Personal plan cannot be sent to raid.")
        return ""
    end

    local payload = BuildPlanPayload(plan, plan.activeVersion)
    local exportString = QRA.Serialize(payload, isForAddonChannel or false)
    QRA.Debug("Comm: Shared plan export generated")
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
    return QRA.Comm.Export(isForAddonChannel)
end

local function ImportData(input, isSerialized, isForAddonChannel)
    QRA.Debug("Comm: Importing Data")
    ---@type any
    local data = input

    if isSerialized then
        local first, second = QRA.Deserialize(input, isForAddonChannel or false)
        if type(first) == "boolean" then
            data = first and second or nil
        else
            data = first
        end
    end

    if data then
        QRA.Debug("Comm: Deserialized Data", data)
        if IsPlanPayload(data) then
            ImportPlanPayload(data)
        else
            QRA.Print("Comm: Unsupported import format")
            return
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

---@param notesData table
---@param sender string
function QRA.Comm.HandleIncomingNotes(notesData, sender)
    if type(notesData) ~= "table" then
        QRA.Debug("Comm: Invalid notes payload received from", sender)
        return
    end

    if QRA.Notes and QRA.Notes.ReplaceAll then
        QRA.Notes.ReplaceAll(notesData)
    end

    if QRA.UI and QRA.UI.RefreshAll then
        QRA.UI.RefreshAll()
    end

    QRA.Debug("Comm: Notes bundle updated from", sender)
end

---@param noteData table
---@param sender string
function QRA.Comm.HandleIncomingNote(noteData, sender)
    if not noteData or not noteData.encounterId then
        QRA.Debug("Comm: Invalid note data received")
        return
    end

    QRA.DB.notes = QRA.DB.notes or {}

    local encounterId = noteData.encounterId
    local existingNote = QRA.DB.notes[encounterId]

    if not existingNote or (noteData.timestamp and noteData.timestamp > (existingNote.timestamp or 0)) then
        QRA.DB.notes[encounterId] = {
            text = noteData.text or "",
            timestamp = noteData.timestamp or time(),
            author = noteData.author or sender,
        }

        QRA.Debug("Comm: Note updated for encounter", encounterId, "from", sender)

        if QRA.Notes and QRA.Notes.RefreshNote then
            QRA.Notes.RefreshNote(encounterId)
        end
    else
        QRA.Debug("Comm: Ignored older note for encounter", encounterId)
    end
end

---@param encounterId number
---@param noteText string
function QRA.Comm.SendNote(encounterId, noteText)
    QRA.Debug("Comm: Sending Note for encounter", encounterId)

    if not IsInRaid() then
        QRA.Print("You must be in a raid group to send notes.")
        return
    end

    local canSend = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    if not canSend then
        QRA.Print("You must be the raid leader or an assistant to send notes.")
        return
    end

    local noteData = {
        type = "NOTE",
        data = {
            encounterId = encounterId,
            text = noteText,
            timestamp = time(),
            author = UnitName("player"),
        },
        timestamp = time(),
    }

    local serialized = QRA.Serialize(noteData, true)

    QRA.SendCommMessage(COMM_PREFIX, serialized, "BULK", function (_, sentBytes, totalBytes, didSend)
        QRA.Debug("Comm: Note sent", sentBytes, "of", totalBytes, "bytes")
        if didSend and sentBytes == totalBytes then
            QRA.Print(QRA.L["Note successfully sent to raid."])
        else
            QRA.Print(QRA.L["Failed to send note to raid."])
        end
    end, nil, true)
end

function QRA.Comm.SendNotesToRaid()
    if not IsInRaid() then
        QRA.Print(QRA.L["You must be in a raid group to send notes."])
        return
    end

    local canSend = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    if not canSend then
        QRA.Print(QRA.L["You must be the raid leader or an assistant to send notes."])
        return
    end

    local notes = QRA.Notes and QRA.Notes.GetAllRaw and QRA.DeepCopy(QRA.Notes.GetAllRaw()) or {}

    local notesToSend = {}
    for encounterId, note in pairs(notes) do
        if note.text and note.text ~= "" then
            notesToSend[encounterId] = note
        end
    end
    QRA.Debug(notesToSend)

    local payload = {
        type = "NOTES",
        data = notesToSend,
        timestamp = time(),
        author = UnitName("player"),
    }

    local serialized = QRA.Serialize(payload, true)

    QRA.SendCommMessage(COMM_PREFIX, payload, "BULK", function(_, sentBytes, totalBytes, didSend)
        QRA.Debug("Comm: Notes bundle sent", sentBytes, "of", totalBytes, "bytes")
        if didSend and sentBytes == totalBytes then
            QRA.Print(QRA.L["Notes successfully sent to raid."])
        else
            QRA.Print(QRA.L["Failed to send notes to raid."])
        end
    end, nil, true)
end

function QRA.Comm.Initialize()
    RegisterComm()

    QRA.Debug("Comm: Module Initialized")
end
