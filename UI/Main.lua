--[[
    QRaidAssignments - Main UI
    Primary user interface for managing triggers and assignments
    Hierarchical tree view: Instance → Boss → Trigger → Assignments
]]

---@class QRA
local QRA = QRA
QRA.UI = QRA.UI or {}

---@type AbstractFramework
local AF = QRA.AF

--------------------------------------------------
-- Constants
--------------------------------------------------
local UI_WIDTH = 750
local UI_HEIGHT = 550
local TREE_ROW_HEIGHT = 28
local ASSIGNMENT_ROW_HEIGHT = 24
local INDENT_WIDTH = 20

--------------------------------------------------
-- State
--------------------------------------------------
---@class AF_HeaderedFrame
local mainFrame = nil
local treeContent = nil
local selectedBoss = nil
local selectedEncounterId = nil

-- Collapse state (reset on each session)
local collapsedState = {
    instances = {},   -- [instanceName] = true/false
    bosses = {},      -- [bossName] = true/false
    triggers = {},    -- [triggerId] = true/false
}

--------------------------------------------------
-- Collapse State Management
--------------------------------------------------

local function IsInstanceCollapsed(instanceName)
    return collapsedState.instances[instanceName] == true
end

local function IsBossCollapsed(bossName)
    return collapsedState.bosses[bossName] == true
end

local function IsTriggerCollapsed(triggerId)
    return collapsedState.triggers[triggerId] == true
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
            QRA.UI.ShowTriggerContextMenu(row, trigger, onDelete, onAddAssignment, onToggle)
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
    enableCheck:SetEnabled(not trigger.default)

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
            QRA.UI.ShowAssignmentContextMenu(row, assignment, triggerId, onDelete)
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
            QRA.UI.ShowOrphanedAssignmentContextMenu(row, assignment, onDelete, onAdopt)
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
-- Context Menus
--------------------------------------------------

--- Show context menu for a trigger
function QRA.UI.ShowTriggerContextMenu(owner, trigger, onDelete, onAddAssignment, onRefresh)
    local menuItems = {
        {
            QRA.L["Add Assignment"],
            function()
                if onAddAssignment then onAddAssignment(trigger.id) end
            end,
        },
        {
            QRA.L["Export"],
            function()
                local exportString = QRA.Comm.ExportTrigger(trigger.id)
                QRA.UI.ShowExportFrame(exportString)
            end,
        },
        {
            QRA.L["Send to Raid"],
            function()
                local exportString = QRA.Comm.ExportTrigger(trigger.id, true)
                QRA.Comm.SendToRaid(exportString)
            end,
        },
    }

    if not trigger.default then
        table.insert(menuItems, {
            QRA.L["Delete Trigger"],
            function()
                if onDelete then onDelete(trigger) end
            end,
        })
    end

    MenuUtil.CreateButtonContextMenu(owner, unpack(menuItems))
end

--- Show context menu for an assignment
function QRA.UI.ShowAssignmentContextMenu(owner, assignment, triggerId, onDelete)
    MenuUtil.CreateButtonContextMenu(owner,
        {
            QRA.L["Delete Assignment"],
            function()
                if onDelete then onDelete(assignment, triggerId) end
            end,
        }
    )
end

--- Show context menu for an orphaned assignment
function QRA.UI.ShowOrphanedAssignmentContextMenu(owner, assignment, onDelete, onAdopt)
    MenuUtil.CreateButtonContextMenu(owner,
        {
            QRA.L["Assign to Trigger"],
            function()
                if onAdopt then onAdopt(assignment) end
            end,
        },
        {
            QRA.L["Delete Assignment"],
            function()
                if onDelete then onDelete(assignment) end
            end,
        }
    )
end

--------------------------------------------------
-- Delete Trigger Dialog
--------------------------------------------------

--- Show delete trigger confirmation with options
---@param trigger Trigger
---@param onComplete function Called after deletion
function QRA.UI.ShowDeleteTriggerDialog(trigger, onComplete)
    local hasAssignments, assignmentCount = QRA.Triggers.HasAssignments(trigger.id)

    if not hasAssignments then
        -- No assignments, just delete
        QRA.Triggers.DeleteTrigger(trigger.id, nil)
        if onComplete then onComplete() end
        return
    end

    -- Has assignments, show dialog
    local form = CreateFrame("Frame", nil, mainFrame)
    AF.SetSize(form, 300, 80)

    local msgFS = AF.CreateFontString(form, string.format(QRA.L["This trigger has %d assignment(s)"], assignmentCount), "white")
    AF.SetPoint(msgFS, "TOPLEFT", 0, 0)

    local questionFS = AF.CreateFontString(form, QRA.L["What would you like to do with the assignments?"], "gray")
    AF.SetPoint(questionFS, "TOPLEFT", msgFS, "BOTTOMLEFT", 0, -10)

    -- Buttons container
    local btnContainer = CreateFrame("Frame", nil, form)
    AF.SetHeight(btnContainer, 30)
    AF.SetPoint(btnContainer, "TOPLEFT", questionFS, "BOTTOMLEFT", 0, -15)
    AF.SetPoint(btnContainer, "TOPRIGHT", form, 0, -60)

    local deleteAllBtn = AF.CreateButton(btnContainer, QRA.L["Delete All"], "red", 90, 26)
    AF.SetPoint(deleteAllBtn, "LEFT", 0, 0)

    local orphanBtn = AF.CreateButton(btnContainer, QRA.L["Keep as Orphaned"], "orange", 120, 26)
    AF.SetPoint(orphanBtn, "LEFT", deleteAllBtn, "RIGHT", 10, 0)

    local cancelBtn = AF.CreateButton(btnContainer, QRA.L["Cancel"], "gray", 70, 26)
    AF.SetPoint(cancelBtn, "LEFT", orphanBtn, "RIGHT", 10, 0)

    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(QRA.L["Delete Trigger"], "red"), 320)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 100)

    deleteAllBtn:SetOnClick(function()
        QRA.Triggers.DeleteTrigger(trigger.id, false) -- Delete assignments too
        dialog:Hide()
        if onComplete then onComplete() end
    end)

    orphanBtn:SetOnClick(function()
        QRA.Triggers.DeleteTrigger(trigger.id, true) -- Orphan the assignments
        dialog:Hide()
        if onComplete then onComplete() end
    end)

    cancelBtn:SetOnClick(function()
        dialog:Hide()
    end)
end

--------------------------------------------------
-- Adopt Orphan Dialog
--------------------------------------------------

