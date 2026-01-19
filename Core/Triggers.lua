--[[
    QRaidAssignments - Trigger System
    Handles all trigger types: spell casts, auras, timers, NPC deaths
    Each trigger tracks occurrences and can fire assignments on specific counts
]]

---@class QRA
local QRA = QRA
QRA.Triggers = {}

local frame = CreateFrame("Frame", "QRA_TriggerFrame") -- Event frame for combat log and timers
QRA.Triggers.frame = frame
local playerGUID = UnitGUID("player")

frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
function frame:COMBAT_LOG_EVENT_UNFILTERED()
    if QRA.Triggers and QRA.Triggers.ProcessCombatLogEvent then
        QRA.Triggers.ProcessCombatLogEvent(CombatLogGetCurrentEventInfo())
    end
end

--------------------------------------------------
-- Encounter Events
--------------------------------------------------

function frame:ENCOUNTER_START(encounterId, encounterName, difficultyId, groupSize)
    QRA.Debug("ENCOUNTER_START:", encounterId, encounterName, difficultyId, groupSize)
    if QRA.Triggers and QRA.Triggers.OnEncounterStart then
        QRA.Triggers.OnEncounterStart(encounterId, encounterName)
    end
end

function frame:ENCOUNTER_END(encounterId, encounterName, difficultyId, groupSize, success)
    QRA.Debug("ENCOUNTER_END:", encounterId, encounterName, difficultyId, groupSize, success)
    if QRA.Triggers and QRA.Triggers.OnEncounterEnd then
        QRA.Triggers.OnEncounterEnd(encounterId, encounterName, success == 1)
    end

    -- Cancel any pending countdowns
    if QRA.Assignments and QRA.Assignments.CancelAllCountdowns then
        QRA.Assignments.CancelAllCountdowns()
    end
end

function frame:UNIT_HEALTH(unitId)
    QRA.Triggers.OnUnitHealth(unitId)
end

--------------------------------------------------
-- Constants
--------------------------------------------------
QRA.Triggers.Types = {
    SPELL_CAST_SUCCESS = {
        event = "SPELL_CAST_SUCCESS",
        name = "Spell Cast Success",
        abbreviation = "SCC",
    },
    SPELL_CAST_START = {
        event = "SPELL_CAST_START",
        name = "Spell Cast Start",
        abbreviation = "SCS",
    },
    SPELL_AURA_APPLIED = {
        event = "SPELL_AURA_APPLIED",
        name = "Aura Applied",
        abbreviation = "SAA",
    },
    SPELL_AURA_REMOVED = {
        event = "SPELL_AURA_REMOVED",
        name = "Aura Removed",
        abbreviation = "SAR",
    },
    UNIT_DIED = {
        event = "UNIT_DIED",
        name = "NPC Death",
        abbreviation = "NPCD",
    },
    TIMER = {
        event = "TIMER",
        name = "Timer",
        abbreviation = "TMR",
    },
    UNIT_HEALTH = {
        event = "UNIT_HEALTH",
        name = "Unit HP %",
        abbreviation = "UHP",
    },
}

local function GetTriggerTypeAbbreviation(triggerType)
    for key, info in pairs(QRA.Triggers.Types) do
        if key == triggerType then
            return info.abbreviation
        end
    end
    return "UNK"
end

--------------------------------------------------
-- State Management
--------------------------------------------------
local activeTriggers = {}      -- Currently active triggers for the encounter
local occurrenceCounts = {}    -- Track occurrences per trigger ID
local timerHandles = {}        -- Store timer handles for cleanup
local encounterActive = false  -- Is an encounter currently active?
local encounterStartTime = 0   -- When did the encounter start?
local triggerIndex = {}        -- Index of triggers by type and spellId/npcId
local previousUnitHP = {}      -- Track previous HP percentage per unit for UNIT_HEALTH triggers
local currentEncounterId = nil -- Current encounter ID for re-registration

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Check if a trigger should delay its activation
---@param trigger Trigger The trigger to check
---@return boolean shouldDelay True if the trigger should delay activation
local function ShouldDelayActivation(trigger)
    return trigger.activateIn and trigger.activateIn > 0
end

--- Generate a unique ID for a trigger
---@return string
local function GenerateTriggerID()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local id = ""

    for i = 1, 10 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end

    return id
