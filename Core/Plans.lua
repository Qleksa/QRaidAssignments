---@class QRA
local QRA = select(2, ...)

QRA.Plans = QRA.Plans or {}

local PERSONAL_PLAN_NAME = "Personal"
local PERSONAL_PLAN_ID = "plan_personal"

local function GeneratePlanID()
    return string.format("plan_%s_%s", time(), math.random(1000, 9999))
end

local function GetNow()
    return time()
end

local function EnsureVersionShape(version, index)
    if not version then
        return {
            version = index,
            triggers = {},
            createdAt = GetNow(),
        }
    end

    version.version = version.version or index
    version.triggers = version.triggers or {}
    version.createdAt = version.createdAt or GetNow()
    return version
end

local function NormalizePlan(plan)
    if not plan then return nil end

    plan.id = plan.id or GeneratePlanID()
    plan.name = plan.name or "Unnamed"
    plan.instanceName = plan.instanceName or QRA.L["All Instances"]
    plan.isPersonal = plan.isPersonal == true
    plan.versions = plan.versions or {}
    plan.createdAt = plan.createdAt or GetNow()
    plan.updatedAt = plan.updatedAt or GetNow()

    if #plan.versions == 0 then
        table.insert(plan.versions, {
            version = 1,
            triggers = {},
            createdAt = plan.createdAt,
        })
    end

    for i, version in ipairs(plan.versions) do
        plan.versions[i] = EnsureVersionShape(version, i)
        plan.versions[i].version = i
    end

    if not plan.activeVersion or plan.activeVersion < 1 or plan.activeVersion > #plan.versions then
        plan.activeVersion = #plan.versions
    end

    return plan
end

local function GetPlanById(planId)
    for _, plan in ipairs(QRA.DB.plans or {}) do
        if plan.id == planId then
            return plan
        end
    end
    return nil
end

local function GetPersonalPlanInternal()
    for _, plan in ipairs(QRA.DB.plans or {}) do
        if plan.isPersonal or plan.name == PERSONAL_PLAN_NAME then
            plan.isPersonal = true
            plan.name = PERSONAL_PLAN_NAME
            plan.id = PERSONAL_PLAN_ID
            NormalizePlan(plan)
            return plan
        end
    end
    return nil
end

local function EnsurePersonalPlan()
    local personal = GetPersonalPlanInternal()
    if personal then
        return personal
    end

    personal = NormalizePlan({
        id = PERSONAL_PLAN_ID,
        name = PERSONAL_PLAN_NAME,
        instanceName = QRA.L["All Instances"],
        isPersonal = true,
        versions = {
            {
                version = 1,
                triggers = {},
                createdAt = GetNow(),
            },
        },
        activeVersion = 1,
        createdAt = GetNow(),
        updatedAt = GetNow(),
    })

    table.insert(QRA.DB.plans, personal)
    QRA.Debug("Plans: Created Personal plan")
    return personal
end

local function GetFirstNonPersonalPlan()
    for _, plan in ipairs(QRA.DB.plans or {}) do
        if not plan.isPersonal then
            return plan
        end
    end
    return nil
end

local function EnsureSharedPlanExists()
    local existing = GetFirstNonPersonalPlan()
    if existing then
        return existing
    end

    local now = GetNow()
    local plan = NormalizePlan({
        id = GeneratePlanID(),
        name = QRA.L["Main Plan"],
        instanceName = QRA.L["All Instances"],
        isPersonal = false,
        versions = {
            {
                version = 1,
                triggers = {},
                createdAt = now,
                source = "bootstrap",
            },
        },
        activeVersion = 1,
        createdAt = now,
        updatedAt = now,
    })

    table.insert(QRA.DB.plans, plan)
    QRA.DB.activePlanId = plan.id
    QRA.DB.selectedPlanId = plan.id
    QRA.DB.selectedPlanVersion = 1
    return plan
end

