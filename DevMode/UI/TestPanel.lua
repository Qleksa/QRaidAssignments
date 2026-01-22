--[[
    QRaidAssignments - Dev Mode: Test Panel UI
    Main test controls window with boss selector, encounter buttons, and trigger list
]]

---@class QRA
local QRA = select(2, ...)
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.UI = QRA.DevMode.UI or {}

local DevModeUI = QRA.DevMode.UI

---@type AbstractFramework
local AF = QRA.AF

--------------------------------------------------
-- Constants
--------------------------------------------------
local PANEL_WIDTH = 350
local PANEL_HEIGHT = 450
local LIST_ROW_HEIGHT = 28

--------------------------------------------------
-- State
--------------------------------------------------
local testPanelFrame = nil
local selectedBoss = nil
local selectedEncounterId = nil
local triggerScrollList = nil
local updateEncounterStatusFunc = nil  -- Will be set after creation

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Create the boss dropdown
---@param parent Frame
---@return Frame dropdown
local function CreateBossDropdown(parent)
    local dropdown = QRA.Widgets.CreateBossMenu(parent, 200, function(self, item)
        selectedBoss = item.text
        selectedEncounterId = item.encounterId
        QRA.DevMode.SetTestBoss(selectedBoss, selectedEncounterId)
        QRA.Debug("DevMode UI: Selected boss:", selectedBoss, selectedEncounterId)

        -- Update button states
        if updateEncounterStatusFunc then
            updateEncounterStatusFunc()
        end

        -- Refresh trigger list
        if DevModeUI.RefreshTriggerList then
            DevModeUI.RefreshTriggerList()
        end
    end)

    return dropdown
end