end

--- Generate a default name for a trigger
--- @param triggerType string trigger type
--- @param config table trigger config
local function GenerateTriggerName(triggerType, config)
    if config.name and config.name ~= "" then
        return config.name
    end

    if triggerType == QRA.Triggers.Types.TIMER.event then
        local timeDisplay = string.format("%ds", config.time or 0)
        if config.repeatInterval and config.repeatInterval > 0 then
            if config.repeatCount and config.repeatCount > 0 then
                return string.format("%s / %ds x%d", timeDisplay, config.repeatInterval, config.repeatCount)
            end
            return string.format("%s / %ds", timeDisplay, config.repeatInterval)
        end
        return timeDisplay
    elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
        -- Format: "boss @ 25%, 50%, 75%"
        local hpDisplay = config.hpThresholds or ""
        -- Add % signs to each threshold
        hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
        return string.format("%s @ %s", config.targetGuid or "unknown", hpDisplay)
    else
        return string.format("%s %s",
            GetTriggerTypeAbbreviation(triggerType),
            config.spellName or config.targetGuid or "generic"
        )
    end
end

--- Reset occurrence counts for all triggers
local function ResetOccurrenceCounts()
    wipe(occurrenceCounts)
end

--- Public function to reset occurrence counts and re-register triggers (for DevMode)
--- This allows re-testing triggers that were exhausted
function QRA.Triggers.ResetOccurrences()
    ResetOccurrenceCounts()

    -- If an encounter is active, re-register all triggers to restore exhausted ones
    if encounterActive and currentEncounterId then
        QRA.Triggers.RegisterEncounterTriggers(currentEncounterId)
        QRA.Debug("Triggers: Re-registered triggers for encounter", currentEncounterId)
    end

    QRA.Debug("Triggers: Occurrence counts reset")
end

--- Increment and get the occurrence count for a trigger key
---@param key string The trigger key (type_spellId combination)
---@return number
local function IncrementOccurrence(key)
    occurrenceCounts[key] = (occurrenceCounts[key] or 0) + 1
    return occurrenceCounts[key]
end

--- Get current occurrence count for a trigger key
---@param key string The trigger key
---@return number
local function GetOccurrence(key)
    return occurrenceCounts[key] or 0
end

--- Parse HP threshold string into sorted array of integers
---@param thresholdStr string Comma-separated HP percentages (e.g., "25,50,75")
---@return table Sorted array of integers
local function ParseHPThresholds(thresholdStr)
    if not thresholdStr or thresholdStr == "" then return {} end

    local thresholds = {}
    for threshold in string.gmatch(thresholdStr, "[^,]+") do
        local num = tonumber(strtrim(threshold))
        if num and num >= 1 and num <= 100 then
            table.insert(thresholds, num)
        end
    end

    table.sort(thresholds)
    return thresholds
end

--- Extract NPC ID from unit GUID
---@param unitGuid string The unit's GUID
---@return number|nil The NPC ID or nil
local function GetNpcIdFromGuid(unitGuid)
    if not unitGuid then return nil end
    local npcId = select(6, strsplit("-", unitGuid))
    return tonumber(npcId)
end

--------------------------------------------------
-- Unit Health Handler
--------------------------------------------------

