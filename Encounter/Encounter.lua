---@class QRA
local QRA = select(2, ...)

local AF = _G.AbstractFramework

---@enum QRA_EncounterMessages
QRA.EncounterMessages = {
    Start = "QRA_StartEncounter",
    End = "QRA_EndEncounter",
    SetPhase = "QRA_SetPhase",
}

---@class QRA_Encounter | QRA_Module
---@field encounterId number
---@field bossName string
---@field phase number
---@field startTime number
---@field endTime? number
---@field NewEncounter fun(self: QRA_Encounter, bossName: string, encounterId: number): QRA_Encounter
---@field End fun(self: QRA_Encounter, success: boolean)
---@field GetPhase fun(self: QRA_Encounter): number
---@field SetPhase fun(self: QRA_Encounter, phase: number)
---@field IsEngaged fun(self: QRA_Encounter): boolean
---@field SendMessage fun(self: QRA_Encounter, event: QRA_EncounterMessages, ...: any)
---@field RegisterMessage fun(self: QRA_Encounter, message: QRA_EncounterMessages, callback: fun(message: string, ...: any)?, priority?: string, tag?: string)
---@field UnregisterMessage fun(self: QRA_Encounter, message: QRA_EncounterMessages, tag: string)
---@field UnregisterAllMessages fun(self: QRA_Encounter)
---@field RegisterEvent fun(self: QRA_Encounter, event: FrameEvent, callback: fun(event: string, ...: any)?)
---@field UnregisterEvent fun(self: QRA_Encounter, event: FrameEvent)
---@field UnregisterAllEvents fun(self: QRA_Encounter)
QRA.Encounter = {
    registeredEvents = {},
    registeredMessages = {},

    --- Create a new encounter
    --- @return QRA_Encounter
    NewEncounter = function(self, bossName, encounterId)
        QRA.Debug("Encounter: Started:", bossName, "ID:", encounterId)

        local boss = {
            bossName = bossName,
            phase = 1,
            encounterId = encounterId,
            startTime = GetTime(),
            endTime = nil,
        }
        setmetatable(boss, { __index = QRA.Encounter })

        C_Timer.After(0, function ()
            boss:SendMessage(QRA.EncounterMessages.Start)
        end)

        local bossMod = QRA.BossMods.GetBossMod()
        if bossMod then
            bossMod:RegisterStage(function(_, _, _, phase)
                self:SetPhase(phase)
            end)
        end

        return boss
    end,

    --- End the current encounter
    --- @param success boolean whether the encounter was successfully completed
    End = function(self, success)
        QRA.Debug("Encounter: Ended:", self.bossName, "ID:", self.encounterId, "Success:", success)
        self.endTime = GetTime()

        self:SendMessage(QRA.EncounterMessages.End, success)

        self:UnregisterAllEvents()
        self:UnregisterAllMessages()
    end,

    --- Return the current phase
    ---@return number phase
    GetPhase = function(self)
        return self.phase
    end,

    --- Set the current phase
    SetPhase = function(self, phase)
        QRA.Debug("Encounter: Phase changed to", phase)
        self.phase = phase
        self:SendMessage(QRA.EncounterMessages.SetPhase, phase)
    end,

    --- Check if the encounter is currently engaged
    ---@return boolean isEngaged
    IsEngaged = function (self)
        return self.endTime == nil
    end,

    --- Send a message to all registered listeners
    ---@param message QRA_EncounterMessages
    ---@param ... any
    SendMessage = function (self, message, ...)
        QRA.Debug("Encounter: Sending message", message)
        QRA.Event.SendEvent(self, message, ...)
    end,

    --- Register a message listener
    --- @param message QRA_EncounterMessages
    --- @param callback fun(message: string, ...: any)?
    --- @param priority? string
    --- @param tag? string
    RegisterMessage = function (self, message, callback, priority, tag)
        if not self.registeredMessages[message] then
            QRA.Debug("Encounter: Registering message", message, "with priority '" .. (priority or "medium") .. "'", tag and "and tag '" .. tag .. "'")
            QRA.Event.RegisterEvent(self, message, callback, priority, tag)
            self.registeredMessages[message] = true
        end
    end,

    --- Unregister a message listener
    --- @param message QRA_EncounterMessages
    --- @param tag string
    UnregisterMessage = function (self, message, tag)
        if self.registeredMessages[message] then
            QRA.Debug("Encounter: Unregistering message", message, tag and "with tag '" .. tag .. "'")
            QRA.Event.UnregisterEvent(self, message, tag)
        end
    end,

    --- Unregister all message listeners
    UnregisterAllMessages = function (self)
        QRA.Debug("Encounter: Unregistering all messages")
        for e, cb in next, self.registeredMessages do
            QRA.Debug("\t" .. e)
            QRA.Event.UnregisterAllCallbacks(self, e)
        end
        self.registeredMessages = {}
    end,
}