local function EnsureSelectedPlanPointers()
    local selectedPlanId = QRA.DB.selectedPlanId
    local selectedVersion = QRA.DB.selectedPlanVersion

    local selectedPlan = selectedPlanId and GetPlanById(selectedPlanId) or nil
    if not selectedPlan then
        selectedPlan = GetFirstNonPersonalPlan() or EnsurePersonalPlan()
        QRA.DB.selectedPlanId = selectedPlan.id
    end

    selectedVersion = tonumber(selectedVersion)
    if not selectedVersion or selectedVersion < 1 or selectedVersion > #selectedPlan.versions then
        selectedVersion = selectedPlan.activeVersion or #selectedPlan.versions
        QRA.DB.selectedPlanVersion = selectedVersion
    end

    if not QRA.DB.activePlanId then
        local active = GetFirstNonPersonalPlan()
        QRA.DB.activePlanId = active and active.id or nil
    end

    if QRA.DB.activePlanId then
        local activePlan = GetPlanById(QRA.DB.activePlanId)
        if not activePlan or activePlan.isPersonal then
            QRA.DB.activePlanId = nil
        end
    end
end

local function NormalizeAllPlans()
    QRA.DB.plans = QRA.DB.plans or {}

    for index, plan in ipairs(QRA.DB.plans) do
        QRA.DB.plans[index] = NormalizePlan(plan)
    end

    EnsurePersonalPlan()
    EnsureSelectedPlanPointers()
end

local function SetSelectedPlan(planId, version)
    local plan = GetPlanById(planId)
    if not plan then
        return false
    end

    local selectedVersion = tonumber(version) or plan.activeVersion or #plan.versions
    if selectedVersion < 1 then selectedVersion = 1 end
    if selectedVersion > #plan.versions then selectedVersion = #plan.versions end

    QRA.DB.selectedPlanId = plan.id
    QRA.DB.selectedPlanVersion = selectedVersion
    return true
end

local function FormatDefaultPlanName(instanceName)
    local suffix = instanceName or "Raid"
    if suffix == QRA.L["All Instances"] then
        suffix = "Raid"
    else
        suffix = suffix:match("^[^%s]+") or suffix
    end

    local now = date("*t")
    local ts = string.format(
        "%04d-%02d-%02d:%02d:%02d:%02d",
        now.year,
        now.month,
        now.day,
        now.hour,
        now.min,
        now.sec
    )
    return string.format("%s-%s", ts, suffix)
end

local function GetEffectiveInstanceName(plan)
    if not plan then
        return QRA.L["All Instances"]
    end

    if plan.isPersonal or plan.instanceName == nil or plan.instanceName == "" then
        return QRA.L["All Instances"]
    end

    return plan.instanceName
end

function QRA.Plans.GetDefaultPlanName(instanceName)
    return FormatDefaultPlanName(instanceName)
end

---@param plan Plan|nil
---@return string
function QRA.Plans.GetEffectiveInstanceName(plan)
    return GetEffectiveInstanceName(plan)
end

---@param planId string
---@param version number|nil
---@return Trigger[]
function QRA.Plans.GetTriggersForVersion(planId, version)
    local plan = GetPlanById(planId)
    if not plan then return {} end

    local targetVersion = tonumber(version) or plan.activeVersion
    local versionData = plan.versions[targetVersion]
    if not versionData then
        return {}
    end

    return versionData.triggers or {}
end

---@param planId string
---@param version number|nil
---@return Trigger[]
function QRA.Plans.GetEditableTriggers(planId, version)
    return QRA.Plans.GetTriggersForVersion(planId, version)
end

---@param planId string
---@param version number|nil
---@return boolean
function QRA.Plans.SetSelected(planId, version)
    return SetSelectedPlan(planId, version)
end

---@return Plan|nil
function QRA.Plans.GetSelectedPlan()
    local plan = GetPlanById(QRA.DB.selectedPlanId)
    if not plan then
        EnsureSelectedPlanPointers()
        plan = GetPlanById(QRA.DB.selectedPlanId)
    end
    return plan
end

---@return number
function QRA.Plans.GetSelectedVersion()
    local plan = QRA.Plans.GetSelectedPlan()
    if not plan then return 1 end

    local version = tonumber(QRA.DB.selectedPlanVersion) or plan.activeVersion
    if version < 1 then version = 1 end
    if version > #plan.versions then version = #plan.versions end
    return version
