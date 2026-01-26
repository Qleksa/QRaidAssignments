---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = QRA.Triggers.Factory or {}

---@class UnitHPTrigger
QRA.Triggers.Factory.UnitHPTrigger = {}
---@class UnitDiedTrigger
QRA.Triggers.Factory.UnitDiedTrigger = {}


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

---@class UnitHPTrigger : Trigger
---@field hpThresholds string comma separated list of hp thresholds
---@field targetGuid string
---@field activateIn? string seconds to delay trigger activation with optional interval and repeat count
local UnitHPTrigger = QRA.Triggers.Factory.UnitHPTrigger
setmetatable(UnitHPTrigger, QRA.Triggers.Factory.BaseTrigger)
UnitHPTrigger.__index = UnitHPTrigger

function UnitHPTrigger:GetIndexKey()
    local npcId = tonumber(self.targetGuid)
    return npcId or self.targetGuid
end

function UnitHPTrigger:Validate()
    QRA.Debug("Validating UnitHPTrigger:", self)

    local valid, err = ValidateTargetGuid(self.targetGuid)
    if not valid then
        return false, err
    end

    return ValidateHPThresholds(self.hpThresholds)
end

function UnitHPTrigger:GenerateName()
    local hpDisplay = self.hpThresholds or ""
    hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
    return string.format("%s @ %s", self.targetGuid or "unknown", hpDisplay)
end

function UnitHPTrigger:GetUIFields()
    return {
        { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true },
        { name = "hpThresholds", type = "hpThresholds", label = "HP Thresholds (%)", required = true },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end

---@class UnitDiedTrigger : UnitHPTrigger
---@field counter string
local UnitDiedTrigger = QRA.Triggers.Factory.UnitDiedTrigger
setmetatable(UnitDiedTrigger, QRA.Triggers.Factory.BaseTrigger)
UnitDiedTrigger.__index = UnitDiedTrigger

function UnitDiedTrigger:GetIndexKey()
    local npcId = tonumber(self.targetGuid)
    return npcId or self.targetGuid
end

function UnitDiedTrigger:Validate()
    QRA.Debug("Validating UnitHPTrigger:", self)

    return ValidateTargetGuid(self.targetGuid)
end

function UnitDiedTrigger:GenerateName()
    local hpDisplay = self.hpThresholds or ""
    hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
    return string.format("%s @ %s", self.targetGuid or "unknown", hpDisplay)
end

function UnitDiedTrigger:GetUIFields()
    return {
        { name = "name", type = "text", label = "Name", required = false },
        { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true },
        { name = "counter", type = "counter", label = "Counter", required = false },
        { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false },
    }
end
