--[[
    QRaidAssignments - Dev Mode: Event Log UI
    Displays event history with replay functionality
]]

---@class QRA
local QRA = select(2, ...)
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.UI = QRA.DevMode.UI or {}

local DevModeUI = QRA.DevMode.UI
local EventHistory = QRA.DevMode.EventHistory

---@type AbstractFramework
local AF = _G.AbstractFramework

--------------------------------------------------
-- Constants
--------------------------------------------------
local PANEL_WIDTH = 450
local PANEL_HEIGHT = 400
local LIST_ROW_HEIGHT = 24

--------------------------------------------------
-- State
--------------------------------------------------
local eventLogPanelFrame = nil
local eventScrollList = nil

--------------------------------------------------
-- Event Type Colors
--------------------------------------------------
local EVENT_COLORS = {
    SPELL_CAST_SUCCESS = "accent",
    SPELL_CAST_START = "yellow",
    SPELL_AURA_APPLIED = "lime",
    SPELL_AURA_REMOVED = "orange",
    UNIT_DIED = "red",
    TIMER = "skyblue",
    UNIT_HEALTH = "purple",
}

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Create an event row for the log
---@param parent Frame
---@param event table
---@param onReplay function
---@return Frame
local function CreateEventRow(parent, event, onReplay)
    local row = CreateFrame("Frame", nil, parent)
    AF.SetHeight(row, LIST_ROW_HEIGHT)
    AF.SetPoint(row, "LEFT")
    AF.SetPoint(row, "RIGHT")

    local colorKey = EVENT_COLORS[event.eventType] or "white"

    -- Timestamp
    local timeStr = string.format("%.1fs", event.encounterTime)
    local timeFS = AF.CreateFontString(row, timeStr, "gray")
    AF.SetPoint(timeFS, "LEFT", row, 5, 0)
    AF.SetWidth(timeFS, 45)

    -- Event type
    local typeFS = AF.CreateFontString(row, event.eventType, colorKey)
    AF.SetPoint(typeFS, "LEFT", timeFS, "RIGHT", 5, 0)
    AF.SetWidth(typeFS, 130)
    typeFS:SetJustifyH("LEFT")

    -- Details
    local detailText = ""
    local data = event.data

    if event.eventType == "SPELL_CAST_SUCCESS" or event.eventType == "SPELL_CAST_START" then
        detailText = string.format("%s", data.spellName or data.spellId or "?")
        if data.targetName then
            detailText = detailText .. " -> " .. data.targetName
        end
    elseif event.eventType == "SPELL_AURA_APPLIED" or event.eventType == "SPELL_AURA_REMOVED" then
        detailText = string.format("%s on %s", data.spellName or "?", data.targetName or "self")
    elseif event.eventType == "UNIT_DIED" then
        detailText = data.name or "?"
    elseif event.eventType == "TIMER" then
        detailText = string.format("@ %ds", data.time or 0)
    elseif event.eventType == "UNIT_HEALTH" then
        detailText = string.format("%s: %d%% -> %d%%", data.unitId or "?", data.oldHealth or 0, data.newHealth or 0)
    end

    local detailFS = AF.CreateFontString(row, detailText, "white")
    AF.SetPoint(detailFS, "LEFT", typeFS, "RIGHT", 5, 0)
    AF.SetPoint(detailFS, "RIGHT", row, -55, 0)
    detailFS:SetJustifyH("LEFT")
    detailFS:SetWordWrap(false)

    -- Replay button
    local replayBtn = AF.CreateButton(row, ">", "softlime", 30, 20)
    AF.SetPoint(replayBtn, "RIGHT", row, -5, 0)
    replayBtn:SetOnClick(function()
        if onReplay then
            onReplay(event)
        end
    end)

    return row
end

--------------------------------------------------
-- Main Panel Creation
--------------------------------------------------