end

---@return string|nil
function QRA.Plans.GetSelectedPlanId()
    return QRA.DB.selectedPlanId
end

---@return Plan[]
function QRA.Plans.GetAll()
    return QRA.DB.plans or {}
end

---@return Plan|nil
function QRA.Plans.Get(planId)
    return GetPlanById(planId)
end

---@return Plan
function QRA.Plans.GetPersonalPlan()
    return EnsurePersonalPlan()
end

---@return Plan|nil
function QRA.Plans.GetActivePlan()
    local plan = QRA.DB.activePlanId and GetPlanById(QRA.DB.activePlanId) or nil
    if plan and not plan.isPersonal then
        return plan
    end
    return nil
end

---@return string|nil
function QRA.Plans.GetActivePlanId()
    local active = QRA.Plans.GetActivePlan()
    return active and active.id or nil
end

---@param planId string
---@param version number|nil
---@return boolean
function QRA.Plans.SetActiveVersion(planId, version)
    local plan = GetPlanById(planId)
    if not plan then return false end

    local targetVersion = tonumber(version) or plan.activeVersion
    if targetVersion < 1 or targetVersion > #plan.versions then
        return false
    end

    plan.activeVersion = targetVersion
    plan.updatedAt = GetNow()

    if not plan.isPersonal then
        QRA.DB.activePlanId = plan.id
    end

    QRA.Debug("Plans: Active version set", plan.name, "v" .. targetVersion)
    return true
end

---@param name string|nil
---@param instanceName string|nil
---@return Plan
function QRA.Plans.Create(name, instanceName)
    local cleanInstance = instanceName or QRA.L["All Instances"]
    local cleanName = name and strtrim(name) or ""
    if cleanName == "" then
        cleanName = FormatDefaultPlanName(cleanInstance)
    end

    local now = GetNow()
    local plan = NormalizePlan({
        id = GeneratePlanID(),
        name = cleanName,
        instanceName = cleanInstance,
        isPersonal = false,
        versions = {
            {
                version = 1,
                triggers = {},
                createdAt = now,
                source = "manual",
            },
        },
        activeVersion = 1,
        createdAt = now,
        updatedAt = now,
    })

    table.insert(QRA.DB.plans, plan)

    QRA.DB.selectedPlanId = plan.id
    QRA.DB.selectedPlanVersion = 1
    if not QRA.DB.activePlanId then
        QRA.DB.activePlanId = plan.id
    end

    QRA.Debug("Plans: Created", plan.name)
    return plan
end

---@param planId string
---@param instanceName string
---@return boolean
function QRA.Plans.SetInstance(planId, instanceName)
    local plan = GetPlanById(planId)
    if not plan or plan.isPersonal then return false end

    plan.instanceName = instanceName
    plan.updatedAt = GetNow()
    return true
end

---@param planId string
---@param newName string
---@return boolean
function QRA.Plans.Rename(planId, newName)
    local plan = GetPlanById(planId)
    if not plan or plan.isPersonal then return false end

    local trimmed = newName and strtrim(newName) or ""
    if trimmed == "" then
        return false
    end

    plan.name = trimmed
    plan.updatedAt = GetNow()
    return true
end

---@param planId string
---@param version number|nil
---@return boolean
function QRA.Plans.DeleteVersion(planId, version)
    local plan = GetPlanById(planId)
    if not plan then return false end

    if #plan.versions <= 1 then
        return false
    end

    local targetVersion = tonumber(version)
    if not targetVersion or targetVersion < 1 or targetVersion > #plan.versions then
        return false
    end

    table.remove(plan.versions, targetVersion)

    for i, versionData in ipairs(plan.versions) do
        versionData.version = i
    end

    if plan.activeVersion >= targetVersion then
        plan.activeVersion = math.max(1, plan.activeVersion - 1)
    end

    if QRA.DB.selectedPlanId == plan.id then
        local selectedVersion = tonumber(QRA.DB.selectedPlanVersion) or plan.activeVersion
        if selectedVersion >= targetVersion then
            selectedVersion = math.max(1, selectedVersion - 1)
        end
        QRA.DB.selectedPlanVersion = selectedVersion
    end

    plan.updatedAt = GetNow()
    return true
