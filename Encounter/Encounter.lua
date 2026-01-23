---@class QRA
local QRA = QRA

---@class QRA_Encounter
---@field encounterId number
---@field bossName string
---@field phase number
---@field startTime number
---@field endTime? number
---@field NewEncounter fun(self: QRA_Encounter, bossName: string, encounterId: number): QRA_Encounter
---@field End fun(self: QRA_Encounter, success: boolean)
---@field GetPhase fun(self: QRA_Encounter): number
---@field SetPhase fun(self: QRA_Encounter, phase: number)
---@field SendEvent fun(self:QRA_Encounter, eventName: string, ...: any)
---@field RegisterEvent fun(eventName: string, callback: fun(eventName: string, ...: any), priority?: string)
QRA.Encounter = {
    encounterId = 0,
    bossName = "",
    phase = 1,
    startTime = 0,
    endTime = nil,
}

do
    local SendEvent = QRA.Event.SendEvent
    local RegisterEvent = QRA.Event.RegisterEvent

    --- Start a new encounter
    ---@param bossName string
    ---@param encounterId number
    ---@return QRA_Encounter
    function QRA.Encounter:NewEncounter(bossName, encounterId)
        QRA.Debug("Encounter: Started:", bossName, "ID:", encounterId)

        local boss = {
            SendEvent = SendEvent,
            RegisterEvent = RegisterEvent,
        }
        setmetatable(boss, { __index = QRA.Encounter })
        return boss
    end
end

--- End the current encounter
--- @param success boolean whether the encounter was successfully completed
function QRA.Encounter:End(success)
    QRA.Debug("Encounter: Ended:", self.bossName, "ID:", self.encounterId, "Success:", success)
    self.endTime = GetTime()
end

--- Return the current phase
---@return number phase
function QRA.Encounter:GetPhase()
    return self.phase
end

--- Set the current phase
--- @param phase number
function QRA.Encounter:SetPhase(phase)
    QRA.Debug("Encounter: Phase changed to", phase)
    self.phase = phase
    self:SendEvent("QRA_SetPhase", phase)
end

do
    local encounter = QRA.Encounter:NewEncounter("Test Boss", 1234)
    encounter:SetPhase(2)
    QRA.Debug("Encounter: Module initialized")
end
