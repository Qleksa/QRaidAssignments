---@class QRA
local QRA = select(2, ...)

QRA.UI.Settings = {}

---@type AbstractFramework
local AF = _G.AbstractFramework

local settingsFrame = nil

--- Create a section header with optional collapse button
---@param parent Frame Parent frame
---@param title string Header title
---@param collapsible boolean|nil Whether the section is collapsible
---@return Frame header
local function CreateSectionHeader(parent, title, collapsible)
    local header = CreateFrame("Frame", nil, parent)
    AF.SetHeight(header, 24)
    AF.SetPoint(header, "LEFT")
    AF.SetPoint(header, "RIGHT")

    -- Background
    local bg = AF.CreateGradientTexture(header, "HORIZONTAL", {0.2, 0.2, 0.2, 0.8}, {0.1, 0.1, 0.1, 0.4})
    AF.SetPoint(bg, "TOPLEFT")
    AF.SetPoint(bg, "BOTTOMRIGHT")

    -- Title text
    local titleFS = AF.CreateFontString(header, title, "softlime")
    AF.SetPoint(titleFS, "LEFT", 10, 0)

    -- Collapse button (optional)
    if collapsible then
        local collapseBtn = AF.CreateButton(header, "-", "static", 20, 18)
        AF.SetPoint(collapseBtn, "RIGHT", -5, 0)

        header.collapsed = false
        header.content = nil  -- Will be set by user

        collapseBtn:SetOnClick(function()
            header.collapsed = not header.collapsed
            collapseBtn:SetText(header.collapsed and "+" or "-")
            if header.content then
                if header.collapsed then
                    header.content:Hide()
                else
                    header.content:Show()
                end
            end
            if header.OnCollapse then
                header.OnCollapse(header.collapsed)
            end
        end)

        header.collapseBtn = collapseBtn
    end

    return header
end

function QRA.UI.Settings.ShowSettingsPanel(parent)
    if settingsFrame then
        settingsFrame:Show()
        return
    end

    settingsFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_SettingsPanel",
        QRA.L["Settings"],
        310,
        550
    )
    AF.SetPoint(settingsFrame, "CENTER", QRA.UIParent, 0, 0)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    table.insert(UISpecialFrames, settingsFrame:GetName())

    local content = CreateFrame("Frame", nil, settingsFrame)
    AF.SetPoint(content, "TOPLEFT", settingsFrame, 10, -10)
    AF.SetPoint(content, "BOTTOMRIGHT", settingsFrame, -10, 40)

    -- Notifications section
    local notifHeader = CreateSectionHeader(content, QRA.L["Notification Settings"])
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

    -- Assignment Display section
    local assignDisplayHeader = CreateSectionHeader(content, "Assignment Display")
    AF.SetPoint(assignDisplayHeader, "TOPLEFT", chatCheck, "BOTTOMLEFT", -10, -20)
    AF.SetPoint(assignDisplayHeader, "TOPRIGHT", content, 0, 0)

    local assignDisplayCheck = AF.CreateCheckButton(content, "Show Assignment Display on Zone Entry", function(checked)
        QRA.Settings.assignmentDisplay.enabled = checked
        if not checked and QRA.AssignmentDisplay then
            QRA.AssignmentDisplay.Hide()
        end
    end)
    AF.SetPoint(assignDisplayCheck, "TOPLEFT", assignDisplayHeader, "BOTTOMLEFT", 10, -10)
    assignDisplayCheck:SetChecked(QRA.Settings.assignmentDisplay.enabled)

    -- Test buttons section
    local testHeader = CreateSectionHeader(content, QRA.L["Test Notifications"])
    AF.SetPoint(testHeader, "TOPLEFT", assignDisplayCheck, "BOTTOMLEFT", -10, -20)
    AF.SetPoint(testHeader, "TOPRIGHT", content, 0, 0)

    local testTTSBtn = AF.CreateButton(content, QRA.L["Test TTS"], "static", 80, 22)
    AF.SetPoint(testTTSBtn, "TOPLEFT", testHeader, "BOTTOMLEFT", 0, -10)
    testTTSBtn:SetOnClick(QRA.Notifications.TestTTS)

    local testSoundBtn = AF.CreateButton(content, QRA.L["Test Sound"], "static", 90, 22)
    AF.SetPoint(testSoundBtn, "LEFT", testTTSBtn, "RIGHT", 8, 0)
    testSoundBtn:SetOnClick(QRA.Notifications.TestSound)

    local testScreenBtn = AF.CreateButton(content, QRA.L["Test Screen"], "static", 100, 22)
    AF.SetPoint(testScreenBtn, "TOPLEFT", testTTSBtn, "BOTTOMLEFT", 0, -8)
    testScreenBtn:SetOnClick(QRA.Notifications.TestScreen)

    local testCountdownBtn = AF.CreateButton(content, QRA.L["Test Countdown"], "static", 120, 22)
    AF.SetPoint(testCountdownBtn, "LEFT", testScreenBtn, "RIGHT", 8, 0)
    testCountdownBtn:SetOnClick(QRA.Notifications.TestCountdown)

    local testMultipleCountdowns = AF.CreateButton(content, "Test Multiple Countdowns", "static", 185, 22)
    AF.SetPoint(testMultipleCountdowns, "TOPLEFT", testScreenBtn, "BOTTOMLEFT", 0, -8)
    testMultipleCountdowns:SetOnClick(QRA.Notifications.TestMultipleCountdowns)

    -- Movers section
    local moversHeader = CreateSectionHeader(content, QRA.L["Movers"])
    AF.SetPoint(moversHeader, "TOPLEFT", testMultipleCountdowns, "BOTTOMLEFT", 0, -20)
    AF.SetPoint(moversHeader, "TOPRIGHT", content, 0, 0)

    local showMoversBtn = AF.CreateButton(content, QRA.L["Show Movers"], "static", 115, 26)
    AF.SetPoint(showMoversBtn, "TOPLEFT", moversHeader, "BOTTOMLEFT", 0, -10)
    showMoversBtn:SetOnClick(function()
        AF.ShowMovers("QRA Movers")
    end)

    local hideMoversBtn = AF.CreateButton(content, QRA.L["Hide Movers"], "static", 100, 26)
    AF.SetPoint(hideMoversBtn, "LEFT", showMoversBtn, "RIGHT", 8, 0)
    hideMoversBtn:SetOnClick(function()
        AF.HideMovers()
    end)

    -- Debug section
    local debugHeader = CreateSectionHeader(content, QRA.L["Debug"])
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
