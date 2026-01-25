--[[
    QRaidAssignments - Dev Mode: Event History
    Tracks fired events and supports replay functionality
]]

---@class QRA
local QRA = select(2, ...)

---@class QRA_DevMode | QRA_Module
QRA.DevMode = QRA.DevMode or {}

---@class QRA_DevMode_EventHistory | QRA_Module
QRA.DevMode.EventHistory = {}

---@class QRA_DevMode_EventHistory
local EventHistory = QRA.DevMode.EventHistory

--------------------------------------------------
-- State
--------------------------------------------------
local eventLog = {}  -- Array of logged events
local maxEvents = 500  -- Maximum events to keep in history

--------------------------------------------------
-- Event Structure
--------------------------------------------------
--[[
    Event = {
        id = 1,
        timestamp = 123456.789,  -- GetTime()
        encounterTime = 15.5,    -- Time since encounter start
        eventType = "SPELL_CAST_SUCCESS",
        data = {
            spellId = 12345,
            spellName = "Spell Name",
            sourceUnitId = "boss1",
            targetName = "Player1",
            ...
        },
    }
]]

--------------------------------------------------
-- History Management
--------------------------------------------------

--- Initialize event history from saved data
function EventHistory.Initialize()
    -- Load from DB if exists
    if QRA.DB.devMode and QRA.DB.devMode.eventHistory then
        eventLog = QRA.DB.devMode.eventHistory
    else
        eventLog = {}
    end
end

--- Save event history to DB
local function SaveToDb()
    if QRA.DB.devMode then
        QRA.DB.devMode.eventHistory = eventLog
    end
end

--- Add an event to history
---@param eventType string
---@param data table
---@return table event The created event
function EventHistory.AddEvent(eventType, data)
    local encounterTime = 0
    if QRA.DevMode.FakeEncounter and QRA.DevMode.FakeEncounter.IsActive() then
        encounterTime = QRA.DevMode.FakeEncounter.GetEncounterTime()
    end

    local event = {
        id = #eventLog + 1,
        timestamp = GetTime(),
        encounterTime = encounterTime,
        eventType = eventType,
        data = QRA.DeepCopy(data),
    }

    table.insert(eventLog, event)

    -- Trim if over max
    while #eventLog > maxEvents do
        table.remove(eventLog, 1)
        -- Re-index
        for i, evt in ipairs(eventLog) do
            evt.id = i
        end
    end

    SaveToDb()

    -- Notify UI if handler exists
    if EventHistory.OnEventAdded then
        EventHistory.OnEventAdded(event)
    end

    return event
end

--- Get all events
---@return table
function EventHistory.GetAll()
    return eventLog
end

--- Get events by type
---@param eventType string
---@return table
function EventHistory.GetByType(eventType)
    local filtered = {}
    for _, event in ipairs(eventLog) do
        if event.eventType == eventType then
            table.insert(filtered, event)
        end
    end
    return filtered
end

--- Get event by ID
---@param eventId number
---@return table|nil
function EventHistory.GetById(eventId)
    for _, event in ipairs(eventLog) do
        if event.id == eventId then
            return event
        end
    end
    return nil
end

--- Get event count
---@return number
function EventHistory.GetCount()
    return #eventLog
end

--- Clear all events
function EventHistory.Clear()
    wipe(eventLog)
    SaveToDb()

    if EventHistory.OnHistoryCleared then
        EventHistory.OnHistoryCleared()
    end

    QRA.Debug("EventHistory: Cleared all events")
end

--------------------------------------------------
-- Replay Functions
--------------------------------------------------

--- Replay a single event
---@param eventId number
---@return boolean success
function EventHistory.ReplayEvent(eventId)
    local event = EventHistory.GetById(eventId)
    if not event then
        QRA.Debug("EventHistory: Event not found:", eventId)
        return false
    end

    return EventHistory.ReplayEventData(event)
end

--- Replay an event from its data
---@param event table
---@return boolean success
function EventHistory.ReplayEventData(event)
    local eventType = event.eventType
    local data = event.data

    if not QRA.DevMode.FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local EventFirer = QRA.DevMode.EventFirer

    if eventType == "SPELL_CAST_SUCCESS" then
        return EventFirer.FireSpellCastSuccess(data.spellId, data.sourceUnitId, data.targetName)
    elseif eventType == "SPELL_CAST_START" then
        return EventFirer.FireSpellCastStart(data.spellId, data.sourceUnitId)
    elseif eventType == "SPELL_AURA_APPLIED" then
        return EventFirer.FireAuraApplied(data.spellId, data.targetName, data.sourceUnitId, data.duration)
    elseif eventType == "SPELL_AURA_REMOVED" then
        return EventFirer.FireAuraRemoved(data.spellId, data.targetName, data.sourceUnitId)
    elseif eventType == "UNIT_DIED" then
        return EventFirer.FireNPCDeath(data.npcId, data.unitId)
    elseif eventType == "UNIT_SPELLCAST_SUCCEEDED" then
        return EventFirer.FireUnitSpellcastSucceeded(data.unitId, data.spellId)
    elseif eventType == "TIMER" then
        return EventFirer.FireTimerTrigger(data.triggerId)
    elseif eventType == "UNIT_HEALTH" then
        if QRA.DevMode.FakeEncounter then
            QRA.DevMode.FakeEncounter.SetBossHealth(data.unitId, data.newHealth)
        end
        return true
    end

    return false
