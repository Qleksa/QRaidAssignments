---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA_UI
QRA.UI = QRA.UI or {}

---@class QRA_UI_Tree
QRA.UI.Tree = {}

-- Collapse state (reset on each session)
local collapsedState = {
    instances = {},   -- [instanceName] = true/false
    bosses = {},      -- [bossName] = true/false
    triggers = {},    -- [triggerId] = true/false
}

local TREE_ROW_HEIGHT = 28
local ASSIGNMENT_ROW_HEIGHT = 24
local INDENT_WIDTH = 20

--------------------------------------------------
-- Collapse State Management
--------------------------------------------------

local function IsInstanceCollapsed(instanceName)
    return collapsedState.instances[instanceName]
end

local function IsBossCollapsed(bossName)
    return collapsedState.bosses[bossName]
end

local function IsTriggerCollapsed(triggerId)
    return collapsedState.triggers[triggerId]
end

local function SetInstanceCollapsed(instanceName, collapsed)
    collapsedState.instances[instanceName] = collapsed
end

local function SetBossCollapsed(bossName, collapsed)
    collapsedState.bosses[bossName] = collapsed
end

local function SetTriggerCollapsed(triggerId, collapsed)
    collapsedState.triggers[triggerId] = collapsed
end

local function ExpandAll()
    wipe(collapsedState.instances)
    wipe(collapsedState.bosses)
    wipe(collapsedState.triggers)
end

local function CollapseAll()
    -- Collapse all instances
    for instanceName, _ in pairs(QRA.Bosses.GetAllBosses()) do
        collapsedState.instances[instanceName] = true
    end
    -- Collapse all bosses
    for _, instanceData in pairs(QRA.Bosses.GetAllBosses()) do
        for _, bossData in ipairs(instanceData.bosses) do
            collapsedState.bosses[bossData.name] = true
        end
    end
    -- Collapse all triggers
    for _, trigger in ipairs(QRA.Triggers.GetAll()) do
        collapsedState.triggers[trigger.id] = true
    end
end

--------------------------------------------------
-- Tree Row Widgets
--------------------------------------------------

--- Create an instance header row
---@param parent Frame
---@param instanceName string
---@param tier number|nil
---@param onToggle function
---@return Frame row
local function CreateInstanceRow(parent, instanceName, tier, onToggle)
    local row = CreateFrame("Frame", nil, parent)
    AF.SetHeight(row, TREE_ROW_HEIGHT + 2)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")

    local collapsed = IsInstanceCollapsed(instanceName)

    -- Gradient background for instance header
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.18, 0.18, 0.25, 0.95)

    -- Left accent bar
    local accentBar = row:CreateTexture(nil, "ARTWORK")
    accentBar:SetSize(3, TREE_ROW_HEIGHT - 4)
    AF.SetPoint(accentBar, "LEFT", 2, 0)
    accentBar:SetColorTexture(AF.GetColorRGB("softlime"))

    -- Collapse indicator
    local collapseBtn = CreateFrame("Button", nil, row)
    collapseBtn:SetSize(16, 16)
    AF.SetPoint(collapseBtn, "LEFT", 10, 0)
    local collapseIcon = collapseBtn:CreateFontString(nil, "ARTWORK")
    collapseIcon:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    collapseIcon:SetPoint("CENTER")
    collapseIcon:SetText(collapsed and ">" or "v")
    collapseIcon:SetTextColor(AF.GetColorRGB("softlime"))
    collapseBtn:SetScript("OnClick", function()
        SetInstanceCollapsed(instanceName, not IsInstanceCollapsed(instanceName))
        if onToggle then onToggle() end
    end)
    collapseBtn:SetScript("OnEnter", function() collapseIcon:SetTextColor(1, 1, 1) end)
    collapseBtn:SetScript("OnLeave", function() collapseIcon:SetTextColor(AF.GetColorRGB("softlime")) end)

    -- Instance name with tier badge
    local nameFS = AF.CreateFontString(row, instanceName, "softlime")
    nameFS:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    AF.SetPoint(nameFS, "LEFT", collapseBtn, "RIGHT", 5, 0)

    -- Tier badge
    if tier then
        local tierBadge = AF.CreateFontString(row, string.format("T%d", tier), "white")
        tierBadge:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        AF.SetPoint(tierBadge, "LEFT", nameFS, "RIGHT", 8, 0)

        -- Badge background
        local tierBg = row:CreateTexture(nil, "ARTWORK", nil, -1)
        tierBg:SetSize(tierBadge:GetStringWidth() + 8, 14)
        tierBg:SetPoint("CENTER", tierBadge, 0, 0)
        tierBg:SetColorTexture(0.3, 0.3, 0.4, 0.8)
    end

    row.instanceName = instanceName

    return row
