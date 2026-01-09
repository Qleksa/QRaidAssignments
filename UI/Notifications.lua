--[[
    QRaidAssignments - Notifications System
    Handles TTS, sound playback, on-screen messages, and countdown alerts
]]

local QRA = _G.QRA
QRA.Notifications = {}

local AF = _G.AbstractFramework

--------------------------------------------------
-- Configuration
--------------------------------------------------
local config = {
    ttsEnabled = true,
    soundEnabled = true,
    screenEnabled = true,
    chatEnabled = true,

    screenDuration = 5,        -- Default screen message duration
    screenPosition = "CENTER", -- Where to show screen messages
    chatChannel = "SAY",       -- Default chat channel

    countdownSounds = {
        [10] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/10.ogg",
        [9] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/9.ogg",
        [8] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/8.ogg",
        [7] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/7.ogg",
        [6] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/6.ogg",
        [5] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/5.ogg",
        [4] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/4.ogg",
        [3] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/3.ogg",
        [2] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/2.ogg",
        [1] = "Interface/AddOns/QRaidAssignmentsV1/Media/Sounds/1.ogg",
    },
}

--------------------------------------------------
-- Screen Message Frame
--------------------------------------------------
local screenMessageFrame = nil

-- TODO: Use AF framses

--- Create the screen message display frame
local function CreateScreenMessageFrame()
    if screenMessageFrame then return end

    screenMessageFrame = CreateFrame("Frame", "QRA_ScreenMessage", QRA.UIParent)
    screenMessageFrame:SetSize(400, 60)
    screenMessageFrame:SetPoint("CENTER", 0, 150)
    screenMessageFrame:SetFrameStrata("HIGH")
    screenMessageFrame:Hide()

    -- Background
    local bg = screenMessageFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    -- Message text
    local text = AF.CreateFontString(screenMessageFrame, "", "yellow")
    AF.SetPoint(text, "CENTER")
    text:SetJustifyH("CENTER")
    screenMessageFrame.text = text

    -- Countdown text (smaller, below main message)
    local countdown = AF.CreateFontString(screenMessageFrame, "", "white")
    AF.SetPoint(countdown, "TOP", text, "BOTTOM", 0, -5)
    screenMessageFrame.countdown = countdown

    -- Animation group for fade out
    local ag = screenMessageFrame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.5)
    fade:SetStartDelay(4.5)
    ag:SetScript("OnFinished", function()
        screenMessageFrame:Hide()
        screenMessageFrame:SetAlpha(1)
    end)
    screenMessageFrame.fadeAnim = ag
end

---@param type AlertType Type of notification
---@param message string Message
---@param file string|nil Sound file for SOUND type
function QRA.Notifications.Notify(type, message, file)
    if type == "TTS" then
        QRA.Notifications.SpeakTTS(message)
    elseif type == "SOUND" then
        QRA.Notifications.PlaySound(file)
    elseif type == "SCREEN" then
        QRA.Notifications.ShowOnScreen(message)
    elseif type == "CHAT" then
        QRA.Notifications.SendChat(message)
    end
end

--------------------------------------------------
-- Text-to-Speech
--------------------------------------------------

--- Speak a message using TTS
---@param message string The message to speak
---@param voice string|nil Optional voice identifier
function QRA.Notifications.SpeakTTS(message, voice)
    if not config.ttsEnabled then return end
    if not message or message == "" then return end

    -- Use the TextToSpeech API if available (Retail only)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        local voiceId = voice or Enum.TtsVoiceType.Standard
        C_VoiceChat.SpeakText(
            voiceId,
            message,
            Enum.VoiceTtsDestination.LocalPlayback,
            1.0,  -- Speech rate
            100   -- Volume
        )
    else
        -- Classic fallback: use LibTextToSpeech if available, or print to chat
        local LibTTS = LibStub and LibStub("LibTextToSpeech", true)
        if LibTTS then
            LibTTS:Speak(message)
        else
            -- Final fallback: just print it
            QRA.Print("|cffFFFF00[TTS]|r " .. message)
        end
    end

    QRA.Debug("Notifications: TTS -", message)
end

--------------------------------------------------
-- Sound Playback
--------------------------------------------------

--- Play a sound file
---@param soundFile string|nil Path to the sound file
---@param channel string|nil Sound channel (Master, SFX, Music, Ambience, Dialog)
function QRA.Notifications.PlaySound(soundFile, channel)
    if not config.soundEnabled then return end

    if soundFile then
        PlaySoundFile(soundFile, channel or "Master")
    else
        -- Default alert sound
        PlaySound(SOUNDKIT.RAID_WARNING, channel or "Master")
    end
end

--- Play a countdown sound for the given number
---@param number number The countdown number (1 up to 10)
---@param useDefault boolean|nil Whether to use the default sound instead of custom
function QRA.Notifications.PlayCountdown(number, useDefault)
    if not config.soundEnabled then return end
    if (number < 1) or (number > 10) then return end

    local soundFile = config.countdownSounds[number]
    if not useDefault and soundFile then
        PlaySoundFile(soundFile, "Master")
    else
        -- Fallback to default sound
        PlaySound(SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_TIMER, "Master")
    end
end

--------------------------------------------------
-- On-Screen Messages
--------------------------------------------------