--- Process UNIT_HEALTH events for HP-based triggers
---@param unitId string The unit ID that had a health change
function QRA.Triggers.OnUnitHealth(unitId)
    if not encounterActive then return end

    -- Only monitor boss units
    if not unitId or not unitId:match("^boss%d?$") then return end

    -- Get current HP percentage
    local currentHP = UnitHealth(unitId)
    local maxHP = UnitHealthMax(unitId)
    if not currentHP or not maxHP or maxHP == 0 then return end

    local currentPercent = (currentHP / maxHP) * 100
    local previousPercent = previousUnitHP[unitId]

    -- First event for this unit - just store and return
    if not previousPercent then
        previousUnitHP[unitId] = currentPercent
        return
    end

    -- Only proceed if HP decreased
    if currentPercent >= previousPercent then
        previousUnitHP[unitId] = currentPercent
        return
    end

    -- Get triggers for this unit
    local triggersToCheck = {}

    -- Check specific unit triggers (boss1, boss2, etc.)
    if triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event] then
        local specificTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event][unitId]
        if specificTriggers then
            for _, trigger in ipairs(specificTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check generic "boss" triggers
        local bossTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event]["boss"]
        if bossTriggers then
            for _, trigger in ipairs(bossTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check NPC ID triggers
        local unitGuid = UnitGUID(unitId)
        if unitGuid then
            local npcId = GetNpcIdFromGuid(unitGuid)
            if npcId then
                local npcTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event][tostring(npcId)]
                if npcTriggers then
                    for _, trigger in ipairs(npcTriggers) do
                        table.insert(triggersToCheck, trigger)
                    end
                end
            end
        end
    end

    -- Process each trigger
    for _, trigger in ipairs(triggersToCheck) do
        if trigger.enabled then
            local thresholds = ParseHPThresholds(trigger.hpThresholds)

            -- Find the LOWEST crossed threshold
            local crossedThreshold = nil
            for _, threshold in ipairs(thresholds) do
                if previousPercent > threshold and currentPercent <= threshold then
                    if not crossedThreshold or threshold < crossedThreshold then
                        crossedThreshold = threshold
                    end
                end
            end

            if crossedThreshold then
                -- Use counter to ensure fire once per threshold
                local counterKey = string.format("%s_%s_%d",
                    trigger.type, trigger.targetGuid, crossedThreshold)
                local count = IncrementOccurrence(counterKey)

                -- Always fire once for UNIT_HEALTH (no counter formula check needed)
                if count == 1 then
                    local eventData = {
                        unitId = unitId,
                        unitGuid = UnitGUID(unitId),
                        threshold = crossedThreshold,
                        currentPercent = currentPercent,
                        previousPercent = previousPercent,
                    }

                    QRA.Debug("Triggers: Fired UNIT_HEALTH", trigger.id, "threshold", crossedThreshold, "%")

                    -- Check if we should delay the activation
                    if ShouldDelayActivation(trigger) then
                        QRA.Debug("Triggers: Delaying UNIT_HEALTH activation by", trigger.activateIn, "seconds")
                        QRA.DelayedInvoke(trigger.activateIn, function()
                            QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, count)
                        end)
                    else
                        QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, count)
                    end
                end
            end
        end
    end

    previousUnitHP[unitId] = currentPercent
end

--- Process UNIT_HEALTH events for fake bosses (DevMode)
--- This version takes fake boss data directly instead of using WoW API
---@param unitId string The fake boss unit ID
---@param unitGuid string The fake boss GUID
---@param currentPercent number Current HP percentage (0-100)
---@param previousPercent number Previous HP percentage (0-100)
function QRA.Triggers.ProcessFakeUnitHealth(unitId, unitGuid, currentPercent, previousPercent)
    if not encounterActive then return end

    -- Get triggers for this unit
    local triggersToCheck = {}

    -- Check specific unit triggers (boss1, boss2, etc.)
    if triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event] then
        local specificTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event][unitId]
        if specificTriggers then
            for _, trigger in ipairs(specificTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check generic "boss" triggers
        local bossTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event]["boss"]
        if bossTriggers then
            for _, trigger in ipairs(bossTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check NPC ID triggers
        if unitGuid then
            local npcId = GetNpcIdFromGuid(unitGuid)
            if npcId then
                local npcTriggers = triggerIndex[QRA.Triggers.Types.UNIT_HEALTH.event][tostring(npcId)]
                if npcTriggers then
                    for _, trigger in ipairs(npcTriggers) do
                        table.insert(triggersToCheck, trigger)
                    end
                end
            end
        end
    end

    QRA.Debug("Triggers: ProcessFakeUnitHealth", unitId, "checking", #triggersToCheck, "triggers")

    -- Process each trigger
    for _, trigger in ipairs(triggersToCheck) do
        if trigger.enabled then
            local thresholds = ParseHPThresholds(trigger.hpThresholds)

            -- Find the LOWEST crossed threshold
            local crossedThreshold = nil
            for _, threshold in ipairs(thresholds) do
                if previousPercent > threshold and currentPercent <= threshold then
                    if not crossedThreshold or threshold < crossedThreshold then
                        crossedThreshold = threshold
                    end
                end
            end

            if crossedThreshold then
                -- Use counter to ensure fire once per threshold
                local counterKey = string.format("%s_%s_%d",
                    trigger.type, trigger.targetGuid, crossedThreshold)
                local count = IncrementOccurrence(counterKey)

                -- Always fire once for UNIT_HEALTH (no counter formula check needed)
                if count == 1 then
                    local eventData = {
                        unitId = unitId,
                        unitGuid = unitGuid,
                        threshold = crossedThreshold,
                        currentPercent = currentPercent,
                        previousPercent = previousPercent,
                    }

                    QRA.Debug("Triggers: Fired UNIT_HEALTH (fake)", trigger.id, "threshold", crossedThreshold, "%")

                    -- Check if we should delay the activation
                    if ShouldDelayActivation(trigger) then
                        QRA.Debug("Triggers: Delaying UNIT_HEALTH (fake) activation by", trigger.activateIn, "seconds")
                        QRA.DelayedInvoke(trigger.activateIn, function()
                            QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, count)
                        end)
                    else
                        QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, count)
                    end
                end
            end
        end
    end