-- Event handling

do
    --[[
        {
          [eventPrefix] = {
            [suffix] = {
                [unit] = {
                    [spellId] = { true/false (register/unregister), ...
                }
            },
            ...
          },
        }
    --]]

    local combatEvents = {}
    local registeredEvents = {}

    local function processCombatEvent(...)
        QRA.Debug("Encounter: Processing combat event")
        local _, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
                destGUID, destName, destFlags, destRaidFlags,
                spellId = CombatLogGetCurrentEventInfo()

        local isBoss = UnitGUID("boss1") == sourceGUID

        if combatEvents[event] then
            QRA.Debug("Encounter: Handling event", event)

            for unit, spellTable in next, combatEvents[event] do
                if (unit == "boss1" and isBoss) then
                    if spellTable[spellId] then
                        QRA.Debug("Encounter: Invoking combat event callback for unit", unit, "and spellId", spellId)
                        for callback, _ in next, spellTable do
                            if type(callback) == "function" then
                                callback(event, ...)
                            end
                        end
                    end
                end
            end
        end
    end

    local encounterFrame = CreateFrame("Frame")
    encounterFrame:SetScript("OnEvent", function(_, event, ...)
        QRA.Debug("Encounter Frame received event:", event)

        if registeredEvents[event] then
            QRA.Debug("Encounter: Handling event", event)

            for module, callback in next, registeredEvents[event] do
                QRA.Debug("Encounter: Invoking callback for module", module.bossName)
                if type(callback) == "function" then
                    callback(event, ...)
                elseif type(callback) == "string" and module[callback] then
                    module[callback](module, ...)
                end
            end
        end
    end)
    function encounterFrame:COMBAT_LOG_EVENT_UNFILTERED()
        processCombatEvent()
    end

    --- Register an event listener
    --- @param event FrameEvent
    --- @param callback fun(event: string, ...: any)?
    function QRA.Encounter:RegisterEvent(event, callback)
        if not registeredEvents[event] then
            registeredEvents[event] = {}
            QRA.Debug("Encounter: Registering event", event)
            encounterFrame:RegisterEvent(event)
            registeredEvents[event][self] = callback or event
        end

    end

    --- Unregister an event listener
    --- @param event FrameEvent
    function QRA.Encounter:UnregisterEvent(event)
        if registeredEvents[event] then
            QRA.Debug("Encounter: Unregistering event", event)
            encounterFrame:UnregisterEvent(event)
            registeredEvents[event][self] = nil
        end
    end

    --- Unregister all event listeners
    function QRA.Encounter:UnregisterAllEvents()
        QRA.Debug("Encounter: Unregistering all events")
        for e, cb in next, registeredEvents do
            QRA.Debug("\t" .. e)
            encounterFrame:UnregisterEvent(e)
        end
        registeredEvents = {}
    end

    local function RegisterCombatEvent(event, callback)
        if not combatEvents[event] then
            combatEvents[event] = {}
            QRA.Debug("Encounter: Registering combat event", event)
            combatEvents[event][callback] = true
        end
    end

    function QRA.Encounter:RegisterSpellEvent(event, unit, spellId)
        if not combatEvents[event] then
            combatEvents[event] = {}
            QRA.Debug("Encounter: Registering spell event", event, "for unit", unit, "and spellId", spellId)
            combatEvents[event][unit] = combatEvents[event][unit] or {}
            combatEvents[event][unit][spellId] = true
            self:RegisterEvent(event)
        end
    end
end

function QRA.Encounter.Initialize()
    -- QRA.Debug("Encounter: Module initialized")
end
