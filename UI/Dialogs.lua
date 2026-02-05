---@class QRA
local QRA = select(2, ...)

---@class QRA_UI
QRA.UI = QRA.UI or {}

---@class QRA_UI_Dialogs
QRA.UI.Dialogs = {}

---@type AbstractFramework
local AF = _G.AbstractFramework

---@class AF_HeaderedFrame
local assignmentEditorFrame = nil
---@class AF_HeaderedFrame
local triggerEditorFrame = nil
---@class Frame
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
            400,
            "HIGH",
            mainFrame:GetFrameLevel() + 10
        )
        AF.SetPoint(assignmentEditorFrame, "CENTER", mainFrame, 0, 0)
        table.insert(UISpecialFrames, assignmentEditorFrame:GetName())
    end

    -- Update title based on new/edit
    local title = isNew and QRA.L["New Assignment"] or QRA.L["Edit Assignment"]
    assignmentEditorFrame:SetTitle(AF.WrapTextInColor(title, "softlime"))

    -- Clear previous content
    if assignmentEditorFrame.content then
        assignmentEditorFrame.content:Hide()
        assignmentEditorFrame.content:SetParent(nil)
    end

    local form = CreateFrame("Frame", nil, assignmentEditorFrame)
    AF.SetPoint(form, "TOPLEFT", assignmentEditorFrame, 10, -35)
    AF.SetPoint(form, "BOTTOMRIGHT", assignmentEditorFrame, -10, 50)
    assignmentEditorFrame.content = form

    -- Layout constants
    local FIELD_SPACING = -10
    local FIELD_SPACING_LARGE = -25
    local FORM_WIDTH = 200

    -- Trigger dropdown
    local triggerDropdown = QRA.Widgets.CreateTriggerDropdown(form, FORM_WIDTH)
    AF.SetPoint(triggerDropdown, "TOPLEFT", 0, 10)
    if existingTriggerId then
        triggerDropdown:SetSelectedValue(existingTriggerId)
    end

    -- Counter formula input
    local counterInput = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], FORM_WIDTH)
    AF.SetPoint(counterInput, "TOPLEFT", triggerDropdown, "BOTTOMLEFT", 0, FIELD_SPACING)
    if assignment.counterFormula then
        counterInput:SetValue(assignment.counterFormula)
    end

    -- Assign Target text input
    local assignTargetInput = QRA.Widgets.CreateAssignTargetInput(form, QRA.L["Assign To"], FORM_WIDTH)
    AF.SetPoint(assignTargetInput, "TOPLEFT", counterInput, "BOTTOMLEFT", 0, FIELD_SPACING)
    if assignment.assignTarget then
        assignTargetInput:SetValue(assignment.assignTarget)
    else
        assignTargetInput:SetValue("ALL")
    end

    -- Spell input
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell"], FORM_WIDTH)
    AF.SetPoint(spellInput, "TOPLEFT", assignTargetInput, "BOTTOMLEFT", 0, FIELD_SPACING_LARGE)
    if assignment.spellId then
        spellInput:SetSpell(assignment.spellId, assignment.spellName)
        spellInput:SetCursorPosition(0)
    end

    -- Message input
    local msgInput = AF.CreateEditBox(form, QRA.L["Message (optional)"], FORM_WIDTH, 20)
    AF.SetPoint(msgInput, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, FIELD_SPACING)
    if assignment.message then
        msgInput:SetText(assignment.message)
        msgInput:SetCursorPosition(0)
    end

    -- Target input
    local targetInput = AF.CreateEditBox(form, QRA.L["Target (optional)"], FORM_WIDTH, 20)
    AF.SetPoint(targetInput, "TOPLEFT", msgInput, "BOTTOMLEFT", 0, FIELD_SPACING)
    if assignment.targetPlayer then
        targetInput:SetText(assignment.targetPlayer)
        targetInput:SetCursorPosition(0)
    end
    AF.SetTooltip(targetInput, "TOPLEFT", 0, 2, "Specify a target player name for the spell assignment.\nIf message is provided it overrides specified target.")

    -- Countdown slider
    local countdownSlider = QRA.Widgets.CreateCountdownSlider(form, FORM_WIDTH, 0, 10)
    AF.SetPoint(countdownSlider, "TOPLEFT", targetInput, "BOTTOMLEFT", 0, FIELD_SPACING_LARGE)
    if assignment.countdownTime then
        countdownSlider:SetValue(assignment.countdownTime)
        countdownSlider:SetCursorPosition(0)
    end

    -- Alert type dropdown
    local alertDropdown = QRA.Widgets.CreateAlertTypeDropdown(form, FORM_WIDTH)
    AF.SetPoint(alertDropdown, "TOPLEFT", countdownSlider, "BOTTOMLEFT", 0, FIELD_SPACING_LARGE)
    if assignment.alertType then
        alertDropdown:SetSelectedValue(assignment.alertType)
    end

    -- Activate In input
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], FORM_WIDTH, false)
    AF.SetPoint(activateInInput, "TOPLEFT", alertDropdown, "BOTTOMLEFT", 0, FIELD_SPACING)
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
            activateIn = tonumber(activateInInput:GetValue()),
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

    -- Layout constants
    local FIELD_SPACING = -10
    local SPELL_FIELD_SPACING = -10
    local FORM_WIDTH = 200

    if not triggerEditorFrame then
        triggerEditorFrame = AF.CreateHeaderedFrame(
            QRA.UIParent,
            "QRA_TriggerEditor",
            QRA.L["Trigger Editor"],
            FORM_WIDTH + 20,
            230,
            "HIGH",
            mainFrame:GetFrameLevel() + 10
        )
        AF.SetPoint(triggerEditorFrame, "CENTER", mainFrame, 0, 0)
        table.insert(UISpecialFrames, triggerEditorFrame:GetName())
    end

    -- Update title based on new/edit
    local title = isNew and QRA.L["New Trigger"] or QRA.L["Edit Trigger"]
    triggerEditorFrame:SetTitle(AF.WrapTextInColor(title, "softlime"))

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
    local typeDropdown = QRA.Widgets.CreateTriggerTypeDropdown(form, FORM_WIDTH)
    AF.SetPoint(typeDropdown, "TOPLEFT", 0, 10)
    if trigger.type then
        typeDropdown:SetSelectedValue(trigger.type)
    end
    typeDropdown:SetEnabled(editable)

    -- Name field
    local nameInput = AF.CreateEditBox(form, QRA.L["Name"], FORM_WIDTH, 20)
    nameInput:Hide()
    if trigger.name then
        nameInput:SetText(trigger.name)
        nameInput:SetCursorPosition(0)
    end
    nameInput:SetEnabled(editable)

    -- Spell input (shown for spell-related triggers)
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell ID"], FORM_WIDTH, false)
    spellInput:Hide()
    if trigger.spellId then
        spellInput:SetSpell(trigger.spellId)
        spellInput:SetCursorPosition(0)
    end
    spellInput:SetEnabled(editable)

    -- Timer input (shown for timer triggers)
    local timerInput = AF.CreateEditBox(form, QRA.L["Time (seconds)"], FORM_WIDTH, 20, "number")
    timerInput:Hide()
    if trigger.time then
        timerInput:SetText(tostring(trigger.time))
        timerInput:SetCursorPosition(0)
    end
    timerInput:SetEnabled(editable)

    -- Interval input (shown for timer triggers)
    local intervalInput = AF.CreateEditBox(form, QRA.L["Interval (seconds)"], FORM_WIDTH, 20, "number")
    intervalInput:Hide()
    if trigger.repeatInterval then
        intervalInput:SetText(tostring(trigger.repeatInterval))
        intervalInput:SetCursorPosition(0)
    end
    intervalInput:SetEnabled(editable)

    -- Repeat Count input (shown for timer triggers)
    local repeatCountInput = AF.CreateEditBox(form, QRA.L["Repeat Count"], FORM_WIDTH, 20, "number")
    repeatCountInput:Hide()
    if trigger.repeatCount then
        repeatCountInput:SetText(tostring(trigger.repeatCount))
        repeatCountInput:SetCursorPosition(0)
    end
    repeatCountInput:SetEnabled(editable)

    -- Target GUID input (shown for UNIT_HEALTH and UNIT_DIED triggers)
    local targetGuidInput = QRA.Widgets.CreateTargetGuidInput(form, QRA.L["Target Unit/NPC ID"], FORM_WIDTH, bossInput)
    targetGuidInput:Hide()
    if trigger.targetGuid then
        targetGuidInput:SetText(trigger.targetGuid)
    end
    targetGuidInput:SetCursorPosition(0)
    targetGuidInput:SetEnabled(editable)

    -- HP Thresholds input (shown for UNIT_HEALTH triggers)
    local hpThresholdsInput = QRA.Widgets.CreateHPThresholdsInput(form, QRA.L["HP Thresholds (%)"], FORM_WIDTH)
    hpThresholdsInput:Hide()
    if trigger.hpThresholds then
        hpThresholdsInput:SetText(trigger.hpThresholds)
    end
    hpThresholdsInput:SetCursorPosition(0)
    hpThresholdsInput:SetEnabled(editable)

    -- Counter formula input
    local occSelector = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], FORM_WIDTH)
    QRA.Debug("Setting counter formula to:", trigger.counterFormula, "Type:", type(trigger.counterFormula))
    if trigger.counterFormula then
        occSelector:SetValue(trigger.counterFormula)
    end
    occSelector:Hide()
    occSelector:SetEnabled(editable)

    -- Activate In input
    local activateInInput = QRA.Widgets.CreateActivateInInput(form, QRA.L["Activate In (seconds)"], FORM_WIDTH, true)
    if trigger.activateIn then
        activateInInput:SetValue(trigger.activateIn)
    end
    activateInInput:Hide()
    activateInInput:SetEnabled(editable)

    -- Map field names to UI widgets for registry-based form generation
    -- Include spacing hints for different widget types
    local uiInputs = {
        name = nameInput,
        spell = spellInput,
        time = timerInput,
        interval = intervalInput,
        repeatCount = repeatCountInput,
        targetGuid = targetGuidInput,
        hpThresholds = hpThresholdsInput,
        counter = occSelector,
        activateIn = activateInInput,
    }

    local widgetSpacing = {
        spell = SPELL_FIELD_SPACING,
        default = FIELD_SPACING,
    }

    local function GetWidgetSpacing(fieldName)
        return widgetSpacing[fieldName] or widgetSpacing.default
    end

    local function UpdateInputVisibility()
        local triggerType = typeDropdown:GetSelectedValue()

        for _, widget in pairs(uiInputs) do
            widget:Hide()
            widget:ClearAllPoints()
        end

        local handler = QRA.Triggers.TypeRegistry:GetHandler(triggerType)
        local uiFields = handler and handler.GetUIFields() or {}

        ---@type Frame
        local previousWidget = typeDropdown

        for _, fieldDef in ipairs(uiFields) do
            local widget = uiInputs[fieldDef.name]
            if widget then
                local spacing = GetWidgetSpacing(fieldDef.name)
                AF.SetPoint(widget, "TOPLEFT", previousWidget, "BOTTOMLEFT", 0, spacing)
                widget:Show()
                previousWidget = widget
            end
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

    form.trigger = trigger
    form.isNew = isNew
    form.bossInput = bossInput
    form.editable = editable
    form.uiInputs = uiInputs

    saveBtn:SetOnClick(function()
        local currentTrigger = form.trigger
        local currentIsNew = form.isNew
        local currentBossInput = form.bossInput

        QRA.Debug("Saving trigger from editor for:", currentTrigger, currentBossInput)
        local triggerType = typeDropdown:GetSelectedValue()
        QRA.Debug("Selected trigger type:", triggerType)
        local bossData = QRA.Bosses.GetBossByName(currentBossInput)

        local config = {
            id = currentTrigger.id,
            bossName = currentBossInput,
            encounterId = bossData and bossData.encounterId or nil,
        }

        local typeConfig = QRA.Triggers.TypeRegistry.GetConfigFromUI(triggerType, form.uiInputs)
        for key, value in pairs(typeConfig) do
            config[key] = value
        end

        if not config.counterFormula then
            local counterFormulaValue = occSelector:GetValue()
            config.counterFormula = counterFormulaValue or "*"
        end

        QRA.Debug("Trigger config to save:", config)

        local isValid, errorMessage = QRA.Triggers.TypeRegistry.ValidateConfig(triggerType, config)
        if not isValid then
            QRA.Debug("Invalid trigger configuration:", errorMessage)
            QRA.Print("Validation error: " .. (errorMessage or "Unknown error"))
            return
        end

        local newTrigger = QRA.Triggers.Create(triggerType, config, currentIsNew)

        if not newTrigger then
            QRA.Print("Failed to create trigger")
            return
        end

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
