---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = QRA.Triggers.Factory or {}

local SpellTriggerMixin = {}

function SpellTriggerMixin:GetIndexKey()
    return self.spellId
end

function SpellTriggerMixin:Validate()
    if not self.spellId or self.spellId <= 0 then
        return false, "Spell ID must be a positive number."
    end

    local spellInfo = C_Spell.GetSpellInfo(self.spellId)
    if not spellInfo then
        return false, "Invalid Spell ID: " .. tostring(self.spellId)
    end

    return true
end

function SpellTriggerMixin:GenerateName()
    local typeInfo = QRA.Triggers.Types[self.type]
    local abbrev = typeInfo and typeInfo.abbreviation or "SPL"
    return string.format("%s %s", abbrev, self.spellName or "Unknown")
end

function SpellTriggerMixin:GetUIFields()
    return {
        { name = "name", type = "text", label = "Name", required = false },
        { name = "spell", type = "spell", label = "Spell ID", required = true },
        { name = "counter", type = "counter", label = "Counter", required = false },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end

local UnitSpellcastTriggerMixin = {}

function UnitSpellcastTriggerMixin:GetIndexKey()
    return QRA.Triggers.Factory.SpellTrigger.GetIndexKey(self)
end

function UnitSpellcastTriggerMixin:Validate()
    return QRA.Triggers.Factory.SpellTrigger.Validate(self)
end

function UnitSpellcastTriggerMixin:GenerateName()
    return QRA.Triggers.Factory.SpellTrigger.GenerateName(self)
end

function UnitSpellcastTriggerMixin:GetUIFields()
    return QRA.Triggers.Factory.SpellTrigger.GetUIFields(self)
end

QRA.Triggers.Factory.SpellTrigger = SpellTriggerMixin
QRA.Triggers.Factory.UnitSpellcastTrigger = UnitSpellcastTriggerMixin
