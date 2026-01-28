---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = QRA.Triggers.Factory or {}

local function ValidateTargetGuid(targetGuid)
    if not targetGuid or targetGuid == "" then
        return false, "Target GUID must be specified."
    end

    local target = targetGuid
    if target ~= "boss" and not target:match("^boss[1-8]$") then
        local npcId = tonumber(target)
        if not npcId or npcId <= 0 then
            return false, "Target GUID must be 'boss', 'boss[1-8]', or a valid NPC ID."
        end
    end

    return true
end

local function ValidateHPThresholds(hpThresholds)
    if not hpThresholds or hpThresholds == "" then
        return false, "HP thresholds must be specified."
    end

    local hasValid = false
    for threshold in string.gmatch(hpThresholds, "[^,]+") do
        local num = tonumber(strtrim(threshold))
        if not num or num < 1 or num > 100 then
            return false, "Invalid HP threshold: " .. tostring(threshold)
        end
        hasValid = true
    end

    if not hasValid then
        return false, "At least one valid HP threshold must be specified."
    end

    return true
end

local UnitHPTriggerMixin = {}

function UnitHPTriggerMixin:GetIndexKey()
    local npcId = tonumber(self.targetGuid)
    return npcId or self.targetGuid
end

function UnitHPTriggerMixin:Validate()
    local valid, err = ValidateTargetGuid(self.targetGuid)
    if not valid then
        return false, err
    end

    return ValidateHPThresholds(self.hpThresholds)
end

function UnitHPTriggerMixin:GenerateName()
    local hpDisplay = self.hpThresholds or ""
    hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
    return string.format("%s @ %s", self.targetGuid or "unknown", hpDisplay)
end

function UnitHPTriggerMixin:GetUIFields()
    return {
        { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true },
        { name = "hpThresholds", type = "hpThresholds", label = "HP Thresholds (%)", required = true },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end

local UnitDiedTriggerMixin = {}

function UnitDiedTriggerMixin:GetIndexKey()
    local npcId = tonumber(self.targetGuid)
    return npcId or self.targetGuid
end

function UnitDiedTriggerMixin:Validate()
    return ValidateTargetGuid(self.targetGuid)
end

function UnitDiedTriggerMixin:GenerateName()
    local hpDisplay = self.hpThresholds or ""
    hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
    return string.format("%s @ %s", self.targetGuid or "unknown", hpDisplay)
end

function UnitDiedTriggerMixin:GetUIFields()
    return {
        { name = "name", type = "text", label = "Name", required = false },
        { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true },
        { name = "counter", type = "counter", label = "Counter", required = false },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end

QRA.Triggers.Factory.UnitHPTrigger = UnitHPTriggerMixin
QRA.Triggers.Factory.UnitDiedTrigger = UnitDiedTriggerMixin
