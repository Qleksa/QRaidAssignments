---@diagnostic disable: undefined-field

---@class QRA
local QRA = select(2, ...)

---@class QRA_Triggers
QRA.Triggers = QRA.Triggers or {}

---@type table<string, Trigger>
local DB = {}

do

end

--- Locals

---@type table<string|number, Trigger[]>
local triggerMap = {}

local tinsert = table.insert
local tmerge = QRA.Table.Merge

--- Helpers

--- Get all triggers for a specific boss encounter
--- @param encounterId number
--- @return Trigger[] triggers
local function GetBossTriggers(encounterId)
    local triggers = {}
    for _, trigger in pairs(DB) do
        if trigger.encounterId == encounterId then
            tinsert(triggers, trigger)
        end
    end
    return triggers
end

local function CreateDefaultTriggers()
    local instances = QRA.Bosses.GetAllBosses()
    for _, instance in pairs(instances) do
        local bosses = instance.bosses
        for _, boss in pairs(bosses) do
            local triggers = boss.triggers or {}
            for _, trigger in ipairs(triggers) do
                local triggerId = boss.name .. "_" .. trigger.type .. "_" .. (trigger.spellId or trigger.targetGuid or trigger.time or "generic")
                local existingTrigger = DB[triggerId]
                if not existingTrigger then
                    local t = QRA.Triggers.Factory.Create(tmerge(trigger, {
                        id = triggerId,
                        default = true,
                        encounterId = boss.encounterId,
                        bossName = boss.name,
                    }))
                    if t then
                        QRA.Debug("Creating default trigger: ", t.id)
                        t:Save()
                        DB[t.id] = t
                    end
                end
            end
        end
    end
end


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
    UNIT_SPELLCAST_SUCCEEDED = {
        event = "UNIT_SPELLCAST_SUCCEEDED",
        name = "Unit Spellcast Succeeded",
        abbreviation = "USS",
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

--- Register a trigger
--- @param trigger Trigger
function QRA.Triggers.Register(trigger)
    QRA.Debug("Registering trigger: ", trigger.id)
    local indexKey = trigger:GetIndexKey()
    if indexKey then
        if not triggerMap[indexKey] then
            triggerMap[indexKey] = {}
        end
        tinsert(triggerMap[indexKey], trigger)
    end
end

--- Register encounter triggers
--- @param encounterId number
function QRA.Triggers.RegisterEncounterTriggers(encounterId)
    local triggers = GetBossTriggers(encounterId)
    for _, triggerData in ipairs(triggers) do
        QRA.Debug("Restoring trigger from DB:", triggerData.id)
        local trigger = DB[triggerData.id]
        QRA.Triggers.Register(trigger)
    end
end

local function TestTriggerCreation()
    local t, err = QRA.Triggers.Factory.Create{
        type = QRA.Triggers.Types.TIMER,
        time = 30,
        repeatInterval = 1,
        repeatCount = 3,
        bossName = "Test Boss",
    }
    QRA.Debug("Creating test trigger...")
    if not t then
        QRA.Debug("Error creating test trigger: " .. err)
    else
        QRA.Debug("Test trigger created: ", t)
        t:Save()
        t.bossName = "Updated Boss Name"
        t:Update()
        local t1 = t:Find()
        QRA.Debug("Found trigger:", t1)
        t:Delete()
    end
end

local function TestTriggerRegistration()
    QRA.Debug("Testing trigger registration for encounter 1559...")
    local t = GetBossTriggers(1559)
    QRA.Debug("Found triggers for encounter 1559:", t)
    for _, trigger in ipairs(t) do
        QRA.Triggers.Register(trigger)
    end
end

function QRA.Triggers.Initialize()
    -- TestTriggerCreation()
    for _, trigger in pairs(QRA.DB.triggers) do
        QRA.Debug("Restoring trigger from DB:", trigger.id)
        local clone = QRA.DeepCopy(trigger)
        local restoredTrigger = QRA.Triggers.Factory.Restore(clone)
        DB[restoredTrigger.id] = clone
    end

    CreateDefaultTriggers()
    TestTriggerRegistration()
    QRA.Debug("Triggers V2 module initialized.")
end