--- Show a message on screen
---@param message string The message to display
---@param duration number|nil Duration in seconds (default 5)
---@param color table|nil RGB color table {r, g, b}
function QRA.Notifications.ShowOnScreen(message, duration, color)
    if not config.screenEnabled then return end

    if not screenMessageFrame then
        CreateScreenMessageFrame()
    end

    screenMessageFrame.text:SetText(message)
    if color then
        screenMessageFrame.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 0)
    else
        screenMessageFrame.text:SetTextColor(1, 1, 0)  -- Yellow default
    end
    screenMessageFrame.countdown:SetText("")

    -- Reset and show
    screenMessageFrame:SetAlpha(1)
    screenMessageFrame:Show()

    -- Restart fade animation
    screenMessageFrame.fadeAnim:Stop()
    screenMessageFrame.fadeAnim:GetAnimations():SetStartDelay((duration or config.screenDuration) - 0.5)
    screenMessageFrame.fadeAnim:Play()

    QRA.Debug("Notifications: Screen -", message)
end

--- Show a countdown start notification
---@param assignment table The assignment starting countdown
---@param seconds number Seconds remaining
function QRA.Notifications.ShowCountdown(assignment, seconds)
    if not config.screenEnabled then return end

    if not screenMessageFrame then
        CreateScreenMessageFrame()
    end

    local message = assignment.message or assignment.spellName or QRA.L["Assignment"]
    screenMessageFrame.text:SetText(message)
    screenMessageFrame.countdown:SetText(string.format(QRA.L["in %d seconds"], seconds))

    screenMessageFrame:SetAlpha(1)
    screenMessageFrame:Show()

    -- Don't auto-hide during countdown
    screenMessageFrame.fadeAnim:Stop()

    local remaining = seconds
    C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        if remaining > 0 then
            QRA.Notifications.PlayCountdown(remaining)
        end
        QRA.Notifications.UpdateCountdown(remaining)
    end, seconds)
end

--- Update the countdown display
---@param seconds number Seconds remaining
function QRA.Notifications.UpdateCountdown(seconds)
    if screenMessageFrame and screenMessageFrame:IsShown() then
        if seconds > 0 then
            screenMessageFrame.countdown:SetText(string.format(QRA.L["in %d seconds"], seconds))
        else
            screenMessageFrame.countdown:SetText(QRA.L["NOW!"])
            screenMessageFrame.countdown:SetTextColor(1, 0, 0)  -- Red

            -- Start fade out
            screenMessageFrame.fadeAnim:Stop()
            screenMessageFrame.fadeAnim:GetAnimations():SetStartDelay(1.5)
            screenMessageFrame.fadeAnim:Play()
        end
    end
end

--------------------------------------------------
-- Chat Messages
--------------------------------------------------

--- Send a message to chat
---@param message string The message to send
---@param channel string|nil Chat channel (SAY, PARTY, RAID, etc.)
function QRA.Notifications.SendChat(message, channel)
    if not config.chatEnabled then return end

    channel = channel or config.chatChannel

    -- Determine appropriate channel
    if channel == "RAID" and not IsInRaid() then
        if IsInGroup() then
            channel = "PARTY"
        else
            channel = "SAY"
        end
    elseif channel == "PARTY" and not IsInGroup() then
        channel = "SAY"
    end

    C_ChatInfo.SendChatMessage(message, channel)
    QRA.Debug("Notifications: Chat -", channel, message)
end

--------------------------------------------------
-- Raid Warning
--------------------------------------------------

--- Show a raid warning style message
---@param message string The message to display
---@param playSound boolean|nil Whether to play the raid warning sound
function QRA.Notifications.ShowRaidWarning(message, playSound)
    if RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    end

    if playSound then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

--------------------------------------------------
-- Configuration
--------------------------------------------------

--- Get current notification settings
---@return table
function QRA.Notifications.GetConfig()
    return config
end

--- Update notification settings
---@param settings table Settings to update
function QRA.Notifications.SetConfig(settings)
    for key, value in pairs(settings) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
end

--- Enable/disable TTS
---@param enabled boolean
function QRA.Notifications.SetTTSEnabled(enabled)
    config.ttsEnabled = enabled
end

--- Enable/disable sound
---@param enabled boolean
function QRA.Notifications.SetSoundEnabled(enabled)
    config.soundEnabled = enabled
end

--- Enable/disable screen messages
---@param enabled boolean
function QRA.Notifications.SetScreenEnabled(enabled)
    config.screenEnabled = enabled
end

--- Enable/disable chat messages
---@param enabled boolean
function QRA.Notifications.SetChatEnabled(enabled)
    config.chatEnabled = enabled
end

--------------------------------------------------
-- Test Functions
--------------------------------------------------

--- Test TTS notification
function QRA.Notifications.TestTTS()
    QRA.Notifications.SpeakTTS("This is a test of the text to speech system")
end

--- Test sound notification
function QRA.Notifications.TestSound()
    QRA.Notifications.PlaySound()
end

--- Test screen notification
function QRA.Notifications.TestScreen()
    QRA.Notifications.ShowOnScreen("Test Screen Message", 3, {1, 1, 0})
end

--- Test countdown
function QRA.Notifications.TestCountdown()
    local assignment = {
        message = "Use Heroism",
        countdownTime = 5,
    }
    QRA.Notifications.ShowCountdown(assignment, 5)
end

--------------------------------------------------
-- Persistence
--------------------------------------------------

--- Save notification settings to DB
function QRA.Notifications.SaveToDB()
    if not QRA.DB then return end
    QRA.DB.notifications = {
        ttsEnabled = config.ttsEnabled,
        soundEnabled = config.soundEnabled,
        screenEnabled = config.screenEnabled,
        chatEnabled = config.chatEnabled,
        screenDuration = config.screenDuration,
        chatChannel = config.chatChannel,
    }
end

--- Load notification settings from DB
function QRA.Notifications.LoadFromDB()
    if not QRA.DB or not QRA.DB.notifications then return end

    for key, value in pairs(QRA.DB.notifications) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Notifications.Initialize()
    QRA.Notifications.LoadFromDB()
    CreateScreenMessageFrame()
    QRA.Debug("Notifications: Module initialized")
end
