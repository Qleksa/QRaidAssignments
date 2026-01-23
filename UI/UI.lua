--[[
    QRaidAssignments - Main UI
    Primary user interface for managing triggers and assignments
    Hierarchical tree view: Instance → Boss → Trigger → Assignments
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

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
    local expandBtn = QRA.UI.Tree.CreateExpandButton(topBar)
    AF.SetPoint(expandBtn, "LEFT", sep1, "RIGHT", 8, 0)

    local collapseBtn = QRA.UI.Tree.CreateCollapseButton(topBar)
    AF.SetPoint(collapseBtn, "LEFT", expandBtn, "RIGHT", 2, 0)

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
            QRA.UI.Dialogs.ShowExportFrame(exportString)
        end
    end)

    -- RIGHT GROUP: Test Mode and Settings
    -- Settings button
    local settingsBtn = AF.CreateButton(topBar, "S", "static", 26, 26)
    AF.SetPoint(settingsBtn, "RIGHT", topBar, 0, 0)
    AF.SetTooltip(settingsBtn, "ANCHOR_LEFT", 0, 0, QRA.L["Settings"])
    settingsBtn:SetOnClick(function()
        QRA.UI.Settings.ShowSettingsPanel(mainFrame)
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

    local scrollList = AF.CreateScrollList(content, nil, 5, 5, 13, 28, 3, nil, "gray")
    AF.SetPoint(scrollList, "TOPLEFT", topBar, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", content, 0, 40)
    content.scrollList = scrollList

    --------------------------------------------------
    -- Bottom Buttons
    --------------------------------------------------

    local addTriggerBtn = AF.CreateButton(content, QRA.L["+ Add Trigger"], "softlime", 120, 26)
    AF.SetPoint(addTriggerBtn, "TOPLEFT", scrollList, "BOTTOMLEFT", 0, -8)
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