end

--- Replay a sequence of events with timing
---@param startEventId number|nil Start from this event ID (default: 1)
---@param endEventId number|nil End at this event ID (default: last)
---@param preserveTiming boolean|nil Whether to preserve relative timing (default: true)
---@param callback function|nil Called when replay completes
function EventHistory.ReplaySequence(startEventId, endEventId, preserveTiming, callback)
    startEventId = startEventId or 1
    endEventId = endEventId or #eventLog
    preserveTiming = preserveTiming ~= false

    if not QRA.DevMode.FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    -- Collect events in range
    local eventsToReplay = {}
    for _, event in ipairs(eventLog) do
        if event.id >= startEventId and event.id <= endEventId then
            table.insert(eventsToReplay, event)
        end
    end

    if #eventsToReplay == 0 then
        QRA.Debug("EventHistory: No events to replay")
        return false
    end

    -- Sort by original timestamp
    table.sort(eventsToReplay, function(a, b)
        return a.timestamp < b.timestamp
    end)

    local baseTime = eventsToReplay[1].timestamp
    local replayIndex = 1

    local function ReplayNext()
        if replayIndex > #eventsToReplay then
            QRA.Debug("EventHistory: Replay sequence complete")
            if callback then callback() end
            return
        end

        local event = eventsToReplay[replayIndex]
        EventHistory.ReplayEventData(event)
        replayIndex = replayIndex + 1

        -- Schedule next event
        if replayIndex <= #eventsToReplay and preserveTiming then
            local nextEvent = eventsToReplay[replayIndex]
            local delay = (nextEvent.timestamp - event.timestamp)
            delay = math.max(0.01, delay)  -- Minimum delay
            C_Timer.After(delay, ReplayNext)
        elseif replayIndex <= #eventsToReplay then
            -- No timing, fire immediately
            C_Timer.After(0.1, ReplayNext)  -- Small delay to prevent freezing
        else
            if callback then callback() end
        end
    end

    QRA.Debug("EventHistory: Starting replay of", #eventsToReplay, "events")
    ReplayNext()

    return true
end

--- Stop any active replay
function EventHistory.StopReplay()
    -- TODO: Implement replay cancellation
    -- For now, replays run to completion
end

--------------------------------------------------
-- Export/Import
--------------------------------------------------

--- Export event history to string
---@return string|nil
function EventHistory.Export()
    return QRA.Serialize(eventLog)
end

--- Import event history from string
---@param dataStr string
---@return boolean success
function EventHistory.Import(dataStr)
    local success, data = QRA.Deserialize(dataStr)
    if success and type(data) == "table" then
        eventLog = data
        SaveToDb()
        QRA.Debug("EventHistory: Imported", #eventLog, "events")
        return true
    end
    return false
end

--------------------------------------------------
-- Formatting
--------------------------------------------------

--- Format an event for display
---@param event table
---@return string
function EventHistory.FormatEvent(event)
    local timeStr = string.format("%.1fs", event.encounterTime)
    local typeStr = event.eventType

    local detailStr = ""
    local data = event.data

    if event.eventType == "SPELL_CAST_SUCCESS" or event.eventType == "SPELL_CAST_START" then
        detailStr = string.format("%s (%d)", data.spellName or "?", data.spellId or 0)
        if data.targetName then
            detailStr = detailStr .. " -> " .. data.targetName
        end
    elseif event.eventType == "SPELL_AURA_APPLIED" or event.eventType == "SPELL_AURA_REMOVED" then
        detailStr = string.format("%s (%d) on %s", data.spellName or "?", data.spellId or 0, data.targetName or "?")
    elseif event.eventType == "UNIT_SPELLCAST_SUCCEEDED" then
        detailStr = string.format("%s (%d) by %s", data.spellName or "?", data.spellId or 0, data.unitId or "?")
    elseif event.eventType == "UNIT_DIED" then
        detailStr = data.name or "?"
    elseif event.eventType == "TIMER" then
        detailStr = string.format("Timer @ %ds", data.time or 0)
    elseif event.eventType == "UNIT_HEALTH" then
        detailStr = string.format("%s: %d%% -> %d%%", data.unitId or "?", data.oldHealth or 0, data.newHealth or 0)
    end

    return string.format("[%s] %s: %s", timeStr, typeStr, detailStr)
end