--- Show dialog to assign an orphaned assignment to a trigger
---@param assignment OrphanedAssignment
---@param onComplete function
function QRA.UI.ShowAdoptOrphanDialog(assignment, onComplete)
    local form = CreateFrame("Frame", nil, mainFrame)
    AF.SetSize(form, 300, 60)

    local triggerDropdown = QRA.Widgets.CreateTriggerDropdown(form, 280)
    AF.SetPoint(triggerDropdown, "TOPLEFT", 0, 10)

    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(QRA.L["Assign to Trigger"], "accent"), 320)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 80)

    dialog:SetOnConfirm(function()
        local triggerId = triggerDropdown:GetSelectedValue()
        if triggerId then
            QRA.Assignments.AdoptOrphan(assignment.id, triggerId)
            if onComplete then onComplete() end
        end
    end)
end

--------------------------------------------------
-- Main Tree View
--------------------------------------------------

local function BuildTreeView(parent, scrollList, bossFilter)
    local widgets = {}

    local function RefreshTree()
        BuildTreeView(parent, scrollList, bossFilter)
    end

    local function OnEditTrigger(trigger)
        QRA.UI.ShowTriggerEditor(trigger, trigger.bossName)
    end

    local function OnDeleteTrigger(trigger)
        QRA.UI.ShowDeleteTriggerDialog(trigger, function()
            RefreshTree()
        end)
    end

    local function OnAddAssignment(triggerId)
        QRA.UI.ShowAssignmentEditor(nil, triggerId)
    end

    local function OnEditAssignment(assignment, triggerId)
        QRA.UI.ShowAssignmentEditor(assignment, triggerId)
    end

    local function OnDeleteAssignment(assignment, triggerId)
        QRA.Assignments.Remove(triggerId, assignment.id)
        RefreshTree()
    end

    local function OnAddTrigger(bossName)
        QRA.UI.ShowTriggerEditor(nil, bossName)
    end

    -- If boss filter is set, only show that boss's triggers
    if bossFilter then
        local triggers = QRA.Triggers.GetBossTriggers(bossFilter)

        for _, trigger in ipairs(triggers) do
            -- Trigger row
            local triggerRow = CreateTriggerRow(
                scrollList.slotFrame,
                trigger,
                0,  -- No indent when showing single boss
                RefreshTree,
                OnEditTrigger,
                OnDeleteTrigger,
                OnAddAssignment
            )
            table.insert(widgets, triggerRow)

            -- Nested assignments (if expanded)
            if not IsTriggerCollapsed(trigger.id) and trigger.assignments then
                for _, assignment in ipairs(trigger.assignments) do
                    local assignRow = CreateAssignmentRow(
                        scrollList.slotFrame,
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
                local instanceRow = CreateInstanceRow(scrollList.slotFrame, instanceName, instanceData.tier, RefreshTree)
                table.insert(widgets, instanceRow)

                -- Bosses (if instance expanded)
                if not IsInstanceCollapsed(instanceName) then
                    for _, bossData in ipairs(instanceData.bosses) do
                        local triggers = QRA.Triggers.GetBossTriggers(bossData.name)

                        if #triggers > 0 then
                            -- Boss header
                            local bossRow = CreateBossRow(scrollList.slotFrame, bossData, 1, RefreshTree, OnAddTrigger)
                            table.insert(widgets, bossRow)

                            -- Triggers (if boss expanded)
                            if not IsBossCollapsed(bossData.name) then
                                for _, trigger in ipairs(triggers) do
                                    -- Trigger row
                                    local triggerRow = CreateTriggerRow(
                                        scrollList.slotFrame,
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
                                                scrollList.slotFrame,
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
        local separator = CreateFrame("Frame", nil, scrollList.slotFrame)
        AF.SetHeight(separator, 8)
        AF.SetPoint(separator, "LEFT")
        AF.SetPoint(separator, "RIGHT")
        table.insert(widgets, separator)

        -- Orphaned header
        local orphanHeader = CreateFrame("Frame", nil, scrollList.slotFrame)
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
                scrollList.slotFrame,
                assignment,
                function(a) QRA.UI.ShowAssignmentEditor(a, nil) end,
                function(a)
                    QRA.Assignments.DeleteOrphan(a.id)
                    RefreshTree()
                end,
                function(a)
                    QRA.UI.ShowAdoptOrphanDialog(a, RefreshTree)
                end
            )
            table.insert(widgets, orphanRow)
        end
    end

    scrollList:SetWidgets(widgets)
end

--------------------------------------------------
-- Settings Panel
--------------------------------------------------

local settingsFrame = nil

--- Create and show settings panel
function QRA.UI.ShowSettingsPanel()
    if settingsFrame then
        settingsFrame:Show()
        return
    end

    settingsFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_SettingsPanel",
        QRA.L["Settings"],
        300,
        430
    )
    AF.SetPoint(settingsFrame, "CENTER", mainFrame, 0, 0)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)

    local content = CreateFrame("Frame", nil, settingsFrame)
    AF.SetPoint(content, "TOPLEFT", settingsFrame, 10, -10)
    AF.SetPoint(content, "BOTTOMRIGHT", settingsFrame, -10, 40)

    -- Notifications section
    local notifHeader = QRA.Widgets.CreateSectionHeader(content, QRA.L["Notification Settings"])
    AF.SetPoint(notifHeader, "TOPLEFT", content, 0, 0)
    AF.SetPoint(notifHeader, "TOPRIGHT", content, 0, 0)

    local notifConfig = QRA.Notifications.GetConfig()

    -- TTS toggle
    local ttsCheck = AF.CreateCheckButton(content, QRA.L["Enable Text-to-Speech"], function(checked)
        QRA.Notifications.SetTTSEnabled(checked)
        QRA.Notifications.SaveToDB()
    end)
    AF.SetPoint(ttsCheck, "TOPLEFT", notifHeader, "BOTTOMLEFT", 10, -15)
    ttsCheck:SetChecked(notifConfig.ttsEnabled)

    -- Sound toggle
    local soundCheck = AF.CreateCheckButton(content, QRA.L["Enable Sounds"], function(checked)
        QRA.Notifications.SetSoundEnabled(checked)
        QRA.Notifications.SaveToDB()
    end)
    AF.SetPoint(soundCheck, "TOPLEFT", ttsCheck, "BOTTOMLEFT", 0, -10)
    soundCheck:SetChecked(notifConfig.soundEnabled)

    -- Screen messages toggle
    local screenCheck = AF.CreateCheckButton(content, QRA.L["Enable On-Screen Messages"], function(checked)
        QRA.Notifications.SetScreenEnabled(checked)
        QRA.Notifications.SaveToDB()
    end)
    AF.SetPoint(screenCheck, "TOPLEFT", soundCheck, "BOTTOMLEFT", 0, -10)
    screenCheck:SetChecked(notifConfig.screenEnabled)

    -- Chat toggle
    local chatCheck = AF.CreateCheckButton(content, QRA.L["Enable Chat Messages"], function(checked)
        QRA.Notifications.SetChatEnabled(checked)
        QRA.Notifications.SaveToDB()
    end)
    AF.SetPoint(chatCheck, "TOPLEFT", screenCheck, "BOTTOMLEFT", 0, -10)
    chatCheck:SetChecked(notifConfig.chatEnabled)

    -- Test buttons section
    local testHeader = QRA.Widgets.CreateSectionHeader(content, QRA.L["Test Notifications"])
    AF.SetPoint(testHeader, "TOPLEFT", chatCheck, "BOTTOMLEFT", -10, -20)
    AF.SetPoint(testHeader, "TOPRIGHT", content, 0, 0)

    local testTTSBtn = AF.CreateButton(content, QRA.L["Test TTS"], "static", 80, 22)
    AF.SetPoint(testTTSBtn, "TOPLEFT", testHeader, "BOTTOMLEFT", 10, -10)
    testTTSBtn:SetOnClick(QRA.Notifications.TestTTS)

    local testSoundBtn = AF.CreateButton(content, QRA.L["Test Sound"], "static", 90, 22)
    AF.SetPoint(testSoundBtn, "LEFT", testTTSBtn, "RIGHT", 8, 0)
    testSoundBtn:SetOnClick(QRA.Notifications.TestSound)

    local testScreenBtn = AF.CreateButton(content, QRA.L["Test Screen"], "static", 100, 22)
    AF.SetPoint(testScreenBtn, "TOPLEFT", testTTSBtn, "BOTTOMLEFT", 0, -8)
    testScreenBtn:SetOnClick(QRA.Notifications.TestScreen)

    local testCountdownBtn = AF.CreateButton(content, QRA.L["Test Countdown"], "static", 125, 22)
    AF.SetPoint(testCountdownBtn, "LEFT", testScreenBtn, "RIGHT", 8, 0)
    testCountdownBtn:SetOnClick(QRA.Notifications.TestCountdown)

    -- Movers section
    local moversHeader = QRA.Widgets.CreateSectionHeader(content, QRA.L["Movers"])
    AF.SetPoint(moversHeader, "TOPLEFT", testScreenBtn, "BOTTOMLEFT", -10, -20)
    AF.SetPoint(moversHeader, "TOPRIGHT", content, 0, 0)

    local showMoversBtn = AF.CreateButton(content, QRA.L["Show Movers"], "static", 115, 26)
    AF.SetPoint(showMoversBtn, "TOPLEFT", moversHeader, "BOTTOMLEFT", 0, -15)
    showMoversBtn:SetOnClick(function()
        AF.ShowMovers("QRA Movers")
    end)

    local hideMoversBtn = AF.CreateButton(content, QRA.L["Hide Movers"], "static", 100, 26)
    AF.SetPoint(hideMoversBtn, "LEFT", showMoversBtn, "RIGHT", 8, 0)
    hideMoversBtn:SetOnClick(function()
        AF.HideMovers()
    end)

    -- Debug section
    local debugHeader = QRA.Widgets.CreateSectionHeader(content, QRA.L["Debug"])
    AF.SetPoint(debugHeader, "TOPLEFT", showMoversBtn, "BOTTOMLEFT", 0, -20)
    AF.SetPoint(debugHeader, "TOPRIGHT", content, 0, 0)

    local debugCheck = AF.CreateCheckButton(content, QRA.L["Enable Debug Mode"], function(checked)
        QRA.Settings.debug = checked
        if AFConfig then
            AFConfig.debug[QRA.name] = checked
        end
    end)
    AF.SetPoint(debugCheck, "TOPLEFT", debugHeader, "BOTTOMLEFT", 10, -10)
    debugCheck:SetChecked(QRA.Settings.debug)

    -- Close button
    local closeBtn = AF.CreateButton(settingsFrame, QRA.L["Close"], "gray", 80, 26)
    AF.SetPoint(closeBtn, "BOTTOMRIGHT", settingsFrame, -10, 10)
    closeBtn:SetOnClick(function()
        settingsFrame:Hide()
    end)

    settingsFrame:Show()
