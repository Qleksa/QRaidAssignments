--[[
    QRaidAssignments - Dev Mode: Event Firer
    Fires simulated combat log and other events for testing triggers
]]

---@class QRA
local QRA = select(2, ...)
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.EventFirer = {}

local EventFirer = QRA.DevMode.EventFirer
local FakeEncounter = QRA.DevMode.FakeEncounter

--------------------------------------------------
-- Event Type Definitions
--------------------------------------------------
EventFirer.EventTypes = {
    SPELL_CAST_SUCCESS = {
        name = "Spell Cast Success",
        requiresSpell = true,
        requiresSource = true,
        requiresTarget = false,
    },
    SPELL_CAST_START = {
        name = "Spell Cast Start",
        requiresSpell = true,
        requiresSource = true,
        requiresTarget = false,
    },
    SPELL_AURA_APPLIED = {
        name = "Aura Applied",
        requiresSpell = true,
        requiresSource = true,
        requiresTarget = true,
    },
    SPELL_AURA_REMOVED = {
        name = "Aura Removed",
        requiresSpell = true,
        requiresSource = true,
        requiresTarget = true,
    },
    UNIT_DIED = {
        name = "Unit Died",
        requiresSpell = false,
        requiresSource = false,
        requiresTarget = true,
    },
}

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Get a fake boss GUID, defaulting to boss1
---@param unitId string|nil
---@return string guid
---@return string name
---@return number npcId
local function GetFakeBossInfo(unitId)
    unitId = unitId or "boss1"
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if boss then
        return boss.guid, boss.name, boss.npcId
    end
    -- Fallback
    return "Creature-0-0-0-0-0-00000001", "Unknown Boss", 0
end

--- Get player info
---@param playerName string|nil
---@return string guid
---@return string name
local function GetPlayerInfo(playerName)
    if not playerName then
        local playerName = UnitName("player")
        return UnitGUID("player"), playerName
    end

    local player = QRA.DevMode.GetPlayer(playerName)
    if player then
        return player.guid, player.name
    end

    -- Fallback to self
    local playerName = UnitName("player")
    return UnitGUID("player"), playerName
end

--- Build a fake combat log event payload
---@param subEvent string
---@param sourceGUID string
---@param sourceName string
---@param destGUID string|nil
---@param destName string|nil
---@param spellId number|nil
---@param spellName string|nil
---@return table
local function BuildCombatLogPayload(subEvent, sourceGUID, sourceName, destGUID, destName, spellId, spellName)
    -- CombatLogGetCurrentEventInfo() returns:
    -- timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
    -- destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, ...

    local timestamp = GetTime()
    local hideCaster = false
    local sourceFlags = 0x0a48  -- COMBATLOG_OBJECT_REACTION_HOSTILE + OBJECT_TYPE_NPC
    local sourceRaidFlags = 0
    local destFlags = destGUID and 0x0511 or 0  -- COMBATLOG_OBJECT_REACTION_FRIENDLY if has dest
    local destRaidFlags = 0
    local spellSchool = 1  -- Physical

    return {
        timestamp,
        subEvent,
        hideCaster,
        sourceGUID,
        sourceName,
        sourceFlags,
        sourceRaidFlags,
        destGUID or "",
        destName or "",
        destFlags,
        destRaidFlags,
        spellId or 0,
        spellName or "",
        spellSchool,
    }
end

--------------------------------------------------
-- Event Firing Functions
--------------------------------------------------

--- Fire a combat log event directly to the trigger processor
---@param eventData table The combat log event data
local function FireToTriggerProcessor(eventData)
    if QRA.Triggers and QRA.Triggers.ProcessCombatLogEvent then
        QRA.Triggers.ProcessCombatLogEvent(unpack(eventData))
        QRA.Debug("EventFirer: Fired event", eventData[2], eventData[13] and "spell: " .. eventData[13])
    end
end

