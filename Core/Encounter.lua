---@class QRA
local QRA = select(2, ...)

---@class QRA_Encounter
QRA.Encounter = QRA.Encounter or {}

---@type Trigger[]
local registeredTriggers = {}
local isEncounterActive = false
local timerHandlers = {}
local encounterTime = 0

local combatEvents = {
    "COMBAT_LOG_EVENT_UNFILTERED",
    "UNIT_HEALTH",
    "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_REGEN_ENABLED",
}

local function GetEncounterTime()
    if not isEncounterActive then return 0 end
    return GetTime() - encounterTime
end

--- Schedule a single assignment for a timer trigger occurrence
--- @param trigger Trigger
--- @param assignment Assignment
--- @param time number The time when the trigger fires (seconds from encounter start)
--- @param counter number The occurrence counter for this trigger
local function ScheduleTimerAssignment(trigger, assignment, time, counter)
    if not assignment.enabled then return end

    if not QRA.CounterFormula.Matches(assignment.counterFormula, counter) then
        return
    end

    local countdownTime = assignment.countdownTime or 0
    local absoluteScheduleTime = time - countdownTime -- Time from encounter start when assignment should start countdown
    local currentEncounterTime = GetEncounterTime()
    local scheduleDelay = math.max(0, absoluteScheduleTime - currentEncounterTime) -- Delay from NOW

    local eventData = {
        triggerId = trigger.id,
        triggerTime = time,
        counter = counter,
    }

    QRA.Debug("Triggers: Scheduling assignment", assignment.id, "in", scheduleDelay, "seconds (encounter time:", currentEncounterTime, "target:", absoluteScheduleTime, ")")

    C_Timer.After(scheduleDelay, function()
        if not isEncounterActive then return end
        QRA.Assignments.ExecuteAssignment(assignment, eventData)
    end)
end

--- Schedule all assignments for timer trigger occurance
--- @param trigger Trigger
--- @param time number Time when the trigger fires
--- @param counter number The occurance counter
local function ScheduleTimerOccurances(trigger, time, counter)
    if not trigger.assignments or #trigger.assignments == 0 then return end

    for _, assignment in pairs(trigger.assignments) do
        ScheduleTimerAssignment(trigger, assignment, time, counter)
    end
end

local function StartTimerTriggers()
    for _, trigger in pairs(registeredTriggers) do
        if trigger.enabled and trigger.type == QRA.Triggers.Types.TIMER.event then
            QRA.Debug("Starting timer trigger:", trigger.id)
            local initial, interval, repeatCount = trigger:GetDelay()

            timerHandlers[trigger.id] = {}

            ScheduleTimerOccurances(trigger, trigger.time, 1)

            if interval and interval > 0 then
                local maxRepeats = (repeatCount and repeatCount > 0) and (repeatCount - 1) or nil
                local currentOccurance = 1
                local ticker = C_Timer.NewTicker(interval, function()
                    if not isEncounterActive then return end
                    currentOccurance = currentOccurance + 1
                    local occuranceTime = trigger.time + (currentOccurance - 1) * interval
                    ScheduleTimerOccurances(trigger, occuranceTime, currentOccurance)
                end)
            end
        end
    end
end

local function StopTimerTriggers()
    for triggerId, handler in pairs(timerHandlers) do
        QRA.Debug("Stopping timer trigger:", triggerId)
        handler:Cancel()
        timerHandlers[triggerId] = nil
    end
end


local frame = CreateFrame("Frame")
frame:SetFrameLevel(0)
frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

local function RegisterCombatEvents()
    for _, event in ipairs(combatEvents) do
        frame:RegisterEvent(event)
    end
end

local function UnregisterCombatEvents()
    for _, event in ipairs(combatEvents) do
        frame:UnregisterEvent(event)
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
function frame:ENCOUNTER_START(encounterId, encounterName)
    QRA.Debug("Encounter started:", encounterName, "ID:", encounterId)

    RegisterCombatEvents()

    isEncounterActive = true
    local triggers = QRA.Triggers.GetBossTriggers(encounterName)
    for _, trigger in pairs(triggers) do
        tinsert(registeredTriggers, trigger)
    end

    encounterTime = GetTime()
    StartTimerTriggers()
end

function frame:ENCOUNTER_END(encounterId, encounterName)
    QRA.Debug("Encounter ended:", encounterName, "ID:", encounterId)

    UnregisterCombatEvents()
    isEncounterActive = false
    wipe(registeredTriggers)
    StopTimerTriggers()
end

function frame:PLAYER_REGEN_ENABLED()
    -- Not sure if this occurs after or before ENCOUNTER_END, gotta check
    if isEncounterActive then -- Sometimes encounters can end without ENCOUNTER_END firing, so we reset state here as well
        isEncounterActive = false
        StopTimerTriggers()
    end
end

function frame:COMBAT_LOG_EVENT_UNFILTERED(...)

end

function frame:UNIT_HEALTH(unitId)
end

function frame:UNIT_SPELLCAST_SUCCEEDED(unitId, castGuid, spellId)
end