end

--------------------------------------------------
-- Main Frame Creation
--------------------------------------------------

--- Create the main UI frame
local function CreateMainFrame()
    if mainFrame then return mainFrame end

    mainFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_MainFrame",
        "Q's Raid Assignments",
        UI_WIDTH,
        UI_HEIGHT
    )
    AF.SetPoint(mainFrame, "CENTER")
    mainFrame:SetFrameLevel(500)

    -- Apply combat protection
    AF.ApplyCombatProtectionToFrame(mainFrame)

    -- Content area
    local content = CreateFrame("Frame", nil, mainFrame)
    AF.SetPoint(content, "TOPLEFT", mainFrame, 10, -30)
    AF.SetPoint(content, "BOTTOMRIGHT", mainFrame, -10, 10)
    treeContent = content

    --------------------------------------------------
    -- Top Bar
    --------------------------------------------------
    local topBar = CreateFrame("Frame", nil, content)
    AF.SetHeight(topBar, 30)
    AF.SetPoint(topBar, "TOPLEFT", content, 0, 0)
    AF.SetPoint(topBar, "TOPRIGHT", content, 0, 0)

    -- LEFT GROUP: Boss filter and tree controls
    -- Boss filter dropdown
    local bossDropdown = QRA.Widgets.CreateBossMenu(topBar, 160, function(self, item)
        selectedBoss = item.text
        selectedEncounterId = item.encounterId
        QRA.Debug("Selected boss:", selectedBoss, "encounterId:", selectedEncounterId)
        QRA.UI.RefreshTree()
    end)
    AF.SetPoint(bossDropdown, "LEFT", topBar, 0, 0)

    -- Show All button
    local showAllBtn = AF.CreateButton(topBar, "All", "static", 30, 26)
    AF.SetPoint(showAllBtn, "LEFT", bossDropdown, "RIGHT", 5, 0)
    AF.SetTooltip(showAllBtn, "ANCHOR_BOTTOM", 0, 0, QRA.L["All Instances"])
    showAllBtn:SetOnClick(function()
        selectedBoss = nil
        selectedEncounterId = nil
        bossDropdown:SetText(QRA.L["All Instances"])
        QRA.UI.RefreshTree()
    end)

    -- Separator
    local sep1 = topBar:CreateTexture(nil, "ARTWORK")
    sep1:SetSize(1, 20)
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    AF.SetPoint(sep1, "LEFT", showAllBtn, "RIGHT", 8, 0)

    -- Expand/Collapse buttons
    local expandBtn = AF.CreateButton(topBar, "+", "static", 26, 26)
    AF.SetPoint(expandBtn, "LEFT", sep1, "RIGHT", 8, 0)
    AF.SetTooltip(expandBtn, "ANCHOR_BOTTOM", 0, 0, QRA.L["Expand All"])
    expandBtn:SetOnClick(function()
        ExpandAll()
        QRA.UI.RefreshTree()
    end)

    local collapseBtn = AF.CreateButton(topBar, "-", "static", 26, 26)
    AF.SetPoint(collapseBtn, "LEFT", expandBtn, "RIGHT", 2, 0)
    AF.SetTooltip(collapseBtn, "ANCHOR_BOTTOM", 0, 0, QRA.L["Collapse All"])
    collapseBtn:SetOnClick(function()
        CollapseAll()
        QRA.UI.RefreshTree()
    end)

    -- CENTER GROUP: Import/Export
    local sep2 = topBar:CreateTexture(nil, "ARTWORK")
    sep2:SetSize(1, 20)
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    AF.SetPoint(sep2, "LEFT", collapseBtn, "RIGHT", 10, 0)

    local importBtn = AF.CreateButton(topBar, QRA.L["Import"], "softblue", 60, 26)
    AF.SetPoint(importBtn, "LEFT", sep2, "RIGHT", 10, 0)
    importBtn:SetOnClick(function()
        QRA.UI.ShowImportFrame(function(input)
            QRA.Comm.Import(input, false)
            QRA.UI.RefreshTree()
        end)
    end)

    local exportBtn = AF.CreateButton(topBar, QRA.L["Export"], "softlime", 60, 26)
    AF.SetPoint(exportBtn, "LEFT", importBtn, "RIGHT", 5, 0)
    exportBtn:SetOnClick(function()
        local exportString = selectedEncounterId and QRA.Comm.ExportBoss(selectedEncounterId) or QRA.Comm.Export()
        if exportString and exportString ~= "" then
            QRA.UI.ShowExportFrame(exportString)
        end
    end)

    -- RIGHT GROUP: Test Mode and Settings
    -- Settings button
    local settingsBtn = AF.CreateButton(topBar, "S", "static", 26, 26)
    AF.SetPoint(settingsBtn, "RIGHT", topBar, 0, 0)
    AF.SetTooltip(settingsBtn, "ANCHOR_LEFT", 0, 0, QRA.L["Settings"])
    settingsBtn:SetOnClick(function()
        QRA.UI.ShowSettingsPanel()
    end)

    -- Test Mode button
    local testModeBtn = AF.CreateButton(topBar, "Test", "purple", 50, 26)
    AF.SetPoint(testModeBtn, "RIGHT", settingsBtn, "LEFT", -5, 0)
    AF.SetTooltip(testModeBtn, "ANCHOR_LEFT", 0, 0, QRA.L["Test Mode"], "Open DevMode test panel")
    testModeBtn:SetOnClick(function()
        if QRA.DevMode then
            if not QRA.DevMode.IsActive() then
                QRA.DevMode.Enable(selectedBoss, selectedEncounterId)
            end
            if QRA.DevMode.UI and QRA.DevMode.UI.ShowTestPanel then
                if selectedBoss then
                    QRA.DevMode.UI.SetSelectedBoss(selectedBoss, selectedEncounterId)
                end
                QRA.DevMode.UI.ShowTestPanel()
            end
        end
    end)

    --------------------------------------------------
    -- Tree List
    --------------------------------------------------
    local listFrame = AF.CreateBorderedFrame(content, nil, nil, 200, nil, "gray")
    AF.SetPoint(listFrame, "TOPLEFT", topBar, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(listFrame, "BOTTOMRIGHT", content, 0, 40)

    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 13, TREE_ROW_HEIGHT, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 5)
    content.scrollList = scrollList

    --------------------------------------------------
    -- Bottom Buttons
    --------------------------------------------------
    local addTriggerBtn = AF.CreateButton(content, QRA.L["+ Add Trigger"], "softlime", 120, 26)
    AF.SetPoint(addTriggerBtn, "TOPLEFT", listFrame, "BOTTOMLEFT", 0, -8)
    addTriggerBtn:SetEnabled(false)
    addTriggerBtn:SetOnClick(function()
        QRA.UI.ShowTriggerEditor(nil, selectedBoss)
    end)

    -- Update button state when boss selected
    hooksecurefunc(bossDropdown, "OnMenuSelection", function()
        addTriggerBtn:SetEnabled(selectedBoss ~= nil)
    end)

    -- Send to Raid button
    local sendToRaidBtn = AF.CreateButton(content, QRA.L["Send to Raid"], "softblue", 110, 26)
    AF.SetPoint(sendToRaidBtn, "LEFT", addTriggerBtn, "RIGHT", 10, 0)
    sendToRaidBtn:SetOnClick(function()
        local exportString = selectedEncounterId and QRA.Comm.ExportBoss(selectedEncounterId, true) or QRA.Comm.Export(true)
        if exportString and exportString ~= "" then
            QRA.Comm.SendToRaid(exportString)
        end
    end)

    -- Roster button
    local rosterBtn = AF.CreateButton(content, QRA.L["Roster"], "static", 80, 26)
    AF.SetPoint(rosterBtn, "LEFT", sendToRaidBtn, "RIGHT", 10, 0)
    AF.SetTooltip(rosterBtn, "TOPLEFT", 0, 2, "Roster Manager", "Save current raid roster for planning", "assignments when not in raid")
    rosterBtn:SetOnClick(function()
        QRA.AssignTargetMenu.ShowRosterManager(mainFrame)
    end)

    -- Test Mode indicator (shown when DevMode is active)
    local testModeIndicator = AF.CreateFontString(content, QRA.L["TEST MODE"], "purple")
    testModeIndicator:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    AF.SetPoint(testModeIndicator, "BOTTOMRIGHT", content, 0, 12)
    testModeIndicator:Hide()
    mainFrame.testModeIndicator = testModeIndicator

    -- Update test mode indicator visibility
    local function UpdateTestModeIndicator()
        if QRA.DevMode and QRA.DevMode.IsActive() then
            testModeIndicator:Show()
        else
            testModeIndicator:Hide()
        end
    end

    -- Hook into DevMode state changes
    if QRA.DevMode then
        QRA.DevMode.OnStateChanged = function(active)
            UpdateTestModeIndicator()
        end
    end

    -- Initial update
    UpdateTestModeIndicator()

    -- Store references
    content.addTriggerBtn = addTriggerBtn
    content.bossDropdown = bossDropdown

    -- Refresh function
    function QRA.UI.RefreshTree()
        BuildTreeView(content, scrollList, selectedBoss)
        content.addTriggerBtn:SetEnabled(selectedBoss ~= nil)
    end

    -- Refresh data when shown
    mainFrame:SetScript("OnShow", function()
        QRA.UI.RefreshTree()
        UpdateTestModeIndicator()
    end)

    return mainFrame