end

local function BuildTriggerIndex()
    wipe(triggerIndex)

    for _, trigger in pairs(activeTriggers) do
        if trigger.type ~= QRA.Triggers.Types.TIMER.event then
            if not triggerIndex[trigger.type] then
                triggerIndex[trigger.type] = {}
            end

            local idKey
            if trigger.type == QRA.Triggers.Types.UNIT_HEALTH.event or
                trigger.type == QRA.Triggers.Types.UNIT_DIED.event
            then
                -- For UNIT_HEALTH and UNIT_DIED, index by targetGuid (boss, boss1, or NPC ID)
                idKey = trigger.targetGuid
            else
                -- For other types, use spellId
                idKey = trigger.spellId
            end

            if idKey then
                if not triggerIndex[trigger.type][idKey] then
                    triggerIndex[trigger.type][idKey] = {}
                end
                table.insert(triggerIndex[trigger.type][idKey], trigger)
            end
        end
    end

    QRA.Debug("Triggers: Built trigger index with", #activeTriggers, triggerIndex)
end

local function RemoveFromIndex(trigger)
    if trigger.type == QRA.Triggers.Types.TIMER.event then
        return
    end

    local idKey
    if trigger.type == QRA.Triggers.Types.UNIT_HEALTH.event or
        trigger.type == QRA.Triggers.Types.UNIT_DIED.event then
        idKey = trigger.targetGuid
    else
        idKey = trigger.spellId
    end

    if idKey and triggerIndex[trigger.type] and triggerIndex[trigger.type][idKey] then
        for index, t in ipairs(triggerIndex[trigger.type][idKey]) do
            if t.id == trigger.id then
                table.remove(triggerIndex[trigger.type][idKey], index)
                QRA.Debug("Triggers: Removed trigger from index", trigger.id)
                break
            end
        end
    end
end

local function ShouldRemoveTrigger(trigger, currentCounter)
    local maxCounter = QRA.CounterFormula.GetMaxCounter(trigger.counterFormula)
    if not maxCounter then
        return false -- Infinite formula, never remove
    end
    return currentCounter >= maxCounter
end

--------------------------------------------------
-- Trigger Creation
--------------------------------------------------

--- Create a new trigger configuration
---@param triggerType string One of QRA.Triggers.Types
---@param config table Configuration specific to trigger type
---@param isNew boolean Whether this is a new trigger
---@return Trigger trigger The configured trigger object
function QRA.Triggers.Create(triggerType, config, isNew)
    -- QRA.Debug("Triggers: Creating new trigger of type", triggerType, "with config:", config)
    ---@type Trigger
    local trigger = {
        id = isNew and GenerateTriggerID() or config.id,
        version = 1,
        name = GenerateTriggerName(triggerType, config),
        type = triggerType,
        enabled = true,
        default = config.default or false,
        counterFormula = config.counterFormula, -- Counter formula (e.g., "1,3,5", ">2,+<6", "1%3")
        assignments = {},                       -- Linked assignments
        bossName = config.bossName,             -- Boss this trigger belongs to
        encounterId = config.encounterId,       -- Encounter ID
        createdAt = time(),
    }

    -- Type-specific configuration
    if triggerType == QRA.Triggers.Types.SPELL_CAST_SUCCESS.event or
        triggerType == QRA.Triggers.Types.SPELL_CAST_START.event then
        trigger.spellId = config.spellId
        trigger.spellName = config.spellName
        trigger.activateIn = config.activateIn -- Delay activation (non-Timer triggers only)
    elseif triggerType == QRA.Triggers.Types.SPELL_AURA_APPLIED.event or
        triggerType == QRA.Triggers.Types.SPELL_AURA_REMOVED.event then
        trigger.spellId = config.spellId
        trigger.spellName = config.spellName
        trigger.activateIn = config.activateIn
    elseif triggerType == QRA.Triggers.Types.TIMER.event then
        trigger.time = config.time
        trigger.repeatInterval = config.repeatInterval
        trigger.repeatCount = config.repeatCount
    elseif triggerType == QRA.Triggers.Types.UNIT_DIED.event then
        trigger.targetGuid = config.targetGuid
        trigger.activateIn = config.activateIn
    elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
        trigger.targetGuid = config.targetGuid -- "boss", "boss1", or numeric NPC ID
        trigger.hpThresholds = config.hpThresholds -- Raw comma-separated string "25,50,75"
        trigger.activateIn = config.activateIn
    end

    QRA.Debug("Triggers: Created trigger", trigger)
    return trigger
end

--------------------------------------------------
-- Trigger Registration
--------------------------------------------------

--- Register a trigger for the current encounter
---@param trigger table The trigger to register
function QRA.Triggers.Register(trigger)
    QRA.Debug("Triggers: Registering trigger", trigger.id)
    if not trigger or not trigger.id then
        QRA.Debug("Triggers: Invalid trigger registration attempt")
        return
    end

    activeTriggers[trigger.id] = trigger
end

--- Register all triggers for a specific encounter
---@param encounterId number The encounter ID
function QRA.Triggers.RegisterEncounterTriggers(encounterId)
    QRA.Debug("Triggers: Registering triggers for encounter ID", encounterId)
    QRA.Triggers.UnregisterAll()

    for _, trigger in ipairs(QRA.DB.triggers) do
        if trigger.encounterId == encounterId then
            QRA.Triggers.Register(trigger)
        end
    end

    BuildTriggerIndex()
end

-- Alias for internal calls
local RegisterEncounterTriggers = function(encounterId)
    QRA.Triggers.RegisterEncounterTriggers(encounterId)
end

--- Unregister a specific trigger
---@param triggerId string The trigger ID to unregister
function QRA.Triggers.Unregister(triggerId)
    if activeTriggers[triggerId] then
        activeTriggers[triggerId] = nil
        QRA.Debug("Triggers: Unregistered trigger", triggerId)
    end
end

--- Unregister all triggers
function QRA.Triggers.UnregisterAll()
    wipe(activeTriggers)
    QRA.Debug("Triggers: Unregistered all triggers")
end

--- Get all triggers
---@return Trigger[]
function QRA.Triggers.GetAll()
    return QRA.DB.triggers
end

--- Get triggers for a specific boss
--- @param bossName string boss name
--- @return Trigger[]
function QRA.Triggers.GetBossTriggers(bossName)
    local triggers = {}

    ---@param a Trigger
    ---@param b Trigger
    local function sortFunction(a, b)
        -- QRA.Debug("Sorting triggers", {a.default, a.type, a.time}, {b.default, b.type, b.time})
        if a.default and not b.default then
            return true
        end
        if not a.default and b.default then
            return false
        end
        if a.type == "TIMER" and b.type ~= "TIMER" then
            return true
        end
        if a.type ~= "TIMER" and b.type == "TIMER" then
            return false
        end
        if a.type ~= "TIMER" and b.type ~= "TIMER" then
            return a.createdAt < b.createdAt
        end
        return (a.time or 0) < (b.time or 0)
    end

    for _, trigger in ipairs(QRA.DB.triggers) do
        if trigger.bossName == bossName then
            table.insert(triggers, trigger)
        end
    end

    table.sort(triggers, sortFunction)
    return triggers
end

--- Get triggers for a specific encounter ID
--- @param encounterId number encounter id
--- @return Trigger[]
function QRA.Triggers.GetTriggersByEncounterId(encounterId)
    local triggers = {}

    for _, trigger in ipairs(QRA.DB.triggers) do
        if trigger.encounterId == encounterId then
            table.insert(triggers, trigger)
        end
    end

    return triggers
end

--- Get a specific trigger by ID
---@param triggerId string
---@return Trigger|nil
function QRA.Triggers.Get(triggerId)
    for _, trigger in ipairs(QRA.DB.triggers) do
        if trigger.id == triggerId then
            return trigger
        end
    end
    return nil
end

--------------------------------------------------
-- Trigger Persistence
--------------------------------------------------

--- Save a new trigger to the database
--- @param trigger Trigger trigger to save
function QRA.Triggers.SaveTrigger(trigger)
    if not trigger or not trigger.id then
        QRA.Debug("Triggers: Invalid trigger save attempt")
        return
    end

    table.insert(QRA.DB.triggers, trigger)
    QRA.Debug("Triggers: Saved trigger", trigger.id)
end

--- Update an existing trigger in the database
--- @param trigger Trigger trigger to update
function QRA.Triggers.UpdateTrigger(trigger)
    if not trigger or not trigger.id then
        QRA.Debug("Triggers: Invalid trigger update attempt")
        return
    end

    for index, existingTrigger in ipairs(QRA.DB.triggers) do
        if existingTrigger.id == trigger.id then
            QRA.DB.triggers[index] = trigger
            QRA.Debug("Triggers: Updated trigger", trigger.id)
            return
        end
    end

    QRA.Debug("Triggers: Trigger not found for update", trigger.id)
end

--- Insert or update a trigger in the database
---@param trigger Trigger trigger to upsert
function QRA.Triggers.UpsertTrigger(trigger)
    if not trigger or not trigger.id then
        QRA.Print("Triggers: Invalid trigger upsert attempt")
        return
    end

    for index, existingTrigger in ipairs(QRA.DB.triggers) do
        if existingTrigger.id == trigger.id then
            QRA.DB.triggers[index] = trigger
            QRA.Debug("Triggers: Upserted (updated) trigger", trigger.id)
            return
        end
    end

    table.insert(QRA.DB.triggers, trigger)
    QRA.Debug("Triggers: Upserted (saved) new trigger", trigger.id)
end

--- Delete a trigger from the database
--- @param triggerId string trigger ID to delete
--- @param orphanAssignments boolean|nil If true, move assignments to orphaned. If false, delete them. If nil, just delete trigger (assignments already handled)
function QRA.Triggers.DeleteTrigger(triggerId, orphanAssignments)
    for index, trigger in ipairs(QRA.DB.triggers) do
        if trigger.id == triggerId then
            -- Handle assignments if present and orphanAssignments is specified
            if orphanAssignments ~= nil and trigger.assignments and #trigger.assignments > 0 then
                if orphanAssignments then
                    -- Move assignments to orphaned
                    QRA.Assignments.OrphanAssignments(triggerId, trigger.assignments)
                end
                -- If orphanAssignments is false, assignments are just deleted with the trigger
            end
            
            table.remove(QRA.DB.triggers, index)
            QRA.Debug("Triggers: Deleted trigger", triggerId)
            return true
        end
    end
    QRA.Debug("Triggers: Trigger not found for deletion", triggerId)
    return false
end

--- Check if a trigger has assignments
---@param triggerId string
---@return boolean hasAssignments
---@return number count
function QRA.Triggers.HasAssignments(triggerId)
    local trigger = QRA.Triggers.Get(triggerId)
    if trigger and trigger.assignments then
        return #trigger.assignments > 0, #trigger.assignments
    end
    return false, 0
end

--------------------------------------------------
-- Timer Trigger Handling
--------------------------------------------------

--- Start all timer-based triggers
local function StartTimerTriggers()
    for id, trigger in pairs(activeTriggers) do
        if trigger.type == QRA.Triggers.Types.TIMER.event and trigger.enabled then
            local function FireTimer()
                if not encounterActive then return end
                QRA.Triggers.Fire(trigger)
            end

            if trigger.repeatInterval and trigger.repeatInterval > 0 then
                -- Repeating timer: fire at initial time, then every interval after that
                local initialTime = trigger.time or 0
                -- Store handles in a table so we can cancel both initial and ticker
                timerHandles[id] = { initial = nil, ticker = nil }
                local handleEntry = timerHandles[id]

                handleEntry.initial = C_Timer.NewTimer(initialTime, function()
                    if not encounterActive then return end
                    QRA.Triggers.Fire(trigger)
                    -- Start the repeating ticker after the first fire
                    -- repeatCount is total fires, so ticker fires (repeatCount - 1) additional times
                    local repeatCount = trigger.repeatCount
                    if repeatCount and repeatCount > 1 then
                        -- Subtract 1 because the initial fire already happened
                        handleEntry.ticker = C_Timer.NewTicker(trigger.repeatInterval, FireTimer, repeatCount - 1)
                    elseif not repeatCount or repeatCount == 0 then
                        -- No limit, repeat indefinitely
                        handleEntry.ticker = C_Timer.NewTicker(trigger.repeatInterval, FireTimer)
                    end
                    -- If repeatCount == 1, no ticker needed (only the initial fire)
                end)
            else
                -- One-shot timer
                C_Timer.After(trigger.time or 0, FireTimer)
            end
        end
    end
end

--- Cancel all active timer triggers
local function CancelTimerTriggers()
    for id, handle in pairs(timerHandles) do
        if type(handle) == "table" then
            -- New format: table with initial and ticker
            if handle.initial and handle.initial.Cancel then
                handle.initial:Cancel()
            end
            if handle.ticker and handle.ticker.Cancel then
                handle.ticker:Cancel()
            end
        elseif handle and handle.Cancel then
            -- Legacy format: single handle
            handle:Cancel()
        end
    end
    wipe(timerHandles)
end

--------------------------------------------------
-- Trigger Firing
--------------------------------------------------

--- Fire a trigger, checking occurrence count
---@param trigger Trigger The trigger that fired
---@param eventData table|nil Additional data from the event
function QRA.Triggers.Fire(trigger, eventData)
    if not trigger or not trigger.enabled then return end

    -- Generate key for counter tracking (based on type and identifier)
    local counterKey = string.format("%s_%s",
        trigger.type,
        trigger.spellId or trigger.targetGuid or trigger.time or "generic"
    )

    local currentCounter = IncrementOccurrence(counterKey)

    -- Check if this counter matches the trigger's formula
    if QRA.CounterFormula.Matches(trigger.counterFormula, currentCounter) then
        QRA.Debug("Triggers: Fired", trigger.id, "counter", currentCounter)

        -- Check if we should delay the activation
        if ShouldDelayActivation(trigger) then
            QRA.Debug("Triggers: Delaying activation by", trigger.activateIn, "seconds")
            QRA.DelayedInvoke(trigger.activateIn, function()
                -- Execute linked assignments after delay
                QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, currentCounter)
            end)
        else
            -- Execute linked assignments immediately
            QRA.Assignments.ExecuteForTrigger(trigger.id, eventData, currentCounter)
        end
    end

    -- Check if trigger is exhausted and should be removed
    if ShouldRemoveTrigger(trigger, currentCounter) then
        QRA.Triggers.Unregister(trigger.id)
        RemoveFromIndex(trigger)
        QRA.Debug("Triggers: Unregistered exhausted trigger", trigger.id)
    end