--- Create a trigger row for the test panel
---@param parent Frame
---@param trigger Trigger
---@param onFire function
---@return Frame row
local function CreateTestTriggerRow(parent, trigger, onFire)
    local row = CreateFrame("Frame", nil, parent)
    AF.SetHeight(row, LIST_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")

    -- Get trigger type color
    local typeColor = QRA.Widgets.Colors.triggerType[trigger.type] or "white"

    -- Type abbreviation
    local typeInfo = QRA.Triggers.Types[trigger.type]
    local typeAbbr = typeInfo and typeInfo.abbreviation or "?"
    local typeFS = AF.CreateFontString(row, typeAbbr, typeColor)
    AF.SetPoint(typeFS, "LEFT", 5, 0)
    AF.SetWidth(typeFS, 35)

    -- Details
    local detailText = ""
    if trigger.spellName then
        detailText = trigger.spellName
    elseif trigger.spellId then
        detailText = "Spell ID: " .. trigger.spellId
    elseif trigger.time then
        detailText = trigger.time .. "s"
    elseif trigger.targetGuid then
        detailText = "NPC: " .. trigger.targetGuid
    elseif trigger.hpThresholds then
        detailText = "HP: " .. trigger.hpThresholds .. "%"
    else
        detailText = QRA.L["Unknown"]
    end

    local detailFS = AF.CreateFontString(row, detailText, "white")
    AF.SetPoint(detailFS, "LEFT", typeFS, "RIGHT", 5, 0)
    AF.SetPoint(detailFS, "RIGHT", row, -65, 0)
    detailFS:SetJustifyH("LEFT")
    detailFS:SetWordWrap(false)

    -- Fire button
    local fireBtn = AF.CreateButton(row, QRA.L["Fire"], "softlime", 50, 22)
    AF.SetPoint(fireBtn, "RIGHT", row, -5, 0)
    fireBtn:SetOnClick(function()
        if onFire then
            onFire(trigger)
        end
    end)

    return row
end

--------------------------------------------------
-- Main Panel Creation
--------------------------------------------------

--- Create the test panel window
function DevModeUI.CreateTestPanel()
    if testPanelFrame then
        return testPanelFrame
    end

    -- Create main frame
    local frame = AF.CreateHeaderedFrame(UIParent, "QRA_DevMode_TestPanel", QRA.L["DevMode: Test Panel"], PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        QRA.DevMode.SaveFramePosition(self, "testPanel")
    end)

    -- Apply saved position or center
    if not QRA.DevMode.ApplyWindowPosition(frame, "testPanel") then
        frame:SetPoint("CENTER")
    end

    testPanelFrame = frame

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    AF.SetPoint(content, "TOPLEFT", frame, 10, -35)
    AF.SetPoint(content, "BOTTOMRIGHT", frame, -10, 10)

    --------------------------------------------------
    -- Boss Selection Section
    --------------------------------------------------
    local bossDropdown = CreateBossDropdown(content)
    AF.SetPoint(bossDropdown, "TOPLEFT", content, 0, 0)

    -- Restore last selected boss
    if QRA.DB.devMode and QRA.DB.devMode.lastBossName then
        selectedBoss = QRA.DB.devMode.lastBossName
        selectedEncounterId = QRA.DB.devMode.lastEncounterId
        -- Note: The dropdown will need to be set externally after bosses are loaded
    end

    --------------------------------------------------
    -- Encounter Control Section
    --------------------------------------------------
    local encounterLabel = AF.CreateFontString(content, QRA.L["Encounter:"], "accent")
    AF.SetPoint(encounterLabel, "TOPLEFT", bossDropdown, "BOTTOMLEFT", 0, -10)

    local startBtn = AF.CreateButton(content, QRA.L["Start Encounter"], "lime", 120, 28)
    AF.SetPoint(startBtn, "TOPLEFT", encounterLabel, "BOTTOMLEFT", 0, -5)

    local stopBtn = AF.CreateButton(content, QRA.L["Stop Encounter"], "red", 120, 28)
    AF.SetPoint(stopBtn, "LEFT", startBtn, "RIGHT", 10, 0)

    local encounterStatusFS = AF.CreateFontString(content, "", "gray")
    AF.SetPoint(encounterStatusFS, "TOPLEFT", startBtn, "BOTTOMLEFT", 0, -5)
    content.encounterStatusFS = encounterStatusFS

    local function UpdateEncounterStatus()
        if QRA.DevMode.FakeEncounter.IsActive() then
            local _, bossName = QRA.DevMode.FakeEncounter.GetCurrentEncounter()
            encounterStatusFS:SetText(QRA.L["Active:"] .. " " .. (bossName or "?"))
            encounterStatusFS:SetTextColor(AF.GetColorRGB("lime"))
            startBtn:SetEnabled(false)
            stopBtn:SetEnabled(true)
        else
            encounterStatusFS:SetText(QRA.L["Inactive"])
            encounterStatusFS:SetTextColor(AF.GetColorRGB("gray"))
            startBtn:SetEnabled(selectedBoss ~= nil)
            stopBtn:SetEnabled(false)
        end
    end

    -- Store reference for dropdown callback
    updateEncounterStatusFunc = UpdateEncounterStatus

    startBtn:SetOnClick(function()
        if selectedBoss then
            QRA.DevMode.FakeEncounter.Start(selectedBoss, selectedEncounterId)
            UpdateEncounterStatus()
            DevModeUI.RefreshTriggerList()
        else
            QRA.Print(QRA.L["DevMode: Select a boss first"])
        end
    end)

    stopBtn:SetOnClick(function()
        QRA.DevMode.FakeEncounter.Stop(false)
        UpdateEncounterStatus()
    end)

    -- Listen for encounter state changes
    QRA.DevMode.FakeEncounter.OnEncounterStateChanged = function(active)
        UpdateEncounterStatus()
    end

    --------------------------------------------------
    -- Trigger List Section
    --------------------------------------------------
    local triggerLabel = AF.CreateFontString(content, QRA.L["Registered Triggers:"], "accent")
    AF.SetPoint(triggerLabel, "TOPLEFT", encounterStatusFS, "BOTTOMLEFT", 0, -15)

    local listFrame = AF.CreateBorderedFrame(content, nil, nil, 100, nil, "gray")
    AF.SetPoint(listFrame, "TOPLEFT", triggerLabel, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(listFrame, "BOTTOMRIGHT", content, 0, 80)

    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 8, LIST_ROW_HEIGHT, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 5)
    triggerScrollList = scrollList

    --- Refresh the trigger list
    function DevModeUI.RefreshTriggerList()
        local widgets = {}

        if selectedBoss then
            local triggers = QRA.Triggers.GetBossTriggers(selectedBoss)

            for i, trigger in ipairs(triggers) do
                local row = CreateTestTriggerRow(scrollList.slotFrame, trigger, function(t)
                    if not QRA.DevMode.FakeEncounter.IsActive() then
                        QRA.Print(QRA.L["DevMode: Start an encounter first"])
                        return
                    end
                    QRA.DevMode.EventFirer.FireTrigger(t)
                end)

                -- Zebra striping
                if i % 2 == 0 then
                    local bg = row:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(1, 1, 1, 0.03)
                end

                table.insert(widgets, row)
            end
        end

        scrollList:SetWidgets(widgets)
    end

    --------------------------------------------------
    -- Bottom Buttons
    --------------------------------------------------
    local resetBtn = AF.CreateButton(content, QRA.L["Reset Counters"], "orange", 100, 26)
    AF.SetPoint(resetBtn, "BOTTOMLEFT", content, 0, 40)
    resetBtn:SetOnClick(function()
        -- Reset trigger occurrence counters
        if QRA.Triggers and QRA.Triggers.ResetOccurrences then
            QRA.Triggers.ResetOccurrences()
        end
        QRA.Print(QRA.L["DevMode: Counters reset"])
    end)

    local fakeBossBtn = AF.CreateButton(content, QRA.L["Fake Boss"], "skyblue", 100, 26)
    AF.SetPoint(fakeBossBtn, "LEFT", resetBtn, "RIGHT", 10, 0)
    fakeBossBtn:SetOnClick(function()
        DevModeUI.ShowFakeBossPanel()
    end)

    local eventLogBtn = AF.CreateButton(content, QRA.L["Event Log"], "purple", 100, 26)
    AF.SetPoint(eventLogBtn, "LEFT", fakeBossBtn, "RIGHT", 10, 0)
    eventLogBtn:SetOnClick(function()
        DevModeUI.ShowEventLogPanel()
    end)

    -- Close button
    local closeBtn = AF.CreateButton(content, QRA.L["Close"], "red", 80, 26)
    AF.SetPoint(closeBtn, "BOTTOMRIGHT", content, 0, 5)
    closeBtn:SetOnClick(function()
        frame:Hide()
    end)

    -- Exit Test Mode button
    local exitBtn = AF.CreateButton(content, QRA.L["Exit Test Mode"], "gray", 100, 26)
    AF.SetPoint(exitBtn, "RIGHT", closeBtn, "LEFT", -10, 0)
    exitBtn:SetOnClick(function()
        QRA.DevMode.Disable()
        frame:Hide()
    end)

    -- Initial state update
    UpdateEncounterStatus()

    return frame
end

--------------------------------------------------
-- Panel Show/Hide
--------------------------------------------------

--- Show the test panel
function DevModeUI.ShowTestPanel()
    if not testPanelFrame then
        DevModeUI.CreateTestPanel()
    end

    testPanelFrame:Show()

    -- Update button states and refresh trigger list
    if updateEncounterStatusFunc then
        updateEncounterStatusFunc()
    end
    DevModeUI.RefreshTriggerList()
end

--- Hide the test panel
function DevModeUI.HideTestPanel()
    if testPanelFrame then
        testPanelFrame:Hide()
    end
end

--- Toggle the test panel
function DevModeUI.ToggleTestPanel()
    if testPanelFrame and testPanelFrame:IsShown() then
        DevModeUI.HideTestPanel()
    else
        DevModeUI.ShowTestPanel()
    end
end

--- Check if test panel is shown
---@return boolean
function DevModeUI.IsTestPanelShown()
    return testPanelFrame and testPanelFrame:IsShown()
end

--------------------------------------------------
-- Update Selected Boss (called from main UI)
--------------------------------------------------

--- Set the selected boss from external source
---@param bossName string
---@param encounterId number|nil
function DevModeUI.SetSelectedBoss(bossName, encounterId)
    selectedBoss = bossName
    selectedEncounterId = encounterId
    QRA.DevMode.SetTestBoss(bossName, encounterId)

    if testPanelFrame and testPanelFrame:IsShown() then
        DevModeUI.RefreshTriggerList()
    end
end