end

--------------------------------------------------
-- Public API
--------------------------------------------------

--- Show the main frame
function QRA.UI.ShowMainFrame()
    local frame = CreateMainFrame()
    frame:Show()
end

--- Hide the main frame
function QRA.UI.HideMainFrame()
    if mainFrame then
        mainFrame:Hide()
    end
end

--- Toggle the main frame visibility
function QRA.UI.Toggle()
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    else
        QRA.UI.ShowMainFrame()
    end
end

--- Refresh all lists in the UI
function QRA.UI.RefreshAll()
    if QRA.UI.RefreshTree then
        QRA.UI.RefreshTree()
    end
end

--------------------------------------------------
-- Editor Windows
--------------------------------------------------

---@class AF_HeaderedFrame
local assignmentEditorFrame = nil
---@class AF_HeaderedFrame
local triggerEditorFrame = nil

--- Show the assignment editor window
---@param assignment OrphanedAssignment|nil Existing assignment to edit, or nil for new
---@param triggerId string|nil Trigger ID to associate with (for new assignments)
function QRA.UI.ShowAssignmentEditor(assignment, triggerId)
    local isNew = assignment == nil
    local isOrphaned = assignment and assignment.orphanedAt ~= nil
    assignment = assignment or {}

    -- For orphaned assignments being edited, we need to handle differently
    local existingTriggerId = triggerId or assignment.triggerId

    -- Create or reuse the editor frame
    if not assignmentEditorFrame then
        assignmentEditorFrame = AF.CreateHeaderedFrame(
            QRA.UIParent,
            "QRA_AssignmentEditor",
            QRA.L["Assignment Editor"],
            220,
            425
        )
        AF.SetPoint(assignmentEditorFrame, "CENTER", mainFrame, 0, 0)
        assignmentEditorFrame:SetFrameStrata("DIALOG")
        assignmentEditorFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        assignmentEditorFrame:EnableMouse(true)
        assignmentEditorFrame:SetMovable(true)
        assignmentEditorFrame:RegisterForDrag("LeftButton")
        assignmentEditorFrame:SetScript("OnDragStart", assignmentEditorFrame.StartMoving)
        assignmentEditorFrame:SetScript("OnDragStop", assignmentEditorFrame.StopMovingOrSizing)
        assignmentEditorFrame:SetClampedToScreen(true)
    end

    -- Update title based on new/edit
    local title = isNew and QRA.L["New Assignment"] or QRA.L["Edit Assignment"]
    assignmentEditorFrame:SetTitle(AF.WrapTextInColor(title, "accent"))

    -- Clear previous content
    if assignmentEditorFrame.content then
        assignmentEditorFrame.content:Hide()
        assignmentEditorFrame.content:SetParent(nil)
    end

    -- Create form container
    local form = CreateFrame("Frame", nil, assignmentEditorFrame)
    AF.SetPoint(form, "TOPLEFT", assignmentEditorFrame, 10, -35)
    AF.SetPoint(form, "BOTTOMRIGHT", assignmentEditorFrame, -10, 50)
    assignmentEditorFrame.content = form

    -- Trigger dropdown (link to a trigger)
    local triggerDropdown = QRA.Widgets.CreateTriggerDropdown(form, 200)
    AF.SetPoint(triggerDropdown, "TOPLEFT", 0, 10)
    if existingTriggerId then
        triggerDropdown:SetSelectedValue(existingTriggerId)
    end

    -- Counter formula input (for assignment-level counter)
    local counterInput = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], 200)
    AF.SetPoint(counterInput, "TOPLEFT", triggerDropdown, "BOTTOMLEFT", 0, -10)
    if assignment.counterFormula then
        counterInput:SetValue(assignment.counterFormula)
    end

    -- Assign Target text input (who receives this assignment)
    local assignTargetInput = QRA.Widgets.CreateAssignTargetInput(form, QRA.L["Assign To"], 200)
    AF.SetPoint(assignTargetInput, "TOPLEFT", counterInput, "BOTTOMLEFT", 0, -10)
    if assignment.assignTarget then
        assignTargetInput:SetValue(assignment.assignTarget)
    else
        assignTargetInput:SetValue("ALL")
    end

    -- Spell input
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell"], 200)
    AF.SetPoint(spellInput, "TOPLEFT", assignTargetInput, "BOTTOMLEFT", 0, -25)
    if assignment.spellId then
        spellInput:SetSpell(assignment.spellId, assignment.spellName)
        spellInput:SetCursorPosition(0)
    end

    -- Message input
    local msgInput = AF.CreateEditBox(form, QRA.L["Message (optional)"], 200, 20)
    AF.SetPoint(msgInput, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, -15)
    if assignment.message then
        msgInput:SetText(assignment.message)
        msgInput:SetCursorPosition(0)
    end

    -- Target input (who to use the spell on)
    local targetInput = AF.CreateEditBox(form, QRA.L["Target (optional)"], 200, 20)
    AF.SetPoint(targetInput, "TOPLEFT", msgInput, "BOTTOMLEFT", 0, -10)
    if assignment.targetPlayer then
        targetInput:SetText(assignment.targetPlayer)
        targetInput:SetCursorPosition(0)
    end
    AF.SetTooltip(targetInput, "TOPLEFT", 0, 2,
        "Specify a target player name for the spell assignment.\nIf message is provided it overrides specified target."
    )

    -- Countdown slider
    local countdownSlider = QRA.Widgets.CreateCountdownSlider(form, 200, 0, 10)
    AF.SetPoint(countdownSlider, "TOPLEFT", targetInput, "BOTTOMLEFT", 0, -25)
    if assignment.countdownTime then
        countdownSlider:SetValue(assignment.countdownTime)
        countdownSlider:SetCursorPosition(0)
    end

    -- Alert type dropdown
    local alertDropdown = QRA.Widgets.CreateAlertTypeDropdown(form, 200)
    AF.SetPoint(alertDropdown, "TOPLEFT", countdownSlider, "BOTTOMLEFT", 0, -30)
    if assignment.alertType then
        alertDropdown:SetSelectedValue(assignment.alertType)
    end

    -- Activate In input (delay assignment activation)
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], 200)
    AF.SetPoint(activateInInput, "TOPLEFT", alertDropdown, "BOTTOMLEFT", 0, -10)
    if assignment.activateIn then
        activateInInput:SetValue(assignment.activateIn)
    end

    -- Save button (create once, reuse)
    if not assignmentEditorFrame.saveBtn then
        assignmentEditorFrame.saveBtn = AF.CreateButton(assignmentEditorFrame, QRA.L["Save"], "softlime", 80, 26)
        AF.SetPoint(assignmentEditorFrame.saveBtn, "BOTTOMRIGHT", assignmentEditorFrame, -10, 10)
    end
    local saveBtn = assignmentEditorFrame.saveBtn

    -- Cancel button (create once, reuse)
    if not assignmentEditorFrame.cancelBtn then
        assignmentEditorFrame.cancelBtn = AF.CreateButton(assignmentEditorFrame, QRA.L["Cancel"], "gray", 80, 26)
        AF.SetPoint(assignmentEditorFrame.cancelBtn, "RIGHT", assignmentEditorFrame.saveBtn, "LEFT", -10, 0)
        assignmentEditorFrame.cancelBtn:SetOnClick(function()
            assignmentEditorFrame:Hide()
        end)
    end

    -- Store current state on form for save handler to reference
    form.assignment = assignment
    form.isNew = isNew
    form.isOrphaned = isOrphaned
    form.existingTriggerId = existingTriggerId

    saveBtn:SetOnClick(function()
        local currentAssignment = form.assignment
        local currentIsNew = form.isNew
        local currentIsOrphaned = form.isOrphaned

        local spellData = spellInput:GetSpell()
        local message = msgInput:GetText()
        local targetPlayer = targetInput:GetText()

        local selectedTriggerId = triggerDropdown:GetSelectedValue()

        local newAssignment = QRA.Assignments.Create({
            triggerId = selectedTriggerId,
            counterFormula = counterInput:GetValue() or "*",
            assignTarget = assignTargetInput:GetValue() or "ALL",
            spellId = spellData.spellId,
            spellName = spellData.spellName or nil,
            message = message,
            targetPlayer = targetPlayer,
            countdownTime = countdownSlider:GetValue(),
            alertType = alertDropdown:GetSelectedValue(),
            activateIn = activateInInput:GetValue(),
        })

        if currentIsNew then
            if selectedTriggerId then
                QRA.Assignments.Add(selectedTriggerId, newAssignment)
            end
        elseif currentIsOrphaned then
            -- Updating an orphaned assignment
            if selectedTriggerId then
                -- Moving orphan to a trigger
                QRA.Assignments.DeleteOrphan(currentAssignment.id)
                QRA.Assignments.Add(selectedTriggerId, newAssignment)
            else
                -- Just updating orphan data
                QRA.Assignments.UpdateOrphan(currentAssignment.id, {
                    counterFormula = newAssignment.counterFormula,
                    assignTarget = newAssignment.assignTarget,
                    spellId = newAssignment.spellId,
                    spellName = newAssignment.spellName,
                    message = newAssignment.message,
                    targetPlayer = newAssignment.targetPlayer,
                    countdownTime = newAssignment.countdownTime,
                    alertType = newAssignment.alertType,
                    activateIn = newAssignment.activateIn,
                })
            end
        else
            -- Updating existing assignment
            local oldTriggerId = currentAssignment.triggerId
            if oldTriggerId ~= selectedTriggerId then
                -- Moving to different trigger
                QRA.Assignments.Remove(oldTriggerId, currentAssignment.id)
                if selectedTriggerId then
                    QRA.Assignments.Add(selectedTriggerId, newAssignment)
                end
            else
                -- Same trigger, just update
                QRA.Assignments.Update(oldTriggerId, currentAssignment.id, {
                    counterFormula = newAssignment.counterFormula,
                    assignTarget = newAssignment.assignTarget,
                    spellId = newAssignment.spellId,
                    spellName = newAssignment.spellName,
                    message = newAssignment.message,
                    targetPlayer = newAssignment.targetPlayer,
                    countdownTime = newAssignment.countdownTime,
                    alertType = newAssignment.alertType,
                    activateIn = newAssignment.activateIn,
                })
            end
        end

        QRA.UI.RefreshAll()
        assignmentEditorFrame:Hide()
    end)

    -- ESC key handler
    assignmentEditorFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)

    assignmentEditorFrame:Show()