end

---@param planId string
---@return boolean deleted
---@return string? reason
function QRA.Plans.DeletePlan(planId)
    local plans = QRA.DB.plans or {}

    local targetIndex = nil
    local targetPlan = nil
    for i, plan in ipairs(plans) do
        if plan.id == planId then
            targetIndex = i
            targetPlan = plan
            break
        end
    end

    if not targetIndex or not targetPlan then
        return false, "not_found"
    end

    if targetPlan.isPersonal then
        return false, "personal_protected"
    end

    table.remove(plans, targetIndex)

    if QRA.DB.activePlanId == targetPlan.id then
        local replacement = GetFirstNonPersonalPlan()
        QRA.DB.activePlanId = replacement and replacement.id or nil
    end

    if QRA.DB.selectedPlanId == targetPlan.id then
        local replacement = QRA.Plans.GetActivePlan() or GetFirstNonPersonalPlan() or EnsurePersonalPlan()
        QRA.DB.selectedPlanId = replacement and replacement.id or nil
        QRA.DB.selectedPlanVersion = replacement and replacement.activeVersion or 1
    end

    EnsureSelectedPlanPointers()
    return true, nil
end

---@param planId string
---@param version number
---@return boolean deleted
---@return string? reason
function QRA.Plans.DeletePlanOrVersion(planId, version)
    local plan = GetPlanById(planId)
    if not plan then
        return false, "not_found"
    end

    local targetVersion = tonumber(version)
    if not targetVersion or targetVersion < 1 or targetVersion > #plan.versions then
        return false, "invalid_version"
    end

    if #plan.versions > 1 then
        if QRA.Plans.DeleteVersion(planId, targetVersion) then
            if plan.isPersonal then
                QRA.DB.selectedPlanId = plan.id
                QRA.DB.selectedPlanVersion = plan.activeVersion
            elseif QRA.DB.activePlanId == plan.id then
                QRA.DB.selectedPlanId = plan.id
                QRA.DB.selectedPlanVersion = plan.activeVersion
            end
            EnsureSelectedPlanPointers()
            return true, nil
        end
        return false, "delete_version_failed"
    end

    return QRA.Plans.DeletePlan(planId)
end

---@param plan Plan
---@param triggers Trigger[]
---@param source string|nil
---@return number
local function AddPlanVersion(plan, triggers, source)
    local now = GetNow()
    local newVersionNumber = #plan.versions + 1

    table.insert(plan.versions, {
        version = newVersionNumber,
        triggers = QRA.DeepCopy(triggers or {}),
        createdAt = now,
        source = source,
    })

    plan.activeVersion = newVersionNumber
    plan.updatedAt = now

    if not plan.isPersonal then
        QRA.DB.activePlanId = plan.id
    end

    QRA.DB.selectedPlanId = plan.id
    QRA.DB.selectedPlanVersion = newVersionNumber

    return newVersionNumber
end

---@param plan Plan
---@param triggers Trigger[]
---@param source string|nil
---@return number
local function ReplacePlanActiveVersion(plan, triggers, source)
    local now = GetNow()

    if #plan.versions == 0 then
        table.insert(plan.versions, {
            version = 1,
            triggers = {},
            createdAt = now,
            source = source,
        })
        plan.activeVersion = 1
    end

    local targetVersion = tonumber(plan.activeVersion) or #plan.versions
    if targetVersion < 1 or targetVersion > #plan.versions then
        targetVersion = #plan.versions
    end

    local versionData = EnsureVersionShape(plan.versions[targetVersion], targetVersion)
    versionData.triggers = QRA.DeepCopy(triggers or {})
    versionData.createdAt = now
    versionData.source = source

    plan.versions[targetVersion] = versionData
    plan.activeVersion = targetVersion
    plan.updatedAt = now

    if not plan.isPersonal then
        QRA.DB.activePlanId = plan.id
    end

    QRA.DB.selectedPlanId = plan.id
    QRA.DB.selectedPlanVersion = targetVersion

    return targetVersion
