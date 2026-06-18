--[[
    QRaidAssignments - Boss Event Modules
    Per-boss event handler system. Boss-specific WoW events (e.g., CHAT_MSG_RAID_BOSS_EMOTE)
    are registered on encounter start, removed on encounter end, and fire into the existing
    trigger/assignment pipeline.

    Architecture:
    1. Inline events in Data/Bosses.lua (bossData.events) - quick, works now
    2. Separate modules via QRA.BossEventModules.Register(encounterId, module) - future
]]

---@class QRA
local QRA = select(2, ...)

QRA.BossEventModules = QRA.BossEventModules or {}

-- Internal state
local registeredEvents = {} -- { eventName = true } tracks WoW events registered on the frame
local currentEncounterId = nil

--- Register a boss event module for an encounter
---@param encounterId number
---@param module table Must provide GetEvents() -> BossEventDef[]
function QRA.BossEventModules.Register(encounterId, module)
    if not QRA.BossEventModules.Modules then
        QRA.BossEventModules.Modules = {}
    end
    QRA.BossEventModules.Modules[encounterId] = module
end

--- Get event definitions for the current encounter
--- Checks module registry first, then falls back to bossData.events
---@param encounterId number
---@return table[]|nil events
local function GetBossEventDefs(encounterId)
    local module = QRA.BossEventModules.Modules and QRA.BossEventModules.Modules[encounterId]
    if module and module.GetEvents then
        return module.GetEvents()
    end

    local bossData = QRA.Bosses.GetBossByEncounterId(encounterId)
    if bossData and bossData.events then
        return bossData.events
    end

    return nil
end

--- Create a handler function that checks the filter and fires the linked trigger
---@param triggerId string
---@param eventDef BossEventDef
---@return function
local function CreateEventHandler(triggerId, eventDef)
    return function(self, ...)
        -- Check filter
        if eventDef.filter then
            if type(eventDef.filter) == "string" then
                local text = ...
                if not text or not text:find(eventDef.filter) then
                    return
                end
            elseif type(eventDef.filter) == "function" then
                if not eventDef.filter(...) then
                    return
                end
            end
        end

        -- Get fresh trigger reference (respects enable/disable + config changes)
        local trigger = QRA.Triggers.Get(triggerId)
        if not trigger or not trigger.enabled then
            return
        end

        -- Build event data for the assignment pipeline
        local eventData = {}
        if eventDef.event and eventDef.event:find("CHAT_MSG") then
            eventData.text = ...
        end

        QRA.Triggers.Fire(trigger, eventData)
    end
end

--- Register all boss-specific WoW events for the current encounter
--- Called from QRA.Triggers.OnEncounterStart
---@param encounterId number
function QRA.BossEventModules.RegisterBossEvents(encounterId)
    QRA.BossEventModules.UnregisterBossEvents()

    local bossData = QRA.Bosses.GetBossByEncounterId(encounterId)
    if not bossData then
        return
    end

    local events = GetBossEventDefs(encounterId)
    if not events then
        return
    end

    currentEncounterId = encounterId
    local frame = QRA.Triggers.frame

    for _, eventDef in ipairs(events) do
        local triggerId = bossData.name .. "_BOSS_EMOTE_" .. eventDef.name

        if not registeredEvents[eventDef.event] then
            frame:RegisterEvent(eventDef.event)
            registeredEvents[eventDef.event] = true
        end

        frame[eventDef.event] = CreateEventHandler(triggerId, eventDef)
        QRA.Debug("BossEventModules: Registered", eventDef.event, "for", bossData.name)
    end

    QRA.Debug("BossEventModules: Registered", #events, "events for encounter", encounterId)
end

--- Unregister all boss-specific events from the trigger frame
--- Called from QRA.Triggers.OnEncounterEnd
function QRA.BossEventModules.UnregisterBossEvents()
    local frame = QRA.Triggers.frame

    for eventName, _ in pairs(registeredEvents) do
        frame:UnregisterEvent(eventName)
        frame[eventName] = nil
    end

    wipe(registeredEvents)
    currentEncounterId = nil

    QRA.Debug("BossEventModules: Unregistered all boss events")
end