end

--- Show the trigger editor window
---@param trigger Trigger|nil Existing trigger to edit, or nil for new
---@param bossInput string|nil Boss name to associate the trigger with
function QRA.UI.ShowTriggerEditor(trigger, bossInput)
    QRA.Debug("Opening Trigger Editor: ", trigger, bossInput)
    local isNew = trigger == nil
    local editable = not isNew and trigger.default ~= true or isNew
    trigger = trigger or {}

    -- Create or reuse the editor frame
    if not triggerEditorFrame then
        triggerEditorFrame = AF.CreateHeaderedFrame(
            QRA.UIParent,
            "QRA_TriggerEditor",
            QRA.L["Trigger Editor"],
            220,
            250
        )
        AF.SetPoint(triggerEditorFrame, "CENTER", mainFrame, 0, 0)
        triggerEditorFrame:SetFrameStrata("DIALOG")
        triggerEditorFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        triggerEditorFrame:EnableMouse(true)
        triggerEditorFrame:SetMovable(true)
        triggerEditorFrame:RegisterForDrag("LeftButton")
        triggerEditorFrame:SetScript("OnDragStart", triggerEditorFrame.StartMoving)
        triggerEditorFrame:SetScript("OnDragStop", triggerEditorFrame.StopMovingOrSizing)
        triggerEditorFrame:SetClampedToScreen(true)
    end

    -- Update title based on new/edit
    local title = isNew and QRA.L["New Trigger"] or QRA.L["Edit Trigger"]
    triggerEditorFrame:SetTitle(AF.WrapTextInColor(title, "accent"))

    -- Clear previous content
    if triggerEditorFrame.content then
        triggerEditorFrame.content:Hide()
        triggerEditorFrame.content:SetParent(nil)
    end

    -- Create form container
    local form = CreateFrame("Frame", nil, triggerEditorFrame)
    AF.SetPoint(form, "TOPLEFT", triggerEditorFrame, 10, -35)
    AF.SetPoint(form, "BOTTOMRIGHT", triggerEditorFrame, -10, 50)
    triggerEditorFrame.content = form

    -- Trigger type dropdown
    local typeDropdown = QRA.Widgets.CreateTriggerTypeDropdown(form, 200)
    AF.SetPoint(typeDropdown, "TOPLEFT", 0, 10)
    if trigger.type then
        typeDropdown:SetSelectedValue(trigger.type)
    end
    typeDropdown:SetEnabled(editable)

    -- Name field
    local nameInput = AF.CreateEditBox(form, QRA.L["Name"], 200, 20)
    AF.SetPoint(nameInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -10)
    nameInput:Hide()
    if trigger.name then
        nameInput:SetText(trigger.name)
        nameInput:SetCursorPosition(0)
    end
    nameInput:SetEnabled(editable)

    -- Spell input (shown for spell-related triggers)
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell ID"], 200, false)
    AF.SetPoint(spellInput, "TOPLEFT", nameInput, "BOTTOMLEFT", 0, -35)
    spellInput:Hide()
    if trigger.spellId then
        spellInput:SetSpell(trigger.spellId)
        spellInput:SetCursorPosition(0)
    end
    spellInput:SetEnabled(editable)

    -- Timer input (shown for timer triggers)
    local timerInput = AF.CreateEditBox(form, QRA.L["Time (seconds)"], 200, 20, "number")
    AF.SetPoint(timerInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    timerInput:Hide()
    if trigger.time then
        timerInput:SetText(tostring(trigger.time))
        timerInput:SetCursorPosition(0)
    end
    timerInput:SetEnabled(editable)

    -- Interval input (shown for timer triggers, below Time input)
    local intervalInput = AF.CreateEditBox(form, QRA.L["Interval (seconds)"], 200, 20, "number")
    AF.SetPoint(intervalInput, "TOPLEFT", timerInput, "BOTTOMLEFT", 0, -10)
    intervalInput:Hide()
    if trigger.repeatInterval then
        intervalInput:SetText(tostring(trigger.repeatInterval))
        intervalInput:SetCursorPosition(0)
    end
    intervalInput:SetEnabled(editable)

    -- Repeat Count input (shown for timer triggers, below Interval input)
    local repeatCountInput = AF.CreateEditBox(form, QRA.L["Repeat Count"], 200, 20, "number")
    AF.SetPoint(repeatCountInput, "TOPLEFT", intervalInput, "BOTTOMLEFT", 0, -10)
    repeatCountInput:Hide()
    if trigger.repeatCount then
        repeatCountInput:SetText(tostring(trigger.repeatCount))
        repeatCountInput:SetCursorPosition(0)
    end
    repeatCountInput:SetEnabled(editable)

    -- Target GUID input (shown for UNIT_HEALTH and UNIT_DIED triggers)
    local targetGuidInput = QRA.Widgets.CreateTargetGuidInput(form, QRA.L["Target Unit/NPC ID"], 200)
    AF.SetPoint(targetGuidInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    targetGuidInput:Hide()
    if trigger.targetGuid then
        targetGuidInput:SetText(trigger.targetGuid)
    end
    targetGuidInput:SetCursorPosition(0)
    targetGuidInput:SetEnabled(editable)

    -- HP Thresholds input (shown for UNIT_HEALTH triggers)
    local hpThresholdsInput = QRA.Widgets.CreateHPThresholdsInput(form, QRA.L["HP Thresholds (%)"], 200)
    AF.SetPoint(hpThresholdsInput, "TOPLEFT", targetGuidInput, "BOTTOMLEFT", 0, -10)
    hpThresholdsInput:Hide()
    if trigger.hpThresholds then
        hpThresholdsInput:SetText(trigger.hpThresholds)
    end
    hpThresholdsInput:SetCursorPosition(0)
    hpThresholdsInput:SetEnabled(editable)

    -- Counter formula input
    local occSelector = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], 200)
    AF.SetPoint(occSelector, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, -5)
    QRA.Debug("Setting counter formula to:", trigger.counterFormula, "Type:", type(trigger.counterFormula))
    if trigger.counterFormula then
        occSelector:SetValue(trigger.counterFormula)
    end
    occSelector:Hide()
    occSelector:SetEnabled(editable)

    -- Activate In input (delay trigger activation)
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], 200)
    AF.SetPoint(activateInInput, "TOPLEFT", occSelector, "BOTTOMLEFT", 0, -5)
    if trigger.activateIn then
        activateInInput:SetValue(trigger.activateIn)
    end
    activateInInput:Hide()
    activateInInput:SetEnabled(editable)

    -- Update visibility based on trigger type
    local function UpdateInputVisibility()
        local triggerType = typeDropdown:GetSelectedValue()
        nameInput:Hide()
        spellInput:Hide()
        timerInput:Hide()
        intervalInput:Hide()
        repeatCountInput:Hide()
        targetGuidInput:Hide()
        hpThresholdsInput:Hide()
        occSelector:Hide()
        activateInInput:Hide()

        if triggerType == QRA.Triggers.Types.SPELL_CAST_SUCCESS.event or
           triggerType == QRA.Triggers.Types.SPELL_CAST_START.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_APPLIED.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_REMOVED.event then
            nameInput:Show()
            spellInput:Show()
            occSelector:Show()
            AF.SetPoint(activateInInput, "TOPLEFT", occSelector, "BOTTOMLEFT", 0, -5)
            activateInInput:Show()
        elseif triggerType == QRA.Triggers.Types.TIMER.event then
            timerInput:Show()
            intervalInput:Show()
            repeatCountInput:Show()
        elseif triggerType == QRA.Triggers.Types.UNIT_DIED.event then
            nameInput:Show()
            targetGuidInput:Show()
            occSelector:Show()
            AF.SetPoint(activateInInput, "TOPLEFT", occSelector, "BOTTOMLEFT", 0, -5)
            activateInInput:Show()
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            targetGuidInput:Show()
            hpThresholdsInput:Show()
            AF.SetPoint(activateInInput, "TOPLEFT", hpThresholdsInput, "BOTTOMLEFT", 0, -5)
            activateInInput:Show()
        end
    end

    typeDropdown:SetOnSelect(function()
        UpdateInputVisibility()
    end)
    UpdateInputVisibility()

    -- Save button (create once, reuse)
    if not triggerEditorFrame.saveBtn then
        triggerEditorFrame.saveBtn = AF.CreateButton(triggerEditorFrame, QRA.L["Save"], "softlime", 80, 26)
        AF.SetPoint(triggerEditorFrame.saveBtn, "BOTTOMRIGHT", triggerEditorFrame, -10, 10)
    end
    local saveBtn = triggerEditorFrame.saveBtn
    saveBtn:SetEnabled(editable)

    -- Cancel button (create once, reuse)
    if not triggerEditorFrame.cancelBtn then
        triggerEditorFrame.cancelBtn = AF.CreateButton(triggerEditorFrame, QRA.L["Cancel"], "gray", 80, 26)
        AF.SetPoint(triggerEditorFrame.cancelBtn, "RIGHT", triggerEditorFrame.saveBtn, "LEFT", -10, 0)
        triggerEditorFrame.cancelBtn:SetOnClick(function()
            triggerEditorFrame:Hide()
        end)
    end

    -- Store current state on form for save handler to reference
    form.trigger = trigger
    form.isNew = isNew
    form.bossInput = bossInput
    form.editable = editable

    saveBtn:SetOnClick(function()
        -- Get current state from form (not closure)
        local currentTrigger = form.trigger
        local currentIsNew = form.isNew
        local currentBossInput = form.bossInput

        QRA.Debug("Saving trigger from editor for:", currentTrigger, currentBossInput)
        local triggerType = typeDropdown:GetSelectedValue()
        QRA.Debug("Selected trigger type:", triggerType)
        local bossData = QRA.Bosses.GetBossByName(currentBossInput)
        local counterFormulaValue = occSelector:GetValue()
        QRA.Debug("Counter formula from UI:", counterFormulaValue, type(counterFormulaValue))
        local config = {
            id = currentTrigger.id,
            counterFormula = counterFormulaValue or "*",
            bossName = currentBossInput,
            encounterId = bossData and bossData.encounterId or nil,
        }

        -- Only include name for trigger types that show the name input field and should preserve custom names
        -- Timer and HP% triggers auto-generate names based on their configuration
        if triggerType ~= QRA.Triggers.Types.TIMER.event and
           triggerType ~= QRA.Triggers.Types.UNIT_HEALTH.event then
            local customName = strtrim(nameInput:GetText())
            if customName ~= "" then
                config.name = customName
            end
        end

        if triggerType == QRA.Triggers.Types.SPELL_CAST_SUCCESS.event or
           triggerType == QRA.Triggers.Types.SPELL_CAST_START.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_APPLIED.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_REMOVED.event then
            local spellData = spellInput:GetSpell()
            QRA.Debug("Selected spell:", spellData)
            config.spellId = spellData.spellId
            config.spellName = spellData.spellName
            config.activateIn = activateInInput:GetValue()
        elseif triggerType == QRA.Triggers.Types.TIMER.event then
            config.time = tonumber(timerInput:GetText()) or 0
            local intervalValue = tonumber(intervalInput:GetText())
            config.repeatInterval = (intervalValue and intervalValue > 0) and intervalValue or nil
            local repeatCountValue = tonumber(repeatCountInput:GetText())
            config.repeatCount = (repeatCountValue and repeatCountValue > 0) and math.floor(repeatCountValue) or nil
            config.counterFormula = "1"
        elseif triggerType == QRA.Triggers.Types.UNIT_DIED.event then
            config.targetGuid = strtrim(targetGuidInput:GetText())
            config.activateIn = activateInInput:GetValue()
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            config.targetGuid = strtrim(targetGuidInput:GetText())
            config.hpThresholds = strtrim(hpThresholdsInput:GetText())
            config.activateIn = activateInInput:GetValue()
        end

        QRA.Debug("Trigger config to save:", config)

        -- Validation
        local isValid = true
        if triggerType == QRA.Triggers.Types.TIMER.event then
            local hasValidTime = config.time and config.time > 0
            local hasValidInterval = config.repeatInterval and config.repeatInterval > 0
            if not hasValidTime and not hasValidInterval then
                isValid = false
            end
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            if not targetGuidInput:IsValid() or not hpThresholdsInput:IsValid() then
                isValid = false
            end
        end

        if not isValid then
            QRA.Debug("Invalid trigger configuration, aborting save")
            return
        end

        local newTrigger = QRA.Triggers.Create(triggerType, config, currentIsNew)

        -- Preserve existing assignments when updating
        if not currentIsNew and currentTrigger.assignments then
            newTrigger.assignments = currentTrigger.assignments
        end

        if currentIsNew then
            QRA.Triggers.SaveTrigger(newTrigger)
        else
            QRA.Triggers.UpdateTrigger(newTrigger)
        end

        QRA.UI.RefreshAll()
        triggerEditorFrame:Hide()
    end)

    -- ESC key handler
    triggerEditorFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)

    triggerEditorFrame:Show()
