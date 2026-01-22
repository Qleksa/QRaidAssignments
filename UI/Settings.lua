---@class QRA
local QRA = select(2, ...)

QRA.UI.Settings = {}

---@type AbstractFramework
local AF = QRA.AF

local settingsFrame = nil

function QRA.UI.Settings.ShowSettingsPanel(parent)
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
    AF.SetPoint(settingsFrame, "CENTER", QRA.UIParent, 0, 0)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetFrameLevel(parent:GetFrameLevel() + 10)

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
