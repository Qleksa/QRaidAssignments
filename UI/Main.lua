--[[
    QRaidAssignments - Main UI
    Primary user interface for managing triggers and assignments
]]

---@class QRA
local QRA = QRA
QRA.UI = QRA.UI or {}

local AF = _G.AbstractFramework

--------------------------------------------------
-- Constants
--------------------------------------------------
local UI_WIDTH = 700
local UI_HEIGHT = 500
local TAB_HEIGHT = 28
local LIST_ROW_HEIGHT = 28

--------------------------------------------------
-- State
--------------------------------------------------
---@class AF_HeaderedFrame
local mainFrame = nil
local currentTab = "triggers"  -- "triggers", "assignments", "settings"
local selectedBoss = nil  -- Filter triggers by boss
local selectedEncounterId = nil  -- Encounter ID for selected boss

--------------------------------------------------
-- Tab System
--------------------------------------------------

local tabs = {
    { id = "triggers", label = QRA.L["Triggers"] },
    { id = "assignments", label = QRA.L["Assignments"] },
    { id = "settings", label = QRA.L["Settings"] },
}

local tabButtons = {}
local tabContents = {}

--- Switch to a different tab
---@param tabId string The tab to switch to
local function SwitchTab(tabId)
    currentTab = tabId

    -- Update button states
    for id, btn in pairs(tabButtons) do
        if id == tabId then
            btn:SetBackdropBorderColor(AF.GetColorRGB("accent"))
            btn.text:SetTextColor(AF.GetColorRGB("accent"))
        else
            btn:SetBackdropBorderColor(AF.GetColorRGB("gray"))
            btn.text:SetTextColor(AF.GetColorRGB("white"))
        end
    end

    -- Show/hide content
    for id, content in pairs(tabContents) do
        if id == tabId then
            content:Show()
        else
            content:Hide()
        end
    end
end

