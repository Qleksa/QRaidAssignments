---@class QRA
local QRA = select(2, ...)

---@class DB
QRA.DB = QRA.DB or {}

local db = QRA.DB

do
    QRA.Debug("Database module loading...")

    DevTools_Dump(db)
end

--- Triggers

--- Save a trigger to the database
---@param trigger Trigger
function QRA.DB.SaveTrigger(trigger)
    db.triggers[trigger.id] = trigger
end

--- Get a trigger by ID
--- @param triggerId string Trigger ID
--- @return Trigger|nil trigger or nil if not found
function QRA.DB.GetTrigger(triggerId)
    return QRA.Triggers.Factory.Restore(db.triggers[triggerId])
end

--- Delete a trigger by ID
--- @param triggerId string Trigger ID
function QRA.DB.DeleteTrigger(triggerId)
    db.triggers[triggerId] = nil
end

--- Get triggers for a specific encounter
--- @param encounterId number Encounter ID
--- @return Trigger[] triggers List of triggers for the encounter
function QRA.DB.GetEncounterTriggers(encounterId)
    local triggers = {}
    for _, triggerData in pairs(db.triggers) do
        if triggerData.encounterId == encounterId then
            table.insert(triggers, triggerData)
        end
    end
    return triggers
end

function QRA.DB.Initialize()
    QRA.Debug("Database module initialized.")
end