function DevModeUI.CreateEventLogPanel()
    if eventLogPanelFrame then
        return eventLogPanelFrame
    end

    local frame = AF.CreateHeaderedFrame(UIParent, "QRA_DevMode_EventLogPanel", QRA.L["DevMode: Event Log"], PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        QRA.DevMode.SaveFramePosition(self, "eventLogPanel")
    end)

    -- Apply saved position
    if not QRA.DevMode.ApplyWindowPosition(frame, "eventLogPanel") then
        frame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end

    eventLogPanelFrame = frame

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    AF.SetPoint(content, "TOPLEFT", frame, 10, -35)
    AF.SetPoint(content, "BOTTOMRIGHT", frame, -10, 10)

    -- Header row
    local headerRow = CreateFrame("Frame", nil, content)
    AF.SetHeight(headerRow, 20)
    AF.SetPoint(headerRow, "TOPLEFT", content, 0, 0)
    AF.SetPoint(headerRow, "TOPRIGHT", content, 0, 0)

    local hTime = AF.CreateFontString(headerRow, QRA.L["Time"], "gray")
    AF.SetPoint(hTime, "LEFT", headerRow, 5, 0)
    AF.SetWidth(hTime, 45)

    local hType = AF.CreateFontString(headerRow, QRA.L["Event"], "gray")
    AF.SetPoint(hType, "LEFT", hTime, "RIGHT", 5, 0)
    AF.SetWidth(hType, 130)

    local hDetails = AF.CreateFontString(headerRow, QRA.L["Details"], "gray")
    AF.SetPoint(hDetails, "LEFT", hType, "RIGHT", 5, 0)

    -- Event count display
    local countFS = AF.CreateFontString(headerRow, "0 events", "gray")
    AF.SetPoint(countFS, "RIGHT", headerRow, -5, 0)
    content.countFS = countFS

    -- List frame
    local listFrame = AF.CreateBorderedFrame(content, nil, nil, 100, nil, "gray")
    AF.SetPoint(listFrame, "TOPLEFT", headerRow, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(listFrame, "BOTTOMRIGHT", content, 0, 45)

    local scrollList = AF.CreateScrollList(listFrame, nil, 5, 5, 10, LIST_ROW_HEIGHT, 3)
    AF.SetPoint(scrollList, "TOPLEFT", listFrame, 5, -5)
    AF.SetPoint(scrollList, "BOTTOMRIGHT", listFrame, -5, 5)
    eventScrollList = scrollList

    --- Refresh the event list
    function DevModeUI.RefreshEventLog()
        local widgets = {}
        local events = EventHistory.GetAll()

        -- Show in reverse order (newest first)
        for i = #events, 1, -1 do
            local event = events[i]
            local row = CreateEventRow(scrollList.slotFrame, event, function(e)
                EventHistory.ReplayEvent(e.id)
            end)

            -- Zebra striping
            if (#events - i + 1) % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end

            table.insert(widgets, row)
        end

        scrollList:SetWidgets(widgets)
        countFS:SetText(#events .. " " .. QRA.L["events"])
    end

    -- Register for new events
    EventHistory.OnEventAdded = function(event)
        if eventLogPanelFrame and eventLogPanelFrame:IsShown() then
            DevModeUI.RefreshEventLog()
        end
    end

    EventHistory.OnHistoryCleared = function()
        if eventLogPanelFrame and eventLogPanelFrame:IsShown() then
            DevModeUI.RefreshEventLog()
        end
    end

    --------------------------------------------------
    -- Bottom Buttons
    --------------------------------------------------
    local clearBtn = AF.CreateButton(content, QRA.L["Clear All"], "red", 80, 26)
    AF.SetPoint(clearBtn, "BOTTOMLEFT", content, 0, 5)
    clearBtn:SetOnClick(function()
        EventHistory.Clear()
    end)

    local replayAllBtn = AF.CreateButton(content, QRA.L["Replay All"], "lime", 80, 26)
    AF.SetPoint(replayAllBtn, "LEFT", clearBtn, "RIGHT", 10, 0)
    replayAllBtn:SetOnClick(function()
        if not QRA.DevMode.FakeEncounter.IsActive() then
            QRA.Print(QRA.L["DevMode: Start an encounter first"])
            return
        end
        EventHistory.ReplaySequence(nil, nil, true)
    end)

    local replayNoTimingBtn = AF.CreateButton(content, QRA.L["Replay Fast"], "orange", 80, 26)
    AF.SetPoint(replayNoTimingBtn, "LEFT", replayAllBtn, "RIGHT", 10, 0)
    replayNoTimingBtn:SetOnClick(function()
        if not QRA.DevMode.FakeEncounter.IsActive() then
            QRA.Print(QRA.L["DevMode: Start an encounter first"])
            return
        end
        EventHistory.ReplaySequence(nil, nil, false)
    end)

    local closeBtn = AF.CreateButton(content, QRA.L["Close"], "gray", 80, 26)
    AF.SetPoint(closeBtn, "BOTTOMRIGHT", content, 0, 5)
    closeBtn:SetOnClick(function()
        frame:Hide()
    end)

    return frame
end

--------------------------------------------------
-- Panel Show/Hide
--------------------------------------------------

function DevModeUI.ShowEventLogPanel()
    if not eventLogPanelFrame then
        DevModeUI.CreateEventLogPanel()
    end

    eventLogPanelFrame:Show()
    DevModeUI.RefreshEventLog()
end

function DevModeUI.HideEventLogPanel()
    if eventLogPanelFrame then
        eventLogPanelFrame:Hide()
    end
end

function DevModeUI.ToggleEventLogPanel()
    if eventLogPanelFrame and eventLogPanelFrame:IsShown() then
        DevModeUI.HideEventLogPanel()
    else
        DevModeUI.ShowEventLogPanel()
    end
end
