---@class QRA
local QRA = select(2, ...)

---@class QRA_UI | QRA_Module
QRA.UI = QRA.UI or {}

---@class QRA_UI_Dialogs | QRA_Module
QRA.UI.Dialogs = {}

---@type AbstractFramework
local AF = _G.AbstractFramework

---@type AF_HeaderedFrame
local assignmentEditorFrame = nil
---@class AF_HeaderedFrame
local triggerEditorFrame = nil
---@type Frame
local mainFrame = nil

--- Show the assignment editor window
---@param assignment OrphanedAssignment|nil Existing assignment to edit, or nil for new
---@param triggerId string|nil Trigger ID to associate with (for new assignments)
function QRA.UI.Dialogs.ShowAssignmentEditor(assignment, triggerId)
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
        assignmentEditorFrame:SetFrameStrata("HIGH")
        assignmentEditorFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    end

    -- Update title based on new/edit
    local title = isNew and QRA.L["New Assignment"] or QRA.L["Edit Assignment"]
    assignmentEditorFrame:SetTitle(AF.WrapTextInColor(title, "accent"))

    -- Clear previous content
    if assignmentEditorFrame.content then
        assignmentEditorFrame.content:Hide()
        assignmentEditorFrame.content:SetParent(nil)
    end

    local form = CreateFrame("Frame", nil, assignmentEditorFrame)
    AF.SetPoint(form, "TOPLEFT", assignmentEditorFrame, 10, -35)
    AF.SetPoint(form, "BOTTOMRIGHT", assignmentEditorFrame, -10, 50)
    assignmentEditorFrame.content = form

    -- Trigger dropdown
    local triggerDropdown = QRA.Widgets.CreateTriggerDropdown(form, 200)
    AF.SetPoint(triggerDropdown, "TOPLEFT", 0, 10)
    if existingTriggerId then
        triggerDropdown:SetSelectedValue(existingTriggerId)
    end

    -- Counter formula input
    local counterInput = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], 200)
    AF.SetPoint(counterInput, "TOPLEFT", triggerDropdown, "BOTTOMLEFT", 0, -10)
    if assignment.counterFormula then
        counterInput:SetValue(assignment.counterFormula)
    end

    -- Assign Target text input
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

    -- Target input
    local targetInput = AF.CreateEditBox(form, QRA.L["Target (optional)"], 200, 20)
    AF.SetPoint(targetInput, "TOPLEFT", msgInput, "BOTTOMLEFT", 0, -10)
    if assignment.targetPlayer then
        targetInput:SetText(assignment.targetPlayer)
        targetInput:SetCursorPosition(0)
    end
    AF.SetTooltip(targetInput, "TOPLEFT", 0, 2, "Specify a target player name for the spell assignment.\nIf message is provided it overrides specified target.")

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

    -- Activate In input
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], 200)
    AF.SetPoint(activateInInput, "TOPLEFT", alertDropdown, "BOTTOMLEFT", 0, -10)
    if assignment.activateIn then
        activateInInput:SetValue(assignment.activateIn)
    end

    -- Save button
    if not assignmentEditorFrame.saveBtn then
        assignmentEditorFrame.saveBtn = AF.CreateButton(assignmentEditorFrame, QRA.L["Save"], "softlime", 80, 26)
        AF.SetPoint(assignmentEditorFrame.saveBtn, "BOTTOMRIGHT", assignmentEditorFrame, -10, 10)
    end
    local saveBtn = assignmentEditorFrame.saveBtn

    -- Cancel button
    if not assignmentEditorFrame.cancelBtn then
        assignmentEditorFrame.cancelBtn = AF.CreateButton(assignmentEditorFrame, QRA.L["Cancel"], "gray", 80, 26)
        AF.SetPoint(assignmentEditorFrame.cancelBtn, "RIGHT", assignmentEditorFrame.saveBtn, "LEFT", -10, 0)
        assignmentEditorFrame.cancelBtn:SetOnClick(function()
            assignmentEditorFrame:Hide()
        end)
    end

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
function QRA.UI.Dialogs.ShowTriggerEditor(trigger, bossInput)
    QRA.Debug("Opening Trigger Editor: ", trigger, bossInput)
    local isNew = trigger == nil
    local editable = not isNew and trigger.default ~= true or isNew
    trigger = trigger or {}

    if not triggerEditorFrame then
        triggerEditorFrame = AF.CreateHeaderedFrame(
            QRA.UIParent,
            "QRA_TriggerEditor",
            QRA.L["Trigger Editor"],
            220,
            250
        )
        AF.SetPoint(triggerEditorFrame, "CENTER", mainFrame, 0, 0)
        triggerEditorFrame:SetFrameStrata("HIGH")
        triggerEditorFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
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

    -- Interval input (shown for timer triggers)
    local intervalInput = AF.CreateEditBox(form, QRA.L["Interval (seconds)"], 200, 20, "number")
    AF.SetPoint(intervalInput, "TOPLEFT", timerInput, "BOTTOMLEFT", 0, -10)
    intervalInput:Hide()
    if trigger.repeatInterval then
        intervalInput:SetText(tostring(trigger.repeatInterval))
        intervalInput:SetCursorPosition(0)
    end
    intervalInput:SetEnabled(editable)

    -- Repeat Count input (shown for timer triggers)
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

    -- Activate In input
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], 200)
    AF.SetPoint(activateInInput, "TOPLEFT", occSelector, "BOTTOMLEFT", 0, -5)
    if trigger.activateIn then
        activateInInput:SetValue(trigger.activateIn)
    end
    activateInInput:Hide()
    activateInInput:SetEnabled(editable)

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

    -- Save button
    if not triggerEditorFrame.saveBtn then
        triggerEditorFrame.saveBtn = AF.CreateButton(triggerEditorFrame, QRA.L["Save"], "softlime", 80, 26)
        AF.SetPoint(triggerEditorFrame.saveBtn, "BOTTOMRIGHT", triggerEditorFrame, -10, 10)
    end
    local saveBtn = triggerEditorFrame.saveBtn
    saveBtn:SetEnabled(editable)

    -- Cancel button
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
function QRA.UI.Dialogs.ShowTemplateNameDialog(onConfirm)
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
function QRA.UI.Dialogs.ShowExportFrame(exportString)
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
function QRA.UI.Dialogs.ShowImportFrame(callback)
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
-- Delete Trigger Dialog
--------------------------------------------------

--- Show delete trigger confirmation with options
---@param trigger Trigger
---@param onComplete function Called after deletion
function QRA.UI.Dialogs.ShowDeleteTriggerDialog(trigger, onComplete)
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
function QRA.UI.Dialogs.ShowAdoptOrphanDialog(assignment, onComplete)
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

---@param myMainFrame Frame
function QRA.UI.Dialogs.Initialize(myMainFrame)
    mainFrame = myMainFrame
end