end

--- Show template name input dialog
---@param onConfirm function Callback with template name
function QRA.UI.ShowTemplateNameDialog(onConfirm)
    local form = CreateFrame("Frame", nil, mainFrame)

    local nameInput = AF.CreateEditBox(form, QRA.L["Template Name"], 200, 20)
    AF.SetPoint(nameInput, "TOPLEFT", 0, 0)
    nameInput:SetText("New Template")

    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(QRA.L["Save Template"], "accent"), 220)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 50)
    dialog:SetOnConfirm(function()
        local name = nameInput:GetText()
        if name and name ~= "" and onConfirm then
            onConfirm(name)
        end
    end)
end

---@class AF_HeaderedFrame
local exportFrame = nil
--- Show export dialog
---@param exportString string The export string to show
function QRA.UI.ShowExportFrame(exportString)
    if exportFrame then
        exportFrame:SetText(exportString)
        exportFrame:Show()
        return
    end

    exportFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_ExportFrame",
        QRA.L["Export Data"],
        400,
        300
    )
    AF.SetPoint(exportFrame, "CENTER", mainFrame, 0, 0)
    local editBox = AF.CreateEditBox(exportFrame, QRA.L["Export Data"], 400, 200, "multiline")
    AF.SetPoint(editBox, "TOPLEFT")
    editBox:SetAutoFocus(true)
    editBox:SetText(exportString)

    local ctrlDown = false
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA" then
            ctrlDown = true
        end
        if key == "ESCAPE" then
            exportFrame:Hide()
        end
    end)
    editBox:SetScript("OnKeyUp", function(self, key)
        if key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA" then
            QRA.DelayedInvoke(0.2, function() ctrlDown = false end)
        end
        if ctrlDown and key == "C" then
            QRA.DelayedInvoke(0.1, function() exportFrame:Hide() end)
        end
    end)

    function exportFrame:SetText(text)
        editBox:SetText(text)
    end

    exportFrame:Show()