--- Fire a spell cast success event
---@param spellId number
---@param sourceUnitId string|nil Boss unit ID (default: "boss1")
---@param targetName string|nil Target player name (optional)
---@return boolean success
function EventFirer.FireSpellCastSuccess(spellId, sourceUnitId, targetName)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local sourceGUID, sourceName = GetFakeBossInfo(sourceUnitId)
    local destGUID, destName = nil, nil
    if targetName then
        destGUID, destName = GetPlayerInfo(targetName)
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local spellName = spellInfo and spellInfo.name or "Unknown Spell"

    local eventData = BuildCombatLogPayload(
        "SPELL_CAST_SUCCESS",
        sourceGUID, sourceName,
        destGUID, destName,
        spellId, spellName
    )

    FireToTriggerProcessor(eventData)

    -- Log event
    QRA.DevMode.EventHistory.AddEvent("SPELL_CAST_SUCCESS", {
        spellId = spellId,
        spellName = spellName,
        sourceUnitId = sourceUnitId,
        targetName = targetName,
    })

    return true
end

--- Fire a spell cast start event
---@param spellId number
---@param sourceUnitId string|nil Boss unit ID (default: "boss1")
---@return boolean success
function EventFirer.FireSpellCastStart(spellId, sourceUnitId)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local sourceGUID, sourceName = GetFakeBossInfo(sourceUnitId)

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local spellName = spellInfo and spellInfo.name or "Unknown Spell"

    local eventData = BuildCombatLogPayload(
        "SPELL_CAST_START",
        sourceGUID, sourceName,
        nil, nil,
        spellId, spellName
    )

    FireToTriggerProcessor(eventData)

    QRA.DevMode.EventHistory.AddEvent("SPELL_CAST_START", {
        spellId = spellId,
        spellName = spellName,
        sourceUnitId = sourceUnitId,
    })

    return true
end

--- Fire an aura applied event
---@param spellId number
---@param targetName string|nil Target player name (default: self)
---@param sourceUnitId string|nil Source boss unit ID (default: "boss1")
---@param duration number|nil Debuff duration for fake player tracking
---@return boolean success
function EventFirer.FireAuraApplied(spellId, targetName, sourceUnitId, duration)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local sourceGUID, sourceName = GetFakeBossInfo(sourceUnitId)
    local destGUID, destName = GetPlayerInfo(targetName)

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local spellName = spellInfo and spellInfo.name or "Unknown Spell"

    local eventData = BuildCombatLogPayload(
        "SPELL_AURA_APPLIED",
        sourceGUID, sourceName,
        destGUID, destName,
        spellId, spellName
    )

    FireToTriggerProcessor(eventData)

    QRA.DevMode.EventHistory.AddEvent("SPELL_AURA_APPLIED", {
        spellId = spellId,
        spellName = spellName,
        sourceUnitId = sourceUnitId,
        targetName = destName,
        duration = duration,
    })

    return true
end

--- Fire an aura removed event
---@param spellId number
---@param targetName string|nil Target player name (default: self)
---@param sourceUnitId string|nil Source boss unit ID (default: "boss1")
---@return boolean success
function EventFirer.FireAuraRemoved(spellId, targetName, sourceUnitId)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local sourceGUID, sourceName = GetFakeBossInfo(sourceUnitId)
    local destGUID, destName = GetPlayerInfo(targetName)

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local spellName = spellInfo and spellInfo.name or "Unknown Spell"

    local eventData = BuildCombatLogPayload(
        "SPELL_AURA_REMOVED",
        sourceGUID, sourceName,
        destGUID, destName,
        spellId, spellName
    )

    FireToTriggerProcessor(eventData)

    QRA.DevMode.EventHistory.AddEvent("SPELL_AURA_REMOVED", {
        spellId = spellId,
        spellName = spellName,
        sourceUnitId = sourceUnitId,
        targetName = destName,
    })

    return true
end