end

---@param planId string
---@param source string|nil
---@return number|nil
function QRA.Plans.AddVersionCopyFromSelected(planId, source)
    return QRA.Plans.AddVersionFromActive(planId, source)
end

---@param planId string
---@param source string|nil
---@return number|nil
function QRA.Plans.AddVersionFromActive(planId, source)
    local plan = GetPlanById(planId)
    if not plan then return nil end

    local existing = plan.versions[plan.activeVersion]
    if not existing then return nil end

    return AddPlanVersion(plan, existing.triggers or {}, source)
end

---@param planId string
---@param source string|nil
---@return number|nil
function QRA.Plans.AddEmptyVersion(planId, source)
    local plan = GetPlanById(planId)
    if not plan then return nil end

    return AddPlanVersion(plan, {}, source)
end

---@param planName string
---@return Plan|nil
function QRA.Plans.GetByName(planName)
    if not planName then return nil end

    for _, plan in ipairs(QRA.DB.plans or {}) do
        if not plan.isPersonal and plan.name == planName then
            return plan
        end
    end

    return nil
end

---@param planName string
---@param instanceName string
---@param triggers Trigger[]
---@param source string|nil
---@return Plan plan
---@return number version
function QRA.Plans.ImportReplaceActiveVersion(planName, instanceName, triggers, source)
    local plan = QRA.Plans.GetByName(planName)
    local now = GetNow()
    local importSource = source or "import"

    if not plan then
        plan = NormalizePlan({
            id = GeneratePlanID(),
            name = planName,
            instanceName = instanceName or QRA.L["All Instances"],
            isPersonal = false,
            versions = {
                {
                    version = 1,
                    triggers = {},
                    createdAt = now,
                    source = importSource,
                },
            },
            activeVersion = 1,
            createdAt = now,
            updatedAt = now,
        })
        table.insert(QRA.DB.plans, plan)
    else
        if instanceName and instanceName ~= "" then
            plan.instanceName = instanceName
        end
    end

    local replacedVersion = ReplacePlanActiveVersion(plan, triggers, importSource)
    QRA.Debug("Plans: Imported plan into active version", plan.name, "v" .. replacedVersion)
    return plan, replacedVersion
end

---@return Trigger[]
function QRA.Plans.GetEncounterRuntimeTriggers()
    local combined = {}

    local activePlan = QRA.Plans.GetActivePlan()
    if activePlan then
        local activeVersion = activePlan.versions[activePlan.activeVersion]
        for _, trigger in ipairs(activeVersion and activeVersion.triggers or {}) do
            table.insert(combined, trigger)
        end
    end

    local personal = EnsurePersonalPlan()
    local personalVersion = personal.versions[personal.activeVersion]
    for _, trigger in ipairs(personalVersion and personalVersion.triggers or {}) do
        table.insert(combined, trigger)
    end

    return combined
end

---@return Trigger[]
function QRA.Plans.GetSelectedTriggers()
    local plan = QRA.Plans.GetSelectedPlan()
    if not plan then return {} end
    return QRA.Plans.GetTriggersForVersion(plan.id, QRA.Plans.GetSelectedVersion())
end

---@param encounterId number
---@param planId string|nil
---@param version number|nil
---@return Trigger[]
function QRA.Plans.GetTriggersByEncounterId(encounterId, planId, version)
    local selectedPlan = planId and QRA.Plans.Get(planId) or QRA.Plans.GetSelectedPlan()
    if not selectedPlan then return {} end

    local targetVersion = version or selectedPlan.activeVersion
    local source = QRA.Plans.GetTriggersForVersion(selectedPlan.id, targetVersion)
    local result = {}

    for _, trigger in ipairs(source) do
        if trigger.encounterId == encounterId then
            table.insert(result, trigger)
        end
    end

    return result
end