--- Create the tab bar
---@param parent Frame Parent frame
---@return Frame tabBar
local function CreateTabBar(parent)
    local tabBar = CreateFrame("Frame", nil, parent)
    AF.SetHeight(tabBar, TAB_HEIGHT)
    AF.SetPoint(tabBar, "TOPLEFT", parent, 10, -5)
    AF.SetPoint(tabBar, "TOPRIGHT", parent, -10, -5)

    local tabWidth = (UI_WIDTH - 20 - (#tabs - 1) * 5) / #tabs
    local prevTab = nil

    for i, tabInfo in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        AF.SetSize(btn, tabWidth, TAB_HEIGHT - 4)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        btn:SetBackdropBorderColor(AF.GetColorRGB("gray"))

        if prevTab then
            AF.SetPoint(btn, "LEFT", prevTab, "RIGHT", 5, 0)
        else
            AF.SetPoint(btn, "LEFT", tabBar, 0, 0)
        end

        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        text:SetPoint("CENTER")
        text:SetText(tabInfo.label)
        btn.text = text

        btn:SetScript("OnClick", function()
            SwitchTab(tabInfo.id)
        end)

        btn:SetScript("OnEnter", function(self)
            if currentTab ~= tabInfo.id then
                self:SetBackdropBorderColor(AF.GetColorRGB("accent", 0.5))
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if currentTab ~= tabInfo.id then
                self:SetBackdropBorderColor(AF.GetColorRGB("gray"))
            end
        end)

        tabButtons[tabInfo.id] = btn
        prevTab = btn
    end

    return tabBar
end

--------------------------------------------------
-- Assignments Tab
--------------------------------------------------

local function CreateAssignmentsTab(parent)
    local content = CreateFrame("Frame", nil, parent)
    AF.SetPoint(content, "TOPLEFT", parent, 10, -TAB_HEIGHT - 15)
    AF.SetPoint(content, "BOTTOMRIGHT", parent, -10, 10)

    -- Header
    local header = QRA.Widgets.CreateSectionHeader(content, QRA.L["Raid Assignments"])
    AF.SetPoint(header, "TOPLEFT", content, 0, 0)
    AF.SetPoint(header, "TOPRIGHT", content, 0, 0)

    -- Assignment list frame
    local listFrame = AF.CreateBorderedFrame(content, nil, nil, 200, nil, "white")
    AF.SetPoint(listFrame, "TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(listFrame, "BOTTOMRIGHT", content, 0, 40)

    -- List header row
    local listHeader = CreateFrame("Frame", nil, listFrame)
    AF.SetHeight(listHeader, 20)
    AF.SetPoint(listHeader, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(listHeader, "TOPRIGHT", listFrame, -5, -5)

    local hEnabled = AF.CreateFontString(listHeader, "", "gray")
    AF.SetPoint(hEnabled, "LEFT", 5, 0)
    AF.SetWidth(hEnabled, 25)

    local hSpell = AF.CreateFontString(listHeader, QRA.L["Spell/Action"], "gray")
    AF.SetPoint(hSpell, "LEFT", 33, 0)

    local hAssignTo = AF.CreateFontString(listHeader, QRA.L["Assign To"] or "Assign To", "gray")
    AF.SetPoint(hAssignTo, "LEFT", 185, 0)

    local hTrigger = AF.CreateFontString(listHeader, QRA.L["Trigger"], "gray")
    AF.SetPoint(hTrigger, "LEFT", 267, 0)

    local hCountdown = AF.CreateFontString(listHeader, QRA.L["CD"], "gray")
    AF.SetPoint(hCountdown, "RIGHT", -35, 0)
    AF.SetWidth(hCountdown, 30)

    -- Scroll list for assignments
    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 8, LIST_ROW_HEIGHT, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listHeader, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 8)
    content.scrollList = scrollList

    -- Refresh function
    function content:RefreshAssignments()
        local widgets = {}
        local assignments = QRA.Assignments.GetAsList()

        for i, assignment in ipairs(assignments) do
            local row = QRA.Widgets.CreateAssignmentRow(
                scrollList.slotFrame,
                assignment,
                function(a) QRA.UI.ShowAssignmentEditor(a) end,
                function(a)
                    QRA.Assignments.Remove(a.id)
                    self:RefreshAssignments()
                end
            )

            -- Zebra striping
            if i % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end

            table.insert(widgets, row)
        end

        scrollList:SetWidgets(widgets)
    end

    -- Add Assignment button
    local addBtn = AF.CreateButton(content, QRA.L["+ Add Assignment"], "softlime", 150, 26)
    AF.SetPoint(addBtn, "TOPLEFT", listFrame, "BOTTOMLEFT", 0, -8)
    addBtn:SetOnClick(function()
        QRA.UI.ShowAssignmentEditor()
    end)

    -- Quick test button
    local testBtn = AF.CreateButton(content, QRA.L["Test Alert"], "static", 100, 26)
    AF.SetPoint(testBtn, "LEFT", addBtn, "RIGHT", 10, 0)
    testBtn:SetOnClick(function()
        QRA.Notifications.TestCountdown()
    end)

    -- Roster Manager button
    local rosterBtn = AF.CreateButton(content, QRA.L["Roster"], "static", 80, 26)
    AF.SetPoint(rosterBtn, "LEFT", testBtn, "RIGHT", 10, 0)
    AF.SetTooltip(rosterBtn, "TOPLEFT", 0, 2, "Roster Manager", "Save current raid roster for planning", "assignments when not in raid")
    rosterBtn:SetOnClick(function()
        QRA.AssignTargetMenu.ShowRosterManager(parent)
    end)

    return content
end

--------------------------------------------------
-- Triggers Tab
--------------------------------------------------

local function CreateTriggersTab(parent)
    local content = CreateFrame("Frame", nil, parent)
    AF.SetPoint(content, "TOPLEFT", parent, 10, -TAB_HEIGHT - 15)
    AF.SetPoint(content, "BOTTOMRIGHT", parent, -10, 10)

    -- Top bar
    local topBar = CreateFrame("Frame", nil, content)
    AF.SetHeight(topBar, 24)
    AF.SetPoint(topBar, "TOPLEFT", content, 0, 0)
    AF.SetPoint(topBar, "TOPRIGHT", content, 0, 0)

    -- Boss filter dropdown
    local bossDropdown = QRA.Widgets.CreateBossMenu(topBar, 150, function(self, item)
        selectedBoss = item.text
        selectedEncounterId = item.encounterId
        QRA.Debug("Selected boss:", selectedBoss, "encounterId:", selectedEncounterId)
        content:SetButtonState()
        content:RefreshTriggers()
    end)
    AF.SetPoint(bossDropdown, "LEFT", topBar, 0, -10)
    content.bossDropdown = bossDropdown

    -- Export button
    local exportBtn = AF.CreateButton(content, QRA.L["Export"], "softlime", 80, 26)
    AF.SetPoint(exportBtn, "LEFT", bossDropdown, "RIGHT", 10, 0)
    exportBtn:SetOnClick(function()
        local exportString = selectedEncounterId and QRA.Comm.ExportBoss(selectedEncounterId) or QRA.Comm.Export()
        if exportString and exportString ~= "" then
            QRA.UI.ShowExportFrame(exportString)
        end
    end)

    -- Import button
    local importBtn = AF.CreateButton(content, QRA.L["Import"], "softblue", 80, 26)
    AF.SetPoint(importBtn, "LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetOnClick(function()
        QRA.UI.ShowImportFrame(function(input)
            QRA.Comm.Import(input, false)
        end)
    end)

    -- Test Mode button
    local testModeBtn = AF.CreateButton(content, QRA.L["Test Mode"], "purple", 100, 26)
    AF.SetPoint(testModeBtn, "TOPRIGHT", topBar, "RIGHT", 0, 5)
    testModeBtn:SetOnClick(function()
        if QRA.DevMode then
            if not QRA.DevMode.IsActive() then
                QRA.DevMode.Enable(selectedBoss, selectedEncounterId)
            end
            if QRA.DevMode.UI and QRA.DevMode.UI.ShowTestPanel then
                -- Pass the selected boss to the test panel
                if selectedBoss then
                    QRA.DevMode.UI.SetSelectedBoss(selectedBoss, selectedEncounterId)
                end
                QRA.DevMode.UI.ShowTestPanel()
            end
        end
    end)

    -- Templates button
    -- local templatesBtn = AF.CreateButton(topBar, QRA.L["Templates"], "static", 100, 24)
    -- AF.SetPoint(templatesBtn, "RIGHT", topBar, 0, 0)
    -- templatesBtn:SetOnClick(function()
    --     QRA.UI.ShowTemplatesPopup()
    -- end)

    -- Trigger list frame
    local listFrame = AF.CreateBorderedFrame(content, nil, nil, 200, nil, "gray")
    AF.SetPoint(listFrame, "TOPLEFT", topBar, "BOTTOMLEFT", 0, -35)
    AF.SetPoint(listFrame, "BOTTOMRIGHT", content, 0, 40)

    -- List header row
    local listHeader = CreateFrame("Frame", nil, listFrame)
    AF.SetHeight(listHeader, 20)
    AF.SetPoint(listHeader, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(listHeader, "TOPRIGHT", listFrame, -5, -5)

    -- local hType = AF.CreateFontString(listHeader, QRA.L["Type"], "gray")
    -- AF.SetPoint(hType, "LEFT", 30, 0)

    local hDetails = AF.CreateFontString(listHeader, QRA.L["Details"], "gray")
    AF.SetPoint(hDetails, "LEFT", 55, 0)

    local hOcc = AF.CreateFontString(listHeader, QRA.L["#"], "gray")
    AF.SetPoint(hOcc, "RIGHT", -30, 0)
    AF.SetWidth(hOcc, 40)

    -- Scroll list for triggers
    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 8, LIST_ROW_HEIGHT, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listHeader, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 8)
    content.scrollList = scrollList

    -- Refresh function
    function content:RefreshTriggers()
        local widgets = {}
        local triggers = QRA.Triggers.GetBossTriggers(selectedBoss)
        local i = 0

        for _, trigger in pairs(triggers) do
            i = i + 1
            local row = QRA.Widgets.CreateTriggerRow(
                scrollList.slotFrame,
                trigger,
                function(t) QRA.UI.ShowTriggerEditor(t, selectedBoss) end,
                function(t)
                    QRA.Debug("Deleting trigger", t.id)
                    QRA.Triggers.Unregister(t.id)
                    QRA.Triggers.DeleteTrigger(t.id)
                    self:RefreshTriggers()
                end
            )

            -- Zebra striping
            if i % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end

            table.insert(widgets, row)
        end

        scrollList:SetWidgets(widgets)

        -- Refresh boss dropdown items
        if bossDropdown.RefreshBosses then
            bossDropdown:RefreshBosses()
        end
    end

    -- Add Trigger button
    local addBtn = AF.CreateButton(content, QRA.L["+ Add Trigger"], "softlime", 150, 26)
    AF.SetPoint(addBtn, "TOPLEFT", listFrame, "BOTTOMLEFT", 0, -8)
    addBtn:SetEnabled(selectedBoss ~= nil)
    addBtn:SetOnClick(function()
        QRA.UI.ShowTriggerEditor(nil, selectedBoss)
    end)

    -- Send to Raid button
    local sendToRaidBtn = AF.CreateButton(content, QRA.L["Send to Raid"], "softblue", 120, 26)
    AF.SetPoint(sendToRaidBtn, "LEFT", addBtn, "RIGHT", 10, 0)
    sendToRaidBtn:SetOnClick(function()
        local exportString = selectedEncounterId and QRA.Comm.ExportBoss(selectedEncounterId, true) or QRA.Comm.Export(true)
        if exportString and exportString ~= "" then
            QRA.Comm.SendToRaid(exportString)
        end
    end)

    function content:SetButtonState()
        if addBtn then addBtn:SetEnabled(selectedBoss ~= nil) end
    end

    return content
end

--------------------------------------------------
-- Templates Popup
--------------------------------------------------

--- Show a popup dialog for managing templates
function QRA.UI.ShowTemplatesPopup()
    local form = CreateFrame("Frame", nil, mainFrame)
    AF.SetWidth(form, 350)
    AF.SetHeight(form, 280)

    -- Template list scroll frame
    local listFrame = AF.CreateBorderedFrame(form, nil, nil, 200, nil, "gray")
    AF.SetPoint(listFrame, "TOPLEFT", form, 0, 0)
    AF.SetPoint(listFrame, "TOPRIGHT", form, 0, 0)
    AF.SetHeight(listFrame, 200)

    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 8, 40, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 8)

    local function RefreshTemplates()
        local widgets = {}
        local templates = QRA.Templates.GetAsList()

        for i, template in ipairs(templates) do
            local row = CreateFrame("Frame", nil, scrollList.slotFrame)
            AF.SetHeight(row, 36)
            AF.SetPoint(row, "LEFT")
            AF.SetPoint(row, "RIGHT")

            -- Template name
            local nameFS = AF.CreateFontString(row, template.name, "white")
            AF.SetPoint(nameFS, "TOPLEFT", 10, -5)
            AF.SetPoint(nameFS, "TOPRIGHT", row, -100, -5)
            nameFS:SetJustifyH("LEFT")

            -- Info (trigger/assignment count)
            local infoText = string.format("%d %s, %d %s",
                #template.triggers, QRA.L["triggers"],
                #template.assignments, QRA.L["assignments"]
            )
            local infoFS = AF.CreateFontString(row, infoText, "gray")
            AF.SetPoint(infoFS, "TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2)

            -- Apply button
            local applyBtn = AF.CreateButton(row, QRA.L["Apply"], "accent", 50, 22)
            AF.SetPoint(applyBtn, "RIGHT", row, -45, 0)
            applyBtn:SetOnClick(function()
                QRA.Templates.Apply(template.id, true)
                QRA.UI.RefreshAll()
                QRA.Print(QRA.L["Template applied:"], template.name)
            end)

            -- Delete icon
            local delBtn = AF.CreateButton(row, "×", "red", 22, 22)
            AF.SetPoint(delBtn, "RIGHT", row, -10, 0)
            delBtn:SetOnClick(function()
                QRA.Templates.Delete(template.id)
                RefreshTemplates()
            end)

            -- Zebra striping
            if i % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end

            table.insert(widgets, row)
        end

        scrollList:SetWidgets(widgets)
    end

    RefreshTemplates()

    -- Save Current as Template button
    local saveBtn = AF.CreateButton(form, QRA.L["Save Current as Template"], "accent", 200, 26)
    AF.SetPoint(saveBtn, "TOPLEFT", listFrame, "BOTTOMLEFT", 0, -8)
    saveBtn:SetOnClick(function()
        QRA.UI.ShowTemplateNameDialog(function(name)
            local triggerIds = {}
            for id, _ in pairs(QRA.Triggers.GetAll()) do
                table.insert(triggerIds, id)
            end
            local template = QRA.Templates.CreateFromCurrent(name, triggerIds)
            QRA.Templates.Save(template)
            RefreshTemplates()
        end)
    end)

    -- Show popup dialog
    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(QRA.L["Manage Templates"], "accent"), 370)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 250)
end

--------------------------------------------------
-- Settings Tab
--------------------------------------------------

local function CreateSettingsTab(parent)
    local content = CreateFrame("Frame", nil, parent)
    AF.SetPoint(content, "TOPLEFT", parent, 10, -TAB_HEIGHT - 15)
    AF.SetPoint(content, "BOTTOMRIGHT", parent, -10, 10)

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
    AF.SetPoint(testHeader, "TOPLEFT", chatCheck, "BOTTOMLEFT", -10, -25)
    AF.SetPoint(testHeader, "TOPRIGHT", content, 0, 0)

    local testTTSBtn = AF.CreateButton(content, QRA.L["Test TTS"], "static", 100, 24)
    AF.SetPoint(testTTSBtn, "TOPLEFT", testHeader, "BOTTOMLEFT", 10, -10)
    testTTSBtn:SetOnClick(QRA.Notifications.TestTTS)

    local testSoundBtn = AF.CreateButton(content, QRA.L["Test Sound"], "static", 100, 24)
    AF.SetPoint(testSoundBtn, "LEFT", testTTSBtn, "RIGHT", 10, 0)
    testSoundBtn:SetOnClick(QRA.Notifications.TestSound)

    local testScreenBtn = AF.CreateButton(content, QRA.L["Test Screen"], "static", 100, 24)
    AF.SetPoint(testScreenBtn, "LEFT", testSoundBtn, "RIGHT", 10, 0)
    testScreenBtn:SetOnClick(QRA.Notifications.TestScreen)

    local testCountdownBtn = AF.CreateButton(content, QRA.L["Test Countdown"], "static", 120, 24)
    AF.SetPoint(testCountdownBtn, "LEFT", testScreenBtn, "RIGHT", 10, 0)
    testCountdownBtn:SetOnClick(QRA.Notifications.TestCountdown)

    -- Debug section
    local debugHeader = QRA.Widgets.CreateSectionHeader(content, QRA.L["Debug"])
    AF.SetPoint(debugHeader, "TOPLEFT", testTTSBtn, "BOTTOMLEFT", -10, -25)
    AF.SetPoint(debugHeader, "TOPRIGHT", content, 0, 0)


    local debugCheck = AF.CreateCheckButton(content, QRA.L["Enable Debug Mode"], function(checked)
        QRA.Settings.debug = checked
        if AFConfig then
            AFConfig.debug[QRA.name] = checked
        end
    end)
    AF.SetPoint(debugCheck, "TOPLEFT", debugHeader, "BOTTOMLEFT", 10, -10)
    debugCheck:SetChecked(QRA.Settings.debug)

    return content
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

    -- Create tab bar
    local tabBar = CreateTabBar(mainFrame)

    -- Test Mode indicator (shown when DevMode is active)
    local testModeIndicator = AF.CreateFontString(mainFrame, QRA.L["TEST MODE"], "purple")
    testModeIndicator:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    AF.SetPoint(testModeIndicator, "BOTTOMRIGHT", mainFrame, -24, 4)
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

    -- Create tab contents
    tabContents["triggers"] = CreateTriggersTab(mainFrame)
    tabContents["assignments"] = CreateAssignmentsTab(mainFrame)
    tabContents["settings"] = CreateSettingsTab(mainFrame)

    -- Initialize to triggers tab
    SwitchTab("triggers")

    -- Refresh data when shown
    mainFrame:SetScript("OnShow", function()
        if tabContents["triggers"] and tabContents["triggers"].RefreshTriggers then
            tabContents["triggers"]:RefreshTriggers()
        end
        if tabContents["assignments"] and tabContents["assignments"].RefreshAssignments then
            tabContents["assignments"]:RefreshAssignments()
        end
        -- Update test mode indicator
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
    if tabContents["assignments"] and tabContents["assignments"].RefreshAssignments then
        tabContents["assignments"]:RefreshAssignments()
    end
    if tabContents["triggers"] and tabContents["triggers"].RefreshTriggers then
        tabContents["triggers"]:RefreshTriggers()
    end
end

--------------------------------------------------
-- Editor Dialogs
--------------------------------------------------

--- Show the assignment editor dialog
---@param assignment table|nil Existing assignment to edit, or nil for new
function QRA.UI.ShowAssignmentEditor(assignment)
    local isNew = assignment == nil
    assignment = assignment or {}

    local form = CreateFrame("Frame", nil, mainFrame)

    -- Trigger dropdown (link to a trigger)
    local triggerDropdown = QRA.Widgets.CreateTriggerDropdown(form, 200)
    AF.SetPoint(triggerDropdown, "TOPLEFT", 0, -15)
    if assignment.triggerId then
        triggerDropdown:SetSelectedValue(assignment.triggerId)
    end

    -- Assign Target menu (who receives this assignment)
    local assignTargetMenu = QRA.AssignTargetMenu.CreateMenuButton(form, 200)
    AF.SetPoint(assignTargetMenu, "TOPLEFT", triggerDropdown, "BOTTOMLEFT", 0, -30)
    if assignment.assignTarget then
        assignTargetMenu:SetSelectedTarget(assignment.assignTarget)
    else
        assignTargetMenu:SetSelectedTarget("ALL")
    end

    -- Spell input
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell"], 200)
    AF.SetPoint(spellInput, "TOPLEFT", assignTargetMenu, "BOTTOMLEFT", 0, -35)
    if assignment.spellId then
        spellInput:SetSpell(assignment.spellId)
        spellInput:SetCursorPosition(0)
    end

    -- Message input
    local msgInput = AF.CreateEditBox(form, QRA.L["Message (optional)"], 200, 20)
    AF.SetPoint(msgInput, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, -15)
    if assignment.message then
        msgInput:SetText(assignment.message)
        msgInput:SetCursorPosition(0)
    end

    -- Countdown slider
    local countdownSlider = QRA.Widgets.CreateCountdownSlider(form, 200, 0, 30)
    AF.SetPoint(countdownSlider, "TOPLEFT", msgInput, "BOTTOMLEFT", 0, -25)
    countdownSlider:SetValue(assignment.countdownTime or 5)

    -- Alert type dropdown
    local alertDropdown = QRA.Widgets.CreateAlertTypeDropdown(form, 200)
    AF.SetPoint(alertDropdown, "TOPLEFT", countdownSlider, "BOTTOMLEFT", 0, -30)
    if assignment.alertType then
        alertDropdown:SetSelectedValue(assignment.alertType)
    end

    -- Show dialog using AF.GetDialog pattern
    local title = isNew and QRA.L["New Assignment"] or QRA.L["Edit Assignment"]
    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(title, "accent"), 220)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 280)
    dialog:SetToCustom("Save", "Cancel", 60)
    -- dialog:EnableYes(EnableYesButton())
    dialog:SetOnConfirm(function()
        local spellData = spellInput:GetSpell()
        local message = nil
        if msgInput:GetText() ~= "" then
            message = msgInput:GetText()
        end

        local newAssignment = QRA.Assignments.Create({
            triggerId = triggerDropdown:GetSelectedValue(),
            assignTarget = assignTargetMenu:GetSelectedTarget() or "ALL",
            spellId = spellData.spellId,
            spellName = spellData.spellName or nil,
            message = message,
            countdownTime = countdownSlider:GetValue(),
            alertType = alertDropdown:GetSelectedValue(),
        })

        if isNew then
            QRA.Assignments.Add(newAssignment)
        else
            QRA.Assignments.Update(assignment.id, {
                triggerId = newAssignment.triggerId,
                assignTarget = newAssignment.assignTarget,
                spellId = newAssignment.spellId,
                spellName = newAssignment.spellName,
                message = newAssignment.message,
                countdownTime = newAssignment.countdownTime,
                alertType = newAssignment.alertType,
            })
        end

        QRA.UI.RefreshAll()
    end)
