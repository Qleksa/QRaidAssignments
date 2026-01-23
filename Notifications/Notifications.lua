--[[
    QRaidAssignments - Notifications System
    Handles TTS, sound playback, on-screen messages, and countdown alerts
]]

---@class QRA
local QRA = select(2, ...)

QRA.Notifications = QRA.Notifications or {}

---@type AbstractFramework
local AF = _G.AbstractFramework

--------------------------------------------------
-- Configuration
--------------------------------------------------

---@class QRA_CountdownSounds
---@field [number] string Sound file path

---@class QRA_FramePosition
---@field point string Anchor point
---@field xOfs number X offset
---@field yOfs number Y offset

---@class QRA_NotificationConfig
---@field ttsEnabled boolean
---@field soundEnabled boolean
---@field screenEnabled boolean
---@field chatEnabled boolean
---@field screenDuration number
---@field screenPosition string
---@field chatChannel string
---@field countdownSounds QRA_CountdownSounds
---@field framePosition QRA_FramePosition
local config = {
    ttsEnabled = true,
    soundEnabled = true,
    screenEnabled = true,
    chatEnabled = true,

    screenDuration = 5,        -- Default screen message duration
    screenPosition = "CENTER", -- Where to show screen messages
    chatChannel = "SAY",       -- Default chat channel

    countdownSounds = {
        [10] = "Interface/AddOns/QRaidAssignments/Media/Sounds/10.ogg",
        [9] = "Interface/AddOns/QRaidAssignments/Media/Sounds/9.ogg",
        [8] = "Interface/AddOns/QRaidAssignments/Media/Sounds/8.ogg",
        [7] = "Interface/AddOns/QRaidAssignments/Media/Sounds/7.ogg",
        [6] = "Interface/AddOns/QRaidAssignments/Media/Sounds/6.ogg",
        [5] = "Interface/AddOns/QRaidAssignments/Media/Sounds/5.ogg",
        [4] = "Interface/AddOns/QRaidAssignments/Media/Sounds/4.ogg",
        [3] = "Interface/AddOns/QRaidAssignments/Media/Sounds/3.ogg",
        [2] = "Interface/AddOns/QRaidAssignments/Media/Sounds/2.ogg",
        [1] = "Interface/AddOns/QRaidAssignments/Media/Sounds/1.ogg",
    },

    framePosition = {
        point = "TOP",
        xOfs = 0,
        yOfs = -200,
    }
}

local MOVER_GROUP = "QRA Movers"

---@type QRA_ScreenMessageFrame
local notificationFrame = nil

---@type TickerCallback
local countdownTicker = nil

function UpdateFramePosition(point, x, y)
    config.framePosition.point = point
    config.framePosition.xOfs = x
    config.framePosition.yOfs = y

    notificationFrame:UpdatePosition(point, x, y)
end

---@param type AlertType Notification type
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


    if C_VoiceChat and C_VoiceChat.SpeakText then
        local voiceId = voice or Enum.TtsVoiceType.Alternate
        C_VoiceChat.SpeakText(
            voiceId,
            message,
            Enum.VoiceTtsDestination.LocalPlayback,
            1.0,  -- Speech rate
            100   -- Volume
        )
    else
        QRA.Print("Issue with TTS: C_VoiceChat.SpeakText not available")
    end
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

    notificationFrame:SetMessageText(message)
    notificationFrame.text:SetTextColor(1, 1, 0)
    if color then
        notificationFrame.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 0)
    end
    notificationFrame:SetCountdownText("")
    notificationFrame:HideBar()

    notificationFrame:SetAlpha(1)
    notificationFrame:Show()
    -- notificationFrame:FadeOut(duration or (config.screenDuration))
end

--- Show a countdown start notification
---@param assignment Assignment The assignment starting countdown
---@param seconds number Seconds remaining
function QRA.Notifications.ShowCountdown(assignment, seconds)
    if not config.screenEnabled then return end

    local message = assignment.message
    if message == "" and assignment.spellName then
        message = string.format("Use %s", assignment.spellName)
        if assignment.targetPlayer and assignment.targetPlayer ~= "" then
            message = message .. " on " .. assignment.targetPlayer
        end
    end
    message = message or "Assignment triggered!"

    notificationFrame:Init(message, assignment.spellId, seconds)
    notificationFrame:SetAlpha(1)
    notificationFrame:Show()

    -- Don't auto-hide during countdown
    notificationFrame.fadeAnim:Stop()

    if countdownTicker then
        countdownTicker:Cancel()
    end

    local remaining = seconds
    local startTime = GetTime()
    QRA.Notifications.PlayCountdown(seconds)
    countdownTicker = C_Timer.NewTicker(1, function()
        local elapsed = GetTime() - startTime
        remaining = seconds - elapsed

        if remaining > 0 then
            QRA.Notifications.PlayCountdown(math.ceil(remaining))
            notificationFrame:SetBarValue((remaining / seconds) * 100)
        end
        notificationFrame:UpdateCountdown(math.ceil(remaining))
    end, seconds)
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
---@return QRA_NotificationConfig
function QRA.Notifications.GetConfig()
    return config
end

--- Update notification settings
---@param settings QRA_NotificationConfig
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
        framePosition = config.framePosition,
    }
end

--- Load notification settings from DB
function QRA.Notifications.LoadFromDB()
    if not QRA.DB or not QRA.DB.notifications then return end

    for key, value in pairs(QRA.DB.notifications) do
        if config[key] then
            config[key] = value
        end
    end
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Notifications.Initialize()
    QRA.Notifications.LoadFromDB()
    notificationFrame = QRA.Notifications.UI.CreateScreenMessageFrame(config.framePosition)
    AF.CreateMover(notificationFrame, MOVER_GROUP, "Notification Frame", UpdateFramePosition)
    QRA.Debug("Notifications: Module initialized")
end