--- Fire an NPC death event
---@param npcId number|nil NPC ID (uses boss1's npcId if nil)
---@param unitId string|nil Boss unit ID (default: "boss1")
---@return boolean success
function EventFirer.FireNPCDeath(npcId, unitId)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local destGUID, destName, bossNpcId = GetFakeBossInfo(unitId)
    npcId = npcId or bossNpcId

    -- UNIT_DIED doesn't have spell info
    local eventData = BuildCombatLogPayload(
        "UNIT_DIED",
        "", "",
        destGUID, destName
    )

    FireToTriggerProcessor(eventData)

    QRA.DevMode.EventHistory.AddEvent("UNIT_DIED", {
        npcId = npcId,
        unitId = unitId,
        name = destName,
    })

    return true
end

--- Fire a unit health change event (for UNIT_HEALTH triggers)
---@param unitId string Boss unit ID
---@param newHealthPercent number New health percentage (0-100)
---@param oldHealthPercent number Old health percentage (0-100)
---@return boolean success
function EventFirer.FireUnitHealthChange(unitId, newHealthPercent, oldHealthPercent)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    -- Only process if health decreased
    if newHealthPercent >= oldHealthPercent then
        QRA.Debug("EventFirer: Health increased or unchanged, skipping", unitId, oldHealthPercent, "->", newHealthPercent)
        return false
    end

    local boss = FakeEncounter.GetFakeBoss(unitId)
    if not boss then
        QRA.Debug("EventFirer: Fake boss not found for", unitId)
        return false
    end

    QRA.Debug("EventFirer: Health change", unitId, oldHealthPercent, "->", newHealthPercent)

    -- Log event
    QRA.DevMode.EventHistory.AddEvent("UNIT_HEALTH", {
        unitId = unitId,
        oldHealth = oldHealthPercent,
        newHealth = newHealthPercent,
    })

    -- Call the trigger processor with fake boss data
    if QRA.Triggers and QRA.Triggers.ProcessFakeUnitHealth then
        QRA.Triggers.ProcessFakeUnitHealth(unitId, boss.guid, newHealthPercent, oldHealthPercent)
    end

    return true
end

--- Fire a timer trigger manually
---@param triggerId string The trigger ID
---@return boolean success
function EventFirer.FireTimerTrigger(triggerId)
    if not FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    local trigger = QRA.Triggers.Get(triggerId)
    if not trigger then
        QRA.Print(QRA.L["DevMode: Trigger not found"])
        return false
    end

    if trigger.type ~= "TIMER" then
        QRA.Print(QRA.L["DevMode: Not a timer trigger"])
        return false
    end

    -- Fire the timer trigger's assignments directly
    if QRA.Assignments and QRA.Assignments.ExecuteForTrigger then
        QRA.Assignments.ExecuteForTrigger(triggerId, { time = trigger.time }, 1)
    end

    QRA.DevMode.EventHistory.AddEvent("TIMER", {
        triggerId = triggerId,
        time = trigger.time,
    })

    QRA.Debug("EventFirer: Fired timer trigger", triggerId)
    return true
end

--------------------------------------------------
-- Generic Trigger Firing
--------------------------------------------------

--- Fire an event for a specific trigger
---@param trigger Trigger The trigger object
---@return boolean success
function EventFirer.FireTrigger(trigger)
    if not trigger then return false end

    if trigger.type == "SPELL_CAST_SUCCESS" then
        return EventFirer.FireSpellCastSuccess(trigger.spellId, "boss1")
    elseif trigger.type == "SPELL_CAST_START" then
        return EventFirer.FireSpellCastStart(trigger.spellId, "boss1")
    elseif trigger.type == "SPELL_AURA_APPLIED" then
        return EventFirer.FireAuraApplied(trigger.spellId, nil, "boss1")
    elseif trigger.type == "SPELL_AURA_REMOVED" then
        return EventFirer.FireAuraRemoved(trigger.spellId, nil, "boss1")
    elseif trigger.type == "UNIT_DIED" then
        return EventFirer.FireNPCDeath(nil, trigger.targetGuid)
    elseif trigger.type == "TIMER" then
        return EventFirer.FireTimerTrigger(trigger.id)
    elseif trigger.type == "UNIT_HEALTH" then
        -- For UNIT_HEALTH, we need the user to set the HP threshold
        -- This is handled through the Fake Boss UI
        QRA.Print(QRA.L["DevMode: Use the Fake Boss panel to change HP"])
        return false
    end

    return false
end