end

--------------------------------------------------
-- Combat Log Event Handling
--------------------------------------------------

--- Process combat log events and check triggers
function QRA.Triggers.ProcessCombatLogEvent(...)
    -- QRA.Debug("Triggers: Processing combat log event")
    if not encounterActive then return end

    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName = ...

    local eventBucket = triggerIndex[subevent]
    if not eventBucket then return end

    local spellId, spellName
    if subevent:find("SPELL") or subevent:find("RANGE") then
        spellId = select(12, ...)
    end

    local triggersToCheck = {}
    if subevent == QRA.Triggers.Types.UNIT_DIED.event then
        local npcId = select(6, strsplit("-", destGUID))

        -- Check NPC ID triggers
        local npcTriggers = eventBucket[tonumber(npcId)]
        if npcTriggers then
            for _, trigger in ipairs(npcTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check generic "boss" triggers
        local bossTriggers = eventBucket["boss"]
        if bossTriggers then
            for _, trigger in ipairs(bossTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end

        -- Check specific unit ID triggers (boss1, boss2, etc.)
        for i = 1, 8 do
            local unitId = i == 1 and "boss" or "boss" .. i
            if UnitExists(unitId) and UnitGUID(unitId) == destGUID then
                local unitTriggers = eventBucket[unitId]
                if unitTriggers then
                    for _, trigger in ipairs(unitTriggers) do
                        table.insert(triggersToCheck, trigger)
                    end
                end
                break
            end
        end
    elseif spellId then
        local spellTriggers = eventBucket[spellId]
        if spellTriggers then
            for _, trigger in ipairs(spellTriggers) do
                table.insert(triggersToCheck, trigger)
            end
        end
    end

    if #triggersToCheck == 0 then return end

    local eventData = {
        timestamp = timestamp,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        destGUID = destGUID,
        destName = destName,
        spellId = spellId,
        spellName = spellName,
    }

    for _, trigger in ipairs(triggersToCheck) do
        QRA.Debug("Checking trigger:", trigger.id, "Type:", trigger.type)
        if trigger.enabled then
            local shouldFire = false

            -- Check trigger type matches event
            if subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" then
                QRA.Debug("Checking SPELL_CAST_SUCCESS trigger for spell ID:", spellId)
                if not trigger.sourceUnit or UnitGUID(trigger.sourceUnit) == sourceGUID then
                    shouldFire = true
                end
            elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REMOVED" then
                if not trigger.targetUnit or UnitGUID(trigger.targetUnit) == destGUID then
                    shouldFire = true
                end
            elseif subevent == "UNIT_DIED" then
                -- For UNIT_DIED triggers, check if targetGuid matches destGUID
                if not trigger.targetGuid or UnitGUID(trigger.targetGuid) == destGUID then
                    shouldFire = true
                end
            end

            if shouldFire then
                QRA.Triggers.Fire(trigger, eventData)
            end
        end
    end
end

--------------------------------------------------
-- Encounter Management
--------------------------------------------------

--- Called when an encounter starts
---@param encounterId number The encounter ID
---@param encounterName string The encounter name
function QRA.Triggers.OnEncounterStart(encounterId, encounterName)
    QRA.Debug("Triggers: Encounter started -", encounterName, "(ID:", encounterId, ")")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("UNIT_HEALTH")

    encounterActive = true
    encounterStartTime = GetTime()
    currentEncounterId = encounterId -- Store for potential re-registration
    wipe(previousUnitHP)           -- Reset HP tracking
    RegisterEncounterTriggers(encounterId)
    ResetOccurrenceCounts()
    StartTimerTriggers()
end

--- Called when an encounter ends
---@param encounterId number The encounter ID
---@param encounterName string The encounter name
---@param success boolean Whether the encounter was successful
function QRA.Triggers.OnEncounterEnd(encounterId, encounterName, success)
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:UnregisterEvent("UNIT_HEALTH")
    encounterActive = false
    currentEncounterId = nil -- Clear encounter ID
    wipe(previousUnitHP)   -- Clear HP tracking
    CancelTimerTriggers()
    ResetOccurrenceCounts()

    QRA.Debug("Triggers: Encounter ended -", encounterName, success and "(Success)" or "(Wipe)")
end

--- Get current encounter time
---@return number Time in seconds since encounter start
function QRA.Triggers.GetEncounterTime()
    if not encounterActive then return 0 end
    return GetTime() - encounterStartTime
end

--- Check if an encounter is currently active
---@return boolean
function QRA.Triggers.IsEncounterActive()
    return encounterActive
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

local function CreateDefaultBossTriggers()
    local bosses = QRA.Bosses.GetAllBosses()
    for _, instanceData in pairs(bosses) do
        for _, bossData in ipairs(instanceData.bosses) do
            local triggers = bossData.triggers
            if triggers then
                for _, trigger in ipairs(triggers) do
                    local triggerId = bossData.name .. "_" .. trigger.type .. "_" .. (trigger.spellId or trigger.targetGuid or trigger.time or "generic")
                    local existingTrigger = QRA.Triggers.Get(triggerId)
                    if not existingTrigger then
                        local newTrigger = QRA.Triggers.Create(trigger.type, QRA.TableMerge({
                            id = triggerId,
                            default = true,
                            bossName = bossData.name,
                            encounterId = bossData.encounterId,
                        }, trigger), false)
                        QRA.Triggers.SaveTrigger(newTrigger)
                    end
                end
            end
        end
    end
end

function QRA.Triggers.Initialize()
    CreateDefaultBossTriggers()
    QRA.Debug("Triggers: Module initialized")
end
