--[[
    QRaidAssignments - Main UI
    Primary user interface for managing triggers and assignments
    Hierarchical tree view: Instance → Boss → Trigger → Assignments
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA_UI
QRA.UI = QRA.UI or {}

--------------------------------------------------
-- Constants
--------------------------------------------------
local UI_WIDTH = 750
local UI_HEIGHT = 550

--------------------------------------------------
-- State
--------------------------------------------------
---@class AF_HeaderedFrame
local mainFrame = nil
local selectedBoss = nil
local selectedEncounterId = nil
local selectedPlanId = nil
local selectedPlanVersion = nil

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

    local settingsBtn = AF.CreateIconButton(mainFrame, AF.GetIcon("Settings"), 24, 24, 2, "gray", "softlime", "TRILINEAR")
    AF.SetPoint(settingsBtn, "TOPRIGHT", mainFrame, -5, -5)
    AF.SetTooltip(settingsBtn, "ANCHOR_LEFT", 0, 0, QRA.L["Settings"])
    settingsBtn:SetOnClick(function()
        QRA.UI.Settings.ShowSettingsPanel(mainFrame)
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, mainFrame)
    AF.SetPoint(content, "TOPLEFT", mainFrame, 10, -15)
    AF.SetPoint(content, "BOTTOMRIGHT", mainFrame, -10, 5)

    --------------------------------------------------
    -- Top Bar
    --------------------------------------------------
    local topBar = CreateFrame("Frame", nil, content)
    AF.SetHeight(topBar, 64)
    AF.SetPoint(topBar, "TOPLEFT", content, 0, 0)
    AF.SetPoint(topBar, "TOPRIGHT", content, 0, 0)

    local planBar = CreateFrame("Frame", nil, topBar)
    AF.SetHeight(planBar, 30)
    AF.SetPoint(planBar, "TOPLEFT", topBar, 0, 0)
    AF.SetPoint(planBar, "TOPRIGHT", topBar, 0, 0)

    local filterBar = CreateFrame("Frame", nil, topBar)
    AF.SetHeight(filterBar, 30)
    AF.SetPoint(filterBar, "TOPLEFT", planBar, "BOTTOMLEFT", 0, -8)
    AF.SetPoint(filterBar, "TOPRIGHT", planBar, "BOTTOMRIGHT", 0, -4)

    local bossDropdown = nil
    local planDropdown = nil
    local setActiveVersionBtn = nil
    local deletePlanBtn = nil

    local function GetSelectedPlan()
        if selectedPlanId then
            return QRA.Plans.Get(selectedPlanId)
        end
        return QRA.Plans.GetSelectedPlan()
    end

    local function UpdateSetActiveButtonState()
        if not setActiveVersionBtn then return end
        local plan = GetSelectedPlan()
        if not plan then
            setActiveVersionBtn:SetEnabled(false)
            if deletePlanBtn then
                deletePlanBtn:SetEnabled(false)
            end
            return
        end

        if deletePlanBtn then
            local canDelete = not (plan.isPersonal and #plan.versions <= 1)
            deletePlanBtn:SetEnabled(canDelete)
        end

        if plan.isPersonal then
            setActiveVersionBtn:SetEnabled(plan.activeVersion ~= selectedPlanVersion)
            return
        end

        local activePlanId, activeVersion = QRA.Plans.GetActiveVersionSelection()
        local isSelectedActive = activePlanId == selectedPlanId and activeVersion == selectedPlanVersion
        setActiveVersionBtn:SetEnabled(not isSelectedActive)
    end

    local function ApplyPlanSelection(planId, version)
        if not planId then return end
        if not QRA.Plans.SetSelected(planId, version) then
            return
        end

        selectedPlanId = planId
        selectedPlanVersion = QRA.Plans.GetSelectedVersion()

        local plan = GetSelectedPlan()
        if bossDropdown and bossDropdown.RefreshItems then
            bossDropdown:RefreshItems(QRA.Plans.GetEffectiveInstanceName(plan))
        end

        selectedBoss = nil
        selectedEncounterId = nil

        if bossDropdown then
            bossDropdown:SetText(QRA.L["All Bosses"])
        end

        if planDropdown then
            planDropdown:RefreshItems()
            planDropdown:SetSelected(selectedPlanId, selectedPlanVersion)
        end

        UpdateSetActiveButtonState()
    end

    function QRA.UI.SetPlanSelection(planId, version)
        ApplyPlanSelection(planId, version)
    end

    planDropdown = QRA.Widgets.CreatePlanMenu(planBar, 240, function(planId, version)
        ApplyPlanSelection(planId, version)
        QRA.UI.RefreshTree()
    end)
    AF.SetPoint(planDropdown, "LEFT", planBar, 0, 0)

    setActiveVersionBtn = AF.CreateButton(planBar, QRA.L["Set Active"], "static", 78, 26)
    AF.SetPoint(setActiveVersionBtn, "LEFT", planDropdown, "RIGHT", 5, 0)
    setActiveVersionBtn:SetOnClick(function()
        if selectedPlanId and selectedPlanVersion then
            local selectedPlan = GetSelectedPlan()
            if selectedPlan and selectedPlan.isPersonal and selectedPlan.activeVersion ~= selectedPlanVersion then
                QRA.Plans.SetSelected(selectedPlanId, selectedPlanVersion)
            end

            if QRA.Plans.SetActiveVersion(selectedPlanId, selectedPlanVersion) then
                UpdateSetActiveButtonState()
                if planDropdown then
                    planDropdown:RefreshItems()
                    planDropdown:SetSelected(selectedPlanId, selectedPlanVersion)
                end
                QRA.UI.RefreshTree()
            end
        end
    end)

    deletePlanBtn = AF.CreateButton(planBar, QRA.L["Delete"], "red", 62, 26)
    AF.SetPoint(deletePlanBtn, "LEFT", setActiveVersionBtn, "RIGHT", 5, 0)
    deletePlanBtn:SetOnClick(function()
        if not selectedPlanId or not selectedPlanVersion then
            return
        end

        QRA.UI.Dialogs.ShowDeletePlanOrVersionDialog(selectedPlanId, selectedPlanVersion, function()
            QRA.UI.RefreshTree()
        end)
    end)

    -- LEFT GROUP: Boss filter and tree controls
    -- Boss filter dropdown
    bossDropdown = QRA.Widgets.CreateBossMenu(filterBar, 160, function(self, item)
        selectedBoss = item.text
        selectedEncounterId = item.encounterId
        QRA.Debug("Selected boss:", selectedBoss, "encounterId:", selectedEncounterId)
        QRA.UI.RefreshTree()
    end, function()
        local plan = GetSelectedPlan()
        return QRA.Plans.GetEffectiveInstanceName(plan)
    end)
    AF.SetPoint(bossDropdown, "LEFT", filterBar, 0, 0)

    -- Show All button
    local showAllBtn = AF.CreateButton(filterBar, "All", "static", 30, 26)
    AF.SetPoint(showAllBtn, "LEFT", bossDropdown, "RIGHT", 5, 0)
    AF.SetTooltip(showAllBtn, "ANCHOR_BOTTOM", 0, 0, QRA.L["All Bosses"])
    showAllBtn:SetOnClick(function()
        selectedBoss = nil
        selectedEncounterId = nil
        bossDropdown:SetText(QRA.L["All Bosses"])
        QRA.UI.RefreshTree()
    end)

    -- Separator
    local sep1 = filterBar:CreateTexture(nil, "ARTWORK")
    sep1:SetSize(1, 20)
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    AF.SetPoint(sep1, "LEFT", showAllBtn, "RIGHT", 8, 0)

    -- Expand/Collapse buttons
    local expandBtn = QRA.UI.Tree.CreateExpandButton(filterBar)
    AF.SetPoint(expandBtn, "LEFT", sep1, "RIGHT", 8, 0)

    local collapseBtn = QRA.UI.Tree.CreateCollapseButton(filterBar)
    AF.SetPoint(collapseBtn, "LEFT", expandBtn, "RIGHT", 2, 0)

    -- CENTER GROUP: Import/Export
    local sep2 = filterBar:CreateTexture(nil, "ARTWORK")
    sep2:SetSize(1, 20)
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    AF.SetPoint(sep2, "LEFT", collapseBtn, "RIGHT", 10, 0)

    local importBtn = AF.CreateButton(filterBar, QRA.L["Import"], "softblue", 60, 26)
    AF.SetPoint(importBtn, "LEFT", sep2, "RIGHT", 10, 0)
    importBtn:SetOnClick(function()
        QRA.UI.Dialogs.ShowImportFrame(function(input)
            QRA.Comm.Import(input, false)
            QRA.UI.RefreshTree()
        end)
    end)

    local exportBtn = AF.CreateButton(filterBar, QRA.L["Export"], "softlime", 60, 26)
    AF.SetPoint(exportBtn, "LEFT", importBtn, "RIGHT", 5, 0)
    exportBtn:SetOnClick(function()
        local exportString = QRA.Comm.Export()
        if exportString and exportString ~= "" then
            QRA.UI.Dialogs.ShowExportFrame(exportString)
        end
    end)

    local deleteAllBtn = AF.CreateButton(filterBar, QRA.L["Delete All Data"], "red", 128, 26)
    AF.SetPoint(deleteAllBtn, "LEFT", exportBtn, "RIGHT", 5, 0)
    AF.SetTooltip(deleteAllBtn, "ANCHOR_BOTTOM", 0, 0, QRA.L["Delete All Data"])
    deleteAllBtn:SetOnClick(function()
        QRA.UI.Dialogs.ShowDeleteAllDataDialog(function()
            QRA.UI.RefreshTree()
        end)
    end)

    -- RIGHT GROUP
    -- Test Mode button
    local testModeBtn = AF.CreateButton(filterBar, "Test", "purple", 50, 26)
    AF.SetPoint(testModeBtn, "RIGHT", filterBar, 0, 0)
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

    local initialPlan = QRA.Plans.GetSelectedPlan()
    if initialPlan then
        selectedPlanId = initialPlan.id
        selectedPlanVersion = QRA.Plans.GetSelectedVersion()
        ApplyPlanSelection(selectedPlanId, selectedPlanVersion)
    else
        selectedPlanId = nil
        selectedPlanVersion = nil
    end

    --------------------------------------------------
    -- Tree List
    --------------------------------------------------

    local scrollList = AF.CreateScrollList(content, nil, 5, 5, 13, 28, 3, nil, "gray")
    AF.SetPoint(scrollList, "TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", content, 0, 40)
    content.scrollList = scrollList

    --------------------------------------------------
    -- Bottom Buttons
    --------------------------------------------------

    local addTriggerBtn = AF.CreateButton(content, QRA.L["+ Add Trigger"], "softlime", 120, 26)
    AF.SetPoint(addTriggerBtn, "TOPLEFT", scrollList, "BOTTOMLEFT", 0, -8)
    addTriggerBtn:SetEnabled(false)
    addTriggerBtn:SetOnClick(function()
        QRA.UI.Dialogs.ShowTriggerEditor(nil, selectedBoss)
    end)

    -- Update button state when boss selected
    hooksecurefunc(bossDropdown, "OnMenuSelection", function()
        addTriggerBtn:SetEnabled(selectedBoss ~= nil)
    end)

    -- Send to Raid button
    local sendToRaidBtn = AF.CreateButton(content, QRA.L["Send to Raid"], "softblue", 110, 26)
    AF.SetPoint(sendToRaidBtn, "LEFT", addTriggerBtn, "RIGHT", 10, 0)
    sendToRaidBtn:SetOnClick(function()
        local exportString = QRA.Comm.ExportActiveSharedPlan(true)
        if exportString and exportString ~= "" then
            QRA.Comm.SendToRaid(exportString)
        end
    end)

    -- Roster button
    local rosterBtn = AF.CreateButton(content, QRA.L["Roster"], "static", 80, 26)
    AF.SetPoint(rosterBtn, "LEFT", sendToRaidBtn, "RIGHT", 10, 0)
    AF.SetTooltip(rosterBtn, "TOPLEFT", 0, 2, "Roster Manager", "Save current raid roster for planning assignments when not in raid")
    rosterBtn:SetOnClick(function()
        QRA.AssignTargetMenu.ShowRosterManager(mainFrame)
    end)

    local newPlanBtn = AF.CreateButton(content, QRA.L["+ New Plan"], "softlime", 100, 26)
    AF.SetPoint(newPlanBtn, "BOTTOMRIGHT", content, 0, 8)
    newPlanBtn:SetOnClick(function()
        QRA.UI.Dialogs.ShowNewPlanDialog(function(planId, version)
            ApplyPlanSelection(planId, version)
            QRA.UI.RefreshTree()
        end)
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
    content.planDropdown = planDropdown
    content.setActiveVersionBtn = setActiveVersionBtn
    content.deletePlanBtn = deletePlanBtn
    content.newPlanBtn = newPlanBtn

    -- Refresh function
    function QRA.UI.RefreshTree()
        local selectedPlan = QRA.Plans.GetSelectedPlan()
        if selectedPlan then
            selectedPlanId = selectedPlan.id
            selectedPlanVersion = QRA.Plans.GetSelectedVersion()

            if bossDropdown and bossDropdown.RefreshItems then
                bossDropdown:RefreshItems(QRA.Plans.GetEffectiveInstanceName(selectedPlan))
            end
        end

        if planDropdown then
            planDropdown:RefreshItems()
            planDropdown:SetSelected(selectedPlanId, selectedPlanVersion)
        end

        UpdateSetActiveButtonState()

        QRA.UI.Tree.BuildTreeView(content, scrollList, selectedBoss)
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
-- Initialization
--------------------------------------------------

function QRA.UI.Initialize()
    CreateMainFrame()
    QRA.UI.Dialogs.Initialize(mainFrame)
    QRA.Debug("UI: Module initialized")
end
