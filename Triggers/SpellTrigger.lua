---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = QRA.Triggers.Factory or {}

---@class SpellTrigger
QRA.Triggers.Factory.SpellTrigger = {}
---@class UnitSpellcastTrigger
QRA.Triggers.Factory.UnitSpellcastTrigger = {}

---@class SpellTrigger : Trigger
---@field spellId number 
---@field spellName string
---@field counter string
---@field activateIn? string seconds to delay trigger activation with optional interval and repeat count
local SpellTrigger = QRA.Triggers.Factory.SpellTrigger
setmetatable(SpellTrigger, QRA.Triggers.Factory.BaseTrigger)
SpellTrigger.__index = SpellTrigger


function SpellTrigger:GetIndexKey()
    return self.spellId
end

function SpellTrigger:Validate()
    QRA.Debug("Validating SpellTrigger:", self)

    if not self.spellId or self.spellId <= 0 then
        return false, "Spell ID must be a positive number."
    end

    local spellInfo = C_Spell.GetSpellInfo(self.spellId)
    if not spellInfo then
        return false, "Invalid Spell ID: " .. tostring(self.spellId)
    end

    return true
end

function SpellTrigger:GenerateName()
    local typeInfo = QRA.Triggers.Types[self.type]
    local abbrev = typeInfo and typeInfo.abbreviation or "SPL"
    return string.format("%s %s", abbrev, self.spellName or "Unknown")
end

function SpellTrigger:GetUIFields()
    return {
        { name = "name", type = "text", label = "Name", required = false },
        { name = "spell", type = "spell", label = "Spell ID", required = true },
        { name = "counter", type = "counter", label = "Counter", required = false },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end

---@class UnitSpellcastTrigger : SpellTrigger
local UnitSpellcastTrigger = QRA.Triggers.Factory.UnitSpellcastTrigger
setmetatable(UnitSpellcastTrigger, QRA.Triggers.Factory.BaseTrigger)
UnitSpellcastTrigger.__index = UnitSpellcastTrigger

function UnitSpellcastTrigger:GetIndexKey()
    return QRA.Triggers.Factory.SpellTrigger.GetIndexKey(self)
end

function UnitSpellcastTrigger:Validate()
    return QRA.Triggers.Factory.SpellTrigger.Validate(self)
end

function UnitSpellcastTrigger:GenerateName()
    return QRA.Triggers.Factory.SpellTrigger.GenerateName(self)
end

function UnitSpellcastTrigger:GetUIFields()
    return QRA.Triggers.Factory.SpellTrigger.GetUIFields(self)
end