end

--- Show the trigger editor dialog
---@param trigger table|nil Existing trigger to edit, or nil for new
---@param bossInput string|nil Boss name to associate the trigger with
function QRA.UI.ShowTriggerEditor(trigger, bossInput)
    QRA.Debug("Opening Trigger Editor: ", trigger, bossInput)
    local isNew = trigger == nil
    trigger = trigger or {}

    local form = CreateFrame("Frame", 'QRA_TriggerEditor', mainFrame)

    -- Trigger type dropdown
    local typeDropdown = QRA.Widgets.CreateTriggerTypeDropdown(form, 200)
    AF.SetPoint(typeDropdown, "TOPLEFT", 0, -20)
    if trigger.type then
        typeDropdown:SetSelectedValue(trigger.type)
    end

    -- Spell input (shown for spell-related triggers)
    local spellInput = QRA.Widgets.CreateSpellInput(form, QRA.L["Spell ID"], 200)
    AF.SetPoint(spellInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    spellInput:Hide()
    if trigger.spellId then
        spellInput:SetSpell(trigger.spellId)
        spellInput:SetCursorPosition(0)
    end

    -- Timer input (shown for timer triggers)
    local timerInput = AF.CreateEditBox(form, QRA.L["Time (seconds)"], 200, 20, "number")
    AF.SetPoint(timerInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    timerInput:Hide()
    if trigger.time then
        timerInput:SetText(tostring(trigger.time))
        timerInput:SetCursorPosition(0)
    end

    -- NPC ID input (shown for NPC death triggers)
    local npcInput = AF.CreateEditBox(form, QRA.L["NPC ID"], 200, 20, "number")
    AF.SetPoint(npcInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    npcInput:Hide()
    if trigger.npcId then
        npcInput:SetText(tostring(trigger.npcId))
    end
    npcInput:SetCursorPosition(0)

    -- Target GUID input (shown for UNIT_HEALTH triggers)
    local targetGuidInput = QRA.Widgets.CreateTargetGuidInput(form, QRA.L["Target Unit/NPC ID"], 200)
    AF.SetPoint(targetGuidInput, "TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -35)
    targetGuidInput:Hide()
    if trigger.targetGuid then
        targetGuidInput:SetText(trigger.targetGuid)
    end
    targetGuidInput:SetCursorPosition(0)

    -- HP Thresholds input (shown for UNIT_HEALTH triggers)
    local hpThresholdsInput = QRA.Widgets.CreateHPThresholdsInput(form, QRA.L["HP Thresholds (%)"], 200)
    AF.SetPoint(hpThresholdsInput, "TOPLEFT", targetGuidInput, "BOTTOMLEFT", 0, -10)
    hpThresholdsInput:Hide()
    if trigger.hpThresholds then
        hpThresholdsInput:SetText(trigger.hpThresholds)
    end
    hpThresholdsInput:SetCursorPosition(0)

    -- Counter formula input
    local occSelector = QRA.Widgets.CreateCounterInput(form, QRA.L["Counter"], 194)
    AF.SetPoint(occSelector, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, -5)
    QRA.Debug("Setting counter formula to:", trigger.counterFormula, "Type:", type(trigger.counterFormula))
    if trigger.counterFormula then
        occSelector:SetValue(trigger.counterFormula)
        QRA.Debug("After SetValue, text is:", occSelector:GetValue())
    else
        QRA.Debug("No counter formula provided, using default")
    end
    occSelector:Hide()

    -- Update visibility based on trigger type
    local function UpdateInputVisibility()
        local triggerType = typeDropdown:GetSelectedValue()
        spellInput:Hide()
        timerInput:Hide()
        npcInput:Hide()
        targetGuidInput:Hide()
        hpThresholdsInput:Hide()
        occSelector:Hide()

        if triggerType == QRA.Triggers.Types.SPELL_CAST_SUCCESS.event or
           triggerType == QRA.Triggers.Types.SPELL_CAST_START.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_APPLIED.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_REMOVED.event then
            spellInput:Show()
            occSelector:Show()
        elseif triggerType == QRA.Triggers.Types.TIMER.event then
            timerInput:Show()
        elseif triggerType == QRA.Triggers.Types.NPC_DEATH.event then
            npcInput:Show()
            occSelector:Show()
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            targetGuidInput:Show()
            hpThresholdsInput:Show()
        end
    end

    typeDropdown:SetOnSelect(function()
        UpdateInputVisibility()
    end)
    UpdateInputVisibility()

    -- Show dialog using AF.GetDialog pattern
    local title = isNew and QRA.L["New Trigger"] or QRA.L["Edit Trigger"]
    local dialog = AF.GetDialog(mainFrame, AF.WrapTextInColor(title, "accent"), 220)
    AF.SetPoint(dialog, "CENTER", mainFrame, 0, 0)
    dialog:SetContent(form, 250)
    dialog:SetToCustom("Save", "Cancel", 60)
    dialog:SetOnConfirm(function()
        QRA.Debug("Saving trigger from editor for:", trigger, bossInput)
        local triggerType = typeDropdown:GetSelectedValue()
        QRA.Debug("Selected trigger type:", triggerType)
        local bossData = QRA.Bosses.GetBossByName(bossInput)
        local counterFormulaValue = occSelector:GetValue()
        QRA.Debug("Counter formula from UI:", counterFormulaValue, type(counterFormulaValue))
        local config = {
            id = trigger.id,
            counterFormula = counterFormulaValue or "*",
            bossName = bossInput,
            encounterId = bossData and bossData.encounterId or nil,
        }

        if triggerType == QRA.Triggers.Types.SPELL_CAST_SUCCESS.event or
           triggerType == QRA.Triggers.Types.SPELL_CAST_START.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_APPLIED.event or
           triggerType == QRA.Triggers.Types.SPELL_AURA_REMOVED.event then
            local spellData = spellInput:GetSpell()
            QRA.Debug("Selected spell:", spellData)
            config.spellId = spellData.spellId
            config.spellName = spellData.spellName
        elseif triggerType == QRA.Triggers.Types.TIMER.event then
            config.time = tonumber(timerInput:GetText()) or 0
            config.counterFormula = "1"
        elseif triggerType == QRA.Triggers.Types.NPC_DEATH.event then
            config.npcId = tonumber(npcInput:GetText())
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            config.targetGuid = strtrim(targetGuidInput:GetText())
            config.hpThresholds = strtrim(hpThresholdsInput:GetText())
        end

        QRA.Debug("Trigger config to save:", config)

        -- Validation
        local isValid = true
        if triggerType == QRA.Triggers.Types.TIMER.event and (config.time == nil or config.time <= 0) then
            isValid = false
        elseif triggerType == QRA.Triggers.Types.UNIT_HEALTH.event then
            if not targetGuidInput:IsValid() or not hpThresholdsInput:IsValid() then
                isValid = false
            end
        end

        if not isValid then
            QRA.Debug("Invalid trigger configuration, aborting save")
            return
        end


        local newTrigger = QRA.Triggers.Create(triggerType, config, isNew)

        if isNew then
            QRA.Triggers.SaveTrigger(newTrigger)
        else
            -- Update existing trigger
            QRA.Triggers.UpdateTrigger(newTrigger)
        end

        QRA.UI.RefreshAll()
    end)
end

--- Show template name input dialog
---@param onConfirm function Callback with template name
function QRA.UI.ShowTemplateNameDialog(onConfirm)
    local form = CreateFrame("Frame", nil, mainFrame)

    local nameInput = AF.CreateEditBox(form, QRA.L["Template Name"], 200, 20)
    AF.SetPoint(nameInput, "TOPLEFT", 0, 0)
    nameInput:SetText("New Template")

    -- Show dialog using AF.GetDialog pattern
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

    -- Auto close on Ctrl+C or ESC
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
            AF.DelayedInvoke(0.2, function() ctrlDown = false end)
        end
        if ctrlDown and key == "C" then
            AF.DelayedInvoke(0.1, function() exportFrame:Hide() end)
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
