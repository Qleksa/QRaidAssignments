--[[
    QRaidAssignments - Dev Mode: Presets Data
    Common test scenarios and configurations (placeholder for future expansion)
]]

---@class QRA
local QRA = QRA
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.Presets = {}

local Presets = QRA.DevMode.Presets

--------------------------------------------------
-- Preset Structure
--------------------------------------------------
--[[
    Preset = {
        id = "preset_id",
        name = "Preset Name",
        description = "What this preset does",
        events = {
            {
                delay = 0,  -- Seconds from start
                eventType = "SPELL_CAST_SUCCESS",
                data = { spellId = 12345, ... },
            },
            ...
        },
    }
]]

--------------------------------------------------
-- Built-in Presets
--------------------------------------------------
Presets.builtIn = {
    {
        id = "quick_test",
        name = "Quick Test Sequence",
        description = "A simple sequence of events for testing",
        events = {
            { delay = 0, eventType = "SPELL_CAST_START", data = { spellId = 0 } },
            { delay = 2, eventType = "SPELL_CAST_SUCCESS", data = { spellId = 0 } },
            { delay = 5, eventType = "SPELL_AURA_APPLIED", data = { spellId = 0 } },
            { delay = 10, eventType = "SPELL_AURA_REMOVED", data = { spellId = 0 } },
        },
    },
}

--------------------------------------------------
-- Preset Management
--------------------------------------------------

--- Get all presets (built-in + custom)
---@return table
function Presets.GetAll()
    local all = {}

    -- Add built-in presets
    for _, preset in ipairs(Presets.builtIn) do
        table.insert(all, preset)
    end

    -- Add custom presets from DB
    if QRA.DB.devMode and QRA.DB.devMode.customPresets then
        for _, preset in ipairs(QRA.DB.devMode.customPresets) do
            table.insert(all, preset)
        end
    end

    return all
end

--- Get preset by ID
---@param presetId string
---@return table|nil
function Presets.Get(presetId)
    for _, preset in ipairs(Presets.GetAll()) do
        if preset.id == presetId then
            return preset
        end
    end
    return nil
end

--- Run a preset
---@param presetId string
---@return boolean success
function Presets.Run(presetId)
    local preset = Presets.Get(presetId)
    if not preset then
        QRA.Debug("Presets: Preset not found:", presetId)
        return false
    end

    if not QRA.DevMode.FakeEncounter.IsActive() then
        QRA.Print(QRA.L["DevMode: Start an encounter first"])
        return false
    end

    -- Schedule events based on their delays
    for _, eventConfig in ipairs(preset.events) do
        C_Timer.After(eventConfig.delay, function()
            if QRA.DevMode.FakeEncounter.IsActive() then
                local EventFirer = QRA.DevMode.EventFirer
                local data = eventConfig.data

                if eventConfig.eventType == "SPELL_CAST_SUCCESS" then
                    EventFirer.FireSpellCastSuccess(data.spellId, data.sourceUnitId, data.targetName)
                elseif eventConfig.eventType == "SPELL_CAST_START" then
                    EventFirer.FireSpellCastStart(data.spellId, data.sourceUnitId)
                elseif eventConfig.eventType == "SPELL_AURA_APPLIED" then
                    EventFirer.FireAuraApplied(data.spellId, data.targetName, data.sourceUnitId, data.duration)
                elseif eventConfig.eventType == "SPELL_AURA_REMOVED" then
                    EventFirer.FireAuraRemoved(data.spellId, data.targetName, data.sourceUnitId)
                elseif eventConfig.eventType == "UNIT_DIED" then
                    EventFirer.FireNPCDeath(data.npcId, data.unitId)
                end
            end
        end)
    end

    QRA.Debug("Presets: Running preset:", preset.name)
    return true
end

--- Save current event history as a preset
---@param name string
---@param description string|nil
---@return table|nil preset
function Presets.SaveFromHistory(name, description)
    local events = QRA.DevMode.EventHistory.GetAll()
    if #events == 0 then
        QRA.Print(QRA.L["DevMode: No events to save"])
        return nil
    end

    local baseTime = events[1].timestamp
    local presetEvents = {}

    for _, event in ipairs(events) do
        table.insert(presetEvents, {
            delay = event.timestamp - baseTime,
            eventType = event.eventType,
            data = QRA.DeepCopy(event.data),
        })
    end

    local preset = {
        id = "custom_" .. time() .. "_" .. math.random(1000, 9999),
        name = name,
        description = description or "",
        events = presetEvents,
        isCustom = true,
    }

    -- Save to DB
    if not QRA.DB.devMode.customPresets then
        QRA.DB.devMode.customPresets = {}
    end
    table.insert(QRA.DB.devMode.customPresets, preset)

    QRA.Debug("Presets: Saved preset:", name, "with", #presetEvents, "events")
    return preset
end

--- Delete a custom preset
---@param presetId string
---@return boolean success
function Presets.Delete(presetId)
    if not QRA.DB.devMode.customPresets then return false end

    for i, preset in ipairs(QRA.DB.devMode.customPresets) do
        if preset.id == presetId then
            table.remove(QRA.DB.devMode.customPresets, i)
            QRA.Debug("Presets: Deleted preset:", presetId)
            return true
        end
    end

    return false
end