end

---@class AF_HeaderedFrame
local importFrame = nil
--- Show import dialog
---@param callback function Callback with import string
function QRA.UI.ShowImportFrame(callback)
    if importFrame then
        importFrame:ClearText()
        importFrame:Show()
        return
    end

    importFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_ImportFrame",
        QRA.L["Import Data"],
        400,
        200
    )
    AF.SetPoint(importFrame, "CENTER", mainFrame, 0, 0)

    local editBox = AF.CreateScrollEditBox(importFrame, QRA.L["Import Data"], nil, 400, 150)
    AF.SetPoint(editBox, "TOPLEFT")
    editBox:SetAutoFocus(true)

    local importBtn = AF.CreateButton(importFrame, QRA.L["OK"], "softlime", 100, 26)
    AF.SetPoint(importBtn, "BOTTOMRIGHT")
    importBtn:SetOnClick(function()
        local input = editBox:GetText()
        if input and input ~= "" and callback then
            editBox:SetText("")
            callback(input)
            importFrame:Hide()
        end
    end)

    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            importFrame:Hide()
        end
        if key == "ENTER" and IsControlKeyDown() then
            importBtn:Click()
        end
    end)

    function importFrame:ClearText()
        editBox:SetText("")
    end

    importFrame:Show()
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.UI.Initialize()
    QRA.Debug("UI: Module initialized")
end