---@param wipePersonal boolean|nil
function QRA.Plans.ClearAll(wipePersonal)
    local personal = EnsurePersonalPlan()
    local keepPersonal = wipePersonal ~= true

    local newPlans = {}
    if keepPersonal then
        personal.versions = {
            {
                version = 1,
                triggers = {},
                createdAt = GetNow(),
                source = "reset",
            },
        }
        personal.activeVersion = 1
        personal.updatedAt = GetNow()
        table.insert(newPlans, personal)

        local now = GetNow()
        local shared = NormalizePlan({
            id = GeneratePlanID(),
            name = QRA.L["Main Plan"],
            instanceName = QRA.L["All Instances"],
            isPersonal = false,
            versions = {
                {
                    version = 1,
                    triggers = {},
                    createdAt = now,
                    source = "reset",
                },
            },
            activeVersion = 1,
            createdAt = now,
            updatedAt = now,
        })
        table.insert(newPlans, shared)
    end

    QRA.DB.plans = newPlans
    QRA.DB.activePlanId = keepPersonal and newPlans[2] and newPlans[2].id or nil

    if keepPersonal then
        local sharedPlan = GetFirstNonPersonalPlan()
        QRA.DB.selectedPlanId = sharedPlan and sharedPlan.id or personal.id
        QRA.DB.selectedPlanVersion = 1
    else
        QRA.DB.selectedPlanId = nil
        QRA.DB.selectedPlanVersion = nil
        EnsurePersonalPlan()
        EnsureSelectedPlanPointers()
    end

    QRA.DB.orphanedAssignments = {}
end

---@param planId string
---@param version number|nil
---@return boolean
function QRA.Plans.IsVersionActive(planId, version)
    local plan = GetPlanById(planId)
    if not plan then return false end

    local targetVersion = tonumber(version)
    if not targetVersion then return false end

    if plan.isPersonal then
        return plan.activeVersion == targetVersion
    end

    return QRA.DB.activePlanId == plan.id and plan.activeVersion == targetVersion
end

---@return table
function QRA.Plans.GetSummaryItems()
    local items = {}

    for _, plan in ipairs(QRA.DB.plans or {}) do
        local children = {}
        for version = 1, #plan.versions do
            local label = "v" .. version
            if QRA.Plans.IsVersionActive(plan.id, version) then
                label = label .. " (Active)"
            end
            table.insert(children, {
                text = label,
                planId = plan.id,
                version = version,
            })
        end

        table.insert(items, {
            text = plan.name,
            planId = plan.id,
            notClickable = #children > 0,
            children = #children > 0 and children or nil,
        })
    end

    return items
end

---@return string|nil
---@return number|nil
function QRA.Plans.GetActiveVersionSelection()
    local activePlan = QRA.Plans.GetActivePlan()
    if not activePlan then
        return nil, nil
    end

    return activePlan.id, activePlan.activeVersion
end

---@param planId string|nil
function QRA.Plans.MarkUpdated(planId)
    local targetId = planId or QRA.DB.selectedPlanId
    if not targetId then return end

    local plan = GetPlanById(targetId)
    if not plan then return end
    plan.updatedAt = GetNow()
end

local function MigrateLegacyTriggers()
    local legacyTriggers = QRA.DB.triggers
    if not legacyTriggers or #legacyTriggers == 0 then
        return
    end

    local defaultPlan = QRA.Plans.Create("Migrated Plan", QRA.L["All Instances"])
    local version = defaultPlan.versions[1]
    version.triggers = QRA.DeepCopy(legacyTriggers)
    version.source = "migration"
    defaultPlan.updatedAt = GetNow()

    QRA.DB.activePlanId = defaultPlan.id
    QRA.DB.selectedPlanId = defaultPlan.id
    QRA.DB.selectedPlanVersion = 1

    QRA.DB.triggers = {}
    QRA.Debug("Plans: Migrated legacy triggers into plan", defaultPlan.name)
end

function QRA.Plans.Initialize()
    NormalizeAllPlans()
    MigrateLegacyTriggers()
    EnsureSharedPlanExists()
    NormalizeAllPlans()
    QRA.Debug("Plans: Module initialized")
end
