--[[
    QRaidAssignments - Dev Mode: Fake Encounter
    Simulates encounter start/end and manages fake boss units
]]

---@class QRA
local QRA = QRA
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.FakeEncounter = {}

local FakeEncounter = QRA.DevMode.FakeEncounter

--------------------------------------------------
-- State
--------------------------------------------------
local isEncounterActive = false
local encounterStartTime = 0
local currentEncounterId = nil
local currentBossName = nil
local fakeBosses = {}  -- Table of fake boss data

--------------------------------------------------
-- Fake Boss Data Structure
--------------------------------------------------
--[[
    FakeBoss = {
        unitId = "boss1",
        npcId = 12345,
        name = "Boss Name",
        guid = "Creature-0-0-0-0-12345-0000000001",
        maxHealth = 100,
        currentHealth = 100,
        debuffs = {},  -- Active debuffs on this boss
    }
]]

--------------------------------------------------
-- Boss Management
--------------------------------------------------

--- Generate a fake GUID for an NPC
---@param npcId number
---@param index number
---@return string
local function GenerateFakeGuid(npcId, index)
    return string.format("Creature-0-0-0-0-%d-%08X", npcId, index)
end

--- Initialize fake bosses for an encounter
---@param encounterId number
---@param bossName string
local function InitializeFakeBosses(encounterId, bossName)
    wipe(fakeBosses)

    -- Get boss data from Bosses.lua
    local _, _, bossData = QRA.Bosses.GetBossByName(bossName)

    if bossData then
        -- For now, create a single boss. Could be extended for multi-boss fights
        fakeBosses[1] = {
            unitId = "boss1",
            npcId = bossData.npcId or encounterId,  -- Use encounterId as fallback
            name = bossName,
            guid = GenerateFakeGuid(bossData.npcId or encounterId, 1),
            maxHealth = 100,
            currentHealth = 100,
            debuffs = {},
        }

        -- TODO: Add support for multi-boss encounters based on boss data
        -- For now, encounters with multiple bosses can be added manually
    else
        -- Fallback: create a generic boss
        fakeBosses[1] = {
            unitId = "boss1",
            npcId = encounterId,
            name = bossName or "Unknown Boss",
            guid = GenerateFakeGuid(encounterId, 1),
            maxHealth = 100,
            currentHealth = 100,
            debuffs = {},
        }
    end

    QRA.Debug("FakeEncounter: Initialized", #fakeBosses, "boss(es)")
end

--------------------------------------------------
-- Encounter Management
--------------------------------------------------

--- Check if fake encounter is active
---@return boolean
function FakeEncounter.IsActive()
    return isEncounterActive
end

--- Start a fake encounter
---@param bossName string The boss name
---@param encounterId number|nil The encounter ID (optional, will look up from boss name)
function FakeEncounter.Start(bossName, encounterId)
    if isEncounterActive then
        QRA.Debug("FakeEncounter: Already active, stopping first")
        FakeEncounter.Stop()
    end

    -- Look up encounter ID if not provided
    if not encounterId and bossName then
        local _, _, bossData = QRA.Bosses.GetBossByName(bossName)
        if bossData then
            encounterId = bossData.encounterId
        end
    end

    if not encounterId then
        QRA.Print(QRA.L["DevMode: Could not find encounter ID for boss:"], bossName)
        return false
    end

    currentEncounterId = encounterId
    currentBossName = bossName
    isEncounterActive = true
    encounterStartTime = GetTime()

    -- Initialize fake bosses
    InitializeFakeBosses(encounterId, bossName)

    -- Persist state
    QRA.DB.devMode.encounterActive = true

    -- Fire the encounter start through the normal trigger system
    QRA.Debug("FakeEncounter: Starting fake encounter -", bossName, "(ID:", encounterId, ")")

    -- Call the trigger system's OnEncounterStart
    if QRA.Triggers and QRA.Triggers.OnEncounterStart then
        QRA.Triggers.OnEncounterStart(encounterId, bossName)
    end

    -- Notify UI
    if FakeEncounter.OnEncounterStateChanged then
        FakeEncounter.OnEncounterStateChanged(true, bossName, encounterId)
    end

    return true
end

--- Stop the fake encounter
---@param success boolean|nil Whether the encounter was successful (default: false)
function FakeEncounter.Stop(success)
    if not isEncounterActive then
        QRA.Debug("FakeEncounter: No active encounter to stop")
        return
    end

    local endEncounterId = currentEncounterId
    local endBossName = currentBossName

    isEncounterActive = false
    currentEncounterId = nil
    currentBossName = nil
    encounterStartTime = 0

    -- Clear fake bosses
    wipe(fakeBosses)

    -- Persist state
    QRA.DB.devMode.encounterActive = false

    -- Fire the encounter end through the normal trigger system
    QRA.Debug("FakeEncounter: Stopping fake encounter -", endBossName, success and "(Success)" or "(Wipe)")

    if QRA.Triggers and QRA.Triggers.OnEncounterEnd then
        QRA.Triggers.OnEncounterEnd(endEncounterId, endBossName, success or false)
    end

    -- Notify UI
    if FakeEncounter.OnEncounterStateChanged then
        FakeEncounter.OnEncounterStateChanged(false, endBossName, endEncounterId)
    end
end

--- Get encounter time
---@return number
function FakeEncounter.GetEncounterTime()
    if not isEncounterActive then return 0 end
    return GetTime() - encounterStartTime
end

--- Get current encounter info
---@return number|nil encounterId
---@return string|nil bossName
function FakeEncounter.GetCurrentEncounter()
    return currentEncounterId, currentBossName
end

--------------------------------------------------
-- Fake Boss Management
--------------------------------------------------

--- Get all fake bosses
---@return table
function FakeEncounter.GetFakeBosses()
    return fakeBosses
end

--- Get a specific fake boss
---@param unitId string e.g., "boss1"
---@return table|nil
function FakeEncounter.GetFakeBoss(unitId)
    for _, boss in ipairs(fakeBosses) do
        if boss.unitId == unitId then
            return boss
        end
    end
    return nil
end

--- Get fake boss by index
---@param index number
---@return table|nil
function FakeEncounter.GetFakeBossByIndex(index)
    return fakeBosses[index]
end

--- Add a fake boss (for multi-boss encounters)
---@param name string
---@param npcId number|nil
---@return table boss
function FakeEncounter.AddFakeBoss(name, npcId)
    local index = #fakeBosses + 1
    local boss = {
        unitId = "boss" .. index,
        npcId = npcId or (currentEncounterId + index),
        name = name,
        guid = GenerateFakeGuid(npcId or (currentEncounterId + index), index),
        maxHealth = 100,
        currentHealth = 100,
        debuffs = {},
    }
    table.insert(fakeBosses, boss)
    QRA.Debug("FakeEncounter: Added fake boss", name, "as", boss.unitId)
    return boss
end

--- Remove a fake boss
---@param unitId string
function FakeEncounter.RemoveFakeBoss(unitId)
    for i, boss in ipairs(fakeBosses) do
        if boss.unitId == unitId then
            table.remove(fakeBosses, i)
            QRA.Debug("FakeEncounter: Removed fake boss", unitId)
            return true
        end
    end
    return false
end

--- Set fake boss health percentage
---@param unitId string
---@param healthPercent number 0-100
function FakeEncounter.SetBossHealth(unitId, healthPercent)
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if boss then
        local oldHealth = boss.currentHealth
        boss.currentHealth = math.max(0, math.min(100, healthPercent))

        QRA.Debug("FakeEncounter: Set", unitId, "health from", oldHealth, "to", boss.currentHealth)

        -- If health decreased, fire a UNIT_HEALTH-like event through EventFirer
        if boss.currentHealth < oldHealth and QRA.DevMode.EventFirer then
            QRA.DevMode.EventFirer.FireUnitHealthChange(unitId, boss.currentHealth, oldHealth)
        end

        return true
    end
    return false
end

--- Get fake boss health
---@param unitId string
---@return number|nil currentHealth
---@return number|nil maxHealth
function FakeEncounter.GetBossHealth(unitId)
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if boss then
        return boss.currentHealth, boss.maxHealth
    end
    return nil, nil
end

--------------------------------------------------
-- Fake Boss Debuffs
--------------------------------------------------

--- Apply a debuff to a fake boss
---@param unitId string
---@param spellId number
---@param duration number Duration in seconds (0 = permanent until removed)
---@return boolean success
function FakeEncounter.ApplyBossDebuff(unitId, spellId, duration)
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if not boss then return false end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local debuff = {
        spellId = spellId,
        spellName = spellInfo and spellInfo.name or "Unknown",
        appliedAt = GetTime(),
        duration = duration,
        expiresAt = duration > 0 and (GetTime() + duration) or nil,
    }

    boss.debuffs[spellId] = debuff
    QRA.Debug("FakeEncounter: Applied debuff", debuff.spellName, "to", unitId, "for", duration, "sec")

    -- Schedule removal if duration > 0
    if duration > 0 then
        C_Timer.After(duration, function()
            FakeEncounter.RemoveBossDebuff(unitId, spellId)
        end)
    end

    return true
end

--- Remove a debuff from a fake boss
---@param unitId string
---@param spellId number
---@return boolean success
function FakeEncounter.RemoveBossDebuff(unitId, spellId)
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if not boss or not boss.debuffs[spellId] then return false end

    local debuff = boss.debuffs[spellId]
    boss.debuffs[spellId] = nil
    QRA.Debug("FakeEncounter: Removed debuff", debuff.spellName, "from", unitId)

    return true
end

--- Get all debuffs on a fake boss
---@param unitId string
---@return table debuffs
function FakeEncounter.GetBossDebuffs(unitId)
    local boss = FakeEncounter.GetFakeBoss(unitId)
    if boss then
        return boss.debuffs
    end
    return {}
end