end

--- Create a boss header row
---@param parent Frame
---@param bossData table
---@param indentLevel number
---@param onToggle function
---@param onAddTrigger function
---@return Frame row
local function CreateBossRow(parent, bossData, indentLevel, onToggle, onAddTrigger)
    local row = CreateFrame("Frame", nil, parent)
    AF.SetHeight(row, TREE_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")

    local collapsed = IsBossCollapsed(bossData.name)
    local indent = indentLevel * INDENT_WIDTH

    -- Subtle background for boss level
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.13, 0.7)

    -- Collapse indicator
    local collapseBtn = CreateFrame("Button", nil, row)
    collapseBtn:SetSize(14, 14)
    AF.SetPoint(collapseBtn, "LEFT", indent + 8, 0)
    local collapseIcon = collapseBtn:CreateFontString(nil, "ARTWORK")
    collapseIcon:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    collapseIcon:SetPoint("CENTER")
    collapseIcon:SetText(collapsed and ">" or "v")
    collapseIcon:SetTextColor(0.7, 0.7, 0.7)
    collapseBtn:SetScript("OnClick", function()
        SetBossCollapsed(bossData.name, not IsBossCollapsed(bossData.name))
        if onToggle then onToggle() end
    end)
    collapseBtn:SetScript("OnEnter", function() collapseIcon:SetTextColor(1, 1, 1) end)
    collapseBtn:SetScript("OnLeave", function() collapseIcon:SetTextColor(0.7, 0.7, 0.7) end)

    -- Boss name
    local nameFS = AF.CreateFontString(row, bossData.name, "white")
    nameFS:SetFont(STANDARD_TEXT_FONT, 11, "")
    AF.SetPoint(nameFS, "LEFT", collapseBtn, "RIGHT", 5, 0)

    -- Trigger count badge
    local triggers = QRA.Triggers.GetBossTriggers(bossData.name)
    local countBadge = AF.CreateFontString(row, tostring(#triggers), "gray")
    countBadge:SetFont(STANDARD_TEXT_FONT, 9, "")
    AF.SetPoint(countBadge, "LEFT", nameFS, "RIGHT", 8, 0)

    -- Count badge background
    local countBg = row:CreateTexture(nil, "ARTWORK", nil, -1)
    countBg:SetSize(countBadge:GetStringWidth() + 10, 14)
    countBg:SetPoint("CENTER", countBadge, 0, 0)
    countBg:SetColorTexture(0.2, 0.2, 0.25, 0.8)

    -- Add Trigger button
    local addBtn = AF.CreateButton(row, "+", "lime", 20, 20)
    AF.SetPoint(addBtn, "RIGHT", row, -5, 0)
    AF.SetTooltip(addBtn, "ANCHOR_RIGHT", 0, 0, QRA.L["+ Add Trigger"])
    addBtn:SetOnClick(function()
        if onAddTrigger then onAddTrigger(bossData.name) end
    end)

    row.bossData = bossData

    return row
end

--- Create a trigger row with nested assignments
---@param parent Frame
---@param trigger Trigger
---@param indentLevel number
---@param onToggle function
---@param onEdit function
---@param onDelete function
---@param onAddAssignment function
---@return Frame row
local function CreateTriggerRow(parent, trigger, indentLevel, onToggle, onEdit, onDelete, onAddAssignment)
    local row = CreateFrame("Button", "QRA_TRIGGER_ROW_" .. trigger.id, parent)
    AF.SetHeight(row, TREE_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local collapsed = IsTriggerCollapsed(trigger.id)
    local indent = indentLevel * INDENT_WIDTH
    local hasAssignments = trigger.assignments and #trigger.assignments > 0

    -- Hover highlight
    row:SetScript("OnEnter", function(self)
        if not row.hoverBg then
            row.hoverBg = row:CreateTexture(nil, "BACKGROUND")
            row.hoverBg:SetAllPoints()
            row.hoverBg:SetColorTexture(1, 1, 1, 0.05)
        end
        row.hoverBg:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if row.hoverBg then row.hoverBg:Hide() end
    end)

    -- Click handler
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if onEdit then onEdit(trigger) end
        elseif button == "RightButton" then
            QRA.UI.ContextMenus.ShowTriggerContextMenu(row, trigger, onDelete, onAddAssignment)
        end
    end)

    -- Collapse button (only if has assignments)
    local collapseBtn
    if hasAssignments then
        collapseBtn = CreateFrame("Button", nil, row)
        collapseBtn:SetSize(12, 12)
        AF.SetPoint(collapseBtn, "LEFT", indent + 8, 0)
        local collapseIcon = collapseBtn:CreateFontString(nil, "ARTWORK")
        collapseIcon:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        collapseIcon:SetPoint("CENTER")
        collapseIcon:SetText(collapsed and ">" or "v")
        collapseIcon:SetTextColor(0.6, 0.6, 0.6)
        collapseBtn:SetScript("OnClick", function()
            SetTriggerCollapsed(trigger.id, not IsTriggerCollapsed(trigger.id))
            if onToggle then onToggle() end
        end)
        collapseBtn:SetScript("OnEnter", function() collapseIcon:SetTextColor(1, 1, 1) end)
        collapseBtn:SetScript("OnLeave", function() collapseIcon:SetTextColor(0.6, 0.6, 0.6) end)
    end

    -- Enabled checkbox
    local startOffset = hasAssignments and (indent + 22) or (indent + 12)
    local enableCheck = AF.CreateCheckButton(row, nil, function(checked)
        trigger.enabled = checked
        QRA.Triggers.UpdateTrigger(trigger)
    end)
    AF.SetPoint(enableCheck, "LEFT", startOffset, 0)
    enableCheck:SetChecked(trigger.enabled)

    -- Type indicator border
    local typeBorder = row:CreateTexture(nil, "ARTWORK", nil, -1)
    typeBorder:SetSize(12, 12)
    AF.SetPoint(typeBorder, "LEFT", startOffset + 25, 0)
    typeBorder:SetColorTexture(0, 0, 0, 0.8)

    -- Type indicator
    local typeColor = QRA.Widgets.Colors.triggerType[trigger.type] or "gray"
    local typeIndicator = row:CreateTexture(nil, "ARTWORK")
    typeIndicator:SetSize(10, 10)
    typeIndicator:SetPoint("CENTER", typeBorder, 0, 0)
    typeIndicator:SetColorTexture(AF.GetColorRGB(typeColor))

    -- Trigger details
    local details
    if trigger.name and trigger.name ~= "" then
        details = trigger.name
    elseif trigger.type == QRA.Triggers.Types.UNIT_HEALTH.event then
        local hpDisplay = trigger.hpThresholds or ""
        hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
        details = string.format("%s @ %s", trigger.targetGuid or "unknown", hpDisplay)
    elseif trigger.type == QRA.Triggers.Types.TIMER.event then
        local timeDisplay = trigger.time and string.format("%ds", trigger.time) or "0s"
        if trigger.repeatInterval and trigger.repeatInterval > 0 then
            if trigger.repeatCount and trigger.repeatCount > 0 then
                details = string.format("%s / %ds x%d", timeDisplay, trigger.repeatInterval, trigger.repeatCount)
            else
                details = string.format("%s / %ds", timeDisplay, trigger.repeatInterval)
            end
        else
            details = timeDisplay
        end
    else
        details = trigger.spellName or trigger.targetGuid or (trigger.time and string.format("%ds", trigger.time)) or "-"
    end

    local detailsFS = AF.CreateFontString(row, details, "white")
    AF.SetPoint(detailsFS, "LEFT", startOffset + 42, 0)
    -- AF.SetPoint(detailsFS, "RIGHT", row, -80, 0)
    detailsFS:SetJustifyH("LEFT")
    detailsFS:SetWordWrap(false)

    -- Assignment count badge (show how many assignments)
    local assignCount = trigger.assignments and #trigger.assignments or 0
    if assignCount > 0 then
        local assignBadge = AF.CreateFontString(row, tostring(assignCount), "skyblue")
        assignBadge:SetFont(STANDARD_TEXT_FONT, 9, "")
        AF.SetPoint(assignBadge, "RIGHT", detailsFS, 15, 0)

        local assignBg = row:CreateTexture(nil, "ARTWORK", nil, -1)
        assignBg:SetSize(assignBadge:GetStringWidth() + 8, 13)
        assignBg:SetPoint("CENTER", assignBadge, 0, 0)
        assignBg:SetColorTexture(0.15, 0.25, 0.35, 0.8)
    end

    -- Counter formula (not for TIMER or UNIT_HEALTH)
    local occText = ""
    if trigger.type ~= QRA.Triggers.Types.TIMER.event and trigger.type ~= QRA.Triggers.Types.UNIT_HEALTH.event then
        occText = trigger.counterFormula or "*"
    end
    local occFS = AF.CreateFontString(row, occText, "gray")
    occFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(occFS, "RIGHT", row, -55, 0)
    AF.SetWidth(occFS, 35)

    -- Add Assignment button
    local addAssignBtn = AF.CreateButton(row, "+", "skyblue", 20, 20)
    AF.SetPoint(addAssignBtn, "RIGHT", row, -29, 0)
    AF.SetTooltip(addAssignBtn, "ANCHOR_RIGHT", 0, 0, QRA.L["Add Assignment"])
    addAssignBtn:SetOnClick(function()
        if onAddAssignment then onAddAssignment(trigger.id) end
    end)

    -- Delete button (only for non-default triggers)
    if not trigger.default then
        local delBtn = AF.CreateButton(row, "x", "red", 20, 20)
        AF.SetPoint(delBtn, "RIGHT", row, -5, 0)
        AF.SetTooltip(delBtn, "ANCHOR_RIGHT", 0, 0, QRA.L["Delete Trigger"])
        delBtn:SetOnClick(function()
            if onDelete then onDelete(trigger) end
        end)
    end

    row.trigger = trigger

    return row
end

--- Create an assignment row (nested under trigger)
---@param parent Frame
---@param assignment Assignment
---@param triggerId string
---@param indentLevel number
---@param onEdit function
---@param onDelete function
---@return Frame row
local function CreateAssignmentRow(parent, assignment, triggerId, indentLevel, onEdit, onDelete)
    local row = CreateFrame("Button", nil, parent)
    AF.SetHeight(row, ASSIGNMENT_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local indent = indentLevel * INDENT_WIDTH

    -- Light background for assignment level
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.1, 0.12, 0.5)

    -- Hover highlight
    row:SetScript("OnEnter", function(self)
        if not row.hoverBg then
            row.hoverBg = row:CreateTexture(nil, "BACKGROUND")
            row.hoverBg:SetAllPoints()
            row.hoverBg:SetColorTexture(1, 1, 1, 0.08)
        end
        row.hoverBg:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if row.hoverBg then row.hoverBg:Hide() end
    end)

    -- Click handler
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if onEdit then onEdit(assignment, triggerId) end
        elseif button == "RightButton" then
            QRA.UI.ContextMenus.ShowAssignmentContextMenu(row, assignment, triggerId, onDelete)
        end
    end)

    -- Enabled checkbox
    local enableCheck = AF.CreateCheckButton(row, nil, function(checked)
        QRA.Assignments.Update(triggerId, assignment.id, { enabled = checked })
    end)
    AF.SetPoint(enableCheck, "LEFT", indent + 15, 0)
    enableCheck:SetChecked(assignment.enabled)

    -- Assignment indicator (small dash or bullet)
    local bulletFS = AF.CreateFontString(row, "-", "gray")
    AF.SetPoint(bulletFS, "LEFT", indent + 40, 0)

    -- Spell icon (if applicable)
    local iconOffset = indent + 55
    if assignment.spellId then
        local spellIcon = C_Spell.GetSpellTexture(assignment.spellId)
        if spellIcon then
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            AF.SetPoint(icon, "LEFT", iconOffset, 0)
            icon:SetTexture(spellIcon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconOffset = iconOffset + 22
        end
    end

    -- Assignment description
    local descText = (assignment.message and assignment.message ~= "" and assignment.message) or assignment.spellName or QRA.L["Unknown Assignment"]
    local descFS = AF.CreateFontString(row, descText, "white")
    descFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(descFS, "LEFT", iconOffset, 0)
    AF.SetWidth(descFS, 120)
    descFS:SetJustifyH("LEFT")
    descFS:SetWordWrap(false)

    -- Assign target display
    local assignTarget = assignment.assignTarget or "ALL"
    local targetDisplayText = QRA.AssignTarget and QRA.AssignTarget.GetColoredDisplayText(assignTarget, false) or assignTarget
    local targetFS = AF.CreateFontString(row, targetDisplayText, "softlime")
    targetFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(targetFS, "LEFT", descFS, "RIGHT", 5, 0)
    AF.SetWidth(targetFS, 150)
    targetFS:SetJustifyH("LEFT")
    targetFS:SetWordWrap(false)

    -- Countdown display
    local countdownFS = AF.CreateFontString(row, string.format("%ds", assignment.countdownTime or 0), "skyblue")
    countdownFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(countdownFS, "RIGHT", row, -25, 0)
    AF.SetWidth(countdownFS, 25)

    -- Delete button
    local delBtn = AF.CreateButton(row, "x", "red", 20, 20)
    AF.SetPoint(delBtn, "RIGHT", row, -5, 0)
    AF.SetTooltip(delBtn, "ANCHOR_RIGHT", 0, 0, QRA.L["Delete Assignment"])
    delBtn:SetOnClick(function()
        if onDelete then onDelete(assignment, triggerId) end
    end)

    row.assignment = assignment
    row.triggerId = triggerId

    return row
end

--- Create an orphaned assignment row
---@param parent Frame
---@param assignment OrphanedAssignment
---@param onEdit function
---@param onDelete function
---@param onAdopt function
---@return Frame row
local function CreateOrphanedAssignmentRow(parent, assignment, onEdit, onDelete, onAdopt)
    local row = CreateFrame("Button", nil, parent)
    AF.SetHeight(row, ASSIGNMENT_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Warning background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.3, 0.15, 0.1, 0.5)

    -- Hover highlight
    row:SetScript("OnEnter", function(self)
        if not row.hoverBg then
            row.hoverBg = row:CreateTexture(nil, "BACKGROUND")
            row.hoverBg:SetAllPoints()
            row.hoverBg:SetColorTexture(1, 1, 1, 0.08)
        end
        row.hoverBg:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if row.hoverBg then row.hoverBg:Hide() end
    end)

    -- Click handler
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if onEdit then onEdit(assignment) end
        elseif button == "RightButton" then
            QRA.UI.ContextMenus.ShowOrphanedAssignmentContextMenu(row, assignment, onDelete, onAdopt)
        end
    end)

    -- Warning icon
    local warnIcon = row:CreateFontString(nil, "ARTWORK")
    warnIcon:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    warnIcon:SetPoint("LEFT", 10, 0)
    warnIcon:SetText("!")
    warnIcon:SetTextColor(1, 0.6, 0.2)

    -- Enabled checkbox
    local enableCheck = AF.CreateCheckButton(row, nil, function(checked)
        QRA.Assignments.UpdateOrphan(assignment.id, { enabled = checked })
    end)
    AF.SetPoint(enableCheck, "LEFT", 25, 0)
    enableCheck:SetChecked(assignment.enabled)

    -- Spell icon (if applicable)
    local iconOffset = 55
    if assignment.spellId then
        local spellIcon = C_Spell.GetSpellTexture(assignment.spellId)
        if spellIcon then
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            AF.SetPoint(icon, "LEFT", iconOffset, 0)
            icon:SetTexture(spellIcon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconOffset = iconOffset + 22
        end
    end

    -- Assignment description
    local descText = (assignment.message and assignment.message ~= "" and assignment.message) or assignment.spellName or QRA.L["Unknown Assignment"]
    local descFS = AF.CreateFontString(row, descText, "white")
    descFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(descFS, "LEFT", iconOffset, 0)
    AF.SetWidth(descFS, 150)
    descFS:SetJustifyH("LEFT")
    descFS:SetWordWrap(false)

    -- Assign target
    local assignTarget = assignment.assignTarget or "ALL"
    local targetDisplayText = QRA.AssignTarget and QRA.AssignTarget.GetColoredDisplayText(assignTarget, false) or assignTarget
    local targetFS = AF.CreateFontString(row, targetDisplayText, "accent")
    targetFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    AF.SetPoint(targetFS, "LEFT", descFS, "RIGHT", 5, 0)
    AF.SetWidth(targetFS, 70)
    targetFS:SetJustifyH("LEFT")

    -- Adopt button (assign to trigger)
    local adoptBtn = AF.CreateButton(row, QRA.L["Assign to Trigger"], "orange", 90, 18)
    AF.SetPoint(adoptBtn, "RIGHT", row, -25, 0)
    adoptBtn:SetOnClick(function()
        if onAdopt then onAdopt(assignment) end
    end)

    -- Delete button
    local delBtn = AF.CreateButton(row, "x", "red", 20, 20)
    AF.SetPoint(delBtn, "RIGHT", row, -5, 0)
    delBtn:SetOnClick(function()
        if onDelete then onDelete(assignment) end
    end)

    row.assignment = assignment

    return row
end

--------------------------------------------------
-- Main Tree View
--------------------------------------------------

local function CreateTreeWidgets(parent, listParent, bossName)
    local widgets = {}

    local function RefreshTree()
        CreateTreeWidgets(parent, listParent, bossName)
    end

    local function OnEditTrigger(trigger)
        QRA.UI.Dialogs.ShowTriggerEditor(trigger, trigger.bossName)
    end

    local function OnDeleteTrigger(trigger)
        QRA.UI.Dialogs.ShowDeleteTriggerDialog(trigger, function()
            QRA.UI.RefreshTree()
        end)
    end

    local function OnAddAssignment(triggerId)
        QRA.UI.Dialogs.ShowAssignmentEditor(nil, triggerId)
    end

    local function OnEditAssignment(assignment, triggerId)
        QRA.UI.Dialogs.ShowAssignmentEditor(assignment, triggerId)
    end

    local function OnDeleteAssignment(assignment, triggerId)
        QRA.Assignments.Remove(triggerId, assignment.id)
        QRA.UI.RefreshTree()
    end

    local function OnAddTrigger(bossName)
        QRA.UI.Dialogs.ShowTriggerEditor(nil, bossName)
    end

    -- If boss filter is set, only show that boss's triggers
    if bossName then
        local triggers = QRA.Triggers.GetBossTriggers(bossName)

        for _, trigger in ipairs(triggers) do
            -- Trigger row
            local triggerRow = CreateTriggerRow(
                listParent,
                trigger,
                0,  -- No indent when showing single boss
                QRA.UI.RefreshTree,
                OnEditTrigger,
                OnDeleteTrigger,
                OnAddAssignment
            )
            table.insert(widgets, triggerRow)

            -- Nested assignments (if expanded)
            if not IsTriggerCollapsed(trigger.id) and trigger.assignments then
                for _, assignment in ipairs(trigger.assignments) do
                    local assignRow = CreateAssignmentRow(
                        listParent,
                        assignment,
                        trigger.id,
                        1,
                        OnEditAssignment,
                        OnDeleteAssignment
                    )
                    table.insert(widgets, assignRow)
                end
            end
        end
    else
        -- Show all triggers grouped by Instance → Boss
        local instances = QRA.Bosses.GetInstancesSortedByTier()

        for _, instanceInfo in ipairs(instances) do
            local instanceName = instanceInfo.name
            local instanceData = instanceInfo.data

            -- Check if instance has any triggers
            local instanceHasTriggers = false
            for _, bossData in ipairs(instanceData.bosses) do
                local bossTriggers = QRA.Triggers.GetBossTriggers(bossData.name)
                if #bossTriggers > 0 then
                    instanceHasTriggers = true
                    break
                end
            end

            if instanceHasTriggers then
                -- Instance header
                local instanceRow = CreateInstanceRow(listParent, instanceName, instanceData.tier, QRA.UI.RefreshTree)
                table.insert(widgets, instanceRow)

                -- Bosses (if instance expanded)
                if not IsInstanceCollapsed(instanceName) then
                    for _, bossData in ipairs(instanceData.bosses) do
                        local triggers = QRA.Triggers.GetBossTriggers(bossData.name)

                        if #triggers > 0 then
                            -- Boss header
                            local bossRow = CreateBossRow(listParent, bossData, 1, QRA.UI.RefreshTree, OnAddTrigger)
                            table.insert(widgets, bossRow)

                            -- Triggers (if boss expanded)
                            if not IsBossCollapsed(bossData.name) then
                                for _, trigger in ipairs(triggers) do
                                    -- Trigger row
                                    local triggerRow = CreateTriggerRow(
                                        listParent,
                                        trigger,
                                        2,
                                        RefreshTree,
                                        OnEditTrigger,
                                        OnDeleteTrigger,
                                        OnAddAssignment
                                    )
                                    table.insert(widgets, triggerRow)

                                    -- Nested assignments (if trigger expanded)
                                    if not IsTriggerCollapsed(trigger.id) and trigger.assignments then
                                        for _, assignment in ipairs(trigger.assignments) do
                                            local assignRow = CreateAssignmentRow(
                                                listParent,
                                                assignment,
                                                trigger.id,
                                                3,
                                                OnEditAssignment,
                                                OnDeleteAssignment
                                            )
                                            table.insert(widgets, assignRow)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Orphaned Assignments Section
    local orphaned = QRA.Assignments.GetOrphaned()
    if #orphaned > 0 then
        -- Separator
        local separator = CreateFrame("Frame", nil, listParent)
        AF.SetHeight(separator, 8)
        AF.SetPoint(separator, "LEFT")
        AF.SetPoint(separator, "RIGHT")
        table.insert(widgets, separator)

        -- Orphaned header
        local orphanHeader = CreateFrame("Frame", nil, listParent)
        AF.SetHeight(orphanHeader, TREE_ROW_HEIGHT)
        AF.SetPoint(orphanHeader, "LEFT")
        AF.SetPoint(orphanHeader, "RIGHT")

        local orphanBg = orphanHeader:CreateTexture(nil, "BACKGROUND")
        orphanBg:SetAllPoints()
        orphanBg:SetColorTexture(0.3, 0.15, 0.1, 0.8)

        local warnIcon = orphanHeader:CreateFontString(nil, "ARTWORK")
        warnIcon:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        warnIcon:SetPoint("LEFT", 10, 0)
        warnIcon:SetText("!")
        warnIcon:SetTextColor(1, 0.6, 0.2)

        local orphanTitle = AF.CreateFontString(orphanHeader, QRA.L["Orphaned Assignments"] .. " (" .. #orphaned .. ")", "orange")
        orphanTitle:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        AF.SetPoint(orphanTitle, "LEFT", warnIcon, "RIGHT", 5, 0)

        table.insert(widgets, orphanHeader)

        -- Orphaned assignment rows
        for _, assignment in ipairs(orphaned) do
            local orphanRow = CreateOrphanedAssignmentRow(
                listParent,
                assignment,
                function(a) QRA.UI.Dialogs.ShowAssignmentEditor(a, nil) end,
                function(a)
                    QRA.Assignments.DeleteOrphan(a.id)
                    QRA.UI.RefreshTree()
                end,
                function(a)
                    QRA.UI.Dialogs.ShowAdoptOrphanDialog(a, QRA.UI.RefreshTree)
                end
            )
            table.insert(widgets, orphanRow)
        end
    end

    return widgets
end

local function CreateButton(parent, text, width, height, color, tooltipText, onClick)
    local btn = AF.CreateButton(parent, text, color or "static", width, height)
    if tooltipText then
        AF.SetTooltip(btn, "ANCHOR_BOTTOM", 0, 0, tooltipText)
    end
    btn:SetOnClick(onClick)

    return btn
end

--- Create Expand All button
---@param parent Frame
---@return AF_Button button
function QRA.UI.Tree.CreateExpandButton(parent)
    return CreateButton(
        parent,
        "+",
        26,
        26,
        "static",
        QRA.L["Expand All"],
        function()
            ExpandAll()
            QRA.UI.RefreshTree()
        end
    )
end

--- Create Collapse All button
---@param parent Frame
---@return AF_Button button
function QRA.UI.Tree.CreateCollapseButton(parent)
    return CreateButton(
        parent,
        "-",
        26,
        26,
        "static",
        QRA.L["Collapse All"],
        function()
            CollapseAll()
            QRA.UI.RefreshTree()
        end
    )
end

--- Build the tree view
---@param parent Frame
---@param listParent AF_ScrollList
---@param bossName string|nil
-- -@return table widgets
function QRA.UI.Tree.BuildTreeView(parent, listParent, bossName)
    local widgets = CreateTreeWidgets(parent, listParent.slotFrame, bossName)
    listParent:SetWidgets(widgets)
end
