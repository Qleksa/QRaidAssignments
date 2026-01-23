---@class QRA
local QRA = QRA

---@class Encounter
---@field encounterId number
---@field bossName string
---@field phase number
---@field startTime number
---@field endTime number
local encounter = {
    encounterId = 0,
    bossName = "",
    phase = 1,
    startTime = 0,
    endTime = 0,
}

do
    QRA.Event.RegisterEvent("QRA_TEST", function(event, phase)
        QRA.Debug("Encounter: Received event callback for phase change to", phase)
    end, "high")
end

QRA.Encounter = {}

--- Start a new encounter
function QRA.Encounter.Start(encounterId, bossName)
    QRA.Debug("Encounter: Started:", bossName, "ID:", encounterId)
    encounter = {
        encounterId = encounterId,
        bossName = bossName,
        phase = 1,
        startTime = GetTime(),
        endTime = 0,
    }
end

--- End the current encounter
--- @param success boolean whether the encounter was successfully completed
function QRA.Encounter.End(success)
    QRA.Debug("Encounter: Ended:", encounter.bossName, "ID:", encounter.encounterId, "Success:", success)
    encounter.endTime = GetTime()
end

--- Return the current phase
---@return number phase
function QRA.Encounter.GetPhase()
    return encounter.phase
end

--- Set the current phase
--- @param phase number
function QRA.Encounter.SetPhase(phase)
    QRA.Debug("Encounter: Phase changed to", phase)
    encounter.phase = phase
    QRA.Event.SendEvent("QRA_TEST", phase)
end

function QRA.Encounter.Initialize()
    QRA.Encounter.SetPhase(1)
    QRA.Debug("Encounter: Module initialized")
end
